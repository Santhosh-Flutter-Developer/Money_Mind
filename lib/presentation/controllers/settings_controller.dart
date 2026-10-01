import 'package:decimal/decimal.dart';
import 'package:get/get.dart';
import '../../core/error/failure.dart';
import '../../core/widgets/snack.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';
import 'app_events.dart';

class SettingsController extends GetxController {
  final BudgetUseCases _uc;
  SettingsController(this._uc);

  final categories = <ExpenseCategory>[].obs;
  final recurring = <RecurringExpense>[].obs;
  final loading = false.obs;
  final saving = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    ever(Get.find<AppEvents>().logoutTick, (_) {
      categories.clear();
      recurring.clear();
    });
  }

  Future<void> load() async {
    if (categories.isEmpty && recurring.isEmpty) loading.value = true;
    error.value = null;
    try {
      final r = await Future.wait([_uc.categories(), _uc.recurring()]);
      categories.assignAll(r[0] as List<ExpenseCategory>);
      recurring.assignAll(r[1] as List<RecurringExpense>);
    } catch (e) {
      error.value = mapError(e).message;
    } finally {
      loading.value = false;
    }
  }

  Future<bool> _run(Future<void> Function() action, String ok) async {
    if (saving.value) return false;
    saving.value = true;
    try {
      await action();
      await load();
      Snack.success(ok);
      return true;
    } catch (e) {
      Snack.error(mapError(e).message);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> addCategory(String name) => _run(() => _uc.addCategory(name, 'category', categories), 'Category added');
  Future<bool> renameCategory(ExpenseCategory c, String name) => _run(() => _uc.renameCategory(c.id, name), 'Category renamed');
  Future<bool> deleteCategory(ExpenseCategory c) => _run(() => _uc.deleteCategory(c.id), 'Category deleted');

  Future<bool> saveRecurring({
    RecurringExpense? existing,
    required String name,
    required String? categoryId,
    required Decimal amount,
    required int? dueDay,
    required bool active,
    String? notes,
  }) =>
      _run(
          () => _uc.saveRecurring(
              existing: existing,
              name: name,
              categoryId: categoryId,
              amount: amount,
              dueDay: dueDay,
              active: active,
              notes: notes,
              all: recurring),
          'Recurring expense saved. It applies from the next cycle.');

  Future<bool> deleteRecurring(RecurringExpense r) => _run(() => _uc.deleteRecurring(r.id), 'Recurring expense deleted');
}
