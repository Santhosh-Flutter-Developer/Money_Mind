import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../controllers/auth_controller.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/common.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final c = Get.find<OnboardingController>();
  final _salary = TextEditingController();
  final _goal = TextEditingController();
  final _day = TextEditingController(text: '1');

  @override
  void dispose() {
    _salary.dispose();
    _goal.dispose();
    _day.dispose();
    super.dispose();
  }

  String get cur => Get.find<AuthController>().currency;

  Future<void> _addExpense() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final day = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('Regular expense'),
      content: Form(
        key: key,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AppTextField(controller: name, label: 'Name (e.g. Rent)', validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
          AmountField(controller: amount, currency: cur),
          AppTextField(controller: day, label: 'Due day of month (optional)', keyboard: TextInputType.number, validator: (v) => (v ?? '').isEmpty ? null : (int.tryParse(v!) == null || int.parse(v) < 1 || int.parse(v) > 31 ? '1-31' : null)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
        TextButton(onPressed: () { if (key.currentState!.validate()) Get.back(result: true); }, child: const Text('Add')),
      ],
    ));
    if (ok == true) {
      c.expenses.add(DraftExpense(name.text.trim(), MoneyUtils.tryParse(amount.text)!, int.tryParse(day.text)));
    }
  }

  Widget _stepBody() {
    switch (c.step.value) {
      case 0:
        return _panel(Icons.waving_hand_outlined, 'Welcome to MoneyMind', 'Plan every salary cycle, watch your savings grow and never lose track of money you have lent. Setup takes under a minute.', []);
      case 1:
        return _panel(Icons.payments_outlined, 'Your salary', 'We use this to plan each cycle. You can change it any month.', [
          AmountField(controller: _salary, label: 'Monthly salary', currency: cur, allowZero: true),
          AppTextField(controller: _day, label: 'Salary day (1-28)', keyboard: TextInputType.number, validator: (v) {
            final n = int.tryParse(v ?? '');
            return n == null || n < 1 || n > 28 ? 'Enter 1-28' : null;
          }),
          const Text('Salary day 5 means your cycle runs 5th → 4th of the next month.', style: TextStyle(fontSize: 12)),
        ]);
      case 2:
        return _panel(Icons.repeat, 'Regular monthly expenses', 'Rent, EMI, RD, bills… they will be added to every new cycle automatically.', [
          Obx(() => Column(children: [
                for (var i = 0; i < c.expenses.length; i++)
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text(c.expenses[i].name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(MoneyUtils.format(c.expenses[i].amount, currency: cur), style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => c.expenses.removeAt(i)),
                    ]),
                  ),
              ])),
          OutlinedButton.icon(onPressed: _addExpense, icon: const Icon(Icons.add), label: const Text('Add expense')),
        ]);
      case 3:
        return _panel(Icons.handshake_outlined, 'Do you lend money?', 'Track borrowers, monthly interest and repayments.', [
          Obx(() => SwitchListTile(
                title: const Text('Yes, I want to add a loan'),
                subtitle: const Text("We'll open the loan form when setup finishes."),
                value: c.wantsToLend.value,
                onChanged: (v) => c.wantsToLend.value = v,
              )),
        ]);
      default:
        return _panel(Icons.flag_outlined, 'Savings goal (optional)', 'Set a target and track your progress.', [
          AmountField(controller: _goal, label: 'Goal amount', currency: cur, allowZero: true),
          Obx(() => DateField(label: 'Target date (optional)', value: c.goalDate.value, onChanged: (d) => c.goalDate.value = d)),
        ]);
    }
  }

  Widget _panel(IconData icon, String title, String text, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Icon(icon, size: 56, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        ...children,
      ]);

  bool _validateStep() {
    if (c.step.value == 1) {
      final s = MoneyUtils.tryParse(_salary.text);
      final d = int.tryParse(_day.text);
      if (s == null || s < Decimal.zero) return false;
      if (d == null || d < 1 || d > 28) return false;
      c.salary.value = s;
      c.salaryDay.value = d;
    }
    if (c.step.value == 4) {
      c.goal.value = MoneyUtils.tryParse(_goal.text);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(actions: [TextButton(onPressed: c.skip, child: const Text('Skip'))]),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Obx(() => LinearProgressIndicator(value: (c.step.value + 1) / OnboardingController.steps, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 24),
                  Expanded(child: SingleChildScrollView(child: Obx(_stepBody))),
                  Obx(() => Row(children: [
                        if (c.step.value > 0) Expanded(child: OutlinedButton(onPressed: c.back, child: const Text('Back'))),
                        if (c.step.value > 0) const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: c.step.value == OnboardingController.steps - 1 ? 'Finish' : 'Next',
                            loading: c.saving.value,
                            onPressed: () {
                              if (!_validateStep()) {
                                Get.snackbar('Check your entry', 'Please enter valid values to continue.');
                                return;
                              }
                              c.step.value == OnboardingController.steps - 1 ? c.finish() : c.next();
                            },
                          ),
                        ),
                      ])),
                ]),
              ),
            ),
          ),
        ),
      );
}
