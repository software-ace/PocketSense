import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/db_key.dart';
import 'data/local_store.dart';
import 'data/repo.dart';
import 'l10n/l10n.dart';
import 'screens/onboarding_screen.dart';
import 'security/lock_gate.dart';
import 'settings/app_settings.dart';
import 'shell.dart';
import 'sync/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Packages register their own licenses; the bundled font doesn't.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Noto Sans Arabic'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  await AppSettings.load();
  runApp(const PocketSenseApp());
}

ThemeData appTheme(Brightness brightness) => ThemeData(
      brightness: brightness,
      colorSchemeSeed: brightness == Brightness.light ? const Color(0xFF4F46E5) : const Color(0xFF818CF8),
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // Arabic glyphs come from the bundled font; Latin text keeps the
      // platform font.
      fontFamilyFallback: const ['NotoSansArabic'],
    );

/// Bumped to start over from an empty database (after "erase all data"):
/// Boot is keyed by it, so it opens again from scratch.
final _generation = ValueNotifier(0);

Future<void> _eraseAndRestart() async {
  await SyncService.instance.stop();
  await LocalStore.eraseAll();
  await AppSettings.setSync(enabled: false);
  // Starting over is exactly when "Import a backup" is wanted.
  await AppSettings.setOnboardingStep(0);
  // Left on, it would soon rotate the old backups out with near-empty ones.
  await AppSettings.setAutoBackupDir(null);
  _generation.value++;
}

class PocketSenseApp extends StatelessWidget {
  const PocketSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: AppSettings.locale,
      builder: (context, locale, _) => MaterialApp(
        onGenerateTitle: (c) => c.l10n.appTitle,
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        localeResolutionCallback: (device, _) {
          final resolved = resolveAppLocale(locale, device);
          AppSettings.applyToIntl(resolved);
          return resolved;
        },
        theme: appTheme(Brightness.light),
        darkTheme: appTheme(Brightness.dark),
        // Above the Navigator, so the lock covers every route and dialog.
        builder: (context, child) => LockGate(onEraseAll: _eraseAndRestart, child: child!),
        home: ValueListenableBuilder<int>(
          valueListenable: _generation,
          builder: (_, generation, _) => Boot(key: ValueKey(generation)),
        ),
      ),
    );
  }
}

/// Opens the on-device database behind the splash, then shows the app. If the
/// database can't be opened, says so instead of running without data.
class Boot extends StatefulWidget {
  const Boot({super.key});

  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  Future<void>? _opening;

  // Starter categories are named in the UI language, so opening waits for
  // localizations (not available yet in initState). This also runs again
  // whenever the language changes, and renames them to match.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opening == null) {
      _opening = _open();
    } else {
      final names = starterCategoryNames(context.l10n);
      _opening!.then((_) => _localizeCategories(names)).ignore();
    }
  }

  Future<void> _open() async {
    final names = starterCategoryNames(context.l10n);
    await LocalStore.open(categoryNames: names, starterNames: starterCategoryDefaultNames());
    // The system language may have changed since they were created.
    await _localizeCategories(names);
  }

  static Future<void> _localizeCategories(Map<String, String> names) =>
      FinanceRepo().localizeStarterCategories(names, starterCategoryDefaultNames());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _opening,
      builder: (context, snap) {
        if (snap.hasError) {
          return StartupError(
            error: snap.error!,
            onRetry: () => setState(() => _opening = _open()),
            onErase: snap.error is DbKeyLost ? _eraseAndRestart : null,
          );
        }
        if (snap.connectionState != ConnectionState.done) return const _Splash();
        if (AppSettings.onboardingStep < AppSettings.onboardingDone) {
          return OnboardingScreen(onDone: () => setState(() {}));
        }
        return const Shell();
      },
    );
  }
}

class StartupError extends StatelessWidget {
  const StartupError({super.key, required this.error, required this.onRetry, this.onErase});

  final Object error;
  final VoidCallback onRetry;

  /// Offered only when the data is unrecoverable ([DbKeyLost]).
  final VoidCallback? onErase;

  static String describe(AppLocalizations l, Object error) => switch (error) {
        KeyStoreUnavailable(:final detail) => l.keyringUnavailable(detail),
        DbKeyLost() => l.dbKeyLost,
        _ => '$error',
      };

  Future<void> _confirmErase(BuildContext context) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.eraseAllTitle),
        content: Text(l.eraseAllBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.erase),
          ),
        ],
      ),
    );
    if (ok == true) onErase!();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(l.startupErrorTitle, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(describe(l, error), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: Text(l.tryAgain)),
                if (onErase != null) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => _confirmErase(context), child: Text(l.eraseAndStartOver)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Matches the native Android splash background.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Center(child: Image.asset('assets/splash_icon.png', width: 120, height: 120)),
      );
}
