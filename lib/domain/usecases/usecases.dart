import 'package:decimal/decimal.dart';
import '../../core/error/failure.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../entities/entities.dart';
import '../repositories/repositories.dart';
import '../services/budget_logic.dart';
import '../services/lending_logic.dart';
import '../services/report_calculator.dart';

Failure _invalid(String m) => Failure(m, FailureType.validation);

// ------------------------------------------------------------- auth
class AuthUseCases {
  final AuthRepository _repo;
  AuthUseCases(this._repo);

  bool get hasSession => _repo.hasSession;
  Stream<bool> get sessionChanges => _repo.sessionChanges;
  Stream<bool> get recoveryEvents => _repo.recoveryEvents;

  /// Returns true when a session exists right away (no email confirmation needed).
  Future<bool> signUp(String name, String email, String password) {
    if (name.trim().isEmpty) throw _invalid('Name is required');
    return _repo.signUp(name: name.trim(), email: email.trim(), password: password);
  }

  Future<void> signIn(String email, String password) => _repo.signIn(email.trim(), password);
  Future<void> signOut() => _repo.signOut();
  Future<void> sendReset(String email) => _repo.sendPasswordReset(email.trim());
  Future<void> updatePassword(String p) => _repo.updatePassword(p);
  Future<UserProfile> profile() => _repo.profile();
  Future<void> updateProfile(Map<String, dynamic> v) => _repo.updateProfile(v);
  Future<AppSettings> settings() => _repo.settings();
  Future<void> updateSettings(Map<String, dynamic> v) => _repo.updateSettings(v);
  Future<void> seedDemo() => _repo.seedDemoData();
}

// ----------------------------------------------------------- budget
class BudgetUseCases {
  final BudgetRepository _repo;
  BudgetUseCases(this._repo);

  Future<List<ExpenseCategory>> categories() => _repo.categories();
  Future<void> addCategory(String name, String icon, List<ExpenseCategory> existing) {
    if (name.trim().isEmpty) throw _invalid('Category name is required');
    if (existing.any((c) => c.name.toLowerCase() == name.trim().toLowerCase())) {
      throw const Failure('That category already exists.', FailureType.duplicate);
    }
    return _repo.addCategory(name.trim(), icon);
  }

  Future<void> renameCategory(String id, String name) {
    if (name.trim().isEmpty) throw _invalid('Category name is required');
    return _repo.renameCategory(id, name.trim());
  }

  Future<void> deleteCategory(String id) => _repo.deleteCategory(id);

  Future<List<RecurringExpense>> recurring() => _repo.recurring();
  Future<void> saveRecurring({
    RecurringExpense? existing,
    required String name,
    required String? categoryId,
    required Decimal amount,
    required int? dueDay,
    required bool active,
    String? notes,
    required List<RecurringExpense> all,
  }) {
    if (name.trim().isEmpty) throw _invalid('Name is required');
    if (amount <= Decimal.zero) throw _invalid('Amount must be greater than 0');
    final dup = all.any((r) => r.id != existing?.id && r.name.toLowerCase() == name.trim().toLowerCase());
    if (dup) throw const Failure('A recurring expense with this name already exists.', FailureType.duplicate);
    return _repo.saveRecurring(existing, {
      'name': name.trim(),
      'category_id': categoryId,
      'amount': MoneyUtils.toDb(amount),
      'due_day': dueDay,
      'is_active': active,
      'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
    });
  }

  Future<void> deleteRecurring(String id) => _repo.deleteRecurring(id);

  Future<MonthlyBudget> ensureBudget(BudgetPeriod p) => _repo.ensureBudget(p.start, p.end);
  Future<MonthlyBudget?> budgetFor(BudgetPeriod p) => _repo.budgetByStart(p.start);
  Future<MonthlyBudget?> budgetById(String id) => _repo.budgetById(id);
  Future<List<MonthlyBudget>> budgets({DateTime? from, DateTime? to}) => _repo.budgets(from: from, to: to);
  Future<List<BudgetItem>> items(String budgetId) => _repo.items(budgetId);

