import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../utils/platform.dart';
import '../widgets/state_views.dart';
import '../widgets/swipe_delete_background.dart';
import '../widgets/data_aware.dart';
import '../utils/format.dart';
import 'csv_actions.dart';

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

  // Each parent followed by its subcategories (always of its type).
  List<Category> get _filtered => Category.tree(_filter == 'all' ? _cats : _cats.where((c) => c.type == _filter).toList());

  String? _parentName(Category c) => _cats.where((p) => p.id == c.parentId).firstOrNull?.name;

  /// What a list shows under a category's name: its parent for a
  /// subcategory, its type for the rest.
  String _subtitle(Category c) {
    final parent = _parentName(c);
    if (parent != null) return context.l10n.subcategoryOf(parent);
    return c.type == 'income' ? context.l10n.income : context.l10n.expense;
  }

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

  Future<void> _edit(Category? existing) async {
    await showDialog<bool>(context: context, builder: (_) => _CategoryDialog(existing: existing, cats: _cats));
  }

  Future<bool> _confirmDelete(Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteNamedTitle(c.name)),
        content: Text(switch (_parentName(c)) {
          final String parent => ctx.l10n.deleteSubcategoryBody(parent),
          null when _cats.any((s) => s.parentId == c.id) => ctx.l10n.deleteParentCategoryBody,
          null => ctx.l10n.deleteCategoryBody,
        }),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.cancel)),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.delete, style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    return ok == true;
  }

  /// [confirmed]: a swipe already asked (in confirmDismiss).
  Future<void> _delete(Category c, {bool confirmed = false}) async {
    if (!confirmed && !await _confirmDelete(c)) return;
    try {
      await _repo.deleteCategory(c.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.deleteFailed('$e'))));
      await _load(); // brings back a row a swipe took away
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = PlatformUi.isDesktop(context);
    final pad = PlatformUi.hPadding(context);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l.categories), actions: [const CsvMenu(kind: CsvKind.categories)]),
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
        final color = parseHex(c.color) ?? Theme.of(context).colorScheme.primary;
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
                    Text(_subtitle(c), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline), overflow: TextOverflow.ellipsis),
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
                    PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error), title: Text(ctx.l10n.delete, style: TextStyle(color: Theme.of(ctx).colorScheme.error)), contentPadding: EdgeInsets.zero)),
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
        final color = parseHex(c.color) ?? Theme.of(context).colorScheme.primary;
        return Dismissible(
          key: ValueKey(c.id),
          direction: DismissDirection.endToStart,
          background: const SwipeDeleteBackground(),
          // Asked before the row leaves: Cancel keeps it in place.
          confirmDismiss: (_) => _confirmDelete(c),
          onDismissed: (_) {
            setState(() => _cats.remove(c));
            _delete(c, confirmed: true);
          },
          child: ListTile(
            onTap: () => _edit(c),
            // A subcategory sits in under its parent.
            contentPadding: EdgeInsetsDirectional.only(start: c.parentId != null && _parentName(c) != null ? 40 : 16, end: 24),
            leading: CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.2), child: Icon(Icons.tag, color: color)),
            title: Text(c.name),
            subtitle: Text(_subtitle(c)),
            trailing: Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
        );
      },
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final Category? existing;
  final List<Category> cats;
  const _CategoryDialog({this.existing, required this.cats});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late String _type = widget.existing?.type ?? 'expense';
  late String _color = widget.existing?.color ?? _CategoriesScreenState._swatches[0];
  late int? _parentId = widget.existing?.parentId;
  // A new subcategory starts in its parent's colour, until one is tapped.
  late bool _colorPicked = widget.existing != null;
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
        await repo.insertCategory(name: name, type: _type, color: _color, parentId: _parentId);
      } else {
        await repo.updateCategory(widget.existing!.id, name: name, type: _type, color: _color, parentId: _parentId);
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
    final id = widget.existing?.id;
    // Two levels only: a parent is top-level and not this one, and one with
    // subcategories can't become one.
    final parents = [for (final c in widget.cats) if (c.parentId == null && c.id != id) c];
    final hasSubs = id != null && widget.cats.any((c) => c.parentId == id);
    final parent = parents.where((c) => c.id == _parentId).firstOrNull;
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
          DropdownButtonFormField<int?>(
            initialValue: parent?.id,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.parentCategoryOptional, helperText: hasSubs ? l.hasSubcategoriesHint : null, helperMaxLines: 2),
            items: [
              DropdownMenuItem(value: null, child: Text(l.noParentCategory, overflow: TextOverflow.ellipsis)),
              for (final c in parents) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: hasSubs
                ? null
                : (v) => setState(() {
                      _parentId = v;
                      final p = parents.where((c) => c.id == v).firstOrNull;
                      if (p != null && !_colorPicked) _color = p.color;
                    }),
          ),
          const SizedBox(height: 16),
          // A subcategory is its parent's type.
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'expense', label: Text(l.expense)),
              ButtonSegment(value: 'income', label: Text(l.income)),
            ],
            selected: {parent?.type ?? _type},
            onSelectionChanged: parent != null ? null : (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          Text(l.color, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final sw in _CategoriesScreenState._swatches)
              GestureDetector(
                onTap: () => setState(() {
                  _color = sw;
                  _colorPicked = true;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: parseHex(sw),
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
