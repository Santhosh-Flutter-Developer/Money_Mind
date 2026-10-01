import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/entities.dart';
import '../../domain/services/budget_logic.dart';
import '../../domain/usecases/usecases.dart';
import '../controllers/auth_controller.dart';
import '../controllers/budget_controller.dart';
import '../widgets/common.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});
  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final c = Get.find<BudgetController>();

  @override
  void initState() {
    super.initState();
    c.period.value = null; // always open on the current cycle
    c.load();
  }

  String m(Decimal d) => MoneyUtils.format(d, currency: c.currency);

  Future<void> _editItem(BudgetItem? item) async {
    await Get.toNamed(item == null ? AppRoutes.expenseAdd : AppRoutes.expenseEdit, arguments: item);
    c.load(target: c.period.value);
  }

  Future<void> _delete(BudgetItem i) async {
    if (i.isCompleted) {
      Get.snackbar('Completed expense', 'Undo the completion first, then delete.');
      return;
    }
    if (await confirmDialog('Delete ${i.name}?', 'This removes it from this cycle.', confirm: 'Delete', danger: true)) c.deleteItem(i);
  }

  Future<void> _addIncome() async {
    final amount = TextEditingController();
    final desc = TextEditingController();
    final key = GlobalKey<FormState>();
    DateTime date = Fmt.today();
    final ok = await Get.dialog<bool>(StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Add income'),
        content: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AmountField(controller: amount, currency: c.currency),
              AppTextField(controller: desc, label: 'Description (e.g. Bonus)'),
              DateField(label: 'Date', value: date, onChanged: (d) => set(() => date = d)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(onPressed: () { if (key.currentState!.validate()) Get.back(result: true); }, child: const Text('Add')),
        ],
      ),
    ));
    if (ok == true) await c.addIncome(MoneyUtils.tryParse(amount.text)!, date, desc.text);
  }

  Future<void> _salary() async {
    final b = c.budget.value;
    if (b == null) return;
    final amount = TextEditingController(text: b.salary.toString());
    final key = GlobalKey<FormState>();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text('${b.period.label} salary'),
      content: Form(key: key, child: AmountField(controller: amount, label: 'Salary for this cycle', currency: c.currency, allowZero: true)),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
        TextButton(onPressed: () => Get.toNamed(AppRoutes.salarySettings), child: const Text('Salary day…')),
        TextButton(onPressed: () { if (key.currentState!.validate()) Get.back(result: true); }, child: const Text('Save')),
      ],
    ));
    if (ok == true) await c.updateSalary(MoneyUtils.tryParse(amount.text)!);
  }

  Future<void> _close() async {
    final p = c.closePreview;
    final b = c.budget.value;
    if (p == null || b == null) return;
    Widget row(String l, Decimal v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [Expanded(child: Text(l)), Text(m(v), style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500))]),
        );
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text('Close ${b.period.label}?'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        row('Income', p.salary + p.extraIncome),
        row('Completed expenses', p.completed),
        row('Remaining', p.remaining, bold: true),
        const Divider(),
        row('Moved to savings', p.transfer, bold: true),
        if (p.pendingAmount > Decimal.zero)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('${m(p.pendingAmount)} of pending expenses are not deducted. Complete them first if they were paid.', style: const TextStyle(color: AppColors.warning, fontSize: 13)),
          ),
        const Padding(padding: EdgeInsets.only(top: 10), child: Text('A closed cycle cannot be closed again or edited.', style: TextStyle(fontSize: 12))),
      ]),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
        TextButton(onPressed: () => Get.back(result: true), child: const Text('Close cycle', style: TextStyle(fontWeight: FontWeight.w800))),
      ],
    ));
    if (ok == true) await c.closeCycle();
  }

  Future<void> _history() async {
    final list = await c.history();
    Get.bottomSheet(
      Container(
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Budget history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          Flexible(
            child: list.isEmpty
                ? const Padding(padding: EdgeInsets.all(24), child: Text('No cycles yet.'))
                : ListView(shrinkWrap: true, children: [
                    for (final b in list.reversed)
                      ListTile(
                        title: Text(b.period.label),
                        subtitle: Text('Spent ${m(b.spent)} of ${m(b.totalIncome)}'),
                        trailing: b.closed ? const StatusChip('Closed', AppColors.transfer) : const StatusChip('Open', AppColors.income),
                        onTap: () {
                          Get.back();
                          Get.toNamed(AppRoutes.budgetOf(b.id));
                        },
                      ),
                  ]),
          ),
        ]),
      ),
      isScrollControlled: true,
    );
  }

  Widget _summary() {
    final s = c.summary!;
    final b = c.budget.value!;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _kv('Salary', m(b.salary))),
          Expanded(child: _kv('Extra income', m(b.extraIncome))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _kv('Planned', m(s.planned))),
          Expanded(child: _kv('Spent', m(s.spent), color: AppColors.expense)),
          Expanded(child: _kv('Pending', m(s.pending), color: AppColors.warning)),
        ]),
        const SizedBox(height: 14),
        LinearProgressIndicator(value: s.progress, minHeight: 8, borderRadius: BorderRadius.circular(8)),
        const SizedBox(height: 10),
        Row(children: [
          const Expanded(child: Text('Remaining', style: TextStyle(fontWeight: FontWeight.w600))),
          Text(m(s.remaining), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: s.remaining < Decimal.zero ? AppColors.expense : AppColors.income)),
        ]),
        if (b.closed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Icon(Icons.lock_outline, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text('Closed · ${m(b.savingsTransferred)} moved to savings')),
            ]),
          ),
      ]),
    );
  }

  Widget _kv(String k, String v, {Color? color}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(fontSize: 12)),
        FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color))),
      ]);

  @override
  Widget build(BuildContext context) => AdaptiveShell(
        route: AppRoutes.budget,
        child: Scaffold(
          appBar: AppBar(title: const Text('Budget'), actions: [
            IconButton(icon: const Icon(Icons.payments_outlined), tooltip: 'Salary', onPressed: _salary),
            IconButton(icon: const Icon(Icons.history), tooltip: 'History', onPressed: _history),
          ]),
          floatingActionButton: Obx(() {
            final b = c.budget.value;
            if (b == null || b.closed) return const SizedBox();
            return FloatingActionButton.extended(onPressed: () => _editItem(null), icon: const Icon(Icons.add), label: const Text('Expense'));
          }),
          body: Obx(() => LoadState(
                loading: c.loading.value,
                error: c.error.value,
                hasData: c.budget.value != null,
                onRetry: () => c.load(target: c.period.value),
                child: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
                  PageBody(
                    maxWidth: 900,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      MonthSwitcher(
                        title: c.period.value?.label ?? '',
                        subtitle: c.period.value?.rangeLabel ?? '',
                        onPrev: c.previous,
                        onNext: c.next,
                      ),
                      if (c.budget.value == null) ...[
                        const SizedBox(height: 60),
                        EmptyState(
                          icon: Icons.event_busy_outlined,
                          title: c.canCreate.value ? 'No budget for this cycle' : 'This cycle has not started',
                          subtitle: c.canCreate.value ? 'Create it to add expenses and track this period.' : 'You can plan it once it begins.',
                          actionLabel: c.canCreate.value ? 'Create budget' : null,
                          onAction: c.createForPeriod,
                        ),
                      ] else ...[
                        _summary(),
                        Row(children: [
                          for (final f in const ['all', 'pending', 'completed'])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(label: Text(f[0].toUpperCase() + f.substring(1)), selected: c.filter.value == f, onSelected: (_) => c.filter.value = f),
                            ),
                          const Spacer(),
                          if (!c.budget.value!.closed) TextButton.icon(onPressed: _addIncome, icon: const Icon(Icons.add), label: const Text('Income')),
                        ]),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: TextField(
                            onChanged: (v) => c.search.value = v,
                            decoration: InputDecoration(hintText: 'Search expenses', prefixIcon: const Icon(Icons.search), filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                          ),
                        ),
                        if (c.visible.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: EmptyState(icon: Icons.receipt_long_outlined, title: 'No expenses to show', subtitle: 'Add one with the + button.')),
                        for (final i in c.visible)
                          BudgetItemTile(
                            item: i,
                            currency: c.currency,
                            locked: c.budget.value!.closed,
                            busy: c.busyIds.contains(i.id),
                            onToggle: () => i.isCompleted ? c.undo(i) : c.complete(i),
                            onEdit: () => _editItem(i),
                            onDelete: () => _delete(i),
                          ),
                        const SizedBox(height: 8),
                        if (!c.budget.value!.closed)
                          OutlinedButton.icon(onPressed: c.saving.value ? null : _close, icon: const Icon(Icons.lock_clock_outlined), label: const Text('Close this cycle')),
                      ],
                    ]),
                  ),
                ]),
              )),
        ),
      );
}

