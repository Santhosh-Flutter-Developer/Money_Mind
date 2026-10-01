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

// ------------------------------------------------------- category look & feel
const _catPalette = [
  Color(0xFF6A5AE0),
  Color(0xFF3B82F6),
  Color(0xFFF59E0B),
  Color(0xFF12B886),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFA855F7),
  Color(0xFFFF5470),
];

Color categoryColor(String? name) {
  final s = (name ?? 'other').toLowerCase();
  var h = 7;
  for (final u in s.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return _catPalette[h % _catPalette.length];
}

IconData categoryIcon(String? name) {
  final s = (name ?? '').toLowerCase();
  bool has(List<String> k) => k.any(s.contains);
  if (has(['food', 'restaurant', 'dining'])) return Icons.restaurant;
  if (has(['grocer'])) return Icons.shopping_basket;
  if (has(['gas', 'fuel', 'petrol'])) return Icons.local_gas_station;
  if (has(['electric', 'power'])) return Icons.bolt;
  if (has(['water'])) return Icons.water_drop;
  if (has(['medic', 'pharma'])) return Icons.medication;
  if (has(['health'])) return Icons.favorite;
  if (has(['rent', 'home', 'house'])) return Icons.home;
  if (has(['bike'])) return Icons.two_wheeler;
  if (has(['car'])) return Icons.directions_car;
  if (has(['emi', 'loan', 'credit'])) return Icons.credit_card;
  if (has(['rd', 'invest', 'sip', 'mutual'])) return Icons.trending_up;
  if (has(['shop'])) return Icons.shopping_bag;
  if (has(['entertain', 'movie'])) return Icons.movie;
  if (has(['travel', 'trip'])) return Icons.flight;
  if (has(['bill', 'recharge'])) return Icons.receipt_long;
  if (has(['educ', 'school', 'fee'])) return Icons.school;
  if (has(['family'])) return Icons.family_restroom;
  return Icons.category;
}

class CategoryAvatar extends StatelessWidget {
  final String? name;
  final double size;
  const CategoryAvatar({super.key, this.name, this.size = 42});
  @override
  Widget build(BuildContext context) {
    final c = categoryColor(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(size * 0.34)),
      child: Icon(categoryIcon(name), color: c, size: size * 0.52),
    );
  }
}

// ------------------------------------------------------------------- shell
class _Nav {
  final String label;
  final IconData icon;
  final IconData selected;
  final String route;
  final Color color;
  const _Nav(this.label, this.icon, this.selected, this.route, this.color);
}

const _allNav = [
  _Nav('Home', Icons.home_outlined, Icons.home_rounded, AppRoutes.home, Color(0xFF6A5AE0)),
  _Nav('Budget', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, AppRoutes.budget, Color(0xFF3B82F6)),
  _Nav('Lending', Icons.handshake_outlined, Icons.handshake, AppRoutes.lending, Color(0xFFF59E0B)),
  _Nav('Savings', Icons.savings_outlined, Icons.savings, AppRoutes.savings, Color(0xFF14B8A6)),
  _Nav('Reports', Icons.bar_chart_outlined, Icons.bar_chart, AppRoutes.reports, Color(0xFF12B886)),
  _Nav('Transactions', Icons.receipt_long_outlined, Icons.receipt_long, AppRoutes.transactions, Color(0xFFA855F7)),
  _Nav('Calendar', Icons.calendar_month_outlined, Icons.calendar_month, AppRoutes.calendar, Color(0xFFEC4899)),
  _Nav('More', Icons.grid_view_rounded, Icons.grid_view_rounded, AppRoutes.settings, Color(0xFFFF5470)),
];
const _mobileRoutes = [AppRoutes.home, AppRoutes.budget, AppRoutes.lending, AppRoutes.reports, AppRoutes.settings];

