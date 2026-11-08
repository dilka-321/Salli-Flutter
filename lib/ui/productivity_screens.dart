import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currency.dart';
import '../core/loans.dart';
import '../core/plans.dart';
import '../core/round6.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'accounts_screen.dart';
import 'plans_common.dart';
import 'theme.dart';
import 'transfers_screen.dart';
import 'widgets.dart';

// ======================================================================= To-Do
class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});
  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  String tab = 'active';

  Future<void> _form(String? id) {
    final s = StoreScope.read(context);
    final t = id == null ? null : s.todos.where((x) => x['id'] == id).firstOrNull;
    final title = TextEditingController(text: '${t?['title'] ?? ''}');
    var tag = '${t?['tag'] ?? 'Personal'}';
    var due = '${t?['due'] ?? addDays(today(), 1)}';
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(t != null ? 'Edit task' : 'New task', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(controller: title, autofocus: true, decoration: const InputDecoration(hintText: 'What needs doing?')),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final x in kTodoTags) ChoiceChip(label: Text(x), selected: tag == x, onSelected: (_) => set(() => tag = x))]),
                const SizedBox(height: 12),
                DateButton(value: due, label: 'Due date', onChanged: (v) => set(() => due = v)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    if (title.text.trim().isEmpty) return toast(c, 'Enter a task');
                    s.saveTodo(id: id, title: title.text.trim(), tag: tag, due: due);
                    Navigator.pop(c);
                    toast(context, 'Task saved');
                  },
                  child: const Text('Save'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = s.todos.where((t) => tab == 'active' ? t['done'] != true : t['done'] == true).toList()..sort((a, b) => '${a['due']}'.compareTo('${b['due']}'));
    return Scaffold(
      appBar: AppBar(title: const Text('To-Do List')),
      floatingActionButton: FloatingActionButton(onPressed: () => _form(null), child: const Icon(Icons.add_rounded)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'active', label: Text('Active'), icon: Icon(Icons.check_box_outline_blank_rounded)), ButtonSegment(value: 'done', label: Text('Completed'), icon: Icon(Icons.check_rounded))],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        if (L.isEmpty) EmptyNote(tab == 'active' ? 'Nothing to do\nAdd financial to-dos like paying bills or renewing insurance' : 'No completed tasks yet', icon: Icons.check_box_outlined),
        for (final t in L)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(6, 8, 4, 8),
              child: Row(children: [
                Checkbox(
                  value: t['done'] == true,
                  activeColor: p.accent,
                  onChanged: (_) {
                    HapticFeedback.selectionClick();
                    s.toggleTodo('${t['id']}');
                    toast(context, s.todos.firstWhere((x) => x['id'] == t['id'])['done'] == true ? 'Marked complete' : 'Moved to active');
                  },
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${t['title']}', style: TextStyle(fontWeight: FontWeight.w700, decoration: t['done'] == true ? TextDecoration.lineThrough : null, color: t['done'] == true ? p.muted : null)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Badge2('${t['tag'] ?? 'Personal'}', color: p.pos),
                      const SizedBox(width: 8),
                      if ('${t['due'] ?? ''}'.isNotEmpty) Text(fmtDate('${t['due']}'), style: TextStyle(fontSize: 12, color: t['done'] != true && '${t['due']}'.compareTo(today()) < 0 ? p.neg : p.muted)),
                    ]),
                  ]),
                ),
                moreMenu([
                  ('Edit', Icons.edit_outlined, () => _form('${t['id']}'), false),
                  (
                    'Delete',
                    Icons.delete_outline,
                    () {
                      s.deleteTodo('${t['id']}');
                      toast(context, 'Task deleted');
                    },
                    true
                  ),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ======================================================================= Priority board
class PrioritiesScreen extends StatefulWidget {
  const PrioritiesScreen({super.key});
  @override
  State<PrioritiesScreen> createState() => _PrioritiesScreenState();
}

class _PrioritiesScreenState extends State<PrioritiesScreen> {
  String tab = 'pending';
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final L = s.priorities.where((x) => tab == 'pending' ? x['done'] != true : x['done'] == true).toList()..sort((a, b) => s.prScore(b).compareTo(s.prScore(a)));
    Color qc(String c) => c == 'red' ? p.neg : c == 'blue' ? const Color(0xFF5B8DEF) : c == 'orange' ? p.warn : p.muted;
    return Scaffold(
      appBar: AppBar(title: const Text('Priority Board')),
      floatingActionButton: FloatingActionButton(onPressed: () => Navigator.of(context).push(pageRoute(const PriorityEditScreen())), child: const Icon(Icons.add_rounded)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'pending', label: Text('Pending'), icon: Icon(Icons.assignment_outlined)), ButtonSegment(value: 'done', label: Text('Completed'), icon: Icon(Icons.check_rounded))],
          selected: {tab},
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        if (L.isEmpty) EmptyNote(tab == 'pending' ? 'No pending priorities' : 'No completed priorities', icon: Icons.assignment_outlined),
        for (final x in L)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Builder(builder: (_) {
              final q = s.prQuadrant(x);
              final cur = '${x['costCur'] ?? s.base}';
              return GlassCard(
                padding: const EdgeInsets.fromLTRB(6, 8, 4, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Checkbox(value: x['done'] == true, activeColor: p.accent, onChanged: (_) => s.togglePriority('${x['id']}')),
                    Expanded(child: Text('${x['title']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                    Badge2(q.$1, color: qc(q.$2)),
                    moreMenu([
                      ('Edit', Icons.edit_outlined, () => Navigator.of(context).push(pageRoute(PriorityEditScreen(existing: x))), false),
                      (
                        'Delete',
                        Icons.delete_outline,
                        () {
                          s.deletePriority('${x['id']}');
                          toast(context, 'Deleted');
                        },
                        true
                      ),
                    ]),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if ('${x['desc'] ?? ''}'.isNotEmpty) Text('${x['desc']}', style: TextStyle(color: p.muted, fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        Badge2('${x['category'] ?? 'Other'}', color: p.muted),
                        Badge2('Importance: ${x['importance']}', color: p.muted),
                        Badge2('Urgency: ${x['urgency']}', color: p.muted),
                        if (toD(x['cost']) > 0) Badge2(money(toD(x['cost']), cur), color: p.pos),
                      ]),
                      if ('${x['whyImportant'] ?? ''}'.isNotEmpty || '${x['whyUrgent'] ?? ''}'.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            [if ('${x['whyImportant'] ?? ''}'.isNotEmpty) 'Important: ${x['whyImportant']}', if ('${x['whyUrgent'] ?? ''}'.isNotEmpty) 'Urgent: ${x['whyUrgent']}'].join(' · '),
                            style: TextStyle(color: p.muted, fontSize: 12),
                          ),
                        ),
                    ]),
                  ),
                ]),
              );
            }),
          ),
      ]),
    );
  }
}

