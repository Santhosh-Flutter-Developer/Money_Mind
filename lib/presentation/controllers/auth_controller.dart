import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/error/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/prefs_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/snack.dart';
import '../../domain/entities/entities.dart';
import '../../domain/services/cycle_calculator.dart';
import '../../domain/usecases/usecases.dart';
import 'app_events.dart';

class AuthController extends GetxController {
  final AuthUseCases _uc;
  final AppEvents _events;
  AuthController(this._uc, this._events);

  final profile = Rxn<UserProfile>();
  final settings = const AppSettings().obs;
  final busy = false.obs;
  bool _manualLogout = false;
  StreamSubscription<bool>? _session;
  StreamSubscription<bool>? _recovery;

  static const _publicRoutes = {
    AppRoutes.splash,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
    AppRoutes.resetPassword,
  };

  @override
  void onInit() {
    super.onInit();
    _session = _uc.sessionChanges.listen((hasSession) {
      if (!hasSession && profile.value != null && !_manualLogout) {
        // Session ended (expired or signed out elsewhere)
        _clearAndGoLogin();
        Snack.info('You have been signed out.');
      }
    });
    _recovery = _uc.recoveryEvents.listen((_) => Get.toNamed(AppRoutes.resetPassword));
  }

  @override
  void onClose() {
    _session?.cancel();
    _recovery?.cancel();
    super.onClose();
  }

  void _clearAndGoLogin() {
    profile.value = null;
    _events.loggedOut();
    if (!_publicRoutes.contains(Get.currentRoute)) Get.offAllNamed(AppRoutes.login);
  }

  String get currency => profile.value?.currency ?? 'INR';
  CycleMode get cycleMode => (profile.value?.usesSalaryCycle ?? true) ? CycleMode.salaryCycle : CycleMode.calendarMonth;
  int get salaryDay => profile.value?.salaryDay ?? 1;

  BudgetPeriod get currentPeriod =>
      CycleCalculator.periodFor(Fmt.today(), salaryDay: salaryDay, mode: cycleMode);

  /// Decides where the app should start. Returns an error message to show on the splash screen.
  Future<String?> bootstrap() async {
    if (!_uc.hasSession) {
      Get.offAllNamed(AppRoutes.login);
      return null;
    }
    try {
      await loadProfile();
      Get.offAllNamed(profile.value!.onboarded ? AppRoutes.home : AppRoutes.onboarding);
      return null;
    } catch (e) {
      final f = mapError(e);
      if (f.isAuth) {
        Get.offAllNamed(AppRoutes.login);
        return null;
      }
      return f.message;
    }
  }

  Future<void> loadProfile() async {
    profile.value = await _uc.profile();
    settings.value = await _uc.settings();
    final mode = settings.value.themeMode;
    final tm = mode == 'dark' ? ThemeMode.dark : mode == 'light' ? ThemeMode.light : ThemeMode.system;
    Get.changeThemeMode(tm);
    await PrefsService.setThemeMode(tm);
  }

  Future<void> signIn(String email, String password) async {
    if (busy.value) return;
    busy.value = true;
    try {
      await _uc.signIn(email, password);
      await loadProfile();
      Get.offAllNamed(profile.value!.onboarded ? AppRoutes.home : AppRoutes.onboarding);
    } catch (e) {
      Snack.error(mapError(e).message);
    } finally {
      busy.value = false;
    }
  }

  Future<void> register(String name, String email, String password, String currency) async {
    if (busy.value) return;
    busy.value = true;
    try {
      final hasSession = await _uc.signUp(name, email, password);
      if (!hasSession) {
        Snack.success('Account created. Check your email to confirm, then log in.');
        Get.offAllNamed(AppRoutes.login);
        return;
      }
      await loadProfile();
      await _uc.updateProfile({'currency': currency});
      await loadProfile();
      Get.offAllNamed(AppRoutes.onboarding);
    } catch (e) {
      Snack.error(mapError(e).message);
    } finally {
      busy.value = false;
    }
  }

  Future<bool> sendReset(String email) async {
    busy.value = true;
    try {
      await _uc.sendReset(email);
      Snack.success('If that email is registered, a reset link is on its way.');
      return true;
    } catch (e) {
      Snack.error(mapError(e).message);
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<bool> updatePassword(String password) async {
    busy.value = true;
    try {
      await _uc.updatePassword(password);
      Snack.success('Password updated.');
      return true;
    } catch (e) {
      Snack.error(mapError(e).message);
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<void> logout() async {
    _manualLogout = true;
    try {
      await _uc.signOut();
    } catch (e) {
      _manualLogout = false;
      Snack.error(mapError(e).message);
      return;
    }
    _clearAndGoLogin();
    _manualLogout = false;
  }

  Future<bool> saveProfile(Map<String, dynamic> values) async {
    busy.value = true;
    try {
      await _uc.updateProfile(values);
      await loadProfile();
      return true;
    } catch (e) {
      Snack.error(mapError(e).message);
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<void> saveSettings(Map<String, dynamic> values) async {
    try {
      await _uc.updateSettings(values);
      settings.value = await _uc.settings();
    } catch (e) {
      Snack.error(mapError(e).message);
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    Get.changeThemeMode(mode);
    await PrefsService.setThemeMode(mode);
    await saveSettings({'theme_mode': mode.name});
  }

  Future<void> loadDemoData() async {
    busy.value = true;
    try {
      await _uc.seedDemo();
      await loadProfile();
      Snack.success('Demo data loaded.');
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      Snack.error(mapError(e).message);
    } finally {
      busy.value = false;
    }
  }
}
