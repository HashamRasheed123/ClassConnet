import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import '../core/utils/formatters.dart';

/// User profile model
class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'student' | 'admin'
  final int credits;
  final int streakCount;
  final bool isKzynovexVerified;
  final String? avatarUrl;
  final String? rollNo;
  final bool isLoggedIn;
  final bool canUpload;
  final String uploadRequestStatus; // 'none' | 'pending' | 'approved' | 'rejected'
  final DateTime? uploadRequestedAt;
  final String authProvider; // 'google' | 'pin'

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.credits = 30,
    this.streakCount = 1,
    this.isKzynovexVerified = false,
    this.avatarUrl,
    this.rollNo,
    this.isLoggedIn = true,
    this.canUpload = false,
    this.uploadRequestStatus = 'none',
    this.uploadRequestedAt,
    this.authProvider = 'pin',
  });

  const UserModel.empty()
      : id = '',
        name = '',
        email = '',
        role = 'student',
        credits = 0,
        streakCount = 0,
        isKzynovexVerified = false,
        avatarUrl = null,
        rollNo = null,
        isLoggedIn = false,
        canUpload = false,
        uploadRequestStatus = 'none',
        uploadRequestedAt = null,
        authProvider = 'pin';

  static List<String> get designatedAdminEmails => AppConfig.adminEmails;

  static bool isDesignatedAdminEmail(String? checkEmail) =>
      AppConfig.isDesignatedAdminEmail(checkEmail);

  bool get isAdmin =>
      role == 'admin' || isDesignatedAdminEmail(email);

  bool get isUploaderVerified =>
      isAdmin || canUpload || uploadRequestStatus == 'approved';

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    int? credits,
    int? streakCount,
    bool? isKzynovexVerified,
    String? avatarUrl,
    String? rollNo,
    bool? isLoggedIn,
    bool? canUpload,
    String? uploadRequestStatus,
    DateTime? uploadRequestedAt,
    String? authProvider,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      credits: credits ?? this.credits,
      streakCount: streakCount ?? this.streakCount,
      isKzynovexVerified: isKzynovexVerified ?? this.isKzynovexVerified,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rollNo: rollNo ?? this.rollNo,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      canUpload: canUpload ?? this.canUpload,
      uploadRequestStatus: uploadRequestStatus ?? this.uploadRequestStatus,
      uploadRequestedAt: uploadRequestedAt ?? this.uploadRequestedAt,
      authProvider: authProvider ?? this.authProvider,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Student',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'student',
      credits: (map['credits'] as num?)?.toInt() ?? 30,
      streakCount: (map['streak_count'] as num?)?.toInt() ?? 1,
      isKzynovexVerified: map['is_kzynovex_verified'] as bool? ?? false,
      avatarUrl: map['avatar_url'] as String?,
      rollNo: map['roll_no'] as String?,
      isLoggedIn: map['is_logged_in'] as bool? ?? true,
      canUpload: map['can_upload'] as bool? ?? false,
      uploadRequestStatus: map['upload_request_status'] as String? ?? 'none',
      uploadRequestedAt: map['upload_requested_at'] != null
          ? DateTime.tryParse(map['upload_requested_at'] as String)
          : null,
      authProvider: map['auth_provider'] as String? ?? 'pin',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'credits': credits,
        'streak_count': streakCount,
        'is_kzynovex_verified': isKzynovexVerified,
        'avatar_url': avatarUrl,
        'roll_no': rollNo,
        'is_logged_in': isLoggedIn,
        'can_upload': canUpload,
        'upload_request_status': uploadRequestStatus,
        'upload_requested_at': uploadRequestedAt?.toIso8601String(),
        'auth_provider': authProvider,
      };
}

