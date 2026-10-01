import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/entities.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
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
    return AppCard(
      color: AppColors.primary,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${b.period.label} · ${b.period.rangeLabel}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 10),
        const Text('Remaining this cycle', style: TextStyle(color: Colors.white70)),
        FittedBox(fit: BoxFit.scaleDown, child: Text(m(s.remaining), style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800))),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: s.progress, minHeight: 8, borderRadius: BorderRadius.circular(8), backgroundColor: Colors.white24, color: Colors.white),
        const SizedBox(height: 12),
        Row(children: [
          _heroStat('Salary', m(s.totalIncome)),
          _heroStat('Spent', m(s.spent)),
          _heroStat('Pending', m(s.pending)),
        ]),
        if (b.closed) const Padding(padding: EdgeInsets.only(top: 10), child: Text('This cycle is closed', style: TextStyle(color: Colors.white70))),
      ]),
    );
  }

  Widget _heroStat(String l, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
        ]),
      );

  Widget _quick() => StatGrid(minTile: 110, children: [
        _qa(Icons.add_card, 'Expense', () => _open(AppRoutes.expenseAdd, args: {'useCurrent': true})),
        _qa(Icons.payments_outlined, 'Income', () => _open(AppRoutes.budget)),
        _qa(Icons.handshake_outlined, 'Loan', () => _open(AppRoutes.lendingAdd)),
        _qa(Icons.savings_outlined, 'Savings', () => _open(AppRoutes.savingsAdd)),
      ]);

  Widget _qa(IconData i, String l, VoidCallback t) => AppCard(
        onTap: t,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(children: [Icon(i, color: AppColors.primary), const SizedBox(height: 6), Text(l, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))]),
      );

  Widget _stats() => StatGrid(children: [
        StatTile(label: 'Savings wallet', value: m(c.savings), icon: Icons.savings_outlined, color: AppColors.savings),
        StatTile(label: 'Money lent', value: m(c.moneyLent), icon: Icons.handshake_outlined, color: AppColors.lending),
        StatTile(label: 'Interest this cycle', value: m(c.interestThisCycle.value), icon: Icons.percent, color: AppColors.interest),
        StatTile(label: 'Pending interest', value: m(c.interestPending), icon: Icons.hourglass_bottom, color: AppColors.warning),
        StatTile(label: 'Total interest received', value: m(c.interestReceivedTotal), icon: Icons.trending_up, color: AppColors.income),
        StatTile(label: 'Net worth', value: m(c.netWorth), icon: Icons.account_balance, caption: 'Available + savings + principal lent'),
      ]);

  Widget _upcoming() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader('Upcoming expenses', action: 'See all', onAction: () => _open(AppRoutes.budget)),
        if (c.upcoming.isEmpty) const AppCard(child: Text('No expenses planned for this cycle.')),
        for (final i in c.upcoming)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(i.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, color: i.isCompleted ? AppColors.income : AppColors.warning),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(i.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (i.dueDate != null) Text('Due ${Fmt.shortDate(i.dueDate!)}', style: const TextStyle(fontSize: 12)),
              ])),
              Text(m(i.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
      ]);

  Widget _reminders() {
    final list = c.reminders.take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader('Reminders', action: 'All', onAction: () => Get.toNamed(AppRoutes.notifications)),
      if (list.isEmpty) const AppCard(child: Text("You're all caught up.")),
      for (final r in list)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(_kindIcon(r.kind), color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(Fmt.date(r.when), style: const TextStyle(fontSize: 12)),
            ])),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) => AdaptiveShell(
        route: AppRoutes.home,
        child: Scaffold(
          appBar: AppBar(
            title: Obx(() => Text('${Fmt.greeting()}, ${auth.profile.value?.firstName ?? ''}')),
            actions: [
              Obx(() => IconButton(
                    onPressed: () => Get.toNamed(AppRoutes.notifications),
                    icon: Badge(isLabelVisible: c.reminders.isNotEmpty, label: Text('${c.reminders.length > 9 ? '9+' : c.reminders.length}'), child: const Icon(Icons.notifications_outlined)),
                  )),
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
                            final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_hero(), _quick(), const SizedBox(height: 12), _stats()]);
                            final right = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_upcoming(), _reminders()]);
                            if (!wide) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, right]);
                            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(flex: 3, child: left),
                              const SizedBox(width: 20),
                              Expanded(flex: 2, child: right),
                            ]);
                          }),
                        ),
                      ]),
              )),
        ),
      );
}

IconData _kindIcon(String k) => switch (k) {
      'expense' => Icons.receipt_long_outlined,
      'interest' => Icons.percent,
      'salary' => Icons.payments_outlined,
      _ => Icons.savings_outlined,
    };
