import 'package:decimal/decimal.dart';
import 'package:get/get.dart';
import '../../core/error/failure.dart';
import '../../core/services/export_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/snack.dart';
import '../../domain/entities/entities.dart';
import '../../domain/services/cycle_calculator.dart';
import '../../domain/services/lending_logic.dart';
import '../../domain/services/report_calculator.dart';
import '../../domain/usecases/usecases.dart';
import 'app_events.dart';
import 'auth_controller.dart';

enum ReportRange { monthly, yearly, custom }

class ReportsController extends GetxController {
  final ReportUseCases _uc;
  final BudgetUseCases _budget;
  final AuthController _auth;
  ReportsController(this._uc, this._budget, this._auth);

  final range = ReportRange.monthly.obs;
  final period = Rxn<BudgetPeriod>(); // monthly cycle in view
  final year = DateTime.now().year.obs;
  final customFrom = Rxn<DateTime>();
  final customTo = Rxn<DateTime>();
  final data = Rxn<ReportData>();
  final trend = <MonthlyBudget>[].obs;
  final loading = false.obs;
  final exporting = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    ever(Get.find<AppEvents>().logoutTick, (_) {
      data.value = null;
      trend.clear();
      period.value = null;
    });
  }

  String get currency => _auth.currency;

  BudgetPeriod get _p => period.value ?? _auth.currentPeriod;

  (DateTime, DateTime) get bounds {
    switch (range.value) {
      case ReportRange.monthly:
        return (_p.start, _p.end);
      case ReportRange.yearly:
        return (DateTime(year.value, 1, 1), DateTime(year.value, 12, 31));
      case ReportRange.custom:
        final f = customFrom.value ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
        final t = customTo.value ?? Fmt.today();
        return (f, t);
    }
  }

  String get rangeLabel {
    switch (range.value) {
      case ReportRange.monthly:
        return _p.label;
      case ReportRange.yearly:
        return '${year.value}';
      case ReportRange.custom:
        final b = bounds;
        return '${Fmt.date(b.$1)} - ${Fmt.date(b.$2)}';
    }
  }

  void setRange(ReportRange r) {
    range.value = r;
    load();
  }

  void step(int dir) {
    if (range.value == ReportRange.monthly) {
      period.value = dir < 0
          ? CycleCalculator.previous(_p, salaryDay: _auth.salaryDay, mode: _auth.cycleMode)
          : CycleCalculator.next(_p, salaryDay: _auth.salaryDay, mode: _auth.cycleMode);
    } else if (range.value == ReportRange.yearly) {
      year.value += dir;
    }
    load();
  }

  void setCustom(DateTime from, DateTime to) {
    customFrom.value = from;
    customTo.value = to;
    range.value = ReportRange.custom;
    load();
  }

  // -------- derived numbers (all through ReportCalculator so types stay separate)
  List<MoneyTxn> get _t => data.value?.txns ?? const [];
  Decimal get income => ReportCalculator.income(_t);
  Decimal get expenses => ReportCalculator.expenses(_t);
  Decimal get interest => ReportCalculator.interestReceived(_t);
  Decimal get lent => ReportCalculator.principalLent(_t);
  Decimal get principalBack => ReportCalculator.principalReturned(_t);
  Decimal get netFlow => ReportCalculator.netFlow(_t);
  Map<String, Decimal> get byCategory => ReportCalculator.expenseByCategory(_t);
  Decimal get savingsAdded => MoneyUtils.sum((data.value?.savings ?? const <SavingsTxn>[])
      .where((s) => s.type == SavingsTxnType.monthlySavings || s.type == SavingsTxnType.deposit)
      .map((s) => s.amount));
  Decimal get savingsWithdrawn => MoneyUtils.sum(
      (data.value?.savings ?? const <SavingsTxn>[]).where((s) => s.type == SavingsTxnType.withdrawal).map((s) => s.amount));
  Decimal get avgSavings => ReportCalculator.averageSavings(trend);
  List<InterestPeriod> get periods => data.value?.periods ?? const [];
  List<Loan> get loans => data.value?.loans ?? const [];
  Decimal get pendingInterest => InterestCalculator.totalPending(periods);

  Future<void> load() async {
    if (data.value == null) loading.value = true;
    error.value = null;
    try {
      final b = bounds;
      final d = await _uc.load(b.$1, b.$2);
      final end = b.$2;
      trend.assignAll(await _budget.budgets(from: DateTime(end.year, end.month - 11, 1), to: end));
      data.value = d;
    } catch (e) {
      error.value = mapError(e).message;
    } finally {
      loading.value = false;
    }
  }

  Future<void> export(ExportKind kind, {required bool pdf, required DateTime from, required DateTime to}) async {
    if (exporting.value) return;
    exporting.value = true;
    try {
      final d = await _uc.load(from, to);
      final table = _uc.buildExport(kind, d, currency);
      if (table.rows.isEmpty) {
        Snack.info('Nothing to export for this range.');
        return;
      }
      pdf ? await ExportService.savePdf(table) : await ExportService.saveCsv(table);
      Snack.success('${pdf ? 'PDF' : 'CSV'} exported');
    } catch (e) {
      Snack.error(mapError(e).message);
    } finally {
      exporting.value = false;
    }
  }
}
