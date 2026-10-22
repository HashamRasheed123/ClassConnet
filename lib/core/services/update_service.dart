import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';

/// Metadata for a release returned by Titan Portal Update Manager API
class AppUpdateInfo {
  final int versionCode;
  final String versionName;
  final String releaseNotes;
  final bool isMandatory;
  final String rawDownloadUrl;
  final String resolvedDownloadUrl;

  const AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.releaseNotes,
    required this.isMandatory,
    required this.rawDownloadUrl,
    required this.resolvedDownloadUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json, String baseUrl) {
    final rawUrl = json['download_url'] as String? ?? '';
    String resolvedUrl = rawUrl;
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      resolvedUrl = rawUrl;
    } else {
      final cleanBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final cleanPath = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
      resolvedUrl = '$cleanBase$cleanPath';
    }

    return AppUpdateInfo(
      versionCode: json['version_code'] as int? ?? 0,
      versionName: json['version_name'] as String? ?? '1.0.0',
      releaseNotes: json['release_notes'] as String? ?? 'General improvements and stability fixes.',
      isMandatory: json['is_mandatory'] as bool? ?? false,
      rawDownloadUrl: rawUrl,
      resolvedDownloadUrl: resolvedUrl,
    );
  }

  bool get isNewerThanCurrent => versionCode > AppConfig.appVersionCode;
}

enum UpdateCheckStatus {
  idle,
  checking,
  updateAvailable,
  upToDate,
  error,
}

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final AppUpdateInfo? updateInfo;
  final String message;

  const UpdateCheckResult({
    required this.status,
    this.updateInfo,
    required this.message,
  });

  bool get isUpdateAvailable =>
      status == UpdateCheckStatus.updateAvailable && updateInfo != null;
}

