import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../models/models.dart';

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

class AlertScheduler {
  AlertScheduler._();
  static final AlertScheduler instance = AlertScheduler._();

  static const String _prefAlertModeKey = 'kzynovex_alert_mode';
  static const String _prefLeadTimeKey = 'kzynovex_alert_lead_time_mins';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelRingId = 'class_alerts_ring_v2';
  static const String channelVibrateId = 'class_alerts_vibrate_v2';
  static const String channelSilentId = 'class_alerts_silent_v2';

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    _configureLocalTimeZone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // 1. Ring Channel (High priority alarm sound + strong vibration)
      final ringPattern =
          Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1500]);
      final ringChannel = AndroidNotificationChannel(
        channelRingId,
        'Lecture Alarms (Ring & Vibrate)',
        description: 'Audible high-priority alarms before upcoming lectures.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: ringPattern,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

      // 2. Vibrate Channel (Haptics only, silent)
      final vibratePattern =
          Int64List.fromList([0, 800, 300, 800, 300, 1200]);
      final vibrateChannel = AndroidNotificationChannel(
        channelVibrateId,
        'Lecture Alerts (Vibrate)',
        description: 'Vibration-only notifications before classes.',
        importance: Importance.high,
        playSound: false,
        enableVibration: true,
        vibrationPattern: vibratePattern,
      );

      // 3. Silent Channel
      const silentChannel = AndroidNotificationChannel(
        channelSilentId,
        'Lecture Alerts (Silent)',
        description: 'Silent low-priority notifications.',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      );

      await androidPlugin.createNotificationChannel(ringChannel);
      await androidPlugin.createNotificationChannel(vibrateChannel);
      await androidPlugin.createNotificationChannel(silentChannel);

      await requestPermissions();
    }

    _isInitialized = true;
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

  Future<bool> requestPermissions() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final notifGranted =
          await androidPlugin.requestNotificationsPermission() ?? false;
      final alarmGranted =
          await androidPlugin.requestExactAlarmsPermission() ?? false;
      return notifGranted && alarmGranted;
    }
    return true;
  }

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

  /// Computes the next upcoming DateTime for a weekday slot (1 = Monday ... 7 = Sunday)
  static DateTime getNextSlotDateTime({
    required int dayOfWeek,
    required String startTime,
    required int leadTimeMinutes,
  }) {
    final now = DateTime.now();
    final parts = startTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    int daysDifference = (dayOfWeek - now.weekday) % 7;
    var candidate = DateTime(
      now.year,
      now.month,
      now.day + daysDifference,
      hour,
      minute,
    ).subtract(Duration(minutes: leadTimeMinutes));

    // If candidate alert time has already passed today, schedule for next week
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  /// Synchronizes exact Android AlarmClock notifications for all weekly slots.
  /// Works even when the app is completely closed or screen is off.
  Future<int> syncAllTimetableAlerts({
    required List<TimetableSlotModel> slots,
    required Map<String, SubjectModel> subjectMap,
    required AlertMode mode,
    int? leadTimeMinutes,
  }) async {
    if (!_isInitialized) await initialize();

    final leadTime = leadTimeMinutes ?? await getSavedLeadTimeMinutes();

    // 1. Silent mode cancels all alarms
    if (mode == AlertMode.silent || slots.isEmpty) {
      await cancelAll();
      debugPrint('AlertScheduler: Silent mode active. All lecture alarms cleared.');
      return 0;
    }

    // 2. Clear existing alarms before re-scheduling to prevent duplicates
    await cancelAll();

    final isRing = mode == AlertMode.ring;
    final channelId = isRing ? channelRingId : channelVibrateId;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      isRing ? 'Lecture Alarms (Ring & Vibrate)' : 'Lecture Alerts (Vibrate)',
      channelDescription: 'Audible and vibrating alarms before lectures begin',
      importance: isRing ? Importance.max : Importance.high,
      priority: Priority.max,
      playSound: isRing,
      enableVibration: true,
      vibrationPattern: isRing
          ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1500])
          : Int64List.fromList([0, 800, 300, 800, 300, 1200]),
      audioAttributesUsage:
          isRing ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    int scheduledCount = 0;

    for (final slot in slots) {
      final subject = subjectMap[slot.subjectId];
      final subjectName = subject?.name ?? 'Class Lecture';
      final alertDateTime = getNextSlotDateTime(
        dayOfWeek: slot.dayOfWeek,
        startTime: slot.startTime,
        leadTimeMinutes: leadTime,
      );

      final now = DateTime.now();
      if (alertDateTime.isAfter(now)) {
        final tzAlertTime = tz.TZDateTime.from(alertDateTime, _safeLocation);
        final notificationId = (slot.id.hashCode & 0x7FFFFFFF) % 100000;

        try {
          await _notificationsPlugin.zonedSchedule(
            id: notificationId,
            title: isRing
                ? '⏰ CLASS ALARM: $subjectName'
                : '📳 Class in $leadTime mins: $subjectName',
            body:
                'Starts at ${slot.formattedStartTime} in ${slot.defaultRoom}. Don\'t be late!',
            scheduledDate: tzAlertTime,
            notificationDetails: notificationDetails,
            androidScheduleMode: AndroidScheduleMode.alarmClock,
          );
          scheduledCount++;
          debugPrint(
              'AlertScheduler: Scheduled alarm for $subjectName at $alertDateTime (id: $notificationId)');
        } catch (e) {
          debugPrint('Error scheduling exact alarm for $subjectName: $e');
        }
      }
    }

    return scheduledCount;
  }

  /// Triggers an immediate alarm preview so user can test the ringtone and vibration.
  Future<void> testAlarmNow({
    required AlertMode mode,
    String? subjectName,
    String? room,
  }) async {
    if (!_isInitialized) await initialize();

    final isRing = mode == AlertMode.ring;

    final channelId = isRing ? channelRingId : channelVibrateId;
    final androidDetails = AndroidNotificationDetails(
      channelId,
      isRing ? 'Lecture Alarms (Ring & Vibrate)' : 'Lecture Alerts (Vibrate)',
      channelDescription: 'Audible and vibrating alarms before lectures begin',
      importance: Importance.max,
      priority: Priority.max,
      playSound: isRing,
      enableVibration: true,
      vibrationPattern: isRing
          ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1500])
          : Int64List.fromList([0, 800, 300, 800, 300, 1200]),
      audioAttributesUsage:
          isRing ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );

    final details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: 999999,
      title: isRing
          ? '⏰ LECTURE ALARM TEST (Ring & Vibrate)'
          : '📳 LECTURE ALARM TEST (Vibrate)',
      body:
          'Your lecture alarm clock is active! ${subjectName ?? "Next Lecture"} starting in ${room ?? "Campus Hall"}.',
      notificationDetails: details,
    );
  }

  Future<void> scheduleLectureAlert({
    required int notificationId,
    required String subjectName,
    required String room,
    required String timeFormatted,
    required AlertMode mode,
  }) async {
    // Retained for backward-compatibility with single alerts
    await testAlarmNow(
      mode: mode,
      subjectName: subjectName,
      room: room,
    );
  }

  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('AlertScheduler cancelAll: $e');
    }
  }
}
