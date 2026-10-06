import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../data/auto_backup.dart';
import '../data/backup.dart';
import '../data/local_store.dart';
import '../l10n/l10n.dart';
import '../settings/app_settings.dart';

/// Settings → Backup: export to / import from a file the user picks. Exports
/// are always encrypted with the backup password; imports read old plain
/// files too.

Future<void> exportBackup(BuildContext context) async {
  final l = context.l10n;
  final password = await ensureBackupPassword(context);
  if (password == null || !context.mounted) return;
  try {
    _toast(context, l.preparingBackup);
    final sealed = await Backup.encrypt(await Backup.export(await LocalStore.instance()), password);
    if (!context.mounted) return;
    final saved = await FilePicker.saveFile(
      fileName: 'pocketsense-${DateFormat('yyyy-MM-dd', 'en').format(DateTime.now())}.json',
      bytes: utf8.encode(sealed),
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (saved != null && context.mounted) _toast(context, l.exportDone);
  } catch (e) {
    if (context.mounted) _toast(context, l.exportFailed('$e'));
  }
}

/// Returns true once a backup was imported. [confirmReplace] asks first;
/// onboarding skips it, since there is nothing there yet to replace.
Future<bool> importBackup(BuildContext context, {bool confirmReplace = true}) async {
  final l = context.l10n;
  final PlatformFile? file;
  try {
    file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['json']);
  } catch (e) {
    if (context.mounted) _toast(context, l.backupReadFailed('$e'));
    return false;
  }
  if (file == null || !context.mounted) return false;
  if (confirmReplace) {
    final paired = (await (await LocalStore.instance()).selectRows('peers')).isNotEmpty;
    if (!context.mounted) return false;
    final body = paired ? '${l.importConfirmBody} ${l.importConfirmSynced}' : l.importConfirmBody;
    final ok = await _confirm(context, l.importConfirmTitle, body, l.importAction);
    if (ok != true || !context.mounted) return false;
  }

  String json;
  try {
    json = utf8.decode(await file.readAsBytes());
  } on FormatException {
    if (context.mounted) _toast(context, l.backupNotJson);
    return false;
  } catch (e) {
    if (context.mounted) _toast(context, l.backupReadFailed('$e'));
    return false;
  }
  if (!context.mounted) return false;
  try {
    if (Backup.isEncrypted(json)) {
      final opened = await _openEncrypted(context, json);
      if (opened == null || !context.mounted) return false;
      json = opened;
    }
    final s = await Backup.import(await LocalStore.instance(), json);
    if (context.mounted) _toast(context, l.importDone(s.categories + s.transactions + s.budgets + s.recurring));
    return true;
  } on BackupException catch (e) {
    if (context.mounted) _toast(context, describeBackupProblem(l, e));
    return false;
  }
}

String describeBackupProblem(AppLocalizations l, BackupException e) => switch (e.problem) {
      BackupProblem.notJson => l.backupNotJson,
      BackupProblem.notABackup => l.backupNotABackup,
      BackupProblem.tooNew => l.backupTooNew,
      BackupProblem.wrongCurrency => l.backupWrongCurrency(e.detail ?? '?'),
      BackupProblem.badData => l.backupBadData(e.detail ?? ''),
      BackupProblem.wrongPassword => l.backupWrongPassword,
    };

/// Turns on daily backups: needs a backup password and a folder the app can
/// write to, then makes the first backup right away.
Future<void> enableAutoBackup(BuildContext context) async {
  if (await ensureBackupPassword(context) == null || !context.mounted) return;
  final dir = await FilePicker.getDirectoryPath();
  if (dir == null || !context.mounted) return;
  if (!await AutoBackup.canWrite(dir)) {
    if (context.mounted) _toast(context, context.l10n.autoBackupFolderUnusable);
    return;
  }
  await AppSettings.setAutoBackupDir(dir);
  await AutoBackup.runIfDue();
}

/// The plain JSON inside an encrypted backup, or null if the user gives up.
/// Tries the saved password first, so on the device that made the file
/// nothing is asked. A password that works on a device with none saved is
/// kept, for automatic backups.
Future<String?> _openEncrypted(BuildContext context, String sealed) async {
  final saved = await BackupPassword.read();
  if (saved != null) {
    try {
      return await Backup.decrypt(sealed, saved);
    } on BackupException catch (e) {
      if (e.problem != BackupProblem.wrongPassword) rethrow;
    }
  }
  var wrong = false;
  while (true) {
    if (!context.mounted) return null;
    final password = await _askPassword(context, wrong: wrong);
    if (password == null) return null;
    try {
      final json = await Backup.decrypt(sealed, password);
      if (saved == null) await BackupPassword.save(password);
      return json;
    } on BackupException catch (e) {
      if (e.problem != BackupProblem.wrongPassword) rethrow;
      wrong = true;
    }
  }
}

/// The saved backup password, or a new one the user chooses now.
Future<String?> ensureBackupPassword(BuildContext context) async =>
    await BackupPassword.read() ?? (context.mounted ? await setBackupPassword(context) : null);

/// Asks for a new backup password (twice), saves it and returns it.
Future<String?> setBackupPassword(BuildContext context, {bool changing = false}) async {
  final password = await showDialog<String>(context: context, builder: (_) => _NewPasswordDialog(changing: changing));
  if (password == null) return null;
  await BackupPassword.save(password);
  if (context.mounted) _toast(context, context.l10n.backupPasswordSaved);
  return password;
}

Future<String?> _askPassword(BuildContext context, {required bool wrong}) =>
    showDialog<String>(context: context, builder: (_) => _UnlockDialog(wrong: wrong));

// Stateful so the controller outlives the closing animation: disposing it as
// soon as showDialog returns breaks the still-visible text field.
class _UnlockDialog extends StatefulWidget {
  const _UnlockDialog({required this.wrong});
  final bool wrong;

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.encryptedBackupTitle),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.encryptedBackupBody),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(labelText: l.passwordLabel, errorText: widget.wrong ? l.backupWrongPassword : null, errorMaxLines: 3),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text), child: Text(l.unlock)),
      ],
    );
  }
}

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog({required this.changing});
  final bool changing;

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _second = TextEditingController();

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) Navigator.pop(context, _first.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.chooseBackupPassword),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.backupPasswordWarning),
            if (widget.changing) ...[const SizedBox(height: 8), Text(l.backupPasswordChangeNote)],
            const SizedBox(height: 12),
            TextFormField(
              controller: _first,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(labelText: l.passwordLabel),
              validator: (v) => (v ?? '').length < BackupPassword.minLength ? l.passwordTooShort(BackupPassword.minLength) : null,
            ),
            TextFormField(
              controller: _second,
              obscureText: true,
              decoration: InputDecoration(labelText: l.repeatPasswordLabel),
              validator: (v) => v != _first.text ? l.passwordsDontMatch : null,
              onFieldSubmitted: (_) => _save(),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}

Future<bool?> _confirm(BuildContext context, String title, String body, String action) => showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
