import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import '../core/services/alert_scheduler.dart';
import '../core/services/auth_service.dart';
import '../core/services/sync_service.dart';
import '../core/utils/google_drive_util.dart';
import '../core/utils/uuid_util.dart';
import '../models/models.dart';
import '../repositories/class_repository.dart';

// ===================================================================
// REPOSITORY & SYNC PROVIDERS
// ===================================================================

final classRepositoryProvider = Provider<ClassRepository>((ref) {
  SupabaseClient? client;
  if (AppConfig.isSupabaseConfigured) {
    try {
      client = Supabase.instance.client;
    } catch (_) {}
  }
  return ClassRepository(client: client);
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final repo = ref.watch(classRepositoryProvider);
  return SyncService(
    repository: repo,
    client: repo.client,
  );
});

class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    _init();
    return const SyncState();
  }

  Future<void> _init() async {
    final service = ref.read(syncServiceProvider);
    final pending = await service.getPendingMutations();
    final lastSynced = await service.getLastSyncedAt();
    state = state.copyWith(
      pendingCount: pending.length,
      lastSyncedAt: lastSynced,
      isConnected: service.canSync,
    );
  }

  Future<SyncResult> triggerSync() async {
    state = state.copyWith(isSyncing: true);
    final service = ref.read(syncServiceProvider);
    final result = await service.performSync();

    final pending = await service.getPendingMutations();
    final lastSynced = await service.getLastSyncedAt();

    // Reload active provider states from local cache
    await ref.read(subjectsProvider.notifier).reloadFromLocal();
    await ref.read(timetableSlotsProvider.notifier).reloadFromLocal();
    await ref.read(dailyOverridesProvider.notifier).reloadFromLocal();
    await ref.read(resourcesProvider.notifier).reloadFromLocal();

    state = state.copyWith(
      isSyncing: false,
      pendingCount: pending.length,
      lastSyncedAt: lastSynced,
      lastMessage: result.message,
    );

    return result;
  }

  void refreshPendingCount() async {
    final service = ref.read(syncServiceProvider);
    final pending = await service.getPendingMutations();
    state = state.copyWith(pendingCount: pending.length);
  }
}

final syncStateProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

// ===================================================================
// USER & ROLE PROVIDER
// ===================================================================

class UserNotifier extends Notifier<UserModel> {
  @override
  UserModel build() {
    _loadFromSession();
    return AuthService.instance.currentSession ?? const UserModel.empty();
  }

  Future<void> _loadFromSession() async {
    try {
      final session = await AuthService.instance.getActiveSession();
      if (session != null) {
        state = session;
      }
    } catch (_) {}
  }

  Future<AuthResult> login({
    required String rollNo,
    required String pin,
  }) async {
    final result = await AuthService.instance.loginStudent(
      rollNo: rollNo,
      pin: pin,
    );
    if (result.success && result.user != null) {
      state = result.user!;
    }
    return result;
  }

  Future<AuthResult> register({
    required String rollNo,
    required String name,
    required String pin,
    String? email,
  }) async {
    final result = await AuthService.instance.registerStudent(
      rollNo: rollNo,
      name: name,
      pin: pin,
      email: email,
    );
    if (result.success && result.user != null) {
      state = result.user!;
    }
    return result;
  }

  Future<AuthResult> signInWithGoogle({
    required String email,
    required String name,
    String? avatarUrl,
  }) async {
    final result = await AuthService.instance.signInWithGoogle(
      email: email,
      name: name,
      avatarUrl: avatarUrl,
    );
    if (result.success && result.user != null) {
      state = result.user!;
    }
    return result;
  }

  Future<void> reloadSession() async {
    await _loadFromSession();
  }

  Future<AuthResult> submitUploaderRequest({
    required String rollNo,
    required String name,
  }) async {
    final result = await AuthService.instance.submitUploaderRequest(
      userId: state.id,
      googleEmail: state.email,
      name: name,
      rollNo: rollNo,
    );
    if (result.success) {
      final updated = state.copyWith(
        rollNo: rollNo.trim().toUpperCase(),
        name: name.trim(),
        uploadRequestStatus: 'pending',
        uploadRequestedAt: DateTime.now(),
      );
      state = updated;
      ref.read(uploaderRequestsProvider.notifier).refresh();
    }
    return result;
  }

  Future<void> logout() async {
    await AuthService.instance.logout();
    state = const UserModel.empty();
    HapticFeedback.mediumImpact();
  }

  Future<AuthResult> elevateToAdmin(String passkey) async {
    final result = await AuthService.instance.verifyAdminAccess(
      rollNo: state.rollNo,
      passkey: passkey,
      email: state.email,
    );
    if (result.success) {
      final updated = state.copyWith(role: 'admin');
      state = updated;
      await AuthService.instance.saveSession(updated);
      HapticFeedback.heavyImpact();
    }
    return result;
  }

  Future<void> downgradeToStudent() async {
    final updated = state.copyWith(role: 'student');
    state = updated;
    await AuthService.instance.saveSession(updated);
    HapticFeedback.lightImpact();
  }

  void toggleRole() {
    if (state.isAdmin) {
      downgradeToStudent();
    }
  }

