import 'package:get/get.dart';
import '../../core/services/supabase_service.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/repositories/repositories_impl.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/usecases/usecases.dart';
import '../controllers/app_events.dart';
import '../controllers/auth_controller.dart';
import '../controllers/budget_controller.dart';
import '../controllers/calendar_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/lending_controller.dart';
import '../controllers/onboarding_controller.dart';
import '../controllers/reports_controller.dart';
import '../controllers/savings_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/transactions_controller.dart';

/// Dependency injection: datasource -> repositories -> use cases -> controllers.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AppEvents(), permanent: true);
    final ds = SupabaseDataSource(SupabaseService.client);
    Get.put<AuthRepository>(AuthRepositoryImpl(ds), permanent: true);
    Get.put<BudgetRepository>(BudgetRepositoryImpl(ds), permanent: true);
    Get.put<SavingsRepository>(SavingsRepositoryImpl(ds), permanent: true);
    Get.put<LendingRepository>(LendingRepositoryImpl(ds), permanent: true);
    Get.put<TransactionRepository>(TransactionRepositoryImpl(ds), permanent: true);

    Get.put(AuthUseCases(Get.find()), permanent: true);
    Get.put(BudgetUseCases(Get.find()), permanent: true);
    Get.put(SavingsUseCases(Get.find()), permanent: true);
    Get.put(LendingUseCases(Get.find()), permanent: true);
    Get.put(TransactionUseCases(Get.find()), permanent: true);
    Get.put(ReportUseCases(Get.find<BudgetRepository>(), Get.find<SavingsRepository>(),
        Get.find<LendingRepository>(), Get.find<TransactionRepository>()), permanent: true);

    Get.put(AuthController(Get.find(), Get.find()), permanent: true);
    Get.lazyPut(() => HomeController(Get.find(), Get.find(), Get.find(), Get.find()), fenix: true);
    Get.lazyPut(() => BudgetController(Get.find(), Get.find()), fenix: true);
    Get.lazyPut(() => LendingController(Get.find(), Get.find()), fenix: true);
    Get.lazyPut(() => SavingsController(Get.find(), Get.find()), fenix: true);
    Get.lazyPut(() => TransactionsController(Get.find(), Get.find(), Get.find()), fenix: true);
    Get.lazyPut(() => ReportsController(Get.find(), Get.find(), Get.find()), fenix: true);
    Get.lazyPut(() => CalendarController(Get.find(), Get.find(), Get.find(), Get.find()), fenix: true);
    Get.lazyPut(() => SettingsController(Get.find()), fenix: true);
    Get.lazyPut(() => OnboardingController(Get.find(), Get.find()), fenix: true);
  }
}

class LoanDetailBinding extends Bindings {
  @override
  void dependencies() {
    final id = Get.parameters['id']!;
    Get.lazyPut(() => LoanDetailController(Get.find(), id), tag: id);
  }
}
