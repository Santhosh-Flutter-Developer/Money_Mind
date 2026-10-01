import 'package:decimal/decimal.dart';
import '../../core/utils/formatters.dart';

// ------------------------------------------------------------ profile
class UserProfile {
  final String id;
  final String name;
  final String email;
  final String currency;
  final int salaryDay;
  final Decimal defaultSalary;
  final String cycleMode; // salary_cycle | calendar_month
  final String? avatarUrl;
  final Decimal? savingsGoal;
  final DateTime? savingsGoalDate;
  final bool onboarded;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.currency,
    required this.salaryDay,
    required this.defaultSalary,
    required this.cycleMode,
    this.avatarUrl,
    this.savingsGoal,
    this.savingsGoalDate,
    required this.onboarded,
  });

  bool get usesSalaryCycle => cycleMode == 'salary_cycle';
  String get firstName => name.trim().isEmpty ? 'there' : name.trim().split(' ').first;
}

class AppSettings {
  final bool expenseReminders;
  final bool interestReminders;
  final bool salaryReminder;
  final bool closingReminder;
  final String themeMode;
  const AppSettings({
    this.expenseReminders = true,
    this.interestReminders = true,
    this.salaryReminder = true,
    this.closingReminder = true,
    this.themeMode = 'system',
  });
}

// --------------------------------------------------------- categories
class ExpenseCategory {
  final String id;
  final String name;
  final String icon;
  final bool isDefault;
  const ExpenseCategory({required this.id, required this.name, required this.icon, required this.isDefault});
}

class RecurringExpense {
  final String id;
  final String name;
  final String? categoryId;
  final String? categoryName;
  final Decimal amount;
  final int? dueDay;
  final bool isActive;
  final String? notes;
  const RecurringExpense({
    required this.id,
    required this.name,
    this.categoryId,
    this.categoryName,
    required this.amount,
    this.dueDay,
    required this.isActive,
    this.notes,
  });
}

// ------------------------------------------------------------- budget
class BudgetPeriod {
  final DateTime start;
  final DateTime end;
  const BudgetPeriod(this.start, this.end);

  bool contains(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(start) && !x.isAfter(end);
  }

  String get label => Fmt.monthYear(start);
  String get rangeLabel => '${Fmt.shortDate(start)} → ${Fmt.date(end)}';

  @override
  bool operator ==(Object other) => other is BudgetPeriod && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(start, end);
}

enum ItemStatus { pending, completed, skipped }

class MonthlyBudget {
  final String id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Decimal salary;
  final bool closed;
  final DateTime? closedAt;
  final Decimal savingsTransferred;
  final Decimal planned;
  final Decimal spent;
  final Decimal pending;
  final Decimal extraIncome;

  const MonthlyBudget({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.salary,
    required this.closed,
    this.closedAt,
    required this.savingsTransferred,
    required this.planned,
    required this.spent,
    required this.pending,
    required this.extraIncome,
  });

  BudgetPeriod get period => BudgetPeriod(periodStart, periodEnd);
  Decimal get totalIncome => salary + extraIncome;
  Decimal get remaining => totalIncome - spent;
}

class BudgetItem {
  final String id;
  final String budgetId;
  final String? categoryId;
  final String? categoryName;
  final String? recurringId;
  final String name;
  final Decimal amount;
  final DateTime? dueDate;
  final bool isRecurring;
  final ItemStatus status;
  final DateTime? completedAt;
  final String? notes;

  const BudgetItem({
    required this.id,
    required this.budgetId,
    this.categoryId,
    this.categoryName,
    this.recurringId,
    required this.name,
    required this.amount,
    this.dueDate,
    required this.isRecurring,
    required this.status,
    this.completedAt,
    this.notes,
  });

  bool get isCompleted => status == ItemStatus.completed;
  bool get isPending => status == ItemStatus.pending;

