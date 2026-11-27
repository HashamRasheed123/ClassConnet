import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../utils/google_drive_util.dart';

enum OfflineDocErrorType {
  none,
  invalidUrl,
  fileNotFoundLocally,
  networkOrOffline,
  unreachableOrPrivateUrl,
}

class CachedDocumentEntry {
  final String cacheKey;
  final String sourceUrl;
  final String title;
  final String localFilePath;
  final String fileExtension; // 'pdf', 'jpg', 'png', 'webp', 'bin'
  final int fileSizeBytes;
  final DateTime cachedAt;

  const CachedDocumentEntry({
    required this.cacheKey,
    required this.sourceUrl,
    required this.title,
    required this.localFilePath,
    required this.fileExtension,
    required this.fileSizeBytes,
    required this.cachedAt,
  });

  bool get isPdf => fileExtension.toLowerCase() == 'pdf';
  bool get isImage =>
      const {'jpg', 'jpeg', 'png', 'webp', 'gif'}
          .contains(fileExtension.toLowerCase());

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    final kb = fileSizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toMap() => {
        'cache_key': cacheKey,
        'source_url': sourceUrl,
        'title': title,
        'local_file_path': localFilePath,
        'file_extension': fileExtension,
        'file_size_bytes': fileSizeBytes,
        'cached_at': cachedAt.toIso8601String(),
      };

  factory CachedDocumentEntry.fromMap(Map<String, dynamic> map) {
    return CachedDocumentEntry(
      cacheKey: map['cache_key'] as String? ?? '',
      sourceUrl: map['source_url'] as String? ?? '',
      title: map['title'] as String? ?? 'Document',
      localFilePath: map['local_file_path'] as String? ?? '',
      fileExtension: map['file_extension'] as String? ?? 'pdf',
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
      cachedAt: DateTime.tryParse(map['cached_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class OfflineDocResult {
  final bool success;
  final CachedDocumentEntry? entry;
  final OfflineDocErrorType errorType;
  final String message;

  const OfflineDocResult({
    required this.success,
    this.entry,
    this.errorType = OfflineDocErrorType.none,
    required this.message,
  });
}

/// Manages downloading Google Drive / web documents once, storing their local
/// file path in SharedPreferences, verifying local file existence (auto-healing
/// "File Not Found" bugs), and serving them offline on subsequent clicks.
class OfflineDocumentService {
  OfflineDocumentService._();
  static final OfflineDocumentService instance = OfflineDocumentService._();

  static const String _prefsKey = 'offline_document_cache_map_v1';
  static const MethodChannel _nativeChannel =
      MethodChannel('classconnect/alarm_power');
  Map<String, CachedDocumentEntry> _memoryCache = {};
  bool _loaded = false;

  /// Requests Android storage permission when required (Android 9 / API <= 28)
  /// and returns true when granted (or on Android 10+ Scoped Storage).
  Future<bool> ensureStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final granted = await _nativeChannel
          .invokeMethod<bool>('ensureStoragePermission');
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Saves [bytes] to the user's visible `Download/ClassConnect` folder using
  /// Android `MediaStore.Downloads` (Android 10+) or legacy Downloads after
  /// requesting runtime storage permission (Android 9 and below).
  Future<String?> saveToPublicDownloads({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final path = await _nativeChannel.invokeMethod<String>(
        'saveFileToDownloads',
        {
          'fileName': fileName,
          'mimeType': mimeType,
          'bytes': bytes,
        },
      );
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}

    // Fallback direct write if MethodChannel is unavailable
    try {
      final dlDir = Directory('/storage/emulated/0/Download');
      if (await dlDir.exists()) {
        final publicCopy = File('${dlDir.path}/$fileName');
        await publicCopy.writeAsBytes(bytes, flush: true);
        return publicCopy.path;
      }
    } catch (_) {}
    return null;
  }

  /// Notifies UI widgets whenever the cached document registry changes.
  final ValueNotifier<int> cacheVersionNotifier = ValueNotifier<int>(0);

  /// Normalizes any URL or local identifier into a deterministic cache key.
  static String cacheKeyForUrl(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return '';
    final normalized = GoogleDriveUtil.normalizeForComparison(clean);
    return normalized.isNotEmpty ? normalized : clean.toLowerCase();
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _memoryCache = decoded.map(
          (k, v) => MapEntry(
            k,
            CachedDocumentEntry.fromMap(Map<String, dynamic>.from(v as Map)),
          ),
        );
      }
      _loaded = true;
    } catch (e) {
      debugPrint('OfflineDocumentService load error: $e');
      _loaded = true;
    }
  }

  Future<void> _persistRegistry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _memoryCache.map((k, v) => MapEntry(k, v.toMap()));
      await prefs.setString(_prefsKey, jsonEncode(map));
      cacheVersionNotifier.value++;
    } catch (e) {
      debugPrint('OfflineDocumentService persist error: $e');
    }
  }