  void updateProfile({
    String? name,
    String? email,
    String? rollNo,
    String? avatarUrl,
  }) {
    state = state.copyWith(
      name: name ?? state.name,
      email: email ?? state.email,
      rollNo: rollNo ?? state.rollNo,
      avatarUrl: avatarUrl ?? state.avatarUrl,
    );
    HapticFeedback.lightImpact();
  }

  void addCredits(int amount) {
    state = state.copyWith(credits: state.credits + amount);
  }

  bool deductCredits(int amount) {
    if (state.credits < amount) return false;
    state = state.copyWith(credits: state.credits - amount);
    return true;
  }
}

final currentUserProvider =
    NotifierProvider<UserNotifier, UserModel>(UserNotifier.new);

class UsersListNotifier extends Notifier<List<UserModel>> {
  @override
  List<UserModel> build() {
    _loadUsers();
    return const [];
  }

  Future<void> _loadUsers() async {
    final list = await AuthService.instance.getAllUsers();
    state = list;
  }

  Future<void> refresh() async {
    final list = await AuthService.instance.getAllUsers();
    state = list;
  }

  Future<AuthResult> createUser(UserModel user, String pin) async {
    final result =
        await AuthService.instance.adminCreateUser(user: user, pin: pin);
    if (result.success) {
      await refresh();
    }
    return result;
  }

  Future<bool> updateUser(UserModel user, {String? newPin}) async {
    final ok = await AuthService.instance.adminUpdateUser(user, newPin: newPin);
    if (ok) {
      await refresh();
      final current = ref.read(currentUserProvider);
      if (current.rollNo == user.rollNo) {
        ref.read(currentUserProvider.notifier).updateProfile(
              name: user.name,
              email: user.email,
              rollNo: user.rollNo,
            );
      }
    }
    return ok;
  }

  Future<bool> deleteUser(String rollNo) async {
    final ok = await AuthService.instance.adminDeleteUser(rollNo);
    if (ok) {
      await refresh();
    }
    return ok;
  }

  Future<bool> resetPin(String rollNo, String newPin) async {
    final ok = await AuthService.instance
        .adminResetStudentPin(rollNo: rollNo, newPin: newPin);
    if (ok) {
      await refresh();
    }
    return ok;
  }
}

final usersListProvider =
    NotifierProvider<UsersListNotifier, List<UserModel>>(UsersListNotifier.new);

class AdminWhitelistNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _load();
    return const ['23-SE-402', 'ADMIN-01', 'CR-01'];
  }

  Future<void> _load() async {
    state = await AuthService.instance.getAdminWhitelist();
  }

  Future<void> refresh() async {
    state = await AuthService.instance.getAdminWhitelist();
  }

  Future<bool> add(String rollNo) async {
    final ok = await AuthService.instance.addAdminToWhitelist(rollNo);
    if (ok) await refresh();
    return ok;
  }

  Future<bool> remove(String rollNo) async {
    final ok = await AuthService.instance.removeAdminFromWhitelist(rollNo);
    if (ok) await refresh();
    return ok;
  }
}

final adminWhitelistProvider =
    NotifierProvider<AdminWhitelistNotifier, List<String>>(
        AdminWhitelistNotifier.new);

// ===================================================================
// SUBJECTS & TIMETABLE PROVIDERS (MUTABLE BY ADMIN)
// ===================================================================

class SubjectsNotifier extends Notifier<List<SubjectModel>> {
  @override
  List<SubjectModel> build() {
    _initData();
    return ClassRepository.memorySubjects ??
        (ClassRepository.hasPreloaded ? const [] : ClassRepository.mockSubjects);
  }

  Future<void> _initData() async {
    final repo = ref.read(classRepositoryProvider);
    final cached = await repo.loadCachedSubjects();
    if (cached != null) {
      state = cached;
    }
    final live = await repo.fetchSubjects();
    if (live != null) {
      state = live;
      await repo.cacheSubjects(live);
    }
  }

  Future<void> reloadFromLocal() async {
    final cached = await ref.read(classRepositoryProvider).loadCachedSubjects();
    if (cached != null) {
      state = cached;
    }
  }

  void addSubject(SubjectModel subject) {
    state = [...state, subject];
    ref.read(classRepositoryProvider).cacheSubjects(state);
    ref.read(syncServiceProvider).enqueueMutation(
          entity: 'subject',
          entityId: subject.id,
          action: 'upsert',
          payload: subject.toMap(),
        );
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).createSubject(subject);
    HapticFeedback.lightImpact();
  }

  void updateSubject(SubjectModel updated) {
    state = state.map((s) => s.id == updated.id ? updated : s).toList();
    ref.read(classRepositoryProvider).cacheSubjects(state);
    ref.read(syncServiceProvider).enqueueMutation(
          entity: 'subject',
          entityId: updated.id,
          action: 'upsert',
          payload: updated.toMap(),
        );
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).updateSubject(updated);
    HapticFeedback.lightImpact();
  }

  void deleteSubject(String subjectId) {
    state = state.where((s) => s.id != subjectId).toList();
    ref.read(classRepositoryProvider).cacheSubjects(state);
    ref.read(syncServiceProvider).enqueueMutation(
          entity: 'subject',
          entityId: subjectId,
          action: 'delete',
        );
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    // Cascade delete any slots for this subject
    ref.read(timetableSlotsProvider.notifier).deleteSlotsForSubject(subjectId);
    ref.read(classRepositoryProvider).deleteSubject(subjectId);
    HapticFeedback.mediumImpact();
  }
}

