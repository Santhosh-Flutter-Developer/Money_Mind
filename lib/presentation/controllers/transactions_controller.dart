import 'package:get/get.dart';
import '../../core/error/failure.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';
import 'app_events.dart';
import 'auth_controller.dart';

class TransactionsController extends GetxController {
  final TransactionUseCases _uc;
  final BudgetUseCases _budget;
  final AuthController _auth;
  TransactionsController(this._uc, this._budget, this._auth);

  final all = <MoneyTxn>[].obs;
  final categories = <ExpenseCategory>[].obs;
  final type = Rxn<TxnType>();
  final categoryId = RxnString();
  final from = Rxn<DateTime>();
  final to = Rxn<DateTime>();
  final search = ''.obs;
  final loading = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    ever(Get.find<AppEvents>().logoutTick, (_) => all.clear());
  }

  String get currency => _auth.currency;

  /// Search runs locally over description, category and type (person names live in descriptions).
  List<MoneyTxn> get visible {
    final q = search.value.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((t) =>
            t.description.toLowerCase().contains(q) ||
            (t.categoryName ?? '').toLowerCase().contains(q) ||
            t.type.name.contains(q))
        .toList();
  }

  bool get hasFilters => type.value != null || categoryId.value != null || from.value != null || to.value != null;

  void clearFilters() {
    type.value = null;
    categoryId.value = null;
    from.value = null;
    to.value = null;
    load();
  }

  Future<void> load() async {
    if (all.isEmpty) loading.value = true;
    error.value = null;
    try {
      if (categories.isEmpty) categories.assignAll(await _budget.categories());
      all.assignAll(await _uc.query(TxnFilter(
        type: type.value,
        categoryId: categoryId.value,
        from: from.value,
        to: to.value,
        limit: 1000,
      )));
    } catch (e) {
      error.value = mapError(e).message;
    } finally {
      loading.value = false;
    }
  }
}
