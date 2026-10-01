import 'package:decimal/decimal.dart';
import 'package:get/get.dart';
import '../../core/error/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/snack.dart';
import '../../domain/usecases/usecases.dart';
import 'auth_controller.dart';

class DraftExpense {
  String name;
  Decimal amount;
  int? dueDay;
  DraftExpense(this.name, this.amount, this.dueDay);
}

class OnboardingController extends GetxController {
  final AuthController _auth;
  final BudgetUseCases _budget;
  OnboardingController(this._auth, this._budget);

  static const steps = 5;
  final step = 0.obs;
  final salary = Rxn<Decimal>();
  final salaryDay = 1.obs;
  final expenses = <DraftExpense>[].obs;
  final wantsToLend = false.obs;
  final goal = Rxn<Decimal>();
  final goalDate = Rxn<DateTime>();
  final saving = false.obs;

  void next() {
    if (step.value < steps - 1) step.value++;
  }

  void back() {
    if (step.value > 0) step.value--;
  }

  Future<void> skip() => finish(skipped: true);

  Future<void> finish({bool skipped = false}) async {
    if (saving.value) return;
    saving.value = true;
    try {
      final values = <String, dynamic>{'onboarded': true};
      if (!skipped) {
        values['salary_day'] = salaryDay.value;
        if (salary.value != null) values['default_salary'] = MoneyUtils.toDb(salary.value!);
        if (goal.value != null && goal.value! > Decimal.zero) {
          values['savings_goal'] = MoneyUtils.toDb(goal.value!);
          values['savings_goal_date'] = goalDate.value == null ? null : Fmt.db(goalDate.value!);
        }
      }
      final ok = await _auth.saveProfile(values);
      if (!ok) return;
      if (!skipped) {
        
        for (final e in expenses) {
          try {
            await _budget.saveRecurring(
                name: e.name, categoryId: null, amount: e.amount, dueDay: e.dueDay, active: true, all: const []);

          } catch (err) {
            Snack.error('${e.name}: ${mapError(err).message}');
          }
        }
      }
      Get.offAllNamed(AppRoutes.home);
      if (!skipped && wantsToLend.value) Get.toNamed(AppRoutes.lendingAdd);
    } catch (e) {
      Snack.error(mapError(e).message);
    } finally {
      saving.value = false;
    }
  }
}