final subjectsProvider =
    NotifierProvider<SubjectsNotifier, List<SubjectModel>>(SubjectsNotifier.new);

class TimetableSlotsNotifier extends Notifier<List<TimetableSlotModel>> {
  @override
  List<TimetableSlotModel> build() {
    _initData();
    return ClassRepository.memorySlots ??
        (ClassRepository.hasPreloaded ? const [] : ClassRepository.mockSlots);
  }

  Future<void> _initData() async {
    final repo = ref.read(classRepositoryProvider);
    final cached = await repo.loadCachedSlots();
    if (cached != null) {
      state = cached;
    }
    final live = await repo.fetchSlots();
    if (live != null) {
      state = live;
      await repo.cacheSlots(live);
    }
  }

  Future<void> reloadFromLocal() async {
    final cached = await ref.read(classRepositoryProvider).loadCachedSlots();
    if (cached != null) {
      state = cached;
    }
  }

  void addSlot(TimetableSlotModel slot) {
    state = [...state, slot];
    ref.read(classRepositoryProvider).cacheSlots(state);
    ref.read(syncServiceProvider).enqueueMutation(
          entity: 'slot',
          entityId: slot.id,
          action: 'upsert',
          payload: slot.toMap(),
        );
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).createSlot(slot);
    HapticFeedback.lightImpact();
  }

  void updateSlot(TimetableSlotModel updated) {
    state = state.map((s) => s.id == updated.id ? updated : s).toList();
    ref.read(classRepositoryProvider).cacheSlots(state);
    ref.read(syncServiceProvider).enqueueMutation(
          entity: 'slot',
          entityId: updated.id,
          action: 'upsert',
          payload: updated.toMap(),
        );
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).updateSlot(updated);
    HapticFeedback.lightImpact();
  }

  void deleteSlot(String slotId) {
    state = state.where((s) => s.id != slotId).toList();
    ref.read(classRepositoryProvider).cacheSlots(state);
    ref.read(syncServiceProvider).enqueueMutation(
          entity: 'slot',
          entityId: slotId,
          action: 'delete',
        );
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).deleteSlot(slotId);
    HapticFeedback.mediumImpact();
  }

  void deleteSlotsForSubject(String subjectId) {
    final slotsToRemove = state.where((s) => s.subjectId == subjectId).toList();
    for (final s in slotsToRemove) {
      ref.read(syncServiceProvider).enqueueMutation(
            entity: 'slot',
            entityId: s.id,
            action: 'delete',
          );
    }
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    state = state.where((s) => s.subjectId != subjectId).toList();
    ref.read(classRepositoryProvider).cacheSlots(state);
  }
}

final timetableSlotsProvider =
    NotifierProvider<TimetableSlotsNotifier, List<TimetableSlotModel>>(
        TimetableSlotsNotifier.new);

// ===================================================================
// DAILY OVERRIDES PROVIDER
// ===================================================================

class OverridesNotifier extends Notifier<List<DailyOverrideModel>> {
  @override
  List<DailyOverrideModel> build() {
    _initData();
    return ClassRepository.memoryOverrides ?? const [];
  }

  Future<void> _initData() async {
    final repo = ref.read(classRepositoryProvider);
    final cached = await repo.loadCachedOverrides();
    if (cached != null) {
      state = cached;
    }
    final live = await repo.fetchOverrides();
    if (live != null) {
      state = live;
      await repo.cacheOverrides(live);
    }
  }

  Future<void> reloadFromLocal() async {
    final cached = await ref.read(classRepositoryProvider).loadCachedOverrides();
    if (cached != null) {
      state = cached;
    }
  }

