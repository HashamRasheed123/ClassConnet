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
  final SupabaseClient? client;

  SyncService({
    required this.repository,
    this.client,
  });

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
                payload['subject_id'] = UuidUtil.fromString(payload['subject_id'].toString());
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
              final payload = Map<String, dynamic>.from(mutation.payload!);
              payload['id'] = UuidUtil.fromString(payload['id']?.toString() ?? mutation.id);
              if (payload['slot_id'] != null) {
                payload['slot_id'] = UuidUtil.fromString(payload['slot_id'].toString());
              }
              if (payload['reported_by'] != null && !UuidUtil.isValidUuid(payload['reported_by'].toString())) {
                payload.remove('reported_by');
              }
              try {
                await _withTimeout(client!.from('daily_overrides').upsert(payload));
              } catch (e) {
                if (e.toString().contains('column') || e.toString().contains('PGRST204')) {
                  final fallback = Map<String, dynamic>.from(payload)
                    ..remove('actual_start_time')
                    ..remove('actual_end_time')
                    ..remove('rescheduled_date');
                  await _withTimeout(client!.from('daily_overrides').upsert(fallback));
                } else {
                  rethrow;
                }
              }
              success = true;
            } else if (mutation.action == 'delete') {
              final id = UuidUtil.fromString(mutation.id);
              await _withTimeout(client!.from('daily_overrides').delete().eq('id', id));
              success = true;
            }
            break;

          case 'resource':
            if (mutation.action == 'upsert' && mutation.payload != null) {
              final payload = Map<String, dynamic>.from(mutation.payload!);
              payload['id'] = UuidUtil.fromString(payload['id']?.toString() ?? mutation.id);
              if (payload['subject_id'] != null) {
                payload['subject_id'] = UuidUtil.fromString(payload['subject_id'].toString());
              }
              if (payload['uploader_id'] != null && !UuidUtil.isValidUuid(payload['uploader_id'].toString())) {
                payload.remove('uploader_id');
              }
              await _withTimeout(client!.from('resources').upsert(payload));
              success = true;
            } else if (mutation.action == 'delete') {
              final id = UuidUtil.fromString(mutation.id);
              await _withTimeout(client!.from('resources').delete().eq('id', id));
              success = true;
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
