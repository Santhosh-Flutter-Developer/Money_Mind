import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final c = Get.find<HomeController>();
  final auth = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    c.load();
  }

  String m(dynamic d) => MoneyUtils.format(d, currency: c.currency);

  Future<void> _open(String route, {Object? args}) async {
    await Get.toNamed(route, arguments: args);
    c.load();
  }

  Widget _hero() {
    final s = c.summary!;
    final b = c.budget.value!;
    const white = TextStyle(color: Colors.white);
    return GradientCard(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text('${b.period.label} · ${b.period.rangeLabel}', style: white.copyWith(color: Colors.white70, fontSize: 12))),
          if (b.closed) const StatusChip('Closed', Colors.white),
        ]),
        const SizedBox(height: 14),
        Text('Remaining this cycle', style: white.copyWith(color: Colors.white70)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AnimatedAmount(value: s.remaining, currency: c.currency, style: white.copyWith(fontSize: 40, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 14),
        GradientProgress(value: s.progress, track: Colors.white24, height: 9, gradient: const LinearGradient(colors: [Colors.white, Color(0xB3FFFFFF)])),
        const SizedBox(height: 4),
        Text('${(s.progress * 100).round()}% of income spent', style: white.copyWith(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 14),
        Row(children: [
          _heroStat(Icons.south_west_rounded, 'Income', m(s.totalIncome)),
          _heroStat(Icons.north_east_rounded, 'Spent', m(s.spent)),
          _heroStat(Icons.hourglass_bottom_rounded, 'Pending', m(s.pending)),
        ]),
      ]),
    );
  }

  Widget _heroStat(IconData i, String l, String v) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(i, size: 13, color: Colors.white70), const SizedBox(width: 4), Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11))]),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
          ]),
        ),
      );

  Widget _quick() => StatGrid(minTile: 100, children: [
        _qa(Icons.add_card_rounded, 'Expense', AppGradients.rose, () => _open(AppRoutes.expenseAdd, args: {'useCurrent': true})),
        _qa(Icons.payments_rounded, 'Income', AppGradients.mint, () => _open(AppRoutes.budget)),
        _qa(Icons.handshake_rounded, 'Loan', AppGradients.ocean, () => _open(AppRoutes.lendingAdd)),
        _qa(Icons.savings_rounded, 'Savings', AppGradients.gold, () => _open(AppRoutes.savingsAdd)),
      ]);

  Widget _qa(IconData i, String l, Gradient g, VoidCallback t) => AppCard(
        onTap: t,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: (g as LinearGradient).colors.first.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Icon(i, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(l, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );

  Widget _stats() => StatGrid(children: [
        StatTile(label: 'Savings wallet', value: m(c.savings), icon: Icons.savings_rounded, color: AppColors.savings),
        StatTile(label: 'Money lent', value: m(c.moneyLent), icon: Icons.handshake_rounded, color: AppColors.lending),
        StatTile(label: 'Interest this cycle', value: m(c.interestThisCycle.value), icon: Icons.percent_rounded, color: AppColors.interest),
        StatTile(label: 'Pending interest', value: m(c.interestPending), icon: Icons.hourglass_bottom_rounded, color: AppColors.warning),
        StatTile(label: 'Total interest received', value: m(c.interestReceivedTotal), icon: Icons.trending_up_rounded, color: AppColors.income),
        StatTile(label: 'Net worth', value: m(c.netWorth), icon: Icons.account_balance_rounded, color: AppColors.pink, caption: 'Available + savings + principal lent'),
      ]);

  Widget _chartCard(String title, String subtitle, Widget child) => AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _noData(String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 36), child: Center(child: Text(text, textAlign: TextAlign.center)));

  Widget _charts() {
    final cats = c.categorySpend;
    final top = <String, double>{};
    var other = 0.0;
    var idx = 0;
    for (final e in cats.entries) {
      if (idx++ < 5) {
        top[e.key] = e.value.toDouble();
      } else {
        other += e.value.toDouble();
      }
    }
    if (other > 0) top['Other'] = (top['Other'] ?? 0) + other;
    final total = cats.values.fold<double>(0, (a, b) => a + b.toDouble());
    final labels = [for (final b in c.trend) Fmt.monthShort(b.periodStart)];
    final spentVals = [for (final b in c.trend) b.spent.toDouble()];

    final donut = top.isEmpty
        ? _noData('Add expenses to see where your money goes.')
        : Column(children: [
            CategoryPie(data: top, centerTop: MoneyUtils.compact(Decimal.parse(total.toStringAsFixed(2)), currency: c.currency), centerBottom: c.categoryIsPlanned ? 'Planned' : 'Spent'),
            const SizedBox(height: 8),
            ChartLegend(items: [for (var i = 0; i < top.length; i++) ('${top.keys.elementAt(i)} · ${MoneyUtils.compact(Decimal.parse(top.values.elementAt(i).toStringAsFixed(2)), currency: c.currency)}', chartPalette[i % chartPalette.length])]),
          ]);

    return StatGrid(minTile: 330, children: [
      _chartCard('Where your money goes', c.categoryIsPlanned ? 'Planned this cycle' : 'Spent this cycle', donut),
      _chartCard(
        'Income vs spent',
        c.trend.isEmpty ? 'No cycles yet' : 'Last ${c.trend.length} cycle${c.trend.length == 1 ? '' : 's'}',
        c.trend.isEmpty
            ? _noData('Your history will appear here.')
            : Column(children: [
                GroupedBars(labels: labels, series: [[for (final b in c.trend) b.totalIncome.toDouble()], spentVals], colors: const [AppColors.income, AppColors.expense]),
                const SizedBox(height: 8),
                const ChartLegend(items: [('Income', AppColors.income), ('Spent', AppColors.expense)]),
              ]),
      ),
      _chartCard(
        'Spending trend',
        'Completed expenses per cycle',
        c.trend.length < 2 ? _noData('Needs at least two cycles.') : TrendLine(labels: labels, values: spentVals, color: AppColors.primary),
      ),
      _chartCard(
        'Savings per cycle',
        'Moved to your savings wallet',
        c.trend.isEmpty ? _noData('Close a cycle to see savings.') : GroupedBars(labels: labels, series: [[for (final b in c.trend) b.savingsTransferred.toDouble()]], colors: const [AppColors.savings]),
      ),
    ]);
  }

  Widget _upcoming() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader('Upcoming expenses', action: 'See all', onAction: () => _open(AppRoutes.budget)),
        if (c.upcoming.isEmpty) const AppCard(child: Text('No expenses planned for this cycle.')),
        for (final i in c.upcoming)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              CategoryAvatar(name: i.categoryName ?? i.name),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(i.name, style: TextStyle(fontWeight: FontWeight.w600, decoration: i.isCompleted ? TextDecoration.lineThrough : null)),
                if (i.dueDate != null) Text('Due ${Fmt.shortDate(i.dueDate!)}', style: const TextStyle(fontSize: 12)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(m(i.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                i.isCompleted ? const StatusChip('Paid', AppColors.income) : const StatusChip('Pending', AppColors.warning),
              ]),
            ]),
          ),
      ]);

  Widget _reminders() {
    final list = c.reminders.take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader('Reminders', action: 'All', onAction: () => Get.toNamed(AppRoutes.notifications)),
      if (list.isEmpty) const AppCard(child: Text("You're all caught up. 🎉")),
      for (final r in list)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _kindColor(r.kind).withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
              child: Icon(_kindIcon(r.kind), color: _kindColor(r.kind), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(Fmt.date(r.when), style: const TextStyle(fontSize: 12)),
            ])),
          ]),
        ),
    ]);
  }

  Widget _header() => Obx(() {
        final p = auth.profile.value;
        return Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: AppGradients.brand, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]),
            alignment: Alignment.center,
            child: Text((p?.name.isNotEmpty ?? false) ? p!.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(Fmt.greeting(), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text(p?.firstName ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ]);
      });

  @override
  Widget build(BuildContext context) => AdaptiveShell(
        route: AppRoutes.home,
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 68,
            title: _header(),
            actions: [
              Obx(() => IconButton(
                    onPressed: () => Get.toNamed(AppRoutes.notifications),
                    icon: Badge(isLabelVisible: c.reminders.isNotEmpty, label: Text('${c.reminders.length > 9 ? '9+' : c.reminders.length}'), child: const Icon(Icons.notifications_none_rounded, size: 28)),
                  )),
              const SizedBox(width: 6),
            ],
          ),
          body: Obx(() => LoadState(
                loading: c.loading.value,
                error: c.error.value,
                hasData: c.budget.value != null,
                onRetry: c.load,
                child: c.budget.value == null
                    ? const SizedBox()
                    : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                        PageBody(
                          child: LayoutBuilder(builder: (context, box) {
                            final wide = box.maxWidth > 820;
                            final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Appear(child: _hero()),
                              Appear(delayMs: 80, child: _quick()),
                              const SizedBox(height: 12),
                              Appear(delayMs: 160, child: _stats()),
                              const SectionHeader('Insights'),
                              Appear(delayMs: 240, child: _charts()),
                            ]);
                            final right = Appear(delayMs: 240, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_upcoming(), _reminders()]));
                            if (!wide) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, right]);
                            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: left), const SizedBox(width: 20), Expanded(flex: 2, child: right)]);
                          }),
                        ),
                      ]),
              )),
        ),
      );
}

IconData _kindIcon(String k) => switch (k) {
      'expense' => Icons.receipt_long_rounded,
      'interest' => Icons.percent_rounded,
      'salary' => Icons.payments_rounded,
      _ => Icons.savings_rounded,
    };

Color _kindColor(String k) => switch (k) {
      'expense' => AppColors.expense,
      'interest' => AppColors.interest,
      'salary' => AppColors.income,
      _ => AppColors.savings,
    };