  void submitReport({
    required String slotId,
    required OverrideStatus status,
    String? actualRoom,
    String? actualStartTime,
    String? actualEndTime,
    DateTime? rescheduledDate,
    String? topicCovered,
    required String reportedBy,
  }) {
    final newOverride = DailyOverrideModel(
      id: UuidUtil.generate(),
      slotId: slotId,
      date: DateTime.now(),
      status: status,
      actualRoom: actualRoom,
      actualStartTime: actualStartTime,
      actualEndTime: actualEndTime,
      rescheduledDate: rescheduledDate,
      topicCovered: topicCovered,
      reportedBy: reportedBy,
      isApproved: false, // Sent to Admin Mod Queue
    );
    state = [newOverride, ...state];
    ref.read(classRepositoryProvider).cacheOverrides(state);
    ref.read(syncServiceProvider).enqueueMutation(
          entity: 'override',
          entityId: newOverride.id,
          action: 'upsert',
          payload: newOverride.toMap(),
        );
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).saveOverride(newOverride);
  }

  /// Direct admin override with instant approval and optional Supabase sync
  void setDirectOverride({
    required String slotId,
    required OverrideStatus status,
    DateTime? date,
    String? actualRoom,
    String? actualStartTime,
    String? actualEndTime,
    DateTime? rescheduledDate,
    String? topicCovered,
  }) {
    final targetDate = date ?? DateTime.now();
    final targetDayStr = targetDate.toIso8601String().substring(0, 10);

    // Filter out previous override for same slot on same date
    final remaining = state.where((o) {
      final oDayStr = o.date.toIso8601String().substring(0, 10);
      return !(o.slotId == slotId && oDayStr == targetDayStr);
    }).toList();

    final newOverride = DailyOverrideModel(
      id: UuidUtil.generate(),
      slotId: slotId,
      date: targetDate,
      status: status,
      actualRoom: actualRoom,
      actualStartTime: actualStartTime,
      actualEndTime: actualEndTime,
      rescheduledDate: rescheduledDate,
      topicCovered: topicCovered,
      reportedBy: ref.read(currentUserProvider).id,
      isApproved: true, // Immediate admin broadcast
    );

    state = [newOverride, ...remaining];
    ref.read(classRepositoryProvider).cacheOverrides(state);
    ref.read(syncServiceProvider).enqueueMutation(
          entity: 'override',
          entityId: newOverride.id,
          action: 'upsert',
          payload: newOverride.toMap(),
        );
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).saveOverride(newOverride);
    HapticFeedback.mediumImpact();
  }

  void deleteOverride(String overrideId) {
    state = state.where((ov) => ov.id != overrideId).toList();
    ref.read(classRepositoryProvider).cacheOverrides(state);
    ref.read(syncServiceProvider).enqueueMutation(
          entity: 'override',
          entityId: overrideId,
          action: 'delete',
        );
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).deleteOverride(overrideId);
    HapticFeedback.selectionClick();
  }

  void approveOverride(String overrideId) {
    state = state.map((ov) {
      if (ov.id == overrideId) {
        final approved = ov.copyWith(isApproved: true);
        ref.read(classRepositoryProvider).saveOverride(approved);
        ref.read(syncServiceProvider).enqueueMutation(
              entity: 'override',
              entityId: approved.id,
              action: 'upsert',
              payload: approved.toMap(),
            );
        return approved;
      }
      return ov;
    }).toList();
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).cacheOverrides(state);
  }

  void rejectOverride(String overrideId) {
    state = state.where((ov) => ov.id != overrideId).toList();
    ref.read(classRepositoryProvider).cacheOverrides(state);
    ref.read(syncServiceProvider).enqueueMutation(
          entity: 'override',
          entityId: overrideId,
          action: 'delete',
        );
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).deleteOverride(overrideId);
  }
}

final dailyOverridesProvider =
    NotifierProvider<OverridesNotifier, List<DailyOverrideModel>>(
        OverridesNotifier.new);

// ===================================================================
// TODAY LECTURES COMPUTED PROVIDER
// ===================================================================

DateTime _parseLectureTime(DateTime date, String timeStr, int fallbackH, int fallbackM) {
  try {
    final parts = timeStr.trim().split(':');
    final h = int.parse(parts[0]);
    final m = parts.length > 1 ? int.parse(parts[1]) : 0;
    return DateTime(date.year, date.month, date.day, h, m);
  } catch (_) {
    return DateTime(date.year, date.month, date.day, fallbackH, fallbackM);
  }
}

final todayLecturesProvider = Provider<List<LectureItem>>((ref) {
  final slots = ref.watch(timetableSlotsProvider);
  final subjects = ref.watch(subjectsProvider);
  final overrides = ref.watch(dailyOverridesProvider);

  final now = DateTime.now();
  final dayOfWeek = now.weekday; // 1 = Mon ... 7 = Sun (accurate real-world day)

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  final todaySlots = slots.where((s) => s.dayOfWeek == dayOfWeek).toList();
  final items = <LectureItem>[];

  SubjectModel getSubjectForSlot(TimetableSlotModel slot) {
    final targetUuid = UuidUtil.fromString(slot.subjectId);
    return subjects.firstWhere(
      (s) => s.id == slot.subjectId || UuidUtil.fromString(s.id) == targetUuid,
      orElse: () => subjects.isNotEmpty
          ? subjects.first
          : const SubjectModel(
              id: 'unknown',
              name: 'Class Lecture',
              code: 'LEC',
              professor: 'Instructor',
            ),
    );
  }

  for (final slot in todaySlots) {
    final subject = getSubjectForSlot(slot);

    final override = overrides.cast<DailyOverrideModel?>().firstWhere(
      (o) =>
          o != null &&
          o.slotId == slot.id &&
          isSameDay(o.date, now) &&
          o.isApproved,
      orElse: () => null,
    );

    final effectiveStart = (override?.actualStartTime != null && override!.actualStartTime!.isNotEmpty)
        ? override.actualStartTime!
        : slot.startTime;
    final effectiveEnd = (override?.actualEndTime != null && override!.actualEndTime!.isNotEmpty)
        ? override.actualEndTime!
        : slot.endTime;

    final startsAt = _parseLectureTime(now, effectiveStart, 9, 0);
    final endsAt = _parseLectureTime(now, effectiveEnd, 10, 0);

    items.add(LectureItem(
      slot: slot,
      subject: subject,
      override: override,
      startsAt: startsAt,
      endsAt: endsAt,
    ));
  }

  // Also include classes from other days that were rescheduled to today
  for (final ov in overrides) {
    if (ov.isApproved &&
        ov.status == OverrideStatus.rescheduled &&
        ov.rescheduledDate != null &&
        isSameDay(ov.rescheduledDate!, now)) {
      final targetSlotUuid = UuidUtil.fromString(ov.slotId);
      final originSlot = slots.cast<TimetableSlotModel?>().firstWhere(
        (s) => s != null && (s.id == ov.slotId || UuidUtil.fromString(s.id) == targetSlotUuid),
        orElse: () => null,
      );

      if (originSlot != null && originSlot.dayOfWeek != dayOfWeek) {
        if (!items.any((it) => it.slot.id == originSlot.id)) {
          final subject = getSubjectForSlot(originSlot);
          final effectiveStart = (ov.actualStartTime != null && ov.actualStartTime!.isNotEmpty)
              ? ov.actualStartTime!
              : originSlot.startTime;
          final effectiveEnd = (ov.actualEndTime != null && ov.actualEndTime!.isNotEmpty)
              ? ov.actualEndTime!
              : originSlot.endTime;

          final startsAt = _parseLectureTime(now, effectiveStart, 9, 0);
          final endsAt = _parseLectureTime(now, effectiveEnd, 10, 0);

          items.add(LectureItem(
            slot: originSlot,
            subject: subject,
            override: ov,
            startsAt: startsAt,
            endsAt: endsAt,
          ));
        }
      }
    }
  }

  items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return items;
});

