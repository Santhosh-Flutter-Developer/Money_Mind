import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneymind/core/utils/money.dart';
import 'package:moneymind/domain/entities/entities.dart';
import 'package:moneymind/domain/services/cycle_calculator.dart';
import 'package:moneymind/domain/services/report_calculator.dart';
import 'helpers.dart';

void main() {
  group('CycleCalculator', () {
    test('salary day 5: 20 Sep falls in 5 Sep -> 4 Oct', () {
      final p = CycleCalculator.periodFor(DateTime(2026, 9, 20), salaryDay: 5, mode: CycleMode.salaryCycle);
      expect(p.start, DateTime(2026, 9, 5));
      expect(p.end, DateTime(2026, 10, 4));
    });

    test('date before salary day belongs to the previous cycle', () {
      final p = CycleCalculator.periodFor(DateTime(2026, 9, 2), salaryDay: 5, mode: CycleMode.salaryCycle);
      expect(p.start, DateTime(2026, 8, 5));
      expect(p.end, DateTime(2026, 9, 4));
    });

    test('year boundary', () {
      final p = CycleCalculator.periodFor(DateTime(2026, 1, 2), salaryDay: 5, mode: CycleMode.salaryCycle);
      expect(p.start, DateTime(2025, 12, 5));
      expect(p.end, DateTime(2026, 1, 4));
    });

    test('salary day 1 equals the calendar month', () {
      final p = CycleCalculator.periodFor(DateTime(2026, 9, 15), salaryDay: 1, mode: CycleMode.salaryCycle);
      expect(p.start, DateTime(2026, 9, 1));
      expect(p.end, DateTime(2026, 9, 30));
    });

    test('calendar mode handles leap February', () {
      final p = CycleCalculator.periodFor(DateTime(2028, 2, 10), salaryDay: 5, mode: CycleMode.calendarMonth);
      expect(p.end, DateTime(2028, 2, 29));
    });

    test('next and previous are contiguous', () {
      final p = CycleCalculator.periodFor(DateTime(2026, 9, 20), salaryDay: 5, mode: CycleMode.salaryCycle);
      final n = CycleCalculator.next(p, salaryDay: 5, mode: CycleMode.salaryCycle);
      final b = CycleCalculator.previous(p, salaryDay: 5, mode: CycleMode.salaryCycle);
      expect(n.start, DateTime(2026, 10, 5));
      expect(b.end, DateTime(2026, 9, 4));
      expect(p.contains(DateTime(2026, 10, 4)), true);
      expect(p.contains(DateTime(2026, 10, 5)), false);
    });

    test('dayInPeriod clamps to short months', () {
      final d = CycleCalculator.dayInPeriod(DateTime(2026, 2, 1), DateTime(2026, 2, 28), 31);
      expect(d, DateTime(2026, 2, 28));
      expect(CycleCalculator.dayInPeriod(DateTime(2026, 9, 5), DateTime(2026, 10, 4), null), DateTime(2026, 10, 4));
    });
  });

  group('ReportCalculator keeps money types separate', () {
    final t = [
      txn(TxnType.income, TxnDirection.inflow, '70000'),
      txn(TxnType.expense, TxnDirection.outflow, '15000', category: 'Rent'),
      txn(TxnType.expense, TxnDirection.outflow, '6500', category: 'Food'),
      txn(TxnType.interest, TxnDirection.inflow, '1350'),
      txn(TxnType.lending, TxnDirection.outflow, '10000'),
      txn(TxnType.lending, TxnDirection.inflow, '5000'),
      txn(TxnType.transfer, TxnDirection.neutral, '48500'),
    ];

    test('net flow = income + interest - expenses (lending and transfers excluded)', () {
      expect(ReportCalculator.netFlow(t), D('49850'));
    });

    test('lending principal is not an expense and principal returned is not income', () {
      expect(ReportCalculator.expenses(t), D('21500'));
      expect(ReportCalculator.income(t), D('70000'));
      expect(ReportCalculator.principalLent(t), D('10000'));
      expect(ReportCalculator.principalReturned(t), D('5000'));
    });

    test('interest is reported separately as income-like receipts', () {
      expect(ReportCalculator.interestReceived(t), D('1350'));
    });

    test('expenses grouped by category, largest first', () {
      final by = ReportCalculator.expenseByCategory(t);
      expect(by.keys.toList(), ['Rent', 'Food']);
      expect(by['Rent'], D('15000'));
    });

    test('average monthly savings only counts closed cycles', () {
      MonthlyBudget b(bool closed, String saved) => MonthlyBudget(
          id: saved, periodStart: DateTime(2026, 1, 1), periodEnd: DateTime(2026, 1, 31), salary: D('1'), closed: closed,
          savingsTransferred: D(saved), planned: Decimal.zero, spent: Decimal.zero, pending: Decimal.zero, extraIncome: Decimal.zero);
      expect(ReportCalculator.averageSavings([b(true, '100'), b(true, '300'), b(false, '0')]), D('200'));
      expect(ReportCalculator.averageSavings([]), Decimal.zero);
    });
  });

  group('MoneyUtils', () {
    test('Indian digit grouping', () {
      expect(MoneyUtils.format(D('70000')), '₹70,000');
      expect(MoneyUtils.format(D('125000')), '₹1,25,000');
      expect(MoneyUtils.format(D('12500000')), '₹1,25,00,000');
      expect(MoneyUtils.format(D('300.5')), '₹300.50');
      expect(MoneyUtils.format(D('-4000')), '-₹4,000');
    });

    test('western grouping for other currencies', () {
      expect(MoneyUtils.format(D('1234567'), currency: 'USD'), r'$1,234,567');
    });

    test('parsing user input', () {
      expect(MoneyUtils.tryParse('1,25,000'), D('125000'));
      expect(MoneyUtils.tryParse('₹5000.50'), D('5000.50'));
      expect(MoneyUtils.tryParse(''), isNull);
      expect(MoneyUtils.tryParse('abc'), isNull);
    });

    test('no floating point drift', () {
      expect(D('0.1') + D('0.2'), D('0.3'));
      expect(MoneyUtils.percentOf(D('10000'), D('3')), D('300'));
    });

    test('compact labels', () {
      expect(MoneyUtils.compact(D('1250')), '1.3K');
      expect(MoneyUtils.compact(D('250000')), '2.5L');
    });
  });
}
