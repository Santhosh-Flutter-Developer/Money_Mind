import 'package:decimal/decimal.dart';
import 'package:get/get.dart';
import '../../core/error/failure.dart';
import '../../core/widgets/snack.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';
import 'app_events.dart';
import 'auth_controller.dart';

class SavingsController extends GetxController {
  final SavingsUseCases _uc;
  final AuthController _auth;
  SavingsController(this._uc, this._auth);

  final wallet = Rxn<SavingsWallet>();
  final txns = <SavingsTxn>[].obs;
  final loading = false.obs;
  final saving = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    ever(Get.find<AppEvents>().logoutTick, (_) {
      wallet.value = null;
      txns.clear();
    });
  }

  String get currency => _auth.currency;
  Decimal get balance => wallet.value?.balance ?? Decimal.zero;

  /// 0..1 progress towards the optional savings goal.
  double? get goalProgress {
    final goal = _auth.profile.value?.savingsGoal;
    if (goal == null || goal <= Decimal.zero) return null;
    return (balance / goal).toDecimal(scaleOnInfinitePrecision: 4).toDouble().clamp(0.0, 1.0).toDouble();
  }

  Decimal? get goalRemaining {
    final goal = _auth.profile.value?.savingsGoal;
    if (goal == null) return null;
    final r = goal - balance;
    return r < Decimal.zero ? Decimal.zero : r;
  }

  Future<void> load() async {
    if (wallet.value == null) loading.value = true;
    error.value = null;
    try {
      final r = await Future.wait([_uc.wallet(), _uc.transactions()]);
      wallet.value = r[0] as SavingsWallet;
      txns.assignAll(r[1] as List<SavingsTxn>);
    } catch (e) {
      error.value = mapError(e).message;
    } finally {
      loading.value = false;
    }
  }

  Future<bool> deposit(Decimal amount, DateTime date, String description, String? notes, String key) =>
      _run(() => _uc.deposit(amount, date, description, notes, key), 'Deposit added');

  Future<bool> withdraw(Decimal amount, DateTime date, String description, String? notes, String key) {
    final w = wallet.value;
    if (w == null) return Future.value(false);
    return _run(() => _uc.withdraw(w, amount, date, description, notes, key), 'Withdrawal recorded');
  }

  Future<bool> updateTx(SavingsTxn t, Decimal amount, DateTime date, String description, String? notes) =>
      _run(() => _uc.updateTx(t, amount, date, description, notes), 'Entry updated');

  Future<bool> deleteTx(SavingsTxn t) => _run(() => _uc.deleteTx(t), 'Entry deleted');

  Future<bool> _run(Future<void> Function() action, String okMessage) async {
    if (saving.value) return false;
    saving.value = true;
    try {
      await action();
      await load();
      Snack.success(okMessage);
      return true;
    } catch (e) {
      Snack.error(mapError(e).message);
      return false;
    } finally {
      saving.value = false;
    }
  }
}