  /// Synchronous check for UI badges (after [ensureLoaded] has run).
  CachedDocumentEntry? peekCachedEntry(String url) {
    final key = cacheKeyForUrl(url);
    if (key.isEmpty) return null;
    final entry = _memoryCache[key];
    if (entry == null) return null;
    try {
      final f = File(entry.localFilePath);
      if (f.existsSync() && f.lengthSync() > 0) {
        return entry;
      }
    } catch (_) {}
    return null;
  }

  /// Verifies both the registry entry AND that the physical file still exists
  /// on device storage and is non-empty. If the file was deleted externally
  /// ("File Not Found" bug), automatically cleans the stale entry and returns null.
  Future<CachedDocumentEntry?> getValidCachedEntry(String url) async {
    await ensureLoaded();
    final key = cacheKeyForUrl(url);
    if (key.isEmpty) return null;

    final existing = _memoryCache[key];
    if (existing == null) return null;

    try {
      final file = File(existing.localFilePath);
      if (await file.exists()) {
        final len = await file.length();
        if (len > 0) {
          return existing;
        }
      }
    } catch (e) {
      debugPrint('Cached file check failed for ${existing.localFilePath}: $e');
    }

    // Stale address ("File Not Found" on storage) -> auto-heal by removing stale entry
    _memoryCache.remove(key);
    await _persistRegistry();
    return null;
  }

  Future<Directory> _getOfflineDocsDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${baseDir.path}/offline_vault_docs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies a local file picked from the user's device into persistent app
  /// storage and registers its address under [urlKey] so it is always available
  /// offline and never fails with "File Not Found".
  Future<CachedDocumentEntry?> importLocalFile({
    required String sourceFilePath,
    required String urlKey,
    required String title,
  }) async {
    await ensureLoaded();
    try {
      final srcFile = File(sourceFilePath);
      if (!await srcFile.exists()) return null;
      final bytes = await srcFile.readAsBytes();
      if (bytes.isEmpty) return null;

      final ext = _detectExtension(bytes, sourceFilePath, null);
      final docsDir = await _getOfflineDocsDir();
      final safeName = _sanitizeFileName(title, urlKey);
      final targetPath = '${docsDir.path}/${safeName}_local.$ext';
      final targetFile = File(targetPath);
      await targetFile.writeAsBytes(bytes, flush: true);

      final key = cacheKeyForUrl(urlKey);
      final entry = CachedDocumentEntry(
        cacheKey: key,
        sourceUrl: urlKey,
        title: title,
        localFilePath: targetFile.path,
        fileExtension: ext,
        fileSizeBytes: bytes.length,
        cachedAt: DateTime.now(),
      );
      _memoryCache[key] = entry;
      await _persistRegistry();
      return entry;
    } catch (e) {
      debugPrint('importLocalFile error: $e');
      return null;
    }
  }

