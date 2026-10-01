import 'package:decimal/decimal.dart';
import 'package:moneymind/domain/entities/entities.dart';

Decimal D(String v) => Decimal.parse(v);

BudgetItem item(String id, String amount, {ItemStatus status = ItemStatus.pending, String? recurringId}) => BudgetItem(
      id: id,
      budgetId: 'b1',
      name: 'Item $id',
      amount: D(amount),
      isRecurring: recurringId != null,
      recurringId: recurringId,
      status: status,
    );

Loan loan({bool active = true, String principal = '10000', String rate = '3'}) => Loan(
      id: 'l1',
      personName: 'Sasi',
      principal: D(principal),
      rate: D(rate),
      interestType: 'monthly_percentage',
      startDate: DateTime(2026, 1, 5),
      active: active,
      principalReturned: Decimal.zero,
    );

MoneyTxn txn(TxnType type, TxnDirection dir, String amount, {String? category}) => MoneyTxn(
      id: '${type.name}-$amount-${category ?? ''}',
      type: type,
      direction: dir,
      amount: D(amount),
      date: DateTime(2026, 9, 10),
      description: type.name,
      categoryName: category,
    );
