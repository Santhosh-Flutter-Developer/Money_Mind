import 'package:decimal/decimal.dart';
import 'package:get/get.dart';
import '../../core/error/failure.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/entities.dart';
import '../../domain/services/lending_logic.dart';
import '../../domain/usecases/usecases.dart';
import 'app_events.dart';
import 'auth_controller.dart';

class CalEvent {
  final String title;
  final String? amountText;
  final String kind; // salary expense expense_due interest interest_due savings loan
  final bool done;
  final Decimal? amount;
  const CalEvent(this.title, this.kind, {this.amount, this.done = true, this.amountText});
}

class CalendarController extends GetxController {
  final TransactionUseCases _txns;
  final BudgetUseCases _budget;
  final LendingUseCases _lending;
  final AuthController _auth;
  CalendarController(this._txns, this._budget, this._lending, this._auth);

  final month = Rx<DateTime>(DateTime(DateTime.now().year, DateTime.now().month, 1));
  final selected = Rx<DateTime>(Fmt.today());
  final events = <DateTime, List<CalEvent>>{}.obs;
  final loading = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    ever(Get.find<AppEvents>().logoutTick, (_) => events.clear());
  }

  String get currency => _auth.currency;
  List<CalEvent> eventsOn(DateTime d) => events[DateTime(d.year, d.month, d.day)] ?? const [];

  void shift(int dir) {
    month.value = DateTime(month.value.year, month.value.month + dir, 1);
    selected.value = month.value;
    load();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      final start = month.value;
      final end = DateTime(start.year, start.month + 1, 0);
      final map = <DateTime, List<CalEvent>>{};
      void add(DateTime d, CalEvent e) => (map[DateTime(d.year, d.month, d.day)] ??= []).add(e);

      final txns = await _txns.query(TxnFilter(from: start, to: end, limit: 2000));
      for (final t in txns) {
        switch (t.type) {
          case TxnType.income:
            add(t.date, CalEvent(t.description.isEmpty ? 'Income' : t.description, 'salary', amount: t.amount));
          case TxnType.expense:
            add(t.date, CalEvent(t.description, 'expense', amount: t.amount));
          case TxnType.interest:
            add(t.date, CalEvent(t.description, 'interest', amount: t.amount));
          case TxnType.lending:
            add(t.date, CalEvent(t.description, 'loan', amount: t.amount));
          case TxnType.savings:
          case TxnType.transfer:
            add(t.date, CalEvent(t.description, 'savings', amount: t.amount));
        }
      }

      // pending bills from any cycle overlapping this month
      final budgets = await _budget.budgets(from: DateTime(start.year, start.month - 1, 1), to: end);
      for (final b in budgets.where((b) => !b.periodStart.isAfter(end) && !b.periodEnd.isBefore(start))) {
        for (final i in await _budget.items(b.id)) {
          final d = i.dueDate;
          if (i.isPending && d != null && !d.isBefore(start) && !d.isAfter(end)) {
            add(d, CalEvent('${i.name} due', 'expense_due', amount: i.amount, done: false));
          }
        }
      }

      final names = {for (final l in await _lending.loans()) l.id: l.personName};
      for (final p in await _lending.periods()) {
        if (!p.isSettled && !p.due.isBefore(start) && !p.due.isAfter(end)) {
          add(p.due, CalEvent("${names[p.loanId] ?? 'Borrower'} interest due", 'interest_due', amount: p.remaining, done: false));
        }
      }
      events.assignAll(map);
    } catch (e) {
      error.value = mapError(e).message;
    } finally {
      loading.value = false;
    }
  }
}
