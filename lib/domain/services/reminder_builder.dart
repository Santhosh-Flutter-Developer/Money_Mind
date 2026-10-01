import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../entities/entities.dart';
import 'cycle_calculator.dart';

/// Single source for both OS notifications and the in-app reminder list.
class ReminderBuilder {
  static List<Reminder> build({
    required UserProfile profile,
    required AppSettings settings,
    required MonthlyBudget? budget,
    required List<BudgetItem> items,
    required List<InterestPeriod> periods,
    required Map<String, String> loanNames,
    required DateTime today,
  }) {
    final out = <Reminder>[];
    DateTime at(DateTime d) => DateTime(d.year, d.month, d.day, 9);
    final cur = profile.currency;

    if (settings.expenseReminders) {
      for (final i in items.where((i) => i.isPending && i.dueDate != null)) {
        final due = i.dueDate!;
        out.add(Reminder(
          title: '${i.name} is due ${due == today ? 'today' : 'tomorrow'}',
          body: '${MoneyUtils.format(i.amount, currency: cur)} pending',
          when: at(due.subtract(const Duration(days: 1)).isBefore(today) ? due : due.subtract(const Duration(days: 1))),
          kind: 'expense',
        ));
      }
    }
    if (settings.interestReminders) {
      for (final p in periods.where((p) => !p.isSettled)) {
        out.add(Reminder(
          title: "${loanNames[p.loanId] ?? 'Borrower'}'s ${MoneyUtils.format(p.remaining, currency: cur)} interest is due",
          body: 'For ${p.label} · due ${Fmt.date(p.due)}',
          when: at(p.due),
          kind: 'interest',
        ));
      }
    }
    if (settings.salaryReminder) {
      final mode = profile.usesSalaryCycle ? CycleMode.salaryCycle : CycleMode.calendarMonth;
      final nextStart = CycleCalculator.next(CycleCalculator.periodFor(today, salaryDay: profile.salaryDay, mode: mode),
              salaryDay: profile.salaryDay, mode: mode)
          .start;
      out.add(Reminder(
        title: 'Monthly salary day is tomorrow',
        body: 'Start your new budget cycle on ${Fmt.date(nextStart)}',
        when: at(nextStart.subtract(const Duration(days: 1))),
        kind: 'salary',
      ));
    }
    if (settings.closingReminder && budget != null && !budget.closed) {
      final rem = budget.remaining;
      if (rem > MoneyUtils.parse(0)) {
        out.add(Reminder(
          title: '${MoneyUtils.format(rem, currency: cur)} is available to move to savings',
          body: 'Close the ${budget.period.label} cycle to transfer it',
          when: at(budget.periodEnd),
          kind: 'closing',
        ));
      }
    }
    out.sort((a, b) => a.when.compareTo(b.when));
    return out;
  }
}
