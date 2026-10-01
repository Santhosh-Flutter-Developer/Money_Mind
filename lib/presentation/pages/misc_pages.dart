import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/entities.dart';
import '../controllers/auth_controller.dart';
import '../controllers/calendar_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/transactions_controller.dart';
import '../widgets/common.dart';
import '../widgets/txn_actions.dart';

InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    filled: true,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none));

// ------------------------------------------------------------ transactions
class TransactionsPage extends StatefulWidget {
  final TxnType? preset; // used by /expenses
  const TransactionsPage({super.key, this.preset});
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final c = Get.find<TransactionsController>();
  @override
  void initState() {
    super.initState();
    c.type.value = widget.preset;
    c.load();
  }

  Future<void> _filters() async {
    DateTime? from = c.from.value;
    DateTime? to = c.to.value;
    String? cat = c.categoryId.value;
    await Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, set) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20))),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Filters',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: c.categories.any((x) => x.id == cat) ? cat : null,
                    decoration: _dec('Category'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('All categories')),
                      for (final x in c.categories)
                        DropdownMenuItem<String?>(
                            value: x.id, child: Text(x.name))
                    ],
                    onChanged: (v) => set(() => cat = v),
                  ),
                  const SizedBox(height: 14),
                  DateField(
                      label: 'From',
                      value: from,
                      onChanged: (d) => set(() => from = d)),
                  DateField(
                      label: 'To',
                      value: to,
                      onChanged: (d) => set(() => to = d)),
                  PrimaryButton(
                      label: 'Apply',
                      onPressed: () {
                        c.categoryId.value = cat;
                        c.from.value = from;
                        c.to.value = to;
                        Get.back();
                        c.load();
                      }),
                  TextButton(
                      onPressed: () {
                        Get.back();
                        c.clearFilters();
                      },
                      child: const Text('Clear filters')),
                ]),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) => AdaptiveShell(
        route: AppRoutes.transactions,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Transactions'),
            leading: widget.preset != null ? const BackButton() : null,
            actions: [
              Obx(() => IconButton(
                  icon: Badge(
                      isLabelVisible: c.hasFilters,
                      smallSize: 8,
                      child: const Icon(Icons.filter_list)),
                  onPressed: _filters))
            ],
          ),
          body: Column(children: [
            PageBody(
              maxWidth: 900,
              child: Column(children: [
                TextField(
                    onChanged: (v) => c.search.value = v,
                    decoration: InputDecoration(
                        hintText: 'Search description, category or person',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none))),
                SizedBox(
                  height: 48,
                  child: Obx(() =>
                      ListView(scrollDirection: Axis.horizontal, children: [
                        Padding(
                            padding: const EdgeInsets.only(right: 8, top: 6),
                            child: ChoiceChip(
                                label: const Text('All'),
                                selected: c.type.value == null,
                                onSelected: (_) {
                                  c.type.value = null;
                                  c.load();
                                })),
                        for (final t in TxnType.values)
                          Padding(
                              padding: const EdgeInsets.only(right: 8, top: 6),
                              child: ChoiceChip(
                                  label: Text(t.name[0].toUpperCase() +
                                      t.name.substring(1)),
                                  selected: c.type.value == t,
                                  onSelected: (_) {
                                    c.type.value = t;
                                    c.load();
                                  })),
                      ])),
                ),
              ]),
            ),
            Expanded(
              child: Obx(() => LoadState(
                    loading: c.loading.value,
                    error: c.error.value,
                    hasData: c.all.isNotEmpty,
                    onRetry: c.load,
                    child: c.visible.isEmpty
                        ? ListView(children: const [
                            SizedBox(height: 60),
                            EmptyState(
                                icon: Icons.receipt_long_outlined,
                                title: 'No transactions found',
                                subtitle: 'Try a different filter or search.')
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: c.visible.length,
                            itemBuilder: (_, i) => PageBody(
                                maxWidth: 900,
                                child: TxnTile(
                                    txn: c.visible[i],
                                    currency: c.currency,
                                    onTap: () => TxnActions.show(
                                        c.visible[i], c.currency))),
                          ),
                  )),
            ),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- calendar
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final c = Get.find<CalendarController>();
  @override
  void initState() {
    super.initState();
    c.load();
  }

  Color _color(String k) => switch (k) {
        'salary' => AppColors.income,
        'expense' => AppColors.expense,
        'expense_due' => AppColors.warning,
        'interest' => AppColors.interest,
        'interest_due' => const Color(0xFFD946EF),
        'loan' => AppColors.lending,
        _ => AppColors.savings,
      };

  Widget _grid() {
    final first = c.month.value;
    final days = DateTime(first.year, first.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday first
    final cells = <Widget>[
      for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
        Center(
            child:
                Text(d, style: const TextStyle(fontWeight: FontWeight.w700))),
      for (var i = 0; i < lead; i++) const SizedBox(),
      for (var d = 1; d <= days; d++)
        _cell(DateTime(first.year, first.month, d)),
    ];
    return GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.05,
        children: cells);
  }

  Widget _cell(DateTime d) {
    final ev = c.eventsOn(d);
    final sel = c.selected.value == d;
    final today = d == Fmt.today();
    final kinds = ev.map((e) => e.kind).toSet().take(4);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => c.selected.value = d,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary.withOpacity(0.16) : null,
          border: today ? Border.all(color: AppColors.primary) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${d.day}',
              style: TextStyle(
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500)),
          const SizedBox(height: 3),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final k in kinds)
              Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration:
                      BoxDecoration(color: _color(k), shape: BoxShape.circle))
          ]),
        ]),
      ),
    );
  }

  Widget _details() {
    final list = c.eventsOn(c.selected.value);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(Fmt.date(c.selected.value)),
      if (list.isEmpty) const AppCard(child: Text('Nothing on this day.')),
      for (final e in list)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: _color(e.kind), shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(child: Text(e.title)),
            if (e.amount != null)
              Text(MoneyUtils.format(e.amount!, currency: c.currency),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            if (!e.done)
              const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: StatusChip('Due', AppColors.warning)),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) => AdaptiveShell(
        route: AppRoutes.calendar,
        child: Scaffold(
          appBar: AppBar(
              title: const Text('Calendar'), leading: const BackButton()),
          body: Obx(() => LoadState(
                loading: c.loading.value,
                error: c.error.value,
                hasData: c.events.isNotEmpty,
                onRetry: c.load,
                child: ListView(children: [
                  PageBody(
                    maxWidth: 1000,
                    child: LayoutBuilder(
                        builder: (context, box) => Obx(() {
                              final cal = Column(children: [
                                MonthSwitcher(
                                    title: Fmt.monthYear(c.month.value),
                                    subtitle: '',
                                    onPrev: () => c.shift(-1),
                                    onNext: () => c.shift(1)),
                                _grid()
                              ]);
                              if (box.maxWidth > 760)
                                return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 3, child: cal),
                                      const SizedBox(width: 24),
                                      Expanded(flex: 2, child: _details())
                                    ]);
                              return Column(children: [
                                cal,
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: _details())
                              ]);
                            })),
                  ),
                ]),
              )),
        ),
      );
}