final nextLectureProvider = Provider<LectureItem?>((ref) {
  final slots = ref.watch(timetableSlotsProvider);
  final subjects = ref.watch(subjectsProvider);
  final overrides = ref.watch(dailyOverridesProvider);
  final todayLectures = ref.watch(todayLecturesProvider);

  if (slots.isEmpty || subjects.isEmpty) return null;

  // 1. Ongoing lecture today
  for (final l in todayLectures) {
    if (l.isOngoing) return l;
  }

  // 2. Upcoming lecture today
  for (final l in todayLectures) {
    if (l.isUpcoming) return l;
  }

  // 3. If no classes today (e.g. Sunday/weekend), search ahead across the coming days
  final now = DateTime.now();
  for (int offset = 1; offset <= 7; offset++) {
    final futureDate = now.add(Duration(days: offset));
    final targetDayOfWeek = futureDate.weekday; // 1 = Mon ... 7 = Sun

    final futureSlots =
        slots.where((s) => s.dayOfWeek == targetDayOfWeek).toList();
    if (futureSlots.isEmpty) continue;

    // Earliest class on that upcoming day
    futureSlots.sort((a, b) => a.startTime.compareTo(b.startTime));
    final nextSlot = futureSlots.first;

    final targetUuid = UuidUtil.fromString(nextSlot.subjectId);
    final subject = subjects.firstWhere(
      (s) => s.id == nextSlot.subjectId || UuidUtil.fromString(s.id) == targetUuid,
      orElse: () => subjects.isNotEmpty
          ? subjects.first
          : const SubjectModel(
              id: 'unknown',
              name: 'Class Lecture',
              code: 'LEC',
              professor: 'Instructor',
            ),
    );

    final override = overrides.cast<DailyOverrideModel?>().firstWhere(
      (o) =>
          o != null &&
          o.slotId == nextSlot.id &&
          o.date.year == futureDate.year &&
          o.date.month == futureDate.month &&
          o.date.day == futureDate.day &&
          o.isApproved,
      orElse: () => null,
    );

    final effectiveStart = (override?.actualStartTime != null && override!.actualStartTime!.isNotEmpty)
        ? override.actualStartTime!
        : nextSlot.startTime;
    final effectiveEnd = (override?.actualEndTime != null && override!.actualEndTime!.isNotEmpty)
        ? override.actualEndTime!
        : nextSlot.endTime;

    final startsAt = _parseLectureTime(futureDate, effectiveStart, 9, 0);
    final endsAt = _parseLectureTime(futureDate, effectiveEnd, 10, 0);

    return LectureItem(
      slot: nextSlot,
      subject: subject,
      override: override,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }

  return null;
});

// ===================================================================
// RESOURCES / VAULT PROVIDER
// ===================================================================

class ResourcesNotifier extends Notifier<List<ResourceModel>> {
  @override
  List<ResourceModel> build() {
    _initData();
    return ClassRepository.memoryResources ??
        (ClassRepository.hasPreloaded ? const [] : ClassRepository.mockResources);
  }

  Future<void> _initData() async {
    final repo = ref.read(classRepositoryProvider);
    final cached = await repo.loadCachedResources();
    if (cached != null) {
      state = cached;
    }
    final live = await repo.fetchResources();
    if (live != null) {
      state = live;
      await repo.cacheResources(live);
    }
  }

  Future<void> reloadFromLocal() async {
    final cached = await ref.read(classRepositoryProvider).loadCachedResources();
    if (cached != null) {
      state = cached;
    }
  }

  bool unlockResource(String resourceId) {
    final user = ref.read(currentUserProvider);
    final resource = state.firstWhere((r) => r.id == resourceId);

    if (resource.isUnlocked) return true;

    if (user.credits < resource.costCredits) return false;

    // Deduct credits
    ref.read(currentUserProvider.notifier).deductCredits(resource.costCredits);

    // Mark unlocked
    state = state.map((r) {
      if (r.id == resourceId) return r.copyWith(isUnlocked: true);
      return r;
    }).toList();
    ref.read(classRepositoryProvider).cacheResources(state);

    return true;
  }

  void incrementUpvote(String resourceId) {
    state = state.map((r) {
      if (r.id == resourceId) {
        final updated = r.copyWith(upvotes: r.upvotes + 1);
        ref.read(syncServiceProvider).enqueueMutation(
              entity: 'resource',
              entityId: updated.id,
              action: 'upsert',
              payload: updated.toMap(),
            );
        ref.read(classRepositoryProvider).saveResource(updated);
        return updated;
      }
      return r;
    }).toList();
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).cacheResources(state);
  }

  void decrementUpvote(String resourceId) {
    state = state.map((r) {
      if (r.id == resourceId && r.upvotes > 0) {
        final updated = r.copyWith(upvotes: r.upvotes - 1);
        ref.read(syncServiceProvider).enqueueMutation(
              entity: 'resource',
              entityId: updated.id,
              action: 'upsert',
              payload: updated.toMap(),
            );
        ref.read(classRepositoryProvider).saveResource(updated);
        return updated;
      }
      return r;
    }).toList();
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).cacheResources(state);
  }

  String? submitResource({
    required String subjectId,
    required String title,
    required ResourceType type,
    required String url,
    required String uploaderName,
    String? uploaderId,
  }) {
    // Protection against repeated / duplicate links
    final duplicate = state.where((r) => GoogleDriveUtil.isSameResource(r.url, url)).firstOrNull;
    if (duplicate != null) {
      return 'Duplicate link: This material has already been uploaded as "${duplicate.title}" by ${duplicate.uploaderName}.';
    }

    final user = ref.read(currentUserProvider);
    final newRes = ResourceModel(
      id: UuidUtil.generate(),
      subjectId: subjectId,
      date: DateTime.now(),
      uploaderId: uploaderId ?? user.id,
      uploaderName: uploaderName,
      title: title,
      type: type,
      url: url,
      upvotes: 0,
      costCredits: 5,
      isApproved: false, // Sent to Admin Mod Queue
      isUnlocked: true, // Uploader always has it unlocked
    );

    state = [newRes, ...state];
    ref.read(classRepositoryProvider).cacheResources(state);
    ref.read(syncServiceProvider).enqueueMutation(
          entity: 'resource',
          entityId: newRes.id,
          action: 'upsert',
          payload: newRes.toMap(),
        );
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).saveResource(newRes);

    // Award +50 credits for contributing notes
    ref.read(currentUserProvider.notifier).addCredits(50);
    return null;
  }

  void approveResource(String resourceId) {
    state = state.map((r) {
      if (r.id == resourceId) {
        final approved = r.copyWith(isApproved: true);
        ref.read(classRepositoryProvider).saveResource(approved);
        ref.read(syncServiceProvider).enqueueMutation(
              entity: 'resource',
              entityId: approved.id,
              action: 'upsert',
              payload: approved.toMap(),
            );
        return approved;
      }
      return r;
    }).toList();
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).cacheResources(state);
  }

  void rejectResource(String resourceId) {
    state = state.where((r) => r.id != resourceId).toList();
    ref.read(classRepositoryProvider).cacheResources(state);
    ref.read(syncServiceProvider).enqueueMutation(
          entity: 'resource',
          entityId: resourceId,
          action: 'delete',
        );
    ref.read(syncStateProvider.notifier).refreshPendingCount();
    ref.read(classRepositoryProvider).deleteResource(resourceId);
  }
}

