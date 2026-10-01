import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/error/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/snack.dart';
import '../../domain/entities/entities.dart';
import '../../domain/usecases/usecases.dart';
import '../controllers/budget_controller.dart';
import '../controllers/transactions_controller.dart';
import 'common.dart';

/// Edit / delete sheet for any ledger entry. Each entry type is routed to the operation
/// that keeps every linked record (budget, savings wallet, interest periods, loans) consistent.
class TxnActions {
  static Future<void> show(MoneyTxn t, String currency) async {
    final c = txnColor(t.type);
    final info = _info(t);
    await Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          decoration: BoxDecoration(color: Theme.of(Get.context!).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 18),
            Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(gradient: AppGradients.of(c), borderRadius: BorderRadius.circular(17)), child: Icon(txnIcon(t.type), color: Colors.white)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.description.isEmpty ? t.type.name : t.description, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text('${Fmt.date(t.date)} · ${t.type.name}'),
              ])),
              Text(MoneyUtils.format(t.amount, currency: currency), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c)),
            ]),
            if (info != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(info, style: const TextStyle(fontSize: 13))),
            const SizedBox(height: 18),
            PrimaryButton(label: 'Edit', icon: Icons.edit_outlined, onPressed: () {
              Get.back();
              _edit(t, currency);
            }),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.expense, side: const BorderSide(color: AppColors.expense)),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              onPressed: () {
                Get.back();
                _delete(t, currency);
              },
            ),
          ]),
        ),
      ),
      isScrollControlled: true,
    );
  }

  static String? _info(MoneyTxn t) {
    switch (t.refType) {
      case 'budget_item': {
        return 'Paid expense. Editing or deleting it updates your remaining budget right away.';
      }
      case 'salary': {
        return 'Salary for a cycle. Delete sets that cycle\'s salary to zero.';
      }
      case 'loan':
      case 'loan_return': {
        return 'Loan entry. Opens the loan, where you can edit, reopen or delete it.';
      }
      case 'savings_txn': {
        return t.type == TxnType.transfer ? 'Created when a cycle was closed. Reopen that cycle from Budget → History to change it.' : null;
      }
      default:
        return null;
    }
  }

  static Future<void> _guard(Future<void> Function() action, String ok) async {
    try {
      await action();
      Snack.success(ok);
      if (Get.isRegistered<TransactionsController>()) Get.find<TransactionsController>().load();
    } catch (e) {
      Snack.error(mapError(e).message);
    }
  }

  static Future<void> _edit(MoneyTxn t, String cur) async {
    final budget = Get.find<BudgetUseCases>();
    final lending = Get.find<LendingUseCases>();
    final savings = Get.find<SavingsUseCases>();
    switch (t.refType) {
      case 'budget_item': {
        final item = await Get.find<BudgetController>().prepareItemEdit(t.refId ?? '');
        if (item != null) {
          await Get.toNamed(AppRoutes.expenseEdit, arguments: item);
          if (Get.isRegistered<TransactionsController>()) Get.find<TransactionsController>().load();
        }
      }
      case 'other_income': {
        final r = await showEntryDialog(title: 'Edit income', currency: cur, amount: t.amount, date: t.date, description: t.description, showDescription: true);
        if (r != null) await _guard(() => budget.updateIncome(t, r.amount, r.date, r.description), 'Income updated');
      }
      case 'salary': {
        final r = await showEntryDialog(title: 'Edit salary', currency: cur, amount: t.amount, showDate: false, allowZeroAmount: true, amountLabel: 'Salary');
        if (r != null) await _guard(() => budget.updateSalary(t.refId ?? '', r.amount), 'Salary updated');
      }
      case 'interest_payment': {
        final list = await lending.payments();
        final p = list.where((x) => x.id == t.refId).firstOrNull;
        if (p == null) return Snack.error('That payment no longer exists.');
        final r = await showEntryDialog(title: 'Edit interest payment', currency: cur, amount: p.amount, date: p.date, notes: p.notes, showNotes: true, last: Fmt.today());
        if (r != null) await _guard(() => lending.updatePayment(p, r.amount, r.date, r.notes.isEmpty ? null : r.notes), 'Payment updated');
      }
      case 'savings_txn': {
        final s = await savings.txById(t.refId ?? '');
        if (s == null) return Snack.error('That entry no longer exists.');
        if (s.type == SavingsTxnType.monthlySavings) return Snack.info('Reopen that cycle from Budget → History to change its savings.');
        final r = await showEntryDialog(title: 'Edit savings entry', currency: cur, amount: s.amount, date: s.date, description: s.description, notes: s.notes, showDescription: true, showNotes: true, last: Fmt.today());
        if (r != null) await _guard(() => savings.updateTx(s, r.amount, r.date, r.description, r.notes.isEmpty ? null : r.notes), 'Entry updated');
      }
      case 'loan':
      case 'loan_return': {
        await Get.toNamed(AppRoutes.loanOf(t.refId ?? ''));
      }
      default:
        Snack.info('This entry cannot be edited.');
    }
  }

  static Future<void> _delete(MoneyTxn t, String cur) async {
    final budget = Get.find<BudgetUseCases>();
    final lending = Get.find<LendingUseCases>();
    final savings = Get.find<SavingsUseCases>();
    final amt = MoneyUtils.format(t.amount, currency: cur);
    switch (t.refType) {
      case 'budget_item': {
        if (!await confirmDialog('Delete this expense?', 'It will be removed and $amt goes back into your remaining budget.', confirm: 'Delete', danger: true)) return;
        final item = await budget.itemById(t.refId ?? '');
        if (item == null) return Snack.error('That expense no longer exists.');
        await _guard(() => budget.deleteItem(item), 'Expense deleted');
      }
      case 'other_income': {
        if (!await confirmDialog('Delete this income?', '$amt will be removed from this cycle.', confirm: 'Delete', danger: true)) return;
        await _guard(() => budget.deleteIncome(t), 'Income deleted');
      }
      case 'salary': {
        if (!await confirmDialog('Clear salary?', 'Salary for that cycle becomes ${MoneyUtils.format(Decimal.zero, currency: cur)}.', confirm: 'Clear', danger: true)) return;
        await _guard(() => budget.updateSalary(t.refId ?? '', Decimal.zero), 'Salary cleared');
      }
      case 'interest_payment': {
        if (!await confirmDialog('Delete this payment?', 'The month returns to its earlier pending amount.', confirm: 'Delete', danger: true)) return;
        final list = await lending.payments();
        final p = list.where((x) => x.id == t.refId).firstOrNull;
        if (p == null) return Snack.error('That payment no longer exists.');
        await _guard(() => lending.deletePayment(p), 'Payment deleted');
      }
      case 'savings_txn': {
        final s = await savings.txById(t.refId ?? '');
        if (s == null) return Snack.error('That entry no longer exists.');
        if (s.type == SavingsTxnType.monthlySavings) return Snack.info('Reopen that cycle from Budget → History to remove its savings.');
        if (!await confirmDialog('Delete this savings entry?', 'Your savings balance is adjusted back.', confirm: 'Delete', danger: true)) return;
        await _guard(() => savings.deleteTx(s), 'Entry deleted');
      }
      case 'loan':
      case 'loan_return': {
        await Get.toNamed(AppRoutes.loanOf(t.refId ?? ''));
      }
      default:
        Snack.info('This entry cannot be deleted.');
    }
  }
}
