import 'package:decimal/decimal.dart';
import 'package:get/get.dart';
import '../../core/error/failure.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/entities.dart';
import '../../domain/services/budget_logic.dart';
import '../../domain/services/lending_logic.dart';
import '../../domain/services/reminder_builder.dart';
import '../../domain/usecases/usecases.dart';
import 'app_events.dart';
import 'auth_controller.dart';

class HomeController extends GetxController {
  final BudgetUseCases _budget;
  final SavingsUseCases _savings;
  final LendingUseCases _lending;
  final AuthController _auth;
  HomeController(this._budget, this._savings, this._lending, this._auth);

  final budget = Rxn<MonthlyBudget>();
  final items = <BudgetItem>[].obs;
  final wallet = Rxn<SavingsWallet>();
  final loans = <Loan>[].obs;
  final periods = <InterestPeriod>[].obs;
  final interestThisCycle = Decimal.zero.obs;
  final reminders = <Reminder>[].obs;
  final trend = <MonthlyBudget>[].obs; // last 6 cycles, oldest first
  final loading = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    ever(Get.find<AppEvents>().logoutTick, (_) {
      budget.value = null;
      items.clear();
      wallet.value = null;
      loans.clear();
      periods.clear();
      reminders.clear();
      trend.clear();
    });
  }

  String get currency => _auth.currency;

  BudgetSummary? get summary {
    final b = budget.value;
    return b == null ? null : BudgetCalculator.summarize(salary: b.salary, extraIncome: b.extraIncome, items: items);
  }

  Decimal get savings => wallet.value?.balance ?? Decimal.zero;
  Decimal get moneyLent => MoneyUtils.sum(loans.map((l) => l.outstanding));
  Decimal get interestReceivedTotal => InterestCalculator.totalReceived(periods);
  Decimal get interestPending => InterestCalculator.totalPending(periods);
  Decimal get available => summary?.remaining ?? Decimal.zero;

  /// Cash/available + savings + outstanding principal. Lending and savings transfers are not expenses.
  Decimal get netWorth => available + savings + moneyLent;

  /// Completed spending per category this cycle; falls back to the plan when nothing is paid yet.
  bool get categoryIsPlanned => !items.any((i) => i.isCompleted);

  Map<String, Decimal> get categorySpend {
    final map = <String, Decimal>{};
    final source = categoryIsPlanned ? items.where((i) => i.status != ItemStatus.skipped) : items.where((i) => i.isCompleted);
    for (final i in source) {
      final k = i.categoryName ?? 'Other';
      map[k] = (map[k] ?? Decimal.zero) + i.amount;
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }

  List<BudgetItem> get upcoming {
    final list = items.where((i) => i.status != ItemStatus.skipped).toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return (a.dueDate ?? DateTime(2100)).compareTo(b.dueDate ?? DateTime(2100));
      });
    return list.take(6).toList();
  }

  Future<void> load() async {
    if (budget.value == null) loading.value = true;
    error.value = null;
    try {
      final p = _auth.currentPeriod;
      final b = await _budget.ensureBudget(p);
      await _lending.refresh();
      final r = await Future.wait([
        _budget.items(b.id),
        _savings.wallet(),
        _lending.loans(),
        _lending.periods(),
        _lending.payments(from: p.start, to: p.end),
        _budget.budgets(from: DateTime(p.start.year, p.start.month - 7, 1)),
      ]);
      budget.value = b;
      items.assignAll(r[0] as List<BudgetItem>);
      wallet.value = r[1] as SavingsWallet;
      loans.assignAll(r[2] as List<Loan>);
      periods.assignAll(r[3] as List<InterestPeriod>);
      interestThisCycle.value = MoneyUtils.sum((r[4] as List<InterestPayment>).map((e) => e.amount));
      final all = r[5] as List<MonthlyBudget>;
      trend.assignAll(all.length > 6 ? all.sublist(all.length - 6) : all);
      _buildReminders();
    } catch (e) {
      error.value = mapError(e).message;
    } finally {
      loading.value = false;
    }
  }

  void _buildReminders() {
    final profile = _auth.profile.value;
    if (profile == null) return;
    final names = {for (final l in loans) l.id: l.personName};
    final list = ReminderBuilder.build(
      profile: profile,
      settings: _auth.settings.value,
      budget: budget.value,
      items: items,
      periods: periods.where((p) => loans.any((l) => l.id == p.loanId && l.active)).toList(),
      loanNames: names,
      today: Fmt.today(),
    );
    reminders.assignAll(list);
    NotificationService.instance.reschedule(list);
  }
}