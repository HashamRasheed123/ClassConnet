import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import '../core/utils/uuid_util.dart';
import '../models/models.dart';

/// Hybrid repository supporting both instant offline mock mode and live Supabase.
class ClassRepository {
  final SupabaseClient? client;

  ClassRepository({this.client});

  bool get isLiveSupabase => client != null && AppConfig.isSupabaseConfigured;

  // ===================================================================
  // MOCK SEED DATA (High quality university data)
  // ===================================================================

  static final List<SubjectModel> mockSubjects = [
    const SubjectModel(
      id: '11111111-1111-1111-1111-111111111111',
      name: 'Object Oriented Programming',
      code: 'CS201',
      professor: 'Dr. Sarah Mitchell',
      minAttendancePct: 75,
      colorHex: '#6D28D9',
    ),
    const SubjectModel(
      id: '22222222-2222-2222-2222-222222222222',
      name: 'Data Structures & Algorithms',
      code: 'CS204',
      professor: 'Prof. Alan Vance',
      minAttendancePct: 75,
      colorHex: '#4C1D95',
    ),
    const SubjectModel(
      id: '33333333-3333-3333-3333-333333333333',
      name: 'Digital Logic & Computer Design',
      code: 'EE210',
      professor: 'Dr. Elena Rostova',
      minAttendancePct: 75,
      colorHex: '#059669',
    ),
    const SubjectModel(
      id: '44444444-4444-4444-4444-444444444444',
      name: 'Linear Algebra & Discrete Math',
      code: 'MA105',
      professor: 'Prof. David Chen',
      minAttendancePct: 75,
      colorHex: '#D97706',
    ),
  ];

  static List<TimetableSlotModel> get mockSlots {
    return [
      // Monday (1)
      const TimetableSlotModel(id: 'a0000001-0000-0000-0000-000000000001', subjectId: '11111111-1111-1111-1111-111111111111', dayOfWeek: 1, startTime: '09:00', endTime: '10:15', defaultRoom: 'Hall A-102'),
      const TimetableSlotModel(id: 'a0000002-0000-0000-0000-000000000002', subjectId: '22222222-2222-2222-2222-222222222222', dayOfWeek: 1, startTime: '10:30', endTime: '11:45', defaultRoom: 'Lab 3 (Ground Floor)'),
      const TimetableSlotModel(id: 'a0000003-0000-0000-0000-000000000003', subjectId: '33333333-3333-3333-3333-333333333333', dayOfWeek: 1, startTime: '13:00', endTime: '14:15', defaultRoom: 'Seminar Room 4'),

      // Tuesday (2)
      const TimetableSlotModel(id: 'a0000004-0000-0000-0000-000000000004', subjectId: '44444444-4444-4444-4444-444444444444', dayOfWeek: 2, startTime: '09:00', endTime: '10:15', defaultRoom: 'Room 204'),
      const TimetableSlotModel(id: 'a0000005-0000-0000-0000-000000000005', subjectId: '11111111-1111-1111-1111-111111111111', dayOfWeek: 2, startTime: '11:00', endTime: '12:15', defaultRoom: 'Hall A-102'),

      // Wednesday (3)
      const TimetableSlotModel(id: 'a0000006-0000-0000-0000-000000000006', subjectId: '22222222-2222-2222-2222-222222222222', dayOfWeek: 3, startTime: '09:30', endTime: '10:45', defaultRoom: 'Lab 3'),
      const TimetableSlotModel(id: 'a0000007-0000-0000-0000-000000000007', subjectId: '33333333-3333-3333-3333-333333333333', dayOfWeek: 3, startTime: '11:15', endTime: '12:30', defaultRoom: 'Seminar Room 4'),

      // Thursday (4)
      const TimetableSlotModel(id: 'a0000008-0000-0000-0000-000000000008', subjectId: '44444444-4444-4444-4444-444444444444', dayOfWeek: 4, startTime: '10:00', endTime: '11:15', defaultRoom: 'Room 204'),
      const TimetableSlotModel(id: 'a0000009-0000-0000-0000-000000000009', subjectId: '11111111-1111-1111-1111-111111111111', dayOfWeek: 4, startTime: '12:00', endTime: '13:15', defaultRoom: 'Hall A-102'),

      // Friday (5)
      const TimetableSlotModel(id: 'a0000010-0000-0000-0000-000000000010', subjectId: '22222222-2222-2222-2222-222222222222', dayOfWeek: 5, startTime: '09:00', endTime: '10:15', defaultRoom: 'Lab 3'),
      const TimetableSlotModel(id: 'a0000011-0000-0000-0000-000000000011', subjectId: '44444444-4444-4444-4444-444444444444', dayOfWeek: 5, startTime: '10:30', endTime: '11:45', defaultRoom: 'Room 204'),

      // Saturday (6)
      const TimetableSlotModel(id: 'a0000012-0000-0000-0000-000000000012', subjectId: '33333333-3333-3333-3333-333333333333', dayOfWeek: 6, startTime: '10:00', endTime: '11:30', defaultRoom: 'Hardware Lab'),
    ];
  }