final resourcesProvider =
    NotifierProvider<ResourcesNotifier, List<ResourceModel>>(
        ResourcesNotifier.new);

// ===================================================================
// LIKED RESOURCES TRACKER (PREVENTS INFINITE CREDIT FARMING)
// ===================================================================

class LikedResourcesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _loadFromPrefs();
    return {};
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('liked_resource_ids');
      if (list != null) {
        state = list.toSet();
      }
    } catch (_) {}
  }

  /// Toggles like. Returns true if now liked, false if unliked.
  bool toggleLike(String resourceId) {
    final alreadyLiked = state.contains(resourceId);
    if (alreadyLiked) {
      state = {...state}..remove(resourceId);
      ref.read(resourcesProvider.notifier).decrementUpvote(resourceId);
      ref.read(currentUserProvider.notifier).deductCredits(5);
      _saveToPrefs();
      HapticFeedback.lightImpact();
      return false;
    } else {
      state = {...state, resourceId};
      ref.read(resourcesProvider.notifier).incrementUpvote(resourceId);
      ref.read(currentUserProvider.notifier).addCredits(5);
      _saveToPrefs();
      HapticFeedback.mediumImpact();
      return true;
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('liked_resource_ids', state.toList());
    } catch (_) {}
  }
}

final likedResourcesProvider =
    NotifierProvider<LikedResourcesNotifier, Set<String>>(
        LikedResourcesNotifier.new);

