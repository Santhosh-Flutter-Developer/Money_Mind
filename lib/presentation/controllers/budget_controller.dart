import 'package:decimal/decimal.dart';
import 'package:get/get.dart';
import '../../core/error/failure.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/snack.dart';
import '../../domain/entities/entities.dart';
import '../../domain/services/budget_logic.dart';
import '../../domain/services/cycle_calculator.dart';
import '../../domain/usecases/usecases.dart';
import 'app_events.dart';
import 'auth_controller.dart';

class BudgetController extends GetxController {
  final BudgetUseCases _uc;
  final AuthController _auth;
  BudgetController(this._uc, this._auth);

  final period = Rxn<BudgetPeriod>();
  final budget = Rxn<MonthlyBudget>();
  final items = <BudgetItem>[].obs;
  final categories = <ExpenseCategory>[].obs;
  final filter = 'all'.obs; // all | pending | completed
  final search = ''.obs;
  final loading = false.obs;
  final saving = false.obs;
  final error = RxnString();
  final canCreate = false.obs;
  final busyIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    ever(Get.find<AppEvents>().logoutTick, (_) => _reset());
  }

  void _reset() {
    period.value = null;
    budget.value = null;
    items.clear();
    categories.clear();
  }

  BudgetPeriod get current => _auth.currentPeriod;
  bool get isCurrent => period.value == current;
  String get currency => _auth.currency;

  BudgetSummary? get summary {
    final b = budget.value;
    if (b == null) return null;
    return BudgetCalculator.summarize(salary: b.salary, extraIncome: b.extraIncome, items: items);
  }

  List<BudgetItem> get visible {
    final q = search.value.trim().toLowerCase();
    return items.where((i) {
      final okFilter = filter.value == 'all' ||
          (filter.value == 'pending' && i.isPending) ||
          (filter.value == 'completed' && i.isCompleted);
      final okSearch = q.isEmpty || i.name.toLowerCase().contains(q) || (i.categoryName ?? '').toLowerCase().contains(q);
      return okFilter && okSearch;
    }).toList();
  }

  Future<void> load({BudgetPeriod? target}) async {
    final p = target ?? period.value ?? current;
    period.value = p;
    if (budget.value == null) loading.value = true;
    error.value = null;
    try {
      if (categories.isEmpty) categories.assignAll(await _uc.categories());
      MonthlyBudget? b;
      if (p == current) {
        b = await _uc.ensureBudget(p); // creates the cycle + recurring items once
      } else {
        b = await _uc.budgetFor(p);
      }
      budget.value = b;
      canCreate.value = b == null && !p.start.isAfter(Fmt.today());
      items.assignAll(b == null ? <BudgetItem>[] : await _uc.items(b.id));
    } catch (e) {
      error.value = mapError(e).message;
    } finally {
      loading.value = false;
    }
  }

  Future<void> createForPeriod() async {
    final p = period.value;
    if (p == null) return;
    saving.value = true;
    try {
      await _uc.ensureBudget(p);
      await load(target: p);
    } catch (e) {
      Snack.error(mapError(e).message);
    } finally {
      saving.value = false;
    }
  }

  Future<void> previous() => load(
      target: CycleCalculator.previous(period.value ?? current, salaryDay: _auth.salaryDay, mode: _auth.cycleMode));
  Future<void> next() => load(
      target: CycleCalculator.next(period.value ?? current, salaryDay: _auth.salaryDay, mode: _auth.cycleMode));

  /// Optimistic: numbers update instantly, and roll back if the server rejects.
  Future<bool> complete(BudgetItem item) async {
    if (busyIds.contains(item.id) || item.isCompleted) return false;
    busyIds.add(item.id);
    final before = List<BudgetItem>.of(items);
    items.assignAll(BudgetCalculator.complete(items, item.id));
    try {
      await _uc.completeItem(item);
      return true;
    } catch (e) {
      items.assignAll(before);
      Snack.error(mapError(e).message);
      return false;
    } finally {
      busyIds.remove(item.id);
    }
  }

  Future<bool> undo(BudgetItem item) async {
    if (busyIds.contains(item.id) || !item.isCompleted) return false;
    busyIds.add(item.id);
    final before = List<BudgetItem>.of(items);
    items.assignAll(BudgetCalculator.undo(items, item.id));
    try {
      await _uc.undoItem(item);
      return true;
    } catch (e) {
      items.assignAll(before);
      Snack.error(mapError(e).message);
      return false;
    } finally {
      busyIds.remove(item.id);
    }
  }

  Future<bool> saveItem({
    BudgetItem? existing,
    required String name,
    required Decimal amount,
    required String? categoryId,
    required DateTime date,
    String? notes,
  }) async {
    final b = budget.value;
    if (b == null || saving.value) return false;
    saving.value = true;
    try {
      if (existing == null) {
        await _uc.addItem(budget: b, name: name, amount: amount, categoryId: categoryId, date: date, notes: notes);
      } else {
        await _uc.updateItem(existing, name: name, amount: amount, categoryId: categoryId, date: date, notes: notes);
      }
      await load(target: period.value);
      return true;
    } catch (e) {
      Snack.error(mapError(e).message);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<void> deleteItem(BudgetItem item) async {
    try {
      await _uc.deleteItem(item);
      items.removeWhere((i) => i.id == item.id);
      Snack.success('${item.name} deleted');
    } catch (e) {
      Snack.error(mapError(e).message);
    }
  }

  Future<bool> addIncome(Decimal amount, DateTime date, String description) async {
    final b = budget.value;
    if (b == null || saving.value) return false;
    saving.value = true;
    try {
      await _uc.addIncome(b, amount, date, description);
      await load(target: period.value);
      Snack.success('Income added');
      return true;
    } catch (e) {
      Snack.error(mapError(e).message);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> updateSalary(Decimal salary) async {
    final b = budget.value;
    if (b == null) return false;
    saving.value = true;
    try {
      await _uc.updateSalary(b.id, salary);
      await load(target: period.value);
      return true;
    } catch (e) {
      Snack.error(mapError(e).message);
      return false;
    } finally {
      saving.value = false;
    }
  }

  ClosePreview? get closePreview {
    final b = budget.value;
    return b == null ? null : _uc.closePreview(b, items);
  }

  Future<bool> closeCycle() async {
    final b = budget.value;
    if (b == null || saving.value) return false;
    saving.value = true;
    try {
      await _uc.closeBudget(b);
      await load(target: period.value);
      Snack.success('${b.period.label} closed. Savings updated.');
      return true;
    } catch (e) {
      Snack.error(mapError(e).message);
      await load(target: period.value);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<List<MonthlyBudget>> history() => _uc.budgets();
}