  static List<ResourceModel> get mockResources {
    final now = DateTime.now();
    return [
      ResourceModel(
        id: 'b0000001-0000-0000-0000-000000000001',
        subjectId: '11111111-1111-1111-1111-111111111111',
        date: now.subtract(const Duration(days: 1)),
        uploaderName: 'Sarah K.',
        title: 'Complete UML Class & Sequence Diagrams Revision Guide',
        type: ResourceType.pdf,
        url: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        upvotes: 42,
        costCredits: 5,
        isApproved: true,
        isUnlocked: true,
      ),
      ResourceModel(
        id: 'b0000002-0000-0000-0000-000000000002',
        subjectId: '22222222-2222-2222-2222-222222222222',
        date: now.subtract(const Duration(days: 2)),
        uploaderName: 'Alex T.',
        title: 'Binary Search Trees & AVL Rotations Handwritten Notes',
        type: ResourceType.pdf,
        url: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        upvotes: 38,
        costCredits: 5,
        isApproved: true,
        isUnlocked: false,
      ),
      ResourceModel(
        id: 'b0000003-0000-0000-0000-000000000003',
        subjectId: '22222222-2222-2222-2222-222222222222',
        date: now.subtract(const Duration(days: 3)),
        uploaderName: 'Prof. Vance Lecture Stream',
        title: 'Graph Traversals: BFS, DFS & Dijkstra Algorithm Explained',
        type: ResourceType.youtube,
        url: 'https://www.youtube.com/watch?v=pcKY4hjDrxk',
        upvotes: 56,
        costCredits: 5,
        isApproved: true,
        isUnlocked: false,
      ),
      ResourceModel(
        id: 'res-4',
        subjectId: 'sub-3',
        date: now.subtract(const Duration(days: 4)),
        uploaderName: 'Elena R.',
        title: 'Karnaugh Maps & SOP/POS Simplification Quick Sheet',
        type: ResourceType.image,
        url: 'https://images.unsplash.com/photo-1517842645767-c639042777db?w=800',
        upvotes: 19,
        costCredits: 5,
        isApproved: true,
        isUnlocked: false,
      ),
      ResourceModel(
        id: 'res-5',
        subjectId: 'sub-4',
        date: now.subtract(const Duration(days: 5)),
        uploaderName: 'Devon L.',
        title: 'Eigenvalues, Eigenvectors & Matrix Transformation Cheatsheet',
        type: ResourceType.pdf,
        url: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        upvotes: 27,
        costCredits: 5,
        isApproved: true,
        isUnlocked: false,
      ),
      // Pending submission for Mod Queue demo
      ResourceModel(
        id: 'res-pending-1',
        subjectId: 'sub-1',
        date: now,
        uploaderName: 'Marcus Wright',
        title: 'Design Patterns: Factory, Singleton & Observer in Dart',
        type: ResourceType.pdf,
        url: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        upvotes: 0,
        costCredits: 5,
        isApproved: false,
        isUnlocked: false,
      ),
    ];
  }

