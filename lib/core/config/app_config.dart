/// Backend configuration.
///
/// Secrets and configuration are injected at build/run time so they are never committed to version control:
///   flutter run --dart-define-from-file=.env
/// or
///   flutter run --dart-define-from-file=env.json
///
/// See `.env.example.json` or `.env.example` for required configuration keys.
class AppConfig {
  AppConfig._();

  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envKey = String.fromEnvironment('SUPABASE_KEY');
  static const String _envAdminEmails = String.fromEnvironment('ADMIN_EMAILS');
  static const String _envAdminPassword = String.fromEnvironment('ADMIN_PASSWORD');
  static const String _envDbPassword = String.fromEnvironment('DB_PASSWORD');

  // Test / runtime overrides for mock environments and unit tests
  static String? testSupabaseUrl;
  static String? testSupabaseKey;
  static List<String>? testAdminEmails;
  static String? testAdminPassword;

  /// Supabase project URL
  static String get supabaseUrl =>
      testSupabaseUrl ?? _envUrl;

  /// Supabase anon / publishable key
  static String get supabaseKey =>
      testSupabaseKey ?? _envKey;

  /// Designated Administrator Emails loaded securely from environment variable `ADMIN_EMAILS`
  /// Supports comma-separated emails, e.g. "admin1@example.com,admin2@example.com"
  static List<String> get adminEmails {
    if (testAdminEmails != null) return testAdminEmails!;
    if (_envAdminEmails.isEmpty) return const [];
    return _envAdminEmails
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Master Admin Password loaded securely from environment variable `ADMIN_PASSWORD`
  static String get adminPassword =>
      testAdminPassword ?? _envAdminPassword;

  /// Database password if required by backend scripts/services
  static String get dbPassword => _envDbPassword;

  /// Validates whether an email matches any authorized administrator email
  static bool isDesignatedAdminEmail(String? checkEmail) {
    if (checkEmail == null) return false;
    final normalized = checkEmail.trim().toLowerCase();
    return adminEmails.any((admin) => admin.toLowerCase() == normalized);
  }

  /// Storage bucket holding uploaded lecture notes (Vault).
  static const String notesBucket = 'lecture-notes';

  /// Edge Function that sends FCM pushes.
  static const String notifyFunction = 'notify-class';

  /// FCM topic every signed-in member of the class subscribes to.
  static const String fcmTopic = 'class_updates';

  /// Android notification channel (also referenced in AndroidManifest.xml).
  static const String notificationChannelId = 'class_updates';
  static const String notificationChannelName = 'Class updates';

  /// Supabase free tier default upload limit.
  static const int maxUploadBytes = 50 * 1024 * 1024;

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Application Versioning & Identity
  static const String appVersion = '1.0.0';
  static const int appVersionCode = 1;
  static const String appPackageName = 'com.softwareclass.softwareclass';
  static const String appBuildChannel = 'Signed Release';

  /// Titan Portal Update Manager API (Base host)
  static const String defaultUpdateBaseUrl = 'http://titan.portal.kzynovex.online';
}
