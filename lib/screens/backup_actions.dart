import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../data/backup.dart';
import '../data/local_store.dart';
import '../l10n/l10n.dart';

/// Settings → Backup: export to / import from a JSON file the user picks.

Future<void> exportBackup(BuildContext context) async {
  final l = context.l10n;
  final ok = await _confirm(context, l.exportWarningTitle, l.exportWarningBody, l.exportAction);
  if (ok != true || !context.mounted) return;
  try {
    final json = await Backup.export(await LocalStore.instance());
    final saved = await FilePicker.saveFile(
      fileName: 'pocketsense-${DateFormat('yyyy-MM-dd', 'en').format(DateTime.now())}.json',
      bytes: utf8.encode(json),
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
    final ok = await _confirm(context, l.importConfirmTitle, l.importConfirmBody, l.importAction);
    if (ok != true || !context.mounted) return false;
  }

  final String json;
  try {
    json = utf8.decode(await file.readAsBytes());
  } on FormatException {
    if (context.mounted) _toast(context, l.backupNotJson);
    return false;
  } catch (e) {
    if (context.mounted) _toast(context, l.backupReadFailed('$e'));
    return false;
  }
  try {
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
    };

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
