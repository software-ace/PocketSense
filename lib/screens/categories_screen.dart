import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../utils/platform.dart';
import '../widgets/state_views.dart';
import '../widgets/data_aware.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with SingleTickerProviderStateMixin, DataAware {
  final _repo = FinanceRepo();
  List<Category> _cats = [];
  Object? _error;
  bool _loading = true;
  String _filter = 'all';
  late final TabController _tabController = TabController(length: 3, vsync: this);

  static const _filters = {'all', 'expense', 'income'};

  List<Category> get _filtered => _filter == 'all' ? _cats : _cats.where((c) => c.type == _filter).toList();

  static const _swatches = [
    '#6366f1', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6',
    '#06b6d4', '#ec4899', '#84cc16', '#f97316', '#14b8a6',
    '#3b82f6', '#a855f7',
  ];

  @override
  void onDataChanged() => _load();

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() => _filter = _filters.elementAt(_tabController.index));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await _repo.categories();
      if (!mounted) return;
      setState(() {
        _cats = c;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Color hex(String h) {
    final s = h.startsWith('#') ? h.substring(1) : h;
    return Color(int.parse('FF$s', radix: 16));
  }

  Future<void> _edit(Category? existing) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _CategoryDialog(existing: existing));
    if (saved == true) await _load();
  }

  Future<void> _delete(Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteNamedTitle(c.name)),
        content: Text(ctx.l10n.deleteCategoryBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.cancel)),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.delete, style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteCategory(c.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.deleteFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = PlatformUi.isDesktop(context);
    final pad = PlatformUi.hPadding(context);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l.categories)),
      floatingActionButton: desktop ? null : FloatingActionButton.extended(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: Text(l.newItem)),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: _loading
            ? const LoadingView()
            : _error != null
                ? ErrorView(message: _error.toString(), onRetry: _load)
                : Column(children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad, vertical: 4),
                      child: DefaultTextStyle.merge(
                        style: theme.textTheme.labelLarge ?? const TextStyle(),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: false,
                          dividerHeight: 0,
                          indicatorSize: TabBarIndicatorSize.label,
                          tabs: [
                            Tab(text: l.all),
                            Tab(text: l.expense),
                            Tab(text: l.income),
                          ],
                        ),
                      ),
                    ),
                    if (desktop)
                      Padding(
                        padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
                        child: Row(children: [
                          Expanded(child: Text(l.categoriesShown(_filtered.length, _cats.length), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))),
                          OutlinedButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add, size: 18), label: Text(l.newCategory)),
                        ]),
                      ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(child: EmptyView(icon: Icons.category, title: switch (_filter) { 'expense' => l.noExpenseCategories, 'income' => l.noIncomeCategories, _ => l.noCategories }, subtitle: l.noCategoriesHint))
                          : desktop
                              ? _buildGrid(theme, pad)
                              : _buildList(theme),
                    ),
                  ]),
      ),
    );
  }

  Widget _buildGrid(ThemeData theme, double pad) {
    return GridView.builder(
      padding: EdgeInsets.all(pad),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 300, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.2),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final c = _filtered[i];
        final color = hex(c.color);
        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _edit(c),
            onSecondaryTapDown: (_) => _delete(c),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.15), child: Icon(Icons.tag, color: color, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(c.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(c.type == 'income' ? context.l10n.income : context.l10n.expense, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  ]),
                ),
                PopupMenuButton<String>(
                  tooltip: context.l10n.more,
                  onSelected: (v) {
                    if (v == 'edit') _edit(c);
                    if (v == 'delete') _delete(c);
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(ctx.l10n.edit), contentPadding: EdgeInsets.zero)),
                    PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.delete_outline, color: Colors.redAccent), title: Text(ctx.l10n.delete, style: const TextStyle(color: Colors.redAccent)), contentPadding: EdgeInsets.zero)),
                  ],
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(ThemeData theme) {
    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final c = _filtered[i];
        final color = hex(c.color);
        return Dismissible(
          key: ValueKey(c.id),
          direction: DismissDirection.endToStart,
          background: Container(color: Colors.red.shade400, alignment: AlignmentDirectional.centerEnd, padding: const EdgeInsetsDirectional.only(end: 20), child: const Icon(Icons.delete, color: Colors.white)),
          onDismissed: (_) => _delete(c),
          child: ListTile(
            onTap: () => _edit(c),
            leading: CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.2), child: Icon(Icons.tag, color: color)),
            title: Text(c.name),
            subtitle: Text(c.type == 'income' ? context.l10n.income : context.l10n.expense),
            trailing: Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
        );
      },
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final Category? existing;
  const _CategoryDialog({this.existing});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late String _type = widget.existing?.type ?? 'expense';
  late String _color = widget.existing?.color ?? _CategoriesScreenState._swatches[0];
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();
  // Errors show only after a save attempt, then update as the user types.
  var _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    final name = _nameCtrl.text.trim();
    setState(() => _saving = true);
    try {
      final repo = FinanceRepo();
      if (widget.existing == null) {
        await repo.insertCategory(name: name, type: _type, color: _color);
      } else {
        await repo.updateCategory(widget.existing!.id, name: name, type: _type, color: _color);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.existing == null ? l.newCategory : l.editCategory),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextFormField(
            controller: _nameCtrl,
            autofocus: widget.existing == null,
            decoration: InputDecoration(labelText: l.name),
            validator: (v) => (v ?? '').trim().isEmpty ? l.enterName : null,
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'expense', label: Text(l.expense)),
              ButtonSegment(value: 'income', label: Text(l.income)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          Text(l.color, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final sw in _CategoriesScreenState._swatches)
              GestureDetector(
                onTap: () => setState(() => _color = sw),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(int.parse(sw.substring(1), radix: 16) | 0xFF000000),
                    shape: BoxShape.circle,
                    border: Border.all(color: _color == sw ? theme.colorScheme.onSurface : Colors.transparent, width: 2.5),
                  ),
                  child: _color == sw ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                ),
              ),
          ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.save)),
      ],
    );
  }
}
