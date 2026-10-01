import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/entities.dart';
import '../../domain/services/lending_logic.dart';
import '../controllers/auth_controller.dart';
import '../controllers/lending_controller.dart';
import '../widgets/common.dart';

class LendingPage extends StatefulWidget {
  const LendingPage({super.key});
  @override
  State<LendingPage> createState() => _LendingPageState();
}

class _LendingPageState extends State<LendingPage> {
  final c = Get.find<LendingController>();

  @override
  void initState() {
    super.initState();
    c.load();
  }

  String m(Decimal d) => MoneyUtils.format(d, currency: c.currency);

  Future<void> _add() async {
    await Get.toNamed(AppRoutes.lendingAdd);
    c.load();
  }

  @override
  Widget build(BuildContext context) => AdaptiveShell(
        route: AppRoutes.lending,
        child: Scaffold(
          appBar: AppBar(title: const Text('Lending')),
          floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add loan')),
          body: Obx(() => LoadState(
                loading: c.loading.value,
                error: c.error.value,
                hasData: c.loans.isNotEmpty,
                onRetry: c.load,
                child: c.loans.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 80),
                        EmptyState(icon: Icons.handshake_outlined, title: 'No loans yet', subtitle: 'Add money you have lent and track monthly interest.', actionLabel: 'Add loan', onAction: _add),
                      ])
                    : ListView(padding: const EdgeInsets.only(bottom: 96), children: [
                        PageBody(
                          maxWidth: 1000,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            StatGrid(children: [
                              StatTile(label: 'Total money lent', value: m(c.totalLent), icon: Icons.handshake_outlined, color: AppColors.lending),
                              StatTile(label: 'Interest received', value: m(c.interestReceived), icon: Icons.trending_up, color: AppColors.income),
                              StatTile(label: 'Pending interest', value: m(c.pendingInterest), icon: Icons.hourglass_bottom, color: AppColors.warning),
                              StatTile(label: 'Active loans', value: '${c.active.length}', icon: Icons.people_outline),
                            ]),
                            const SizedBox(height: 8),
                            TextField(
                              onChanged: (v) => c.search.value = v,
                              decoration: InputDecoration(hintText: 'Search borrower', prefixIcon: const Icon(Icons.search), filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                            ),
                            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Show closed loans'), value: c.showClosed.value, onChanged: (v) => c.showClosed.value = v),
                            for (final l in c.visible) _loanCard(l),
                          ]),
                        ),
                      ]),
              )),
        ),
      );

  Widget _loanCard(Loan l) {
    final status = c.thisMonthStatus(l.id);
    final pending = c.pendingFrom(l.id);
    return AppCard(
      onTap: () async {
        await Get.toNamed(AppRoutes.loanOf(l.id));
        c.load();
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: AppColors.lending.withOpacity(0.14), child: Text(l.personName.isEmpty ? '?' : l.personName[0].toUpperCase(), style: const TextStyle(color: AppColors.lending, fontWeight: FontWeight.w800))),
          const SizedBox(width: 12),
          Expanded(child: Text(l.personName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          if (!l.active) const StatusChip('Closed', AppColors.transfer) else if (status != null) interestChip(status),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _kv('Principal', m(l.principal))),
          Expanded(child: _kv('Rate', '${Fmt.rate(l.rate.toDouble())}% / month')),
          Expanded(child: _kv('Monthly interest', m(InterestCalculator.monthly(l.principal, l.rate)))),
        ]),
        if (pending > Decimal.zero)
          Padding(padding: const EdgeInsets.only(top: 10), child: Text('Pending interest: ${m(pending)}', style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _kv(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(fontSize: 12)),
        FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]);
}

/// Add a loan, or edit one when a [Loan] is passed as argument.
class LoanFormPage extends StatefulWidget {
  const LoanFormPage({super.key});
  @override
  State<LoanFormPage> createState() => _LoanFormPageState();
}

