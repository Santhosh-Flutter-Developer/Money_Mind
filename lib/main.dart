import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/services/notification_service.dart';
import 'core/services/prefs_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/bindings/initial_binding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConstants.isConfigured) {
    runApp(const _ConfigErrorApp());
    return;
  }
  await SupabaseService.init();
  await PrefsService.init();
  await NotificationService.instance.init();
  runApp(const MoneyMindApp());
}

class MoneyMindApp extends StatelessWidget {
  const MoneyMindApp({super.key});
  @override
  Widget build(BuildContext context) => GetMaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: PrefsService.themeMode,
        initialBinding: InitialBinding(),
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
      );
}

class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: SelectableText(
                'MoneyMind is not configured.\n\nRun with:\nflutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key\n\nThen run supabase/schema.sql in the Supabase SQL editor.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
