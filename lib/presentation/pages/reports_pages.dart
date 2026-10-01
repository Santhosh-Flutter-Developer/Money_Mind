import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/entities.dart';
import '../../domain/services/lending_logic.dart';
import '../../domain/usecases/usecases.dart';
import '../controllers/auth_controller.dart';
import '../controllers/reports_controller.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

String _m(ReportsController c, Decimal d) => MoneyUtils.format(d, currency: c.currency);
double _d(Decimal d) => d.toDouble();

/// Shared wrapper: loads on open, shows range selector on top.
class _ReportScaffold extends StatefulWidget {
  final String title;
  final Widget Function(ReportsController c) builder;
  const _ReportScaffold({required this.title, required this.builder});
  @override
  State<_ReportScaffold> createState() => _ReportScaffoldState();
}

class _ReportScaffoldState extends State<_ReportScaffold> {
  final c = Get.find<ReportsController>();
  @override
  void initState() {
    super.initState();
    if (c.data.value == null) c.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Obx(() => LoadState(
              loading: c.loading.value,
              error: c.error.value,
              hasData: c.data.value != null,
              onRetry: c.load,
              child: c.data.value == null
                  ? const SizedBox()
                  : ListView(padding: const EdgeInsets.only(bottom: 32), children: [
                      PageBody(maxWidth: 900, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(c.rangeLabel, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
                        widget.builder(c),
                      ])),
                    ]),
            )),
      );
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final c = Get.find<ReportsController>();
  @override
  void initState() {
    super.initState();
    c.load();
  }

  Future<void> _custom() async {
    final b = c.bounds;
    final r = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(DateTime.now().year + 1), initialDateRange: DateTimeRange(start: b.$1, end: b.$2));
    if (r != null) c.setCustom(r.start, r.end);
  }

  Widget _tile(IconData i, String t, String s, String route, {Object? args}) => AppCard(
        onTap: () => Get.toNamed(route, arguments: args),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.12), child: Icon(i, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w700)), Text(s, style: const TextStyle(fontSize: 12))])),
          const Icon(Icons.chevron_right),
        ]),
      );

  @override
  Widget build(BuildContext context) => AdaptiveShell(
        route: AppRoutes.reports,
        child: Scaffold(
          appBar: AppBar(title: const Text('Reports'), actions: [IconButton(icon: const Icon(Icons.download_outlined), tooltip: 'Export', onPressed: () => Get.toNamed(AppRoutes.reportExport))]),
          body: Obx(() => LoadState(
                loading: c.loading.value,
                error: c.error.value,
                hasData: c.data.value != null,
                onRetry: c.load,
                child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
                  PageBody(maxWidth: 900, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (final r in ReportRange.values)
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(r.name[0].toUpperCase() + r.name.substring(1)), selected: c.range.value == r, onSelected: (_) => r == ReportRange.custom ? _custom() : c.setRange(r))),
                    ]),
                    if (c.range.value == ReportRange.custom)
                      TextButton.icon(onPressed: _custom, icon: const Icon(Icons.date_range), label: Text(c.rangeLabel))
                    else
                      MonthSwitcher(title: c.rangeLabel, subtitle: c.range.value == ReportRange.monthly ? c.period.value?.rangeLabel ?? '' : 'Calendar year', onPrev: () => c.step(-1), onNext: () => c.step(1)),
                    if (c.data.value != null) ...[
                      StatGrid(minTile: 150, children: [
                        StatTile(label: 'Income', value: _m(c, c.income), color: AppColors.income),
                        StatTile(label: 'Expenses', value: _m(c, c.expenses), color: AppColors.expense),
                        StatTile(label: 'Interest received', value: _m(c, c.interest), color: AppColors.interest),
                        StatTile(label: 'Net cash flow', value: _m(c, c.netFlow), caption: 'Income + interest − expenses'),
                      ]),
                      const SectionHeader('Reports'),
                      _tile(Icons.pie_chart_outline, 'Expense report', 'Categories, trend and share', AppRoutes.reportExpenses),
                      _tile(Icons.savings_outlined, 'Savings report', 'Wallet, monthly savings, goal', AppRoutes.reportSavings),
                      _tile(Icons.handshake_outlined, 'Lending report', 'Borrowers, principal, interest', AppRoutes.reportLending),
                      _tile(Icons.payments_outlined, 'Income report', 'Salary and other income', AppRoutes.reportGeneric, args: 'income'),
                      _tile(Icons.account_balance_wallet_outlined, 'Budget report', 'Planned vs spent per cycle', AppRoutes.reportGeneric, args: 'budget'),
                      _tile(Icons.percent, 'Interest report', 'Payments received and pending', AppRoutes.reportGeneric, args: 'interest'),
                      _tile(Icons.swap_vert, 'Net cash flow', 'Income, interest and expenses', AppRoutes.reportGeneric, args: 'netflow'),
                      _tile(Icons.download_outlined, 'Export data', 'CSV or PDF', AppRoutes.reportExport),
                    ],
                  ])),
                ]),
              )),
        ),
      );
}

