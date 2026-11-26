import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const MethodChannel _nativeChannel =
      MethodChannel('classconnect/alarm_power');

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

  /// Launches the native Android Package Installer for an already-downloaded APK file.
  Future<String> triggerNativeApkInstall(String filePath) async {
    if (kIsWeb || !Platform.isAndroid) return 'UNSUPPORTED';
    try {
      final res = await _nativeChannel.invokeMethod<String>(
        'installApk',
        {'filePath': filePath},
      );
      return res ?? 'ERROR';
    } catch (e) {
      debugPrint('triggerNativeApkInstall error: $e');
      return 'ERROR';
    }
  }

  /// Downloads the update APK directly inside the app with live progress reporting,
  /// verifies its APK/ZIP magic header, and triggers the Android Package Installer.
  Future<({bool success, String? apkFilePath, String statusMessage})>
      downloadAndInstallUpdate(
    AppUpdateInfo info, {
    required void Function(
      double progress,
      int receivedBytes,
      int totalBytes,
      String statusText,
    ) onProgress,
  }) async {
    final downloadUrl = info.resolvedDownloadUrl.trim();
    if (downloadUrl.isEmpty) {
      return (
        success: false,
        apkFilePath: null,
        statusMessage: 'Invalid update download URL.',
      );
    }

    // Use getTemporaryDirectory() (/cache on Android) which is explicitly shared
    // by FileProvider (<cache-path>) across all Android versions.
    final baseDir = await getTemporaryDirectory();
    final otaDir = Directory('${baseDir.path}/ota_updates');
    if (!await otaDir.exists()) {
      await otaDir.create(recursive: true);
    }
    final cleanVer = info.versionName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final apkFile = File(
      '${otaDir.path}/ClassConnect_v${cleanVer}_b${info.versionCode}.apk',
    );

    // If this exact version APK was already downloaded and is valid (> 1 MB with PK header),
    // launch installer immediately!
    if (await apkFile.exists()) {
      try {
        final len = await apkFile.length();
        if (len > 1024 * 1024) {
          final header = await apkFile.openRead(0, 4).first;
          if (header.length >= 2 && header[0] == 0x50 && header[1] == 0x4B) {
            onProgress(1.0, len, len, 'Update ready! Launching installer...');
            final installRes = await triggerNativeApkInstall(apkFile.path);
            final isSuccess = installRes == 'INSTALLER_LAUNCHED' ||
                installRes == 'PERMISSION_REQUESTED';
            final msg = installRes == 'PERMISSION_REQUESTED'
                ? 'Enable "Allow from this source" — installer will start automatically!'
                : installRes == 'INSTALLER_LAUNCHED'
                    ? 'Android Package Installer opened! Tap "Update" in the system prompt.'
                    : 'Could not launch system installer automatically. Tap below to retry.';
            return (
              success: isSuccess,
              apkFilePath: apkFile.path,
              statusMessage: msg,
            );
          }
        }
      } catch (_) {}
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    IOSink? sink;

    try {
      onProgress(0.0, 0, 0, 'Connecting to update server...');
      Uri targetUri = Uri.parse(downloadUrl);
      HttpClientResponse? response;

      for (int hop = 0; hop < 6; hop++) {
        final request = await client.getUrl(targetUri);
        request.followRedirects = false;
        request.headers.set(HttpHeaders.acceptHeader, '*/*');
        response =
            await request.close().timeout(const Duration(seconds: 30));

        if (response.isRedirect ||
            response.statusCode == HttpStatus.movedPermanently ||
            response.statusCode == HttpStatus.found ||
            response.statusCode == HttpStatus.seeOther ||
            response.statusCode == HttpStatus.temporaryRedirect ||
            response.statusCode == HttpStatus.permanentRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (location != null && location.isNotEmpty) {
            targetUri = targetUri.resolve(location);
            continue;
          }
        }
        break;
      }

      if (response == null || response.statusCode != HttpStatus.ok) {
        return (
          success: false,
          apkFilePath: null,
          statusMessage:
              'Update server returned HTTP ${response?.statusCode ?? "error"}.',
        );
      }

      final totalBytes = response.contentLength;
      final tempFile = File('${apkFile.path}.part');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      sink = tempFile.openWrite();

      int receivedBytes = 0;
      List<int>? firstBytes;

      await for (final chunk
          in response.timeout(const Duration(seconds: 120))) {
        firstBytes ??= chunk.take(4).toList();
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = totalBytes > 0
            ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
            : 0.0;
        final recMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
        final totMb = totalBytes > 0
            ? ' / ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
            : ' MB';
        onProgress(
          progress,
          receivedBytes,
          totalBytes,
          'Downloading update in-app... ($recMb$totMb)',
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // Verify APK ZIP magic header ('PK' = 0x50, 0x4B)
      if (receivedBytes < 1024 ||
          firstBytes == null ||
          firstBytes.length < 2 ||
          firstBytes[0] != 0x50 ||
          firstBytes[1] != 0x4B) {
        if (await tempFile.exists()) await tempFile.delete();
        return (
          success: false,
          apkFilePath: null,
          statusMessage:
              'Downloaded file is not a valid Android APK package.',
        );
      }

      if (await apkFile.exists()) {
        await apkFile.delete();
      }
      await tempFile.rename(apkFile.path);

      onProgress(
        1.0,
        receivedBytes,
        receivedBytes,
        'Download complete! Launching Android Installer...',
      );

      final installStatus = await triggerNativeApkInstall(apkFile.path);
      if (installStatus == 'PERMISSION_REQUESTED') {
        return (
          success: true,
          apkFilePath: apkFile.path,
          statusMessage:
              'Please toggle "Allow from this source" — the update will install automatically when you return!',
        );
      }
      if (installStatus == 'INSTALLER_LAUNCHED') {
        return (
          success: true,
          apkFilePath: apkFile.path,
          statusMessage:
              'Android Package Installer opened! Tap "Update" in the system prompt.',
        );
      }

      return (
        success: false,
        apkFilePath: apkFile.path,
        statusMessage: 'Downloaded APK, but could not launch system installer.',
      );
    } catch (e) {
      debugPrint('downloadAndInstallUpdate error: $e');
      return (
        success: false,
        apkFilePath: null,
        statusMessage: 'In-app update download failed: $e',
      );
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      client.close(force: true);
    }
  }

  /// Displays the interactive update dialog with in-app download progress and automatic installation
  Future<void> showUpdateDialog(
    BuildContext context,
    AppUpdateInfo info, {
    VoidCallback? onLater,
  }) async {
    HapticFeedback.mediumImpact();

    bool isDownloading = false;
    double progress = 0.0;
    String statusText = '';
    String? errorText;
    String? downloadedApkPath;

    await showDialog(
      context: context,
      barrierDismissible: !info.isMandatory && !isDownloading,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => PopScope(
          canPop: !info.isMandatory && !isDownloading,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
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
                                        : 'In-App Update Available',
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
                          constraints: const BoxConstraints(maxHeight: 150),
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

                  // Live In-App Download Progress Area
                  if (isDownloading ||
                      statusText.isNotEmpty ||
                      errorText != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: errorText != null
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: errorText != null
                                ? const Color(0xFFFECACA)
                                : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isDownloading) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Downloading Update...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    progress > 0
                                        ? '${(progress * 100).toStringAsFixed(0)}%'
                                        : '...',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progress > 0 ? progress : null,
                                  minHeight: 8,
                                  backgroundColor: const Color(0xFFDBEAFE),
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            Text(
                              errorText ?? statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: errorText != null
                                    ? AppColors.danger
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        // Direct In-App Update Now Button
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton.icon(
                            onPressed: isDownloading
                                ? null
                                : () async {
                                    // If already downloaded in this session, trigger installer directly
                                    if (downloadedApkPath != null) {
                                      final installRes =
                                          await triggerNativeApkInstall(
                                              downloadedApkPath!);
                                      if (!ctx.mounted) return;
                                      setModalState(() {
                                        if (installRes ==
                                            'INSTALLER_LAUNCHED') {
                                          errorText = null;
                                          statusText =
                                              'Android Package Installer opened! Tap "Update" in the system prompt.';
                                        } else if (installRes ==
                                            'PERMISSION_REQUESTED') {
                                          errorText = null;
                                          statusText =
                                              'Enable "Allow from this source" — installer will start automatically!';
                                        } else {
                                          errorText =
                                              'Could not open Android Package Installer for this file.';
                                        }
                                      });
                                      return;
                                    }

                                    setModalState(() {
                                      isDownloading = true;
                                      errorText = null;
                                      progress = 0.0;
                                      statusText =
                                          'Starting in-app update download...';
                                    });

                                    final res = await downloadAndInstallUpdate(
                                      info,
                                      onProgress: (p, rec, tot, msg) {
                                        if (ctx.mounted) {
                                          setModalState(() {
                                            progress = p;
                                            statusText = msg;
                                          });
                                        }
                                      },
                                    );

                                    if (!ctx.mounted) return;
                                    setModalState(() {
                                      isDownloading = false;
                                      downloadedApkPath = res.apkFilePath;
                                      if (res.success) {
                                        statusText = res.statusMessage;
                                        errorText = null;
                                      } else {
                                        errorText = res.statusMessage;
                                      }
                                    });
                                  },
                            icon: isDownloading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    downloadedApkPath != null
                                        ? Icons.install_mobile_rounded
                                        : Icons.system_update_alt_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              isDownloading
                                  ? 'Downloading in App...'
                                  : (downloadedApkPath != null
                                      ? 'Install Downloaded Update Now'
                                      : 'Update Now (Direct In-App)'),
                              style: const TextStyle(
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

                        // Secondary "Later" & "Skip" actions (if not mandatory and not downloading)
                        if (!info.isMandatory && !isDownloading) ...[
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
                                    await setIgnoredVersionCode(
                                        info.versionCode);
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Version ${info.versionName} skipped. You can still check manually in Settings.'),
                                          duration:
                                              const Duration(seconds: 2),
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
