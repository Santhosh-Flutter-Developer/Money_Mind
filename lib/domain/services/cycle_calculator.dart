import '../entities/entities.dart';

enum CycleMode { salaryCycle, calendarMonth }

/// Works out which budget period a date falls into.
/// Salary day 5 => 05 Sep -> 04 Oct is the "September" cycle.
class CycleCalculator {
  static DateTime _d(int y, int m, int d) => DateTime(y, m, d);

  static BudgetPeriod periodFor(DateTime date, {required int salaryDay, required CycleMode mode}) {
    final d = _d(date.year, date.month, date.day);
    if (mode == CycleMode.calendarMonth) {
      return BudgetPeriod(_d(d.year, d.month, 1), _d(d.year, d.month + 1, 0));
    }
    final sd = salaryDay.clamp(1, 28).toInt();
    final start = d.day >= sd ? _d(d.year, d.month, sd) : _d(d.year, d.month - 1, sd);
    // day 0 of the following month resolves to the last day of this month when sd == 1
    final end = _d(start.year, start.month + 1, sd - 1);
    return BudgetPeriod(start, end);
  }

  static BudgetPeriod next(BudgetPeriod p, {required int salaryDay, required CycleMode mode}) =>
      periodFor(_d(p.end.year, p.end.month, p.end.day + 1), salaryDay: salaryDay, mode: mode);

  static BudgetPeriod previous(BudgetPeriod p, {required int salaryDay, required CycleMode mode}) =>
      periodFor(_d(p.start.year, p.start.month, p.start.day - 1), salaryDay: salaryDay, mode: mode);

  /// Day-of-month inside a period; mirrors the SQL day_in_period() function.
  static DateTime dayInPeriod(DateTime start, DateTime end, int? day) {
    if (day == null) return end;
    DateTime pick(int y, int m) {
      final last = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, day > last ? last : day);
    }

    var d = pick(start.year, start.month);
    if (d.isBefore(start)) d = pick(start.year, start.month + 1);
    return d;
  }
}