class _BottomBar extends StatelessWidget {
  final List<_Nav> items;
  final int index;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.items, required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(light ? 0.10 : 0.4), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onTap(i),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: EdgeInsets.symmetric(horizontal: i == index ? 18 : 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: i == index ? AppGradients.of(items[i].color) : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: i == index ? [BoxShadow(color: items[i].color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))] : null,
                    ),
                    child: Icon(i == index ? items[i].selected : items[i].icon, size: 22, color: i == index ? Colors.white : scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 3),
                  Text(items[i].label, style: TextStyle(fontSize: 11, fontWeight: i == index ? FontWeight.w700 : FontWeight.w500, color: i == index ? items[i].color : scheme.onSurfaceVariant)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Floating colourful bottom bar on phones; navigation rail / sidebar on tablets and desktop.
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
      if (idx < 0) return child; // secondary screen: plain page with back arrow
      return Material(color: bg, child: Column(children: [Expanded(child: child), _BottomBar(items: mobile, index: idx, onTap: (i) => _go(mobile[i].route))]));
    }
    final idx = _allNav.indexWhere((n) => n.route == route).clamp(0, _allNav.length - 1).toInt();
    final extended = w >= AppConstants.desktopBreakpoint;
    return Material(
      color: bg,
      child: Row(children: [
        NavigationRail(
          extended: extended,
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedIndex: idx,
          indicatorColor: _allNav[idx].color.withOpacity(0.16),
          selectedIconTheme: IconThemeData(color: _allNav[idx].color),
          selectedLabelTextStyle: TextStyle(color: _allNav[idx].color, fontWeight: FontWeight.w700),
          onDestinationSelected: (i) => _go(_allNav[i].route),
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(gradient: AppGradients.brand, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.savings_rounded, color: Colors.white, size: 24),
              ),
              if (extended) ...[const SizedBox(width: 10), const Text(AppConstants.appName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))],
            ]),
          ),
          destinations: [
            for (final n in _allNav) NavigationRailDestination(icon: Icon(n.icon), selectedIcon: Icon(n.selected), label: Text(n.label)),
          ],
        ),
        Expanded(child: child),
      ]),
    );
  }
}

// ----------------------------------------------------------------- effects
/// Fades and slides its child in, optionally after a delay (for staggered lists).
class Appear extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const Appear({super.key, required this.child, this.delayMs = 0});
  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(curve), child: widget.child),
    );
  }
}

/// Counts up/down to the new amount whenever it changes.
class AnimatedAmount extends StatelessWidget {
  final Decimal value;
  final String currency;
  final TextStyle? style;
  const AnimatedAmount({super.key, required this.value, required this.currency, this.style});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(end: value.toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text(MoneyUtils.format(Decimal.parse(v.toStringAsFixed(2)), currency: currency), style: style),
      );
}

class GradientProgress extends StatelessWidget {
  final double value;
  final Gradient gradient;
  final double height;
  final Color? track;
  const GradientProgress({super.key, required this.value, this.gradient = AppGradients.brand, this.height = 10, this.track});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(end: value.clamp(0.0, 1.0).toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Container(
          height: height,
          decoration: BoxDecoration(color: track ?? Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(height)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(widthFactor: v, child: DecoratedBox(decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(height)))),
          ),
        ),
      );
}

