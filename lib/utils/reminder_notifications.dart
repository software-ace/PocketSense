import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/local_store.dart';
import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../settings/app_settings.dart';
import 'reminders.dart';

/// Turns the items' reminders into notifications, again whenever data or a
/// setting changes (sync included). Android schedules them with the system,
/// which also shows ones missed while the phone was off once it's back on.
/// The desktop (Linux, Windows) shows them while the app runs, missed ones when
/// it opens.
abstract final class ReminderNotifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _prefs = SharedPreferencesAsync();
  // Android: alarms from an earlier run may still be pending.
  static const _scheduledKey = 'reminders.scheduled';
  // Desktop: reminders up to this time have been shown.
  static const _shownKey = 'reminders.shownUntil';

  /// What a tapped notification asked for: its payload (`recurring:<id>` or
  /// `loan:<id>`), prefixed `create:` from Create Transaction. Whoever acts
  /// on it sets it back to null.
  static final pending = ValueNotifier<String?>(null);

  static const _create = 'create', _dismiss = 'dismiss';
  static bool _ready = false;
  static bool _busy = false;
  static bool _again = false;
  static Timer? _timer;
  static LocalStore? _store;

  static bool get _supported => Platform.isAndroid || Platform.isLinux || Platform.isWindows;
  static List<Listenable> get _settings => [AppSettings.locale, AppSettings.reminderAmounts, AppSettings.currency];

  static Future<void> start() async {
    if (!_supported || _store != null) return;
    _store = await LocalStore.instance();
    _store!.changes.addListener(refresh);
    for (final s in _settings) {
      s.addListener(refresh);
    }
    if (!Platform.isAndroid) _timer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
    await refresh();
  }

  static void stop() {
    _store?.changes.removeListener(refresh);
    _store = null;
    for (final s in _settings) {
      s.removeListener(refresh);
    }
    _timer?.cancel();
    _timer = null;
  }

  /// Whether reminders can show. [ask]: on Android 13+, ask for the
  /// permission first if it hasn't been answered.
  static Future<bool> allowed({bool ask = false}) async {
    if (!Platform.isAndroid) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      return (ask ? await android?.requestNotificationsPermission() : await android?.areNotificationsEnabled()) ?? true;
    } catch (_) {
      return true;
    }
  }

  static const _background = MethodChannel('pocketsense/background');

  /// Makers whose phones stop an app's alarms (after a swipe from recents,
  /// or a reboot) unless it's allowed in their own settings.
  @visibleForTesting
  static const limitingMakers = {'xiaomi', 'huawei', 'honor', 'oppo', 'vivo', 'realme', 'oneplus', 'samsung'};

  /// Whether this phone needs those settings for reminders to arrive.
  static Future<bool> backgroundLimited() async {
    if (!Platform.isAndroid) return false;
    try {
      return limitingMakers.contains((await _background.invokeMethod<String>('manufacturer'))?.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  /// Opens Pocket Sense's App info, where those settings are.
  static Future<void> openAppSettings() => _background.invokeMethod('openAppSettings');

  /// Runs once at a time; a change during a run makes it run again after.
  static Future<void> refresh() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        await _run();
      } while (_again);
    } catch (e, st) {
      debugPrint('reminders: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  static Future<void> _run() async {
    final repo = FinanceRepo();
    final items = await repo.recurring();
    final loans = await repo.loans();
    final now = DateTime.now();
    final locale = resolveAppLocale(AppSettings.locale.value, PlatformDispatcher.instance.locale);
    final l = lookupAppLocalizations(locale);
    String text(Reminder r, DateTime today) =>
        reminderText(l, r, today, amounts: AppSettings.reminderAmounts.value, locale: locale.languageCode);
    final details = NotificationDetails(
      // Private: a secure lock screen shows that there is one, not its text.
      android: AndroidNotificationDetails('reminders', l.reminderChannel,
          visibility: NotificationVisibility.private,
          category: AndroidNotificationCategory.reminder,
          actions: [
            // Opens the app, so the app lock still applies.
            AndroidNotificationAction(_create, l.reminderCreate, showsUserInterface: true),
            AndroidNotificationAction(_dismiss, l.reminderDismiss),
          ]),
      linux: LinuxNotificationDetails(actions: [
        LinuxNotificationAction(key: _create, label: l.reminderCreate),
        LinuxNotificationAction(key: _dismiss, label: l.reminderDismiss),
      ]),
      windows: WindowsNotificationDetails(actions: [
        // The action's arguments come back as its id.
        WindowsAction(content: l.reminderCreate, arguments: _create),
        WindowsAction(content: l.reminderDismiss, arguments: _dismiss),
      ]),
    );

    if (Platform.isAndroid) {
      // shortcut: schedules 90 days ahead (and under Android's 500-alarm cap);
      // each app open moves the window, so only a phone left unopened longer misses some.
      final list = remindersBetween(items, loans, now, now.add(const Duration(days: 90))).take(400).toList();
      // Nothing to schedule or cancel: leave the plugin unstarted.
      if (list.isEmpty && !(await _prefs.getBool(_scheduledKey) ?? false)) return;
      await _init(l);
      await _plugin.cancelAllPendingNotifications();
      for (final r in list) {
        await _plugin.zonedSchedule(
          id: r.id,
          // A fixed instant; the local time zone, DST included, is in r.at.
          scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
          notificationDetails: details,
          // Inexact: a reminder a few minutes late is fine, and exact alarms need a permission.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: l.reminderTitle,
          body: text(r, r.at),
          payload: r.payload,
        );
      }
      await _prefs.setBool(_scheduledKey, list.isNotEmpty);
      return;
    }

    final shownUntil = DateTime.tryParse(await _prefs.getString(_shownKey) ?? '');
    await _prefs.setString(_shownKey, now.toIso8601String());
    // First run: start from now rather than replaying every past reminder.
    if (shownUntil == null) return;
    // One per item, its latest: a week closed shouldn't bring seven of the same.
    final latest = {for (final r in remindersBetween(items, loans, shownUntil, now)) r.payload: r};
    if (latest.isEmpty) return;
    await _init(l);
    for (final r in latest.values) {
      await _plugin.show(id: r.id, title: l.reminderTitle, body: text(r, now), notificationDetails: details, payload: r.payload);
    }
  }

  static Future<void> _init(AppLocalizations l) async {
    if (_ready) return;
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_notification'),
        linux: LinuxInitializationSettings(defaultActionName: l.reminderOpen),
        // A fixed GUID names the app to Windows; changing it orphans its notifications.
        windows: const WindowsInitializationSettings(
            appName: 'Pocket Sense', appUserModelId: 'ace.software.pocketsense', guid: '20fb7ecf-d10b-4ba4-becb-cfcf99983669'),
      ),
      onDidReceiveNotificationResponse: _respond,
    );
    _ready = true;
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if ((launch?.didNotificationLaunchApp ?? false) && response != null && pending.value == null) _respond(response);
    } catch (_) {
      // Not available on Linux; there a tap reaches onDidReceiveNotificationResponse.
    }
  }

  static void _respond(NotificationResponse r) {
    final payload = r.payload;
    // Dismiss only closes it (Android does that itself; Linux reports it too).
    if (payload == null || r.actionId == _dismiss) return;
    pending.value = r.actionId == _create ? '$_create:$payload' : payload;
  }
}