class _LoanFormPageState extends State<LoanFormPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _principal = TextEditingController();
  final _rate = TextEditingController();
  final _day = TextEditingController();
  final _notes = TextEditingController();
  DateTime _start = Fmt.today();
  Loan? _edit;
  final cur = Get.find<AuthController>().currency;

  @override
  void initState() {
    super.initState();
    final a = Get.arguments;
    if (a is Loan) {
      _edit = a;
      _name.text = a.personName;
      _phone.text = a.phone ?? '';
      _principal.text = a.principal.toString();
      _rate.text = a.rate.toString();
      _day.text = a.expectedDay?.toString() ?? '';
      _notes.text = a.notes ?? '';
      _start = a.startDate;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _principal, _rate, _day, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Decimal? get _monthly {
    final p = MoneyUtils.tryParse(_principal.text);
    final r = MoneyUtils.tryParse(_rate.text);
    if (p == null || r == null || p <= Decimal.zero || r < Decimal.zero) return null;
    return InterestCalculator.monthly(p, r);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final principal = MoneyUtils.tryParse(_principal.text)!;
    final rate = MoneyUtils.tryParse(_rate.text)!;
    final day = int.tryParse(_day.text);
    bool ok;
    if (_edit != null) {
      final dc = Get.find<LoanDetailController>(tag: _edit!.id);
      ok = await dc.editLoan(name: _name.text, phone: _phone.text, principal: principal, rate: rate, expectedDay: day, notes: _notes.text);
    } else {
      ok = await Get.find<LendingController>().createLoan(name: _name.text, phone: _phone.text, principal: principal, rate: rate, start: _start, expectedDay: day, notes: _notes.text);
    }
    if (ok) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final saving = _edit != null ? Get.find<LoanDetailController>(tag: _edit!.id).saving : Get.find<LendingController>().saving;
    return FormScaffold(
      title: _edit == null ? 'Add loan' : 'Edit loan',
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 8),
          AppTextField(controller: _name, label: 'Borrower name', validator: (v) => Validators.required(v, 'Name'), prefixIcon: Icons.person_outline),
          AppTextField(controller: _phone, label: 'Phone (optional)', keyboard: TextInputType.phone, prefixIcon: Icons.phone_outlined),
          AmountField(controller: _principal, label: 'Principal amount', currency: cur),
          AppTextField(controller: _rate, label: 'Interest rate (% per month)', keyboard: const TextInputType.numberWithOptions(decimal: true), validator: Validators.rate, onChanged: (_) => setState(() {})),
          if (_monthly != null)
            AppCard(color: AppColors.interest.withOpacity(0.08), child: Text('Monthly interest: ${MoneyUtils.format(_monthly!, currency: cur)}', style: const TextStyle(fontWeight: FontWeight.w700))),
          DateField(label: 'Loan start date', value: _start, last: Fmt.today(), onChanged: (d) => setState(() => _start = d)),
          if (_edit != null) const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Start date cannot be changed. New rate or principal applies to future months only; past months keep their amounts.', style: TextStyle(fontSize: 12))),
          AppTextField(controller: _day, label: 'Expected interest day of month (optional)', keyboard: TextInputType.number, validator: (v) => (v ?? '').isEmpty ? null : Validators.day(v)),
          AppTextField(controller: _notes, label: 'Notes (optional)', maxLines: 2),
          Obx(() => PrimaryButton(label: 'Save loan', loading: saving.value, onPressed: _save)),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class LoanDetailPage extends StatefulWidget {
  const LoanDetailPage({super.key});
  @override
  State<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends State<LoanDetailPage> {
  late final String id = Get.parameters['id']!;
  late final LoanDetailController c = Get.find<LoanDetailController>(tag: id);
  final cur = Get.find<AuthController>().currency;

  @override
  void initState() {
    super.initState();
    c.load();
  }

  String m(Decimal d) => MoneyUtils.format(d, currency: cur);

  Future<void> _closeLoan() async {
    final l = c.loan.value!;
    final amount = TextEditingController(text: l.principal.toString());
    final notes = TextEditingController();
    final key = GlobalKey<FormState>();
    DateTime date = Fmt.today();
    final ok = await Get.dialog<bool>(StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('Close loan – ${l.personName}'),
        content: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (c.pending > Decimal.zero) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${m(c.pending)} of interest is still pending. It stays on record after closing.', style: const TextStyle(color: AppColors.warning, fontSize: 13))),
              AmountField(controller: amount, label: 'Principal returned', currency: cur),
              DateField(label: 'Return date', value: date, onChanged: (d) => set(() => date = d)),
              AppTextField(controller: notes, label: 'Notes (optional)'),
              const Text('Returned principal is not income. History is kept.', style: TextStyle(fontSize: 12)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(onPressed: () { if (key.currentState!.validate()) Get.back(result: true); }, child: const Text('Close loan')),
        ],
      ),
    ));
    if (ok == true) await c.closeLoan(MoneyUtils.tryParse(amount.text)!, date, notes.text);
  }

  Future<void> _pay() async {
    await Get.toNamed(AppRoutes.paymentOf(id));
    c.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Obx(() => Text(c.loan.value?.personName ?? 'Loan')), actions: [
          Obx(() => c.loan.value?.active == true
              ? IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    await Get.toNamed(AppRoutes.lendingAdd, arguments: c.loan.value);
                    c.load();
                  })
              : const SizedBox()),
        ]),
        body: Obx(() => LoadState(
              loading: c.loading.value,
              error: c.error.value,
              hasData: c.loan.value != null,
              onRetry: c.load,
              child: c.loan.value == null
                  ? const SizedBox()
                  : ListView(padding: const EdgeInsets.only(bottom: 32), children: [PageBody(maxWidth: 800, child: _content(c.loan.value!))]),
            )),
      );

  Widget _content(Loan l) {
    final today = Fmt.today();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(m(l.principal), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800))),
            l.active ? const StatusChip('Active', AppColors.income) : const StatusChip('Closed', AppColors.transfer),
          ]),
          const SizedBox(height: 4),
          Text('${Fmt.rate(l.rate.toDouble())}% per month · ${m(InterestCalculator.monthly(l.principal, l.rate))} interest'),
          Text('Started ${Fmt.date(l.startDate)}${l.closedOn != null ? ' · Closed ${Fmt.date(l.closedOn!)}' : ''}'),
          if (l.phone != null) Text('Phone: ${l.phone}'),
          if (!l.active) Text('Principal returned: ${m(l.principalReturned)}'),
          if (l.notes != null && l.notes!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.notes!)),
        ]),
      ),
      StatGrid(minTile: 150, children: [
        StatTile(label: 'Interest received', value: m(c.received), color: AppColors.income),
        StatTile(label: 'Pending interest', value: m(c.pending), color: AppColors.warning),
      ]),
      if (l.active) ...[
        const SizedBox(height: 8),
        PrimaryButton(label: 'Record interest payment', onPressed: c.unsettled.isEmpty ? null : _pay),
        if (c.unsettled.isEmpty) const Padding(padding: EdgeInsets.only(top: 6), child: Text('All interest is settled for now.', textAlign: TextAlign.center)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _closeLoan, child: const Text('Close loan')),
      ],
      const SectionHeader('Interest history'),
      for (final p in c.periods)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${Fmt.shortDate(p.start)} → ${Fmt.shortDate(p.end)} · due ${Fmt.shortDate(p.due)}', style: const TextStyle(fontSize: 12)),
              Text('Paid ${m(p.paid)} of ${m(p.expected)}${p.remaining > Decimal.zero ? ' · ${m(p.remaining)} left' : ''}', style: const TextStyle(fontSize: 12)),
            ])),
            interestChip(InterestCalculator.statusOf(p, today)),
          ]),
        ),
      const SectionHeader('Payments received'),
      if (c.payments.isEmpty) const AppCard(child: Text('No payments recorded yet.')),
      for (final p in c.payments)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            const Icon(Icons.south_west, color: AppColors.income, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('${Fmt.date(p.date)}${p.notes != null && p.notes!.isNotEmpty ? ' · ${p.notes}' : ''}')),
            Text('+${m(p.amount)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.income)),
          ]),
        ),
    ]);
  }
}

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});
  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late final String id = Get.parameters['id']!;
  late final LoanDetailController c = Get.find<LoanDetailController>(tag: id);
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  final cur = Get.find<AuthController>().currency;
  // One key per opened form: a double tap or retry can never record the payment twice.
  final String _key = const Uuid().v4();
  InterestPeriod? _period;
  DateTime _date = Fmt.today();

  @override
  void initState() {
    super.initState();
    _pick(c.unsettled.isEmpty ? null : c.unsettled.first);
  }

  void _pick(InterestPeriod? p) {
    _period = p;
    _amount.text = p?.remaining.toString() ?? '';
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = c.unsettled;
    return FormScaffold(
      title: 'Record payment',
      child: list.isEmpty
          ? const EmptyState(icon: Icons.check_circle_outline, title: 'Nothing due', subtitle: 'All generated interest is paid.')
          : Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DropdownButtonFormField<String>(
                    value: _period?.id,
                    decoration: InputDecoration(labelText: 'Interest month', filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                    items: [for (final p in list) DropdownMenuItem(value: p.id, child: Text('${p.label} · ${MoneyUtils.format(p.remaining, currency: cur)} due'))],
                    onChanged: (v) => setState(() => _pick(list.firstWhere((p) => p.id == v))),
                  ),
                ),
                AmountField(controller: _amount, label: 'Amount received', currency: cur),
                const Text('Partial payments are fine – the rest stays pending. You cannot pay more than what is due.', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                DateField(label: 'Payment date', value: _date, last: Fmt.today(), onChanged: (d) => setState(() => _date = d)),
                AppTextField(controller: _notes, label: 'Notes (optional)'),
                Obx(() => PrimaryButton(
                      label: 'Save payment',
                      loading: c.saving.value,
                      onPressed: () async {
                        if (!_form.currentState!.validate() || _period == null) return;
                        final ok = await c.recordPayment(_period!, MoneyUtils.tryParse(_amount.text)!, _date, _notes.text, _key);
                        if (ok) Get.back();
                      },
                    )),
              ]),
            ),
    );
  }
}
