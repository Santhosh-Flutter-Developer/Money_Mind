import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/common.dart';

// ------------------------------------------------------------ shared pieces
class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final bool isEmail;
  final bool capitalizeWords;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final Iterable<String>? autofill;
  final TextInputAction? action;
  final void Function(String)? onSubmitted;
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.isEmail = false,
    this.capitalizeWords = false,
    this.suffix,
    this.validator,
    this.autofill,
    this.action,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder b(Color c, [double w = 0]) => OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscure,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        textInputAction: action,
        onFieldSubmitted: onSubmitted,
        // Phone keyboards must not "fix" emails or passwords.
        autocorrect: !(obscure || isEmail),
        enableSuggestions: !(obscure || isEmail),
        textCapitalization: capitalizeWords ? TextCapitalization.words : TextCapitalization.none,
        autofillHints: autofill,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withOpacity(0.55),
          prefixIcon: Icon(icon, color: AppColors.primary),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          border: b(Colors.transparent),
          enabledBorder: b(Colors.transparent),
          focusedBorder: b(AppColors.primary, 1.8),
          errorBorder: b(AppColors.expense, 1.4),
          focusedErrorBorder: b(AppColors.expense, 1.8),
        ),
      ),
    );
  }
}

/// Decorative "app preview": stacked cards with a mini bar chart.
class _HeroArt extends StatelessWidget {
  const _HeroArt();
  @override
  Widget build(BuildContext context) {
    const heights = [26.0, 44.0, 34.0, 58.0, 40.0, 66.0, 50.0];
    const barColors = [AppColors.lending, AppColors.interest, AppColors.pink, AppColors.warning, AppColors.income, AppColors.savings, AppColors.primary];
    return FittedBox(
      child: SizedBox(
        width: 330,
        height: 230,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: 0, top: 36, child: Transform.rotate(angle: -0.12, child: Container(
            width: 200,
            height: 124,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: AppGradients.grape, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: const Color(0xFF8E2DE2).withOpacity(0.35), blurRadius: 22, offset: const Offset(0, 12))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Row(children: [Icon(Icons.savings_rounded, color: Colors.white70, size: 16), SizedBox(width: 6), Text('Savings', style: TextStyle(color: Colors.white70, fontSize: 12))]),
              SizedBox(height: 6),
              Text('₹1,25,000', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
          ))),
          Positioned(right: 0, top: 54, child: Transform.rotate(angle: 0.07, child: Container(
            width: 200,
            height: 160,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 26, offset: const Offset(0, 14))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Remaining', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                const StatusChip('+12%', AppColors.income),
              ]),
              const Text('₹48,500', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const Spacer(),
              Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (var i = 0; i < heights.length; i++)
                  Container(width: 15, height: heights[i], decoration: BoxDecoration(gradient: AppGradients.of(barColors[i]), borderRadius: BorderRadius.circular(6))),
              ]),
            ]),
          ))),
          Positioned(left: 26, bottom: 6, child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(gradient: AppGradients.gold, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.warning.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 8))]),
            child: const Icon(Icons.currency_rupee_rounded, color: Colors.white, size: 32),
          )),
          Positioned(right: 18, top: 0, child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(gradient: AppGradients.mint, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.income.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 6))]),
            child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 22),
          )),
        ]),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final bool light;
  const _BrandMark({this.light = false});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(gradient: light ? null : AppGradients.brand, color: light ? Colors.white : null, borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.savings_rounded, color: light ? AppColors.primary : Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        Text(AppConstants.appName, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: light ? Colors.white : null)),
      ]);
}

/// Clean layout: art + plain form on phones; brand panel beside the form on wide screens.
class _AuthShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool back;
  final bool hero;
  const _AuthShell({required this.title, required this.subtitle, required this.children, this.back = false, this.hero = false});

  Widget _form(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(fontSize: 14.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 26),
        ...children,
      ]);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(gradient: AppGradients.brand),
              padding: const EdgeInsets.all(48),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                const _BrandMark(light: true),
                const SizedBox(height: 36),
                const Text('Take control of\nevery rupee.', style: TextStyle(fontSize: 42, height: 1.15, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 14),
                const Text(AppConstants.tagline, style: TextStyle(fontSize: 16, color: Colors.white70)),
                const SizedBox(height: 36),
                const Center(child: SizedBox(width: 420, child: _HeroArt())),
                const SizedBox(height: 30),
                for (final f in const [
                  (Icons.calendar_month_rounded, 'Salary-cycle budgeting'),
                  (Icons.savings_rounded, 'Savings wallet & goals'),
                  (Icons.handshake_rounded, 'Lending with monthly interest'),
                ])
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Icon(f.$1, color: Colors.white, size: 20), const SizedBox(width: 10), Text(f.$2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))])),
              ]),
            ),
          ),
          Expanded(
            flex: 4,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(padding: const EdgeInsets.all(36), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _form(context))),
              ),
            ),
          ),
        ]),
      );
    }
    return Scaffold(
      appBar: back ? AppBar(backgroundColor: Colors.transparent) : null,
      body: Stack(children: [
        Positioned(right: -80, top: -80, child: Container(width: 260, height: 260, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.10)))),
        Positioned(left: -90, top: 150, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.pink.withOpacity(0.08)))),
        Container(color: bg.withOpacity(0)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (hero) ...[const SizedBox(height: 4), const SizedBox(height: 210, child: _HeroArt()), const SizedBox(height: 10)] else ...[const SizedBox(height: 4), const Center(child: _BrandMark()), const SizedBox(height: 22)],
                  Appear(child: _form(context)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ splash
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    setState(() => _error = null);
    final err = await Get.find<AuthController>().bootstrap();
    if (mounted && err != null) setState(() => _error = err);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.brand),
          child: Center(
            child: _error != null
                ? Container(margin: const EdgeInsets.all(24), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(28)), child: ErrorState(message: _error!, onRetry: _start))
                : Column(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.savings_rounded, size: 84, color: Colors.white),
                    SizedBox(height: 14),
                    Text(AppConstants.appName, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white)),
                    SizedBox(height: 6),
                    Text(AppConstants.tagline, style: TextStyle(color: Colors.white70)),
                    SizedBox(height: 30),
                    CircularProgressIndicator(color: Colors.white),
                  ]),
          ),
        ),
      );
}