// ===================================================================
// ATTENDANCE & BUNK CALCULATOR PROVIDER
// ===================================================================

class AttendanceNotifier
    extends Notifier<Map<String, AttendanceRecord>> {
  @override
  Map<String, AttendanceRecord> build() {
    return ClassRepository.initialAttendance;
  }

  void markPresent(String subjectId) {
    final current = state[subjectId] ??
        AttendanceRecord(subjectId: subjectId, attended: 0, total: 0);
    state = {
      ...state,
      subjectId: current.copyWith(
        attended: current.attended + 1,
        total: current.total + 1,
      ),
    };
    HapticFeedback.lightImpact();
  }

  void markAbsent(String subjectId) {
    final current = state[subjectId] ??
        AttendanceRecord(subjectId: subjectId, attended: 0, total: 0);
    state = {
      ...state,
      subjectId: current.copyWith(
        total: current.total + 1,
      ),
    };
    HapticFeedback.mediumImpact();
  }
}

final attendanceProvider = NotifierProvider<AttendanceNotifier,
    Map<String, AttendanceRecord>>(AttendanceNotifier.new);

// ===================================================================
// ALERT & NOTIFICATION PREFERENCES
// ===================================================================

class AlertModeNotifier extends Notifier<AlertMode> {
  @override
  AlertMode build() {
    _loadFromPrefs();
    return AlertMode.ring;
  }

  Future<void> _loadFromPrefs() async {
    state = await AlertScheduler.instance.getSavedAlertMode();
  }

  Future<void> cycleNext() async {
    final next = state.next();
    state = next;
    HapticFeedback.selectionClick();
    await AlertScheduler.instance.saveAlertMode(next);
    _syncTimetableAlerts(next);
  }

  Future<void> setMode(AlertMode mode) async {
    state = mode;
    await AlertScheduler.instance.saveAlertMode(mode);
    _syncTimetableAlerts(mode);
  }

  void _syncTimetableAlerts(AlertMode mode) {
    try {
      final slots = ref.read(timetableSlotsProvider);
      final subjects = ref.read(subjectsProvider);
      final leadTime = ref.read(alertLeadTimeProvider);
      final subjectMap = {for (var s in subjects) s.id: s};
      AlertScheduler.instance.syncAllTimetableAlerts(
        slots: slots,
        subjectMap: subjectMap,
        mode: mode,
        leadTimeMinutes: leadTime,
      );
    } catch (e) {
      debugPrint('Error syncing timetable alerts: $e');
    }
  }
}

final alertModeProvider =
    NotifierProvider<AlertModeNotifier, AlertMode>(AlertModeNotifier.new);

class AlertLeadTimeNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 10;
  }

  Future<void> _load() async {
    state = await AlertScheduler.instance.getSavedLeadTimeMinutes();
  }

  Future<void> setMinutes(int minutes) async {
    state = minutes;
    await AlertScheduler.instance.saveLeadTimeMinutes(minutes);
    try {
      final slots = ref.read(timetableSlotsProvider);
      final subjects = ref.read(subjectsProvider);
      final mode = ref.read(alertModeProvider);
      final subjectMap = {for (var s in subjects) s.id: s};
      AlertScheduler.instance.syncAllTimetableAlerts(
        slots: slots,
        subjectMap: subjectMap,
        mode: mode,
        leadTimeMinutes: minutes,
      );
    } catch (_) {}
  }
}

final alertLeadTimeProvider =
    NotifierProvider<AlertLeadTimeNotifier, int>(AlertLeadTimeNotifier.new);

// ===================================================================
// LEADERBOARD & MOD QUEUE COUNTERS
// ===================================================================

final leaderboardProvider = Provider<List<UserModel>>((ref) {
  final users = ref.watch(usersListProvider);
  final current = ref.watch(currentUserProvider);

  final userMap = <String, UserModel>{};
  for (final u in users) {
    if (u.name.trim().isNotEmpty && (u.email.isNotEmpty || u.rollNo?.isNotEmpty == true)) {
      final key = u.email.isNotEmpty ? u.email.toLowerCase() : u.id;
      userMap[key] = u;
    }
  }

  if (current.isLoggedIn && current.name.trim().isNotEmpty) {
    final currentKey = current.email.isNotEmpty ? current.email.toLowerCase() : current.id;
    userMap[currentKey] = current;
  }

  final list = userMap.values.toList();
  list.sort((a, b) => b.credits.compareTo(a.credits));
  return list;
});

// ===================================================================
// UPLOADER / CONTRIBUTOR VERIFICATION REQUESTS PROVIDER
// ===================================================================

