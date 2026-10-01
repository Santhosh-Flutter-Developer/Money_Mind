import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/entities.dart';

// ---------------------------------------------------------------- responsive
class Responsive {
  static bool isMobile(BuildContext c) => MediaQuery.of(c).size.width < AppConstants.mobileBreakpoint;
  static bool isDesktop(BuildContext c) => MediaQuery.of(c).size.width >= AppConstants.desktopBreakpoint;
  static double hPad(BuildContext c) => isMobile(c) ? 16 : 28;
}

/// Centers content and caps its width on large screens.
class PageBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const PageBody({super.key, required this.child, this.maxWidth = AppConstants.maxContentWidth});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: EdgeInsets.symmetric(horizontal: Responsive.hPad(context)), child: child),
        ),
      );
}

// ------------------------------------------------------------------- shell
class _Nav {
  final String label;
  final IconData icon;
  final IconData selected;
  final String route;
  const _Nav(this.label, this.icon, this.selected, this.route);
}

const _allNav = [
  _Nav('Home', Icons.home_outlined, Icons.home_rounded, AppRoutes.home),
  _Nav('Budget', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, AppRoutes.budget),
  _Nav('Lending', Icons.handshake_outlined, Icons.handshake, AppRoutes.lending),
  _Nav('Savings', Icons.savings_outlined, Icons.savings, AppRoutes.savings),
  _Nav('Reports', Icons.bar_chart_outlined, Icons.bar_chart, AppRoutes.reports),
  _Nav('Transactions', Icons.receipt_long_outlined, Icons.receipt_long, AppRoutes.transactions),
  _Nav('Calendar', Icons.calendar_month_outlined, Icons.calendar_month, AppRoutes.calendar),
  _Nav('More', Icons.menu, Icons.menu_open, AppRoutes.settings),
];
const _mobileRoutes = [AppRoutes.home, AppRoutes.budget, AppRoutes.lending, AppRoutes.reports, AppRoutes.settings];

/// Bottom navigation on phones; navigation rail / sidebar on tablets and desktop.
class AdaptiveShell extends StatelessWidget {
  final String route;
  final Widget child;
  const AdaptiveShell({super.key, required this.route, required this.child});

  void _go(String r) {
    if (r != route) Get.offNamed(r);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    if (w < AppConstants.mobileBreakpoint) {
      final mobile = _allNav.where((n) => _mobileRoutes.contains(n.route)).toList();
      final idx = mobile.indexWhere((n) => n.route == route);
      if (idx < 0) return child; // secondary screen (savings, transactions, calendar): plain page
      return Material(
        color: bg,
        child: Column(children: [
          Expanded(child: child),
          NavigationBar(
            selectedIndex: idx,
            onDestinationSelected: (i) => _go(mobile[i].route),
            destinations: [
              for (final n in mobile)
                NavigationDestination(icon: Icon(n.icon), selectedIcon: Icon(n.selected), label: n.label),
            ],
          ),
        ]),
      );
    }
    final idx = _allNav.indexWhere((n) => n.route == route).clamp(0, _allNav.length - 1).toInt();
    return Material(
      color: bg,
      child: Row(children: [
        NavigationRail(
          extended: w >= AppConstants.desktopBreakpoint,
          selectedIndex: idx,
          onDestinationSelected: (i) => _go(_allNav[i].route),
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.savings_rounded, color: AppColors.primary, size: 30),
              if (w >= AppConstants.desktopBreakpoint) ...[
                const SizedBox(width: 8),
                const Text(AppConstants.appName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ]),
          ),
          destinations: [
            for (final n in _allNav)
              NavigationRailDestination(icon: Icon(n.icon), selectedIcon: Icon(n.selected), label: Text(n.label)),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: child),
      ]),
    );
  }
}

