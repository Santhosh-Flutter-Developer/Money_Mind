import 'package:decimal/decimal.dart';
import '../../core/utils/money.dart';
import '../entities/entities.dart';

/// Keeps income / expense / savings / lending principal / interest / transfers separate.
///  - Money lent is a transfer (never an expense); principal returned is never income.
///  - Interest received IS income.
class ReportCalculator {
  static Decimal _sum(Iterable<MoneyTxn> t, bool Function(MoneyTxn) test) =>
      MoneyUtils.sum(t.where(test).map((e) => e.amount));

  static Decimal income(List<MoneyTxn> t) => _sum(t, (e) => e.type == TxnType.income);
  static Decimal expenses(List<MoneyTxn> t) => _sum(t, (e) => e.type == TxnType.expense);
  static Decimal interestReceived(List<MoneyTxn> t) => _sum(t, (e) => e.type == TxnType.interest);
  static Decimal principalLent(List<MoneyTxn> t) =>
      _sum(t, (e) => e.type == TxnType.lending && e.direction == TxnDirection.outflow);
  static Decimal principalReturned(List<MoneyTxn> t) =>
      _sum(t, (e) => e.type == TxnType.lending && e.direction == TxnDirection.inflow);

  /// Net cash flow = income + interest received - expenses. Transfers are excluded.
  static Decimal netFlow(List<MoneyTxn> t) => income(t) + interestReceived(t) - expenses(t);

  static Map<String, Decimal> expenseByCategory(List<MoneyTxn> t) {
    final map = <String, Decimal>{};
    for (final e in t.where((e) => e.type == TxnType.expense)) {
      final k = e.categoryName ?? 'Other';
      map[k] = (map[k] ?? Decimal.zero) + e.amount;
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }

  static Decimal averageSavings(List<MonthlyBudget> closed) {
    final withSavings = closed.where((b) => b.closed).toList();
    if (withSavings.isEmpty) return Decimal.zero;
    final total = MoneyUtils.sum(withSavings.map((b) => b.savingsTransferred));
    return (total / Decimal.fromInt(withSavings.length)).toDecimal(scaleOnInfinitePrecision: 4).round(scale: 2);
  }
}