  /// Removes a cached file from storage and clears its saved address.
  Future<void> removeCachedDocument(String url) async {
    await ensureLoaded();
    final key = cacheKeyForUrl(url);
    final entry = _memoryCache.remove(key);
    if (entry != null) {
      try {
        final f = File(entry.localFilePath);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
      await _persistRegistry();
    }
  }

  /// Downloads a document from a Google Drive link or direct URL, validates
  /// that the response is a real document/image (not an HTML error/login page),
  /// saves it to local storage, and stores its address for future offline clicks.
  Future<OfflineDocResult> downloadAndCache({
    required String url,
    required String title,
    bool forceRefresh = false,
    void Function(double progress)? onProgress,
  }) async {
    await ensureLoaded();
    final cleanUrl = url.trim();

    if (!GoogleDriveUtil.isValidUrlOrLocalPath(cleanUrl)) {
      return const OfflineDocResult(
        success: false,
        errorType: OfflineDocErrorType.invalidUrl,
        message: 'The attached link is not a valid URL.',
      );
    }

    // 1. Check existing local file unless forceRefresh is requested
    if (!forceRefresh) {
      final cached = await getValidCachedEntry(cleanUrl);
      if (cached != null) {
        return OfflineDocResult(
          success: true,
          entry: cached,
          message: 'Opened from offline storage.',
        );
      }
    }

    // If this was a local-only URI and its file is missing
    if (cleanUrl.startsWith('local://')) {
      return const OfflineDocResult(
        success: false,
        errorType: OfflineDocErrorType.fileNotFoundLocally,
        message: 'This local document file could not be found on this device.',
      );
    }

    // 2. Try candidate download URLs (handles Google Drive direct download & fallbacks)
    final candidates = GoogleDriveUtil.candidateDownloadUrls(cleanUrl);
    if (candidates.isEmpty) {
      return const OfflineDocResult(
        success: false,
        errorType: OfflineDocErrorType.invalidUrl,
        message: 'Could not resolve a valid download link.',
      );
    }

    OfflineDocErrorType lastErrorType = OfflineDocErrorType.networkOrOffline;
    String lastErrorMessage =
        'Could not download document. Check your internet connection.';

    for (final candidateUrl in candidates) {
      try {
        final fetchRes = await _fetchBinaryWithRedirects(
          candidateUrl,
          onProgress: onProgress,
        );

        if (fetchRes == null || fetchRes.bytes.isEmpty) {
          lastErrorType = OfflineDocErrorType.unreachableOrPrivateUrl;
          lastErrorMessage = 'The server returned an empty file.';
          continue;
        }

        // Check if Google Drive returned an HTML page instead of the binary file
        if (_looksLikeHtml(fetchRes.bytes)) {
          // Try extracting Google Drive's virus-scan confirmation URL if present
          final confirmUrl =
              _extractDriveConfirmUrl(fetchRes.bytes, candidateUrl);
          if (confirmUrl != null) {
            final confirmedRes = await _fetchBinaryWithRedirects(
              confirmUrl,
              onProgress: onProgress,
            );
            if (confirmedRes != null &&
                confirmedRes.bytes.isNotEmpty &&
                !_looksLikeHtml(confirmedRes.bytes)) {
              return await _saveVerifiedBytes(
                bytes: confirmedRes.bytes,
                contentType: confirmedRes.contentType,
                sourceUrl: cleanUrl,
                title: title,
              );
            }
          }

          lastErrorType = OfflineDocErrorType.unreachableOrPrivateUrl;
          lastErrorMessage =
              'Google Drive returned a web page instead of a downloadable file. Make sure the Drive link sharing is set to "Anyone with the link".';
          continue;
        }

        return await _saveVerifiedBytes(
          bytes: fetchRes.bytes,
          contentType: fetchRes.contentType,
          sourceUrl: cleanUrl,
          title: title,
        );
      } on SocketException {
        lastErrorType = OfflineDocErrorType.networkOrOffline;
        lastErrorMessage =
            'No internet connection. Connect once to download this document for offline use.';
      } on TimeoutException {
        lastErrorType = OfflineDocErrorType.networkOrOffline;
        lastErrorMessage =
            'Download timed out. Please check your connection and try again.';
      } catch (e) {
        debugPrint('Candidate download failed ($candidateUrl): $e');
        lastErrorType = OfflineDocErrorType.unreachableOrPrivateUrl;
        lastErrorMessage = 'Could not download from link: $e';
      }
    }

    return OfflineDocResult(
      success: false,
      errorType: lastErrorType,
      message: lastErrorMessage,
    );
  }

  Future<OfflineDocResult> _saveVerifiedBytes({
    required Uint8List bytes,
    required String? contentType,
    required String sourceUrl,
    required String title,
  }) async {
    final ext = _detectExtension(bytes, sourceUrl, contentType);
    final docsDir = await _getOfflineDocsDir();
    final safeName = _sanitizeFileName(title, sourceUrl);
    final filePath = '${docsDir.path}/$safeName.$ext';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    // Also save a copy to public Android Download/ClassConnect folder (asking for
    // storage permission on legacy Android and using MediaStore on Android 10+)
    if (!kIsWeb && Platform.isAndroid) {
      final mime = ext == 'pdf'
          ? 'application/pdf'
          : (ext == 'png'
              ? 'image/png'
              : (ext == 'webp' ? 'image/webp' : 'image/jpeg'));
      await saveToPublicDownloads(
        fileName: '$safeName.$ext',
        mimeType: mime,
        bytes: bytes,
      );
    }

    final key = cacheKeyForUrl(sourceUrl);
    final entry = CachedDocumentEntry(
      cacheKey: key,
      sourceUrl: sourceUrl,
      title: title,
      localFilePath: file.path,
      fileExtension: ext,
      fileSizeBytes: bytes.length,
      cachedAt: DateTime.now(),
    );

    _memoryCache[key] = entry;
    await _persistRegistry();

    return OfflineDocResult(
      success: true,
      entry: entry,
      message: 'Downloaded & saved for offline access (${entry.formattedSize}).',
    );
  }

  Future<_FetchedBinary?> _fetchBinaryWithRedirects(
    String initialUrl, {
    void Function(double progress)? onProgress,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      Uri currentUri = Uri.parse(initialUrl);
      for (int hop = 0; hop < 6; hop++) {
        final request = await client.getUrl(currentUri);
        request.followRedirects = false;
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
        );
        request.headers.set(HttpHeaders.acceptHeader, '*/*');

        final response =
            await request.close().timeout(const Duration(seconds: 30));
        final status = response.statusCode;

        if (status == HttpStatus.movedPermanently ||
            status == HttpStatus.found ||
            status == HttpStatus.seeOther ||
            status == HttpStatus.temporaryRedirect ||
            status == HttpStatus.permanentRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (location == null || location.isEmpty) return null;
          currentUri = currentUri.resolve(location);
          continue;
        }

        if (status != HttpStatus.ok) {
          await response.drain<void>();
          return null;
        }

        final total = response.contentLength;
        final builder = BytesBuilder(copy: false);
        int received = 0;

        await for (final chunk in response.timeout(const Duration(seconds: 45))) {
          builder.add(chunk);
          received += chunk.length;
          if (onProgress != null && total > 0) {
            onProgress((received / total).clamp(0.0, 1.0));
          }
        }

        final contentType =
            response.headers.value(HttpHeaders.contentTypeHeader);
        return _FetchedBinary(
          bytes: builder.takeBytes(),
          contentType: contentType,
        );
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static bool _looksLikeHtml(Uint8List bytes) {
    if (bytes.length < 15) return false;
    // Check magic headers for PDF or images first
    if (_isPdfMagic(bytes) || _isImageMagic(bytes)) return false;

    final sampleLen = bytes.length < 512 ? bytes.length : 512;
    final head =
        utf8.decode(bytes.sublist(0, sampleLen), allowMalformed: true).trimLeft().toLowerCase();
    return head.startsWith('<!doctype html') ||
        head.startsWith('<html') ||
        head.startsWith('<head') ||
        head.contains('<title>google drive') ||
        head.contains('accounts.google.com/servicelogin');
  }

  static String? _extractDriveConfirmUrl(Uint8List htmlBytes, String baseUrl) {
    try {
      final text = utf8.decode(htmlBytes, allowMalformed: true);
      final fileId = GoogleDriveUtil.extractFileId(baseUrl);
      if (fileId == null) return null;

      final uuidMatch =
          RegExp(r'name="uuid"\s+value="([^"]+)"').firstMatch(text);
      if (uuidMatch != null) {
        final uuid = uuidMatch.group(1);
        return 'https://drive.usercontent.google.com/download?id=$fileId&export=download&confirm=t&uuid=$uuid';
      }
    } catch (_) {}
    return null;
  }

  static bool _isPdfMagic(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46; // F
  }

  static bool _isImageMagic(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }
    // WEBP: RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    return false;
  }

  static String _detectExtension(
    Uint8List bytes,
    String sourceUrl,
    String? contentType,
  ) {
    if (_isPdfMagic(bytes)) return 'pdf';
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45) {
      return 'webp';
    }

    final ct = (contentType ?? '').toLowerCase();
    if (ct.contains('pdf')) return 'pdf';
    if (ct.contains('png')) return 'png';
    if (ct.contains('jpeg') || ct.contains('jpg')) return 'jpg';
    if (ct.contains('webp')) return 'webp';

    final lowerUrl = sourceUrl.toLowerCase();
    if (lowerUrl.endsWith('.png')) return 'png';
    if (lowerUrl.endsWith('.jpg') || lowerUrl.endsWith('.jpeg')) return 'jpg';
    if (lowerUrl.endsWith('.webp')) return 'webp';
    return 'pdf';
  }

  static String _sanitizeFileName(String title, String url) {
    final cleanedTitle = title
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final shortTitle = cleanedTitle.isEmpty
        ? 'ClassConnect_Doc'
        : (cleanedTitle.length > 40
            ? cleanedTitle.substring(0, 40)
            : cleanedTitle);
    final hash = cacheKeyForUrl(url).hashCode.abs().toRadixString(16);
    return '${shortTitle}_$hash';
  }

  // ===========================================================================
  // UNIFIED UI WORKFLOW: CLICK ONCE TO DOWNLOAD & SAVE, CLICK AGAIN FOR OFFLINE
  // ===========================================================================

  Future<void> openOrDownloadDocument(
    BuildContext context, {
    required String url,
    required String title,
    VoidCallback? onCacheUpdated,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No document link is attached to this item.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // 0. If the link is a Google Drive FOLDER (e.g. /drive/folders/<ID>), open it
    // directly in Google Drive / browser since folders contain multiple files.
    if (GoogleDriveUtil.isGoogleDriveFolder(cleanUrl)) {
      final uri = Uri.tryParse(cleanUrl);
      if (uri != null) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening Google Drive folder "$title"...'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        } catch (_) {
          try {
            await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
            return;
          } catch (_) {}
        }
      }
    }

    // 1. Check if already cached locally and file still exists on storage
    final existing = await getValidCachedEntry(cleanUrl);
    if (existing != null) {
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OfflineDocumentViewerScreen(
            entry: existing,
            onRedownloadRequested: () async {
              onCacheUpdated?.call();
            },
          ),
        ),
      );
      onCacheUpdated?.call();
      return;
    }

    // 2. Not cached yet (or local file was deleted) -> Download with progress dialog
    if (!context.mounted) return;
    final progressNotifier = ValueNotifier<double?>(null);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: ValueListenableBuilder<double?>(
            valueListenable: progressNotifier,
            builder: (context, progress, _) {
              final pct =
                  progress != null ? '${(progress * 100).toInt()}%' : '';
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.downloading_rounded,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Saving Offline Copy... $pct',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.primarySoft,
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Next time you tap this document, it will open instantly offline from device storage.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    final result = await downloadAndCache(
      url: cleanUrl,
      title: title,
      onProgress: (p) => progressNotifier.value = p,
    );

    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context); // Close progress dialog
    }
    onCacheUpdated?.call();

    if (!context.mounted) return;

    if (result.success && result.entry != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OfflineDocumentViewerScreen(
            entry: result.entry!,
            onRedownloadRequested: () async {
              onCacheUpdated?.call();
            },
          ),
        ),
      );
      onCacheUpdated?.call();
    } else {
      _showDownloadErrorDialog(
        context,
        url: cleanUrl,
        title: title,
        result: result,
        onCacheUpdated: onCacheUpdated,
      );
    }
  }

  void _showDownloadErrorDialog(
    BuildContext context, {
    required String url,
    required String title,
    required OfflineDocResult result,
    VoidCallback? onCacheUpdated,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              result.errorType == OfflineDocErrorType.networkOrOffline
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              color: AppColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.errorType == OfflineDocErrorType.networkOrOffline
                    ? 'Offline / Connection Issue'
                    : 'Could Not Download File',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          result.message,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (!url.startsWith('local://'))
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open Link in Browser'),
            ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              openOrDownloadDocument(
                context,
                url: url,
                title: title,
                onCacheUpdated: onCacheUpdated,
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _FetchedBinary {
  final Uint8List bytes;
  final String? contentType;

  const _FetchedBinary({
    required this.bytes,
    this.contentType,
  });
}

/// Built-in Offline Document & Image Viewer Screen.
/// Reads directly from the saved local file path on device storage and handles
/// missing/corrupted files gracefully with 1-tap re-download.
class OfflineDocumentViewerScreen extends StatefulWidget {
  final CachedDocumentEntry entry;
  final VoidCallback? onRedownloadRequested;

  const OfflineDocumentViewerScreen({
    super.key,
    required this.entry,
    this.onRedownloadRequested,
  });

  @override
  State<OfflineDocumentViewerScreen> createState() =>
      _OfflineDocumentViewerScreenState();
}

class _OfflineDocumentViewerScreenState
    extends State<OfflineDocumentViewerScreen> {
  late CachedDocumentEntry _entry;
  Uint8List? _bytes;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _loadLocalFile();
  }

  Future<void> _loadLocalFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final file = File(_entry.localFilePath);
      if (!await file.exists()) {
        await OfflineDocumentService.instance
            .removeCachedDocument(_entry.sourceUrl);
        setState(() {
          _error =
              'Local file was moved or deleted from device storage (${_entry.localFilePath}). Tap "Re-Download" below to restore it.';
          _isLoading = false;
        });
        return;
      }
      final data = await file.readAsBytes();
      if (data.isEmpty) {
        await OfflineDocumentService.instance
            .removeCachedDocument(_entry.sourceUrl);
        setState(() {
          _error = 'The local file is empty (0 bytes). Tap "Re-Download" to fix.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _bytes = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to read local file: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _redownloadFreshCopy() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final res = await OfflineDocumentService.instance.downloadAndCache(
      url: _entry.sourceUrl,
      title: _entry.title,
      forceRefresh: true,
    );
    widget.onRedownloadRequested?.call();
    if (!mounted) return;
    if (res.success && res.entry != null) {
      _entry = res.entry!;
      await _loadLocalFile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline copy refreshed successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      setState(() {
        _error = res.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _shareOrExportFile() async {
    if (_bytes == null) return;
    try {
      final cleanName = _entry.title
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\s]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      await Printing.sharePdf(
        bytes: _bytes!,
        filename:
            '${cleanName.isEmpty ? "Document" : cleanName}.${_entry.fileExtension}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share file: $e')),
        );
      }
    }
  }

  Future<void> _saveCopyToDownloads() async {
    if (_bytes == null) return;
    final cleanName = _entry.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final fileName =
        '${cleanName.isEmpty ? "ClassConnect_Doc" : cleanName}.${_entry.fileExtension}';
    final mime = _entry.isPdf
        ? 'application/pdf'
        : (_entry.fileExtension == 'png' ? 'image/png' : 'image/jpeg');

    final savedPath =
        await OfflineDocumentService.instance.saveToPublicDownloads(
      fileName: fileName,
      mimeType: mime,
      bytes: _bytes!,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedPath != null
              ? 'Saved to Downloads: $savedPath'
              : 'Saved offline in app storage: ${_entry.localFilePath}',
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Text(
              'Offline Ready • ${_entry.formattedSize} • Saved on Device',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          if (_bytes != null)
            IconButton(
              tooltip: 'Save to Device Downloads Folder',
              icon: const Icon(Icons.download_rounded),
              onPressed: _saveCopyToDownloads,
            ),
          if (_bytes != null)
            IconButton(
              tooltip: 'Share / Export File',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: _shareOrExportFile,
            ),
          if (!_entry.sourceUrl.startsWith('local://'))
            IconButton(
              tooltip: 'Re-download fresh copy from cloud',
              icon: const Icon(Icons.sync_rounded),
              onPressed: _redownloadFreshCopy,
            ),
        ],
      ),
      body: Column(
        children: [
          // Local storage path banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              border: Border(bottom: BorderSide(color: AppColors.successBorder)),
            ),
            child: Row(
              children: [
                Icon(Icons.offline_pin_rounded,
                    size: 16, color: AppColors.successText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Local path: ${_entry.localFilePath}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.successText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView()
                    : _buildDocumentBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.dangerBgStrong,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_off_rounded,
                size: 38,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'File Not Found or Unreadable',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (!_entry.sourceUrl.startsWith('local://'))
                  ElevatedButton.icon(
                    onPressed: _redownloadFreshCopy,
                    icon: const Icon(Icons.cloud_download_rounded, size: 18),
                    label: const Text('Re-Download from Cloud'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (!_entry.sourceUrl.startsWith('local://'))
                  OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(_entry.sourceUrl);
                      if (uri != null) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open Original Link'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentBody() {
    final bytes = _bytes!;
    if (_entry.isImage) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _buildErrorView(),
          ),
        ),
      );
    }

    if (_entry.isPdf) {
      return PdfPreview(
        build: (_) async => bytes,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: '${_entry.title}.pdf',
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onError: (context, error) => _buildErrorView(),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_rounded,
                size: 56, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(
              _entry.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Saved offline (${_entry.formattedSize}) at:\n${_entry.localFilePath}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _shareOrExportFile,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open / Share File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