  Future<void> addItem({
    required MonthlyBudget budget,
    required String name,
    required Decimal amount,
    required String? categoryId,
    required DateTime date,
    String? notes,
  }) {
    if (name.trim().isEmpty) throw _invalid('Name is required');
    if (amount <= Decimal.zero) throw _invalid('Amount must be greater than 0');
    if (!budget.period.contains(date)) {
      throw _invalid('Date must be inside ${budget.period.rangeLabel}');
    }
    return _repo.addItem(budget.id, {
      'name': name.trim(),
      'amount': MoneyUtils.toDb(amount),
      'category_id': categoryId,
      'due_date': Fmt.db(date),
      'is_recurring': false,
      'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
    });
  }

  Future<void> updateItem(BudgetItem item, {required String name, required Decimal amount, required String? categoryId, required DateTime? date, String? notes}) {
    if (name.trim().isEmpty) throw _invalid('Name is required');
    if (amount <= Decimal.zero) throw _invalid('Amount must be greater than 0');
    if (item.isCompleted && amount != item.amount) {
      throw const Failure('Undo the completion before changing the amount.', FailureType.validation);
    }
    return _repo.updateItem(item.id, {
      'name': name.trim(),
      'amount': MoneyUtils.toDb(amount),
      'category_id': categoryId,
      'due_date': date == null ? null : Fmt.db(date),
      'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
    });
  }

  Future<void> deleteItem(BudgetItem item) {
    if (item.isCompleted) throw _invalid('Undo the completion before deleting this expense.');
    return _repo.deleteItem(item.id);
  }

  Future<void> completeItem(BudgetItem item) {
    if (item.isCompleted) return Future.value(); // never deduct twice
    return _repo.completeItem(item.id);
  }

  Future<void> undoItem(BudgetItem item) => _repo.undoItem(item.id);

  Future<void> updateSalary(String budgetId, Decimal salary) {
    if (salary < Decimal.zero) throw _invalid('Salary cannot be negative');
    return _repo.updateSalary(budgetId, salary);
  }

  Future<void> addIncome(MonthlyBudget b, Decimal amount, DateTime date, String description) {
    if (amount <= Decimal.zero) throw _invalid('Amount must be greater than 0');
    return _repo.addIncome(budgetId: b.id, amount: amount, date: date, description: description.trim().isEmpty ? 'Other income' : description.trim());
  }

  ClosePreview closePreview(MonthlyBudget b, List<BudgetItem> items) =>
      MonthCloser.preview(salary: b.salary, extraIncome: b.extraIncome, items: items);

  Future<void> closeBudget(MonthlyBudget b) {
    if (b.closed) throw Failure('${b.period.label} cycle is already closed.', FailureType.duplicate);
    return _repo.closeBudget(b.id);
  }
}

// ---------------------------------------------------------- savings
class SavingsUseCases {
  final SavingsRepository _repo;
  SavingsUseCases(this._repo);

  Future<SavingsWallet> wallet() => _repo.wallet();
  Future<List<SavingsTxn>> transactions({DateTime? from, DateTime? to}) => _repo.transactions(from: from, to: to);

  Future<void> deposit(Decimal amount, DateTime date, String description, String? notes, String key) {
    if (amount <= Decimal.zero) throw _invalid('Amount must be greater than 0');
    return _repo.operate(type: 'deposit', amount: amount, date: date, description: description, notes: notes, key: key);
  }

  Future<void> withdraw(SavingsWallet w, Decimal amount, DateTime date, String description, String? notes, String key) {
    SavingsCalculator.withdraw(w.balance, amount); // validates amount & balance
    return _repo.operate(type: 'withdrawal', amount: amount, date: date, description: description, notes: notes, key: key);
  }
}

// ---------------------------------------------------------- lending
class LendingUseCases {
  final LendingRepository _repo;
  LendingUseCases(this._repo);

  Future<void> refresh() => _repo.refreshPeriods();
  Future<List<Loan>> loans() => _repo.loans();
  Future<Loan> loan(String id) => _repo.loan(id);
  Future<List<InterestPeriod>> periods({String? loanId}) => _repo.periods(loanId: loanId);
  Future<List<InterestPayment>> payments({String? loanId, DateTime? from, DateTime? to}) =>
      _repo.payments(loanId: loanId, from: from, to: to);

