import 'package:decimal/decimal.dart';
import '../entities/entities.dart';

abstract class AuthRepository {
  bool get hasSession;
  Stream<bool> get sessionChanges;
  Stream<bool> get recoveryEvents;
  Future<bool> signUp({required String name, required String email, required String password});
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<UserProfile> profile();
  Future<void> updateProfile(Map<String, dynamic> values);
  Future<AppSettings> settings();
  Future<void> updateSettings(Map<String, dynamic> values);
  Future<void> seedDemoData();
}

abstract class BudgetRepository {
  Future<List<ExpenseCategory>> categories();
  Future<void> addCategory(String name, String icon);
  Future<void> renameCategory(String id, String name);
  Future<void> deleteCategory(String id);

  Future<List<RecurringExpense>> recurring();
  Future<void> saveRecurring(RecurringExpense? existing, Map<String, dynamic> values);
  Future<void> deleteRecurring(String id);

  Future<MonthlyBudget> ensureBudget(DateTime start, DateTime end);
  Future<MonthlyBudget?> budgetByStart(DateTime start);
  Future<MonthlyBudget?> budgetById(String id);
  Future<List<MonthlyBudget>> budgets({DateTime? from, DateTime? to});
  Future<List<BudgetItem>> items(String budgetId);
  Future<void> addItem(String budgetId, Map<String, dynamic> values);
  Future<void> updateItem(String id, Map<String, dynamic> values);
  Future<void> deleteItem(String id);
  Future<void> completeItem(String id);
  Future<void> undoItem(String id);
  Future<void> updateSalary(String budgetId, Decimal salary);
  Future<void> addIncome({required String budgetId, required Decimal amount, required DateTime date, required String description});
  Future<void> closeBudget(String budgetId);
  Future<void> reopenBudget(String budgetId);
  Future<void> deleteBudget(String budgetId);
  Future<List<MoneyTxn>> incomes(String budgetId);
  Future<void> updateIncome(String id, {required Decimal amount, required DateTime date, required String description});
  Future<void> deleteIncome(String id);
  Future<BudgetItem?> itemById(String id);
}

abstract class SavingsRepository {
  Future<SavingsWallet> wallet();
  Future<List<SavingsTxn>> transactions({DateTime? from, DateTime? to});
  Future<void> operate({
    required String type,
    required Decimal amount,
    required DateTime date,
    required String description,
    String? notes,
    required String key,
  });
  Future<SavingsTxn?> transactionById(String id);
  Future<void> updateTransaction({required String id, required Decimal amount, required DateTime date, required String description, String? notes});
  Future<void> deleteTransaction(String id);
}

abstract class LendingRepository {
  Future<void> refreshPeriods();
  Future<List<Loan>> loans();
  Future<Loan> loan(String id);
  Future<void> createLoan(Map<String, dynamic> values);
  Future<void> updateLoan(String id, Map<String, dynamic> values);
  Future<List<InterestPeriod>> periods({String? loanId});
  Future<List<InterestPayment>> payments({String? loanId, DateTime? from, DateTime? to});
  Future<void> recordPayment({
    required String periodId,
    required Decimal amount,
    required DateTime date,
    String? notes,
    required String key,
  });
  Future<void> closeLoan({required String loanId, required Decimal amount, required DateTime date, String? notes});
  Future<void> deleteLoan(String id);
  Future<void> reopenLoan(String id);
  Future<void> updatePayment({required String id, required Decimal amount, required DateTime date, String? notes});
  Future<void> deletePayment(String id);
}

abstract class TransactionRepository {
  Future<List<MoneyTxn>> query(TxnFilter filter);
}
