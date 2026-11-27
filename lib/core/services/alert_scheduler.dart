import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/uuid_util.dart';
import 'app_sound_service.dart';
import 'attendance_storage.dart';

enum AlertMode {
  ring('Ring', '🔔'),
  vibrate('Vibrate', '📳'),
  silent('Silent', '🔕');

  const AlertMode(this.label, this.emoji);
  final String label;
  final String emoji;

  AlertMode next() {
    switch (this) {
      case AlertMode.ring:
        return AlertMode.vibrate;
      case AlertMode.vibrate:
        return AlertMode.silent;
      case AlertMode.silent:
        return AlertMode.ring;
    }
  }
}

/// Represents a currently ringing or active lecture alarm to be displayed
/// on the Home Screen Meeting Panel.
class ActiveLectureAlarm {
  final String slotId;
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final String professor;
  final String room;
  final String timeRangeFormatted;
  final DateTime startsAt;
  final bool isUpdated;
  final String? topicCovered;
  final String? meetingUrl;
  final AlertMode mode;
  final bool isRinging;

  const ActiveLectureAlarm({
    required this.slotId,
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.professor,
    required this.room,
    required this.timeRangeFormatted,
    required this.startsAt,
    this.isUpdated = false,
    this.topicCovered,
    this.meetingUrl,
    this.mode = AlertMode.ring,
    this.isRinging = true,
  });

  ActiveLectureAlarm copyWith({
    bool? isRinging,
  }) {
    return ActiveLectureAlarm(
      slotId: slotId,
      subjectId: subjectId,
      subjectName: subjectName,
      subjectCode: subjectCode,
      professor: professor,
      room: room,
      timeRangeFormatted: timeRangeFormatted,
      startsAt: startsAt,
      isUpdated: isUpdated,
      topicCovered: topicCovered,
      meetingUrl: meetingUrl,
      mode: mode,
      isRinging: isRinging ?? this.isRinging,
    );
  }

  Map<String, dynamic> toPayloadMap() => {
        'type': 'lecture',
        'slotId': slotId,
        'subjectId': subjectId,
        'subjectName': subjectName,
        'subjectCode': subjectCode,
        'professor': professor,
        'room': room,
        'timeRangeFormatted': timeRangeFormatted,
        'startsAt': startsAt.toIso8601String(),
        'isUpdated': isUpdated,
        'topicCovered': topicCovered,
        'meetingUrl': meetingUrl,
        'mode': mode.name,
      };

  static ActiveLectureAlarm? fromPayloadString(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      if (payload.startsWith('{')) {
        final map = jsonDecode(payload) as Map<String, dynamic>;
        if (map['type'] != 'lecture') return null;
        return ActiveLectureAlarm(
          slotId: map['slotId'] as String? ?? '',
          subjectId: map['subjectId'] as String? ?? '',
          subjectName: map['subjectName'] as String? ?? 'Class Lecture',
          subjectCode: map['subjectCode'] as String? ?? 'CLASS',
          professor: map['professor'] as String? ?? 'Faculty',
          room: map['room'] as String? ?? 'TBD',
          timeRangeFormatted: map['timeRangeFormatted'] as String? ?? '',
          startsAt: DateTime.tryParse(map['startsAt'] as String? ?? '') ??
              DateTime.now(),
          isUpdated: map['isUpdated'] as bool? ?? false,
          topicCovered: map['topicCovered'] as String?,
          meetingUrl: map['meetingUrl'] as String?,
          mode: AlertMode.values.firstWhere(
            (m) => m.name == map['mode'],
            orElse: () => AlertMode.ring,
          ),
          isRinging: false,
        );
      }
    } catch (_) {}
    return null;
  }
}

/// Handles attendance & alarm action buttons from local lecture notifications.
Future<void> handleAttendanceNotificationAction(
  NotificationResponse response, {
  bool isBackground = false,
}) async {
  final actionId = response.actionId;
  if (actionId == 'mark_present' || actionId == 'mark_absent') {
    if (isBackground) {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        DartPluginRegistrant.ensureInitialized();
      } catch (_) {}
    }
    final parsed = ActiveLectureAlarm.fromPayloadString(response.payload);
    if (parsed != null && parsed.subjectId.isNotEmpty) {
      final slotKey = AttendanceStorage.buildSlotKey(
        date: parsed.startsAt,
        subjectId: parsed.subjectId,
        slotId: parsed.slotId,
      );
      await AttendanceStorage.recordFromNotification(
        subjectId: parsed.subjectId,
        isPresent: actionId == 'mark_present',
        slotKey: slotKey,
      );
    }
    await AlertScheduler.instance.stopActiveAlarm(dismissPanel: true);
    if (!isBackground) {
      AlertScheduler.instance.attendanceSyncVersion.value++;
    }
    return;
  }
  if (actionId == 'stop_alarm') {
    await AlertScheduler.instance.stopActiveAlarm();
  }
}

/// Background handler for notification action buttons (e.g. "Stop", "Present", "Absent").
/// Must be a top-level function so Android can invoke it while the app is killed.
@pragma('vm:entry-point')
Future<void> alarmNotificationBackgroundHandler(
    NotificationResponse response) async {
  await handleAttendanceNotificationAction(response, isBackground: true);
}

/// Real alarm-clock style lecture alerts with native audio stream playback
/// and live Home Screen Meeting Panel integration.
class AlertScheduler {
  AlertScheduler._();
  static final AlertScheduler instance = AlertScheduler._();