/// Core Update Manager Service
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String _keyAutoCheck = 'key_auto_check_updates_v1';
  static const String _keyCustomBaseUrl = 'key_custom_update_base_url_v1';
  static const String _keyIgnoredVersion = 'key_ignored_version_code_v1';

  /// Returns current active update API host
  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString(_keyCustomBaseUrl);
    if (custom != null && custom.trim().isNotEmpty) {
      return custom.trim();
    }
    return AppConfig.defaultUpdateBaseUrl;
  }

  /// Sets custom update API host (useful for local testing / production switches)
  Future<void> setCustomBaseUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_keyCustomBaseUrl);
    } else {
      await prefs.setString(_keyCustomBaseUrl, url.trim());
    }
  }

  /// Auto-check preference toggle
  Future<bool> isAutoCheckEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoCheck) ?? true;
  }

  Future<void> setAutoCheckEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoCheck, enabled);
  }

  /// Ignored versions
  Future<int?> getIgnoredVersionCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyIgnoredVersion);
  }

  Future<void> setIgnoredVersionCode(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyIgnoredVersion, versionCode);
  }

  /// Queries GET /api/v1/update-check/{package_name}
  Future<UpdateCheckResult> checkForUpdate({
    bool ignoreSkipped = false,
  }) async {
    final host = await getBaseUrl();
    final cleanHost = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
    final urlString = '$cleanHost/api/v1/update-check/${AppConfig.appPackageName}';

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      Uri targetUri = Uri.parse(urlString);

      // Follow redirects (including HTTP to HTTPS) up to 5 hops
      HttpClientResponse? response;
      for (int i = 0; i < 5; i++) {
        final request = await client.getUrl(targetUri);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        response = await request.close();

        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location != null) {
            targetUri = targetUri.resolve(location);
            continue;
          }
        }
        break;
      }

      if (response == null) {
        return const UpdateCheckResult(
          status: UpdateCheckStatus.error,
          message: 'Unable to reach update server.',
        );
      }

      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final info = AppUpdateInfo.fromJson(data, cleanHost);

        if (info.isNewerThanCurrent) {
          // Check if this specific non-mandatory version was skipped by user
          if (!ignoreSkipped && !info.isMandatory) {
            final ignored = await getIgnoredVersionCode();
            if (ignored == info.versionCode) {
              return UpdateCheckResult(
                status: UpdateCheckStatus.upToDate,
                updateInfo: info,
                message: 'Update v${info.versionName} is available, but currently snoozed.',
              );
            }
          }

          return UpdateCheckResult(
            status: UpdateCheckStatus.updateAvailable,
            updateInfo: info,
            message: 'A new update (v${info.versionName}) is available!',
          );
        } else {
          return UpdateCheckResult(
            status: UpdateCheckStatus.upToDate,
            updateInfo: info,
            message: 'App is up to date (v${AppConfig.appVersion} Build ${AppConfig.appVersionCode}).',
          );
        }
      } else if (response.statusCode == 404) {
        // As defined in API documentation: package not registered or no release uploaded yet
        return UpdateCheckResult(
          status: UpdateCheckStatus.upToDate,
          message: 'Your app is on the latest version (v${AppConfig.appVersion}).',
        );
      } else {
        return UpdateCheckResult(
          status: UpdateCheckStatus.error,
          message: 'Server returned HTTP ${response.statusCode}',
        );
      }
    } on SocketException {
      return const UpdateCheckResult(
        status: UpdateCheckStatus.error,
        message: 'Network offline. Could not reach update host.',
      );
    } catch (e) {
      return UpdateCheckResult(
        status: UpdateCheckStatus.error,
        message: 'Update check failed: $e',
      );
    } finally {
      client.close();
    }
  }

  /// Displays the interactive update dialog with release notes, description, and action buttons
  Future<void> showUpdateDialog(
    BuildContext context,
    AppUpdateInfo info, {
    VoidCallback? onLater,
  }) async {
    HapticFeedback.mediumImpact();

    await showDialog(
      context: context,
      barrierDismissible: !info.isMandatory,
      builder: (ctx) => PopScope(
        canPop: !info.isMandatory,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Gradient Banner
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    gradient: info.isMandatory
                        ? const LinearGradient(
                            colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : AppColors.brandGradient,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.system_update_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  info.isMandatory
                                      ? 'Mandatory Update'
                                      : 'New Version Available',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                if (info.isMandatory) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'REQUIRED',
                                      style: TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'v${info.versionName} (Build ${info.versionCode})',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Version comparison pill
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current: v${AppConfig.appVersion}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 14, color: AppColors.textSecondary),
                        Text(
                          'New: v${info.versionName}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Release Notes / What's New Description
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "What's New in This Release",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Text(
                            info.releaseNotes.trim().isNotEmpty
                                ? info.releaseNotes
                                : 'Performance optimizations, security patches, and user experience enhancements.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      // Download / Update Now
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(info.resolvedDownloadUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            } else {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Could not open download link: ${info.resolvedDownloadUrl}'),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text(
                            'Download & Install Update',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: info.isMandatory
                                ? const Color(0xFFDC2626)
                                : AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      // Secondary "Later" & "Skip" actions (if not mandatory)
                      if (!info.isMandatory) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  onLater?.call();
                                },
                                child: const Text(
                                  'Remind Me Later',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 16,
                              color: AppColors.border,
                            ),
                            Expanded(
                              child: TextButton(
                                onPressed: () async {
                                  await setIgnoredVersionCode(info.versionCode);
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Version ${info.versionName} skipped. You can still check manually in Settings.'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                child: const Text(
                                  'Skip This Version',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
}

/// Riverpod State Notifier for app update status
class UpdateStateNotifier extends Notifier<UpdateCheckResult> {
  @override
  UpdateCheckResult build() {
    return const UpdateCheckResult(
      status: UpdateCheckStatus.idle,
      message: 'Not checked yet',
    );
  }

  Future<UpdateCheckResult> check({
    bool showModalIfAvailable = false,
    BuildContext? context,
    bool manual = false,
  }) async {
    state = const UpdateCheckResult(
      status: UpdateCheckStatus.checking,
      message: 'Checking for updates on Titan Portal...',
    );

    final result = await UpdateService.instance.checkForUpdate(
      ignoreSkipped: manual,
    );

    state = result;

    if (showModalIfAvailable &&
        result.isUpdateAvailable &&
        context != null &&
        context.mounted) {
      UpdateService.instance.showUpdateDialog(context, result.updateInfo!);
    }

    return result;
  }
}

final updateStateProvider =
    NotifierProvider<UpdateStateNotifier, UpdateCheckResult>(
        UpdateStateNotifier.new);