// ----------------------------------------------------------- notifications
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final home = Get.find<HomeController>();
  final auth = Get.find<AuthController>();
  @override
  void initState() {
    super.initState();
    if (home.budget.value == null) home.load();
  }

  Widget _toggle(String label, String field, bool value) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: (v) async {
          await auth.saveSettings({field: v});
          home.load();
        },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: ListView(children: [
          PageBody(
            maxWidth: 700,
            child: Obx(() {
              final s = auth.settings.value;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader('Upcoming reminders'),
                    if (home.reminders.isEmpty)
                      const AppCard(child: Text("You're all caught up.")),
                    for (final r in home.reminders)
                      AppCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(children: [
                          const Icon(Icons.notifications_active_outlined,
                              color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(r.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text('${r.body} · ${Fmt.date(r.when)}',
                                    style: const TextStyle(fontSize: 12))
                              ])),
                        ]),
                      ),
                    const SectionHeader('Settings'),
                    AppCard(
                        child: Column(children: [
                      _toggle('Expense due reminders', 'expense_reminders',
                          s.expenseReminders),
                      _toggle('Interest due reminders', 'interest_reminders',
                          s.interestReminders),
                      _toggle('Salary day reminder', 'salary_reminder',
                          s.salaryReminder),
                      _toggle('Cycle closing reminder', 'closing_reminder',
                          s.closingReminder),
                      const SizedBox(height: 8),
                      TimeField(
                        label: 'Daily reminder time',
                        minutes: s.reminderHour * 60 + s.reminderMinute,
                        onChanged: (v) async {
                          if (v == null) return;
                          await auth.saveSettings({
                            'reminder_hour': v ~/ 60,
                            'reminder_minute': v % 60
                          });
                          home.load();
                        },
                      ),
                    ])),
                    const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                            'Phone notifications are delivered on Android and iOS. On web and desktop, reminders appear in this list.',
                            style: TextStyle(fontSize: 12))),
                  ]);
            }),
          ),
        ]),
      );
}

