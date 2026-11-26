/// Utilities for parsing, normalizing, and converting Google Drive links
/// into direct image stream URLs and detecting duplicates.
class GoogleDriveUtil {
  GoogleDriveUtil._();

  /// Checks whether the URL points to a Google Drive folder rather than a single file.
  /// Example: https://drive.google.com/drive/folders/FOLDER_ID?usp=sharing
  static bool isGoogleDriveFolder(String url) {
    final clean = url.trim().toLowerCase();
    if (clean.isEmpty) return false;
    return clean.contains('drive.google.com/drive/folders/') ||
        RegExp(r'drive\.google\.com/drive/u/\d+/folders/').hasMatch(clean);
  }

  /// Extracts the Google Drive folder ID if the URL is a folder link.
  static String? extractFolderId(String url) {
    if (url.trim().isEmpty) return null;
    final match =
        RegExp(r'/folders/([a-zA-Z0-9_-]+)').firstMatch(url.trim());
    return match?.group(1);
  }

  /// Extracts the Google Drive file ID from various link formats:
  /// - https://drive.google.com/file/d/FILE_ID/view?usp=sharing
  /// - https://drive.google.com/open?id=FILE_ID
  /// - https://drive.google.com/uc?id=FILE_ID
  static String? extractFileId(String url) {
    if (url.trim().isEmpty) return null;
    if (isGoogleDriveFolder(url)) return null;

    // Pattern 1: /file/d/<id>
    final match1 = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (match1 != null) return match1.group(1);

    // Pattern 2: id=<id>
    final match2 = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(url);
    if (match2 != null) return match2.group(1);

    // Pattern 3: /d/<id>
    final match3 = RegExp(r'/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (match3 != null) return match3.group(1);

    return null;
  }

  /// Converts a Google Drive sharing link into a high-speed direct image stream.
  /// Uses Google's official user content CDN: `https://lh3.googleusercontent.com/d/FILE_ID`
  /// which streams without redirects or HTML wrapping, ideal for Image.network.
  static String toDisplayableImageUrl(String url) {
    final clean = url.trim();
    final fileId = extractFileId(clean);
    if (fileId != null) {
      return 'https://lh3.googleusercontent.com/d/$fileId';
    }
    return clean;
  }

  /// Converts a Google Drive / Google Docs / Google Slides link into a direct
  /// binary download URL (PDF or original binary stream).
  static String toDirectDownloadUrl(String url) {
    final clean = url.trim();
    final fileId = extractFileId(clean);
    if (fileId == null) return clean;

    final lower = clean.toLowerCase();
    if (lower.contains('docs.google.com/document/')) {
      return 'https://docs.google.com/document/d/$fileId/export?format=pdf';
    }
    if (lower.contains('docs.google.com/presentation/')) {
      return 'https://docs.google.com/presentation/d/$fileId/export/pdf';
    }
    if (lower.contains('docs.google.com/spreadsheets/')) {
      return 'https://docs.google.com/spreadsheets/d/$fileId/export?format=pdf';
    }
    return 'https://drive.usercontent.google.com/download?id=$fileId&export=download&confirm=t';
  }

  /// Returns ordered candidate download URLs for a given resource link so if one
  /// Google Drive endpoint returns a redirect/interstitial, the downloader can try fallbacks.
  static List<String> candidateDownloadUrls(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return const [];
    final fileId = extractFileId(clean);
    if (fileId == null) return [clean];

    final lower = clean.toLowerCase();
    if (lower.contains('docs.google.com/document/')) {
      return [
        'https://docs.google.com/document/d/$fileId/export?format=pdf',
        'https://drive.usercontent.google.com/download?id=$fileId&export=download&confirm=t',
      ];
    }
    if (lower.contains('docs.google.com/presentation/')) {
      return [
        'https://docs.google.com/presentation/d/$fileId/export/pdf',
        'https://drive.usercontent.google.com/download?id=$fileId&export=download&confirm=t',
      ];
    }
    if (lower.contains('docs.google.com/spreadsheets/')) {
      return [
        'https://docs.google.com/spreadsheets/d/$fileId/export?format=pdf',
        'https://drive.usercontent.google.com/download?id=$fileId&export=download&confirm=t',
      ];
    }

    return [
      'https://drive.usercontent.google.com/download?id=$fileId&export=download&confirm=t',
      'https://drive.google.com/uc?export=download&id=$fileId&confirm=t',
      'https://lh3.googleusercontent.com/d/$fileId',
    ];
  }

  /// Checks whether a URL string is a valid HTTP/HTTPS link or local file path.
  static bool isValidUrlOrLocalPath(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return false;
    if (clean.startsWith('local://') || clean.startsWith('file://')) return true;
    final uri = Uri.tryParse(clean);
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  /// Normalizes a URL for duplicate detection.
  /// If it is a Google Drive link, canonicalizes to `gdrive:file_id`.
  /// For standard URLs, strips tracking query parameters and trailing slashes.

  static String normalizeForComparison(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return '';

    final folderId = extractFolderId(clean);
    if (folderId != null) {
      return 'gdrive_folder:$folderId'.toLowerCase();
    }

    final fileId = extractFileId(clean);
    if (fileId != null) {
      return 'gdrive:$fileId'.toLowerCase();
    }

    try {
      final uri = Uri.parse(clean);
      final host = uri.host.toLowerCase();
      var path = uri.path.toLowerCase();
      if (path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }
      return '$host$path';
    } catch (_) {
      return clean.toLowerCase().replaceAll(RegExp(r'/+$'), '');
    }
  }

  /// Checks if two URLs point to the identical online resource.
  static bool isSameResource(String urlA, String urlB) {
    final a = normalizeForComparison(urlA);
    final b = normalizeForComparison(urlB);
    return a.isNotEmpty && a == b;
  }
}
