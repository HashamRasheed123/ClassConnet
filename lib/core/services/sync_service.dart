import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../utils/uuid_util.dart';
import '../../repositories/class_repository.dart';

/// Represents a single mutation queued for syncing to cloud Supabase
class PendingMutation {
  final String id;
  final String entity; // 'subject' | 'slot' | 'override' | 'resource'
  final String action; // 'upsert' | 'delete'
  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  const PendingMutation({
    required this.id,
    required this.entity,
    required this.action,
    this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'entity': entity,
        'action': action,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
      };

  factory PendingMutation.fromMap(Map<String, dynamic> map) {
    return PendingMutation(
      id: map['id'] as String,
      entity: map['entity'] as String,
      action: map['action'] as String,
      payload: map['payload'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(
          map['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Status and statistics for Cloud Synchronization
class SyncState {
  final bool isSyncing;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? lastMessage;
  final bool isConnected;

  const SyncState({
    this.isSyncing = false,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.lastMessage,
    this.isConnected = true,
  });

  SyncState copyWith({
    bool? isSyncing,
    int? pendingCount,
    DateTime? lastSyncedAt,
    String? lastMessage,
    bool? isConnected,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

/// Offline-First Synchronization Manager:
/// 1. Tracks local mutations in persistent queue
/// 2. Performs delta sync: pushes only unsynced changes to Supabase
/// 3. Pulls remote updates and updates local cache
class SyncService {
  static const String _keyPendingMutations = 'sync_pending_mutations';
  static const String _keyLastSyncedAt = 'sync_last_synced_timestamp';

  final ClassRepository repository;
  final SupabaseClient? _injectedClient;

  SyncService({
    required this.repository,
    SupabaseClient? client,
  }) : _injectedClient = client;

  SupabaseClient? get client => _injectedClient ?? repository.client;

  bool get canSync =>
      client != null && AppConfig.isSupabaseConfigured;

  // ---------------------------------------------------------------------------
  // QUEUE MANAGEMENT
  // ---------------------------------------------------------------------------

  Future<List<PendingMutation>> getPendingMutations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_keyPendingMutations) ?? [];
      return jsonList
          .map((str) => PendingMutation.fromMap(jsonDecode(str) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error reading pending sync queue: $e');
      return [];
    }
  }

  Future<void> enqueueMutation({
    required String entity,
    required String entityId,
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getPendingMutations();

      // Deduplicate: replace any older pending mutation for same entity & ID
      final updated = current
          .where((m) => !(m.entity == entity && m.id == entityId))
          .toList();

      updated.add(
        PendingMutation(
          id: entityId,
          entity: entity,
          action: action,
          payload: payload,
          createdAt: DateTime.now(),
        ),
      );

      final strList = updated.map((m) => jsonEncode(m.toMap())).toList();
      await prefs.setStringList(_keyPendingMutations, strList);
    } catch (e) {
      debugPrint('Error enqueuing sync mutation: $e');
    }
  }

  Future<DateTime?> getLastSyncedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyLastSyncedAt);
      if (str != null) return DateTime.parse(str);
    } catch (_) {}
    return null;
  }

  Future<void> _recordSyncSuccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _keyLastSyncedAt, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // DELTA SYNC ENGINE (Pushes only unsynced, pulls latest from cloud)
  // ---------------------------------------------------------------------------

  Future<T> _withTimeout<T>(Future<T> future) =>
      future.timeout(const Duration(seconds: 8));

  Future<SyncResult> performSync() async {
    if (client == null && AppConfig.isSupabaseConfigured) {
      try {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          publishableKey: AppConfig.supabaseKey,
        );
      } catch (_) {}
    }
    if (!canSync) {
      return const SyncResult(
        success: false,
        pushedCount: 0,
        message: 'Supabase cloud is not configured or offline.',
      );
    }

    final pending = await getPendingMutations();
    int pushedCount = 0;
    final remainingFailed = <PendingMutation>[];

    // Preload current local subjects & slots so foreign-key parent rows can be auto-upserted
    final localSubjects =
        await repository.loadCachedSubjects() ?? ClassRepository.mockSubjects;
    final localSlots =
        await repository.loadCachedSlots() ?? ClassRepository.mockSlots;
    final subjectById = {
      for (final s in localSubjects) UuidUtil.fromString(s.id): s,
    };
    final slotById = {
      for (final sl in localSlots) UuidUtil.fromString(sl.id): sl,
    };

    // 1. PUSH DELTAS: only process pending unsynced mutations with strict 8s timeout
    for (final mutation in pending) {
      bool success = false;
      try {
        switch (mutation.entity) {
          case 'subject':
            if (mutation.action == 'upsert' && mutation.payload != null) {
              final payload = Map<String, dynamic>.from(mutation.payload!);
              payload['id'] = UuidUtil.fromString(payload['id']?.toString() ?? mutation.id);
              await _withTimeout(client!.from('subjects').upsert(payload));
              success = true;
            } else if (mutation.action == 'delete') {
              final id = UuidUtil.fromString(mutation.id);
              await _withTimeout(client!.from('subjects').delete().eq('id', id));
              success = true;
            }
            break;

          case 'slot':
            if (mutation.action == 'upsert' && mutation.payload != null) {
              final payload = Map<String, dynamic>.from(mutation.payload!);
              payload['id'] = UuidUtil.fromString(payload['id']?.toString() ?? mutation.id);
              if (payload['subject_id'] != null) {
                final subId = UuidUtil.fromString(payload['subject_id'].toString());
                payload['subject_id'] = subId;
                final parentSub = subjectById[subId];
                if (parentSub != null) {
                  final subPayload = parentSub.toMap();
                  subPayload['id'] = subId;
                  try {
                    await _withTimeout(client!.from('subjects').upsert(subPayload));
                  } catch (_) {}
                }
              }
              await _withTimeout(client!.from('timetable_slots').upsert(payload));
              success = true;
            } else if (mutation.action == 'delete') {
              final id = UuidUtil.fromString(mutation.id);
              await _withTimeout(client!.from('timetable_slots').delete().eq('id', id));
              success = true;
            }
            break;

          case 'override':
            if (mutation.action == 'upsert' && mutation.payload != null) {
              final rawSlotId = mutation.payload!['slot_id']?.toString();
              final normSlotId = rawSlotId != null ? UuidUtil.fromString(rawSlotId) : null;
              final parentSlot = normSlotId != null ? slotById[normSlotId] : null;
              final parentSub = parentSlot != null
                  ? subjectById[UuidUtil.fromString(parentSlot.subjectId)]
                  : null;
              await _withTimeout(ClassRepository.upsertOverrideRow(
                client!,
                mutation.payload!,
                fallbackId: mutation.id,
                slot: parentSlot,
                subject: parentSub,
              ));
              success = true;
            } else if (mutation.action == 'delete') {
              final id = UuidUtil.fromString(mutation.id);
              await _withTimeout(client!.from('daily_overrides').delete().eq('id', id));
              success = true;
            }
            break;

          case 'assignment':
            if (mutation.action == 'upsert' && mutation.payload != null) {
              final rawSubId = mutation.payload!['subject_id']?.toString();
              if (rawSubId != null) {
                final parentSub = subjectById[UuidUtil.fromString(rawSubId)];
                if (parentSub != null) {
                  final subPayload = parentSub.toMap();
                  subPayload['id'] = UuidUtil.fromString(parentSub.id);
                  try {
                    await _withTimeout(client!.from('subjects').upsert(subPayload));
                  } catch (_) {}
                }
              }
              await _withTimeout(ClassRepository.upsertAssignmentRow(
                client!,
                mutation.payload!,
                fallbackId: mutation.id,
              ));
              success = true;
            } else if (mutation.action == 'delete') {
              final id = UuidUtil.fromString(mutation.id);
              await _withTimeout(client!.from('assignments').delete().eq('id', id));
              success = true;
            }
            break;

          case 'resource':
            if (mutation.action == 'upsert' && mutation.payload != null) {
              final rawSubId = mutation.payload!['subject_id']?.toString();
              final parentSub = rawSubId != null
                  ? subjectById[UuidUtil.fromString(rawSubId)]
                  : null;
              await _withTimeout(ClassRepository.upsertResourceRow(
                client!,
                mutation.payload!,
                fallbackId: mutation.id,
                subject: parentSub,
              ));
              success = true;
            } else if (mutation.action == 'delete') {
              final id = UuidUtil.fromString(mutation.id);
              await _withTimeout(client!.from('resources').delete().eq('id', id));
              success = true;
            }
            break;

          case 'timetable_image':
            if (mutation.action == 'upsert') {
              final url = mutation.payload?['url']?.toString() ?? '';
              final err = await _withTimeout(
                repository.saveOfficialTimetableImageUrl(
                  url,
                  fallbackSubject: localSubjects.firstOrNull,
                ),
              );
              success = err == null;
            } else if (mutation.action == 'delete') {
              final err = await _withTimeout(
                repository.clearOfficialTimetableImageUrl(),
              );
              success = err == null;
            }
            break;
        }
      } catch (e) {
        debugPrint('Sync failed for mutation ${mutation.entity} ${mutation.id}: $e');
        success = false;
      }

      if (success) {
        pushedCount++;
      } else {
        remainingFailed.add(mutation);
      }
    }

    // Save remaining failed mutations back to queue
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyPendingMutations,
      remainingFailed.map((m) => jsonEncode(m.toMap())).toList(),
    );

    // 2. PULL REMOTE UPDATES: Fetch cloud data and update local cache with timeout
    try {
      final remoteSubjects = await _withTimeout(repository.fetchSubjects());
      if (remoteSubjects != null) {
        await repository.cacheSubjects(remoteSubjects);
      }

      final remoteSlots = await _withTimeout(repository.fetchSlots());
      if (remoteSlots != null) {
        await repository.cacheSlots(remoteSlots);
      }

      final remoteOverrides = await _withTimeout(repository.fetchOverrides());
      if (remoteOverrides != null) {
        await repository.cacheOverrides(remoteOverrides);
      }

      final remoteResources = await _withTimeout(repository.fetchResources());
      if (remoteResources != null) {
        await repository.cacheResources(remoteResources);
      }

      final remoteAssignments = await _withTimeout(repository.fetchAssignments());
      if (remoteAssignments != null) {
        await repository.cacheAssignments(remoteAssignments);
      }

      final remoteQuizzes = await _withTimeout(repository.fetchQuizzes());
      if (remoteQuizzes != null) {
        await repository.cacheQuizzes(remoteQuizzes);
      }

      final remoteTimetable =
          await _withTimeout(repository.fetchOfficialTimetableImageUrl());
      if (remoteTimetable.fetched) {
        await repository.cacheTimetableImageUrl(remoteTimetable.url);
      }

      if (remainingFailed.isEmpty) {
        await _recordSyncSuccess();
      }
    } catch (e) {
      debugPrint('Error pulling remote updates during sync: $e');
    }

    final message = remainingFailed.isNotEmpty
        ? 'Sync complete with issues: ${remainingFailed.length} changes remain queued (check network or Supabase connection).'
        : (pushedCount > 0
            ? 'Successfully pushed $pushedCount local changes to Supabase cloud.'
            : 'All data is in sync with cloud.');

    return SyncResult(
      success: remainingFailed.isEmpty,
      pushedCount: pushedCount,
      message: message,
    );
  }
}

class SyncResult {
  final bool success;
  final int pushedCount;
  final String message;

  const SyncResult({
    required this.success,
    required this.pushedCount,
    required this.message,
  });
}