class PriorityEditScreen extends StatefulWidget {
  const PriorityEditScreen({super.key, this.existing});
  final J? existing;
  @override
  State<PriorityEditScreen> createState() => _PriorityEditScreenState();
}

class _PriorityEditScreenState extends State<PriorityEditScreen> {
  final c = <String, TextEditingController>{for (final k in ['title', 'desc', 'whyImportant', 'whyUrgent', 'cost']) k: TextEditingController()};
  String category = 'Other', importance = 'Medium', urgency = 'Medium';
  String? costCur;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      for (final k in ['title', 'desc', 'whyImportant', 'whyUrgent']) {
        c[k]!.text = '${e[k] ?? ''}';
      }
      c['cost']!.text = toD(e['cost']) > 0 ? plainNum(toD(e['cost'])) : '';
      category = '${e['category'] ?? 'Other'}';
      importance = '${e['importance'] ?? 'Medium'}';
      urgency = '${e['urgency'] ?? 'Medium'}';
      costCur = e['costCur']?.toString();
    }
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final cur = costCur ?? s.base;
    final cost = parseAmount(c['cost']!.text) ?? 0;
    Widget dd(String label, String v, List<String> opts, ValueChanged<String> on) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: opts.contains(v) ? v : opts.last,
            decoration: InputDecoration(labelText: label),
            items: [for (final o in opts) DropdownMenuItem(value: o, child: Text(o))],
            onChanged: (x) => setState(() => on(x ?? v)),
          ),
        );
    Widget area(String k, String hint) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c[k], maxLines: 3, minLines: 1, decoration: InputDecoration(hintText: hint)));
    return Scaffold(
      appBar: AppBar(title: Text('${widget.existing != null ? 'Edit' : 'Create'} Priority')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: FilledButton(
            onPressed: () {
              if (c['title']!.text.trim().isEmpty) return toast(context, 'Enter a title');
              s.savePriority({
                if (widget.existing != null) ...widget.existing!,
                'title': c['title']!.text.trim(),
                'desc': c['desc']!.text,
                'category': category,
                'importance': importance,
                'urgency': urgency,
                'whyImportant': c['whyImportant']!.text,
                'whyUrgent': c['whyUrgent']!.text,
                'cost': parseAmount(c['cost']!.text) ?? 0,
                'costCur': cur,
              });
              Navigator.pop(context);
              toast(context, 'Priority saved');
            },
            child: Text(widget.existing != null ? 'Save' : 'Create'),
          ),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c['title'], decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.flag_outlined)))),
        area('desc', 'What is this?'),
        dd('Category', category, kPrCategories, (x) => category = x),
        dd('Importance', importance, kLevels.keys.toList(), (x) => importance = x),
        area('whyImportant', 'Why is it important?'),
        dd('Urgency', urgency, kLevels.keys.toList(), (x) => urgency = x),
        area('whyUrgent', 'Why is it urgent?'),
        Row(children: [
          ActionChip(
            label: Text('${currencySymbol(cur)} $cur ▾'),
            onPressed: () async {
              final x = await pickCurrency(context, cur);
              if (x != null) setState(() => costCur = x);
            },
          ),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: c['cost'], keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Estimated Cost'))),
        ]),
        if (cur != s.base && cost > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('≈ ${moneyB(s, s.conv(cost, cur, s.base))}', style: TextStyle(color: p.pos, fontSize: 12.5))),
      ]),
    );
  }
}

