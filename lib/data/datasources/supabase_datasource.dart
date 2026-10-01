import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/error/failure.dart';
import '../models/mappers.dart';

/// Thin wrapper around Supabase. Every query is also protected by RLS on the server.
class SupabaseDataSource {
  final SupabaseClient _c;
  SupabaseDataSource(this._c);

  String get uid {
    final u = _c.auth.currentUser;
    if (u == null) throw const Failure('Your session has expired. Please log in again.', FailureType.auth);
    return u.id;
  }

  List<Json> _list(dynamic r) => (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Future<Json> _rpc(String fn, [Json? params]) async =>
      Map<String, dynamic>.from(await _c.rpc(fn, params: params) as Map);

  // ---------------------------------------------------------- auth
  bool get hasSession => _c.auth.currentSession != null;
  Stream<bool> get sessionChanges => _c.auth.onAuthStateChange.map((e) => e.session != null);

  Stream<bool> get recoveryEvents =>
      _c.auth.onAuthStateChange.where((e) => e.event == AuthChangeEvent.passwordRecovery).map((_) => true);

  Future<bool> signUp(String name, String email, String password) async {
    final res = await _c.auth.signUp(email: email, password: password, data: {'name': name});
    return res.session != null;
  }

  Future<void> signIn(String email, String password) async {
    try {
      await _c.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      final offline = e.runtimeType.toString().contains('Retryable') ||
          m.contains('failed host') || m.contains('socket') || m.contains('clientexception') || m.contains('timeout');
      if (offline) throw const Failure('No internet connection. Check your network and try again.', FailureType.network);
      if (m.contains('confirm')) throw const Failure('Please confirm your email address (check your inbox), then log in.', FailureType.auth);
      if (m.contains('rate') || m.contains('too many')) throw const Failure('Too many attempts. Please wait a minute and try again.', FailureType.auth);
      // Shows the server's own reason so problems are easy to diagnose.
      throw Failure('Could not log in: ${e.message}', FailureType.auth);
    }
  }

  Future<void> signOut() => _c.auth.signOut();
  Future<void> sendReset(String email) => _c.auth.resetPasswordForEmail(email);
  Future<void> updatePassword(String p) async {
    await _c.auth.updateUser(UserAttributes(password: p));
  }

  // ------------------------------------------------------- profile
  /// Loads the profile; creates it if the sign-up trigger did not (e.g. account made before schema.sql was run).
  Future<Json> profile() async {
    var row = await _c.from('profiles').select().eq('id', uid).maybeSingle();
    if (row == null) {
      final user = _c.auth.currentUser!;
      await _c.from('profiles').upsert({
        'id': user.id,
        'email': user.email ?? '',
        'name': (user.userMetadata?['name'] ?? '') as String,
      });
      row = await _c.from('profiles').select().eq('id', uid).single();
    }
    return Map<String, dynamic>.from(row);
  }
  Future<void> updateProfile(Json v) async {
    await _c.from('profiles').update(v).eq('id', uid);
  }

  Future<Json?> settings() async => await _c.from('app_settings').select().eq('user_id', uid).maybeSingle();
  Future<void> updateSettings(Json v) async {
    await _c.from('app_settings').update(v).eq('user_id', uid);
  }

  Future<void> seedDemo() async {
    await _c.rpc('seed_demo_data');
  }

  // ---------------------------------------------------- categories
  Future<List<Json>> categories() async => _list(await _c.from('categories').select().eq('user_id', uid).order('name'));
  Future<void> addCategory(String name, String icon) async {
    await _c.from('categories').insert({'user_id': uid, 'name': name, 'icon': icon});
  }

  Future<void> renameCategory(String id, String name) async {
    await _c.from('categories').update({'name': name}).eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    await _c.from('categories').delete().eq('id', id);
  }

  Future<List<Json>> recurring() async =>
      _list(await _c.from('recurring_expenses').select('*, categories(name)').eq('user_id', uid).order('name'));
  Future<void> insertRecurring(Json v) async {
    await _c.from('recurring_expenses').insert({...v, 'user_id': uid});
  }

  Future<void> updateRecurring(String id, Json v) async {
    await _c.from('recurring_expenses').update(v).eq('id', id);
  }

  Future<void> deleteRecurring(String id) async {
    await _c.from('recurring_expenses').delete().eq('id', id);
  }

  // -------------------------------------------------------- budget
  Future<Json> ensureBudget(String start, String end) => _rpc('ensure_budget', {'p_start': start, 'p_end': end});

  Future<Json?> budgetSummaryByStart(String start) async =>
      await _c.from('budget_summaries').select().eq('user_id', uid).eq('period_start', start).maybeSingle();

  Future<Json?> budgetSummaryById(String id) async =>
      await _c.from('budget_summaries').select().eq('id', id).maybeSingle();

  Future<List<Json>> budgetSummaries(String? from, String? to) async {
    var q = _c.from('budget_summaries').select().eq('user_id', uid);
    if (from != null) q = q.gte('period_start', from);
    if (to != null) q = q.lte('period_start', to);
    return _list(await q.order('period_start'));
  }

  Future<List<Json>> items(String budgetId) async => _list(await _c
      .from('budget_items')
      .select('*, categories(name)')
      .eq('budget_id', budgetId)
      .order('due_date', ascending: true, nullsFirst: false)
      .order('created_at'));

  Future<void> insertItem(String budgetId, Json v) async {
    await _c.from('budget_items').insert({...v, 'user_id': uid, 'budget_id': budgetId});
  }

  Future<void> updateItem(String id, Json v) async {
    await _c.from('budget_items').update(v).eq('id', id);
  }

  Future<void> deleteItem(String id) async {
    await _c.from('budget_items').delete().eq('id', id);
  }

  Future<void> completeItem(String id) => _rpc('complete_budget_item', {'p_item_id': id});
  Future<void> undoItem(String id) => _rpc('undo_budget_item', {'p_item_id': id});
  Future<void> updateSalary(String id, String salary) => _rpc('update_budget_salary', {'p_budget_id': id, 'p_salary': salary});
  Future<void> closeBudget(String id) => _rpc('close_budget', {'p_budget_id': id});
  Future<void> reopenBudget(String id) => _rpc('reopen_budget', {'p_budget_id': id});
  Future<void> deleteBudget(String id) async {
    await _c.rpc('delete_budget', params: {'p_budget_id': id});
  }

  Future<Json?> itemById(String id) async =>
      await _c.from('budget_items').select('*, categories(name)').eq('id', id).maybeSingle();

  Future<List<Json>> incomes(String budgetId) async => _list(await _c
      .from('transactions')
      .select()
      .eq('budget_id', budgetId)
      .eq('ref_type', 'other_income')
      .order('txn_date'));

  Future<void> updateIncome(String id, Json v) async {
    await _c.from('transactions').update(v).eq('id', id).eq('ref_type', 'other_income');
  }

  Future<void> deleteIncome(String id) async {
    await _c.from('transactions').delete().eq('id', id).eq('ref_type', 'other_income');
  }

  Future<void> addIncome(String budgetId, String amount, String date, String description) async {
    await _c.from('transactions').insert({
      'user_id': uid,
      'type': 'income',
      'direction': 'in',
      'amount': amount,
      'txn_date': date,
      'description': description,
      'budget_id': budgetId,
      'ref_type': 'other_income',
    });
  }

  // ------------------------------------------------------- savings
  Future<Json> wallet() async {
    var row = await _c.from('savings_wallet').select().eq('user_id', uid).maybeSingle();
    if (row == null) {
      await _c.from('savings_wallet').insert({'user_id': uid});
      row = await _c.from('savings_wallet').select().eq('user_id', uid).single();
    }
    return Map<String, dynamic>.from(row);
  }

  Future<List<Json>> savingsTransactions(String? from, String? to) async {
    var q = _c.from('savings_transactions').select().eq('user_id', uid);
    if (from != null) q = q.gte('txn_date', from);
    if (to != null) q = q.lte('txn_date', to);
    return _list(await q.order('txn_date', ascending: false).order('created_at', ascending: false));
  }

  Future<void> savingsOperation(Json p) => _rpc('savings_operation', p);
  Future<Json?> savingsTxnById(String id) async => await _c.from('savings_transactions').select().eq('id', id).maybeSingle();
  Future<void> updateSavingsTxn(Json p) => _rpc('update_savings_transaction', p);
  Future<void> deleteSavingsTxn(String id) => _rpc('delete_savings_transaction', {'p_id': id});

  // ------------------------------------------------------- lending
  Future<void> refreshPeriods() async {
    await _c.rpc('refresh_interest_periods');
  }

  Future<List<Json>> loans() async => _list(await _c.from('loans').select().eq('user_id', uid).order('start_date'));
  Future<Json> loan(String id) async => Map<String, dynamic>.from(await _c.from('loans').select().eq('id', id).single());
  Future<void> createLoan(Json p) => _rpc('create_loan', p);
  Future<void> updateLoan(Json p) => _rpc('update_loan', p);
  Future<void> deleteLoan(String id) async {
    await _c.rpc('delete_loan', params: {'p_loan_id': id});
  }

  Future<void> reopenLoan(String id) => _rpc('reopen_loan', {'p_loan_id': id});
  Future<void> updatePayment(Json p) => _rpc('update_interest_payment', p);
  Future<void> deletePayment(String id) => _rpc('delete_interest_payment', {'p_payment_id': id});

  Future<List<Json>> periods(String? loanId) async {
    var q = _c.from('loan_interest_periods').select().eq('user_id', uid);
    if (loanId != null) q = q.eq('loan_id', loanId);
    return _list(await q.order('period_start', ascending: false));
  }

  Future<List<Json>> payments(String? loanId, String? from, String? to) async {
    var q = _c.from('loan_interest_payments').select().eq('user_id', uid);
    if (loanId != null) q = q.eq('loan_id', loanId);
    if (from != null) q = q.gte('payment_date', from);
    if (to != null) q = q.lte('payment_date', to);
    return _list(await q.order('payment_date', ascending: false));
  }

  Future<void> recordPayment(Json p) => _rpc('record_interest_payment', p);
  Future<void> closeLoan(Json p) => _rpc('close_loan', p);

  // -------------------------------------------------- transactions
  Future<List<Json>> transactions({
    String? type,
    String? search,
    String? categoryId,
    String? from,
    String? to,
    String? min,
    String? max,
    int limit = 500,
  }) async {
    var q = _c.from('transactions').select('*, categories(name)').eq('user_id', uid);
    if (type != null) q = q.eq('type', type);
    if (categoryId != null) q = q.eq('category_id', categoryId);
    if (from != null) q = q.gte('txn_date', from);
    if (to != null) q = q.lte('txn_date', to);
    if (min != null) q = q.gte('amount', min);
    if (max != null) q = q.lte('amount', max);
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().replaceAll(RegExp(r'[%,()]'), ' ');
      q = q.ilike('description', '%$s%');
    }
    return _list(await q.order('txn_date', ascending: false).order('created_at', ascending: false).limit(limit));
  }
}