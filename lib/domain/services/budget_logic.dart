import 'package:decimal/decimal.dart';
import '../../core/error/failure.dart';
import '../../core/utils/money.dart';
import '../entities/entities.dart';
import 'cycle_calculator.dart';

class BudgetSummary {
  final Decimal salary, extraIncome, planned, spent, pending, remaining;
  const BudgetSummary({
    required this.salary,
    required this.extraIncome,
    required this.planned,
    required this.spent,
    required this.pending,
    required this.remaining,
  });
  Decimal get totalIncome => salary + extraIncome;

  /// 0..1 share of income already spent (for progress bars).
  double get progress {
    if (totalIncome <= Decimal.zero) return 0;
    final p = (spent / totalIncome).toDecimal(scaleOnInfinitePrecision: 4).toDouble();
    return p.clamp(0.0, 1.0).toDouble();
  }
}

class BudgetCalculator {
  static Decimal spent(Iterable<BudgetItem> items) =>
      MoneyUtils.sum(items.where((i) => i.isCompleted).map((i) => i.amount));

  static Decimal planned(Iterable<BudgetItem> items) =>
      MoneyUtils.sum(items.where((i) => i.status != ItemStatus.skipped).map((i) => i.amount));

  static Decimal pending(Iterable<BudgetItem> items) =>
      MoneyUtils.sum(items.where((i) => i.isPending).map((i) => i.amount));

  /// remaining = salary (+ extra income) - COMPLETED items only.
  static Decimal remaining({required Decimal salary, Decimal? extraIncome, required Iterable<BudgetItem> items}) =>
      salary + (extraIncome ?? Decimal.zero) - spent(items);

  static BudgetSummary summarize({required Decimal salary, Decimal? extraIncome, required Iterable<BudgetItem> items}) {
    final extra = extraIncome ?? Decimal.zero;
    return BudgetSummary(
      salary: salary,
      extraIncome: extra,
      planned: planned(items),
      spent: spent(items),
      pending: pending(items),
      remaining: remaining(salary: salary, extraIncome: extra, items: items),
    );
  }

  /// Idempotent: completing an already completed item changes nothing.
  static List<BudgetItem> complete(List<BudgetItem> items, String id, {DateTime? at}) => [
        for (final i in items)
          if (i.id == id && !i.isCompleted) i.copyWith(status: ItemStatus.completed, completedAt: at ?? DateTime.now()) else i
      ];

  static List<BudgetItem> undo(List<BudgetItem> items, String id) => [
        for (final i in items)
          if (i.id == id && i.isCompleted) i.copyWith(status: ItemStatus.pending, clearCompletedAt: true) else i
      ];
}

/// Mirrors what the database does at the start of a cycle (used for tests/preview).
class RecurringGenerator {
  static List<BudgetItem> generate({
    required List<RecurringExpense> recurring,
    required BudgetPeriod period,
    required String budgetId,
    List<BudgetItem> existing = const [],
  }) {
    final already = existing.map((e) => e.recurringId).whereType<String>().toSet();
    return [
      for (final r in recurring)
        if (r.isActive && !already.contains(r.id))
          BudgetItem(
            id: '',
            budgetId: budgetId,
            categoryId: r.categoryId,
            categoryName: r.categoryName,
            recurringId: r.id,
            name: r.name,
            amount: r.amount,
            dueDate: CycleCalculator.dayInPeriod(period.start, period.end, r.dueDay),
            isRecurring: true,
            status: ItemStatus.pending,
            notes: r.notes,
          )
    ];
  }
}

class ClosePreview {
  final Decimal salary, extraIncome, completed, pendingAmount, remaining, transfer;
  const ClosePreview({
    required this.salary,
    required this.extraIncome,
    required this.completed,
    required this.pendingAmount,
    required this.remaining,
    required this.transfer,
  });
}

class CloseResult {
  final Decimal transferred;
  final Decimal newSavings;
  const CloseResult(this.transferred, this.newSavings);
}

class SavingsCalculator {
  /// Only a positive remainder is moved to savings.
  static Decimal monthEndTransfer(Decimal remaining) => MoneyUtils.max0(remaining);

  static Decimal deposit(Decimal balance, Decimal amount) {
    if (amount <= Decimal.zero) throw const Failure('Amount must be greater than 0', FailureType.validation);
    return balance + amount;
  }

  static Decimal withdraw(Decimal balance, Decimal amount) {
    if (amount <= Decimal.zero) throw const Failure('Amount must be greater than 0', FailureType.validation);
    if (amount > balance) throw const Failure('Not enough balance in your Savings Wallet.', FailureType.validation);
    return balance - amount;
  }
}

class MonthCloser {
  static ClosePreview preview({required Decimal salary, Decimal? extraIncome, required Iterable<BudgetItem> items}) {
    final s = BudgetCalculator.summarize(salary: salary, extraIncome: extraIncome, items: items);
    return ClosePreview(
      salary: salary,
      extraIncome: s.extraIncome,
      completed: s.spent,
      pendingAmount: s.pending,
      remaining: s.remaining,
      transfer: SavingsCalculator.monthEndTransfer(s.remaining),
    );
  }

  /// Closing twice is rejected; preserves all history (nothing is deleted).
  static CloseResult close({required bool alreadyClosed, required Decimal previousSavings, required ClosePreview preview}) {
    if (alreadyClosed) throw const Failure('This salary cycle is already closed.', FailureType.duplicate);
    return CloseResult(preview.transfer, previousSavings + preview.transfer);
  }
}
