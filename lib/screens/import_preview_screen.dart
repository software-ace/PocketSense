import 'package:flutter/material.dart';

import '../data/csv_files.dart';
import '../l10n/l10n.dart';
import '../utils/format.dart';

/// After a CSV file is picked (transactions, categories or merchants): what
/// each row would do, then the import, then what it did. Nothing is written
/// until Import is tapped.
class ImportPreviewScreen extends StatefulWidget {
  const ImportPreviewScreen({super.key, required this.fileName, required this.bytes, required this.preview});
  final String fileName;
  final int bytes;
  final CsvPreview preview;

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  // Which rows the list shows; null is all of them.
  CsvVerdict? _filter;
  bool _importing = false;
  ImportSummary? _done;
  Object? _error;

  CsvKind get _kind => widget.preview.kind;
  int _count(CsvVerdict v) => widget.preview.count(v);

  Future<void> _import() async {
    // A second click before the redraw would write every row again.
    if (_importing || _done != null) return;
    setState(() => _importing = true);
    try {
      final summary = await CsvFiles.importPreview(widget.preview);
      if (mounted) setState(() => _done = summary);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final adding = _count(CsvVerdict.add);
    final done = _done;
    final title = switch (_kind) {
      CsvKind.transactions => l.importTransactions,
      CsvKind.categories => l.importCategories,
      CsvKind.merchants => l.importMerchants,
    };
    final importLabel = switch (_kind) {
      CsvKind.transactions => l.csvImportN(adding),
      CsvKind.categories => l.csvImportCategoriesN(adding),
      CsvKind.merchants => l.csvImportMerchantsN(adding),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: done != null
            ? _summary(done)
            : _importing
                ? _progress(adding)
                : _previewBody(),
      ),
      bottomNavigationBar: _importing
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: done != null
                    ? FilledButton(onPressed: () => Navigator.pop(context), child: Text(l.done))
                    : Row(children: [
                        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: FilledButton(onPressed: adding == 0 ? null : _import, child: Text(importLabel))),
                      ]),
              ),
            ),
    );
  }

  // ── Preview ──────────────────────────────────────────────────────────

  /// The table's columns before Status: a header and a fixed width, or
  /// null to take the space left.
  List<(String, double?)> _columns() {
    final l = context.l10n;
    return switch (_kind) {
      CsvKind.transactions => [(l.csvColDate, 92), (l.csvColAmount, 76), (l.csvColDetails, null)],
      CsvKind.categories => [(l.csvColName, null), (l.csvColType, 80), (l.csvColColor, 92)],
      CsvKind.merchants => [(l.csvColName, null)],
    };
  }

  Widget _previewBody() {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = [for (final r in widget.preview.rows) if (_filter == null || r.verdict == _filter) r];
    final kb = (widget.bytes / 1024).ceil();

    Widget counter(String label, int n, CsvVerdict? filter, Color bg, Color fg) {
      final selected = _filter == filter;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _filter = filter),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$n', style: theme.textTheme.titleLarge?.copyWith(color: fg, fontWeight: FontWeight.w700)),
                  Text(label, style: theme.textTheme.bodySmall?.copyWith(color: fg), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    // One scroll: the counters and layout card move away as you read rows.
    Widget box(Widget child) => SliverToBoxAdapter(child: child);
    return CustomScrollView(slivers: [
      box(Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.description_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.fileName, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
            Text('$kb KB · CSV', style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline)),
          ]),
        ),
      )),
      box(Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          counter(l.csvRowsFound, widget.preview.rows.length, null, scheme.surfaceContainerHighest, scheme.onSurface),
          const SizedBox(width: 8),
          counter(l.csvWillImport, _count(CsvVerdict.add), CsvVerdict.add, scheme.primaryContainer, scheme.onPrimaryContainer),
          const SizedBox(width: 8),
          counter(l.csvDuplicate, _count(CsvVerdict.duplicate), CsvVerdict.duplicate, _amber(scheme).withValues(alpha: 0.18), _amber(scheme)),
          const SizedBox(width: 8),
          counter(l.csvRejected, _count(CsvVerdict.rejected), CsvVerdict.rejected, scheme.errorContainer, scheme.onErrorContainer),
        ]),
      )),
      box(Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Text(_kind == CsvKind.transactions ? l.csvPreviewNote : l.csvPreviewNoteNames,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline)),
      )),
      box(Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: _layoutCard())),
      if (_error != null)
        box(Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l.addFailed('$_error'), style: TextStyle(color: scheme.error)),
        )),
      box(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          _tableRow([
            for (final (header, _) in _columns()) Text(header, style: theme.textTheme.labelMedium?.copyWith(color: scheme.outline)),
            Text(l.csvColStatus, style: theme.textTheme.labelMedium?.copyWith(color: scheme.outline)),
          ]),
          const Divider(height: 1),
        ]),
      )),
      if (rows.isEmpty)
        box(Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text(l.csvNoRowsHere, style: TextStyle(color: scheme.outline))),
        ))
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => _previewRow(rows[i]),
          ),
        ),
    ]);
  }

  // The columns from [_columns], then Status: the same widths in every row.
  Widget _tableRow(List<Widget> cells, {Color? color}) {
    final columns = _columns();
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, (_, width)) in columns.indexed) ...[
          if (width == null) Expanded(child: cells[i]) else SizedBox(width: width, child: cells[i]),
          const SizedBox(width: 10),
        ],
        SizedBox(width: 96, child: cells.last),
      ]),
    );
  }

  Widget _previewRow(PreviewRow r) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tabular = theme.textTheme.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final bold = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    final (tag, tagBg, tagFg) = switch (r.verdict) {
      CsvVerdict.add => (l.csvNew, scheme.primaryContainer, scheme.onPrimaryContainer),
      CsvVerdict.duplicate => (l.csvDuplicateTag, _amber(scheme).withValues(alpha: 0.18), _amber(scheme)),
      CsvVerdict.rejected => (l.csvRejectedTag, scheme.errorContainer, scheme.onErrorContainer),
    };
    final reason = switch (r.problem) {
      'date' => l.csvProblemDate,
      'type' => l.csvProblemType,
      'amount' => r['amount'].isEmpty
          ? l.csvProblemNoAmount
          // 12,5 or 1,23: a comma that isn't between thousands.
          : RegExp(r'\d,\d{1,2}$').hasMatch(r['amount'])
              ? l.csvProblemDecimalComma
              : l.csvProblemAmount,
      'name' => l.csvProblemName,
      'color' => l.csvProblemColor,
      _ => null,
    };

    final cells = switch (_kind) {
      CsvKind.transactions => () {
          final fils = parseAmount(r['amount']);
          // Spending shows as minus, as on a bank statement.
          final amount = fils == null || r.problem != null ? '—' : '${r['type'].toLowerCase() == 'income' ? '+' : '−'}${amountToInput(fils)}';
          return <Widget>[
            Text(r['date'], style: tabular),
            // Numbers read left to right in Arabic too.
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(amount, textDirection: TextDirection.ltr, style: tabular?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['description'].isEmpty ? '—' : r['description'], style: bold),
              if (r['merchant'].isNotEmpty) Text(r['merchant'], style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline)),
            ]),
          ];
        }(),
      CsvKind.categories => () {
          final type = r['type'].toLowerCase();
          final hex = r['color'];
          final color = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex) ? Color(int.parse('ff${hex.substring(1)}', radix: 16)) : null;
          return <Widget>[
            Text(r['name'].isEmpty ? '—' : r['name'], style: bold),
            Text(type == 'income' ? l.income : (type == 'expense' ? l.expense : (r['type'].isEmpty ? '—' : r['type']))),
            Row(children: [
              if (color != null) ...[
                Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Flexible(child: Text(hex.isEmpty ? '—' : hex, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
            ]),
          ];
        }(),
      CsvKind.merchants => <Widget>[Text(r['name'].isEmpty ? '—' : r['name'], style: bold)],
    };

    return _tableRow(
      color: r.verdict == CsvVerdict.rejected ? scheme.errorContainer.withValues(alpha: 0.35) : null,
      [
        ...cells,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(6)),
            child: Text(tag, style: theme.textTheme.labelSmall?.copyWith(color: tagFg, fontWeight: FontWeight.w600)),
          ),
          if (reason != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(reason, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
            ),
        ]),
      ],
    );
  }

  /// The layout the file must have, with an example: open by itself when
  /// rows were rejected, so the fix is right there.
  Widget _layoutCard() {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (rules, example) = switch (_kind) {
      CsvKind.transactions => (
          [l.csvRuleDate, l.csvRuleType, l.csvRuleAmount, l.csvRuleOptional],
          'date,type,amount,description,category,merchant,account\n'
              '2026-11-08,expense,12.75,Morning coffee,Coffee,Rumi Cafe,Cash\n'
              '2026-11-01,income,"1,250",October salary,Salary,,Arab Bank'
        ),
      CsvKind.categories => (
          [l.csvRuleName, l.csvRuleType, l.csvRuleColor],
          'name,type,color\n'
              'Groceries,expense,#16a34a\n'
              'Freelance,income,'
        ),
      CsvKind.merchants => (
          [l.csvRuleMerchant],
          'name\n'
              'Abdali Mall\n'
              'Carrefour'
        ),
    };
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: _count(CsvVerdict.rejected) > 0,
        leading: const Icon(Icons.help_outline),
        title: Text(l.csvLayoutTitle),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  '),
                Expanded(child: Text(rule, style: theme.textTheme.bodyMedium)),
              ]),
            ),
          const SizedBox(height: 6),
          Text(l.csvExample, style: theme.textTheme.labelMedium?.copyWith(color: scheme.outline)),
          const SizedBox(height: 4),
          // The file's own text: left to right, and scrolls sideways on a phone.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(example, textDirection: TextDirection.ltr, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Importing and done ───────────────────────────────────────────────

  Widget _progress(int adding) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(l.csvImporting, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l.csvImportingDetail(adding), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
        ]),
      ),
    );
  }

  Widget _summary(ImportSummary s) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = [
      ...switch (_kind) {
        CsvKind.transactions => [(l.csvSumAdded, s.added, true), (l.csvSumDuplicates, s.duplicates, false)],
        CsvKind.categories => [(l.csvSumCategoriesAdded, s.added, true), (l.csvSumAlreadyThere, s.duplicates, false)],
        CsvKind.merchants => [(l.csvSumMerchantsAdded, s.added, true), (l.csvSumAlreadyThere, s.duplicates, false)],
      },
      if (s.rejected > 0) (l.csvSumRejected, s.rejected, false),
      if (_kind == CsvKind.transactions) ...[
        (l.csvSumCategories, s.categoriesMatched, false),
        (l.csvSumMerchants, s.newMerchants, false),
        (l.csvSumUncategorized, s.uncategorized, false),
        if (s.unknownAccounts > 0) (l.csvSumUnknownAccounts, s.unknownAccounts, false),
      ],
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(radius: 36, backgroundColor: Colors.green.withValues(alpha: 0.18), child: const Icon(Icons.check, size: 36, color: Colors.green)),
            const SizedBox(height: 20),
            Text(l.csvImportComplete, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(l.csvImportCompleteBody, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                for (final (i, (label, n, highlight)) in lines.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Expanded(child: Text(label)),
                      Text('$n', style: TextStyle(fontWeight: FontWeight.w700, color: highlight ? Colors.green : null)),
                    ]),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // Warning amber that reads on both light and dark surfaces.
  static Color _amber(ColorScheme scheme) => scheme.brightness == Brightness.dark ? const Color(0xFFF5C451) : const Color(0xFF8A5A00);
}