class ExpenseReportPage extends StatelessWidget {
  const ExpenseReportPage({super.key});
  @override
  Widget build(BuildContext context) => _ReportScaffold(
        title: 'Expense report',
        builder: (c) => Obx(() {
          final cats = c.byCategory;
          final top = <String, double>{};
          var other = 0.0;
          var i = 0;
          for (final e in cats.entries) {
            if (i++ < 6) {
              top[e.key] = _d(e.value);
            } else {
              other += _d(e.value);
            }
          }
          if (other > 0) top['Other'] = (top['Other'] ?? 0) + other;
          final labels = [for (final b in c.trend) Fmt.monthShort(b.periodStart)];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            StatGrid(minTile: 150, children: [
              StatTile(label: 'Total spent', value: _m(c, c.expenses), color: AppColors.expense),
              StatTile(label: 'Top category', value: cats.isEmpty ? '—' : cats.keys.first, caption: cats.isEmpty ? null : _m(c, cats.values.first)),
            ]),
            if (top.isEmpty) const EmptyState(icon: Icons.pie_chart_outline, title: 'No expenses in this period', subtitle: 'Complete expenses in Budget to see them here.') else ...[
              const SectionHeader('By category'),
              AppCard(child: CategoryPie(data: top)),
              for (final e in cats.entries.toList().asMap().entries)
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: chartPalette[e.key.clamp(0, 6).toInt()], shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.value.key)),
                    Text(_m(c, e.value.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    Text(c.expenses == Decimal.zero ? '' : '${(_d(e.value.value) / _d(c.expenses) * 100).toStringAsFixed(0)}%'),
                  ]),
                ),
            ],
            if (c.trend.isNotEmpty) ...[
              const SectionHeader('Spent per cycle (last 12)'),
              AppCard(child: TrendLine(labels: labels, values: [for (final b in c.trend) _d(b.spent)], color: AppColors.expense)),
              const SectionHeader('Planned vs spent'),
              AppCard(child: GroupedBars(labels: labels, series: [[for (final b in c.trend) _d(b.planned)], [for (final b in c.trend) _d(b.spent)]], colors: const [AppColors.lending, AppColors.expense])),
            ],
          ]);
        }),
      );
}

