import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/entities.dart';
import '../controllers/auth_controller.dart';
import '../controllers/savings_controller.dart';
import '../widgets/common.dart';

class SavingsPage extends StatefulWidget {
  const SavingsPage({super.key});
  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  final c = Get.find<SavingsController>();
  final auth = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    c.load();
  }

  String m(Decimal d) => MoneyUtils.format(d, currency: c.currency);

  Future<void> _open(String r) async {
    await Get.toNamed(r);
    c.load();
  }

  Future<void> _goal() async {
    final p = auth.profile.value;
    final amount = TextEditingController(text: p?.savingsGoal?.toString() ?? '');
    DateTime? date = p?.savingsGoalDate;
    final key = GlobalKey<FormState>();
    final ok = await Get.dialog<bool>(StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Savings goal'),
        content: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AmountField(controller: amount, label: 'Goal amount', currency: c.currency),
            DateField(label: 'Target date (optional)', value: date, onChanged: (d) => set(() => date = d)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(onPressed: () { if (key.currentState!.validate()) Get.back(result: true); }, child: const Text('Save')),
        ],
      ),
    ));
    if (ok == true) {
      await auth.saveProfile({'savings_goal': MoneyUtils.toDb(MoneyUtils.tryParse(amount.text)!), 'savings_goal_date': date == null ? null : Fmt.db(date!)});
      c.load();
    }
  }

  @override
  Widget build(BuildContext context) => AdaptiveShell(
        route: AppRoutes.savings,
        child: Scaffold(
          appBar: AppBar(title: const Text('Savings Wallet'), actions: [IconButton(icon: const Icon(Icons.flag_outlined), tooltip: 'Goal', onPressed: _goal)]),
          body: Obx(() => LoadState(
                loading: c.loading.value,
                error: c.error.value,
                hasData: c.wallet.value != null,
                onRetry: c.load,
                child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
                  PageBody(
                    maxWidth: 800,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      AppCard(
                        color: AppColors.savings,
                        padding: const EdgeInsets.all(22),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Total savings', style: TextStyle(color: Colors.white70)),
                          FittedBox(fit: BoxFit.scaleDown, child: Text(m(c.balance), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800))),
                        ]),
                      ),
                      if (c.goalProgress != null)
                        AppCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Goal: ${m(auth.profile.value!.savingsGoal!)}${auth.profile.value!.savingsGoalDate != null ? ' by ${Fmt.date(auth.profile.value!.savingsGoalDate!)}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: c.goalProgress, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                            const SizedBox(height: 6),
                            Text('${((c.goalProgress ?? 0) * 100).round()}% · ${m(c.goalRemaining ?? Decimal.zero)} to go'),
                          ]),
                        ),
                      Row(children: [
                        Expanded(child: ElevatedButton.icon(onPressed: () => _open(AppRoutes.savingsAdd), icon: const Icon(Icons.add), label: const Text('Add money'))),
                        const SizedBox(width: 12),
                        Expanded(child: OutlinedButton.icon(onPressed: () => _open(AppRoutes.savingsWithdraw), icon: const Icon(Icons.remove), label: const Text('Withdraw'))),
                      ]),
                      const SectionHeader('History'),
                      if (c.txns.isEmpty) const AppCard(child: Text('No savings activity yet. Close a budget cycle to move your remaining money here.')),
                      for (final t in c.txns) _tile(t),
                    ]),
                  ),
                ]),
              )),
        ),
      );

  Widget _tile(SavingsTxn t) {
    final out = t.signed < Decimal.zero;
    final label = switch (t.type) {
      SavingsTxnType.monthlySavings => 'Monthly savings',
      SavingsTxnType.deposit => 'Deposit',
      SavingsTxnType.withdrawal => 'Withdrawal',
      SavingsTxnType.adjustment => 'Adjustment',
    };
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        CircleAvatar(backgroundColor: (out ? AppColors.expense : AppColors.savings).withOpacity(0.14), child: Icon(out ? Icons.north_east : Icons.south_west, color: out ? AppColors.expense : AppColors.savings, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.description.isEmpty ? label : t.description, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${Fmt.date(t.date)} · $label', style: const TextStyle(fontSize: 12)),
        ])),
        Text('${out ? '-' : '+'}${m(t.amount)}', style: TextStyle(fontWeight: FontWeight.w800, color: out ? AppColors.expense : AppColors.savings)),
      ]),
    );
  }
}

class SavingsOpPage extends StatefulWidget {
  final bool withdraw;
  const SavingsOpPage({super.key, required this.withdraw});
  @override
  State<SavingsOpPage> createState() => _SavingsOpPageState();
}

class _SavingsOpPageState extends State<SavingsOpPage> {
  final c = Get.find<SavingsController>();
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = Fmt.today();
  final String _key = const Uuid().v4(); // idempotency: one submission per opened form

  @override
  void initState() {
    super.initState();
    if (c.wallet.value == null) c.load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final amt = MoneyUtils.tryParse(_amount.text)!;
    final ok = widget.withdraw
        ? await c.withdraw(amt, _date, _desc.text, _notes.text, _key)
        : await c.deposit(amt, _date, _desc.text, _notes.text, _key);
    if (ok) Get.back();
  }

  @override
  Widget build(BuildContext context) => FormScaffold(
        title: widget.withdraw ? 'Withdraw from savings' : 'Add to savings',
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 8),
            Obx(() => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Current balance: ${MoneyUtils.format(c.balance, currency: c.currency)}', style: const TextStyle(fontWeight: FontWeight.w700)))),
            AmountField(controller: _amount, currency: c.currency),
            AppTextField(controller: _desc, label: 'Description (optional)'),
            DateField(label: 'Date', value: _date, last: Fmt.today(), onChanged: (d) => setState(() => _date = d)),
            AppTextField(controller: _notes, label: 'Notes (optional)', maxLines: 2),
            Obx(() => PrimaryButton(label: widget.withdraw ? 'Withdraw' : 'Add money', loading: c.saving.value, onPressed: _save, color: widget.withdraw ? AppColors.expense : null)),
          ]),
        ),
      );
}
