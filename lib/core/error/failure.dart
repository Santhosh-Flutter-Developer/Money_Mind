import 'package:supabase_flutter/supabase_flutter.dart';

enum FailureType { network, auth, validation, duplicate, server, unknown }

/// User-facing error. Raw Supabase/Postgres errors are never shown to users.
class Failure implements Exception {
  final String message;
  final FailureType type;
  const Failure(this.message, [this.type = FailureType.unknown]);
  bool get isAuth => type == FailureType.auth;
  @override
  String toString() => message;
}

Failure mapError(Object e) {
  if (e is Failure) return e;

  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) {
      return const Failure('Incorrect email or password.', FailureType.auth);
    }
    if (m.contains('already registered') || m.contains('already been registered')) {
      return const Failure('An account with this email already exists.', FailureType.duplicate);
    }
    if (m.contains('not confirmed')) {
      return const Failure('Please confirm your email address, then log in.', FailureType.auth);
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return const Failure('Too many attempts. Please wait a moment and try again.', FailureType.auth);
    }
    if (m.contains('password')) {
      return const Failure('Choose a stronger password (at least 6 characters).', FailureType.validation);
    }
    if (m.contains('jwt') || m.contains('expired') || m.contains('session')) {
      return const Failure('Your session has expired. Please log in again.', FailureType.auth);
    }
    return const Failure('Authentication failed. Please try again.', FailureType.auth);
  }

  if (e is PostgrestException) {
    const known = {
      'ALREADY_CLOSED': 'This salary cycle is already closed.',
      'INSUFFICIENT_BALANCE': 'Not enough balance in your Savings Wallet.',
      'OVERPAYMENT': 'That is more than the interest still due.',
      'INVALID_AMOUNT': 'Enter a valid amount greater than zero.',
      'NOT_FOUND': 'That record no longer exists.',
      'COMPLETED_LOCKED': 'Undo the completion before changing the amount.',
      'DEMO_EXISTS': 'Demo data already exists.',
      'NOT_AUTHENTICATED': 'Your session has expired. Please log in again.',
    };
    for (final entry in known.entries) {
      if (e.message.contains(entry.key)) {
        final type = entry.key == 'NOT_AUTHENTICATED'
            ? FailureType.auth
            : entry.key == 'ALREADY_CLOSED'
                ? FailureType.duplicate
                : FailureType.validation;
        return Failure(entry.value, type);
      }
    }
    if (e.code == '23505') {
      return const Failure('That already exists.', FailureType.duplicate);
    }
    if (e.code == '23514' || e.code == '22P02' || e.code == '22007') {
      return const Failure('Please check the values you entered.', FailureType.validation);
    }
    if (e.code == 'PGRST301' || e.message.toLowerCase().contains('jwt')) {
      return const Failure('Your session has expired. Please log in again.', FailureType.auth);
    }
    return const Failure('Something went wrong on our side. Please try again.', FailureType.server);
  }

  final text = e.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('XMLHttpRequest') ||
      text.contains('TimeoutException')) {
    return const Failure('No internet connection. Check your network and try again.', FailureType.network);
  }
  return const Failure('Something went wrong. Please try again.');
}

/// Runs [action] and converts any thrown error into a user-friendly [Failure].
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    throw mapError(e);
  }
}