class SavingsReportPage extends StatelessWidget {
  const SavingsReportPage({super.key});
  @override
  Widget build(BuildContext context) => _ReportScaffold(
        title: 'Savings report',
        builder: (c) => Obx(() {
          final auth = Get.find<AuthController>();
          final labels = [for (final b in c.trend) Fmt.monthShort(b.periodStart)];
          final goal = auth.profile.value?.savingsGoal;
          final txns = c.data.value?.savings ?? const <SavingsTxn>[];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            StatGrid(minTile: 150, children: [
              StatTile(label: 'Added in period', value: _m(c, c.savingsAdded), color: AppColors.savings),
              StatTile(label: 'Withdrawn', value: _m(c, c.savingsWithdrawn), color: AppColors.expense),
              StatTile(label: 'Avg monthly savings', value: _m(c, c.avgSavings), caption: 'Closed cycles, last 12'),
              if (goal != null) StatTile(label: 'Goal', value: _m(c, goal)),
            ]),
            if (c.trend.isNotEmpty) ...[
              const SectionHeader('Moved to savings per cycle'),
              AppCard(child: GroupedBars(labels: labels, series: [[for (final b in c.trend) _d(b.savingsTransferred)]], colors: const [AppColors.savings])),
            ],
            const SectionHeader('Activity'),
            if (txns.isEmpty) const AppCard(child: Text('No savings activity in this period.')),
            for (final t in txns)
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Expanded(child: Text('${Fmt.date(t.date)} · ${t.description}')),
                  Text('${t.signed < Decimal.zero ? '-' : '+'}${_m(c, t.amount)}', style: TextStyle(fontWeight: FontWeight.w800, color: t.signed < Decimal.zero ? AppColors.expense : AppColors.savings)),
                ]),
              ),
          ]);
        }),
      );
}

class LendingReportPage extends StatelessWidget {
  const LendingReportPage({super.key});
  @override
  Widget build(BuildContext context) => _ReportScaffold(
        title: 'Lending report',
        builder: (c) => Obx(() {
          final d = c.data.value!;
          final byMonth = <String, double>{};
          for (final p in d.payments.reversed) {
            final k = Fmt.monthShort(p.date);
            byMonth[k] = (byMonth[k] ?? 0) + _d(p.amount);
          }
          final names = {for (final l in d.loans) l.id: l.personName};
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            StatGrid(minTile: 150, children: [
              StatTile(label: 'Money lent (active)', value: _m(c, MoneyUtils.sum(d.loans.map((l) => l.outstanding))), color: AppColors.lending),
              StatTile(label: 'Interest in period', value: _m(c, c.interest), color: AppColors.interest),
              StatTile(label: 'Pending interest', value: _m(c, c.pendingInterest), color: AppColors.warning),
              StatTile(label: 'Principal returned', value: _m(c, c.principalBack), caption: 'Not counted as income'),
            ]),
            if (byMonth.isNotEmpty) ...[
              const SectionHeader('Interest received by month'),
              AppCard(child: GroupedBars(labels: byMonth.keys.toList(), series: [byMonth.values.toList()], colors: const [AppColors.interest])),
            ],
            const SectionHeader('Borrowers'),
            if (d.loans.isEmpty) const AppCard(child: Text('No loans yet.')),
            for (final l in d.loans)
              AppCard(
                onTap: () => Get.toNamed(AppRoutes.loanOf(l.id)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text(names[l.id]!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))), l.active ? const StatusChip('Active', AppColors.income) : const StatusChip('Closed', AppColors.transfer)]),
                  const SizedBox(height: 6),
                  Text('Principal ${_m(c, l.principal)} · ${Fmt.rate(l.rate.toDouble())}% / month'),
                  Text('Received ${_m(c, InterestCalculator.totalReceived(d.periods.where((p) => p.loanId == l.id)))} · Pending ${_m(c, InterestCalculator.totalPending(d.periods.where((p) => p.loanId == l.id)))}'),
                ]),
              ),
          ]);
        }),
      );
}

