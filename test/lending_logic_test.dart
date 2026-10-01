import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneymind/core/error/failure.dart';
import 'package:moneymind/domain/entities/entities.dart';
import 'package:moneymind/domain/services/lending_logic.dart';
import 'helpers.dart';

void main() {
  group('InterestCalculator', () {
    test('10000 at 3% per month is 300', () {
      expect(InterestCalculator.monthly(D('10000'), D('3')), D('300'));
    });

    test('rounds to 2 decimals', () {
      expect(InterestCalculator.monthly(D('12345'), D('2.5')), D('308.63')); // 308.625 -> 308.63
    });

    test('partial payment: 300 due, 200 paid leaves 100 partial', () {
      final r = InterestCalculator.applyPayment(expected: D('300'), paid: Decimal.zero, amount: D('200'));
      expect(r.paid, D('200'));
      expect(r.remaining, D('100'));
      expect(r.status, InterestStatus.partial);
    });

    test('paying the remainder settles the month', () {
      final r = InterestCalculator.applyPayment(expected: D('300'), paid: D('200'), amount: D('100'));
      expect(r.remaining, Decimal.zero);
      expect(r.status, InterestStatus.paid);
    });

    test('overpayment and non-positive amounts are rejected', () {
      expect(() => InterestCalculator.applyPayment(expected: D('300'), paid: D('200'), amount: D('150')), throwsA(isA<Failure>()));
      expect(() => InterestCalculator.applyPayment(expected: D('300'), paid: Decimal.zero, amount: Decimal.zero), throwsA(isA<Failure>()));
      expect(InterestCalculator.applyPayment(expected: D('300'), paid: D('200'), amount: D('150'), allowAdvance: true).remaining, Decimal.zero);
    });

    test('status: paid > partial > overdue > pending', () {
      final today = DateTime(2026, 9, 10);
      InterestStatus s(String paid, DateTime due) => InterestCalculator.statusFor(expected: D('300'), paid: D(paid), due: due, today: today);
      expect(s('300', DateTime(2026, 9, 1)), InterestStatus.paid);
      expect(s('100', DateTime(2026, 9, 1)), InterestStatus.partial);
      expect(s('0', DateTime(2026, 9, 1)), InterestStatus.overdue);
      expect(s('0', DateTime(2026, 9, 10)), InterestStatus.pending);
      expect(s('0', DateTime(2026, 9, 30)), InterestStatus.pending);
    });

    test('periods are generated monthly from the start date', () {
      final out = InterestCalculator.periodsToGenerate(startDate: DateTime(2026, 1, 5), today: DateTime(2026, 3, 10), principal: D('10000'), rate: D('3'));
      expect(out.map((p) => p.start), [DateTime(2026, 1, 5), DateTime(2026, 2, 5), DateTime(2026, 3, 5)]);
      expect(out.first.end, DateTime(2026, 2, 4));
      expect(out.every((p) => p.expected == D('300')), true);
    });

    test('existing periods are not generated again', () {
      final out = InterestCalculator.periodsToGenerate(
        startDate: DateTime(2026, 1, 5),
        today: DateTime(2026, 3, 10),
        principal: D('10000'),
        rate: D('3'),
        existingStarts: {DateTime(2026, 1, 5), DateTime(2026, 2, 5)},
      );
      expect(out.length, 1);
      expect(out.single.start, DateTime(2026, 3, 5));
    });

    test('month-end start dates are clamped (31 Jan -> 28 Feb)', () {
      final out = InterestCalculator.periodsToGenerate(startDate: DateTime(2026, 1, 31), today: DateTime(2026, 3, 31), principal: D('1000'), rate: D('1'));
      expect(out.map((p) => p.start), [DateTime(2026, 1, 31), DateTime(2026, 2, 28), DateTime(2026, 3, 31)]);
    });

    test('closed loan stops generating after the closing date', () {
      final out = InterestCalculator.periodsToGenerate(
          startDate: DateTime(2026, 1, 5), today: DateTime(2026, 6, 1), closedOn: DateTime(2026, 2, 20), principal: D('10000'), rate: D('3'));
      expect(out.length, 2);
    });

    test('totals of received and pending interest', () {
      final periods = [
        InterestPeriod(id: 'a', loanId: 'l', start: DateTime(2026, 1, 5), end: DateTime(2026, 2, 4), due: DateTime(2026, 2, 4), expected: D('300'), paid: D('300'), storedStatus: InterestStatus.paid),
        InterestPeriod(id: 'b', loanId: 'l', start: DateTime(2026, 2, 5), end: DateTime(2026, 3, 4), due: DateTime(2026, 3, 4), expected: D('300'), paid: D('200'), storedStatus: InterestStatus.partial),
      ];
      expect(InterestCalculator.totalReceived(periods), D('500'));
      expect(InterestCalculator.totalPending(periods), D('100'));
    });
  });

  group('PaymentLedger', () {
    test('the same idempotency key is only accepted once', () {
      final ledger = PaymentLedger();
      var paid = Decimal.zero;
      for (var i = 0; i < 3; i++) {
        if (ledger.tryRecord('key-1')) {
          paid = InterestCalculator.applyPayment(expected: D('300'), paid: paid, amount: D('100')).paid;
        }
      }
      expect(paid, D('100'));
      expect(ledger.tryRecord('key-2'), true);
    });
  });

  group('LoanService', () {
    test('closing keeps the record, marks it closed and sets outstanding to zero', () {
      final closed = LoanService.close(loan(), returned: D('10000'), on: DateTime(2026, 9, 1));
      expect(closed.active, false);
      expect(closed.principalReturned, D('10000'));
      expect(closed.outstanding, Decimal.zero);
      expect(closed.personName, 'Sasi');
    });

    test('closing twice or with a bad amount is rejected', () {
      expect(() => LoanService.close(loan(active: false), returned: D('1'), on: DateTime.now()), throwsA(isA<Failure>()));
      expect(() => LoanService.close(loan(), returned: Decimal.zero, on: DateTime.now()), throwsA(isA<Failure>()));
    });
  });
}
