/// Utilities for parsing, normalizing, and converting Google Drive links
/// into direct image stream URLs and detecting duplicates.
class GoogleDriveUtil {
  GoogleDriveUtil._();

  /// Extracts the Google Drive file ID from various link formats:
  /// - https://drive.google.com/file/d/FILE_ID/view?usp=sharing
  /// - https://drive.google.com/open?id=FILE_ID
  /// - https://drive.google.com/uc?id=FILE_ID
  static String? extractFileId(String url) {
    if (url.trim().isEmpty) return null;

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

  /// Normalizes a URL for duplicate detection.
  /// If it is a Google Drive link, canonicalizes to `gdrive:file_id`.
  /// For standard URLs, strips tracking query parameters and trailing slashes.

  static String normalizeForComparison(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return '';

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