/// Read-only view of any (usually past) cycle from the history list.
class BudgetDetailPage extends StatelessWidget {
  const BudgetDetailPage({super.key});
  @override
  Widget build(BuildContext context) {
    final id = Get.parameters['id']!;
    final uc = Get.find<BudgetUseCases>();
    final cur = Get.find<AuthController>().currency;
    return FormScaffold(
      title: 'Cycle details',
      maxWidth: 800,
      child: FutureBuilder<List<Object?>>(
        future: Future.wait([uc.budgetById(id), uc.items(id)]),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 300, child: SkeletonList(count: 4));
          if (snap.hasError || snap.data![0] == null) return const EmptyState(icon: Icons.error_outline, title: 'Could not load this cycle');
          final b = snap.data![0] as MonthlyBudget;
          final items = snap.data![1] as List<BudgetItem>;
          final s = BudgetCalculator.summarize(salary: b.salary, extraIncome: b.extraIncome, items: items);
          String m(Decimal d) => MoneyUtils.format(d, currency: cur);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(b.period.label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                  b.closed ? const StatusChip('Closed', AppColors.transfer) : const StatusChip('Open', AppColors.income),
                ]),
                Text(b.period.rangeLabel),
                const SizedBox(height: 12),
                Text('Income ${m(s.totalIncome)}  ·  Spent ${m(s.spent)}  ·  Pending ${m(s.pending)}'),
                const SizedBox(height: 6),
                Text('Remaining ${m(s.remaining)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                if (b.closed) Text('Moved to savings: ${m(b.savingsTransferred)}'),
              ]),
            ),
            for (final i in items)
              BudgetItemTile(item: i, currency: cur, locked: true, busy: false, onToggle: () {}, onEdit: () {}, onDelete: () {}),
          ]);
        },
      ),
    );
  }
}

