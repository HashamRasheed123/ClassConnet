import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import '../core/utils/uuid_util.dart';
import '../models/models.dart';

/// Hybrid repository supporting both instant offline mock mode and live Supabase.
class ClassRepository {
  final SupabaseClient? _injectedClient;

  ClassRepository({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient? get client {
    if (_injectedClient != null) return _injectedClient;
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

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

  static List<QuizModel> get mockQuizzes => const [];

  static Map<String, AttendanceRecord> get initialAttendance => const {};

  // ===================================================================
  // LOCAL CACHING & OFFLINE-FIRST PERSISTENCE (SharedPreferences)
  // Ensures changes survive app restarts immediately even without cloud connection.
  // ===================================================================

  static const String _keySubjects = 'cached_admin_subjects';
  static const String _keySlots = 'cached_admin_slots';
  static const String _keyOverrides = 'cached_admin_overrides';
  static const String _keyResources = 'cached_admin_resources';
  static const String _keyAssignments = 'cached_admin_assignments';
  static const String _keyQuizzes = 'cached_admin_quizzes';
  static const String _keyBounties = 'cached_note_bounties_v1';
  static const String keyTimetableImg = 'key_official_timetable_image_url_v2';
  static const String timetableImageUrlPrefix = 'cctimetable://';
  static final String timetableImageResourceId =
      UuidUtil.fromString('official_timetable_sheet_image_v1');

  // Synchronous In-Memory Cache (Avoids async flash of mock data)
  static List<SubjectModel>? memorySubjects;
  static List<TimetableSlotModel>? memorySlots;
  static List<DailyOverrideModel>? memoryOverrides;
  static List<ResourceModel>? memoryResources;
  static List<AssignmentModel>? memoryAssignments;
  static List<QuizModel>? memoryQuizzes;
  static List<NoteBountyModel>? memoryBounties;
  static String? memoryTimetableImageUrl;
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

      final quizJson = prefs.getString(_keyQuizzes);
      if (quizJson != null) {
        final list = jsonDecode(quizJson) as List;
        memoryQuizzes = list
            .map((m) => QuizModel.fromMap(m as Map<String, dynamic>))
            .toList();
      }

      final bountyJson = prefs.getString(_keyBounties);
      if (bountyJson != null) {
        final list = jsonDecode(bountyJson) as List;
        memoryBounties = list
            .map((m) => NoteBountyModel.fromMap(m as Map<String, dynamic>))
            .toList();
      }

      memoryTimetableImageUrl = prefs.getString(keyTimetableImg);

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

  Future<List<QuizModel>?> loadCachedQuizzes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyQuizzes);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        final loaded = list
            .map((m) => QuizModel.fromMap(m as Map<String, dynamic>))
            .toList();
        memoryQuizzes = loaded;
        return loaded;
      }
    } catch (e) {
      debugPrint('Error loading cached quizzes: $e');
    }
    return memoryQuizzes;
  }

  Future<void> cacheQuizzes(List<QuizModel> quizzes) async {
    memoryQuizzes = quizzes;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(quizzes.map((q) => q.toMap()).toList());
      await prefs.setString(_keyQuizzes, jsonStr);
    } catch (e) {
      debugPrint('Error caching quizzes: $e');
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
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .where((r) {
            final url = r['url'] as String? ?? '';
            return !url.startsWith(QuizModel.resourceUrlPrefix) &&
                !url.startsWith(
                    StudentVerificationRequestModel.resourceUrlPrefix) &&
                !url.startsWith(NoteBountyModel.resourceUrlPrefix) &&
                !url.startsWith(timetableImageUrlPrefix);
          })
          .map((r) => ResourceModel.fromMap(r))
          .toList();
    } catch (e) {
      debugPrint('Error fetching resources from Supabase: $e');
      return null;
    }
  }

  // ===================================================================
  // OFFICIAL TIMETABLE IMAGE SYNC (Supabase Cloud + Local Cache)
  // ===================================================================

  Future<String?> loadCachedTimetableImageUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(keyTimetableImg);
      memoryTimetableImageUrl = (url != null && url.trim().isNotEmpty) ? url : null;
      return memoryTimetableImageUrl;
    } catch (e) {
      debugPrint('Error loading cached timetable image: $e');
      return memoryTimetableImageUrl;
    }
  }

  Future<void> cacheTimetableImageUrl(String? url) async {
    final clean = (url != null && url.trim().isNotEmpty) ? url.trim() : null;
    memoryTimetableImageUrl = clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (clean == null) {
        await prefs.remove(keyTimetableImg);
      } else {
        await prefs.setString(keyTimetableImg, clean);
      }
    } catch (e) {
      debugPrint('Error caching timetable image: $e');
    }
  }

  Future<({bool fetched, String? url})> fetchOfficialTimetableImageUrl() async {
    if (!isLiveSupabase) return (fetched: false, url: null);
    try {
      Map<String, dynamic>? row = await client!
          .from('resources')
          .select('url')
          .eq('id', timetableImageResourceId)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      if (row == null) {
        final rows = await client!
            .from('resources')
            .select('url')
            .like('url', '$timetableImageUrlPrefix%')
            .limit(1)
            .timeout(const Duration(seconds: 8));
        if (rows.isNotEmpty) {
          row = rows.first;
        }
      }
      if (row == null) {
        return (fetched: true, url: null);
      }
      final rawUrl = row['url']?.toString() ?? '';
      if (!rawUrl.startsWith(timetableImageUrlPrefix)) {
        return (fetched: true, url: null);
      }
      final clean = rawUrl.substring(timetableImageUrlPrefix.length).trim();
      return (fetched: true, url: clean.isEmpty ? null : clean);
    } catch (e) {
      debugPrint('Error fetching official timetable image: $e');
      return (fetched: false, url: null);
    }
  }

  Future<String?> saveOfficialTimetableImageUrl(
    String displayUrl, {
    SubjectModel? fallbackSubject,
  }) async {
    if (!isLiveSupabase) {
      return 'Supabase is not configured, saved on this device only.';
    }
    final cleanUrl = displayUrl.trim();
    if (cleanUrl.isEmpty) {
      return clearOfficialTimetableImageUrl();
    }
    try {
      final targetSub = fallbackSubject ?? mockSubjects.first;
      final subjectId = UuidUtil.fromString(targetSub.id);
      final payload = <String, dynamic>{
        'id': timetableImageResourceId,
        'subject_id': subjectId,
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'uploader_name': 'Admin',
        'title': 'Official Class Timetable Sheet',
        'type': 'image',
        'url': '$timetableImageUrlPrefix$cleanUrl',
        'upvotes': 0,
        'cost_credits': 0,
        'is_approved': true,
      };
      try {
        await client!
            .from('resources')
            .upsert(payload)
            .timeout(const Duration(seconds: 8));
        return null;
      } catch (e) {
        final s = e.toString().toLowerCase();
        if ((s.contains('23503') || s.contains('foreign key')) &&
            s.contains('subject')) {
          final subPayload = Map<String, dynamic>.from(targetSub.toMap());
          subPayload['id'] = subjectId;
          await client!
              .from('subjects')
              .upsert(subPayload)
              .timeout(const Duration(seconds: 8));
          await client!
              .from('resources')
              .upsert(payload)
              .timeout(const Duration(seconds: 8));
          return null;
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('Error saving official timetable image in Supabase: $e');
      return _friendlyDbError(e);
    }
  }

  Future<String?> clearOfficialTimetableImageUrl() async {
    if (!isLiveSupabase) return null;
    try {
      await client!
          .from('resources')
          .delete()
          .eq('id', timetableImageResourceId)
          .timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('Error deleting official timetable image in Supabase: $e');
      return _friendlyDbError(e);
    }
  }

  Future<List<QuizModel>?> fetchQuizzes() async {
    if (!isLiveSupabase) return null;
    try {
      final rows = await client!
          .from('resources')
          .select()
          .like('url', '${QuizModel.resourceUrlPrefix}%')
          .timeout(const Duration(seconds: 8));
      final quizzes = <QuizModel>[];
      for (final raw in (rows as List)) {
        if (raw is Map<String, dynamic>) {
          final parsed = QuizModel.tryFromResourceMap(raw);
          if (parsed != null) quizzes.add(parsed);
        }
      }
      quizzes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return quizzes;
    } catch (e) {
      debugPrint('Error fetching quizzes from Supabase: $e');
      return null;
    }
  }

  Future<String?> saveQuiz(
    QuizModel quiz, {
    SubjectModel? subject,
  }) async {
    if (!isLiveSupabase) return null;
    try {
      var payload = quiz.toResourcePayload();
      payload['id'] = UuidUtil.fromString(quiz.id);
      payload['subject_id'] = UuidUtil.fromString(quiz.subjectId);
      payload.remove('uploader_id');

      bool ensuredSubject = false;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          await client!
              .from('resources')
              .upsert(payload)
              .timeout(const Duration(seconds: 8));
          return null;
        } catch (e) {
          final s = e.toString().toLowerCase();
          final isFk = s.contains('23503') || s.contains('foreign key');
          if (isFk &&
              s.contains('subject') &&
              !ensuredSubject &&
              subject != null) {
            ensuredSubject = true;
            try {
              final subPayload = Map<String, dynamic>.from(subject.toMap());
              subPayload['id'] = UuidUtil.fromString(subject.id);
              await client!
                  .from('subjects')
                  .upsert(subPayload)
                  .timeout(const Duration(seconds: 8));
              continue;
            } catch (_) {}
          }
          rethrow;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error saving quiz in Supabase: $e');
      return _friendlyDbError(e);
    }
  }

  Future<String?> deleteQuiz(String quizId) async {
    if (!isLiveSupabase) return null;
    try {
      final validId = UuidUtil.fromString(quizId);
      await client!
          .from('resources')
          .delete()
          .eq('id', validId)
          .timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('Error deleting quiz in Supabase: $e');
      return _friendlyDbError(e);
    }
  }

  // ===================================================================
  // NOTE BOUNTIES (Dedicated Table + RPC with ccbounty:// Fallback)
  // ===================================================================

  Future<List<NoteBountyModel>?> loadCachedBounties() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyBounties);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        final loaded = list
            .map((m) => NoteBountyModel.fromMap(m as Map<String, dynamic>))
            .toList();
        memoryBounties = loaded;
        return loaded;
      }
    } catch (e) {
      debugPrint('Error loading cached bounties: $e');
    }
    return memoryBounties;
  }

  Future<void> cacheBounties(List<NoteBountyModel> bounties) async {
    memoryBounties = bounties;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(bounties.map((b) => b.toMap()).toList());
      await prefs.setString(_keyBounties, jsonStr);
    } catch (e) {
      debugPrint('Error caching bounties: $e');
    }
  }

  Future<List<NoteBountyModel>?> fetchNoteBounties() async {
    if (!isLiveSupabase) return null;
    try {
      final rows = await client!
          .from('note_bounties')
          .select()
          .timeout(const Duration(seconds: 8));
      final list = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(NoteBountyModel.fromMap)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      // Fallback to zero-migration ccbounty:// rows in public.resources
      try {
        final rows = await client!
            .from('resources')
            .select()
            .like('url', '${NoteBountyModel.resourceUrlPrefix}%')
            .timeout(const Duration(seconds: 8));
        final list = <NoteBountyModel>[];
        for (final raw in (rows as List)) {
          if (raw is Map<String, dynamic>) {
            final parsed = NoteBountyModel.tryFromResourceMap(raw);
            if (parsed != null) list.add(parsed);
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      } catch (e) {
        debugPrint('Error fetching note bounties from Supabase: $e');
        return null;
      }
    }
  }

  Future<void> _saveBountyResourceFallback(NoteBountyModel bounty) async {
    if (!isLiveSupabase) return;
    try {
      final payload = bounty.toResourcePayload();
      payload['id'] = UuidUtil.fromString(bounty.id);
      payload['subject_id'] = UuidUtil.fromString(
        bounty.subjectId.isNotEmpty
            ? bounty.subjectId
            : '11111111-1111-1111-1111-111111111111',
      );
      payload.remove('uploader_id');
      await client!
          .from('resources')
          .upsert(payload)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Fallback bounty resource upsert skipped: $e');
    }
  }

  Future<bool> createNoteBountyRemote(NoteBountyModel bounty) async {
    if (!isLiveSupabase) return false;
    try {
      await client!.rpc('create_note_bounty', params: {
        'p_id': UuidUtil.fromString(bounty.id),
        'p_requester_id': UuidUtil.fromString(bounty.requesterId),
        'p_subject_id': bounty.subjectId.isNotEmpty
            ? UuidUtil.fromString(bounty.subjectId)
            : null,
        'p_title': bounty.title,
        'p_description': bounty.description,
        'p_reward_credits': bounty.rewardCredits,
      }).timeout(const Duration(seconds: 8));
      return true;
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('pgrst202') ||
          s.contains('42883') ||
          s.contains('could not find the function')) {
        await _saveBountyResourceFallback(bounty);
        return false;
      }
      if (e is PostgrestException && e.message.trim().isNotEmpty) {
        if (e.message.toLowerCase().contains('has no field "roll_no"')) {
          throw const OverrideSyncException(
              'Database update required: run supabase_security_fix.sql in your Supabase SQL Editor to add missing roll_no columns.');
        }
        throw OverrideSyncException(e.message.trim());
      }
      throw OverrideSyncException(_friendlyDbError(e));
    }
  }

  Future<bool> submitBountySolutionRemote(NoteBountyModel bounty) async {
    if (!isLiveSupabase) return false;
    try {
      await client!.rpc('submit_bounty_solution', params: {
        'p_bounty_id': UuidUtil.fromString(bounty.id),
        'p_helper_id': UuidUtil.fromString(bounty.helperId ?? ''),
        'p_solution_text': bounty.solutionText ?? '',
        'p_solution_url': bounty.solutionUrl,
      }).timeout(const Duration(seconds: 8));
      return true;
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('pgrst202') ||
          s.contains('42883') ||
          s.contains('could not find the function')) {
        await _saveBountyResourceFallback(bounty);
        return false;
      }
      if (e is PostgrestException && e.message.trim().isNotEmpty) {
        if (e.message.toLowerCase().contains('has no field "roll_no"')) {
          throw const OverrideSyncException(
              'Database update required: run supabase_security_fix.sql in your Supabase SQL Editor to add missing roll_no columns.');
        }
        throw OverrideSyncException(e.message.trim());
      }
      throw OverrideSyncException(_friendlyDbError(e));
    }
  }

  Future<bool> resolveBountyPayoutRemote({
    required NoteBountyModel updatedBounty,
    required String actorId,
    required String action,
    String? reason,
  }) async {
    if (!isLiveSupabase) return false;
    try {
      await client!.rpc('resolve_bounty_payout', params: {
        'p_bounty_id': UuidUtil.fromString(updatedBounty.id),
        'p_actor_id': UuidUtil.fromString(actorId),
        'p_action': action,
        'p_reason': reason,
      }).timeout(const Duration(seconds: 8));
      return true;
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('pgrst202') ||
          s.contains('42883') ||
          s.contains('could not find the function')) {
        await _saveBountyResourceFallback(updatedBounty);
        return false;
      }
      if (e is PostgrestException && e.message.trim().isNotEmpty) {
        throw OverrideSyncException(e.message.trim());
      }
      throw OverrideSyncException(_friendlyDbError(e));
    }
  }

  Future<String?> createSubject(SubjectModel subject) async {
    if (!isLiveSupabase) return null;
    try {
      final payload = Map<String, dynamic>.from(subject.toMap());
      payload['id'] = UuidUtil.fromString(payload['id']?.toString() ?? subject.id);
      await client!
          .from('subjects')
          .upsert(payload)
          .timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('Error inserting subject in Supabase: $e');
      return _friendlyDbError(e);
    }
  }

  Future<String?> updateSubject(SubjectModel subject) async {
    if (!isLiveSupabase) return null;
    try {
      final payload = Map<String, dynamic>.from(subject.toMap());
      final validId = UuidUtil.fromString(payload['id']?.toString() ?? subject.id);
      payload['id'] = validId;
      await client!
          .from('subjects')
          .upsert(payload)
          .timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('Error updating subject in Supabase: $e');
      return _friendlyDbError(e);
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

  Future<String?> createSlot(TimetableSlotModel slot,
      {SubjectModel? subject}) async {
    return updateSlot(slot, subject: subject);
  }

  Future<String?> updateSlot(TimetableSlotModel slot,
      {SubjectModel? subject}) async {
    if (!isLiveSupabase) return null;
    try {
      final payload = Map<String, dynamic>.from(slot.toMap());
      final validId = UuidUtil.fromString(payload['id']?.toString() ?? slot.id);
      payload['id'] = validId;
      if (payload['subject_id'] != null) {
        payload['subject_id'] =
            UuidUtil.fromString(payload['subject_id'].toString());
      }
      try {
        await client!
            .from('timetable_slots')
            .upsert(payload)
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        final s = e.toString().toLowerCase();
        if ((s.contains('23503') || s.contains('foreign key')) &&
            subject != null) {
          await createSubject(subject);
          await client!
              .from('timetable_slots')
              .upsert(payload)
              .timeout(const Duration(seconds: 8));
        } else {
          rethrow;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error upserting timetable slot in Supabase: $e');
      return _friendlyDbError(e);
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

  /// Normalizes an override row before sending to Supabase.
  static Map<String, dynamic> normalizeOverridePayload(
      Map<String, dynamic> raw, {String? fallbackId}) {
    final payload = Map<String, dynamic>.from(raw);
    payload['id'] =
        UuidUtil.fromString(payload['id']?.toString() ?? fallbackId ?? '');
    if (payload['slot_id'] != null) {
      payload['slot_id'] = UuidUtil.fromString(payload['slot_id'].toString());
    }
    final reporter = payload['reported_by']?.toString();
    if (reporter == null ||
        reporter.isEmpty ||
        !UuidUtil.isValidUuid(reporter)) {
      payload.remove('reported_by');
    }
    return payload;
  }

  /// Self-healing upsert for `daily_overrides`, shared by live saves and the
  /// offline sync queue. Handles the errors that made "push" fail:
  /// * UNIQUE(slot_id, date) clash when a lecture is re-broadcast the same day
  ///   (e.g. marked late twice) -> upsert ON CONFLICT (slot_id, date).
  /// * reported_by FK violation when the admin's id isn't in public.users.
  /// * Older schemas missing actual_start_time / actual_end_time / rescheduled_date
  ///   columns -> encodes those fields into topic_covered via [DailyOverrideModel.encodeMetaIntoTopic]
  ///   so meeting time/date updates still persist and sync across all devices.
  /// * Missing parent slot/subject in Supabase -> auto-upserts them when provided.
  /// Throws [OverrideSyncException] with a readable message if it can't recover.
  static Future<void> upsertOverrideRow(
    SupabaseClient client,
    Map<String, dynamic> raw, {
    String? fallbackId,
    TimetableSlotModel? slot,
    SubjectModel? subject,
  }) async {
    var payload = normalizeOverridePayload(raw, fallbackId: fallbackId);
    final origStart = payload['actual_start_time']?.toString();
    final origEnd = payload['actual_end_time']?.toString();
    final origRDate = payload['rescheduled_date']?.toString();
    final origMeetingUrl = payload['meeting_url']?.toString();
    final origTopic = payload['topic_covered']?.toString();
    final origReporterName = payload['reported_by_name']?.toString();

    bool useConflictTarget = true;
    bool droppedOptionalCols = false;
    bool clearedDuplicate = false;
    bool ensuredParentSlot = false;
    Object? lastError;

    for (int attempt = 0; attempt < 6; attempt++) {
      try {
        if (useConflictTarget) {
          await client
              .from('daily_overrides')
              .upsert(payload, onConflict: 'slot_id,date')
              .timeout(const Duration(seconds: 8));
        } else {
          await client
              .from('daily_overrides')
              .upsert(payload)
              .timeout(const Duration(seconds: 8));
        }
        return;
      } catch (e) {
        lastError = e;
        final s = e.toString().toLowerCase();

        final isFk = s.contains('23503') || s.contains('foreign key');
        if (isFk && payload.containsKey('reported_by') &&
            (s.contains('reported_by') || s.contains('users'))) {
          payload = Map<String, dynamic>.from(payload)..remove('reported_by');
          continue;
        }
        if (isFk && s.contains('slot')) {
          if (!ensuredParentSlot && slot != null) {
            ensuredParentSlot = true;
            try {
              if (subject != null) {
                final subPayload = Map<String, dynamic>.from(subject.toMap());
                subPayload['id'] = UuidUtil.fromString(subject.id);
                await client
                    .from('subjects')
                    .upsert(subPayload)
                    .timeout(const Duration(seconds: 8));
              }
              final slotPayload = Map<String, dynamic>.from(slot.toMap());
              slotPayload['id'] = UuidUtil.fromString(slot.id);
              slotPayload['subject_id'] = UuidUtil.fromString(slot.subjectId);
              await client
                  .from('timetable_slots')
                  .upsert(slotPayload)
                  .timeout(const Duration(seconds: 8));
              continue;
            } catch (_) {}
          }
          throw const OverrideSyncException(
              'This lecture slot is not in the cloud timetable yet. Push the timetable first, then broadcast again.');
        }

        if (!droppedOptionalCols &&
            (s.contains('pgrst204') ||
                s.contains('42703') ||
                (s.contains('column') && !s.contains('violates')))) {
          final encodedTopic = DailyOverrideModel.encodeMetaIntoTopic(
            topicCovered: origTopic,
            actualStartTime: origStart,
            actualEndTime: origEnd,
            rescheduledDate: origRDate,
            meetingUrl: origMeetingUrl,
            reportedByName: origReporterName,
          );
          payload = Map<String, dynamic>.from(payload)
            ..remove('actual_start_time')
            ..remove('actual_end_time')
            ..remove('rescheduled_date')
            ..remove('meeting_url')
            ..remove('reported_by_name');
          if (encodedTopic != null) {
            payload['topic_covered'] = encodedTopic;
          }
          droppedOptionalCols = true;
          continue;
        }

        // No matching unique constraint for ON CONFLICT (older schema)
        if (useConflictTarget &&
            (s.contains('42p10') || s.contains('on conflict'))) {
          useConflictTarget = false;
          continue;
        }

        // Duplicate (slot_id, date) row:
        // Only admin-approved overrides may replace an existing row;
        // student reports must fail so they cannot spam or overwrite overrides.
        if (s.contains('23505') || s.contains('duplicate key')) {
          if (payload['is_approved'] != true) {
            throw const OverrideSyncException(
                'A schedule report for this lecture and date already exists.');
          }
          if (!clearedDuplicate) {
            final slotId = payload['slot_id'];
            final date = payload['date'];
            if (slotId != null && date != null) {
              await client
                  .from('daily_overrides')
                  .delete()
                  .eq('slot_id', slotId)
                  .eq('date', date)
                  .timeout(const Duration(seconds: 8));
            }
            clearedDuplicate = true;
            continue;
          }
        }

        break;
      }
    }
    throw OverrideSyncException(_friendlyDbError(lastError));
  }

  static String _friendlyDbError(Object? e) {
    if (e == null) return 'Unknown error';
    final s = e.toString();
    final lower = s.toLowerCase();
    if (e is TimeoutException || lower.contains('timeout')) {
      return 'Network timeout. Check your internet connection and try again.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup')) {
      return 'No internet connection.';
    }
    if (lower.contains('row-level security') || lower.contains('42501')) {
      return 'Supabase blocked the write (row-level security). Re-run supabase_schema.sql.';
    }
    if (lower.contains('pgrst205') ||
        lower.contains('does not exist') ||
        lower.contains('could not find the table')) {
      return 'Table missing in Supabase. Run supabase_schema.sql in the SQL editor.';
    }
    if (e is PostgrestException) return e.message;
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }

  /// Saves an override live. Returns null on success, or an error message.
  Future<String?> saveOverride(
    DailyOverrideModel override, {
    TimetableSlotModel? slot,
    SubjectModel? subject,
  }) async {
    if (!isLiveSupabase) return null;
    try {
      await upsertOverrideRow(
        client!,
        override.toMap(),
        fallbackId: override.id,
        slot: slot,
        subject: subject,
      );
      return null;
    } on OverrideSyncException catch (e) {
      debugPrint('Error saving override in Supabase: ${e.message}');
      return e.message;
    } catch (e) {
      debugPrint('Error saving override in Supabase: $e');
      return _friendlyDbError(e);
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

  /// Securely approves or rejects a student override via the database RPC
  /// `admin_review_override` (which awards +30 credits once on approval and
  /// deletes on rejection). Falls back to direct table write if the RPC has
  /// not yet been deployed.
  Future<bool> reviewOverride(
    String overrideId, {
    required String adminId,
    required bool approve,
    DailyOverrideModel? fallbackOverride,
  }) async {
    if (!isLiveSupabase) return false;
    try {
      await client!.rpc('admin_review_override', params: {
        'p_override_id': UuidUtil.fromString(overrideId),
        'p_admin_id': UuidUtil.fromString(adminId),
        'p_approve': approve,
      }).timeout(const Duration(seconds: 8));
      return true;
    } catch (e) {
      final s = e.toString().toLowerCase();
      final missingRpc = s.contains('pgrst202') ||
          s.contains('42883') ||
          s.contains('could not find the function');
      if (missingRpc) {
        if (approve && fallbackOverride != null) {
          await saveOverride(fallbackOverride);
        } else if (!approve) {
          await deleteOverride(overrideId);
        }
      } else {
        debugPrint('Error reviewing override via RPC: $e');
      }
      return false;
    }
  }

  /// Shared self-healing upsert for `public.resources` used by both live writes
  /// and [SyncService]. Falls back cleanly if the DB check constraint hasn't
  /// been migrated yet to include `'notes'` / `'folder'`.
  static Future<void> upsertResourceRow(
    SupabaseClient client,
    Map<String, dynamic> raw, {
    String? fallbackId,
    SubjectModel? subject,
  }) async {
    var payload = Map<String, dynamic>.from(raw);
    payload['id'] =
        UuidUtil.fromString(payload['id']?.toString() ?? fallbackId ?? '');
    if (payload['subject_id'] != null) {
      payload['subject_id'] =
          UuidUtil.fromString(payload['subject_id'].toString());
    }
    if (payload['uploader_id'] != null &&
        !UuidUtil.isValidUuid(payload['uploader_id'].toString())) {
      payload.remove('uploader_id');
    }

    bool ensuredSubject = false;
    bool downgradedCategoryType = false;
    final origTitle = payload['title']?.toString() ?? '';
    final origType = ResourceType.fromString(payload['type']?.toString() ?? 'pdf');

    for (int attempt = 0; attempt < 4; attempt++) {
      try {
        await client
            .from('resources')
            .upsert(payload)
            .timeout(const Duration(seconds: 8));
        return;
      } catch (e) {
        final s = e.toString().toLowerCase();
        final isFk = s.contains('23503') || s.contains('foreign key');
        if (isFk &&
            payload.containsKey('uploader_id') &&
            (s.contains('uploader_id') || s.contains('users'))) {
          payload = Map<String, dynamic>.from(payload)..remove('uploader_id');
          continue;
        }
        if (isFk && s.contains('subject') && !ensuredSubject && subject != null) {
          ensuredSubject = true;
          try {
            final subPayload = Map<String, dynamic>.from(subject.toMap());
            subPayload['id'] = UuidUtil.fromString(subject.id);
            await client
                .from('subjects')
                .upsert(subPayload)
                .timeout(const Duration(seconds: 8));
            continue;
          } catch (_) {}
        }
        if (!downgradedCategoryType &&
            (origType == ResourceType.notes || origType == ResourceType.folder) &&
            (s.contains('23514') ||
                s.contains('resources_type_check') ||
                s.contains('check constraint'))) {
          payload = Map<String, dynamic>.from(payload)
            ..['type'] = 'pdf'
            ..['title'] = ResourceModel.encodeFallbackTitle(origTitle, origType);
          downgradedCategoryType = true;
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> saveResource(
    ResourceModel resource, {
    SubjectModel? subject,
  }) async {
    if (!isLiveSupabase) return;
    try {
      await upsertResourceRow(
        client!,
        resource.toMap(),
        fallbackId: resource.id,
        subject: subject,
      );
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

  /// Upserts an assignment/task row. Returns normally on success, or throws
  /// [OverrideSyncException]. Self-heals missing `category` column by encoding
  /// `[TASK:quiz]` / `[TASK:presentation]` into `description`.
  static Future<void> upsertAssignmentRow(
    SupabaseClient client,
    Map<String, dynamic> raw, {
    String? fallbackId,
    SubjectModel? subject,
  }) async {
    var payload = Map<String, dynamic>.from(raw);
    payload['id'] =
        UuidUtil.fromString(payload['id']?.toString() ?? fallbackId ?? '');
    if (payload['subject_id'] != null &&
        payload['subject_id'].toString().isNotEmpty) {
      payload['subject_id'] =
          UuidUtil.fromString(payload['subject_id'].toString());
    } else {
      payload.remove('subject_id');
    }

    final origDesc = payload['description']?.toString() ?? '';
    final taskCat =
        TaskCategory.fromString(payload['category']?.toString());
    bool ensuredSubject = false;
    bool droppedCategoryCol = false;
    Object? lastError;

    for (int attempt = 0; attempt < 4; attempt++) {
      try {
        await client
            .from('assignments')
            .upsert(payload)
            .timeout(const Duration(seconds: 8));
        return;
      } catch (e) {
        lastError = e;
        final s = e.toString().toLowerCase();

        if (!droppedCategoryCol &&
            payload.containsKey('category') &&
            (s.contains('pgrst204') ||
                s.contains('42703') ||
                (s.contains('column') && s.contains('category')))) {
          payload = Map<String, dynamic>.from(payload)..remove('category');
          payload['description'] =
              AssignmentModel.encodeCategoryInDescription(origDesc, taskCat);
          droppedCategoryCol = true;
          continue;
        }

        if (!ensuredSubject &&
            (s.contains('23503') || s.contains('foreign key')) &&
            s.contains('subject')) {
          if (subject != null) {
            ensuredSubject = true;
            try {
              final subPayload = Map<String, dynamic>.from(subject.toMap());
              subPayload['id'] = UuidUtil.fromString(subject.id);
              await client
                  .from('subjects')
                  .upsert(subPayload)
                  .timeout(const Duration(seconds: 8));
              continue;
            } catch (_) {}
          }
          throw const OverrideSyncException(
              'This course is not in the cloud yet. Push your courses first, then post the task again.');
        }
        break;
      }
    }
    throw OverrideSyncException(_friendlyDbError(lastError));
  }

  Future<String?> saveAssignment(
    AssignmentModel assignment, {
    SubjectModel? subject,
  }) async {
    if (!isLiveSupabase) {
      return 'Supabase is not configured, so this assignment is only on this device.';
    }
    try {
      await upsertAssignmentRow(
        client!,
        assignment.toMap(),
        fallbackId: assignment.id,
        subject: subject,
      );
      return null;
    } on OverrideSyncException catch (e) {
      debugPrint('Error saving assignment in Supabase: ${e.message}');
      return e.message;
    } catch (e) {
      debugPrint('Error saving assignment in Supabase: $e');
      return _friendlyDbError(e);
    }
  }

  Future<String?> deleteAssignment(String assignmentId) async {
    if (!isLiveSupabase) return null;
    try {
      final validId = UuidUtil.fromString(assignmentId);
      await client!
          .from('assignments')
          .delete()
          .eq('id', validId)
          .timeout(const Duration(seconds: 8));
      return null;
    } catch (e) {
      debugPrint('Error deleting assignment in Supabase: $e');
      return _friendlyDbError(e);
    }
  }
}

/// Readable error raised when a cloud write can't be completed.
class OverrideSyncException implements Exception {
  final String message;
  const OverrideSyncException(this.message);

  @override
  String toString() => message;
}
