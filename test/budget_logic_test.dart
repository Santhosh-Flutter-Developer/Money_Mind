import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneymind/core/error/failure.dart';
import 'package:moneymind/domain/entities/entities.dart';
import 'package:moneymind/domain/services/budget_logic.dart';
import 'helpers.dart';

void main() {
  group('BudgetCalculator', () {
    test('salary 70000 minus one completed expense of 5000 leaves 65000', () {
      final items = [item('1', '5000', status: ItemStatus.completed)];
      expect(BudgetCalculator.remaining(salary: D('70000'), items: items), D('65000'));
    });

    test('pending expenses do not reduce remaining', () {
      final items = [item('1', '5000'), item('2', '7000')];
      final s = BudgetCalculator.summarize(salary: D('70000'), items: items);
      expect(s.remaining, D('70000'));
      expect(s.pending, D('12000'));
      expect(s.planned, D('12000'));
      expect(s.spent, Decimal.zero);
    });

    test('multiple completions accumulate', () {
      var items = [item('1', '5000'), item('2', '1000'), item('3', '7000')];
      items = BudgetCalculator.complete(items, '1');
      items = BudgetCalculator.complete(items, '3');
      final s = BudgetCalculator.summarize(salary: D('70000'), items: items);
      expect(s.spent, D('12000'));
      expect(s.remaining, D('58000'));
      expect(s.pending, D('1000'));
    });

    test('completing the same item twice never deducts twice', () {
      var items = [item('1', '5000')];
      items = BudgetCalculator.complete(items, '1');
      items = BudgetCalculator.complete(items, '1');
      expect(BudgetCalculator.remaining(salary: D('70000'), items: items), D('65000'));
    });

    test('undo restores the amount; undo on pending is a no-op', () {
      var items = [item('1', '5000')];
      items = BudgetCalculator.complete(items, '1');
      items = BudgetCalculator.undo(items, '1');
      items = BudgetCalculator.undo(items, '1');
      expect(BudgetCalculator.remaining(salary: D('70000'), items: items), D('70000'));
    });

    test('extra income increases remaining', () {
      final items = [item('1', '5000', status: ItemStatus.completed)];
      expect(BudgetCalculator.remaining(salary: D('70000'), extraIncome: D('2000'), items: items), D('67000'));
    });

    test('progress is clamped between 0 and 1', () {
      final s = BudgetCalculator.summarize(salary: D('1000'), items: [item('1', '5000', status: ItemStatus.completed)]);
      expect(s.progress, 1.0);
      expect(BudgetCalculator.summarize(salary: Decimal.zero, items: const []).progress, 0.0);
    });
  });

  group('RecurringGenerator', () {
    final period = BudgetPeriod(DateTime(2026, 9, 5), DateTime(2026, 10, 4));
    final rec = [
      RecurringExpense(id: 'r1', name: 'Rent', amount: D('12000'), dueDay: 7, isActive: true),
      RecurringExpense(id: 'r2', name: 'Gym', amount: D('500'), dueDay: 2, isActive: true),
      RecurringExpense(id: 'r3', name: 'Paused', amount: D('100'), dueDay: 9, isActive: false),
    ];

    test('creates one item per active recurring expense with due dates inside the cycle', () {
      final out = RecurringGenerator.generate(recurring: rec, period: period, budgetId: 'b1');
      expect(out.length, 2);
      expect(out.firstWhere((i) => i.name == 'Rent').dueDate, DateTime(2026, 9, 7));
      expect(out.firstWhere((i) => i.name == 'Gym').dueDate, DateTime(2026, 10, 2)); // day 2 is before the 5th
      expect(out.every((i) => period.contains(i.dueDate!)), true);
    });

    test('does not duplicate items that already exist', () {
      final existing = [item('x', '12000', recurringId: 'r1')];
      final out = RecurringGenerator.generate(recurring: rec, period: period, budgetId: 'b1', existing: existing);
      expect(out.map((e) => e.recurringId), ['r2']);
    });
  });

  group('MonthCloser / savings', () {
    final items = [
      item('1', '21500', status: ItemStatus.completed),
      item('2', '3000'), // pending, not deducted
    ];

    test('preview moves only the positive remainder to savings', () {
      final p = MonthCloser.preview(salary: D('70000'), items: items);
      expect(p.remaining, D('48500'));
      expect(p.transfer, D('48500'));
      expect(p.pendingAmount, D('3000'));
    });

    test('closing updates savings and returns the transfer', () {
      final p = MonthCloser.preview(salary: D('70000'), items: items);
      final r = MonthCloser.close(alreadyClosed: false, previousSavings: D('50000'), preview: p);
      expect(r.transferred, D('48500'));
      expect(r.newSavings, D('98500'));
    });

    test('closing an already closed cycle is rejected', () {
      final p = MonthCloser.preview(salary: D('70000'), items: items);
      expect(() => MonthCloser.close(alreadyClosed: true, previousSavings: D('0'), preview: p), throwsA(isA<Failure>()));
    });

    test('overspent cycle transfers nothing', () {
      final p = MonthCloser.preview(salary: D('1000'), items: [item('1', '5000', status: ItemStatus.completed)]);
      expect(p.remaining, D('-4000'));
      expect(p.transfer, Decimal.zero);
    });

    test('savings deposit and withdrawal', () {
      expect(SavingsCalculator.deposit(D('100'), D('50')), D('150'));
      expect(SavingsCalculator.withdraw(D('100'), D('40')), D('60'));
      expect(() => SavingsCalculator.withdraw(D('100'), D('101')), throwsA(isA<Failure>()));
      expect(() => SavingsCalculator.withdraw(D('100'), Decimal.zero), throwsA(isA<Failure>()));
      expect(() => SavingsCalculator.deposit(D('100'), D('-5')), throwsA(isA<Failure>()));
    });
  });
}
