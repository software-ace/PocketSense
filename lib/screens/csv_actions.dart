import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../data/csv_files.dart';
import '../l10n/l10n.dart';
import 'import_preview_screen.dart';

export '../data/csv_files.dart' show CsvKind;

/// Saves [kind] as a CSV file the user places.
Future<void> exportCsv(BuildContext context, CsvKind kind) async {
  final l = context.l10n;
  try {
    final text = await CsvFiles.export(kind);
    if (!context.mounted) return;
    final saved = await FilePicker.saveFile(
      fileName: 'pocketsense-${kind.name}-${DateFormat('yyyy-MM-dd', 'en').format(DateTime.now())}.csv',
      bytes: utf8.encode(text),
      mimeType: 'text/csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (saved != null && context.mounted) _toast(context, l.csvSaved);
  } catch (e) {
    if (context.mounted) _toast(context, l.exportFailed('$e'));
  }
}

/// Picks a CSV file and opens its preview, where the user imports it or
/// not. Only ever adds; open lists reload by themselves (DataAware).
Future<void> importCsv(BuildContext context, CsvKind kind) async {
  final l = context.l10n;
  final PlatformFile? file;
  final List<int> bytes;
  final String text;
  try {
    file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['csv']);
    if (file == null) return;
    bytes = await file.readAsBytes();
    text = utf8.decode(bytes);
  } on FormatException {
    if (context.mounted) _toast(context, l.csvNotUtf8);
    return;
  } catch (e) {
    if (context.mounted) _toast(context, l.backupReadFailed('$e'));
    return;
  }

  final CsvPreview preview;
  try {
    preview = await CsvFiles.preview(kind, text);
  } on CsvLayoutException catch (e) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.csvCantImportTitle),
          content: Text('${l.csvMissingColumns(e.missing.join(', '))}\n\n${l.csvLayoutHint(CsvFiles.columns[kind]!.join(', '))}'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.done))],
        ),
      );
    }
    return;
  } catch (e) {
    if (context.mounted) _toast(context, l.backupReadFailed('$e'));
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ImportPreviewScreen(fileName: file!.name, bytes: bytes.length, preview: preview)));
}

void _toast(BuildContext context, String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// The ⋮ menu on the Categories and Merchants screens.
class CsvMenu extends StatelessWidget {
  const CsvMenu({super.key, required this.kind});
  final CsvKind kind;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopupMenuButton<bool>(
      onSelected: (import) => import ? importCsv(context, kind) : exportCsv(context, kind),
      itemBuilder: (_) => [
        PopupMenuItem(value: true, child: ListTile(leading: const Icon(Icons.restore_page_outlined), title: Text(l.importCsv), contentPadding: EdgeInsets.zero)),
        PopupMenuItem(value: false, child: ListTile(leading: const Icon(Icons.upload_file_outlined), title: Text(l.exportCsv), contentPadding: EdgeInsets.zero)),
      ],
    );
  }
}