  static const String _prefAlertModeKey = 'kzynovex_alert_mode';
  static const String _prefLeadTimeKey = 'kzynovex_alert_lead_time_mins';
  static const String _prefBatteryPromptKey = 'kzynovex_battery_opt_prompted_v1';
  static const String _prefAlarmSoundKey = 'kzynovex_alarm_sound_preset_v1';
  static const String _prefNotifSoundKey = 'kzynovex_notif_sound_preset_v1';

  static const MethodChannel _powerChannel =
      MethodChannel('classconnect/alarm_power');

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Broadcasts the currently active/ringing lecture alarm so the Home Screen
  /// and MainShell can immediately bring up the Meeting Title Panel.
  final ValueNotifier<ActiveLectureAlarm?> activeAlarmNotifier =
      ValueNotifier<ActiveLectureAlarm?>(null);

  /// Incremented whenever foreground notification attendance action updates storage.
  final ValueNotifier<int> attendanceSyncVersion = ValueNotifier<int>(0);

  // v5 / v2 channels: separate per-preset channels so Android plays the chosen bundled audio.
  static const String channelRingId = 'lecture_alarm_ring_classic_v5';
  static const String channelVibrateId = 'lecture_alarm_vibrate_v4';
  static const String channelSilentId = 'class_alerts_silent_v2';
  static const String channelAssignmentId = 'assignment_reminders_bubble_pop_v2';

  static String ringChannelIdFor(String presetId) {
    final preset = AlarmSoundPreset.fromId(presetId);
    switch (preset) {
      case AlarmSoundPreset.oversimplifiedAlarm:
        return 'lecture_alarm_ring_oversimplified_v5';
      case AlarmSoundPreset.dreamcoreAlarm:
        return 'lecture_alarm_ring_dreamcore_v5';
      case AlarmSoundPreset.chiptuneAlarm:
        return 'lecture_alarm_ring_chiptune_v5';
      case AlarmSoundPreset.classicAlarm:
        return channelRingId;
    }
  }

  static String assignmentChannelIdFor(String presetId) {
    final preset = NotificationSoundPreset.fromId(presetId);
    switch (preset) {
      case NotificationSoundPreset.bubblePop:
        return 'assignment_reminders_bubble_pop_v2';
      case NotificationSoundPreset.interfaceChime:
        return 'assignment_reminders_interface_chime_v2';
      case NotificationSoundPreset.systemDefault:
        return 'assignment_reminders_default_v2';
    }
  }

  static const List<String> _legacyChannelIds = [
    'class_alerts_ring_v2',
    'class_alerts_vibrate_v2',
    'lecture_alarm_ring_v3',
    'lecture_alarm_vibrate_v3',
    'lecture_alarm_ring_v4',
    'assignment_reminders_v1',
  ];

  /// System default alarm ringtone (same sound as the Clock app).
  static const String _alarmSoundUri = 'content://settings/system/alarm_alert';

  /// Android FLAG_INSISTENT: repeat sound/vibration until dismissed.
  static const int _flagInsistent = 4;

  static const int _scheduleWindowDays = 14;
  static const int _maxLectureAlarms = 300;
  static const int _maxAssignmentReminders = 100;

  static const int _lectureIdBase = 100000;
  static const int _assignmentIdBase = 200000;
  static const int _testAlarmId = 999999;

