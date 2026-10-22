import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _date = DateFormat('EEE, d MMM');
  static final _fullDate = DateFormat('EEEE, d MMMM yyyy');
  static final _time = DateFormat('h:mm a');

  static String date(DateTime d) => _date.format(d.toLocal());
  static String fullDate(DateTime d) => _fullDate.format(d.toLocal());
  static String time(DateTime d) => _time.format(d.toLocal());

  static String timeRange(DateTime start, DateTime? end) =>
      end == null ? time(start) : '${time(start)} – ${time(end)}';

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
