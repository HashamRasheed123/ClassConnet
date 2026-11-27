import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/kzynovex_branding.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/class_providers.dart';
import '../../core/widgets/educational_agreement_dialog.dart';
import '../shell/main_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loginLoading = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (AppConfig.isSupabaseConfigured) {
      try {
        _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
          final session = data.session;
          if (data.event == AuthChangeEvent.signedIn && session != null) {
            final email = session.user.email;
            if (email != null && email.isNotEmpty) {
              final name = (session.user.userMetadata?['full_name'] as String?) ??
                  (session.user.userMetadata?['name'] as String?) ??
                  email.split('@').first;
              final avatar = session.user.userMetadata?['avatar_url'] as String?;
              _handleGoogleSignIn(
                email: email,
                name: name,
                avatarUrl: avatar,
              );
            }
          }
        });
      } catch (e) {
        debugPrint('Supabase auth listener setup: $e');
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Native 1-Click Google Sign In (prompts all device Google accounts)
  Future<void> _handleNativeGoogleSignIn() async {
    if (_loginLoading) return;
    setState(() => _loginLoading = true);

    try {
      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
      );

      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account == null) {
        // User dismissed the account chooser bottom sheet
        if (mounted) {
          setState(() => _loginLoading = false);
        }
        return;
      }

      final email = account.email.trim();
      final name = (account.displayName != null && account.displayName!.trim().isNotEmpty)
          ? account.displayName!.trim()
          : email.split('@').first;
      final avatarUrl = account.photoUrl;

      await _handleGoogleSignIn(
        email: email,
        name: name,
        avatarUrl: avatarUrl,
      );
    } catch (e) {
      debugPrint('Native Google Sign-In error: $e');
      if (mounted) {
        setState(() => _loginLoading = false);
        final errText = e.toString();
        String message = 'Google Sign-In failed. Please try again.';
        if (errText.contains('10') || errText.contains('ApiException')) {
          message = 'Google Sign-In error: SHA-1 fingerprint not registered in Firebase for this build.';
        } else if (errText.contains('7') || errText.contains('network')) {
          message = 'Network error: please check your internet connection and try again.';
        }
        _showSnackbar(message, isError: true);
      }
    }
  }

  Future<void> _handleGoogleSignIn({
    required String email,
    required String name,
    String? avatarUrl,
  }) async {
    setState(() => _loginLoading = true);
    try {
      final result = await ref
          .read(currentUserProvider.notifier)
          .signInWithGoogle(
            email: email,
            name: name,
            avatarUrl: avatarUrl,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => const AuthResult(
              success: false,
              message: 'Sign in timed out. Please check your network and try again.',
            ),
          );

      if (!mounted) return;
      if (result.success) {
        _showSnackbar(result.message, isError: false);
        await EducationalAgreementDialog.showIfNeeded(context);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      } else {
        _showSnackbar(result.message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Sign in failed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loginLoading = false);
      }
    }
  }

  Widget _buildGoogleGLogo({double size = 20}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: size * 0.72,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF4285F4),
            fontFamily: 'sans-serif',
          ),
        ),
      ),
    );
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.snackBarBg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Brand Header
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    KzynovexBranding.appName,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Academic Companion & Timetable Hub',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Value Highlights Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureRow(
                        icon: Icons.calendar_today_rounded,
                        color: AppColors.primary,
                        title: 'Live Weekly Timetables',
                        subtitle: 'Real-time lectures, room changes & alerts',
                      ),
                      const SizedBox(height: 14),
                      _buildFeatureRow(
                        icon: Icons.folder_special_rounded,
                        color: AppColors.success,
                        title: 'Verified Study Notes Vault',
                        subtitle: 'Upload requests reviewed by faculty & CRs',
                      ),
                      const SizedBox(height: 14),
                      _buildFeatureRow(
                        icon: Icons.radar_rounded,
                        color: AppColors.warning,
                        title: 'Smart Bunk Radar',
                        subtitle: 'Calculated attendance & lecture tracking',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // =======================================================
                // PROMINENT GOOGLE SIGN IN BUTTON
                // =======================================================
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loginLoading ? null : _handleNativeGoogleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardSurface,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.borderStrong, width: 1.2),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: _loginLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildGoogleGLogo(size: 24),
                              const SizedBox(width: 12),
                              Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),



                const SizedBox(height: 24),

                // Security Note
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Secure OAuth 2.0 Academic Authentication',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