// ======================================================================= Tags
Future<void> showTagDialog(BuildContext context, String? id) {
  final s = StoreScope.read(context);
  final t = id == null ? null : s.tags.where((x) => x['id'] == id).firstOrNull;
  final ctl = TextEditingController(text: '${t?['name'] ?? ''}');
  String? err;
  return showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text(t != null ? 'Edit tag' : 'Add tag'),
        content: TextField(controller: ctl, autofocus: true, decoration: InputDecoration(labelText: 'Tag name', hintText: 'Enter tag name', errorText: err)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final e = s.saveTag(id, ctl.text);
              if (e != null) return set(() => err = e);
              Navigator.pop(c);
              toast(context, 'Tag saved');
            },
            child: Text(t != null ? 'Save' : 'Add'),
          ),
        ],
      ),
    ),
  );
}

class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      floatingActionButton: FloatingActionButton(onPressed: () => showTagDialog(context, null), child: const Icon(Icons.add_rounded)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        if (s.tags.isEmpty) const EmptyNote('No tags yet\nTags help you group transactions like "Essential" or "One-time"', icon: Icons.sell_outlined),
        for (final t in s.tags)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
              child: Row(children: [
                Icon(Icons.sell_outlined, color: p.pos),
                const SizedBox(width: 12),
                Expanded(child: Text('${t['name']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                IconButton(onPressed: () => showTagDialog(context, '${t['id']}'), icon: const Icon(Icons.edit_outlined)),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: p.neg),
                  onPressed: () async {
                    if (await confirmDialog(context, 'Delete tag?', '"${t['name']}" will be removed from all transactions.')) {
                      s.deleteTag('${t['id']}');
                      if (context.mounted) toast(context, 'Tag deleted');
                    }
                  },
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ======================================================================= Account setup (asset / liability groups)
class AccountSetupScreen extends StatelessWidget {
  const AccountSetupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    Widget sec(String kind, String title) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 6), child: Text(title, style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.4))),
          for (final t in s.assetTypes.where((t) => t['kind'] == kind))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                onTap: () => Navigator.of(context).push(pageRoute(GroupEditScreen(existing: t))),
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(children: [
                  EmojiTile('${t['icon'] ?? '💼'}', tint: p.pos, size: 42),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${t['name']}', style: const TextStyle(fontWeight: FontWeight.w700)), Text('${t['group'] ?? ''}', style: TextStyle(color: p.muted, fontSize: 12))])),
                  Icon(Icons.chevron_right_rounded, color: p.muted),
                ]),
              ),
            ),
        ]);
    return Scaffold(
      appBar: AppBar(title: const Text('Account Setup'), actions: [
        IconButton(tooltip: 'My accounts', icon: const Icon(Icons.account_balance_rounded), onPressed: () => Navigator.of(context).push(pageRoute(const AccountsScreen()))),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: () => Navigator.of(context).push(pageRoute(const GroupEditScreen())), child: const Icon(Icons.add_rounded)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [sec('asset', 'ASSETS'), sec('liability', 'LIABILITIES')]),
    );
  }
}