/// Contributor/Uploader Verification Request
class UploaderRequestModel {
  final String id;
  final String userId;
  final String googleEmail;
  final String name;
  final String rollNo;
  final DateTime submittedAt;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  const UploaderRequestModel({
    required this.id,
    required this.userId,
    required this.googleEmail,
    required this.name,
    required this.rollNo,
    required this.submittedAt,
    this.status = 'pending',
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  UploaderRequestModel copyWith({
    String? id,
    String? userId,
    String? googleEmail,
    String? name,
    String? rollNo,
    DateTime? submittedAt,
    String? status,
    String? rejectionReason,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return UploaderRequestModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      googleEmail: googleEmail ?? this.googleEmail,
      name: name ?? this.name,
      rollNo: rollNo ?? this.rollNo,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }

  factory UploaderRequestModel.fromMap(Map<String, dynamic> map) {
    return UploaderRequestModel(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      googleEmail: (map['google_email'] as String? ?? '').trim().toLowerCase(),
      name: map['name'] as String? ?? '',
      rollNo: (map['roll_no'] as String? ?? '').trim().toUpperCase(),
      submittedAt: map['submitted_at'] != null
          ? DateTime.tryParse(map['submitted_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: map['status'] as String? ?? 'pending',
      rejectionReason: map['rejection_reason'] as String?,
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.tryParse(map['reviewed_at'] as String)
          : null,
      reviewedBy: map['reviewed_by'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'google_email': googleEmail,
        'name': name,
        'roll_no': rollNo,
        'submitted_at': submittedAt.toIso8601String(),
        'status': status,
        'rejection_reason': rejectionReason,
        'reviewed_at': reviewedAt?.toIso8601String(),
        'reviewed_by': reviewedBy,
      };
}

/// Academic subject / course
class SubjectModel {
  final String id;
  final String name;
  final String code;
  final String professor;
  final int minAttendancePct;
  final String colorHex;

  const SubjectModel({
    required this.id,
    required this.name,
    required this.code,
    required this.professor,
    this.minAttendancePct = 75,
    this.colorHex = '#6D28D9',
  });

  Color get color {
    final hex = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  SubjectModel copyWith({
    String? id,
    String? name,
    String? code,
    String? professor,
    int? minAttendancePct,
    String? colorHex,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      professor: professor ?? this.professor,
      minAttendancePct: minAttendancePct ?? this.minAttendancePct,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  factory SubjectModel.fromMap(Map<String, dynamic> map) {
    return SubjectModel(
      id: map['id'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      professor: map['professor'] as String,
      minAttendancePct: (map['min_attendance_pct'] as num?)?.toInt() ?? 75,
      colorHex: map['color_hex'] as String? ?? '#6D28D9',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'code': code,
        'professor': professor,
        'min_attendance_pct': minAttendancePct,
        'color_hex': colorHex,
      };
}

/// Weekly recurring slot
class TimetableSlotModel {
  final String id;
  final String subjectId;
  final int dayOfWeek; // 1 = Mon ... 7 = Sun
  final String startTime; // "09:00"
  final String endTime; // "10:15"
  final String defaultRoom;
  final String? meetingUrl;

  const TimetableSlotModel({
    required this.id,
    required this.subjectId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.defaultRoom,
    this.meetingUrl,
  });

  static final RegExp _urlMetaRegex = RegExp(r'\s*\[CC_URL:([^\]]+)\]\s*$');

  /// Encodes [meetingUrl] into [defaultRoom] so unmigrated Supabase `timetable_slots`
  /// tables persist and sync the class meeting link without needing a schema change.
  static String encodeRoomWithUrl(String room, String? meetingUrl) {
    final cleanRoom = room.replaceFirst(_urlMetaRegex, '').trim();
    final safeRoom = cleanRoom.isEmpty ? 'TBD' : cleanRoom;
    final cleanUrl = meetingUrl?.trim();
    if (cleanUrl == null || cleanUrl.isEmpty) {
      return safeRoom;
    }
    return '$safeRoom [CC_URL:${Uri.encodeComponent(cleanUrl)}]';
  }

  String? get effectiveMeetingUrl {
    if (meetingUrl != null && meetingUrl!.trim().isNotEmpty) {
      return Formatters.normalizeMeetingUrl(meetingUrl);
    }
    return Formatters.extractMeetingUrl(defaultRoom);
  }

  bool get hasMeetingUrl =>
      effectiveMeetingUrl != null && effectiveMeetingUrl!.isNotEmpty;

  TimeOfDay get startParsed {
    final norm = Formatters.normalizeTime(startTime);
    final parts = (norm.isNotEmpty ? norm : '09:00').split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  TimeOfDay get endParsed {
    final norm = Formatters.normalizeTime(endTime);
    final parts = (norm.isNotEmpty ? norm : '10:00').split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 10,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  String get formattedStartTime => Formatters.formatTimeString(startTime);
  String get formattedEndTime => Formatters.formatTimeString(endTime);
  String get formattedTimeRange => '$formattedStartTime - $formattedEndTime';

  TimetableSlotModel copyWith({
    String? id,
    String? subjectId,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? defaultRoom,
    String? meetingUrl,
    bool clearMeetingUrl = false,
  }) {
    return TimetableSlotModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime != null ? Formatters.normalizeTime(startTime) : this.startTime,
      endTime: endTime != null ? Formatters.normalizeTime(endTime) : this.endTime,
      defaultRoom: defaultRoom ?? this.defaultRoom,
      meetingUrl: clearMeetingUrl ? null : (meetingUrl ?? this.meetingUrl),
    );
  }

  factory TimetableSlotModel.fromMap(Map<String, dynamic> map) {
    String rawRoom = map['default_room'] as String? ?? 'TBD';
    String? metaUrl;
    final match = _urlMetaRegex.firstMatch(rawRoom);
    if (match != null) {
      final encoded = match.group(1);
      if (encoded != null && encoded.isNotEmpty) {
        try {
          metaUrl = Uri.decodeComponent(encoded);
        } catch (_) {
          metaUrl = encoded;
        }
      }
      rawRoom = rawRoom.substring(0, match.start).trim();
      if (rawRoom.isEmpty) rawRoom = 'TBD';
    }
    final explicitUrl = (map['meeting_url'] as String?)?.trim();
    final resolvedUrl =
        (explicitUrl != null && explicitUrl.isNotEmpty) ? explicitUrl : metaUrl;

    return TimetableSlotModel(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String,
      dayOfWeek: (map['day_of_week'] as num).toInt(),
      startTime: Formatters.normalizeTime(map['start_time'] as String?),
      endTime: Formatters.normalizeTime(map['end_time'] as String?),
      defaultRoom: rawRoom,
      meetingUrl: resolvedUrl,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject_id': subjectId,
        'day_of_week': dayOfWeek,
        'start_time': Formatters.normalizeTime(startTime),
        'end_time': Formatters.normalizeTime(endTime),
        'default_room': encodeRoomWithUrl(defaultRoom, meetingUrl),
      };
}

/// Status of a lecture override
enum OverrideStatus {
  scheduled('Scheduled'),
  cancelled('Cancelled'),
  rescheduled('Rescheduled / Shifted');

  const OverrideStatus(this.label);
  final String label;

  static OverrideStatus fromString(String val) {
    return OverrideStatus.values.firstWhere(
      (s) => s.name == val,
      orElse: () => OverrideStatus.scheduled,
    );
  }
}

/// Daily override for a timetable slot
class DailyOverrideModel {
  final String id;
  final String slotId;
  final DateTime date;
  final OverrideStatus status;
  final String? actualRoom;
  final String? actualStartTime;
  final String? actualEndTime;
  final DateTime? rescheduledDate;
  final String? meetingUrl;
  final String? topicCovered;
  final String? reportedBy;
  final bool isApproved;

  const DailyOverrideModel({
    required this.id,
    required this.slotId,
    required this.date,
    required this.status,
    this.actualRoom,
    this.actualStartTime,
    this.actualEndTime,
    this.rescheduledDate,
    this.meetingUrl,
    this.topicCovered,
    this.reportedBy,
    this.isApproved = false,
  });

  String? get effectiveMeetingUrl {
    if (meetingUrl != null && meetingUrl!.trim().isNotEmpty) {
      return Formatters.normalizeMeetingUrl(meetingUrl);
    }
    return Formatters.extractMeetingUrl(actualRoom);
  }

  bool get hasMeetingUrl =>
      effectiveMeetingUrl != null && effectiveMeetingUrl!.isNotEmpty;

  String? get formattedStartTime =>
      actualStartTime != null ? Formatters.formatTimeString(actualStartTime!) : null;
  String? get formattedEndTime =>
      actualEndTime != null ? Formatters.formatTimeString(actualEndTime!) : null;
  String? get formattedTimeRange =>
      actualStartTime != null ? Formatters.formatTimeRangeString(actualStartTime, actualEndTime) : null;

  DailyOverrideModel copyWith({
    String? id,
    String? slotId,
    DateTime? date,
    OverrideStatus? status,
    String? actualRoom,
    String? actualStartTime,
    String? actualEndTime,
    DateTime? rescheduledDate,
    String? meetingUrl,
    bool clearMeetingUrl = false,
    String? topicCovered,
    String? reportedBy,
    bool? isApproved,
  }) {
    return DailyOverrideModel(
      id: id ?? this.id,
      slotId: slotId ?? this.slotId,
      date: date ?? this.date,
      status: status ?? this.status,
      actualRoom: actualRoom ?? this.actualRoom,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      rescheduledDate: rescheduledDate ?? this.rescheduledDate,
      meetingUrl: clearMeetingUrl ? null : (meetingUrl ?? this.meetingUrl),
      topicCovered: topicCovered ?? this.topicCovered,
      reportedBy: reportedBy ?? this.reportedBy,
      isApproved: isApproved ?? this.isApproved,
    );
  }

  static final RegExp _metaPrefixRegex = RegExp(r'^\[CC_META:([^\]]*)\]\s*');

  /// Encodes `actual_start_time`, `actual_end_time`, `rescheduled_date`, and `meeting_url`
  /// into `topic_covered` so unmigrated Supabase instances without those columns
  /// still persist and sync meeting time/date/link updates reliably.
  static String? encodeMetaIntoTopic({
    String? topicCovered,
    String? actualStartTime,
    String? actualEndTime,
    String? rescheduledDate,
    String? meetingUrl,
  }) {
    final cleanTopic =
        (topicCovered ?? '').replaceFirst(_metaPrefixRegex, '').trim();
    final normStart = Formatters.normalizeOptionalTime(actualStartTime);
    final normEnd = Formatters.normalizeOptionalTime(actualEndTime);
    final normDate = (rescheduledDate != null && rescheduledDate.trim().isNotEmpty)
        ? rescheduledDate.trim().substring(0, 10)
        : null;
    final cleanUrl =
        (meetingUrl != null && meetingUrl.trim().isNotEmpty) ? meetingUrl.trim() : null;

    if (normStart == null &&
        normEnd == null &&
        normDate == null &&
        cleanUrl == null) {
      return cleanTopic.isEmpty ? null : cleanTopic;
    }

    final parts = <String>[
      if (normStart != null) 'start=$normStart',
      if (normEnd != null) 'end=$normEnd',
      if (normDate != null) 'rdate=$normDate',
      if (cleanUrl != null) 'url=${Uri.encodeComponent(cleanUrl)}',
    ];
    final prefix = '[CC_META:${parts.join(';')}]';
    return cleanTopic.isEmpty ? prefix : '$prefix $cleanTopic';
  }

  factory DailyOverrideModel.fromMap(Map<String, dynamic> map) {
    String? rawTopic = map['topic_covered'] as String?;
    String? metaStart;
    String? metaEnd;
    String? metaRDate;
    String? metaUrl;

    if (rawTopic != null) {
      final match = _metaPrefixRegex.firstMatch(rawTopic);
      if (match != null) {
        final metaBody = match.group(1) ?? '';
        for (final kv in metaBody.split(';')) {
          final idx = kv.indexOf('=');
          if (idx > 0) {
            final k = kv.substring(0, idx).trim();
            final v = kv.substring(idx + 1).trim();
            if (v.isNotEmpty) {
              if (k == 'start') metaStart = v;
              if (k == 'end') metaEnd = v;
              if (k == 'rdate') metaRDate = v;
              if (k == 'url') {
                try {
                  metaUrl = Uri.decodeComponent(v);
                } catch (_) {
                  metaUrl = v;
                }
              }
            }
          }
        }
        final stripped = rawTopic.substring(match.end).trim();
        rawTopic = stripped.isEmpty ? null : stripped;
      }
    }

    final rawStart = (map['actual_start_time'] as String?) ?? metaStart;
    final rawEnd = (map['actual_end_time'] as String?) ?? metaEnd;
    final rawRescheduledDate =
        (map['rescheduled_date'] as String?) ?? metaRDate;
    final explicitUrl = (map['meeting_url'] as String?)?.trim();
    final resolvedUrl =
        (explicitUrl != null && explicitUrl.isNotEmpty) ? explicitUrl : metaUrl;

    return DailyOverrideModel(
      id: map['id'] as String,
      slotId: map['slot_id'] as String,
      date: DateTime.parse(map['date'] as String),
      status: OverrideStatus.fromString(map['status'] as String? ?? 'scheduled'),
      actualRoom: map['actual_room'] as String?,
      actualStartTime: Formatters.normalizeOptionalTime(rawStart),
      actualEndTime: Formatters.normalizeOptionalTime(rawEnd),
      rescheduledDate: rawRescheduledDate != null
          ? DateTime.tryParse(rawRescheduledDate)
          : null,
      meetingUrl: resolvedUrl,
      topicCovered: rawTopic,
      reportedBy: map['reported_by'] as String?,
      isApproved: map['is_approved'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'slot_id': slotId,
        'date': date.toIso8601String().substring(0, 10),
        'status': status.name,
        'actual_room': actualRoom,
        'actual_start_time': Formatters.normalizeOptionalTime(actualStartTime),
        'actual_end_time': Formatters.normalizeOptionalTime(actualEndTime),
        'rescheduled_date': rescheduledDate?.toIso8601String().substring(0, 10),
        'meeting_url':
            meetingUrl?.trim().isNotEmpty == true ? meetingUrl!.trim() : null,
        'topic_covered': topicCovered,
        'reported_by': reportedBy,
        'is_approved': isApproved,
      };
}

/// Academic resource / Vault item
enum ResourceType {
  pdf('PDF Document', Icons.picture_as_pdf_rounded),
  image('Image & Slides', Icons.image_rounded),
  youtube('Lecture Video', Icons.play_circle_filled_rounded);

  const ResourceType(this.label, this.icon);
  final String label;
  final IconData icon;

  static ResourceType fromString(String val) {
    return ResourceType.values.firstWhere(
      (t) => t.name == val,
      orElse: () => ResourceType.pdf,
    );
  }
}

class ResourceModel {
  final String id;
  final String subjectId;
  final DateTime date;
  final String? uploaderId;
  final String uploaderName;
  final String title;
  final ResourceType type;
  final String url;
  final int upvotes;
  final int costCredits;
  final bool isApproved;
  final bool isUnlocked;

  const ResourceModel({
    required this.id,
    required this.subjectId,
    required this.date,
    this.uploaderId,
    required this.uploaderName,
    required this.title,
    required this.type,
    required this.url,
    this.upvotes = 0,
    this.costCredits = 5,
    this.isApproved = false,
    this.isUnlocked = false,
  });

  ResourceModel copyWith({
    String? id,
    String? subjectId,
    DateTime? date,
    String? uploaderId,
    String? uploaderName,
    String? title,
    ResourceType? type,
    String? url,
    int? upvotes,
    int? costCredits,
    bool? isApproved,
    bool? isUnlocked,
  }) {
    return ResourceModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      date: date ?? this.date,
      uploaderId: uploaderId ?? this.uploaderId,
      uploaderName: uploaderName ?? this.uploaderName,
      title: title ?? this.title,
      type: type ?? this.type,
      url: url ?? this.url,
      upvotes: upvotes ?? this.upvotes,
      costCredits: costCredits ?? this.costCredits,
      isApproved: isApproved ?? this.isApproved,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }

  factory ResourceModel.fromMap(Map<String, dynamic> map, {bool isUnlocked = false}) {
    return ResourceModel(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String,
      date: DateTime.parse(map['date'] as String),
      uploaderId: map['uploader_id'] as String?,
      uploaderName: map['uploader_name'] as String? ?? 'Classmate',
      title: map['title'] as String,
      type: ResourceType.fromString(map['type'] as String? ?? 'pdf'),
      url: map['url'] as String,
      upvotes: (map['upvotes'] as num?)?.toInt() ?? 0,
      costCredits: (map['cost_credits'] as num?)?.toInt() ?? 5,
      isApproved: map['is_approved'] as bool? ?? false,
      isUnlocked: isUnlocked,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject_id': subjectId,
        'date': date.toIso8601String().substring(0, 10),
        'uploader_id': uploaderId,
        'uploader_name': uploaderName,
        'title': title,
        'type': type.name,
        'url': url,
        'upvotes': upvotes,
        'cost_credits': costCredits,
        'is_approved': isApproved,
      };
}

/// Live combined representation of a lecture for today
class LectureItem {
  final TimetableSlotModel slot;
  final SubjectModel subject;
  final DailyOverrideModel? override;
  final DateTime startsAt;
  final DateTime endsAt;

  const LectureItem({
    required this.slot,
    required this.subject,
    this.override,
    required this.startsAt,
    required this.endsAt,
  });

  bool get isCancelled => override?.status == OverrideStatus.cancelled;
  bool get isRoomChanged =>
      override?.status == OverrideStatus.rescheduled &&
      override?.actualRoom != null &&
      override!.actualRoom!.isNotEmpty &&
      override!.actualRoom != slot.defaultRoom;

  bool get isTimeChanged =>
      override?.status == OverrideStatus.rescheduled &&
      override?.actualStartTime != null &&
      override!.actualStartTime!.isNotEmpty &&
      (Formatters.normalizeTime(override!.actualStartTime) !=
              Formatters.normalizeTime(slot.startTime) ||
          (override?.actualEndTime != null &&
              override!.actualEndTime!.isNotEmpty &&
              Formatters.normalizeTime(override!.actualEndTime) !=
                  Formatters.normalizeTime(slot.endTime)));

  bool get isDayRescheduled =>
      override?.status == OverrideStatus.rescheduled &&
      override?.rescheduledDate != null;

  bool get isRescheduled =>
      override?.status == OverrideStatus.rescheduled &&
      (isRoomChanged || isTimeChanged || isDayRescheduled);

  String get effectiveRoom =>
      isRoomChanged ? override!.actualRoom! : slot.defaultRoom;

  String get effectiveStartTime =>
      (override?.status == OverrideStatus.rescheduled &&
              override?.actualStartTime != null &&
              override!.actualStartTime!.isNotEmpty)
          ? Formatters.normalizeTime(override!.actualStartTime)
          : Formatters.normalizeTime(slot.startTime);

  String get effectiveEndTime =>
      (override?.status == OverrideStatus.rescheduled &&
              override?.actualEndTime != null &&
              override!.actualEndTime!.isNotEmpty)
          ? Formatters.normalizeTime(override!.actualEndTime)
          : Formatters.normalizeTime(slot.endTime);

  String get formattedStartTime => Formatters.formatTimeString(effectiveStartTime);
  String get formattedEndTime => Formatters.formatTimeString(effectiveEndTime);
  String get formattedTimeRange => '$formattedStartTime - $formattedEndTime';

  String? get topicCovered => override?.topicCovered;

  String? get meetingUrl {
    if (isCancelled) return null;
    if (override != null && override!.hasMeetingUrl) {
      return override!.effectiveMeetingUrl;
    }
    return slot.effectiveMeetingUrl;
  }

  bool get hasMeetingUrl => meetingUrl != null && meetingUrl!.isNotEmpty;

  bool get isDayMovedAway {
    if (override?.status != OverrideStatus.rescheduled || override?.rescheduledDate == null) {
      return false;
    }
    final r = override!.rescheduledDate!;
    return !(r.year == startsAt.year && r.month == startsAt.month && r.day == startsAt.day);
  }

  bool get isOngoing {
    final now = DateTime.now();
    return !isCancelled && !isDayMovedAway && now.isAfter(startsAt) && now.isBefore(endsAt);
  }

  bool get isUpcoming {
    final now = DateTime.now();
    return !isCancelled && !isDayMovedAway && startsAt.isAfter(now);
  }
}

/// Attendance Record for Bunk Calculator
class AttendanceRecord {
  final String subjectId;
  final int attended;
  final int total;

  const AttendanceRecord({
    required this.subjectId,
    required this.attended,
    required this.total,
  });

  double get percentage => total == 0 ? 100.0 : (attended / total) * 100.0;

  AttendanceRecord copyWith({
    String? subjectId,
    int? attended,
    int? total,
  }) {
    return AttendanceRecord(
      subjectId: subjectId ?? this.subjectId,
      attended: attended ?? this.attended,
      total: total ?? this.total,
    );
  }

  Map<String, dynamic> toMap() => {
        'subject_id': subjectId,
        'attended': attended,
        'total': total,
      };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      subjectId: map['subject_id'] as String? ?? '',
      attended: (map['attended'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// Calculates bunk safety:
  /// returns positive number if safe to bunk X lectures,
  /// returns negative number indicating X consecutive lectures needed.
  int bunkAllowance(int minPct) {
    if (total == 0) return 0;
    final target = minPct / 100.0;
    if (percentage >= minPct) {
      // (attended) / (total + X) >= target  =>  X <= (attended / target) - total
      final maxMissable = (attended / target) - total;
      return maxMissable.floor();
    } else {
      // (attended + Y) / (total + Y) >= target => Y >= (target*total - attended)/(1 - target)
      final needed = ((target * total) - attended) / (1.0 - target);
      return -needed.ceil();
    }
  }
}

/// Academic Assignment Model
class AssignmentModel {
  final String id;
  final String subjectId;
  final String title;
  final String description;
  final DateTime deadline;
  final String? driveUrl;
  final String createdBy;
  final DateTime createdAt;

  const AssignmentModel({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.description,
    required this.deadline,
    this.driveUrl,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isDueTomorrow {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final d = DateTime(deadline.year, deadline.month, deadline.day);
    return d.isAtSameMomentAs(tomorrow);
  }

  bool get isDueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(deadline.year, deadline.month, deadline.day);
    return d.isAtSameMomentAs(today);
  }

  bool get isOverdue => DateTime.now().isAfter(deadline);

  String get formattedDeadline {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = months[deadline.month - 1];
    final hour = deadline.hour > 12
        ? deadline.hour - 12
        : (deadline.hour == 0 ? 12 : deadline.hour);
    final period = deadline.hour >= 12 ? 'PM' : 'AM';
    final minute = deadline.minute.toString().padLeft(2, '0');
    return '$m ${deadline.day}, $hour:$minute $period';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject_id': subjectId,
        'title': title,
        'description': description,
        'deadline': deadline.toIso8601String(),
        'drive_url': driveUrl,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  factory AssignmentModel.fromMap(Map<String, dynamic> map) {
    return AssignmentModel(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled Assignment',
      description: map['description'] as String? ?? '',
      deadline: DateTime.parse(
          map['deadline'] as String? ?? DateTime.now().toIso8601String()),
      driveUrl: map['drive_url'] as String?,
      createdBy: map['created_by'] as String? ?? 'Admin',
      createdAt: DateTime.parse(
          map['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  AssignmentModel copyWith({
    String? id,
    String? subjectId,
    String? title,
    String? description,
    DateTime? deadline,
    String? driveUrl,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return AssignmentModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      driveUrl: driveUrl ?? this.driveUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Individual MCQ Question inside a Quiz
class QuizQuestionModel {
  final String id;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String? explanation;
  final String? hint;

  const QuizQuestionModel({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    this.explanation,
    this.hint,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'question': question,
        'options': options,
        'correct_option_index': correctOptionIndex,
        'explanation': explanation,
        'hint': hint,
      };

  factory QuizQuestionModel.fromMap(Map<String, dynamic> map) {
    final rawOptions = (map['options'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final safeOptions = rawOptions.isNotEmpty
        ? rawOptions
        : <String>['Option A', 'Option B', 'Option C', 'Option D'];
    final rawIdx = (map['correct_option_index'] as num?)?.toInt() ?? 0;
    return QuizQuestionModel(
      id: map['id']?.toString() ??
          'q_${DateTime.now().microsecondsSinceEpoch}',
      question: map['question']?.toString() ?? '',
      options: safeOptions,
      correctOptionIndex: rawIdx.clamp(0, safeOptions.length - 1),
      explanation: map['explanation'] as String?,
      hint: map['hint'] as String?,
    );
  }

  QuizQuestionModel copyWith({
    String? id,
    String? question,
    List<String>? options,
    int? correctOptionIndex,
    String? explanation,
    String? hint,
  }) {
    return QuizQuestionModel(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      explanation: explanation ?? this.explanation,
      hint: hint ?? this.hint,
    );
  }
}

/// Interactive MCQ Quiz / NotebookLM Imported Quiz
class QuizModel {
  static const String resourceUrlPrefix = 'ccquiz://';

  final String id;
  final String subjectId;
  final String title;
  final String description;
  final String? sourceUrl;
  final List<QuizQuestionModel> questions;
  final String createdBy;
  final DateTime createdAt;

  const QuizModel({
    required this.id,
    required this.subjectId,
    required this.title,
    this.description = '',
    this.sourceUrl,
    required this.questions,
    this.createdBy = 'Admin',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject_id': subjectId,
        'title': title,
        'description': description,
        'source_url': sourceUrl,
        'questions': questions.map((q) => q.toMap()).toList(),
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  factory QuizModel.fromMap(Map<String, dynamic> map) {
    final rawQuestions = (map['questions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(QuizQuestionModel.fromMap)
        .toList();
    return QuizModel(
      id: map['id']?.toString() ??
          'quiz_${DateTime.now().millisecondsSinceEpoch}',
      subjectId: map['subject_id']?.toString() ?? 's1',
      title: map['title']?.toString() ?? 'Untitled Quiz',
      description: map['description']?.toString() ?? '',
      sourceUrl: map['source_url'] as String?,
      questions: rawQuestions,
      createdBy: map['created_by']?.toString() ?? 'Admin',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  /// Encodes this quiz as a `public.resources` row so it syncs across all devices
  /// without requiring manual Supabase SQL migrations.
  Map<String, dynamic> toResourcePayload() {
    final encoded = base64Url.encode(utf8.encode(jsonEncode(toMap())));
    final y = createdAt.year.toString().padLeft(4, '0');
    final m = createdAt.month.toString().padLeft(2, '0');
    final d = createdAt.day.toString().padLeft(2, '0');
    return {
      'id': id,
      'subject_id': subjectId,
      'date': '$y-$m-$d',
      'uploader_id': null,
      'uploader_name': createdBy,
      'title': title,
      'type': 'pdf',
      'url': '$resourceUrlPrefix$encoded',
      'upvotes': questions.length,
      'cost_credits': 0,
      'is_approved': true,
    };
  }

  static QuizModel? tryFromResourceMap(Map<String, dynamic> map) {
    final url = map['url'] as String? ?? '';
    if (!url.startsWith(resourceUrlPrefix)) return null;
    try {
      final b64 = url.substring(resourceUrlPrefix.length).trim();
      final decodedJson = utf8.decode(base64Url.decode(b64));
      final payload = jsonDecode(decodedJson) as Map<String, dynamic>;
      return QuizModel.fromMap(payload);
    } catch (_) {
      return null;
    }
  }

  QuizModel copyWith({
    String? id,
    String? subjectId,
    String? title,
    String? description,
    String? sourceUrl,
    List<QuizQuestionModel>? questions,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return QuizModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      description: description ?? this.description,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      questions: questions ?? this.questions,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