class UploaderRequestsNotifier extends Notifier<List<UploaderRequestModel>> {
  @override
  List<UploaderRequestModel> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    state = await AuthService.instance.getUploaderRequests();
  }

  Future<void> refresh() async {
    state = await AuthService.instance.getUploaderRequests();
  }

  Future<bool> approve(String requestId) async {
    final currentUser = ref.read(currentUserProvider);
    final ok = await AuthService.instance.approveUploaderRequest(
      requestId,
      adminEmail: currentUser.email,
    );
    if (ok) {
      await refresh();
      await ref.read(usersListProvider.notifier).refresh();
      // If current user is the requester, reload their active session
      final session = await AuthService.instance.getActiveSession();
      if (session != null && session.id == currentUser.id) {
        await ref.read(currentUserProvider.notifier).reloadSession();
      }
    }
    return ok;
  }

  Future<bool> reject(String requestId, {String? reason}) async {
    final currentUser = ref.read(currentUserProvider);
    final ok = await AuthService.instance.rejectUploaderRequest(
      requestId,
      reason: reason,
      adminEmail: currentUser.email,
    );
    if (ok) {
      await refresh();
      await ref.read(usersListProvider.notifier).refresh();
      final session = await AuthService.instance.getActiveSession();
      if (session != null && session.id == currentUser.id) {
        await ref.read(currentUserProvider.notifier).reloadSession();
      }
    }
    return ok;
  }
}

final uploaderRequestsProvider =
    NotifierProvider<UploaderRequestsNotifier, List<UploaderRequestModel>>(
        UploaderRequestsNotifier.new);

final pendingUploaderRequestsCountProvider = Provider<int>((ref) {
  return ref.watch(uploaderRequestsProvider).where((r) => r.isPending).length;
});

final pendingModQueueCountProvider = Provider<int>((ref) {
  final pendingResources =
      ref.watch(resourcesProvider).where((r) => !r.isApproved).length;
  final pendingOverrides =
      ref.watch(dailyOverridesProvider).where((o) => !o.isApproved).length;
  final pendingRequests = ref.watch(pendingUploaderRequestsCountProvider);
  return pendingResources + pendingOverrides + pendingRequests;
});

// ===================================================================
// OFFICIAL TIMETABLE IMAGE PROVIDER (Google Drive Powered)
// ===================================================================

class TimetableImageUrlNotifier extends Notifier<String?> {
  static const String _keyTimetableImg = 'key_official_timetable_image_url_v2';

  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_keyTimetableImg);
  }

  Future<void> updateImage(String rawUrl) async {
    final displayUrl = GoogleDriveUtil.toDisplayableImageUrl(rawUrl);
    state = displayUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTimetableImg, displayUrl);
  }

  Future<void> clearImage() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTimetableImg);
  }
}

final timetableImageUrlProvider =
    NotifierProvider<TimetableImageUrlNotifier, String?>(
        TimetableImageUrlNotifier.new);

// ===================================================================
// ASSIGNMENT TRACKER PROVIDERS
// ===================================================================

/// Client-side ONLY checkmark completion tracker.
/// Stored strictly in local SharedPreferences for student privacy.
class AssignmentCompletionNotifier extends Notifier<Set<String>> {
  static const String _keyCompleted = 'key_student_completed_assignment_ids_v1';

  @override
  Set<String> build() {
    _load();
    return {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyCompleted) ?? [];
    state = list.toSet();
  }

  Future<void> toggleCompleted(String assignmentId) async {
    final current = Set<String>.from(state);
    if (current.contains(assignmentId)) {
      current.remove(assignmentId);
    } else {
      current.add(assignmentId);
    }
    state = current;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCompleted, current.toList());
  }

  bool isCompleted(String assignmentId) => state.contains(assignmentId);
}

final assignmentCompletionProvider =
    NotifierProvider<AssignmentCompletionNotifier, Set<String>>(
        AssignmentCompletionNotifier.new);

/// Server-side & cache assignments list manager (Admin-authored)
class AssignmentsNotifier extends Notifier<List<AssignmentModel>> {
  @override
  List<AssignmentModel> build() {
    _init();
    return ClassRepository.memoryAssignments ?? const [];
  }

  Future<void> _init() async {
    final repo = ref.read(classRepositoryProvider);
    final cached = await repo.loadCachedAssignments();
    if (cached != null) {
      state = cached;
    }
    try {
      final remote = await repo.fetchAssignments();
      if (remote != null) {
        state = remote;
        await repo.cacheAssignments(remote);
      }
    } catch (e) {
      debugPrint('Error fetching assignments: $e');
    }
  }

  Future<void> createAssignment({
    required String subjectId,
    required String title,
    required String description,
    required DateTime deadline,
    String? driveUrl,
  }) async {
    final user = ref.read(currentUserProvider);
    final newAssignment = AssignmentModel(
      id: UuidUtil.generate(),
      subjectId: subjectId,
      title: title.trim(),
      description: description.trim(),
      deadline: deadline,
      driveUrl: driveUrl?.trim().isNotEmpty == true ? driveUrl!.trim() : null,
      createdBy: user.name,
      createdAt: DateTime.now(),
    );

    state = [...state, newAssignment]
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    final repo = ref.read(classRepositoryProvider);
    await repo.cacheAssignments(state);
    await repo.saveAssignment(newAssignment);
  }

  Future<void> deleteAssignment(String assignmentId) async {
    state = state.where((a) => a.id != assignmentId).toList();
    final repo = ref.read(classRepositoryProvider);
    await repo.cacheAssignments(state);
    await repo.deleteAssignment(assignmentId);
  }
}

final assignmentsProvider =
    NotifierProvider<AssignmentsNotifier, List<AssignmentModel>>(
        AssignmentsNotifier.new);