// ------------------------------------------------------------ settings/more
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _tile(IconData i, String t, VoidCallback onTap,
      {String? sub, Color? color}) {
    final c = color ?? categoryColor(t);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      onTap: onTap,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                gradient: AppGradients.of(c),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(i, color: Colors.white, size: 22)),
        title: Text(t,
            style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        subtitle: sub == null ? null : Text(sub),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return AdaptiveShell(
      route: AppRoutes.settings,
      child: Scaffold(
        appBar: AppBar(title: const Text('More')),
        body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          PageBody(
            maxWidth: 700,
            child: Obx(() {
              final p = auth.profile.value;
              final mode = Get.isDarkMode;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: () => Get.toNamed(AppRoutes.profile),
                      child: GradientCard(
                        child: Row(children: [
                          CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white24,
                              child: Text(
                                  (p?.name.isNotEmpty ?? false)
                                      ? p!.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800))),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(p?.name ?? '',
                                    style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                                Text(p?.email ?? '',
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              ])),
                          const Icon(Icons.chevron_right, color: Colors.white),
                        ]),
                      ),
                    ),
                    _tile(Icons.payments_outlined, 'Salary & cycle',
                        () => Get.toNamed(AppRoutes.salarySettings),
                        sub: p == null
                            ? null
                            : 'Salary day ${p.salaryDay} · ${p.usesSalaryCycle ? 'Salary cycle' : 'Calendar month'}'),
                    _tile(Icons.repeat, 'Recurring expenses',
                        () => Get.toNamed(AppRoutes.recurring)),
                    _tile(Icons.category_outlined, 'Categories',
                        () => Get.toNamed(AppRoutes.categories)),
                    _tile(Icons.savings_outlined, 'Savings wallet',
                        () => Get.toNamed(AppRoutes.savings)),
                    _tile(Icons.receipt_long_outlined, 'Transactions',
                        () => Get.toNamed(AppRoutes.transactions)),
                    _tile(Icons.calendar_month_outlined, 'Calendar',
                        () => Get.toNamed(AppRoutes.calendar)),
                    _tile(Icons.notifications_outlined, 'Notifications',
                        () => Get.toNamed(AppRoutes.notifications)),
                    _tile(Icons.download_outlined, 'Export data',
                        () => Get.toNamed(AppRoutes.reportExport)),
                    AppCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Appearance',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                    value: ThemeMode.system,
                                    label: Text('System',
                                        style: TextStyle(fontSize: 11))),
                                ButtonSegment(
                                    value: ThemeMode.light,
                                    label: Text('Light',
                                        style: TextStyle(fontSize: 11))),
                                ButtonSegment(
                                    value: ThemeMode.dark,
                                    label: Text('Dark',
                                        style: TextStyle(fontSize: 11)))
                              ],
                              selected: {
                                auth.settings.value.themeMode == 'dark'
                                    ? ThemeMode.dark
                                    : auth.settings.value.themeMode == 'light'
                                        ? ThemeMode.light
                                        : ThemeMode.system
                              },
                              onSelectionChanged: (s) => auth.setTheme(s.first),
                            ),
                            if (mode) const SizedBox(),
                          ]),
                    ),
                    if (AppConstants.demoMode || kDebugMode)
                      _tile(Icons.science_outlined, 'Load demo data', () async {
                        if (await confirmDialog('Load demo data?',
                            'Adds a sample salary setup, recurring expenses, savings and two loans. Only works on an empty account.'))
                          auth.loadDemoData();
                      }),
                    _tile(
                        Icons.privacy_tip_outlined,
                        'Privacy & terms',
                        () => Get.dialog(AlertDialog(
                              title: const Text('Privacy & terms'),
                              content: SelectableText(
                                  'Privacy Policy: ${AppConstants.privacyUrl}\nTerms: ${AppConstants.termsUrl}\n\nYour data is stored in your own Supabase project and protected by Row Level Security.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Get.back(),
                                    child: const Text('Close'))
                              ],
                            ))),
                    _tile(
                        Icons.info_outline,
                        'About MoneyMind',
                        () => showAboutDialog(
                            context: context,
                            applicationName: AppConstants.appName,
                            applicationVersion: '1.0.0',
                            applicationLegalese: AppConstants.tagline)),
                    _tile(Icons.logout, 'Log out', () async {
                      if (await confirmDialog(
                          'Log out?', 'You will need to sign in again.',
                          confirm: 'Log out')) auth.logout();
                    }, color: AppColors.expense),
                  ]);
            }),
          ),
        ]),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final auth = Get.find<AuthController>();
  final _form = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: auth.profile.value?.name ?? '');
  late String _currency = auth.profile.value?.currency ?? 'INR';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _password() async {
    final p = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('Change password'),
      content: Form(
          key: key,
          child: AppTextField(
              controller: p,
              label: 'New password',
              obscure: true,
              validator: Validators.password)),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () {
              if (key.currentState!.validate()) Get.back(result: true);
            },
            child: const Text('Update'))
      ],
    ));
    if (ok == true) await auth.updatePassword(p.text);
  }

  @override
  Widget build(BuildContext context) => FormScaffold(
        title: 'Profile',
        child: Form(
          key: _form,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 8),
            AppTextField(
                controller: _name,
                label: 'Name',
                validator: (v) => Validators.required(v, 'Name')),
            InputDecorator(
                decoration: _dec('Email'),
                child: Text(auth.profile.value?.email ?? '')),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
                value: _currency,
                decoration: _dec('Currency'),
                items: [
                  for (final c in AppConstants.supportedCurrencies)
                    DropdownMenuItem(value: c, child: Text(c))
                ],
                onChanged: (v) => setState(() => _currency = v ?? _currency)),
            const SizedBox(height: 20),
            Obx(() => PrimaryButton(
                label: 'Save',
                loading: auth.busy.value,
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  if (await auth.saveProfile(
                      {'name': _name.text.trim(), 'currency': _currency}))
                    Get.back();
                })),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _password, child: const Text('Change password')),
          ]),
        ),
      );
}