/// income | budget | interest | netflow
class GenericReportPage extends StatelessWidget {
  const GenericReportPage({super.key});
  @override
  Widget build(BuildContext context) {
    final type = (Get.arguments as String?) ?? 'income';
    final titles = {'income': 'Income report', 'budget': 'Budget report', 'interest': 'Interest report', 'netflow': 'Net cash flow'};
    return _ReportScaffold(
      title: titles[type] ?? 'Report',
      builder: (c) => Obx(() {
        final d = c.data.value!;
        Widget row(String l, Decimal v, {Color? color, bool bold = false}) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [Expanded(child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w700 : null))), Text(_m(c, v), style: TextStyle(fontWeight: FontWeight.w800, color: color))]),
            );
        switch (type) {
          case 'budget':
            return Column(children: [
              if (c.trend.isEmpty) const AppCard(child: Text('No budget cycles yet.')),
              for (final b in c.trend.reversed)
                AppCard(
                  onTap: () => Get.toNamed(AppRoutes.budgetOf(b.id)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(b.period.label, style: const TextStyle(fontWeight: FontWeight.w700))), b.closed ? const StatusChip('Closed', AppColors.transfer) : const StatusChip('Open', AppColors.income)]),
                    row('Income', b.totalIncome),
                    row('Planned', b.planned),
                    row('Spent', b.spent, color: AppColors.expense),
                    row('Remaining', b.remaining, bold: true),
                  ]),
                ),
            ]);
          case 'interest':
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AppCard(child: Column(children: [row('Received in period', c.interest, color: AppColors.income), row('Pending (all loans)', c.pendingInterest, color: AppColors.warning)])),
              const SectionHeader('Payments'),
              if (d.payments.isEmpty) const AppCard(child: Text('No interest received in this period.')),
              for (final p in d.payments)
                AppCard(child: Row(children: [Expanded(child: Text('${Fmt.date(p.date)} · ${d.loans.where((l) => l.id == p.loanId).map((l) => l.personName).firstOrNull ?? ''}')), Text('+${_m(c, p.amount)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.income))])),
            ]);
          case 'netflow':
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AppCard(child: Column(children: [
                row('Income', c.income, color: AppColors.income),
                row('Interest received', c.interest, color: AppColors.interest),
                row('Expenses', c.expenses, color: AppColors.expense),
                const Divider(),
                row('Net cash flow', c.netFlow, bold: true),
              ])),
              const SectionHeader('Not counted (transfers)'),
              AppCard(child: Column(children: [
                row('Money lent (principal)', c.lent),
                row('Principal returned', c.principalBack),
                row('Savings added', c.savingsAdded),
                row('Savings withdrawn', c.savingsWithdrawn),
              ])),
            ]);
          default:
            final list = d.txns.where((t) => t.type == TxnType.income).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AppCard(child: Column(children: [row('Total income', c.income, color: AppColors.income), row('Interest (shown separately)', c.interest, color: AppColors.interest)])),
              const SectionHeader('Income entries'),
              if (list.isEmpty) const AppCard(child: Text('No income in this period.')),
              for (final t in list) TxnTile(txn: t, currency: c.currency),
            ]);
        }
      }),
    );
  }
}

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});
  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  final c = Get.find<ReportsController>();
  ExportKind _kind = ExportKind.transactions;
  bool _pdf = false;
  late DateTime _from = c.bounds.$1;
  late DateTime _to = c.bounds.$2;

  static const _labels = {
    ExportKind.expense: 'Expense report',
    ExportKind.savings: 'Savings report',
    ExportKind.lending: 'Lending report',
    ExportKind.interest: 'Interest report',
    ExportKind.transactions: 'Complete transaction history',
  };

  @override
  Widget build(BuildContext context) => FormScaffold(
        title: 'Export data',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DropdownButtonFormField<ExportKind>(
              value: _kind,
              decoration: InputDecoration(labelText: 'Report', filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
              items: [for (final e in _labels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
          ),
          DateField(label: 'From', value: _from, onChanged: (d) => setState(() => _from = d)),
          DateField(label: 'To', value: _to, onChanged: (d) => setState(() => _to = d)),
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: false, label: Text('CSV'), icon: Icon(Icons.table_chart_outlined)), ButtonSegment(value: true, label: Text('PDF'), icon: Icon(Icons.picture_as_pdf_outlined))],
            selected: {_pdf},
            onSelectionChanged: (s) => setState(() => _pdf = s.first),
          ),
          const SizedBox(height: 20),
          Obx(() => PrimaryButton(
                label: 'Export',
                loading: c.exporting.value,
                onPressed: () {
                  if (_to.isBefore(_from)) {
                    Get.snackbar('Check dates', 'The end date must be after the start date.');
                    return;
                  }
                  c.export(_kind, pdf: _pdf, from: _from, to: _to);
                },
              )),
          const SizedBox(height: 12),
          const Text('PDF files use "Rs" instead of the ₹ symbol because the built-in PDF font has no rupee glyph.', style: TextStyle(fontSize: 12)),
        ]),
      );
}
