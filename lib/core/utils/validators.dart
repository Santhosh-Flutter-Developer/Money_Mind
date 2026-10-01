import 'package:decimal/decimal.dart';
import 'money.dart';

class Validators {
  static String? required(String? v, [String label = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email address';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Use at least 6 characters';
    return null;
  }

  /// Amount must be a number > 0 (or >= 0 when [allowZero]).
  static String? amount(String? v, {bool allowZero = false}) {
    final d = MoneyUtils.tryParse(v);
    if (d == null) return 'Enter a valid amount';
    if (allowZero ? d < Decimal.zero : d <= Decimal.zero) {
      return allowZero ? 'Amount cannot be negative' : 'Amount must be greater than 0';
    }
    return null;
  }

  static String? rate(String? v) {
    final d = MoneyUtils.tryParse(v);
    if (d == null) return 'Enter a valid rate';
    if (d < Decimal.zero) return 'Rate cannot be negative';
    return null;
  }

  static String? day(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null || n < 1 || n > 31) return 'Enter a day between 1 and 31';
    return null;
  }
}