// ------------------------------------------------------------------- cards
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final IconData? icon;
  final String? caption;
  const StatTile({super.key, required this.label, required this.value, this.color, this.icon, this.caption});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icon != null) ...[Icon(icon, size: 18, color: color ?? muted), const SizedBox(width: 6)],
          Expanded(child: Text(label, style: TextStyle(color: muted, fontSize: 13), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        ),
        if (caption != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(caption!, style: TextStyle(color: muted, fontSize: 12))),
      ]),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              SizedBox(width: 220, child: ElevatedButton(onPressed: onAction, child: Text(actionLabel!))),
            ],
          ]),
        ),
      );
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) =>
      EmptyState(icon: Icons.cloud_off_outlined, title: message, actionLabel: 'Try again', onAction: onRetry);
}

class SkeletonList extends StatefulWidget {
  final int count;
  const SkeletonList({super.key, this.count = 5});
  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(_c),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: widget.count,
        itemBuilder: (_, i) => Container(
          height: i == 0 ? 130 : 68,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

/// Shows skeleton -> error -> content for a page body.
class LoadState extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool hasData;
  final VoidCallback onRetry;
  final Widget child;
  const LoadState({super.key, required this.loading, required this.error, required this.hasData, required this.onRetry, required this.child});
  @override
  Widget build(BuildContext context) {
    if (loading && !hasData) return const SkeletonList();
    if (error != null && !hasData) return ErrorState(message: error!, onRetry: onRetry);
    return RefreshIndicator(onRefresh: () async => onRetry(), child: child);
  }
}

// ----------------------------------------------------------------- inputs
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboard;
  final bool obscure;
  final int maxLines;
  final Widget? suffix;
  final IconData? prefixIcon;
  final List<TextInputFormatter>? formatters;
  final void Function(String)? onChanged;
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboard,
    this.obscure = false,
    this.maxLines = 1,
    this.suffix,
    this.prefixIcon,
    this.formatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboard,
          obscureText: obscure,
          maxLines: obscure ? 1 : maxLines,
          inputFormatters: formatters,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            suffixIcon: suffix,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
      );
}

class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String currency;
  final bool allowZero;
  const AmountField({super.key, required this.controller, this.label = 'Amount', this.currency = 'INR', this.allowZero = false});
  @override
  Widget build(BuildContext context) => AppTextField(
        controller: controller,
        label: label,
        keyboard: const TextInputType.numberWithOptions(decimal: true),
        formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        validator: (v) {
          final d = MoneyUtils.tryParse(v);
          if (d == null) return 'Enter a valid amount';
          if (allowZero ? d < Decimal.zero : d <= Decimal.zero) return 'Amount must be greater than 0';
          return null;
        },
        suffix: Padding(padding: const EdgeInsets.all(14), child: Text(MoneyUtils.symbol(currency), style: const TextStyle(fontSize: 16))),
      );
}

class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? first;
  final DateTime? last;
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.first, this.last});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final now = DateTime.now();
            final lo = first ?? DateTime(2000);
            final hi = last ?? DateTime(now.year + 5);
            var init = value ?? now;
            if (init.isBefore(lo)) init = lo;
            if (init.isAfter(hi)) init = hi;
            final picked = await showDatePicker(context: context, initialDate: init, firstDate: lo, lastDate: hi);
            if (picked != null) onChanged(DateTime(picked.year, picked.month, picked.day));
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
            child: Text(value == null ? 'Select date' : Fmt.date(value!)),
          ),
        ),
      );
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false, this.color});
  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: color == null ? null : ElevatedButton.styleFrom(backgroundColor: color),
        child: loading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(label),
      );
}

/// Scaffold for forms and detail pages: back arrow, centered width-limited body.
class FormScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;
  const FormScaffold({super.key, required this.title, required this.child, this.actions, this.maxWidth = 640});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: PageBody(maxWidth: maxWidth, child: child),
          ),
        ),
      );
}

class MonthSwitcher extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  const MonthSwitcher({super.key, required this.title, required this.subtitle, required this.onPrev, this.onNext});
  @override
  Widget build(BuildContext context) => Row(children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Column(children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ]);
}

Future<bool> confirmDialog(String title, String message, {String confirm = 'Confirm', bool danger = false}) async {
  final r = await Get.dialog<bool>(AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
      TextButton(
        onPressed: () => Get.back(result: true),
        child: Text(confirm, style: TextStyle(color: danger ? AppColors.expense : null, fontWeight: FontWeight.w700)),
      ),
    ],
  ));
  return r ?? false;
}