// ------------------------------------------------------------------- cards
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.gradient});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? scheme.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        border: light ? null : Border.all(color: scheme.outlineVariant.withOpacity(0.35)),
        boxShadow: light ? [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))] : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(borderRadius: BorderRadius.circular(22), onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Hero card with gradient background and soft decorative circles.
class GradientCard extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final EdgeInsets padding;
  const GradientCard({super.key, required this.child, this.gradient = AppGradients.brand, this.padding = const EdgeInsets.all(20)});
  @override
  Widget build(BuildContext context) {
    final c = (gradient as LinearGradient).colors.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: c.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(children: [
          Positioned(right: -36, top: -36, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.13)))),
          Positioned(left: -30, bottom: -50, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.09)))),
          Padding(padding: padding, child: child),
        ]),
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
    final c = color ?? AppColors.primary;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(gradient: AppGradients.of(c), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: c.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
            child: Icon(icon ?? Icons.insights, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 12),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: color))),
        if (caption != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(caption!, style: TextStyle(color: muted, fontSize: 11.5))),
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
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        child: Row(children: [
          Container(width: 5, height: 20, decoration: BoxDecoration(gradient: AppGradients.brand, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 10),
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
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.18), AppColors.lending.withOpacity(0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Icon(icon, size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            if (subtitle != null)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            if (actionLabel != null) ...[const SizedBox(height: 18), SizedBox(width: 230, child: PrimaryButton(label: actionLabel!, onPressed: onAction))],
          ]),
        ),
      );
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => EmptyState(icon: Icons.cloud_off_outlined, title: message, actionLabel: 'Try again', onAction: onRetry);
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
    final base = AppColors.primary.withOpacity(0.10);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_c),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: widget.count,
        itemBuilder: (_, i) => Container(height: i == 0 ? 150 : 72, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(22))),
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
    return RefreshIndicator(color: AppColors.primary, onRefresh: () async => onRetry(), child: child);
  }
}

// ----------------------------------------------------------------- inputs
InputDecoration appInputDecoration(BuildContext context, String label, {String? hint, Widget? suffix, IconData? prefixIcon}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffix,
    prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, color: AppColors.primary),
    filled: true,
    fillColor: scheme.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border(scheme.outlineVariant.withOpacity(0.6)),
    enabledBorder: border(scheme.outlineVariant.withOpacity(0.6)),
    focusedBorder: border(AppColors.primary, 1.8),
    errorBorder: border(AppColors.expense),
    focusedErrorBorder: border(AppColors.expense, 1.8),
  );
}

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
          decoration: appInputDecoration(context, label, hint: hint, suffix: suffix, prefixIcon: prefixIcon),
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
          if (allowZero ? d < Decimal.zero : d <= Decimal.zero) return allowZero ? 'Amount cannot be negative' : 'Amount must be greater than 0';
          return null;
        },
        suffix: Padding(padding: const EdgeInsets.all(14), child: Text(MoneyUtils.symbol(currency), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary))),
      );
}

/// Tap-to-pick date field (calendar picker).
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
          borderRadius: BorderRadius.circular(16),
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
            decoration: appInputDecoration(context, label, suffix: const Icon(Icons.calendar_month_rounded, color: AppColors.primary)),
            child: Text(value == null ? 'Select date' : Fmt.date(value!)),
          ),
        ),
      );
}

/// Tap-to-pick time field (clock picker). Value is minutes after midnight.
class TimeField extends StatelessWidget {
  final String label;
  final int? minutes;
  final ValueChanged<int?> onChanged;
  final bool optional;
  const TimeField({super.key, required this.label, required this.minutes, required this.onChanged, this.optional = false});
  @override
  Widget build(BuildContext context) {
    final t = minutes == null ? null : TimeOfDay(hour: minutes! ~/ 60, minute: minutes! % 60);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final picked = await showTimePicker(context: context, initialTime: t ?? const TimeOfDay(hour: 9, minute: 0));
          if (picked != null) onChanged(picked.hour * 60 + picked.minute);
        },
        child: InputDecorator(
          decoration: appInputDecoration(
            context,
            label,
            suffix: optional && minutes != null
                ? IconButton(icon: const Icon(Icons.close), onPressed: () => onChanged(null))
                : const Icon(Icons.schedule_rounded, color: AppColors.primary),
          ),
          child: Text(t == null ? (optional ? 'Not set (optional)' : 'Select time') : t.format(context)),
        ),
      ),
    );
  }
}

String ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

