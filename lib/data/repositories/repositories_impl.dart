import 'package:decimal/decimal.dart';
import '../../core/error/failure.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/supabase_datasource.dart';
import '../models/mappers.dart';

String? _d(DateTime? d) => d == null ? null : Fmt.db(d);

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseDataSource _ds;
  AuthRepositoryImpl(this._ds);

  @override
  bool get hasSession => _ds.hasSession;
  @override
  Stream<bool> get sessionChanges => _ds.sessionChanges;
  @override
  Stream<bool> get recoveryEvents => _ds.recoveryEvents;
  @override
  Future<bool> signUp({required String name, required String email, required String password}) =>
      guard(() => _ds.signUp(name, email, password));
  @override
  Future<void> signIn(String email, String password) => guard(() => _ds.signIn(email, password));
  @override
  Future<void> signOut() => guard(_ds.signOut);
  @override
  Future<void> sendPasswordReset(String email) => guard(() => _ds.sendReset(email));
  @override
  Future<void> updatePassword(String password) => guard(() => _ds.updatePassword(password));
  @override
  Future<UserProfile> profile() => guard(() async => Mappers.profile(await _ds.profile()));
  @override
  Future<void> updateProfile(Map<String, dynamic> values) => guard(() => _ds.updateProfile(values));
  @override
  Future<AppSettings> settings() => guard(() async => Mappers.settings(await _ds.settings()));
  @override
  Future<void> updateSettings(Map<String, dynamic> values) => guard(() => _ds.updateSettings(values));
  @override
  Future<void> seedDemoData() => guard(_ds.seedDemo);
}

class BudgetRepositoryImpl implements BudgetRepository {
  final SupabaseDataSource _ds;
  BudgetRepositoryImpl(this._ds);

  @override
  Future<List<ExpenseCategory>> categories() => guard(() async => (await _ds.categories()).map(Mappers.category).toList());
  @override
  Future<void> addCategory(String name, String icon) => guard(() => _ds.addCategory(name, icon));
  @override
  Future<void> renameCategory(String id, String name) => guard(() => _ds.renameCategory(id, name));
  @override
  Future<void> deleteCategory(String id) => guard(() => _ds.deleteCategory(id));

  @override
  Future<List<RecurringExpense>> recurring() => guard(() async => (await _ds.recurring()).map(Mappers.recurring).toList());
  @override
  Future<void> saveRecurring(RecurringExpense? existing, Map<String, dynamic> values) =>
      guard(() => existing == null ? _ds.insertRecurring(values) : _ds.updateRecurring(existing.id, values));
  @override
  Future<void> deleteRecurring(String id) => guard(() => _ds.deleteRecurring(id));

  @override
  Future<MonthlyBudget> ensureBudget(DateTime start, DateTime end) => guard(() async {
        final b = await _ds.ensureBudget(Fmt.db(start), Fmt.db(end));
        final summary = await _ds.budgetSummaryById(b['id'] as String);
        return Mappers.budget(summary ?? b);
      });

  @override
  Future<MonthlyBudget?> budgetByStart(DateTime start) => guard(() async {
        final j = await _ds.budgetSummaryByStart(Fmt.db(start));
        return j == null ? null : Mappers.budget(j);
      });

  @override
  Future<MonthlyBudget?> budgetById(String id) => guard(() async {
        final j = await _ds.budgetSummaryById(id);
        return j == null ? null : Mappers.budget(j);
      });

  @override
  Future<List<MonthlyBudget>> budgets({DateTime? from, DateTime? to}) =>
      guard(() async => (await _ds.budgetSummaries(_d(from), _d(to))).map(Mappers.budget).toList());

  @override
  Future<List<BudgetItem>> items(String budgetId) => guard(() async => (await _ds.items(budgetId)).map(Mappers.item).toList());
  @override
  Future<void> addItem(String budgetId, Map<String, dynamic> values) => guard(() => _ds.insertItem(budgetId, values));
  @override
  Future<void> updateItem(String id, Map<String, dynamic> values) => guard(() => _ds.updateItem(id, values));
  @override
  Future<void> deleteItem(String id) => guard(() => _ds.deleteItem(id));
  @override
  Future<void> completeItem(String id) => guard(() => _ds.completeItem(id));
  @override
  Future<void> undoItem(String id) => guard(() => _ds.undoItem(id));
  @override
  Future<void> updateSalary(String budgetId, Decimal salary) => guard(() => _ds.updateSalary(budgetId, MoneyUtils.toDb(salary)));
  @override
  Future<void> addIncome({required String budgetId, required Decimal amount, required DateTime date, required String description}) =>
      guard(() => _ds.addIncome(budgetId, MoneyUtils.toDb(amount), Fmt.db(date), description));
  @override
  Future<void> closeBudget(String budgetId) => guard(() => _ds.closeBudget(budgetId));
  @override
  Future<void> reopenBudget(String budgetId) => guard(() => _ds.reopenBudget(budgetId));
  @override
  Future<void> deleteBudget(String budgetId) => guard(() => _ds.deleteBudget(budgetId));
  @override
  Future<List<MoneyTxn>> incomes(String budgetId) => guard(() async => (await _ds.incomes(budgetId)).map(Mappers.txn).toList());
  @override
  Future<void> updateIncome(String id, {required Decimal amount, required DateTime date, required String description}) =>
      guard(() => _ds.updateIncome(id, {'amount': MoneyUtils.toDb(amount), 'txn_date': Fmt.db(date), 'description': description}));
  @override
  Future<void> deleteIncome(String id) => guard(() => _ds.deleteIncome(id));
  @override
  Future<BudgetItem?> itemById(String id) => guard(() async {
        final j = await _ds.itemById(id);
        return j == null ? null : Mappers.item(j);
      });
}