  static List<UserModel> get mockLeaderboard => const [];

  static Map<String, AttendanceRecord> get initialAttendance {
    return {
      '11111111-1111-1111-1111-111111111111': const AttendanceRecord(subjectId: '11111111-1111-1111-1111-111111111111', attended: 19, total: 22), // 86.3%
      '22222222-2222-2222-2222-222222222222': const AttendanceRecord(subjectId: '22222222-2222-2222-2222-222222222222', attended: 14, total: 20), // 70.0% (Danger)
      '33333333-3333-3333-3333-333333333333': const AttendanceRecord(subjectId: '33333333-3333-3333-3333-333333333333', attended: 21, total: 24), // 87.5%
      '44444444-4444-4444-4444-444444444444': const AttendanceRecord(subjectId: '44444444-4444-4444-4444-444444444444', attended: 17, total: 21), // 80.9%
      // Backwards compatibility with sub-1..sub-4
      'sub-1': const AttendanceRecord(subjectId: '11111111-1111-1111-1111-111111111111', attended: 19, total: 22),
      'sub-2': const AttendanceRecord(subjectId: '22222222-2222-2222-2222-222222222222', attended: 14, total: 20),
      'sub-3': const AttendanceRecord(subjectId: '33333333-3333-3333-3333-333333333333', attended: 21, total: 24),
      'sub-4': const AttendanceRecord(subjectId: '44444444-4444-4444-4444-444444444444', attended: 17, total: 21),
    };
  }

  // ===================================================================
  // LOCAL CACHING & OFFLINE-FIRST PERSISTENCE (SharedPreferences)
  // Ensures changes survive app restarts immediately even without cloud connection.
  // ===================================================================

  static const String _keySubjects = 'cached_admin_subjects';
  static const String _keySlots = 'cached_admin_slots';
  static const String _keyOverrides = 'cached_admin_overrides';
  static const String _keyResources = 'cached_admin_resources';
  static const String _keyAssignments = 'cached_admin_assignments';

  // Synchronous In-Memory Cache (Avoids async flash of mock data)
  static List<SubjectModel>? memorySubjects;
  static List<TimetableSlotModel>? memorySlots;
  static List<DailyOverrideModel>? memoryOverrides;
  static List<ResourceModel>? memoryResources;
  static List<AssignmentModel>? memoryAssignments;
  static bool hasPreloaded = false;

  /// Preloads cached state into memory at app startup before widgets build
  static Future<void> preloadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final subJson = prefs.getString(_keySubjects);
      if (subJson != null) {
        final list = jsonDecode(subJson) as List;
        memorySubjects = list.map((m) {
          final sub = SubjectModel.fromMap(m as Map<String, dynamic>);
          return sub.copyWith(id: UuidUtil.fromString(sub.id));
        }).toList();
      }

      final slotJson = prefs.getString(_keySlots);
      if (slotJson != null) {
        final list = jsonDecode(slotJson) as List;
        memorySlots = list.map((m) {
          final slot = TimetableSlotModel.fromMap(m as Map<String, dynamic>);
          return slot.copyWith(
            id: UuidUtil.fromString(slot.id),
            subjectId: UuidUtil.fromString(slot.subjectId),
          );
        }).toList();
      }

      final ovJson = prefs.getString(_keyOverrides);
      if (ovJson != null) {
        final list = jsonDecode(ovJson) as List;
        memoryOverrides = list
            .map((m) => DailyOverrideModel.fromMap(m as Map<String, dynamic>))
            .toList();
      } else {
        memoryOverrides = [];
      }

      final resJson = prefs.getString(_keyResources);
      if (resJson != null) {
        final list = jsonDecode(resJson) as List;
        memoryResources = list
            .map((m) => ResourceModel.fromMap(m as Map<String, dynamic>))
            .toList();
      }