  Future<void> createLoan({
    required String name,
    String? phone,
    required Decimal principal,
    required Decimal rate,
    required DateTime start,
    int? expectedDay,
    String? notes,
  }) {
    if (name.trim().isEmpty) throw _invalid('Borrower name is required');
    if (principal <= Decimal.zero) throw _invalid('Principal must be greater than 0');
    if (rate < Decimal.zero) throw _invalid('Interest rate cannot be negative');
    if (start.isAfter(Fmt.today())) throw _invalid('Start date cannot be in the future');
    return _repo.createLoan({
      'p_name': name.trim(),
      'p_phone': phone?.trim(),
      'p_principal': MoneyUtils.toDb(principal),
      'p_rate': rate.toString(),
      'p_type': 'monthly_percentage',
      'p_start': Fmt.db(start),
      'p_expected_day': expectedDay,
      'p_notes': notes?.trim(),
    });
  }

  Future<void> updateLoan(Loan l, {required String name, String? phone, required Decimal rate, required Decimal principal, int? expectedDay, String? notes}) {
    if (name.trim().isEmpty) throw _invalid('Borrower name is required');
    if (principal <= Decimal.zero) throw _invalid('Principal must be greater than 0');
    if (rate < Decimal.zero) throw _invalid('Interest rate cannot be negative');
    if (!l.active) throw const Failure('This loan is closed.', FailureType.validation);
    return _repo.updateLoan(l.id, {
      'person_name': name.trim(),
      'phone': phone == null || phone.trim().isEmpty ? null : phone.trim(),
      'rate': rate.toString(),
      'principal': MoneyUtils.toDb(principal),
      'expected_day': expectedDay,
      'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
    });
  }

  Future<void> recordPayment({
    required InterestPeriod period,
    required Decimal amount,
    required DateTime date,
    String? notes,
    required String key,
  }) {
    InterestCalculator.applyPayment(expected: period.expected, paid: period.paid, amount: amount); // validates
    return _repo.recordPayment(periodId: period.id, amount: amount, date: date, notes: notes, key: key);
  }

  Future<void> closeLoan(Loan l, Decimal amount, DateTime date, String? notes) {
    LoanService.close(l, returned: amount, on: date); // validates
    return _repo.closeLoan(loanId: l.id, amount: amount, date: date, notes: notes);
  }
}

// ----------------------------------------------------- transactions
class TransactionUseCases {
  final TransactionRepository _repo;
  TransactionUseCases(this._repo);
  Future<List<MoneyTxn>> query(TxnFilter f) => _repo.query(f);
}

// ---------------------------------------------------------- reports
class ReportData {
  final DateTime from, to;
  final List<MonthlyBudget> budgets;
  final List<MoneyTxn> txns;
  final List<SavingsTxn> savings;
  final List<Loan> loans;
  final List<InterestPeriod> periods;
  final List<InterestPayment> payments;
  const ReportData({
    required this.from,
    required this.to,
    required this.budgets,
    required this.txns,
    required this.savings,
    required this.loans,
    required this.periods,
    required this.payments,
  });
}

enum ExportKind { expense, savings, lending, interest, transactions }

class ReportUseCases {
  final BudgetRepository _budget;
  final SavingsRepository _savings;
  final LendingRepository _lending;
  final TransactionRepository _txns;
  ReportUseCases(this._budget, this._savings, this._lending, this._txns);

  Future<ReportData> load(DateTime from, DateTime to) async {
    final r = await Future.wait([
      _budget.budgets(from: from, to: to),
      _txns.query(TxnFilter(from: from, to: to, limit: 5000)),
      _savings.transactions(from: from, to: to),
      _lending.loans(),
      _lending.periods(),
      _lending.payments(from: from, to: to),
    ]);
    return ReportData(
      from: from,
      to: to,
      budgets: r[0] as List<MonthlyBudget>,
      txns: r[1] as List<MoneyTxn>,
      savings: r[2] as List<SavingsTxn>,
      loans: r[3] as List<Loan>,
      periods: r[4] as List<InterestPeriod>,
      payments: r[5] as List<InterestPayment>,
    );
  }

