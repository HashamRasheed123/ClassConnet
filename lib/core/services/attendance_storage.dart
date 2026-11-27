import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';
import '../utils/uuid_util.dart';

/// Pure SharedPreferences storage helper for student attendance records and
/// daily slot marks. Kept independent of Riverpod so background notification
/// handlers and [AlertScheduler] can log attendance without circular imports.
class AttendanceStorage {
  AttendanceStorage._();

  static const String recordsPrefsKey = 'student_attendance_records_v1';
  static const String dailyMarksPrefsKey = 'student_attendance_daily_marks_v1';

  static String buildSlotKey({
    required DateTime date,
    required String subjectId,
    required String slotId,
  }) {
    final dayStr = date.toIso8601String().substring(0, 10);
    final normSub = subjectId.trim().isNotEmpty
        ? UuidUtil.fromString(subjectId)
        : 'unknown';
    return '$dayStr|$normSub|$slotId';
  }

  static Future<Map<String, AttendanceRecord>> loadRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(recordsPrefsKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final loaded = <String, AttendanceRecord>{};
      for (final entry in decoded.entries) {
        if (entry.value is Map) {
          loaded[entry.key] = AttendanceRecord.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
      return loaded;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveRecords(Map<String, AttendanceRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = records.map((k, v) => MapEntry(k, v.toMap()));
      await prefs.setString(recordsPrefsKey, jsonEncode(encoded));
    } catch (_) {}
  }

  static Future<Map<String, String>> loadDailyMarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(dailyMarksPrefsKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final cutoff = DateTime.now().subtract(const Duration(days: 14));
      final loaded = <String, String>{};
      for (final entry in decoded.entries) {
        final parts = entry.key.split('|');
        if (parts.isNotEmpty) {
          final dt = DateTime.tryParse(parts[0]);
          if (dt != null && dt.isBefore(cutoff)) continue;
        }
        final val = entry.value?.toString();
        if (val == 'present' || val == 'absent') {
          loaded[entry.key] = val!;
        }
      }
      return loaded;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveDailyMarks(Map<String, String> marks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(dailyMarksPrefsKey, jsonEncode(marks));
    } catch (_) {}
  }

  static String resolveRecordKey(
    Map<String, AttendanceRecord> records,
    String subjectId,
  ) {
    if (records.containsKey(subjectId)) return subjectId;
    final norm = UuidUtil.fromString(subjectId);
    if (records.containsKey(norm)) return norm;
    return norm;
  }

  static Future<({AttendanceRecord record, bool alreadyMarked})>
      recordFromNotification({
    required String subjectId,
    required bool isPresent,
    required String slotKey,
  }) async {
    final records = await loadRecords();
    final marks = await loadDailyMarks();
    final key = resolveRecordKey(records, subjectId);
    final current = records[key] ??
        AttendanceRecord(subjectId: key, attended: 0, total: 0);

    final desired = isPresent ? 'present' : 'absent';
    final existingMark = marks[slotKey];
    if (existingMark == desired) {
      return (record: current, alreadyMarked: true);
    }

    late final AttendanceRecord updated;
    if (existingMark == 'present' && !isPresent) {
      updated = current.copyWith(
        attended: (current.attended - 1).clamp(0, current.total),
      );
    } else if (existingMark == 'absent' && isPresent) {
      updated = current.copyWith(
        attended: (current.attended + 1).clamp(0, current.total),
      );
    } else {
      updated = current.copyWith(
        attended: isPresent ? current.attended + 1 : current.attended,
        total: current.total + 1,
      );
    }

    records[key] = updated;
    marks[slotKey] = desired;
    await saveRecords(records);
    await saveDailyMarks(marks);
    return (record: updated, alreadyMarked: false);
  }
}
