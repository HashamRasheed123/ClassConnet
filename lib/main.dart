import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'core/constants/kzynovex_branding.dart';
import 'core/services/alert_scheduler.dart';
import 'core/services/auth_service.dart';
import 'core/services/offline_document_service.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'repositories/class_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI navigation bar & status bar style
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle);

  // Initialize background services and preload local caches concurrently so startup is ultra-fast
  await Future.wait([
    AuthService.instance.getActiveSession().catchError((e) {
      debugPrint('AuthSession preload skipped: $e');
      return null;
    }),
    ClassRepository.preloadCache().catchError((e) {
      debugPrint('ClassRepository preload skipped: $e');
    }),
    AlertScheduler.instance.initialize().catchError((e) {
      debugPrint('AlertScheduler init skipped: $e');
    }),
    OfflineDocumentService.instance.ensureLoaded().catchError((e) {
      debugPrint('OfflineDocumentService init skipped: $e');
    }),
    if (AppConfig.isSupabaseConfigured)
      Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseKey,
      ).then((_) {
        debugPrint('Supabase initialized successfully.');
      }).catchError((e) {
        debugPrint('Supabase init skipped/error: $e');
      }),
  ]);

  // Global error handler so any route or widget crash displays a styled diagnostic
  // error view with stack trace and Go Back button instead of a silent blank white screen.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF0F172A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFF59E0B),
                      size: 28,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Screen Rendering Diagnostic',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'An error occurred while building this screen. Full diagnostic details below:',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Text(
                    details.exceptionAsString(),
                    style: const TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (ctx) => ElevatedButton.icon(
                    onPressed: () {
                      if (Navigator.canPop(ctx)) {
                        Navigator.pop(ctx);
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  runApp(
    const ProviderScope(
      child: ClassConnectApp(),
    ),
  );
}

class ClassConnectApp extends StatelessWidget {
  const ClassConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: KzynovexBranding.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
