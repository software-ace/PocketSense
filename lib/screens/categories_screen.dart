import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../models/models.dart';
import '../utils/platform.dart';
import '../widgets/state_views.dart';
import '../widgets/sync_indicator.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with SingleTickerProviderStateMixin, SyncAware {
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
        title: Text('Delete "${c.name}"?'),
        content: const Text('Transactions tagged with this category will become uncategorized. Budgets for it will be removed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteCategory(c.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = PlatformUi.isDesktop(context);
    final pad = PlatformUi.hPadding(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories'), actions: const [SyncIndicator()]),
      floatingActionButton: desktop ? null : FloatingActionButton.extended(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('New')),
      body: RefreshIndicator(
        onRefresh: () => syncAndReload(_load),
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
                          tabs: const [
                            Tab(text: 'All'),
                            Tab(text: 'Expense'),
                            Tab(text: 'Income'),
                          ],
                        ),
                      ),
                    ),
                    if (desktop)
                      Padding(
                        padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
                        child: Row(children: [
                          Expanded(child: Text('${_filtered.length} of ${_cats.length} categories', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))),
                          OutlinedButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add, size: 18), label: const Text('New category')),
                        ]),
                      ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(child: EmptyView(icon: Icons.category, title: _filter == 'all' ? 'No categories' : 'No $_filter categories', subtitle: 'Create one to start tagging transactions.'))
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
                    Text(c.type == 'income' ? 'Income' : 'Expense', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  ]),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (v) {
                    if (v == 'edit') _edit(c);
                    if (v == 'delete') _delete(c);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'), contentPadding: EdgeInsets.zero)),
                    PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.redAccent), title: Text('Delete', style: TextStyle(color: Colors.redAccent)), contentPadding: EdgeInsets.zero)),
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
          background: Container(color: Colors.red.shade400, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
          onDismissed: (_) => _delete(c),
          child: ListTile(
            onTap: () => _edit(c),
            leading: CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.2), child: Icon(Icons.tag, color: color)),
            title: Text(c.name),
            subtitle: Text(c.type == 'income' ? 'Income' : 'Expense'),
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _saving) return;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? 'New category' : 'Edit category'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _nameCtrl, autofocus: widget.existing == null, decoration: const InputDecoration(labelText: 'Name'), onSubmitted: (_) => _save()),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('Expense')),
              ButtonSegment(value: 'income', label: Text('Income')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          Text('Color', style: theme.textTheme.labelLarge),
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
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
      ],
    );
  }
}
