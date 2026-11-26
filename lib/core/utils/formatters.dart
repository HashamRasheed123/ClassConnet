import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class Formatters {
  Formatters._();

  /// Normalizes a user-entered meeting URL (auto-prepending `https://` if missing).
  static String? normalizeMeetingUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  /// Extracts a meeting URL if [text] is or contains a link (e.g. Meet, Zoom, Teams, or http/https).
  static String? extractMeetingUrl(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final trimmed = text.trim();
    final urlMatch = RegExp(
      r'(https?://[^\s]+|(?:meet\.google\.com|[\w-]*\.?zoom\.us|teams\.microsoft\.com|teams\.live\.com|[\w-]+\.webex\.com)/[^\s]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (urlMatch != null) {
      return normalizeMeetingUrl(urlMatch.group(0));
    }
    return null;
  }

  /// Opens a class/meeting URL directly in the external browser or native app (Meet/Zoom/Teams).
  static Future<void> launchMeetingUrl(
    BuildContext context,
    String? rawUrl,
  ) async {
    final normalized = normalizeMeetingUrl(rawUrl);
    if (normalized == null) return;
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid meeting link format.')),
        );
      }
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open meeting link: $normalized')),
          );
        }
      }
    }
  }

  static final _date = DateFormat('EEE, d MMM');
  static final _fullDate = DateFormat('EEEE, d MMMM yyyy');
  static final _time = DateFormat('h:mm a');

  static String date(DateTime d) => _date.format(d.toLocal());
  static String fullDate(DateTime d) => _fullDate.format(d.toLocal());
  static String time(DateTime d) => _time.format(d.toLocal());

  static String timeRange(DateTime start, DateTime? end) =>
      end == null ? time(start) : '${time(start)} – ${time(end)}';

  /// Normalizes any "HH:mm:ss" or "H:m" 24-hour time string into canonical "HH:mm".
  static String normalizeTime(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return '';
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]).clamp(0, 23);
        final minute = int.parse(parts[1]).clamp(0, 59);
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    return timeStr.trim();
  }

  /// Normalizes an optional time string, returning null when null or empty.
  static String? normalizeOptionalTime(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final normalized = normalizeTime(timeStr);
    return normalized.isEmpty ? null : normalized;
  }

  /// Converts a "HH:mm" 24-hour time string into 12-hour format (e.g. "9:00 AM", "1:15 PM").
  static String formatTimeString(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        hour = hour % 12;
        if (hour == 0) hour = 12;
        final minuteStr = minute.toString().padLeft(2, '0');
        return '$hour:$minuteStr $period';
      }
    } catch (_) {}
    return timeStr;
  }

  /// Converts start and end 24-hour time strings into 12-hour range (e.g. "9:00 AM - 10:15 AM").
  static String formatTimeRangeString(String? start, String? end) {
    if (start == null || start.isEmpty) return '';
    final formattedStart = formatTimeString(start);
    if (end == null || end.isEmpty) return formattedStart;
    return '$formattedStart - ${formatTimeString(end)}';
  }

  /// "Today", "Tomorrow", "Yesterday" or a short date.
  static String relativeDay(DateTime d) {
    final local = d.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return date(local);
  }

  /// "in 2h 15m", "in 3 days", "started".
  static String countdown(DateTime start) {
    final diff = start.difference(DateTime.now());
    if (diff.isNegative) return 'Started';
    if (diff.inDays >= 1) {
      return 'in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
    }
    if (diff.inHours >= 1) return 'in ${diff.inHours}h ${diff.inMinutes % 60}m';
    return 'in ${diff.inMinutes}m';
  }

  static String timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(d);
  }

  static String fileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
