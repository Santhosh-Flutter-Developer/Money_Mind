import 'package:intl/intl.dart';

class Fmt {
  static final _date = DateFormat('dd MMM yyyy');
  static final _short = DateFormat('dd MMM');
  static final _monthYear = DateFormat('MMMM yyyy');
  static final _monthShort = DateFormat('MMM');
  static final _db = DateFormat('yyyy-MM-dd');

  static String date(DateTime d) => _date.format(d);
  static String shortDate(DateTime d) => _short.format(d);
  static String monthYear(DateTime d) => _monthYear.format(d);
  static String monthShort(DateTime d) => _monthShort.format(d);
  static String db(DateTime d) => _db.format(d);

  static DateTime parseDate(Object? v) {
    final d = DateTime.parse(v.toString());
    return DateTime(d.year, d.month, d.day);
  }

  static DateTime? tryParseDate(Object? v) => v == null ? null : parseDate(v);
  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  /// Rate like 3 or 2.5 without trailing zeros.
  static String rate(num r) {
    var s = r.toStringAsFixed(3);
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return s;
  }
}