// ------------------------------------------------------------------- login
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  final _auth = Get.find<AuthController>();

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_form.currentState!.validate()) _auth.signIn(_email.text, _pass.text);
  }

  @override
  Widget build(BuildContext context) => _AuthShell(
        hero: true,
        title: 'Welcome back 👋',
        subtitle: 'Log in to keep planning your money.',
        children: [
          Form(
            key: _form,
            child: AutofillGroup(
              child: Column(children: [
                _AuthField(controller: _email, label: 'Email', icon: Icons.alternate_email_rounded, isEmail: true, validator: Validators.email, autofill: const [AutofillHints.email], action: TextInputAction.next),
                _AuthField(
                  controller: _pass,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _hide,
                  validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                  autofill: const [AutofillHints.password],
                  action: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _hide = !_hide)),
                ),
              ]),
            ),
          ),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Get.toNamed(AppRoutes.forgotPassword), child: const Text('Forgot password?'))),
          const SizedBox(height: 4),
          Obx(() => PrimaryButton(label: 'Log in', icon: Icons.arrow_forward_rounded, loading: _auth.busy.value, onPressed: _submit)),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Divider()),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('New here?', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            const Expanded(child: Divider()),
          ]),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: () => Get.toNamed(AppRoutes.register), child: const Text('Create an account')),
        ],
      );
}

// ---------------------------------------------------------------- register
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  String _currency = AppConstants.defaultCurrency;
  bool _hide = true;
  final _auth = Get.find<AuthController>();

  @override
  void dispose() {
    for (final c in [_name, _email, _pass, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthShell(
        back: true,
        title: 'Create account',
        subtitle: 'Plan your salary, savings and lending in one place.',
        children: [
          Form(
            key: _form,
            child: Column(children: [
              _AuthField(controller: _name, label: 'Full name', icon: Icons.person_outline_rounded, capitalizeWords: true, validator: (v) => Validators.required(v, 'Name'), action: TextInputAction.next),
              _AuthField(controller: _email, label: 'Email', icon: Icons.alternate_email_rounded, isEmail: true, validator: Validators.email, action: TextInputAction.next),
              _AuthField(
                controller: _pass,
                label: 'Password (min 6 characters)',
                icon: Icons.lock_outline_rounded,
                obscure: _hide,
                validator: Validators.password,
                action: TextInputAction.next,
                suffix: IconButton(icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _hide = !_hide)),
              ),
              _AuthField(controller: _confirm, label: 'Confirm password', icon: Icons.lock_reset_rounded, obscure: _hide, validator: (v) => v != _pass.text ? 'Passwords do not match' : null, action: TextInputAction.done),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: InputDecoration(
                    labelText: 'Currency',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.55),
                    prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                  items: [for (final c in AppConstants.supportedCurrencies) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (v) => setState(() => _currency = v ?? _currency),
                ),
              ),
            ]),
          ),
          Obx(() => PrimaryButton(
                label: 'Create account',
                loading: _auth.busy.value,
                onPressed: () {
                  if (_form.currentState!.validate()) _auth.register(_name.text, _email.text, _pass.text, _currency);
                },
              )),
          const SizedBox(height: 12),
          Text('By continuing you agree to the Terms and Privacy Policy.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}

// ---------------------------------------------------------- forgot / reset
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _auth = Get.find<AuthController>();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthShell(
        back: true,
        title: 'Reset password',
        subtitle: "Enter your email and we'll send you a reset link.",
        children: [
          Form(key: _form, child: _AuthField(controller: _email, label: 'Email', icon: Icons.alternate_email_rounded, isEmail: true, validator: Validators.email)),
          Obx(() => PrimaryButton(
                label: _sent ? 'Send again' : 'Send reset link',
                loading: _auth.busy.value,
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  final ok = await _auth.sendReset(_email.text);
                  if (ok && mounted) setState(() => _sent = true);
                },
              )),
        ],
      );
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _auth = Get.find<AuthController>();

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthShell(
        title: 'New password',
        subtitle: 'Use at least 6 characters.',
        children: [
          Form(
            key: _form,
            child: Column(children: [
              _AuthField(controller: _pass, label: 'New password', icon: Icons.lock_outline_rounded, obscure: true, validator: Validators.password, action: TextInputAction.next),
              _AuthField(controller: _confirm, label: 'Confirm password', icon: Icons.lock_reset_rounded, obscure: true, validator: (v) => v != _pass.text ? 'Passwords do not match' : null),
            ]),
          ),
          Obx(() => PrimaryButton(
                label: 'Update password',
                loading: _auth.busy.value,
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  if (await _auth.updatePassword(_pass.text)) Get.offAllNamed(AppRoutes.splash);
                },
              )),
        ],
      );
}