class SalarySettingsPage extends StatefulWidget {
  const SalarySettingsPage({super.key});
  @override
  State<SalarySettingsPage> createState() => _SalarySettingsPageState();
}

class _SalarySettingsPageState extends State<SalarySettingsPage> {
  final auth = Get.find<AuthController>();
  final _form = GlobalKey<FormState>();
  late final _salary = TextEditingController(
      text: auth.profile.value?.defaultSalary.toString() ?? '0');
  late int _day = auth.salaryDay;
  late bool _salaryCycle = auth.profile.value?.usesSalaryCycle ?? true;

  @override
  void dispose() {
    _salary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormScaffold(
        title: 'Salary & cycle',
        child: Form(
          key: _form,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 8),
            AmountField(
                controller: _salary,
                label: 'Default monthly salary',
                currency: auth.currency,
                allowZero: true),
            DayField(
                label: 'Salary day',
                value: _day,
                max: 28,
                onChanged: (v) => setState(() => _day = v ?? _day)),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use salary cycle'),
                subtitle: Text(_salaryCycle
                    ? 'Cycle runs from salary day to the day before the next one.'
                    : 'Cycle follows the calendar month (1st to last day).'),
                value: _salaryCycle,
                onChanged: (v) => setState(() => _salaryCycle = v)),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    'Changes apply to new cycles. Existing cycles and history are never rewritten.',
                    style: TextStyle(fontSize: 12))),
            Obx(() => PrimaryButton(
                label: 'Save',
                loading: auth.busy.value,
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  final ok = await auth.saveProfile({
                    'default_salary':
                        MoneyUtils.toDb(MoneyUtils.tryParse(_salary.text)!),
                    'salary_day': _day,
                    'cycle_mode':
                        _salaryCycle ? 'salary_cycle' : 'calendar_month',
                  });
                  if (ok) Get.back();
                })),
          ]),
        ),
      );
}