/// Day-of-month picker (1..max) shown as a tappable grid instead of typing a number.
class DayField extends StatelessWidget {
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final int max;
  final bool optional;
  const DayField({super.key, required this.label, required this.value, required this.onChanged, this.max = 31, this.optional = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final r = await Get.dialog<int>(_DayDialog(title: label, initial: value, max: max, optional: optional));
            if (r == null) return; // cancelled
            onChanged(r == 0 ? null : r);
          },
          child: InputDecorator(
            decoration: appInputDecoration(context, label, suffix: const Icon(Icons.event_repeat_rounded, color: AppColors.primary)),
            child: Text(value == null ? (optional ? 'Not set (optional)' : 'Select day') : 'The ${ordinal(value!)} of every month'),
          ),
        ),
      );
}

class _DayDialog extends StatelessWidget {
  final String title;
  final int? initial;
  final int max;
  final bool optional;
  const _DayDialog({required this.title, required this.initial, required this.max, required this.optional});
  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title),
        content: SizedBox(
          width: 320,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (var d = 1; d <= max; d++)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Get.back(result: d),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: d == initial ? AppGradients.brand : null,
                      color: d == initial ? null : AppColors.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$d', style: TextStyle(fontWeight: FontWeight.w600, color: d == initial ? Colors.white : null)),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (optional) TextButton(onPressed: () => Get.back(result: 0), child: const Text('Clear')),
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ],
      );
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  final IconData? icon;
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false, this.color, this.icon});
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final base = color ?? AppColors.primary;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: color == null ? AppGradients.brand : AppGradients.of(base),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: base.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                      Text(label, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
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
        body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(vertical: 8), child: PageBody(maxWidth: maxWidth, child: child))),
      );
}

class MonthSwitcher extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  const MonthSwitcher({super.key, required this.title, required this.subtitle, required this.onPrev, this.onNext});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(gradient: AppGradients.brand, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))]),
        child: Row(children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28)),
          Expanded(
            child: Column(children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28)),
        ]),
      );
}

Future<bool> confirmDialog(String title, String message, {String confirm = 'Confirm', bool danger = false}) async {
  final r = await Get.dialog<bool>(AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    icon: Icon(danger ? Icons.warning_amber_rounded : Icons.help_outline_rounded, color: danger ? AppColors.expense : AppColors.primary, size: 36),
    title: Text(title, textAlign: TextAlign.center),
    content: Text(message, textAlign: TextAlign.center),
    actionsAlignment: MainAxisAlignment.center,
    actions: [
      TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: danger ? AppColors.expense : AppColors.primary),
        onPressed: () => Get.back(result: true),
        child: Text(confirm),
      ),
    ],
  ));
  return r ?? false;
}

// -------------------------------------------------------- reusable edit dialog
class EntryResult {
  final Decimal amount;
  final DateTime date;
  final String description;
  final String notes;
  const EntryResult(this.amount, this.date, this.description, this.notes);
}

/// One dialog for editing any money entry: amount + date picker (+ optional description / notes).
Future<EntryResult?> showEntryDialog({
  required String title,
  required String currency,
  Decimal? amount,
  DateTime? date,
  String? description,
  String? notes,
  String amountLabel = 'Amount',
  bool showDate = true,
  bool showDescription = false,
  bool showNotes = false,
  bool allowZeroAmount = false,
  DateTime? first,
  DateTime? last,
  String saveLabel = 'Save',
}) async {
  final amountC = TextEditingController(text: amount?.toString() ?? '');
  final descC = TextEditingController(text: description ?? '');
  final notesC = TextEditingController(text: notes ?? '');
  final key = GlobalKey<FormState>();
  var picked = date ?? Fmt.today();
  final ok = await Get.dialog<bool>(StatefulBuilder(
    builder: (ctx, set) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title),
      content: Form(
        key: key,
        child: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 6),
              AmountField(controller: amountC, label: amountLabel, currency: currency, allowZero: allowZeroAmount),
              if (showDescription) AppTextField(controller: descC, label: 'Description'),
              if (showDate) DateField(label: 'Date', value: picked, first: first, last: last, onChanged: (d) => set(() => picked = d)),
              if (showNotes) AppTextField(controller: notesC, label: 'Notes (optional)', maxLines: 2),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (key.currentState!.validate()) Get.back(result: true);
          },
          child: Text(saveLabel),
        ),
      ],
    ),
  ));
  final result = ok == true ? EntryResult(MoneyUtils.tryParse(amountC.text)!, picked, descC.text.trim(), notesC.text.trim()) : null;
  amountC.dispose();
  descC.dispose();
  notesC.dispose();
  return result;
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
        child: Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
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
      TxnType.income => Icons.south_west_rounded,
      TxnType.expense => Icons.north_east_rounded,
      TxnType.lending => Icons.handshake_outlined,
      TxnType.interest => Icons.percent_rounded,
      TxnType.savings => Icons.savings_outlined,
      TxnType.transfer => Icons.swap_horiz_rounded,
    };

