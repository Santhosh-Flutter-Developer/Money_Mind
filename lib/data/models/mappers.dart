import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/entities.dart';

typedef Json = Map<String, dynamic>;

/// JSON <-> entity mapping. Money is parsed via Decimal, never double.
class Mappers {
  static String? _catName(Json j) => (j['categories'] as Map?)?['name'] as String?;

  static UserProfile profile(Json j) => UserProfile(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        currency: (j['currency'] ?? 'INR') as String,
        salaryDay: (j['salary_day'] ?? 1) as int,
        defaultSalary: MoneyUtils.parse(j['default_salary']),
        cycleMode: (j['cycle_mode'] ?? 'salary_cycle') as String,
        avatarUrl: j['avatar_url'] as String?,
        savingsGoal: j['savings_goal'] == null ? null : MoneyUtils.parse(j['savings_goal']),
        savingsGoalDate: Fmt.tryParseDate(j['savings_goal_date']),
        onboarded: (j['onboarded'] ?? false) as bool,
      );

  static AppSettings settings(Json? j) => j == null
      ? const AppSettings()
      : AppSettings(
          expenseReminders: (j['expense_reminders'] ?? true) as bool,
          interestReminders: (j['interest_reminders'] ?? true) as bool,
          salaryReminder: (j['salary_reminder'] ?? true) as bool,
          closingReminder: (j['closing_reminder'] ?? true) as bool,
          themeMode: (j['theme_mode'] ?? 'system') as String,
        );

  static ExpenseCategory category(Json j) => ExpenseCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: (j['icon'] ?? 'category') as String,
        isDefault: (j['is_default'] ?? false) as bool,
      );

  static RecurringExpense recurring(Json j) => RecurringExpense(
        id: j['id'] as String,
        name: j['name'] as String,
        categoryId: j['category_id'] as String?,
        categoryName: _catName(j),
        amount: MoneyUtils.parse(j['amount']),
        dueDay: j['due_day'] as int?,
        isActive: (j['is_active'] ?? true) as bool,
        notes: j['notes'] as String?,
      );

  static MonthlyBudget budget(Json j) => MonthlyBudget(
        id: j['id'] as String,
        periodStart: Fmt.parseDate(j['period_start']),
        periodEnd: Fmt.parseDate(j['period_end']),
        salary: MoneyUtils.parse(j['salary']),
        closed: j['status'] == 'closed',
        closedAt: j['closed_at'] == null ? null : DateTime.parse(j['closed_at'] as String).toLocal(),
        savingsTransferred: MoneyUtils.parse(j['savings_transferred']),
        planned: MoneyUtils.parse(j['planned']),
        spent: MoneyUtils.parse(j['spent']),
        pending: MoneyUtils.parse(j['pending']),
        extraIncome: MoneyUtils.parse(j['extra_income']),
      );

  static BudgetItem item(Json j) => BudgetItem(
        id: j['id'] as String,
        budgetId: j['budget_id'] as String,
        categoryId: j['category_id'] as String?,
        categoryName: _catName(j),
        recurringId: j['recurring_id'] as String?,
        name: j['name'] as String,
        amount: MoneyUtils.parse(j['amount']),
        dueDate: Fmt.tryParseDate(j['due_date']),
        isRecurring: (j['is_recurring'] ?? false) as bool,
        status: ItemStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => ItemStatus.pending),
        completedAt: j['completed_at'] == null ? null : DateTime.parse(j['completed_at'] as String).toLocal(),
        notes: j['notes'] as String?,
      );

  static MoneyTxn txn(Json j) => MoneyTxn(
        id: j['id'] as String,
        type: TxnType.values.firstWhere((t) => t.name == j['type']),
        direction: switch (j['direction']) {
          'in' => TxnDirection.inflow,
          'out' => TxnDirection.outflow,
          _ => TxnDirection.neutral,
        },
        amount: MoneyUtils.parse(j['amount']),
        date: Fmt.parseDate(j['txn_date']),
        description: (j['description'] ?? '') as String,
        categoryId: j['category_id'] as String?,
        categoryName: _catName(j),
        refType: j['ref_type'] as String?,
        refId: j['ref_id'] as String?,
      );

  static SavingsWallet wallet(Json j) =>
      SavingsWallet(id: j['id'] as String, balance: MoneyUtils.parse(j['balance']));

  static SavingsTxn savingsTxn(Json j) => SavingsTxn(
        id: j['id'] as String,
        type: switch (j['type']) {
          'monthly_savings' => SavingsTxnType.monthlySavings,
          'withdrawal' => SavingsTxnType.withdrawal,
          'adjustment' => SavingsTxnType.adjustment,
          _ => SavingsTxnType.deposit,
        },
        amount: MoneyUtils.parse(j['amount']),
        date: Fmt.parseDate(j['txn_date']),
        description: (j['description'] ?? '') as String,
        month: j['month_label'] as String?,
        notes: j['notes'] as String?,
      );

  static Loan loan(Json j) => Loan(
        id: j['id'] as String,
        personName: j['person_name'] as String,
        phone: j['phone'] as String?,
        principal: MoneyUtils.parse(j['principal']),
        rate: MoneyUtils.parse(j['rate']),
        interestType: (j['interest_type'] ?? 'monthly_percentage') as String,
        startDate: Fmt.parseDate(j['start_date']),
        expectedDay: j['expected_day'] as int?,
        notes: j['notes'] as String?,
        active: j['status'] == 'active',
        principalReturned: MoneyUtils.parse(j['principal_returned']),
        closedOn: Fmt.tryParseDate(j['closed_on']),
      );

  static InterestPeriod period(Json j) => InterestPeriod(
        id: j['id'] as String,
        loanId: j['loan_id'] as String,
        start: Fmt.parseDate(j['period_start']),
        end: Fmt.parseDate(j['period_end']),
        due: Fmt.parseDate(j['due_date']),
        expected: MoneyUtils.parse(j['expected_amount']),
        paid: MoneyUtils.parse(j['paid_amount']),
        storedStatus: InterestStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => InterestStatus.pending),
      );

  static InterestPayment payment(Json j) => InterestPayment(
        id: j['id'] as String,
        loanId: j['loan_id'] as String,
        periodId: j['period_id'] as String,
        amount: MoneyUtils.parse(j['amount']),
        date: Fmt.parseDate(j['payment_date']),
        notes: j['notes'] as String?,
      );
}