// ------------------------------------------------- categories & recurring
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final c = Get.find<SettingsController>();
  @override
  void initState() {
    super.initState();
    c.load();
  }

  Future<void> _edit(ExpenseCategory? cat) async {
    final t = TextEditingController(text: cat?.name ?? '');
    final key = GlobalKey<FormState>();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: Text(cat == null ? 'New category' : 'Rename category'),
      content: Form(
          key: key,
          child: AppTextField(
              controller: t,
              label: 'Name',
              validator: (v) => Validators.required(v, 'Name'))),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () {
              if (key.currentState!.validate()) Get.back(result: true);
            },
            child: const Text('Save'))
      ],
    ));
    if (ok == true)
      cat == null
          ? await c.addCategory(t.text)
          : await c.renameCategory(cat, t.text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Categories')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add),
            label: const Text('Category')),
        body: Obx(() => LoadState(
              loading: c.loading.value,
              error: c.error.value,
              hasData: c.categories.isNotEmpty,
              onRetry: c.load,
              child: ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    PageBody(
                        maxWidth: 700,
                        child: Column(children: [
                          for (final cat in c.categories)
                            AppCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.label_outline,
                                    color: AppColors.primary),
                                title: Text(cat.name),
                                subtitle: cat.isDefault
                                    ? const Text('Default')
                                    : null,
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _edit(cat)),
                                      IconButton(
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          onPressed: () async {
                                            if (await confirmDialog(
                                                'Delete ${cat.name}?',
                                                'Existing expenses keep their name but lose this category.',
                                                confirm: 'Delete',
                                                danger: true))
                                              c.deleteCategory(cat);
                                          }),
                                    ]),
                              ),
                            ),
                        ])),
                  ]),
            )),
      );
}

class RecurringPage extends StatefulWidget {
  const RecurringPage({super.key});
  @override
  State<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends State<RecurringPage> {
  final c = Get.find<SettingsController>();
  final cur = Get.find<AuthController>().currency;
  @override
  void initState() {
    super.initState();
    c.load();
  }

  Future<void> _edit(RecurringExpense? r) async {
    final name = TextEditingController(text: r?.name ?? '');
    final amount = TextEditingController(text: r?.amount.toString() ?? '');
    int? day = r?.dueDay;
    final notes = TextEditingController(text: r?.notes ?? '');
    String? cat = r?.categoryId;
    bool active = r?.isActive ?? true;
    final key = GlobalKey<FormState>();
    final ok = await Get.dialog<bool>(StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(
            r == null ? 'New recurring expense' : 'Edit recurring expense'),
        content: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AppTextField(
                  controller: name,
                  label: 'Name',
                  validator: (v) => Validators.required(v, 'Name')),
              AmountField(controller: amount, currency: cur),
              DropdownButtonFormField<String?>(
                value: c.categories.any((x) => x.id == cat) ? cat : null,
                decoration: _dec('Category'),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('No category')),
                  for (final x in c.categories)
                    DropdownMenuItem<String?>(value: x.id, child: Text(x.name))
                ],
                onChanged: (v) => set(() => cat = v),
              ),
              const SizedBox(height: 14),
              DayField(
                  label: 'Due day (optional)',
                  value: day,
                  optional: true,
                  onChanged: (v) => set(() => day = v)),
              AppTextField(controller: notes, label: 'Notes (optional)'),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: active,
                  onChanged: (v) => set(() => active = v)),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                if (key.currentState!.validate()) Get.back(result: true);
              },
              child: const Text('Save'))
        ],
      ),
    ));
    if (ok == true) {
      await c.saveRecurring(
          existing: r,
          name: name.text,
          categoryId: cat,
          amount: MoneyUtils.tryParse(amount.text)!,
          dueDay: day,
          active: active,
          notes: notes.text);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Recurring expenses')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add),
            label: const Text('Add')),
        body: Obx(() => LoadState(
              loading: c.loading.value,
              error: c.error.value,
              hasData: c.recurring.isNotEmpty,
              onRetry: c.load,
              child: c.recurring.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 80),
                      EmptyState(
                          icon: Icons.repeat,
                          title: 'No recurring expenses',
                          subtitle:
                              'Add rent, EMI, RD or bills once and they are created every cycle.',
                          actionLabel: 'Add expense',
                          onAction: () => _edit(null))
                    ])
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: [
                          PageBody(
                              maxWidth: 700,
                              child: Column(children: [
                                for (final r in c.recurring)
                                  AppCard(
                                    onTap: () => _edit(r),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    child: Row(children: [
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(r.name,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            Text(
                                                [
                                                  if (r.categoryName != null)
                                                    r.categoryName!,
                                                  if (r.dueDay != null)
                                                    'Day ${r.dueDay}',
                                                  if (!r.isActive) 'Paused'
                                                ].join(' · '),
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                          ])),
                                      Text(
                                          MoneyUtils.format(r.amount,
                                              currency: cur),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800)),
                                      IconButton(
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          onPressed: () async {
                                            if (await confirmDialog(
                                                'Delete ${r.name}?',
                                                'Past cycles are unchanged.',
                                                confirm: 'Delete',
                                                danger: true))
                                              c.deleteRecurring(r);
                                          }),
                                    ]),
                                  ),
                              ])),
                        ]),
            )),
      );
}