class ExpenseFormPage extends StatefulWidget {
  const ExpenseFormPage({super.key});
  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final c = Get.find<BudgetController>();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  String? _categoryId;
  DateTime _date = Fmt.today();
  BudgetItem? _existing;
  bool _ready = true;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is BudgetItem) {
      _existing = args;
      _name.text = args.name;
      _amount.text = args.amount.toString();
      _notes.text = args.notes ?? '';
      _categoryId = args.categoryId;
      _date = args.dueDate ?? _date;
    } else if (args is Map && args['useCurrent'] == true) {
      _ready = false;
      c.load(target: c.current).then((_) {
        if (mounted) setState(() => _ready = true);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await c.saveItem(
      existing: _existing,
      name: _name.text,
      amount: MoneyUtils.tryParse(_amount.text)!,
      categoryId: _categoryId,
      date: _date,
      notes: _notes.text,
    );
    if (ok) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final locked = _existing?.isCompleted ?? false;
    return FormScaffold(
      title: _existing == null ? 'Add expense' : 'Edit expense',
      child: !_ready
          ? const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
          : Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 8),
                if (locked)
                  const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('This expense is completed. Undo it from the Budget list to change the amount.', style: TextStyle(color: AppColors.warning))),
                AppTextField(controller: _name, label: 'Name', validator: (v) => Validators.required(v, 'Name')),
                IgnorePointer(ignoring: locked, child: AmountField(controller: _amount, currency: c.currency)),
                Obx(() => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DropdownButtonFormField<String?>(
                        value: c.categories.any((x) => x.id == _categoryId) ? _categoryId : null,
                        decoration: InputDecoration(labelText: 'Category', filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('No category')),
                          for (final x in c.categories) DropdownMenuItem<String?>(value: x.id, child: Text(x.name)),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    )),
                DateField(
                  label: 'Due date',
                  value: _date,
                  first: c.period.value?.start,
                  last: c.period.value?.end,
                  onChanged: (d) => setState(() => _date = d),
                ),
                AppTextField(controller: _notes, label: 'Notes (optional)', maxLines: 2),
                Obx(() => PrimaryButton(label: 'Save', loading: c.saving.value, onPressed: _save)),
                const SizedBox(height: 24),
              ]),
            ),
    );
  }
}