  BudgetItem copyWith({ItemStatus? status, DateTime? completedAt, bool clearCompletedAt = false}) => BudgetItem(
        id: id,
        budgetId: budgetId,
        categoryId: categoryId,
        categoryName: categoryName,
        recurringId: recurringId,
        name: name,
        amount: amount,
        dueDate: dueDate,
        isRecurring: isRecurring,
        status: status ?? this.status,
        completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
        notes: notes,
      );
}

// ------------------------------------------------------- transactions
enum TxnType { income, expense, lending, interest, savings, transfer }
enum TxnDirection { inflow, outflow, neutral }

class MoneyTxn {
  final String id;
  final TxnType type;
  final TxnDirection direction;
  final Decimal amount;
  final DateTime date;
  final String description;
  final String? categoryId;
  final String? categoryName;
  final String? refType;
  final String? refId;

  const MoneyTxn({
    required this.id,
    required this.type,
    required this.direction,
    required this.amount,
    required this.date,
    required this.description,
    this.categoryId,
    this.categoryName,
    this.refType,
    this.refId,
  });
}

class TxnFilter {
  final TxnType? type;
  final String? search;
  final String? categoryId;
  final DateTime? from;
  final DateTime? to;
  final Decimal? minAmount;
  final Decimal? maxAmount;
  final int limit;
  const TxnFilter({this.type, this.search, this.categoryId, this.from, this.to, this.minAmount, this.maxAmount, this.limit = 500});
}

// ------------------------------------------------------------ savings
class SavingsWallet {
  final String id;
  final Decimal balance;
  const SavingsWallet({required this.id, required this.balance});
}

enum SavingsTxnType { monthlySavings, deposit, withdrawal, adjustment }

class SavingsTxn {
  final String id;
  final SavingsTxnType type;
  final Decimal amount;
  final DateTime date;
  final String description;
  final String? month;
  final String? notes;
  const SavingsTxn({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    this.month,
    this.notes,
  });

  /// Signed effect on the wallet balance.
  Decimal get signed => type == SavingsTxnType.withdrawal ? -amount : amount;
}

// ------------------------------------------------------------ lending
enum InterestStatus { pending, partial, paid, overdue }

class Loan {
  final String id;
  final String personName;
  final String? phone;
  final Decimal principal;
  final Decimal rate;
  final String interestType;
  final DateTime startDate;
  final int? expectedDay;
  final String? notes;
  final bool active;
  final Decimal principalReturned;
  final DateTime? closedOn;

  const Loan({
    required this.id,
    required this.personName,
    this.phone,
    required this.principal,
    required this.rate,
    required this.interestType,
    required this.startDate,
    this.expectedDay,
    this.notes,
    required this.active,
    required this.principalReturned,
    this.closedOn,
  });

  /// Outstanding principal is zero once the loan is closed.
  Decimal get outstanding => active ? principal : Decimal.zero;
}

class InterestPeriod {
  final String id;
  final String loanId;
  final DateTime start;
  final DateTime end;
  final DateTime due;
  final Decimal expected;
  final Decimal paid;
  final InterestStatus storedStatus;

  const InterestPeriod({
    required this.id,
    required this.loanId,
    required this.start,
    required this.end,
    required this.due,
    required this.expected,
    required this.paid,
    required this.storedStatus,
  });

  Decimal get remaining => expected - paid;
  bool get isSettled => remaining <= Decimal.zero;
  String get label => Fmt.monthYear(start);
}

class InterestPayment {
  final String id;
  final String loanId;
  final String periodId;
  final Decimal amount;
  final DateTime date;
  final String? notes;
  const InterestPayment({
    required this.id,
    required this.loanId,
    required this.periodId,
    required this.amount,
    required this.date,
    this.notes,
  });
}

// ------------------------------------------------------- misc / views
class Reminder {
  final String title;
  final String body;
  final DateTime when;
  final String kind; // expense | interest | salary | closing
  const Reminder({required this.title, required this.body, required this.when, required this.kind});
}

class ExportTable {
  final String title;
  final String fileName;
  final List<String> headers;
  final List<List<String>> rows;
  final List<String> summary;
  const ExportTable({
    required this.title,
    required this.fileName,
    required this.headers,
    required this.rows,
    this.summary = const [],
  });
}