      final assignJson = prefs.getString(_keyAssignments);
      if (assignJson != null) {
        final list = jsonDecode(assignJson) as List;
        memoryAssignments = list
            .map((m) => AssignmentModel.fromMap(m as Map<String, dynamic>))
            .toList();
      }

      hasPreloaded = true;
    } catch (e) {
      debugPrint('Error preloading ClassRepository cache: $e');
    }
  }

  Future<List<SubjectModel>?> loadCachedSubjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keySubjects);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        final loaded = list.map((m) {
          final sub = SubjectModel.fromMap(m as Map<String, dynamic>);
          return sub.copyWith(id: UuidUtil.fromString(sub.id));
        }).toList();
        memorySubjects = loaded;
        return loaded;
      }
    } catch (e) {
      debugPrint('Error loading cached subjects: $e');
    }
    return memorySubjects;
  }

  Future<void> cacheSubjects(List<SubjectModel> subjects) async {
    memorySubjects = subjects;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(subjects.map((s) => s.toMap()).toList());
      await prefs.setString(_keySubjects, jsonStr);
    } catch (e) {
      debugPrint('Error caching subjects: $e');
    }
  }

  Future<List<TimetableSlotModel>?> loadCachedSlots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keySlots);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        final loaded = list.map((m) {
          final slot = TimetableSlotModel.fromMap(m as Map<String, dynamic>);
          return slot.copyWith(
            id: UuidUtil.fromString(slot.id),
            subjectId: UuidUtil.fromString(slot.subjectId),
          );
        }).toList();
        memorySlots = loaded;
        return loaded;
      }
    } catch (e) {
      debugPrint('Error loading cached slots: $e');
    }
    return memorySlots;
  }

  Future<void> cacheSlots(List<TimetableSlotModel> slots) async {
    memorySlots = slots;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(slots.map((s) => s.toMap()).toList());
      await prefs.setString(_keySlots, jsonStr);
    } catch (e) {
      debugPrint('Error caching slots: $e');
    }
  }

  Future<List<DailyOverrideModel>?> loadCachedOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyOverrides);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        final loaded = list
            .map((m) => DailyOverrideModel.fromMap(m as Map<String, dynamic>))
            .toList();
        memoryOverrides = loaded;
        return loaded;
      }
    } catch (e) {
      debugPrint('Error loading cached overrides: $e');
    }
    return memoryOverrides;
  }

  Future<void> cacheOverrides(List<DailyOverrideModel> overrides) async {
    memoryOverrides = overrides;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(overrides.map((o) => o.toMap()).toList());
      await prefs.setString(_keyOverrides, jsonStr);
    } catch (e) {
      debugPrint('Error caching overrides: $e');
    }
  }

  Future<List<ResourceModel>?> loadCachedResources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyResources);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        final loaded = list
            .map((m) => ResourceModel.fromMap(m as Map<String, dynamic>))
            .toList();
        memoryResources = loaded;
        return loaded;
      }
    } catch (e) {
      debugPrint('Error loading cached resources: $e');
    }
    return memoryResources;
  }

  Future<void> cacheResources(List<ResourceModel> resources) async {
    memoryResources = resources;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(resources.map((r) => r.toMap()).toList());
      await prefs.setString(_keyResources, jsonStr);
    } catch (e) {
      debugPrint('Error caching resources: $e');
    }
  }

  Future<List<AssignmentModel>?> loadCachedAssignments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyAssignments);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        final loaded = list
            .map((m) => AssignmentModel.fromMap(m as Map<String, dynamic>))
            .toList();
        memoryAssignments = loaded;
        return loaded;
      }
    } catch (e) {
      debugPrint('Error loading cached assignments: $e');
    }
    return memoryAssignments;
  }

  Future<void> cacheAssignments(List<AssignmentModel> assignments) async {
    memoryAssignments = assignments;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(assignments.map((a) => a.toMap()).toList());
      await prefs.setString(_keyAssignments, jsonStr);
    } catch (e) {
      debugPrint('Error caching assignments: $e');
    }
  }

  // ===================================================================
  // LIVE SUPABASE INTEGRATION METHODS
  // Syncs seamlessly with PostgreSQL database when online.
  // ===================================================================

  Future<List<SubjectModel>?> fetchSubjects() async {
    if (!isLiveSupabase) return null;
    try {
      final rows = await client!
          .from('subjects')
          .select()
          .timeout(const Duration(seconds: 8));
      return (rows as List).map((r) => SubjectModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error fetching subjects from Supabase: $e');
      return null;
    }
  }

  Future<List<TimetableSlotModel>?> fetchSlots() async {
    if (!isLiveSupabase) return null;
    try {
      final rows = await client!
          .from('timetable_slots')
          .select()
          .timeout(const Duration(seconds: 8));
      return (rows as List).map((r) => TimetableSlotModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error fetching slots from Supabase: $e');
      return null;
    }
  }

  Future<List<DailyOverrideModel>?> fetchOverrides() async {
    if (!isLiveSupabase) return null;
    try {
      final rows = await client!
          .from('daily_overrides')
          .select()
          .timeout(const Duration(seconds: 8));
      return (rows as List).map((r) => DailyOverrideModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error fetching daily overrides from Supabase: $e');
      return null;
    }
  }

  Future<List<ResourceModel>?> fetchResources() async {
    if (!isLiveSupabase) return null;
    try {
      final rows = await client!
          .from('resources')
          .select()
          .timeout(const Duration(seconds: 8));
      return (rows as List).map((r) => ResourceModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error fetching resources from Supabase: $e');
      return null;
    }
  }

  Future<void> createSubject(SubjectModel subject) async {
    if (!isLiveSupabase) return;
    try {
      final payload = Map<String, dynamic>.from(subject.toMap());
      payload['id'] = UuidUtil.fromString(payload['id']?.toString() ?? subject.id);
      await client!
          .from('subjects')
          .insert(payload)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error inserting subject in Supabase: $e');
    }
  }

  Future<void> updateSubject(SubjectModel subject) async {
    if (!isLiveSupabase) return;
    try {
      final payload = Map<String, dynamic>.from(subject.toMap());
      final validId = UuidUtil.fromString(payload['id']?.toString() ?? subject.id);
      payload['id'] = validId;
      await client!
          .from('subjects')
          .update(payload)
          .eq('id', validId)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error updating subject in Supabase: $e');
    }
  }

  Future<void> deleteSubject(String subjectId) async {
    if (!isLiveSupabase) return;
    try {
      final validId = UuidUtil.fromString(subjectId);
      await client!
          .from('subjects')
          .delete()
          .eq('id', validId)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error deleting subject in Supabase: $e');
    }
  }

  Future<void> createSlot(TimetableSlotModel slot) async {
    if (!isLiveSupabase) return;
    try {
      final payload = Map<String, dynamic>.from(slot.toMap());
      payload['id'] = UuidUtil.fromString(payload['id']?.toString() ?? slot.id);
      if (payload['subject_id'] != null) {
        payload['subject_id'] = UuidUtil.fromString(payload['subject_id'].toString());
      }
      await client!
          .from('timetable_slots')
          .insert(payload)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error creating timetable slot in Supabase: $e');
    }
  }

  Future<void> updateSlot(TimetableSlotModel slot) async {
    if (!isLiveSupabase) return;
    try {
      final payload = Map<String, dynamic>.from(slot.toMap());
      final validId = UuidUtil.fromString(payload['id']?.toString() ?? slot.id);
      payload['id'] = validId;
      if (payload['subject_id'] != null) {
        payload['subject_id'] = UuidUtil.fromString(payload['subject_id'].toString());
      }
      await client!
          .from('timetable_slots')
          .update(payload)
          .eq('id', validId)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error updating timetable slot in Supabase: $e');
    }
  }

  Future<void> deleteSlot(String slotId) async {
    if (!isLiveSupabase) return;
    try {
      final validId = UuidUtil.fromString(slotId);
      await client!
          .from('timetable_slots')
          .delete()
          .eq('id', validId)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error deleting timetable slot in Supabase: $e');
    }
  }

  Future<void> saveOverride(DailyOverrideModel override) async {
    if (!isLiveSupabase) return;
    try {
      final payload = Map<String, dynamic>.from(override.toMap());
      payload['id'] = UuidUtil.fromString(payload['id']?.toString() ?? override.id);
      if (payload['slot_id'] != null) {
        payload['slot_id'] = UuidUtil.fromString(payload['slot_id'].toString());
      }
      if (payload['reported_by'] != null && !UuidUtil.isValidUuid(payload['reported_by'].toString())) {
        payload.remove('reported_by');
      }
      try {
        await client!
            .from('daily_overrides')
            .upsert(payload)
            .timeout(const Duration(seconds: 8));
      } catch (upsertErr) {
        final errStr = upsertErr.toString().toLowerCase();
        if (errStr.contains('pgrst204') || errStr.contains('column') || errStr.contains('not found')) {
          final fallback = Map<String, dynamic>.from(payload)
            ..remove('actual_start_time')
            ..remove('actual_end_time')
            ..remove('rescheduled_date');
          await client!
              .from('daily_overrides')
              .upsert(fallback)
              .timeout(const Duration(seconds: 8));
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Error saving override in Supabase: $e');
    }
  }

  Future<void> deleteOverride(String overrideId) async {
    if (!isLiveSupabase) return;
    try {
      final validId = UuidUtil.fromString(overrideId);
      await client!
          .from('daily_overrides')
          .delete()
          .eq('id', validId)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error deleting override in Supabase: $e');
    }
  }

  Future<void> saveResource(ResourceModel resource) async {
    if (!isLiveSupabase) return;
    try {
      final payload = Map<String, dynamic>.from(resource.toMap());
      payload['id'] = UuidUtil.fromString(payload['id']?.toString() ?? resource.id);
      if (payload['subject_id'] != null) {
        payload['subject_id'] = UuidUtil.fromString(payload['subject_id'].toString());
      }
      if (payload['uploader_id'] != null && !UuidUtil.isValidUuid(payload['uploader_id'].toString())) {
        payload.remove('uploader_id');
      }
      await client!
          .from('resources')
          .upsert(payload)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error saving resource in Supabase: $e');
    }
  }

  Future<void> deleteResource(String resourceId) async {
    if (!isLiveSupabase) return;
    try {
      final validId = UuidUtil.fromString(resourceId);
      await client!
          .from('resources')
          .delete()
          .eq('id', validId)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error deleting resource in Supabase: $e');
    }
  }

  // ===================================================================
  // ASSIGNMENTS INTEGRATION
  // ===================================================================

  Future<List<AssignmentModel>?> fetchAssignments() async {
    if (!isLiveSupabase) return null;
    try {
      final rows = await client!
          .from('assignments')
          .select()
          .order('deadline', ascending: true)
          .timeout(const Duration(seconds: 8));
      return (rows as List).map((r) => AssignmentModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('Error fetching assignments from Supabase: $e');
      return null;
    }
  }

  Future<void> saveAssignment(AssignmentModel assignment) async {
    if (!isLiveSupabase) return;
    try {
      final payload = Map<String, dynamic>.from(assignment.toMap());
      payload['id'] =
          UuidUtil.fromString(payload['id']?.toString() ?? assignment.id);
      if (payload['subject_id'] != null) {
        payload['subject_id'] =
            UuidUtil.fromString(payload['subject_id'].toString());
      }
      await client!
          .from('assignments')
          .upsert(payload)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error saving assignment in Supabase: $e');
    }
  }

  Future<void> deleteAssignment(String assignmentId) async {
    if (!isLiveSupabase) return;
    try {
      final validId = UuidUtil.fromString(assignmentId);
      await client!
          .from('assignments')
          .delete()
          .eq('id', validId)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error deleting assignment in Supabase: $e');
    }
  }
}
