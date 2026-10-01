import 'package:decimal/decimal.dart';

/// All money math goes through here. Never use double for calculations.
class MoneyUtils {
  static Decimal parse(Object? v) {
    if (v == null) return Decimal.zero;
    if (v is Decimal) return v;
    return Decimal.tryParse(v.toString()) ?? Decimal.zero;
  }

  /// Parses user input such as "1,25,000" or "₹5000". Returns null when invalid/empty.
  static Decimal? tryParse(String? input) {
    if (input == null) return null;
    final cleaned = input.replaceAll(',', '').replaceAll(RegExp(r'[₹$€£\s]'), '');
    if (cleaned.isEmpty) return null;
    return Decimal.tryParse(cleaned);
  }

  static Decimal round2(Decimal d) => d.round(scale: 2);

  /// base * rate / 100, rounded half-up to 2 decimals.
  static Decimal percentOf(Decimal base, Decimal rate) =>
      (base * rate / Decimal.fromInt(100)).toDecimal(scaleOnInfinitePrecision: 8).round(scale: 2);

  static Decimal sum(Iterable<Decimal> values) =>
      values.fold(Decimal.zero, (a, b) => a + b);

  static Decimal max0(Decimal d) => d < Decimal.zero ? Decimal.zero : d;

  /// Value sent to the database (string keeps exact precision).
  static String toDb(Decimal d) => round2(d).toStringAsFixed(2);

  static const _symbols = {'INR': '₹', 'USD': r'$', 'EUR': '€', 'GBP': '£'};
  static String symbol(String currency) => _symbols[currency] ?? currency;

  /// ₹70,000 / ₹1,25,000 / ₹300.50 – no trailing ".00".
  static String format(Decimal d, {String currency = 'INR', bool withSymbol = true}) {
    final neg = d < Decimal.zero;
    final abs = neg ? -d : d;
    var s = abs.toStringAsFixed(2);
    if (s.endsWith('.00')) s = s.substring(0, s.length - 3);
    final parts = s.split('.');
    final grouped = currency == 'INR' ? _indian(parts[0]) : _western(parts[0]);
    final body = parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
    final sym = withSymbol ? symbol(currency) : '';
    return '${neg ? '-' : ''}$sym$body';
  }

  /// PDF-safe (built-in PDF fonts lack the rupee glyph).
  static String plain(Decimal d, {String currency = 'INR'}) =>
      '${currency == 'INR' ? 'Rs ' : '$currency '}${format(d, currency: currency, withSymbol: false)}';

  /// ₹70K / ₹1.25L style for chart axes.
  static String compact(Decimal d, {String currency = 'INR'}) {
    final v = d.toDouble();
    final a = v.abs();
    String t(double x, String suffix) {
      var s = x.toStringAsFixed(1);
      if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
      return '${v < 0 ? '-' : ''}$s$suffix';
    }

    if (currency == 'INR') {
      if (a >= 1e7) return t(a / 1e7, 'Cr');
      if (a >= 1e5) return t(a / 1e5, 'L');
    } else if (a >= 1e6) {
      return t(a / 1e6, 'M');
    }
    if (a >= 1e3) return t(a / 1e3, 'K');
    return t(a, '');
  }

  static String _indian(String digits) {
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '${groups.join(',')},$last3';
  }

  static String _western(String digits) =>
      digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}
