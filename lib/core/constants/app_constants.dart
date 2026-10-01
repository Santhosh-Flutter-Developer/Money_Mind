class AppConstants {
  static const appName = 'MoneyMind';
  static const tagline = 'Plan Your Money. Track Your Future.';

  /// Supplied at build/run time, never hardcoded:
  /// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  // static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  // static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const supabaseUrl = "https://llqtmawuxxkeutaogxuk.supabase.co";
  static const supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxscXRtYXd1eHhrZXV0YW9neHVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA3NzM3NDIsImV4cCI6MjEwNjM0OTc0Mn0.EyVMVHN8JdkJ94nqIBUSbFLEhKA8KsUecf_h6lGl7j0";
  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Enables the "Load demo data" tile in More. Use --dart-define=DEMO_MODE=true
  static const demoMode = bool.fromEnvironment('DEMO_MODE');

  static const defaultCurrency = 'INR';
  static const supportedCurrencies = ['INR', 'USD', 'EUR', 'GBP'];
  static const mobileBreakpoint = 700.0;
  static const desktopBreakpoint = 1100.0;
  static const maxContentWidth = 1200.0;

  static const privacyUrl = 'https://moneymind.app/privacy';
  static const termsUrl = 'https://moneymind.app/terms';
}
