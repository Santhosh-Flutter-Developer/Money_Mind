import 'package:decimal/decimal.dart';
import 'package:get/get.dart';
import '../../core/error/failure.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/snack.dart';
import '../../domain/entities/entities.dart';
import '../../domain/services/lending_logic.dart';
import '../../domain/usecases/usecases.dart';
import 'app_events.dart';
import 'auth_controller.dart';

class LendingController extends GetxController {
  final LendingUseCases _uc;
  final AuthController _auth;
  LendingController(this._uc, this._auth);

  final loans = <Loan>[].obs;
  final periods = <InterestPeriod>[].obs;
  final search = ''.obs;
  final showClosed = false.obs;
  final loading = false.obs;
  final saving = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    ever(Get.find<AppEvents>().logoutTick, (_) {
      loans.clear();
      periods.clear();
    });
  }

  String get currency => _auth.currency;
  List<Loan> get active => loans.where((l) => l.active).toList();
  Decimal get totalLent => MoneyUtils.sum(active.map((l) => l.principal));
  Decimal get interestReceived => InterestCalculator.totalReceived(periods);
  Decimal get pendingInterest => InterestCalculator.totalPending(periods);

  List<Loan> get visible {
    final q = search.value.trim().toLowerCase();
    return loans
        .where((l) => (showClosed.value || l.active) && (q.isEmpty || l.personName.toLowerCase().contains(q)))
        .toList();
  }

  List<InterestPeriod> periodsOf(String loanId) => periods.where((p) => p.loanId == loanId).toList();
  Decimal receivedFrom(String loanId) => InterestCalculator.totalReceived(periodsOf(loanId));
  Decimal pendingFrom(String loanId) => InterestCalculator.totalPending(periodsOf(loanId));

  /// Status of the period that contains today (or the latest one).
  InterestStatus? thisMonthStatus(String loanId) {
    final list = periodsOf(loanId);
    if (list.isEmpty) return null;
    final today = Fmt.today();
    final cur = list.firstWhere((p) => !today.isBefore(p.start) && !today.isAfter(p.end), orElse: () => list.first);
    return InterestCalculator.statusOf(cur, today);
  }

  Future<void> load() async {
    if (loans.isEmpty) loading.value = true;
    error.value = null;
    try {
      await _uc.refresh();
      final r = await Future.wait([_uc.loans(), _uc.periods()]);
      loans.assignAll(r[0] as List<Loan>);
      periods.assignAll(r[1] as List<InterestPeriod>);
    } catch (e) {
      error.value = mapError(e).message;
    } finally {
      loading.value = false;
    }
  }

  Future<bool> createLoan({
    required String name,
    String? phone,
    required Decimal principal,
    required Decimal rate,
    required DateTime start,
    int? expectedDay,
    String? notes,
  }) async {
    if (saving.value) return false;
    saving.value = true;
    try {
      await _uc.createLoan(
          name: name, phone: phone, principal: principal, rate: rate, start: start, expectedDay: expectedDay, notes: notes);
      await load();
      Snack.success('Loan to $name added');
      return true;
    } catch (e) {
      Snack.error(mapError(e).message);
      return false;
    } finally {
      saving.value = false;
    }
  }
}

class LoanDetailController extends GetxController {
  final LendingUseCases _uc;
  final String loanId;
  LoanDetailController(this._uc, this.loanId);

  final loan = Rxn<Loan>();
  final periods = <InterestPeriod>[].obs;
  final payments = <InterestPayment>[].obs;
  final loading = false.obs;
  final saving = false.obs;
  final error = RxnString();

  Decimal get received => InterestCalculator.totalReceived(periods);
  Decimal get pending => InterestCalculator.totalPending(periods);
  List<InterestPeriod> get unsettled => periods.where((p) => !p.isSettled).toList()..sort((a, b) => a.start.compareTo(b.start));

  Future<void> load() async {
    if (loan.value == null) loading.value = true;
    error.value = null;
    try {
      final l = await _uc.loan(loanId);
      if (l.active) await _uc.refresh();
      final r = await Future.wait([_uc.periods(loanId: loanId), _uc.payments(loanId: loanId)]);
      loan.value = l;
      periods.assignAll(r[0] as List<InterestPeriod>);
      payments.assignAll(r[1] as List<InterestPayment>);
    } catch (e) {
      error.value = mapError(e).message;
    } finally {
      loading.value = false;
    }
  }

  Future<bool> recordPayment(InterestPeriod period, Decimal amount, DateTime date, String? notes, String key) async {
    if (saving.value) return false;
    saving.value = true;
    try {
      await _uc.recordPayment(period: period, amount: amount, date: date, notes: notes, key: key);
      await load();
      Snack.success('Interest payment recorded');
      return true;
    } catch (e) {
      Snack.error(mapError(e).message);
      await load();
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> closeLoan(Decimal amount, DateTime date, String? notes) async {
    final l = loan.value;
    if (l == null || saving.value) return false;
    saving.value = true;
    try {
      await _uc.closeLoan(l, amount, date, notes);
      await load();
      Snack.success('Loan closed');
      return true;
    } catch (e) {
      Snack.error(mapError(e).message);
      await load();
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> editLoan({
    required String name,
    String? phone,
    required Decimal principal,
    required Decimal rate,
    required DateTime start,
    int? expectedDay,
    String? notes,
  }) async {
    final l = loan.value;
    if (l == null || saving.value) return false;
    saving.value = true;
    try {
      await _uc.updateLoan(l, name: name, phone: phone, rate: rate, principal: principal, start: start, expectedDay: expectedDay, notes: notes);
      await load();
      Snack.success('Loan updated. Months without payments follow the new terms.');
      return true;
    } catch (e) {
      Snack.error(mapError(e).message);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> _run(Future<void> Function() action, String ok, {bool reload = true}) async {
    if (saving.value) return false;
    saving.value = true;
    try {
      await action();
      if (reload) await load();
      Snack.success(ok);
      return true;
    } catch (e) {
      Snack.error(mapError(e).message);
      await load();
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> editPayment(InterestPayment p, Decimal amount, DateTime date, String? notes) =>
      _run(() => _uc.updatePayment(p, amount, date, notes), 'Payment updated');

  Future<bool> deletePayment(InterestPayment p) => _run(() => _uc.deletePayment(p), 'Payment deleted');

  /// Removes the loan with all its interest history and ledger entries.
  Future<bool> deleteLoan() {
    final l = loan.value;
    if (l == null) return Future.value(false);
    return _run(() => _uc.deleteLoan(l), 'Loan deleted', reload: false);
  }

  Future<bool> reopenLoan() {
    final l = loan.value;
    if (l == null) return Future.value(false);
    return _run(() => _uc.reopenLoan(l), 'Loan reopened');
  }
}