class SavingsRepositoryImpl implements SavingsRepository {
  final SupabaseDataSource _ds;
  SavingsRepositoryImpl(this._ds);

  @override
  Future<SavingsWallet> wallet() => guard(() async => Mappers.wallet(await _ds.wallet()));
  @override
  Future<List<SavingsTxn>> transactions({DateTime? from, DateTime? to}) =>
      guard(() async => (await _ds.savingsTransactions(_d(from), _d(to))).map(Mappers.savingsTxn).toList());
  @override
  Future<void> operate({
    required String type,
    required Decimal amount,
    required DateTime date,
    required String description,
    String? notes,
    required String key,
  }) =>
      guard(() => _ds.savingsOperation({
            'p_type': type,
            'p_amount': MoneyUtils.toDb(amount),
            'p_date': Fmt.db(date),
            'p_description': description,
            'p_notes': notes,
            'p_key': key,
          }));
  @override
  Future<SavingsTxn?> transactionById(String id) => guard(() async {
        final j = await _ds.savingsTxnById(id);
        return j == null ? null : Mappers.savingsTxn(j);
      });
  @override
  Future<void> updateTransaction({required String id, required Decimal amount, required DateTime date, required String description, String? notes}) =>
      guard(() => _ds.updateSavingsTxn({
            'p_id': id,
            'p_amount': MoneyUtils.toDb(amount),
            'p_date': Fmt.db(date),
            'p_description': description,
            'p_notes': notes,
          }));
  @override
  Future<void> deleteTransaction(String id) => guard(() => _ds.deleteSavingsTxn(id));
}

class LendingRepositoryImpl implements LendingRepository {
  final SupabaseDataSource _ds;
  LendingRepositoryImpl(this._ds);

  @override
  Future<void> refreshPeriods() => guard(_ds.refreshPeriods);
  @override
  Future<List<Loan>> loans() => guard(() async => (await _ds.loans()).map(Mappers.loan).toList());
  @override
  Future<Loan> loan(String id) => guard(() async => Mappers.loan(await _ds.loan(id)));
  @override
  Future<void> createLoan(Map<String, dynamic> values) => guard(() => _ds.createLoan(values));
  @override
  Future<void> updateLoan(String id, Map<String, dynamic> values) => guard(() => _ds.updateLoan({...values, 'p_loan_id': id}));
  @override
  Future<void> deleteLoan(String id) => guard(() => _ds.deleteLoan(id));
  @override
  Future<void> reopenLoan(String id) => guard(() => _ds.reopenLoan(id));
  @override
  Future<void> updatePayment({required String id, required Decimal amount, required DateTime date, String? notes}) =>
      guard(() => _ds.updatePayment({'p_payment_id': id, 'p_amount': MoneyUtils.toDb(amount), 'p_date': Fmt.db(date), 'p_notes': notes}));
  @override
  Future<void> deletePayment(String id) => guard(() => _ds.deletePayment(id));
  @override
  Future<List<InterestPeriod>> periods({String? loanId}) =>
      guard(() async => (await _ds.periods(loanId)).map(Mappers.period).toList());
  @override
  Future<List<InterestPayment>> payments({String? loanId, DateTime? from, DateTime? to}) =>
      guard(() async => (await _ds.payments(loanId, _d(from), _d(to))).map(Mappers.payment).toList());
  @override
  Future<void> recordPayment({
    required String periodId,
    required Decimal amount,
    required DateTime date,
    String? notes,
    required String key,
  }) =>
      guard(() => _ds.recordPayment({
            'p_period_id': periodId,
            'p_amount': MoneyUtils.toDb(amount),
            'p_date': Fmt.db(date),
            'p_notes': notes,
            'p_key': key,
          }));
  @override
  Future<void> closeLoan({required String loanId, required Decimal amount, required DateTime date, String? notes}) =>
      guard(() => _ds.closeLoan({
            'p_loan_id': loanId,
            'p_amount': MoneyUtils.toDb(amount),
            'p_date': Fmt.db(date),
            'p_notes': notes,
          }));
}

class TransactionRepositoryImpl implements TransactionRepository {
  final SupabaseDataSource _ds;
  TransactionRepositoryImpl(this._ds);

  @override
  Future<List<MoneyTxn>> query(TxnFilter f) => guard(() async {
        final rows = await _ds.transactions(
          type: f.type?.name,
          search: f.search,
          categoryId: f.categoryId,
          from: _d(f.from),
          to: _d(f.to),
          min: f.minAmount == null ? null : MoneyUtils.toDb(f.minAmount!),
          max: f.maxAmount == null ? null : MoneyUtils.toDb(f.maxAmount!),
          limit: f.limit,
        );
        return rows.map(Mappers.txn).toList();
      });
}
