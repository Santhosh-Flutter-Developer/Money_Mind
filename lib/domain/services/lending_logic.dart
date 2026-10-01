import 'package:decimal/decimal.dart';
import '../../core/error/failure.dart';
import '../../core/utils/money.dart';
import '../entities/entities.dart';

class PaymentResult {
  final Decimal paid;
  final Decimal remaining;
  final InterestStatus status;
  const PaymentResult(this.paid, this.remaining, this.status);
}

class PeriodDraft {
  final DateTime start, end, due;
  final Decimal expected;
  const PeriodDraft(this.start, this.end, this.due, this.expected);
}

class InterestCalculator {
  /// principal x rate / 100. 10,000 at 3% => 300.
  static Decimal monthly(Decimal principal, Decimal rate) => MoneyUtils.percentOf(principal, rate);

  /// Applies a (possibly partial) payment. Never touches principal.
  static PaymentResult applyPayment({
    required Decimal expected,
    required Decimal paid,
    required Decimal amount,
    bool allowAdvance = false,
  }) {
    if (amount <= Decimal.zero) throw const Failure('Amount must be greater than 0', FailureType.validation);
    final due = expected - paid;
    if (amount > due && !allowAdvance) {
      throw const Failure('That is more than the interest still due.', FailureType.validation);
    }
    final newPaid = paid + amount;
    final remaining = MoneyUtils.max0(expected - newPaid);
    final status = remaining == Decimal.zero ? InterestStatus.paid : InterestStatus.partial;
    return PaymentResult(newPaid, remaining, status);
  }

  /// Paid > Partial > Overdue (due date passed) > Pending.
  static InterestStatus statusFor({
    required Decimal expected,
    required Decimal paid,
    required DateTime due,
    required DateTime today,
  }) {
    if (paid >= expected) return InterestStatus.paid;
    if (paid > Decimal.zero) return InterestStatus.partial;
    final t = DateTime(today.year, today.month, today.day);
    return due.isBefore(t) ? InterestStatus.overdue : InterestStatus.pending;
  }

  static InterestStatus statusOf(InterestPeriod p, DateTime today) =>
      statusFor(expected: p.expected, paid: p.paid, due: p.due, today: today);

  static DateTime _addMonths(DateTime d, int n) {
    final y = d.year + ((d.month - 1 + n) ~/ 12);
    final m = (d.month - 1 + n) % 12 + 1;
    final last = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, d.day > last ? last : d.day);
  }

  /// Monthly periods from the loan start until [today] (or [closedOn]).
  /// Periods whose start already exists are skipped => no duplicates.
  static List<PeriodDraft> periodsToGenerate({
    required DateTime startDate,
    required DateTime today,
    required Decimal principal,
    required Decimal rate,
    Set<DateTime> existingStarts = const {},
    DateTime? closedOn,
  }) {
    final last = closedOn ?? today;
    final expected = monthly(principal, rate);
    final out = <PeriodDraft>[];
    for (var k = 0; k < 600; k++) {
      final s = _addMonths(startDate, k);
      if (s.isAfter(last)) break;
      if (existingStarts.contains(s)) continue;
      final e = _addMonths(startDate, k + 1).subtract(const Duration(days: 1));
      out.add(PeriodDraft(s, DateTime(e.year, e.month, e.day), DateTime(e.year, e.month, e.day), expected));
    }
    return out;
  }

  static Decimal totalPending(Iterable<InterestPeriod> periods) =>
      MoneyUtils.sum(periods.map((p) => MoneyUtils.max0(p.remaining)));

  static Decimal totalReceived(Iterable<InterestPeriod> periods) => MoneyUtils.sum(periods.map((p) => p.paid));
}

/// Remembers idempotency keys so the same submission is never applied twice.
class PaymentLedger {
  final Set<String> _keys = {};
  bool tryRecord(String key) => _keys.add(key);
}

class LoanService {
  static Loan close(Loan loan, {required Decimal returned, required DateTime on}) {
    if (!loan.active) throw const Failure('This loan is already closed.', FailureType.duplicate);
    if (returned <= Decimal.zero) throw const Failure('Amount must be greater than 0', FailureType.validation);
    return Loan(
      id: loan.id,
      personName: loan.personName,
      phone: loan.phone,
      principal: loan.principal,
      rate: loan.rate,
      interestType: loan.interestType,
      startDate: loan.startDate,
      expectedDay: loan.expectedDay,
      notes: loan.notes,
      active: false,
      principalReturned: returned,
      closedOn: on,
    );
  }
}