  static final Int64List _ringPattern =
      Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1500]);
  static final Int64List _vibratePattern =
      Int64List.fromList([0, 800, 300, 800, 300, 1200]);

  bool _isInitialized = false;
  bool _canScheduleExact = true;

  /// In-app foreground timers for upcoming lectures so alarms fire with 100%
  /// precision and trigger the native alarm stream + Home Screen Meeting Panel.
  final List<Timer> _foregroundTimers = [];

  /// Tracks `(slotId|startsAtIso)` keys that have already fired an immediate
  /// update alert during this session so we don't repeat on re-sync.
  final Set<String> _firedImmediateKeys = {};

  /// Serializes sync calls so concurrent listeners can't cancel each other's alarms.
  Future<void> _syncQueue = Future<void>.value();

  // ---------------------------------------------------------------------------
  // INITIALIZATION & PERMISSIONS
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    _configureLocalTimeZone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            alarmNotificationBackgroundHandler,
      );

      final launchDetails =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchDetails?.notificationResponse != null) {
        _handleNotificationResponse(launchDetails!.notificationResponse!);
      }
    } catch (e) {
      debugPrint(
          'Local notifications platform not initialized (e.g. in test env): $e');
      _isInitialized = true;
      return;
    }

    final androidPlugin = _android;
    if (androidPlugin != null) {
      for (final legacy in _legacyChannelIds) {
        try {
          await androidPlugin.deleteNotificationChannel(channelId: legacy);
        } catch (_) {}
      }

      // 1. Ring channels: per-preset alarm channels on the ALARM audio stream.
      for (final preset in AlarmSoundPreset.values) {
        final AndroidNotificationSound sound = preset.rawResName != null
            ? RawResourceAndroidNotificationSound(preset.rawResName!)
            : const UriAndroidNotificationSound(_alarmSoundUri);
        final ringChannel = AndroidNotificationChannel(
          ringChannelIdFor(preset.id),
          'Lecture Alarms (${preset.name})',
          description: 'Rings like an alarm clock before each lecture.',
          importance: Importance.max,
          playSound: true,
          sound: sound,
          enableVibration: true,
          vibrationPattern: _ringPattern,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );
        await androidPlugin.createNotificationChannel(ringChannel);
      }

      // 2. Vibrate channel: haptics only.
      final vibrateChannel = AndroidNotificationChannel(
        channelVibrateId,
        'Lecture Alarms (Vibrate)',
        description: 'Vibration-only alarms before lectures.',
        importance: Importance.max,
        playSound: false,
        enableVibration: true,
        vibrationPattern: _vibratePattern,
      );

      // 3. Silent channel
      const silentChannel = AndroidNotificationChannel(
        channelSilentId,
        'Lecture Alerts (Silent)',
        description: 'Silent low-priority notifications.',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      );

      // 4. Assignment & reminder channels: per-preset notification sounds.
      for (final notifPreset in NotificationSoundPreset.values) {
        final assignmentChannel = AndroidNotificationChannel(
          assignmentChannelIdFor(notifPreset.id),
          'Assignments & Alerts (${notifPreset.name})',
          description: 'Reminders for assignments, upcoming quizzes & presentations.',
          importance: Importance.high,
          playSound: true,
          sound: notifPreset.rawResName != null
              ? RawResourceAndroidNotificationSound(notifPreset.rawResName!)
              : null,
          enableVibration: true,
        );
        await androidPlugin.createNotificationChannel(assignmentChannel);
      }

      await androidPlugin.createNotificationChannel(vibrateChannel);
      await androidPlugin.createNotificationChannel(silentChannel);

      try {
        _canScheduleExact =
            await androidPlugin.canScheduleExactNotifications() ?? true;
      } catch (_) {}
    }

    _isInitialized = true;
  }

  Future<void> _handleNotificationResponse(NotificationResponse response) async {
    debugPrint(
        'Notification response: action=${response.actionId}, payload=${response.payload}');
    if (response.actionId == 'stop_alarm' ||
        response.actionId == 'mark_present' ||
        response.actionId == 'mark_absent') {
      await handleAttendanceNotificationAction(response, isBackground: false);
      return;
    }
    final parsed = ActiveLectureAlarm.fromPayloadString(response.payload);
    if (parsed != null) {
      // Stop native audio loop when user taps the notification to open the panel,
      // but keep the Meeting Panel visible on the Home Screen.
      _stopNativeAudioOnly();
      activeAlarmNotifier.value = parsed.copyWith(isRinging: false);
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android {
    try {
      return _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
    } catch (_) {
      return null;
    }
  }

  void _configureLocalTimeZone() {
    try {
      final now = DateTime.now();
      final timeZoneName = now.timeZoneName;
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        return;
      } catch (_) {}

      final currentOffset = now.timeZoneOffset;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == currentOffset) {
          tz.setLocalLocation(loc);
          return;
        }
      }
      tz.setLocalLocation(tz.UTC);
    } catch (e) {
      debugPrint('Error configuring timezone: $e');
      try {
        tz.setLocalLocation(tz.UTC);
      } catch (_) {}
    }
  }

  tz.Location get _safeLocation {
    try {
      return tz.local;
    } catch (_) {
      try {
        tz.initializeTimeZones();
        tz.setLocalLocation(tz.UTC);
        return tz.UTC;
      } catch (_) {
        return tz.getLocation('UTC');
      }
    }
  }

  /// Starts native Android alarm stream playback (`USAGE_ALARM`) + vibration.
  Future<void> _startNativeAlarm(AlertMode mode) async {
    if (mode == AlertMode.silent) return;
    try {
      final soundPreset = await getSavedAlarmSoundPreset();
      await _powerChannel.invokeMethod('startAlarmRinging', {
        'playSound': mode == AlertMode.ring,
        'vibrate': true,
        'soundPreset': soundPreset,
        'previewOnly': false,
      });
    } catch (e) {
      debugPrint('Native alarm start skipped: $e');
    }
  }

  /// Plays a 3.5-second preview of the given alarm sound preset from the Cosmetics Store.
  Future<void> previewAlarmSound(String soundPresetId) async {
    try {
      await _powerChannel.invokeMethod('startAlarmRinging', {
        'playSound': true,
        'vibrate': true,
        'soundPreset': soundPresetId,
        'previewOnly': true,
      });
    } catch (e) {
      debugPrint('Alarm sound preview skipped: $e');
    }
  }

  /// Plays a preview of a bundled or system notification sound preset.
  Future<void> previewNotificationSound(String soundPresetId) async {
    await AppSoundService.instance.previewNotificationSound(soundPresetId);
  }

  Future<void> _stopNativeAudioOnly() async {
    try {
      await _powerChannel.invokeMethod('stopAlarmRinging');
    } catch (_) {}
  }

  /// Stops native ringing/vibration, dismisses active alarm notifications,
  /// and clears or silences the Home Screen Meeting Panel.
  Future<void> stopActiveAlarm({bool dismissPanel = true}) async {
    await _stopNativeAudioOnly();
    try {
      await _notificationsPlugin.cancel(id: _testAlarmId);
    } catch (_) {}
    if (dismissPanel) {
      activeAlarmNotifier.value = null;
    } else if (activeAlarmNotifier.value != null) {
      activeAlarmNotifier.value =
          activeAlarmNotifier.value!.copyWith(isRinging: false);
    }
  }

  /// Triggers an active lecture alarm right now: shows the Home Screen Meeting
  /// Panel, starts native alarm stream ringing, and posts the OS notification.
  Future<void> triggerLectureAlarm(
    ActiveLectureAlarm alarm, {
    int? notificationId,
    String? customTitle,
    String? customBody,
  }) async {
    activeAlarmNotifier.value = alarm;
    await _startNativeAlarm(alarm.mode);

    if (alarm.mode != AlertMode.silent) {
      final soundPreset = await getSavedAlarmSoundPreset();
      final details = _alarmDetails(alarm.mode, soundPreset: soundPreset);
      final title = customTitle ??
          '⏰ ${alarm.subjectName} (${alarm.subjectCode})';
      final body = customBody ??
          (alarm.isUpdated
              ? 'UPDATED: ${alarm.timeRangeFormatted} • ${alarm.room} • ${alarm.professor}'
              : '${alarm.timeRangeFormatted} in ${alarm.room} • ${alarm.professor}');
      try {
        await _notificationsPlugin.show(
          id: notificationId ?? _testAlarmId,
          title: title,
          body: body,
          notificationDetails: details,
          payload: jsonEncode(alarm.toPayloadMap()),
        );
      } catch (e) {
        debugPrint('Error showing triggered alarm notification: $e');
      }
    }
  }

  /// Requests everything a lecture alarm needs to fire with the app closed:
  /// notification permission, exact-alarm permission and (once, or when
  /// [forceBatteryPrompt]) an exemption from battery optimization.
  Future<bool> ensureAlarmPermissions({bool forceBatteryPrompt = false}) async {
    if (!_isInitialized) await initialize();
    final androidPlugin = _android;
    if (androidPlugin == null) return true;

    bool notifGranted = true;
    try {
      notifGranted =
          await androidPlugin.requestNotificationsPermission() ?? true;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }

    try {
      _canScheduleExact =
          await androidPlugin.canScheduleExactNotifications() ?? true;
      if (!_canScheduleExact) {
        await androidPlugin.requestExactAlarmsPermission();
        _canScheduleExact =
            await androidPlugin.canScheduleExactNotifications() ?? false;
      }
    } catch (e) {
      debugPrint('Exact alarm permission check failed: $e');
    }

    try {
      await androidPlugin.requestFullScreenIntentPermission();
    } catch (_) {}

    await _maybeRequestBatteryExemption(force: forceBatteryPrompt);

    return notifGranted && _canScheduleExact;
  }

  /// Backwards-compatible alias used by the Profile screen button.
  Future<bool> requestPermissions() =>
      ensureAlarmPermissions(forceBatteryPrompt: true);

  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _powerChannel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _maybeRequestBatteryExemption({bool force = false}) async {
    try {
      if (await isIgnoringBatteryOptimizations()) return;
      final prefs = await SharedPreferences.getInstance();
      if (!force && (prefs.getBool(_prefBatteryPromptKey) ?? false)) return;
      await prefs.setBool(_prefBatteryPromptKey, true);
      await _powerChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('Battery optimization prompt skipped: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // PREFERENCES
  // ---------------------------------------------------------------------------

  Future<AlertMode> getSavedAlertMode() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_prefAlertModeKey);
    if (val == AlertMode.vibrate.name) return AlertMode.vibrate;
    if (val == AlertMode.silent.name) return AlertMode.silent;
    return AlertMode.ring;
  }

  Future<void> saveAlertMode(AlertMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefAlertModeKey, mode.name);
  }

  Future<int> getSavedLeadTimeMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefLeadTimeKey) ?? 10;
  }

  Future<void> saveLeadTimeMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefLeadTimeKey, minutes);
  }

  Future<String> getSavedAlarmSoundPreset() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefAlarmSoundKey) ?? 'classic_alarm';
  }

  Future<void> saveAlarmSoundPreset(String presetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefAlarmSoundKey, presetId);
  }

  Future<String> getSavedNotificationSoundPreset() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefNotifSoundKey) ??
        NotificationSoundPreset.bubblePop.id;
  }

  Future<void> saveNotificationSoundPreset(String presetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefNotifSoundKey, presetId);
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATION DETAILS
  // ---------------------------------------------------------------------------

  NotificationDetails _alarmDetails(
    AlertMode mode, {
    String soundPreset = 'classic_alarm',
  }) {
    final isRing = mode == AlertMode.ring;
    final preset = AlarmSoundPreset.fromId(soundPreset);
    final AndroidNotificationSound? ringSound = !isRing
        ? null
        : (preset.rawResName != null
            ? RawResourceAndroidNotificationSound(preset.rawResName!)
            : const UriAndroidNotificationSound(_alarmSoundUri));

    final android = AndroidNotificationDetails(
      isRing ? ringChannelIdFor(preset.id) : channelVibrateId,
      isRing
          ? 'Lecture Alarms (${preset.name})'
          : 'Lecture Alarms (Vibrate)',
      channelDescription: 'Alarm-clock style alerts before lectures begin',
      importance: Importance.max,
      priority: Priority.max,
      playSound: isRing,
      sound: ringSound,
      enableVibration: true,
      vibrationPattern: isRing ? _ringPattern : _vibratePattern,
      audioAttributesUsage: isRing
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      additionalFlags: Int32List.fromList(<int>[_flagInsistent]),
      timeoutAfter: 60000, // stop ringing automatically after 1 minute
      autoCancel: true,
      ticker: 'Lecture alarm',
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'stop_alarm',
          'Stop Ringing',
          cancelNotification: true,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'mark_present',
          'Present ✓',
          cancelNotification: true,
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          'mark_absent',
          'Absent ✗',
          cancelNotification: true,
          showsUserInterface: false,
        ),
      ],
    );
    return NotificationDetails(android: android);
  }

  NotificationDetails _assignmentDetailsFor(String notifSoundPresetId) {
    final preset = NotificationSoundPreset.fromId(notifSoundPresetId);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        assignmentChannelIdFor(preset.id),
        'Assignments & Alerts (${preset.name})',
        channelDescription:
            'Reminders before admin-posted assignment deadlines.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: preset.rawResName != null
            ? RawResourceAndroidNotificationSound(preset.rawResName!)
            : null,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
      ),
    );
  }

  AndroidScheduleMode get _scheduleMode => _canScheduleExact
      ? AndroidScheduleMode.alarmClock
      : AndroidScheduleMode.inexactAllowWhileIdle;

  // ---------------------------------------------------------------------------
  // OCCURRENCE COMPUTATION
  // ---------------------------------------------------------------------------

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _idsMatch(String a, String b) =>
      a == b || UuidUtil.fromString(a) == UuidUtil.fromString(b);

  static DateTime? _atTime(DateTime day, String? hhmm) {
    final norm = Formatters.normalizeOptionalTime(hhmm);
    if (norm == null) return null;
    final parts = norm.split(':');
    final h = int.tryParse(parts[0]);
    final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  /// Computes the next upcoming DateTime for a weekday slot (1 = Monday ... 7 = Sunday)
  static DateTime getNextSlotDateTime({
    required int dayOfWeek,
    required String startTime,
    required int leadTimeMinutes,
  }) {
    final now = DateTime.now();
    final norm = Formatters.normalizeTime(startTime);
    final parts = (norm.isNotEmpty ? norm : '09:00').split(':');
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    final daysDifference = (dayOfWeek - now.weekday) % 7;
    var candidate = DateTime(
      now.year,
      now.month,
      now.day + daysDifference,
      hour,
      minute,
    ).subtract(Duration(minutes: leadTimeMinutes));

    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  /// Builds every concrete lecture occurrence in the scheduling window with
  /// admin overrides (cancel / late / room change / day move) applied.
  @visibleForTesting
  static List<LectureOccurrence> buildOccurrencesForTesting({
    required List<TimetableSlotModel> slots,
    required List<DailyOverrideModel> overrides,
    int windowDays = _scheduleWindowDays,
    DateTime? referenceNow,
  }) {
    return _buildOccurrences(
      slots: slots,
      overrides: overrides,
      windowDays: windowDays,
      referenceNow: referenceNow,
    );
  }

  static List<LectureOccurrence> _buildOccurrences({
    required List<TimetableSlotModel> slots,
    required List<DailyOverrideModel> overrides,
    int windowDays = _scheduleWindowDays,
    DateTime? referenceNow,
  }) {
    final now = referenceNow ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final approved = overrides.where((o) => o.isApproved).toList();
    final result = <LectureOccurrence>[];
    final seen = <String>{};

    String key(String slotId, DateTime d) =>
        '${UuidUtil.fromString(slotId)}|${d.year}-${d.month}-${d.day}';

    DailyOverrideModel? overrideFor(TimetableSlotModel slot, DateTime day) {
      for (final o in approved) {
        if (!_idsMatch(o.slotId, slot.id)) continue;
        if (_sameDay(o.date, day)) return o;
        if (o.status == OverrideStatus.rescheduled &&
            o.rescheduledDate != null &&
            _sameDay(o.rescheduledDate!, day)) {
          return o;
        }
      }
      return null;
    }

    // 1. Regular weekly occurrences
    for (int offset = 0; offset < windowDays; offset++) {
      final day = today.add(Duration(days: offset));
      for (final slot in slots.where((s) => s.dayOfWeek == day.weekday)) {
        final ov = overrideFor(slot, day);
        if (ov != null) {
          if (ov.status == OverrideStatus.cancelled) {
            seen.add(key(slot.id, day));
            continue;
          }
          if (ov.status == OverrideStatus.rescheduled &&
              ov.rescheduledDate != null &&
              !_sameDay(ov.rescheduledDate!, day)) {
            // Moved away from its regular day to another day: handled in step 2.
            seen.add(key(slot.id, day));
            continue;
          }
        }
        final isChanged = ov != null && ov.status == OverrideStatus.rescheduled;
        final effectiveStartStr = (isChanged &&
                ov.actualStartTime != null &&
                ov.actualStartTime!.trim().isNotEmpty)
            ? Formatters.normalizeTime(ov.actualStartTime)
            : Formatters.normalizeTime(slot.startTime);
        final effectiveEndStr = (isChanged &&
                ov.actualEndTime != null &&
                ov.actualEndTime!.trim().isNotEmpty)
            ? Formatters.normalizeTime(ov.actualEndTime)
            : Formatters.normalizeTime(slot.endTime);

        final start = _atTime(day, effectiveStartStr);
        if (start == null) continue;
        final room = (isChanged &&
                ov.actualRoom != null &&
                ov.actualRoom!.trim().isNotEmpty)
            ? ov.actualRoom!.trim()
            : slot.defaultRoom;
        final meetingUrl =
            (ov != null && ov.hasMeetingUrl) ? ov.effectiveMeetingUrl : slot.effectiveMeetingUrl;
        seen.add(key(slot.id, day));
        result.add(LectureOccurrence(
          slot: slot,
          startsAt: start,
          startTimeStr: effectiveStartStr,
          endTimeStr: effectiveEndStr,
          room: room,
          topicCovered: ov?.topicCovered,
          meetingUrl: meetingUrl,
          isChanged: isChanged &&
              (effectiveStartStr != Formatters.normalizeTime(slot.startTime) ||
                  effectiveEndStr != Formatters.normalizeTime(slot.endTime) ||
                  room != slot.defaultRoom ||
                  ov.rescheduledDate != null),
        ));
      }
    }

    // 2. Lectures moved to a different day (or overridden on a specific date) inside the window
    final windowEnd = today.add(Duration(days: windowDays));
    for (final ov in approved) {
      if (ov.status != OverrideStatus.rescheduled) {
        continue;
      }
      final rawTarget = ov.rescheduledDate ?? ov.date;
      final target = DateTime(rawTarget.year, rawTarget.month, rawTarget.day);
      if (target.isBefore(today) || !target.isBefore(windowEnd)) continue;

      TimetableSlotModel? slot;
      for (final s in slots) {
        if (_idsMatch(s.id, ov.slotId)) {
          slot = s;
          break;
        }
      }
      if (slot == null) continue;
      if (seen.contains(key(slot.id, target))) continue;

      final effectiveStartStr = (ov.actualStartTime != null &&
              ov.actualStartTime!.trim().isNotEmpty)
          ? Formatters.normalizeTime(ov.actualStartTime)
          : Formatters.normalizeTime(slot.startTime);
      final effectiveEndStr = (ov.actualEndTime != null &&
              ov.actualEndTime!.trim().isNotEmpty)
          ? Formatters.normalizeTime(ov.actualEndTime)
          : Formatters.normalizeTime(slot.endTime);

      final start = _atTime(target, effectiveStartStr);
      if (start == null) continue;
      seen.add(key(slot.id, target));
      result.add(LectureOccurrence(
        slot: slot,
        startsAt: start,
        startTimeStr: effectiveStartStr,
        endTimeStr: effectiveEndStr,
        room: (ov.actualRoom != null && ov.actualRoom!.trim().isNotEmpty)
            ? ov.actualRoom!.trim()
            : slot.defaultRoom,
        topicCovered: ov.topicCovered,
        meetingUrl: ov.hasMeetingUrl ? ov.effectiveMeetingUrl : slot.effectiveMeetingUrl,
        isChanged: true,
      ));
    }

    result.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return result;
  }

  // ---------------------------------------------------------------------------
  // SYNC
  // ---------------------------------------------------------------------------

  /// Re-schedules every lecture alarm (and assignment reminder) from scratch.
  /// Safe to call often: calls are serialized and only touch this app's alarms.
  Future<int> syncAllTimetableAlerts({
    required List<TimetableSlotModel> slots,
    required Map<String, SubjectModel> subjectMap,
    required AlertMode mode,
    int? leadTimeMinutes,
    List<DailyOverrideModel> overrides = const [],
    List<AssignmentModel> assignments = const [],
    Set<String> completedAssignmentIds = const {},
  }) {
    final completer = Completer<int>();
    _syncQueue = _syncQueue.then((_) async {
      try {
        completer.complete(await _doSync(
          slots: slots,
          subjectMap: subjectMap,
          mode: mode,
          leadTimeMinutes: leadTimeMinutes,
          overrides: overrides,
          assignments: assignments,
          completedAssignmentIds: completedAssignmentIds,
        ));
      } catch (e, st) {
        debugPrint('AlertScheduler sync failed: $e');
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  SubjectModel? _lookupSubject(
      Map<String, SubjectModel> subjectMap, String subjectId) {
    final direct = subjectMap[subjectId];
    if (direct != null) return direct;
    final target = UuidUtil.fromString(subjectId);
    for (final s in subjectMap.values) {
      if (UuidUtil.fromString(s.id) == target) return s;
    }
    return null;
  }

  void _clearForegroundTimers() {
    for (final t in _foregroundTimers) {
      t.cancel();
    }
    _foregroundTimers.clear();
  }

  Future<int> _doSync({
    required List<TimetableSlotModel> slots,
    required Map<String, SubjectModel> subjectMap,
    required AlertMode mode,
    int? leadTimeMinutes,
    required List<DailyOverrideModel> overrides,
    required List<AssignmentModel> assignments,
    required Set<String> completedAssignmentIds,
  }) async {
    if (!_isInitialized) await initialize();
    try {
      _canScheduleExact =
          await _android?.canScheduleExactNotifications() ?? _canScheduleExact;
    } catch (_) {}

    _clearForegroundTimers();
    final leadTime = leadTimeMinutes ?? await getSavedLeadTimeMinutes();
    final alarmSoundPreset = await getSavedAlarmSoundPreset();
    final notifSoundPreset = await getSavedNotificationSoundPreset();
    await _cancelScheduled();

    final now = DateTime.now();
    int scheduledCount = 0;

    // ---- Lecture alarms ----
    if (mode != AlertMode.silent && slots.isNotEmpty) {
      final details = _alarmDetails(mode, soundPreset: alarmSoundPreset);
      final occurrences =
          _buildOccurrences(slots: slots, overrides: overrides);

      int index = 0;
      for (final occ in occurrences) {
        if (index >= _maxLectureAlarms) break;
        if (!occ.startsAt.isAfter(now)) continue;

        final subject = _lookupSubject(subjectMap, occ.slot.subjectId);
        final subjectName = subject?.name ?? 'Class Lecture';
        final subjectCode = subject?.code ?? 'CLASS';
        final professor = subject?.professor ?? 'Faculty';
        final timeRangeFormatted = Formatters.formatTimeRangeString(
            occ.startTimeStr, occ.endTimeStr);
        final startLabel = _formatTime(occ.startsAt);

        final alarmModel = ActiveLectureAlarm(
          slotId: occ.slot.id,
          subjectId: occ.slot.subjectId,
          subjectName: subjectName,
          subjectCode: subjectCode,
          professor: professor,
          room: occ.room,
          timeRangeFormatted: timeRangeFormatted,
          startsAt: occ.startsAt,
          isUpdated: occ.isChanged,
          topicCovered: occ.topicCovered,
          meetingUrl: occ.meetingUrl,
          mode: mode,
        );
        final payloadJson = jsonEncode(alarmModel.toPayloadMap());

        // 1. Pre-lecture reminder at (startsAt - leadTime)
        final preAlertAt = occ.startsAt.subtract(Duration(minutes: leadTime));
        if (leadTime > 0 && preAlertAt.isAfter(now)) {
          final notifId = _lectureIdBase + index;
          final title = '⏰ $subjectName starts in $leadTime min';
          final body = occ.isChanged
              ? 'UPDATED: $startLabel • ${occ.room}. Schedule updated by admin.'
              : 'Starts at $startLabel in ${occ.room} ($professor).';
          try {
            await _notificationsPlugin.zonedSchedule(
              id: notifId,
              title: title,
              body: body,
              scheduledDate: tz.TZDateTime.from(preAlertAt, _safeLocation),
              notificationDetails: details,
              androidScheduleMode: _scheduleMode,
              payload: payloadJson,
            );
            _scheduleForegroundTimer(
              fireAt: preAlertAt,
              alarm: alarmModel,
              notificationId: notifId,
              title: title,
              body: body,
            );
            index++;
            scheduledCount++;
          } catch (e) {
            debugPrint(
                'Error scheduling pre-alarm for $subjectName at $preAlertAt: $e');
          }
        } else if (occ.isChanged &&
            leadTime > 0 &&
            !preAlertAt.isAfter(now) &&
            occ.startsAt.difference(now).inMinutes <= leadTime) {
          // Admin just rescheduled a meeting to start within the lead-time window!
          final immKey =
              '${UuidUtil.fromString(occ.slot.id)}|${occ.startsAt.toIso8601String()}';
          if (!_firedImmediateKeys.contains(immKey)) {
            _firedImmediateKeys.add(immKey);
            final minsLeft =
                occ.startsAt.difference(now).inMinutes.clamp(1, leadTime);
            final fireAt = now.add(const Duration(seconds: 2));
            final notifId = _lectureIdBase + index;
            final title = '⏰ UPDATED: $subjectName in $minsLeft min';
            final body =
                'Meeting time changed to $startLabel • ${occ.room} ($professor).';
            _scheduleForegroundTimer(
              fireAt: fireAt,
              alarm: alarmModel,
              notificationId: notifId,
              title: title,
              body: body,
            );
            index++;
            scheduledCount++;
          }
        }

        // 2. Exact meeting start-time alarm at `occ.startsAt`
        if (index < _maxLectureAlarms) {
          final startNotifId = _lectureIdBase + index;
          final startTitle = '🔔 $subjectName ($subjectCode) is starting now!';
          final startBody = occ.isChanged
              ? 'UPDATED TIME: $timeRangeFormatted • Room ${occ.room} • $professor'
              : '$timeRangeFormatted • Room ${occ.room} • $professor';
          try {
            await _notificationsPlugin.zonedSchedule(
              id: startNotifId,
              title: startTitle,
              body: startBody,
              scheduledDate: tz.TZDateTime.from(occ.startsAt, _safeLocation),
              notificationDetails: details,
              androidScheduleMode: _scheduleMode,
              payload: payloadJson,
            );
            _scheduleForegroundTimer(
              fireAt: occ.startsAt,
              alarm: alarmModel,
              notificationId: startNotifId,
              title: startTitle,
              body: startBody,
            );
            index++;
            scheduledCount++;
          } catch (e) {
            debugPrint(
                'Error scheduling start alarm for $subjectName at ${occ.startsAt}: $e');
          }
        }
      }
      debugPrint(
          'AlertScheduler: scheduled $scheduledCount lecture alarms (mode: ${mode.name}, exact: $_canScheduleExact).');
    } else {
      debugPrint(
          'AlertScheduler: silent mode or no slots, lecture alarms cleared.');
    }

    // ---- Assignment, Quiz & Presentation reminders (independent of ring mode) ----
    int aIndex = 0;
    final assignmentDetails = _assignmentDetailsFor(notifSoundPreset);
    final pending = assignments
        .where((a) =>
            !completedAssignmentIds.contains(a.id) && a.deadline.isAfter(now))
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    for (final a in pending) {
      final subjectCode =
          _lookupSubject(subjectMap, a.subjectId)?.code ?? a.category.label;
      final reminders = <Duration, String>{
        const Duration(hours: 24): 'tomorrow',
        const Duration(hours: 2): 'in 2 hours',
      };
      for (final entry in reminders.entries) {
        if (aIndex >= _maxAssignmentReminders) break;
        final at = a.deadline.toLocal().subtract(entry.key);
        if (!at.isAfter(now)) continue;

        final String notifTitle;
        final String notifBody;
        switch (a.category) {
          case TaskCategory.assignment:
            final dueWord = entry.key == const Duration(hours: 24)
                ? 'due tomorrow'
                : 'due in 2 hours';
            notifTitle = '📝 $subjectCode Assignment: ${a.title} $dueWord';
            notifBody =
                'Deadline ${a.formattedDeadline}. Mark it done in Tasks once submitted.';
            break;
          case TaskCategory.quiz:
            notifTitle = '🧠 $subjectCode Quiz: ${a.title} ${entry.value}';
            notifBody =
                'Upcoming quiz at ${a.formattedDeadline}. Review your notes in Academic Vault!';
            break;
          case TaskCategory.presentation:
            notifTitle =
                '🎤 $subjectCode Presentation: ${a.title} ${entry.value}';
            notifBody =
                'Scheduled for ${a.formattedDeadline}. Finalize your slides & talking points!';
            break;
        }

        try {
          await _notificationsPlugin.zonedSchedule(
            id: _assignmentIdBase + aIndex,
            title: notifTitle,
            body: notifBody,
            scheduledDate: tz.TZDateTime.from(at, _safeLocation),
            notificationDetails: assignmentDetails,
            androidScheduleMode: _scheduleMode,
            payload: 'assignment:${a.id}',
          );
          aIndex++;
        } catch (e) {
          debugPrint('Error scheduling ${a.category.name} reminder: $e');
        }
      }
    }

    return scheduledCount;
  }

  void _scheduleForegroundTimer({
    required DateTime fireAt,
    required ActiveLectureAlarm alarm,
    required int notificationId,
    required String title,
    required String body,
  }) {
    final delay = fireAt.difference(DateTime.now());
    if (delay.isNegative || delay > const Duration(hours: 24)) return;
    _foregroundTimers.add(
      Timer(delay, () {
        triggerLectureAlarm(
          alarm,
          notificationId: notificationId,
          customTitle: title,
          customBody: body,
        );
      }),
    );
  }

  /// Cancels every pending alarm/reminder this scheduler created, without
  /// touching currently displayed notifications.
  Future<void> _cancelScheduled() async {
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id == _testAlarmId) continue;
        await _notificationsPlugin.cancel(id: p.id);
      }
    } catch (e) {
      debugPrint('AlertScheduler pending cancel failed, falling back: $e');
      try {
        await cancelAll();
      } catch (_) {}
    }
  }

  static String _formatTime(DateTime t) {
    final h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  // ---------------------------------------------------------------------------
  // TESTING
  // ---------------------------------------------------------------------------

  /// Fires the real alarm (same channel, sound, native audio stream, and
  /// Home Screen Meeting Panel as scheduled ones).
  Future<void> testAlarmNow({
    required AlertMode mode,
    String? subjectName,
    String? subjectCode,
    String? professor,
    String? room,
    String? timeRangeFormatted,
    int delaySeconds = 0,
  }) async {
    if (!_isInitialized) await initialize();
    final effectiveMode = mode == AlertMode.silent ? AlertMode.ring : mode;
    final now = DateTime.now();
    final start = now.add(Duration(seconds: delaySeconds));
    final alarm = ActiveLectureAlarm(
      slotId: 'test-alarm-slot',
      subjectId: 'test-subject',
      subjectName: subjectName ?? 'Software Engineering Lecture',
      subjectCode: subjectCode ?? 'SE-301',
      professor: professor ?? 'Course Instructor',
      room: room ?? 'Main Lecture Hall',
      timeRangeFormatted: timeRangeFormatted ??
          '${Formatters.time(start)} - ${Formatters.time(start.add(const Duration(minutes: 60)))}',
      startsAt: start,
      isUpdated: true,
      topicCovered: 'Live Alarm & Home Screen Panel Verification',
      mode: effectiveMode,
    );

    if (delaySeconds <= 0) {
      await triggerLectureAlarm(
        alarm,
        notificationId: _testAlarmId,
        customTitle: effectiveMode == AlertMode.ring
            ? '⏰ ${alarm.subjectName} (Ring)'
            : '📳 ${alarm.subjectName} (Vibrate)',
        customBody:
            '${alarm.timeRangeFormatted} • ${alarm.room}. Tap Stop Ringing to silence.',
      );
      return;
    }

    final alarmSoundPreset = await getSavedAlarmSoundPreset();
    final details = _alarmDetails(effectiveMode, soundPreset: alarmSoundPreset);
    final title = effectiveMode == AlertMode.ring
        ? '⏰ ${alarm.subjectName} (Ring)'
        : '📳 ${alarm.subjectName} (Vibrate)';
    final body =
        '${alarm.timeRangeFormatted} • ${alarm.room}. Tap Stop Ringing to silence.';

    await _notificationsPlugin.zonedSchedule(
      id: _testAlarmId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(start, _safeLocation),
      notificationDetails: details,
      androidScheduleMode: _scheduleMode,
      payload: jsonEncode(alarm.toPayloadMap()),
    );

    _scheduleForegroundTimer(
      fireAt: start,
      alarm: alarm,
      notificationId: _testAlarmId,
      title: title,
      body: body,
    );
  }

  Future<void> scheduleLectureAlert({
    required int notificationId,
    required String subjectName,
    required String room,
    required String timeFormatted,
    required AlertMode mode,
  }) async {
    await testAlarmNow(
      mode: mode,
      subjectName: subjectName,
      room: room,
      timeRangeFormatted: timeFormatted,
    );
  }

  Future<void> cancelAll() async {
    _clearForegroundTimers();
    await _stopNativeAudioOnly();
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('AlertScheduler cancelAll: $e');
    }
  }
}

class LectureOccurrence {
  final TimetableSlotModel slot;
  final DateTime startsAt;
  final String startTimeStr;
  final String endTimeStr;
  final String room;
  final String? topicCovered;
  final String? meetingUrl;
  final bool isChanged;

  const LectureOccurrence({
    required this.slot,
    required this.startsAt,
    required this.startTimeStr,
    required this.endTimeStr,
    required this.room,
    this.topicCovered,
    this.meetingUrl,
    required this.isChanged,
  });
}
