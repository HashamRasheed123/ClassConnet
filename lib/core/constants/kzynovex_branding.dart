import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// Single source of truth for app branding & Kzynovex Studio identity.
class KzynovexBranding {
  KzynovexBranding._();

  static const String appName = 'Class Connect';
  static const String appTagline = 'University Lecture Companion & Academic Vault';
  static const String websiteUrl = 'https://www.kzynovex.online';

  // Splash branding typography & colors
  static const String poweredByLabel = 'POWERED BY';
  static const String brandName = 'KZYNOVEX';
  static const Color brandColor = Color(0xFF6D28D9);
  static const Color brandSecondary = Color(0xFF4C1D95);
  static const Color poweredByColor = Color(0xFF6E6A86);

  static const double poweredByFontSize = 10;
  static const double poweredByLetterSpacing = 3.0;
  static const double brandFontSize = 18;
  static const double brandLetterSpacing = 1.8;

  static const Duration splashMinDuration = Duration(milliseconds: 2500);

  /// Launch official studio website safely
  static Future<bool> launchWebsite() async {
    final uri = Uri.parse(websiteUrl);
    try {
      return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Reusable "POWERED BY / KZYNOVEX" footer lockup
class PoweredByKzynovexFooter extends StatelessWidget {
  const PoweredByKzynovexFooter({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 1.2,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 8),
            Text(
              'POWERED BY',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 3.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 1.2,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bolt_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'KZYNOVEX',
              style: TextStyle(
                fontSize: 18,
                letterSpacing: 2.4,
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Official Kzynovex Promo Card shown on Profile, Auth & About screens
class KzynovexPromoCard extends StatelessWidget {
  const KzynovexPromoCard({super.key});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle top-right gradient glow accent
          Positioned(
            top: -24,
            right: -24,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 13, color: AppColors.primary),
                          SizedBox(width: 5),
                          Text(
                            'OFFICIAL STUDIO PARTNER',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Engineered by Kzynovex',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Custom Web, Desktop & Mobile Software Systems built for high performance and modern team velocity.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => KzynovexBranding.launchWebsite(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Visit kzynovex.online ↗',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
