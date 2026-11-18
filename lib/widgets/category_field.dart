import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';

/// An entry's or recurring item's category. The menu lists [type]'s
/// top-level categories only, so it stays short; once one with
/// subcategories is picked, they slide in under it as chips, "All (parent)"
/// first, to file it more exactly. [value] may be either.
class CategoryField extends StatelessWidget {
  const CategoryField({super.key, required this.cats, required this.type, required this.value, required this.onChanged});
  final List<Category> cats;
  final String type;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final byId = {for (final c in cats) c.id: c};
    final picked = byId[value];
    // The menu shows a subcategory's parent; the chips say which one.
    final parent = byId[picked?.parentId] ?? picked;
    final tops = [for (final c in cats) if (c.type == type && !byId.containsKey(c.parentId)) c];
    final subs = [for (final c in cats) if (parent != null && c.parentId == parent.id) c];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DropdownButtonFormField<int>(
        // Categories load async; only select once the item exists. Rebuilt
        // when the type flips too, so a cleared selection shows as cleared.
        key: ValueKey('${cats.length}-$type'),
        initialValue: tops.any((c) => c.id == parent?.id) ? parent!.id : null,
        decoration: InputDecoration(labelText: l.categoryOptional),
        items: [for (final c in tops) DropdownMenuItem(value: c.id, child: Text(c.name))],
        onChanged: onChanged,
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: AlignmentDirectional.topStart,
        child: subs.isEmpty
            ? const SizedBox(width: double.infinity)
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  for (final (i, c) in [parent!, ...subs].indexed)
                    Padding(
                      padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 8),
                      child: ChoiceChip(
                        label: Text(i == 0 ? l.allOfCategory(c.name) : c.name),
                        selected: value == c.id,
                        onSelected: (_) => onChanged(c.id),
                      ),
                    ),
                ]),
              ),
      ),
    ]);
  }
}