class GroupEditScreen extends StatefulWidget {
  const GroupEditScreen({super.key, this.existing});
  final J? existing;
  @override
  State<GroupEditScreen> createState() => _GroupEditScreenState();
}

class _GroupEditScreenState extends State<GroupEditScreen> {
  final name = TextEditingController();
  String kind = 'asset', group = 'Cash';

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    if (t != null) {
      name.text = '${t['name'] ?? ''}';
      kind = '${t['kind'] ?? 'asset'}';
      group = '${t['group'] ?? 'Cash'}';
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _save() {
    if (name.text.trim().isEmpty) return toast(context, 'Enter a name');
    StoreScope.read(context).saveGroup(id: widget.existing?['id']?.toString(), name: name.text.trim(), kind: kind, group: group);
    Navigator.pop(context);
    toast(context, 'Account group saved');
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    final opts = kind == 'asset' ? kAssetGroups : kLiabGroups;
    if (!opts.contains(group)) group = opts.first;
    final t = widget.existing;
    return Scaffold(
      appBar: AppBar(title: Text(t != null ? 'Edit Account Group' : 'New Account Group'), actions: [IconButton(onPressed: _save, icon: Icon(Icons.check_rounded, color: p.pos))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Cash')),
        const SectionTitle('Group'),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'asset', label: Text('Assets')), ButtonSegment(value: 'liability', label: Text('Liabilities'))],
          selected: {kind},
          onSelectionChanged: (v) => setState(() => kind = v.first),
        ),
        const SectionTitle('This group belongs to which type?'),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: RadioGroup<String>(
            groupValue: group,
            onChanged: (v) => setState(() => group = v ?? group),
            child: Column(children: [for (final o in opts) RadioListTile<String>(value: o, title: Text(o))]),
          ),
        ),
        if (t != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: TextButton.icon(
              icon: Icon(Icons.delete_outline, color: p.neg),
              label: Text('Delete group', style: TextStyle(color: p.neg)),
              onPressed: () async {
                if (s.assets.any((a) => a['typeId'] == t['id'])) return toast(context, 'Move or delete the assets in this group first');
                if (await confirmDialog(context, 'Delete group?', 'This cannot be undone.')) {
                  s.deleteGroup('${t['id']}');
                  if (context.mounted) {
                    Navigator.pop(context);
                    toast(context, 'Deleted');
                  }
                }
              },
            ),
          ),
      ]),
    );
  }
}

// ======================================================================= Customize dashboard
class DashboardSetupScreen extends StatefulWidget {
  const DashboardSetupScreen({super.key});
  @override
  State<DashboardSetupScreen> createState() => _DashboardSetupScreenState();
}

class _DashboardSetupScreenState extends State<DashboardSetupScreen> {
  List<String>? order;
  List<String> hidden = [];

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = Palette.of(context);
    if (order == null) {
      order = s.widgetOrder;
      hidden = s.hiddenWidgets;
    }
    final o = order!;
    return Scaffold(
      appBar: AppBar(title: const Text('Customize Dashboard')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: FilledButton(
            onPressed: () {
              s.saveDashboard(o, hidden);
              Navigator.pop(context);
              toast(context, 'Dashboard layout saved');
            },
            child: const Text('Save Layout'),
          ),
        ),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), child: Text("Drag and drop widgets to arrange them. Switch off any you don't need.", style: TextStyle(color: p.muted))),
        Expanded(
          child: ReorderableListView(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
            onReorder: (a, b) => setState(() {
              if (b > a) b--;
              o.insert(b, o.removeAt(a));
            }),
            children: [
              for (var i = 0; i < o.length; i++)
                Padding(
                  key: ValueKey(o[i]),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                    child: Row(children: [
                      Expanded(child: Text(kWidgetNames[o[i]] ?? o[i], style: TextStyle(color: hidden.contains(o[i]) ? p.muted : null, fontWeight: FontWeight.w600))),
                      Switch(
                        value: !hidden.contains(o[i]),
                        onChanged: (v) => setState(() {
                          if (v) {
                            hidden.remove(o[i]);
                          } else {
                            hidden.add(o[i]);
                          }
                        }),
                      ),
                      ReorderableDragStartListener(index: i, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.drag_indicator_rounded, color: p.muted))),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}