class TxnTile extends StatelessWidget {
  final MoneyTxn txn;
  final String currency;
  final VoidCallback? onTap;
  const TxnTile({super.key, required this.txn, required this.currency, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = txnColor(txn.type);
    final sign = txn.direction == TxnDirection.inflow ? '+' : txn.direction == TxnDirection.outflow ? '-' : '';
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(gradient: AppGradients.of(c), borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: c.withOpacity(0.28), blurRadius: 8, offset: const Offset(0, 3))]),
          child: Icon(txnIcon(txn.type), color: Colors.white, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(txn.description.isEmpty ? txn.type.name : txn.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${Fmt.date(txn.date)} · ${txn.categoryName ?? txn.type.name}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
        Text('$sign${MoneyUtils.format(txn.amount, currency: currency)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: txn.direction == TxnDirection.neutral ? null : c)),
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
    final time = item.dueTimeMinutes == null ? null : TimeOfDay(hour: item.dueTimeMinutes! ~/ 60, minute: item.dueTimeMinutes! % 60).format(context);
    final tile = AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      onTap: locked ? null : onEdit,
      child: Row(children: [
        busy
            ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : Checkbox(value: item.isCompleted, shape: const CircleBorder(), activeColor: AppColors.income, onChanged: locked ? null : (_) => onToggle()),
        CategoryAvatar(name: item.categoryName ?? item.name, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: TextStyle(fontWeight: FontWeight.w600, decoration: item.isCompleted ? TextDecoration.lineThrough : null)),
            Text(
              [
                if (item.categoryName != null) item.categoryName!,
                if (item.dueDate != null) 'Due ${Fmt.shortDate(item.dueDate!)}${time != null ? ' · $time' : ''}',
                if (item.isRecurring) 'Recurring',
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: overdue ? AppColors.expense : muted),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(MoneyUtils.format(item.amount, currency: currency), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
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
        decoration: BoxDecoration(gradient: AppGradients.mint, borderRadius: BorderRadius.circular(22)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 22),
        child: Icon(item.isCompleted ? Icons.undo : Icons.check_circle_outline, color: Colors.white, size: 28),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(gradient: AppGradients.rose, borderRadius: BorderRadius.circular(22)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          onToggle();
        } else {
          onDelete();
        }
        return false; // the controller updates the list, not the swipe itself
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

/// Small bottom sheet with Edit / Delete buttons for a single record.
Future<void> showActionSheet({
  required String title,
  String? subtitle,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  String editLabel = 'Edit',
  String deleteLabel = 'Delete',
}) =>
    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          decoration: BoxDecoration(color: Theme.of(Get.context!).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle)),
            const SizedBox(height: 18),
            PrimaryButton(label: editLabel, icon: Icons.edit_outlined, onPressed: () {
              Get.back();
              onEdit();
            }),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.expense, side: const BorderSide(color: AppColors.expense)),
              icon: const Icon(Icons.delete_outline),
              label: Text(deleteLabel),
              onPressed: () {
                Get.back();
                onDelete();
              },
            ),
          ]),
        ),
      ),
      isScrollControlled: true,
    );
