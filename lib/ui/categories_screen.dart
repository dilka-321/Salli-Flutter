import 'package:flutter/material.dart';

import '../core/ops.dart';
import '../core/store.dart';
import 'theme.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String kind = 'expense';
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final k = q.toLowerCase();
    final mains = s.categories.where((c) {
      if (c['kind'] != kind || (c['parent'] != null && '${c['parent']}'.isNotEmpty)) return false;
      if (k.isEmpty) return true;
      return '${c['name']}'.toLowerCase().contains(k) || s.categories.any((x) => x['parent'] == c['id'] && '${x['name']}'.toLowerCase().contains(k));
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: p.accent,
        foregroundColor: p.accentInk,
        shape: const CircleBorder(),
        onPressed: () => showCategorySheet(context, kind: kind),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'income', label: Text('Income')), ButtonSegment(value: 'expense', label: Text('Expense'))],
          selected: {kind},
          onSelectionChanged: (v) => setState(() => kind = v.first),
        ),
        const SizedBox(height: 12),
        TextField(decoration: InputDecoration(prefixIcon: Icon(Icons.search, color: p.muted), hintText: 'Search categories'), onChanged: (v) => setState(() => q = v.trim())),
        const SizedBox(height: 12),
        if (mains.isEmpty) const EmptyNote('No categories here yet. Tap + to add one.'),
        for (final c in mains) ...[
          _CatCard(c: c),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}

class _CatCard extends StatelessWidget {
  const _CatCard({required this.c});
  final J c;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final subs = s.categories.where((x) => x['parent'] == c['id']).toList();
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${c['icon'] ?? '📦'}', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              if (subs.isNotEmpty) Text('${subs.length} subcategor${subs.length > 1 ? 'ies' : 'y'}', style: TextStyle(color: p.pos, fontSize: 12.5)),
            ]),
          ),
          IconButton(icon: Icon(Icons.add_circle_outline, color: p.muted), tooltip: 'Add subcategory', onPressed: () => showCategorySheet(context, kind: '${c['kind']}', parent: '${c['id']}')),
          IconButton(icon: Icon(Icons.edit_outlined, color: p.accent), onPressed: () => showCategorySheet(context, kind: '${c['kind']}', existing: c)),
          IconButton(icon: Icon(Icons.delete_outline, color: p.neg), onPressed: () => _delete(context, c)),
        ]),
        if (subs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final x in subs)
                InputChip(
                  label: Text('${x['icon'] ?? ''} ${x['name']}'),
                  onPressed: () => showCategorySheet(context, kind: '${x['kind']}', existing: x),
                  onDeleted: () => _delete(context, x),
                  deleteIcon: Icon(Icons.close_rounded, size: 16, color: p.neg),
                ),
            ]),
          ),
      ]),
    );
  }
}

Future<void> _delete(BuildContext context, J c) async {
  final s = StoreScope.read(context);
  final n = s.catUseCount('${c['id']}');
  final isSub = c['parent'] != null && '${c['parent']}'.isNotEmpty;
  final ok = await confirmDialog(
    context,
    isSub ? 'Delete subcategory?' : 'Delete category?',
    '"${c['name']}"${n > 0 ? ' is used by $n transaction${n > 1 ? 's' : ''}; they will show without a category' : ''}.${isSub ? '' : ' Subcategories become main categories.'}',
  );
  if (ok) {
    s.deleteCategory('${c['id']}');
    if (context.mounted) toast(context, 'Category deleted');
  }
}

/// Add / edit a category: name, main category (optional), icon.
void showCategorySheet(BuildContext context, {required String kind, J? existing, String? parent}) {
  final s = StoreScope.read(context);
  final name = TextEditingController(text: existing?['name']?.toString() ?? '');
  String icon = (existing?['icon'] ?? '📦').toString();
  String? par = existing != null ? existing['parent']?.toString() : parent;
  String? err;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sh) => StatefulBuilder(builder: (sh, set) {
      final p = Palette.of(sh);
      final mains = s.categories.where((x) => x['kind'] == kind && (x['parent'] == null || '${x['parent']}'.isEmpty) && x['id'] != existing?['id']).toList();
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(sh).viewInsets.bottom + 20),
        child: SizedBox(
          height: MediaQuery.of(sh).size.height * .78,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(existing != null ? 'Edit Category' : 'Add ${kind == 'income' ? 'Income' : 'Expense'} Category', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: name, decoration: InputDecoration(labelText: 'Category name', prefixText: '$icon  ')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: (par != null && mains.any((m) => m['id'] == par)) ? par : '',
              decoration: const InputDecoration(labelText: 'Main category (optional)'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Create as main category')),
                for (final m in mains) DropdownMenuItem(value: '${m['id']}', child: Text('${m['icon'] ?? ''} ${m['name']}')),
              ],
              onChanged: (v) => set(() => par = (v == null || v.isEmpty) ? null : v),
            ),
            const SizedBox(height: 12),
            Text('Icon', style: TextStyle(color: p.muted)),
            const SizedBox(height: 6),
            Expanded(
              child: GridView.count(
                crossAxisCount: 8,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (final i in kCategoryIcons)
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => set(() => icon = i),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: icon == i ? p.accent.withOpacity(.22) : p.card2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: icon == i ? p.accent : Colors.transparent),
                        ),
                        child: Text(i, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                ],
              ),
            ),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: TextStyle(color: p.neg))),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final r = s.saveCategory(id: existing?['id']?.toString(), kind: kind, name: name.text, icon: icon, parent: par);
                if (r != null) return set(() => err = r);
                Navigator.pop(sh);
                toast(context, existing != null ? 'Category updated' : 'Category created');
              },
              child: Text(existing != null ? 'Save' : 'Create'),
            ),
          ]),
        ),
      );
    }),
  );
}