  ExportTable buildExport(ExportKind kind, ReportData d, String currency) {
    String m(Decimal v) => MoneyUtils.plain(v, currency: currency);
    final range = '${Fmt.date(d.from)} - ${Fmt.date(d.to)}';
    final names = {for (final l in d.loans) l.id: l.personName};
    switch (kind) {
      case ExportKind.expense:
        final cats = ReportCalculator.expenseByCategory(d.txns);
        final total = ReportCalculator.expenses(d.txns);
        return ExportTable(
          title: 'Expense Report ($range)',
          fileName: 'moneymind_expense_report',
          headers: ['Category', 'Amount', 'Share'],
          rows: [
            for (final e in cats.entries) [e.key, m(e.value), _share(e.value, total)]
          ],
          summary: ['Total spent: ${m(total)}', 'Income: ${m(ReportCalculator.income(d.txns))}'],
        );
      case ExportKind.savings:
        final bal = MoneyUtils.sum(d.savings.map((s) => s.signed));
        return ExportTable(
          title: 'Savings Report ($range)',
          fileName: 'moneymind_savings_report',
          headers: ['Date', 'Type', 'Description', 'Amount'],
          rows: [
            for (final s in d.savings)
              [Fmt.date(s.date), s.type.name, s.description, '${s.signed < Decimal.zero ? '-' : '+'}${m(s.amount)}']
          ],
          summary: ['Net change in period: ${m(bal)}'],
        );
      case ExportKind.lending:
        return ExportTable(
          title: 'Lending Report',
          fileName: 'moneymind_lending_report',
          headers: ['Borrower', 'Principal', 'Rate %/mo', 'Status', 'Interest received', 'Pending interest'],
          rows: [
            for (final l in d.loans)
              [
                l.personName,
                m(l.principal),
                Fmt.rate(l.rate.toDouble()),
                l.active ? 'Active' : 'Closed',
                m(InterestCalculator.totalReceived(d.periods.where((p) => p.loanId == l.id))),
                m(InterestCalculator.totalPending(d.periods.where((p) => p.loanId == l.id))),
              ]
          ],
          summary: [
            'Active principal: ${m(MoneyUtils.sum(d.loans.map((l) => l.outstanding)))}',
            'Total interest received: ${m(InterestCalculator.totalReceived(d.periods))}',
            'Pending interest: ${m(InterestCalculator.totalPending(d.periods))}',
          ],
        );
      case ExportKind.interest:
        return ExportTable(
          title: 'Interest Report ($range)',
          fileName: 'moneymind_interest_report',
          headers: ['Payment date', 'Borrower', 'Amount', 'Notes'],
          rows: [
            for (final p in d.payments) [Fmt.date(p.date), names[p.loanId] ?? '-', m(p.amount), p.notes ?? '']
          ],
          summary: ['Interest received: ${m(MoneyUtils.sum(d.payments.map((p) => p.amount)))}'],
        );
      case ExportKind.transactions:
        return ExportTable(
          title: 'Transaction History ($range)',
          fileName: 'moneymind_transactions',
          headers: ['Date', 'Type', 'Category', 'Description', 'Amount'],
          rows: [
            for (final t in d.txns)
              [
                Fmt.date(t.date),
                t.type.name,
                t.categoryName ?? '',
                t.description,
                '${t.direction == TxnDirection.outflow ? '-' : t.direction == TxnDirection.inflow ? '+' : ''}${m(t.amount)}'
              ]
          ],
          summary: [
            'Income: ${m(ReportCalculator.income(d.txns))}',
            'Expenses: ${m(ReportCalculator.expenses(d.txns))}',
            'Interest received: ${m(ReportCalculator.interestReceived(d.txns))}',
          ],
        );
    }
  }

  static String _share(Decimal part, Decimal total) {
    if (total == Decimal.zero) return '0%';
    final p = (part / total).toDecimal(scaleOnInfinitePrecision: 4).toDouble() * 100;
    return '${p.toStringAsFixed(1)}%';
  }
}
