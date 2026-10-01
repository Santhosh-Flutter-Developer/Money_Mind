import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';
import '../../presentation/bindings/initial_binding.dart';
import '../../presentation/pages/auth_pages.dart';
import '../../presentation/pages/budget_pages.dart';
import '../../presentation/pages/home_page.dart';
import '../../presentation/pages/lending_pages.dart';
import '../../presentation/pages/misc_pages.dart';
import '../../presentation/pages/onboarding_page.dart';
import '../../presentation/pages/reports_pages.dart';
import '../../presentation/pages/savings_pages.dart';
import 'app_routes.dart';

/// Sends signed-out users to the login screen.
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) =>
      Get.find<AuthUseCases>().hasSession ? null : const RouteSettings(name: AppRoutes.login);
}

class AppPages {
  static final _guard = [AuthMiddleware()];

  static GetPage<dynamic> _tab(String name, Widget Function() page) =>
      GetPage(name: name, page: page, middlewares: _guard, transition: Transition.noTransition);

  static GetPage<dynamic> _page(String name, Widget Function() page, {Bindings? binding}) =>
      GetPage(name: name, page: page, middlewares: _guard, binding: binding, transition: Transition.fadeIn);

  // NOTE: static paths must come before parameterised ones (/lending/add before /lending/:id).
  static final pages = <GetPage<dynamic>>[
    GetPage(name: AppRoutes.splash, page: () => const SplashPage()),
    GetPage(name: AppRoutes.login, page: () => const LoginPage()),
    GetPage(name: AppRoutes.register, page: () => const RegisterPage()),
    GetPage(name: AppRoutes.forgotPassword, page: () => const ForgotPasswordPage()),
    GetPage(name: AppRoutes.resetPassword, page: () => const ResetPasswordPage()),
    _page(AppRoutes.onboarding, () => const OnboardingPage()),

    _tab(AppRoutes.home, () => const HomePage()),
    _tab(AppRoutes.budget, () => const BudgetPage()),
    _tab(AppRoutes.lending, () => const LendingPage()),
    _tab(AppRoutes.savings, () => const SavingsPage()),
    _tab(AppRoutes.reports, () => const ReportsPage()),
    _tab(AppRoutes.transactions, () => const TransactionsPage()),
    _tab(AppRoutes.calendar, () => const CalendarPage()),
    _tab(AppRoutes.settings, () => const SettingsPage()),

    _page(AppRoutes.expenses, () => const TransactionsPage(preset: TxnType.expense)),
    _page(AppRoutes.expenseAdd, () => const ExpenseFormPage()),
    _page(AppRoutes.expenseEdit, () => const ExpenseFormPage()),

    _page(AppRoutes.lendingAdd, () => const LoanFormPage()),
    _page(AppRoutes.lendingPayment, () => const PaymentPage(), binding: LoanDetailBinding()),
    _page(AppRoutes.lendingDetail, () => const LoanDetailPage(), binding: LoanDetailBinding()),

    _page(AppRoutes.budgetDetail, () => const BudgetDetailPage()),
    _page(AppRoutes.savingsAdd, () => const SavingsOpPage(withdraw: false)),
    _page(AppRoutes.savingsWithdraw, () => const SavingsOpPage(withdraw: true)),

    _page(AppRoutes.reportExpenses, () => const ExpenseReportPage()),
    _page(AppRoutes.reportSavings, () => const SavingsReportPage()),
    _page(AppRoutes.reportLending, () => const LendingReportPage()),
    _page(AppRoutes.reportGeneric, () => const GenericReportPage()),
    _page(AppRoutes.reportExport, () => const ExportPage()),

    _page(AppRoutes.notifications, () => const NotificationsPage()),
    _page(AppRoutes.profile, () => const ProfilePage()),
    _page(AppRoutes.categories, () => const CategoriesPage()),
    _page(AppRoutes.recurring, () => const RecurringPage()),
    _page(AppRoutes.salarySettings, () => const SalarySettingsPage()),
  ];
}
