import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/common.dart';

class _AuthFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool back;
  const _AuthFrame({required this.title, required this.subtitle, required this.children, this.back = false});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: back ? AppBar() : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Icon(Icons.savings_rounded, size: 56, color: AppColors.primary),
                  const SizedBox(height: 8),
                  const Text(AppConstants.appName, textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 28),
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  ...children,
                ]),
              ),
            ),
          ),
        ),
      );
}

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
        body: Center(
          child: _error != null
              ? ErrorState(message: _error!, onRetry: _start)
              : Column(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.savings_rounded, size: 72, color: AppColors.primary),
                  SizedBox(height: 12),
                  Text(AppConstants.appName, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text(AppConstants.tagline),
                  SizedBox(height: 28),
                  CircularProgressIndicator(),
                ]),
        ),
      );
}

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

  @override
  Widget build(BuildContext context) => _AuthFrame(
        title: 'Welcome back',
        subtitle: AppConstants.tagline,
        children: [
          Form(
            key: _form,
            child: Column(children: [
              AppTextField(controller: _email, label: 'Email', keyboard: TextInputType.emailAddress, validator: Validators.email, prefixIcon: Icons.mail_outline),
              AppTextField(
                controller: _pass,
                label: 'Password',
                obscure: _hide,
                validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                prefixIcon: Icons.lock_outline,
                suffix: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)),
              ),
            ]),
          ),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Get.toNamed(AppRoutes.forgotPassword), child: const Text('Forgot password?'))),
          Obx(() => PrimaryButton(
                label: 'Login',
                loading: _auth.busy.value,
                onPressed: () {
                  if (_form.currentState!.validate()) _auth.signIn(_email.text, _pass.text);
                },
              )),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text("Don't have an account?"),
            TextButton(onPressed: () => Get.toNamed(AppRoutes.register), child: const Text('Create account')),
          ]),
        ],
      );
}

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
  final _auth = Get.find<AuthController>();

  @override
  void dispose() {
    for (final c in [_name, _email, _pass, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
        back: true,
        title: 'Create your account',
        subtitle: 'Plan your salary, savings and lending in one place.',
        children: [
          Form(
            key: _form,
            child: Column(children: [
              AppTextField(controller: _name, label: 'Full name', validator: (v) => Validators.required(v, 'Name'), prefixIcon: Icons.person_outline),
              AppTextField(controller: _email, label: 'Email', keyboard: TextInputType.emailAddress, validator: Validators.email, prefixIcon: Icons.mail_outline),
              AppTextField(controller: _pass, label: 'Password', obscure: true, validator: Validators.password, prefixIcon: Icons.lock_outline),
              AppTextField(
                controller: _confirm,
                label: 'Confirm password',
                obscure: true,
                validator: (v) => v != _pass.text ? 'Passwords do not match' : null,
                prefixIcon: Icons.lock_outline,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: InputDecoration(labelText: 'Currency', filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
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
          const SizedBox(height: 8),
          Text('By continuing you agree to the Terms (${AppConstants.termsUrl}) and Privacy Policy (${AppConstants.privacyUrl}).',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}

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
  Widget build(BuildContext context) => _AuthFrame(
        back: true,
        title: 'Reset password',
        subtitle: "Enter your email and we'll send you a reset link.",
        children: [
          Form(key: _form, child: AppTextField(controller: _email, label: 'Email', keyboard: TextInputType.emailAddress, validator: Validators.email, prefixIcon: Icons.mail_outline)),
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
  Widget build(BuildContext context) => _AuthFrame(
        title: 'Choose a new password',
        subtitle: 'Use at least 6 characters.',
        children: [
          Form(
            key: _form,
            child: Column(children: [
              AppTextField(controller: _pass, label: 'New password', obscure: true, validator: Validators.password, prefixIcon: Icons.lock_outline),
              AppTextField(controller: _confirm, label: 'Confirm password', obscure: true, validator: (v) => v != _pass.text ? 'Passwords do not match' : null, prefixIcon: Icons.lock_outline),
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