// ------------------------------------------------------------------ chips
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip(this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

StatusChip interestChip(InterestStatus s) {
  switch (s) {
    case InterestStatus.paid:
      return const StatusChip('Paid', AppColors.income);
    case InterestStatus.partial:
      return const StatusChip('Partial', AppColors.warning);
    case InterestStatus.overdue:
      return const StatusChip('Overdue', AppColors.expense);
    case InterestStatus.pending:
      return const StatusChip('Pending', AppColors.lending);
  }
}

// ------------------------------------------------------------------ tiles
Color txnColor(TxnType t) => switch (t) {
      TxnType.income => AppColors.income,
      TxnType.expense => AppColors.expense,
      TxnType.lending => AppColors.lending,
      TxnType.interest => AppColors.interest,
      TxnType.savings => AppColors.savings,
      TxnType.transfer => AppColors.transfer,
    };

IconData txnIcon(TxnType t) => switch (t) {
      TxnType.income => Icons.south_west,
      TxnType.expense => Icons.north_east,
      TxnType.lending => Icons.handshake_outlined,
      TxnType.interest => Icons.percent,
      TxnType.savings => Icons.savings_outlined,
      TxnType.transfer => Icons.swap_horiz,
    };

class TxnTile extends StatelessWidget {
  final MoneyTxn txn;
  final String currency;
  const TxnTile({super.key, required this.txn, required this.currency});
  @override
  Widget build(BuildContext context) {
    final c = txnColor(txn.type);
    final sign = txn.direction == TxnDirection.inflow ? '+' : txn.direction == TxnDirection.outflow ? '-' : '';
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        CircleAvatar(backgroundColor: c.withOpacity(0.14), child: Icon(txnIcon(txn.type), color: c, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(txn.description.isEmpty ? txn.type.name : txn.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${Fmt.date(txn.date)} · ${txn.categoryName ?? txn.type.name}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
        Text('$sign${MoneyUtils.format(txn.amount, currency: currency)}', style: TextStyle(fontWeight: FontWeight.w800, color: txn.direction == TxnDirection.neutral ? null : c)),
      ]),
    );
  }
}

class BudgetItemTile extends StatelessWidget {
  final BudgetItem item;
  final String currency;
  final bool locked; // cycle closed
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const BudgetItemTile({
    super.key,
    required this.item,
    required this.currency,
    required this.locked,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final overdue = item.isPending && item.dueDate != null && item.dueDate!.isBefore(Fmt.today());
    final tile = AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onTap: locked ? null : onEdit,
      child: Row(children: [
        busy
            ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : Checkbox(
                value: item.isCompleted,
                shape: const CircleBorder(),
                activeColor: AppColors.income,
                onChanged: locked ? null : (_) => onToggle(),
              ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: TextStyle(fontWeight: FontWeight.w600, decoration: item.isCompleted ? TextDecoration.lineThrough : null)),
            Text(
              [
                if (item.categoryName != null) item.categoryName!,
                if (item.dueDate != null) 'Due ${Fmt.shortDate(item.dueDate!)}',
                if (item.isRecurring) 'Recurring',
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: overdue ? AppColors.expense : muted),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(MoneyUtils.format(item.amount, currency: currency), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          item.isCompleted ? const StatusChip('Completed', AppColors.income) : overdue ? const StatusChip('Overdue', AppColors.expense) : const StatusChip('Pending', AppColors.warning),
        ]),
        const SizedBox(width: 8),
      ]),
    );
    if (locked) return tile;
    return Dismissible(
      key: ValueKey('item-${item.id}'),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: AppColors.income, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(item.isCompleted ? Icons.undo : Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: AppColors.expense, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          onToggle();
        } else {
          onDelete();
        }
        return false; // list is updated by the controller, not by the swipe itself
      },
      child: tile,
    );
  }
}

/// Wraps tiles into as many equal columns as fit.
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTile;
  const StatGrid({super.key, required this.children, this.minTile = 170});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        const gap = 12.0;
        final cols = (c.maxWidth / minTile).floor().clamp(1, 6).toInt();
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}
