import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/uuid_util.dart';
import '../../models/models.dart';
import '../../providers/class_providers.dart';
import '../bounties/note_bounties_screen.dart';
import '../quizzes/quiz_center_screen.dart';
import '../vault/vault_screen.dart';

class AdminManagementScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const AdminManagementScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<AdminManagementScreen> createState() =>
      _AdminManagementScreenState();
}

class _AdminManagementScreenState extends ConsumerState<AdminManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDay = 1; // 1 = Mon ... 7 = Sun
  final TextEditingController _userSearchCtrl = TextEditingController();
  String _userSearchQuery = '';
  String _userRoleFilter = 'all'; // 'all', 'student', 'admin', 'verified'

  String _uploaderReqFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'
  String _uploaderReqSearch = '';
  final TextEditingController _uploaderSearchCtrl = TextEditingController();
  String _vaultSearchQuery = '';
  final TextEditingController _vaultSearchCtrl = TextEditingController();

  static const List<Map<String, dynamic>> _days = [
    {'day': 1, 'label': 'Mon', 'fullName': 'Monday'},
    {'day': 2, 'label': 'Tue', 'fullName': 'Tuesday'},
    {'day': 3, 'label': 'Wed', 'fullName': 'Wednesday'},
    {'day': 4, 'label': 'Thu', 'fullName': 'Thursday'},
    {'day': 5, 'label': 'Fri', 'fullName': 'Friday'},
    {'day': 6, 'label': 'Sat', 'fullName': 'Saturday'},
    {'day': 7, 'label': 'Sun', 'fullName': 'Sunday'},
  ];

  static const List<String> _paletteColors = [
    '#6D28D9', // Royal Purple
    '#4C1D95', // Deep Violet
    '#059669', // Emerald
    '#D97706', // Amber Gold
    '#2563EB', // Electric Blue
    '#DC2626', // Crimson Red
    '#0D9488', // Teal
    '#DB2777', // Fuchsia / Rose
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 6),
    );
    final today = DateTime.now().weekday;
    if (today >= 1 && today <= 7) {
      _selectedDay = today;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSearchCtrl.dispose();
    _uploaderSearchCtrl.dispose();
    _vaultSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final slots = ref.watch(timetableSlotsProvider);
    final subjects = ref.watch(subjectsProvider);
    final overrides = ref.watch(dailyOverridesProvider);
    final resources = ref.watch(resourcesProvider);
    final pendingCount = ref.watch(pendingModQueueCountProvider);
    final syncState = ref.watch(syncStateProvider);
    final users = ref.watch(usersListProvider);
    final uploaderRequests = ref.watch(uploaderRequestsProvider);
    final pendingReqCount = ref.watch(pendingUploaderRequestsCountProvider);
    final studentVerifications = ref.watch(studentVerificationRequestsProvider);
    final pendingStudentVerifCount =
        ref.watch(pendingStudentVerificationsCountProvider);
    final bounties = ref.watch(noteBountiesProvider);
    final bountyReviewCount = ref.watch(pendingBountyDisputesCountProvider);
    final quizzes = ref.watch(quizzesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Admin Management Console',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: syncState.pendingCount > 0
                ? '${syncState.pendingCount} unsynced changes. Tap to sync.'
                : 'Cloud in sync. Tap to refresh.',
            icon: syncState.isSyncing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Badge(
                    isLabelVisible: syncState.pendingCount > 0,
                    label: Text('${syncState.pendingCount}'),
                    backgroundColor: AppColors.warning,
                    child: Icon(
                      syncState.pendingCount > 0
                          ? Icons.cloud_upload_rounded
                          : Icons.cloud_done_rounded,
                      color: syncState.pendingCount > 0
                          ? AppColors.warning
                          : AppColors.primary,
                      size: 22,
                    ),
                  ),
            onPressed: syncState.isSyncing
                ? null
                : () async {
                    final res = await ref
                        .read(syncStateProvider.notifier)
                        .triggerSync();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.message),
                          backgroundColor: res.success
                              ? AppColors.snackBarBg
                              : AppColors.danger,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
          ),
          IconButton(
            tooltip: 'Student PIN Reset & Security',
            icon: Icon(Icons.lock_reset_rounded, color: AppColors.primary),
            onPressed: () => _openSecurityManagement(context),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.warningBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.shield_rounded, size: 14, color: AppColors.warning),
                SizedBox(width: 4),
                Text(
                  'ADMIN MODE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: [
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Timetable (${slots.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.school_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Subjects (${subjects.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.broadcast_on_personal_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Live Overrides (${overrides.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.fact_check_rounded, size: 16),
                      const SizedBox(width: 6),
                      const Text('Mod Queue'),
                      if (pendingCount + bountyReviewCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${pendingCount + bountyReviewCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, size: 16),
                      const SizedBox(width: 6),
                      const Text('Verifications'),
                      if (pendingReqCount + pendingStudentVerifCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${pendingReqCount + pendingStudentVerifCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Users (${users.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.psychology_alt_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text('Quizzes (${quizzes.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Timetable Slots Manager
          _buildTimetableManager(slots, subjects),

          // TAB 2: Subjects & Courses Manager
          _buildSubjectsManager(subjects, slots),

          // TAB 3: Live Overrides & Broadcasts
          _buildOverridesManager(overrides, slots, subjects),

          // TAB 4: Moderation Queue
          _buildModQueue(resources, overrides, subjects, slots, users, bounties),

          // TAB 5: Student Badge & Uploader Verification Requests
          _buildUploaderRequestsManager(
              uploaderRequests, studentVerifications, users),

          // TAB 6: Users & Students Roster Manager
          _buildUsersManager(users),

          // TAB 7: NotebookLM & MCQ Quizzes Manager
          const QuizCenterScreen(embeddedInAdmin: true),
        ],
      ),
    );
  }

  // ===================================================================
  // TAB 1: TIMETABLE MANAGER
  // ===================================================================

  Widget _buildTimetableManager(
    List<TimetableSlotModel> allSlots,
    List<SubjectModel> subjects,
  ) {
    final daySlots = allSlots.where((s) => s.dayOfWeek == _selectedDay).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final selectedDayName =
        _days.firstWhere((d) => d['day'] == _selectedDay)['fullName'] as String;

    return Column(
      children: [
        // Day selector pills
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: AppColors.cardSurface,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final d = _days[index];
              final dayNum = d['day'] as int;
              final label = d['label'] as String;
              final isSelected = dayNum == _selectedDay;
              final daySlotCount =
                  allSlots.where((s) => s.dayOfWeek == dayNum).length;

              return InkWell(
                onTap: () => setState(() => _selectedDay = dayNum),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$daySlotCount',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Action Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$selectedDayName (${daySlots.length} Slots)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openSlotFormDialog(context, subjects),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Slot'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Slots list
        Expanded(
          child: daySlots.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy_rounded,
                          size: 48, color: AppColors.border),
                      const SizedBox(height: 12),
                      Text(
                        'No lecture slots scheduled for $selectedDayName.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _openSlotFormDialog(context, subjects),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Schedule First Lecture Slot'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                  itemCount: daySlots.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final slot = daySlots[index];
                    final targetUuid = UuidUtil.fromString(slot.subjectId);
                    final subject = subjects.firstWhere(
                      (s) => s.id == slot.subjectId || UuidUtil.fromString(s.id) == targetUuid,
                      orElse: () => subjects.isNotEmpty
                          ? subjects.first
                          : const SubjectModel(
                              id: 'unknown',
                              name: 'Unknown Course',
                              code: 'GEN000',
                              professor: 'TBD',
                            ),
                    );

                    return _AdminSlotCard(
                      slot: slot,
                      subject: subject,
                      onEdit: () => _openSlotFormDialog(
                        context,
                        subjects,
                        existingSlot: slot,
                      ),
                      onDelete: () => _confirmDeleteSlot(context, slot, subject),
                      onQuickOverride: () =>
                          _openQuickOverrideDialog(context, slot, subject),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ===================================================================
  // TAB 2: SUBJECTS MANAGER
  // ===================================================================

  Widget _buildSubjectsManager(
    List<SubjectModel> subjects,
    List<TimetableSlotModel> slots,
  ) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Curriculum Courses',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${subjects.length} Active Academic Subjects',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openSubjectFormDialog(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New Course'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 36),
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (subjects.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.school_outlined,
                      size: 40, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text(
                    'No Courses Added Yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Tap "+ Add Course" below to add your first curriculum subject.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            for (final sub in subjects) ...[
              _AdminSubjectCard(
                subject: sub,
                slotCount: slots.where((s) => s.subjectId == sub.id || UuidUtil.fromString(s.subjectId) == UuidUtil.fromString(sub.id)).length,
                onEdit: () =>
                    _openSubjectFormDialog(context, existingSubject: sub),
                onDelete: () => _confirmDeleteSubject(context, sub, slots),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
      Positioned(
        bottom: 24,
        right: 20,
        child: FloatingActionButton.extended(
          heroTag: 'admin_add_course_fab',
          onPressed: () => _openSubjectFormDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Course'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
    ],
  );
  }

  // ===================================================================
  // TAB 3: LIVE OVERRIDES & BROADCASTS
  // ===================================================================

  Widget _buildOverridesManager(
    List<DailyOverrideModel> overrides,
    List<TimetableSlotModel> slots,
    List<SubjectModel> subjects,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Broadcast Info Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.08),
                AppColors.secondary.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Override System',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Changes published here immediately update all student dashboards and push alerts.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Broadcasts (${overrides.length})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                if (slots.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please add timetable slots first.')),
                  );
                  return;
                }
                _openBroadcastNewDialog(context, slots, subjects);
              },
              icon: const Icon(Icons.add_alert_rounded, size: 16),
              label: const Text('New Broadcast'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (overrides.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                'No live overrides or cancellations active.\nClasses are following the standard timetable.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
            ),
          )
        else
          for (final ov in overrides) ...[
            _AdminOverrideCard(
              dailyOverride: ov,
              slots: slots,
              subjects: subjects,
              onDelete: () {
                ref.read(dailyOverridesProvider.notifier).deleteOverride(ov.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Override removed. Class restored.')),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  // ===================================================================
  // TAB 4: MODERATION QUEUE
  // ===================================================================

  Widget _buildModQueue(
    List<ResourceModel> resources,
    List<DailyOverrideModel> overrides,
    List<SubjectModel> subjects,
    List<TimetableSlotModel> slots,
    List<UserModel> users,
    List<NoteBountyModel> bounties,
  ) {
    final pendingResources = resources.where((r) => !r.isApproved).toList();
    final pendingOverrides = overrides.where((o) => !o.isApproved).toList();
    final pendingBounties = bounties.where((b) => b.needsReview).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Student Submissions Review',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${pendingResources.length + pendingOverrides.length + pendingBounties.length} PENDING',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (pendingResources.isEmpty &&
            pendingOverrides.isEmpty &&
            pendingBounties.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 44, color: AppColors.success),
                SizedBox(height: 10),
                Text(
                  'Moderation Queue is Clean',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'All student notes and room updates have been reviewed.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (pendingResources.isNotEmpty) ...[
            Text(
              'Vault Notes & Study Materials',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            for (final res in pendingResources) ...[
              _AdminModResourceCard(
                resource: res,
                onEdit: () => showEditResourceModal(context, ref, res),
                onApprove: () {
                  ref
                      .read(resourcesProvider.notifier)
                      .approveResource(res.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Approved: "${res.title}" published!')),
                  );
                },
                onReject: () {
                  ref.read(resourcesProvider.notifier).rejectResource(res.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Resource rejected.')),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 16),
          ],

          if (pendingOverrides.isNotEmpty) ...[
            Text(
              'Student Schedule Reports',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            for (final ov in pendingOverrides) ...[
              _AdminModOverrideCard(
                dailyOverride: ov,
                subjects: subjects,
                slots: slots,
                users: users,
                onApprove: () {
                  ref
                      .read(dailyOverridesProvider.notifier)
                      .approveOverride(ov.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report approved & broadcast!')),
                  );
                },
                onReject: () {
                  ref
                      .read(dailyOverridesProvider.notifier)
                      .rejectOverride(ov.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report rejected.')),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ],

          if (pendingBounties.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Note Bounties Escrow Review',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NoteBountiesScreen(),
                    ),
                  ),
                  child: const Text('Open Full View'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final b in pendingBounties) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: b.isDisputed
                        ? AppColors.danger.withValues(alpha: 0.45)
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: b.isDisputed
                                ? AppColors.dangerBg
                                : AppColors.warningBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            b.isDisputed ? 'DISPUTED SCAM CHECK' : 'SUBMITTED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: b.isDisputed
                                  ? AppColors.danger
                                  : AppColors.warning,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${b.rewardCredits} ⚡ Escrow',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      b.title,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Requester: ${b.requesterName} • Helper: ${b.helperName ?? "Student"}',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                    if (b.solutionText != null && b.solutionText!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        b.solutionText!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textPrimary),
                      ),
                    ],
                    if (b.solutionUrl != null && b.solutionUrl!.isNotEmpty)
                      TextButton.icon(
                        onPressed: () =>
                            Formatters.launchMeetingUrl(context, b.solutionUrl),
                        icon: const Icon(Icons.open_in_new_rounded, size: 15),
                        label: const Text('Inspect Submitted Attachment'),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final err = await ref
                                  .read(noteBountiesProvider.notifier)
                                  .adminRejectSubmission(b.id);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(err ??
                                      'Submission rejected (0 credits). Bounty re-opened.'),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.danger),
                              foregroundColor: AppColors.danger,
                              minimumSize: const Size(0, 36),
                            ),
                            child: const Text('Reject Scam'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final err = await ref
                                  .read(noteBountiesProvider.notifier)
                                  .adminApproveBounty(b.id);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(err ??
                                      'Approved! ${b.rewardCredits} ⚡ paid to ${b.helperName ?? "helper"}.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              minimumSize: const Size(0, 36),
                            ),
                            child: Text('Pay ${b.rewardCredits} ⚡'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],

        // PUBLISHED VAULT DOCUMENTS MANAGER (EDIT / DELETE)
        const SizedBox(height: 24),
        Builder(
          builder: (context) {
            final publishedResources = resources
                .where((r) => r.isApproved && !r.url.startsWith('ccquiz://'))
                .toList();
            final q = _vaultSearchQuery.trim().toLowerCase();
            final filteredVault = publishedResources.where((r) {
              if (q.isEmpty) return true;
              final sub = resolveSubjectById(subjects, r.subjectId);
              return r.title.toLowerCase().contains(q) ||
                  r.uploaderName.toLowerCase().contains(q) ||
                  (sub?.code.toLowerCase().contains(q) ?? false) ||
                  (sub?.name.toLowerCase().contains(q) ?? false);
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Published Vault Documents',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${publishedResources.length} published notes, slides & lectures',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => showUploadModal(context, ref),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text(
                        'Upload',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _vaultSearchCtrl,
                  onChanged: (val) => setState(() => _vaultSearchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search uploaded notes by title, subject, or uploader...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _vaultSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _vaultSearchCtrl.clear();
                              setState(() => _vaultSearchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                if (filteredVault.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Text(
                        publishedResources.isEmpty
                            ? 'No uploaded Vault documents yet.'
                            : 'No uploaded documents match "$_vaultSearchQuery".',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  for (final res in filteredVault) ...[
                    Builder(
                      builder: (context) {
                        final sub = resolveSubjectById(subjects, res.subjectId);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  res.type.icon,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (sub != null) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: sub.color
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              sub.code,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: sub.color,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          res.type.label,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      res.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'By ${res.uploaderName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Edit Document',
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    showEditResourceModal(context, ref, res),
                              ),
                              IconButton(
                                tooltip: 'Delete Document',
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.dangerText,
                                  size: 20,
                                ),
                                onPressed: () => confirmDeleteResourceDialog(
                                    context, ref, res),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
              ],
            );
          },
        ),
      ],
    );
  }

  // ===================================================================
  // MODAL DIALOGS FOR SLOT, SUBJECT, AND OVERRIDES
  // ===================================================================

  void _openSlotFormDialog(
    BuildContext context,
    List<SubjectModel> subjects, {
    TimetableSlotModel? existingSlot,
  }) {
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create at least one Subject before adding slots.'),
        ),
      );
      return;
    }

    final isEditing = existingSlot != null;
    final initialTargetUuid = existingSlot != null ? UuidUtil.fromString(existingSlot.subjectId) : null;
    final matchedSubject = subjects.where((s) =>
        s.id == existingSlot?.subjectId ||
        (initialTargetUuid != null && UuidUtil.fromString(s.id) == initialTargetUuid)
    ).firstOrNull;

    String selectedSubjectId = matchedSubject?.id ?? subjects.first.id;
    int dayOfWeek = existingSlot?.dayOfWeek ?? _selectedDay;
    String startTime = existingSlot?.startTime ?? '09:00';
    String endTime = existingSlot?.endTime ?? '10:15';
    final roomController =
        TextEditingController(text: existingSlot?.defaultRoom ?? 'Hall A-102');
    final meetingUrlController =
        TextEditingController(text: existingSlot?.meetingUrl ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Edit Lecture Slot' : 'Add Timetable Slot',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Subject Selector
                    Text(
                      'Select Course / Subject',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: subjects.any((s) => s.id == selectedSubjectId)
                              ? selectedSubjectId
                              : subjects.first.id,
                          isExpanded: true,
                          items: subjects.map((sub) {
                            return DropdownMenuItem(
                              value: sub.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: sub.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${sub.code} - ${sub.name}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedSubjectId = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Day of Week Selector
                    Text(
                      'Day of Week',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _days.map((d) {
                          final dayNum = d['day'] as int;
                          final isSel = dayNum == dayOfWeek;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(d['label'] as String),
                              selected: isSel,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                              onSelected: (_) {
                                setModalState(() => dayOfWeek = dayNum);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Timing pickers
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Time',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final parts = startTime.split(':').map(int.parse).toList();
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(
                                        hour: parts[0], minute: parts[1]),
                                  );
                                  if (picked != null) {
                                    final h = picked.hour
                                        .toString()
                                        .padLeft(2, '0');
                                    final m = picked.minute
                                        .toString()
                                        .padLeft(2, '0');
                                    setModalState(() => startTime = '$h:$m');
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        Formatters.formatTimeString(startTime),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Icon(Icons.access_time_rounded,
                                          size: 16,
                                          color: AppColors.textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Time',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final parts = endTime.split(':').map(int.parse).toList();
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(
                                        hour: parts[0], minute: parts[1]),
                                  );
                                  if (picked != null) {
                                    final h = picked.hour
                                        .toString()
                                        .padLeft(2, '0');
                                    final m = picked.minute
                                        .toString()
                                        .padLeft(2, '0');
                                    setModalState(() => endTime = '$h:$m');
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        Formatters.formatTimeString(endTime),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Icon(Icons.access_time_rounded,
                                          size: 16,
                                          color: AppColors.textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Room input
                    Text(
                      'Default Lecture Room / Hall',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: roomController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Hall A-102, Lab 3',
                        prefixIcon: const Icon(Icons.room_outlined, size: 18),
                        filled: true,
                        fillColor: AppColors.surfaceSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Room Suggestions
                    Wrap(
                      spacing: 6,
                      children: [
                        'Hall A-102',
                        'Lab 3 (Ground Floor)',
                        'Seminar Room 4',
                        'Room 204',
                        'Online Class',
                      ].map((r) {
                        return ActionChip(
                          label: Text(r, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            setModalState(() => roomController.text = r);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Meeting / Online Class URL (Optional)
                    Text(
                      'Meeting / Online Class URL (Optional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: meetingUrlController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        hintText:
                            'e.g. https://meet.google.com/abc-defg-hij or Zoom link',
                        prefixIcon:
                            const Icon(Icons.video_call_rounded, size: 20),
                        filled: true,
                        fillColor: AppColors.surfaceSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final roomText = roomController.text.trim();
                          final meetingUrlText =
                              meetingUrlController.text.trim();
                          if (roomText.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please specify a lecture room.')),
                            );
                            return;
                          }

                          String? error;
                          if (isEditing) {
                            final updated = existingSlot.copyWith(
                              subjectId: selectedSubjectId,
                              dayOfWeek: dayOfWeek,
                              startTime: startTime,
                              endTime: endTime,
                              defaultRoom: roomText,
                              meetingUrl: meetingUrlText.isNotEmpty
                                  ? meetingUrlText
                                  : null,
                              clearMeetingUrl: meetingUrlText.isEmpty,
                            );
                            error = await ref
                                .read(timetableSlotsProvider.notifier)
                                .updateSlot(updated);
                          } else {
                            final newSlot = TimetableSlotModel(
                              id: UuidUtil.generate(),
                              subjectId: selectedSubjectId,
                              dayOfWeek: dayOfWeek,
                              startTime: startTime,
                              endTime: endTime,
                              defaultRoom: roomText,
                              meetingUrl: meetingUrlText.isNotEmpty
                                  ? meetingUrlText
                                  : null,
                            );
                            error = await ref
                                .read(timetableSlotsProvider.notifier)
                                .addSlot(newSlot);
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error == null
                                    ? (isEditing
                                        ? 'Timetable slot updated & synced to cloud!'
                                        : 'New slot added & synced to cloud!')
                                    : 'Saved locally (Cloud: $error)',
                              ),
                              backgroundColor: error == null
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isEditing ? 'Save Changes' : 'Create Timetable Slot',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteSlot(
    BuildContext context,
    TimetableSlotModel slot,
    SubjectModel subject,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Timetable Slot?'),
        content: Text(
          'Are you sure you want to remove the ${subject.name} slot (${slot.formattedTimeRange})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(timetableSlotsProvider.notifier).deleteSlot(slot.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Timetable slot removed.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openSubjectFormDialog(
    BuildContext context, {
    SubjectModel? existingSubject,
  }) {
    final isEditing = existingSubject != null;
    final nameController =
        TextEditingController(text: existingSubject?.name ?? '');
    final codeController =
        TextEditingController(text: existingSubject?.code ?? '');
    final profController =
        TextEditingController(text: existingSubject?.professor ?? '');
    double minAttendance =
        (existingSubject?.minAttendancePct ?? 75).toDouble();
    String selectedColor = existingSubject?.colorHex ?? _paletteColors[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Edit Course Details' : 'Add New Course',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Course Name',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Distributed Operating Systems',
                        filled: true,
                        fillColor: AppColors.surfaceSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Code',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: codeController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: InputDecoration(
                                  hintText: 'CS301',
                                  filled: true,
                                  fillColor: AppColors.surfaceSubtle,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: AppColors.border),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Professor / Instructor',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: profController,
                                decoration: InputDecoration(
                                  hintText: 'Dr. Sarah Mitchell',
                                  filled: true,
                                  fillColor: AppColors.surfaceSubtle,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: AppColors.border),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Minimum Attendance Target',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                        Text(
                          '${minAttendance.toInt()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: minAttendance,
                      min: 50,
                      max: 90,
                      divisions: 8,
                      label: '${minAttendance.toInt()}%',
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setModalState(() => minAttendance = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    Text(
                      'Theme Color',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _paletteColors.map((hex) {
                        final isSel = selectedColor == hex;
                        final color = Color(
                            int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                        return InkWell(
                          onTap: () => setModalState(() => selectedColor = hex),
                          borderRadius: BorderRadius.circular(999),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel
                                    ? AppColors.textPrimary
                                    : AppColors.cardSurface,
                                width: isSel ? 3 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: isSel
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          final code = codeController.text.trim().toUpperCase();
                          final prof = profController.text.trim();

                          if (name.isEmpty || code.isEmpty || prof.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please fill all course fields.')),
                            );
                            return;
                          }

                          if (isEditing) {
                            final updated = existingSubject.copyWith(
                              name: name,
                              code: code,
                              professor: prof,
                              minAttendancePct: minAttendance.toInt(),
                              colorHex: selectedColor,
                            );
                            ref
                                .read(subjectsProvider.notifier)
                                .updateSubject(updated);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Course updated!')),
                            );
                          } else {
                            final newSub = SubjectModel(
                              id: UuidUtil.generate(),
                              name: name,
                              code: code,
                              professor: prof,
                              minAttendancePct: minAttendance.toInt(),
                              colorHex: selectedColor,
                            );
                            ref
                                .read(subjectsProvider.notifier)
                                .addSubject(newSub);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('New course created!')),
                            );
                          }

                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isEditing ? 'Save Changes' : 'Create Course',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteSubject(
    BuildContext context,
    SubjectModel subject,
    List<TimetableSlotModel> allSlots,
  ) {
    final relatedSlots =
        allSlots.where((s) => s.subjectId == subject.id).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${subject.code}?'),
        content: Text(
          relatedSlots.isEmpty
              ? 'Are you sure you want to delete "${subject.name}"?'
              : 'Warning: Deleting "${subject.name}" will also automatically remove its ${relatedSlots.length} weekly timetable slots!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(subjectsProvider.notifier).deleteSubject(subject.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Deleted "${subject.name}" and cleared associated slots.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Subject'),
          ),
        ],
      ),
    );
  }

  String _dayNameFromWeekday(int w) {
    switch (w) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Day';
    }
  }

  String _monthName(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return (m >= 1 && m <= 12) ? months[m - 1] : '';
  }

  DateTime _upcomingDateForWeekday(int targetWeekday) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = (targetWeekday - today.weekday) % 7;
    return today.add(Duration(days: diff));
  }

  void _openQuickOverrideDialog(
    BuildContext context,
    TimetableSlotModel slot,
    SubjectModel subject, {
    List<TimetableSlotModel>? selectableSlots,
    List<SubjectModel>? allSubjects,
  }) {
    TimetableSlotModel currentSlot = slot;
    SubjectModel currentSubject = subject;
    final roomController = TextEditingController(text: currentSlot.defaultRoom);
    final meetingUrlController =
        TextEditingController(text: currentSlot.meetingUrl ?? '');
    final topicController = TextEditingController();
    OverrideStatus status = OverrideStatus.rescheduled;
    String startTime = Formatters.normalizeTime(currentSlot.startTime);
    String endTime = Formatters.normalizeTime(currentSlot.endTime);
    DateTime originDate = _upcomingDateForWeekday(currentSlot.dayOfWeek);
    DateTime selectedDate = originDate;
    bool updatePermanentSlot = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Direct Broadcast: ${currentSubject.code}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Regular (${_dayNameFromWeekday(currentSlot.dayOfWeek)}): ${currentSlot.formattedTimeRange} • ${currentSlot.defaultRoom}',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),

                    if (selectableSlots != null &&
                        selectableSlots.length > 1) ...[
                      Text(
                        'Select Lecture Slot',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: currentSlot.id,
                            isExpanded: true,
                            items: selectableSlots.map((s) {
                              final sub = allSubjects != null
                                  ? (resolveSubjectById(
                                          allSubjects, s.subjectId) ??
                                      currentSubject)
                                  : currentSubject;
                              return DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                  '${sub.code} (${_dayNameFromWeekday(s.dayOfWeek)} ${s.formattedStartTime}) • ${s.defaultRoom}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                            onChanged: (newId) {
                              if (newId == null) return;
                              final pickedSlot = selectableSlots
                                  .firstWhere((s) => s.id == newId);
                              final pickedSub = allSubjects != null
                                  ? (resolveSubjectById(
                                          allSubjects, pickedSlot.subjectId) ??
                                      currentSubject)
                                  : currentSubject;
                              setModalState(() {
                                currentSlot = pickedSlot;
                                currentSubject = pickedSub;
                                roomController.text = pickedSlot.defaultRoom;
                                meetingUrlController.text =
                                    pickedSlot.meetingUrl ?? '';
                                startTime = Formatters.normalizeTime(
                                    pickedSlot.startTime);
                                endTime = Formatters.normalizeTime(
                                    pickedSlot.endTime);
                                originDate = _upcomingDateForWeekday(
                                    pickedSlot.dayOfWeek);
                                selectedDate = originDate;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Text(
                      'Action Type',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            avatar: const Icon(Icons.cancel_rounded,
                                size: 16, color: Colors.white),
                            label: const Text('Cancel Lecture'),
                            selected: status == OverrideStatus.cancelled,
                            selectedColor: AppColors.danger,
                            labelStyle: TextStyle(
                              color: status == OverrideStatus.cancelled
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            onSelected: (_) {
                              setModalState(
                                  () => status = OverrideStatus.cancelled);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            avatar: const Icon(Icons.schedule_rounded,
                                size: 16, color: Colors.white),
                            label: const Text('Reschedule / Shift'),
                            selected: status == OverrideStatus.rescheduled,
                            selectedColor: AppColors.warning,
                            labelStyle: TextStyle(
                              color: status == OverrideStatus.rescheduled
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            onSelected: (_) {
                              setModalState(
                                  () => status = OverrideStatus.rescheduled);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (status == OverrideStatus.rescheduled) ...[
                      // Reschedule Date / Day
                      Text(
                        'Meeting Day / Date',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate:
                                DateTime.now().subtract(const Duration(days: 7)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${_dayNameFromWeekday(selectedDate.weekday)}, ${selectedDate.day} ${_monthName(selectedDate.month)} ${selectedDate.year}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_drop_down_rounded,
                                  color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Quick Day Chips (Mon .. Sun)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final d in _days)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(d['label'] as String),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selectedDate.weekday ==
                                            (d['day'] as int)
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                  backgroundColor:
                                      selectedDate.weekday == (d['day'] as int)
                                          ? AppColors.primary
                                          : AppColors.surfaceMuted,
                                  onPressed: () {
                                    final targetW = d['day'] as int;
                                    setModalState(() {
                                      selectedDate =
                                          _upcomingDateForWeekday(targetW);
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Meeting Time (Start & End)
                      Text(
                        'Meeting Time (Start & End)',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final norm = Formatters.normalizeTime(startTime);
                                final parts = (norm.isNotEmpty ? norm : '09:00')
                                    .split(':');
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                    hour: int.tryParse(parts[0]) ?? 9,
                                    minute: parts.length > 1
                                        ? (int.tryParse(parts[1]) ?? 0)
                                        : 0,
                                  ),
                                );
                                if (picked != null) {
                                  final h =
                                      picked.hour.toString().padLeft(2, '0');
                                  final m =
                                      picked.minute.toString().padLeft(2, '0');
                                  setModalState(() => startTime = '$h:$m');
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time_rounded,
                                        size: 18, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Start Time',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    AppColors.textSecondary)),
                                        Text(
                                            Formatters.formatTimeString(
                                                startTime),
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final norm = Formatters.normalizeTime(endTime);
                                final parts = (norm.isNotEmpty ? norm : '10:00')
                                    .split(':');
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                    hour: int.tryParse(parts[0]) ?? 10,
                                    minute: parts.length > 1
                                        ? (int.tryParse(parts[1]) ?? 0)
                                        : 0,
                                  ),
                                );
                                if (picked != null) {
                                  final h =
                                      picked.hour.toString().padLeft(2, '0');
                                  final m =
                                      picked.minute.toString().padLeft(2, '0');
                                  setModalState(() => endTime = '$h:$m');
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded,
                                        size: 18, color: AppColors.warning),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('End Time',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    AppColors.textSecondary)),
                                        Text(
                                            Formatters.formatTimeString(endTime),
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Room / Venue
                      Text(
                        'Room / Venue',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: roomController,
                        decoration: InputDecoration(
                          hintText: 'e.g. CS Lab 5 (2nd Floor)',
                          prefixIcon: const Icon(Icons.room_rounded, size: 18),
                          filled: true,
                          fillColor: AppColors.surfaceSubtle,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Meeting / Online Class URL (Optional)
                      Text(
                        'Meeting / Online Class URL (Optional)',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: meetingUrlController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          hintText:
                              'e.g. https://meet.google.com/... or Zoom link',
                          prefixIcon:
                              const Icon(Icons.video_call_rounded, size: 20),
                          filled: true,
                          fillColor: AppColors.surfaceSubtle,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Option to also update the permanent weekly slot
                      CheckboxListTile(
                        value: updatePermanentSlot,
                        onChanged: (val) => setModalState(
                            () => updatePermanentSlot = val ?? false),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.primary,
                        title: Text(
                          'Also update permanent weekly timetable slot',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    Text(
                      'Announcement / Reason (Optional)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: topicController,
                      decoration: InputDecoration(
                        hintText: status == OverrideStatus.cancelled
                            ? 'e.g. Professor attending conference'
                            : 'e.g. Extra prep session or Midterm shift',
                        filled: true,
                        fillColor: AppColors.surfaceSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final newRoom = roomController.text.trim().isNotEmpty
                              ? roomController.text.trim()
                              : currentSlot.defaultRoom;
                          final meetingUrlText =
                              meetingUrlController.text.trim();

                          if (status == OverrideStatus.rescheduled &&
                              updatePermanentSlot) {
                            await ref
                                .read(timetableSlotsProvider.notifier)
                                .updateSlot(
                                  currentSlot.copyWith(
                                    dayOfWeek: selectedDate.weekday,
                                    startTime: startTime,
                                    endTime: endTime,
                                    defaultRoom: newRoom,
                                    meetingUrl: meetingUrlText.isNotEmpty
                                        ? meetingUrlText
                                        : null,
                                    clearMeetingUrl: meetingUrlText.isEmpty,
                                  ),
                                );
                          }

                          final error = await ref
                              .read(dailyOverridesProvider.notifier)
                              .setDirectOverride(
                                slotId: currentSlot.id,
                                status: status,
                                date: status == OverrideStatus.cancelled
                                    ? selectedDate
                                    : originDate,
                                actualRoom: status == OverrideStatus.rescheduled
                                    ? newRoom
                                    : null,
                                actualStartTime:
                                    status == OverrideStatus.rescheduled
                                        ? startTime
                                        : null,
                                actualEndTime:
                                    status == OverrideStatus.rescheduled
                                        ? endTime
                                        : null,
                                rescheduledDate:
                                    status == OverrideStatus.rescheduled
                                        ? selectedDate
                                        : null,
                                meetingUrl: status == OverrideStatus.rescheduled &&
                                        meetingUrlText.isNotEmpty
                                    ? meetingUrlText
                                    : null,
                                topicCovered:
                                    topicController.text.trim().isNotEmpty
                                        ? topicController.text.trim()
                                        : null,
                              );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!context.mounted) return;

                          final successMsg = status == OverrideStatus.cancelled
                              ? 'Cancelled lecture broadcasted to class!'
                              : 'Lecture rescheduled (${Formatters.formatTimeRangeString(startTime, endTime)}) & broadcasted!';

                          if (error == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(successMsg),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$successMsg (Cloud: $error)'),
                                backgroundColor: AppColors.warning,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: status == OverrideStatus.cancelled
                              ? AppColors.danger
                              : AppColors.warning,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Broadcast Update to Students',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openBroadcastNewDialog(
    BuildContext context,
    List<TimetableSlotModel> slots,
    List<SubjectModel> subjects,
  ) {
    if (slots.isEmpty) return;

    final nowWeekday = DateTime.now().weekday;
    final todaySlots = slots.where((s) => s.dayOfWeek == nowWeekday).toList();
    final TimetableSlotModel selectedSlot =
        todaySlots.isNotEmpty ? todaySlots.first : slots.first;
    final SubjectModel subject =
        resolveSubjectById(subjects, selectedSlot.subjectId) ??
            (subjects.isNotEmpty
                ? subjects.first
                : const SubjectModel(
                    id: 'unknown',
                    name: 'Class Lecture',
                    code: 'LEC',
                    professor: 'Instructor',
                  ));

    _openQuickOverrideDialog(
      context,
      selectedSlot,
      subject,
      selectableSlots: slots,
      allSubjects: subjects,
    );
  }

  void _openSecurityManagement(BuildContext context) {
    final rollCtrl = TextEditingController();
    final pinCtrl = TextEditingController(text: '1234');
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final newWhitelistCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.security_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Admin Security & PIN Reset',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),

                // Section 1: Reset Student PIN
                Text(
                  'Reset Student Security PIN',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'If a student forgot their PIN or someone mistakenly claimed their roll number, reset it here.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: rollCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'Roll No (e.g. 23-SE-402)',
                          prefixIcon: Icon(Icons.badge_rounded, size: 18),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: pinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'New PIN',
                          prefixIcon: Icon(Icons.pin_rounded, size: 18),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final roll = rollCtrl.text.trim();
                      final newPin = pinCtrl.text.trim();
                      if (roll.isEmpty || newPin.isEmpty) return;
                      final ok = await AuthService.instance
                          .adminResetStudentPin(rollNo: roll, newPin: newPin);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'PIN for Roll No $roll has been reset to $newPin!'
                                : 'Roll No "$roll" not found in student registry.'),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.danger,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.lock_reset_rounded, size: 16),
                    label: const Text('Reset Student PIN'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),

                // Section 2: Change Master Admin Passkey
                Text(
                  'Change Admin Master Passkey',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Master passkey is configured in your .env / env.json. You can update it below.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: oldPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Current Passkey',
                          prefixIcon: Icon(Icons.key_rounded, size: 18),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: newPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'New Passkey',
                          prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final oldP = oldPassCtrl.text.trim();
                      final newP = newPassCtrl.text.trim();
                      if (oldP.isEmpty || newP.isEmpty) return;
                      final ok = await AuthService.instance.changeAdminPasscode(
                        oldPasskey: oldP,
                        newPasskey: newP,
                      );
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Admin Master Passkey successfully changed!'
                                : 'Incorrect current passkey. Update failed.'),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.danger,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.password_rounded, size: 16),
                    label: const Text('Update Admin Passkey'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),

                // Section 3: Authorized Admin Roll Numbers (Whitelist)
                Row(
                  children: [
                    Icon(Icons.verified_user_rounded,
                        size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Authorized Admin Roll Numbers',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Even if the passcode is leaked, only students with these Roll Numbers can unlock the Admin Console.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final whitelist = ref.watch(adminWhitelistProvider);
                    return Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: whitelist.map((r) {
                        final isProtected = r == '23-SE-402';
                        return Chip(
                          backgroundColor: AppColors.blueBg,
                          side: BorderSide(color: AppColors.blueBorder),
                          avatar: Icon(Icons.shield_rounded,
                              size: 14, color: AppColors.primary),
                          label: Text(
                            r,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              color: AppColors.primary,
                            ),
                          ),
                          deleteIcon: isProtected
                              ? null
                              : const Icon(Icons.close_rounded, size: 14),
                          onDeleted: isProtected
                              ? null
                              : () async {
                                  await ref
                                      .read(adminWhitelistProvider.notifier)
                                      .remove(r);
                                },
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newWhitelistCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'Add Roll No (e.g. 23-SE-405)',
                          prefixIcon: Icon(Icons.badge_rounded, size: 18),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final roll = newWhitelistCtrl.text.trim().toUpperCase();
                        if (roll.isEmpty) return;
                        await ref
                            .read(adminWhitelistProvider.notifier)
                            .add(roll);
                        newWhitelistCtrl.clear();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Roll No "$roll" added to Admin Whitelist!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.add_moderator_rounded, size: 16),
                      label: const Text('Authorize'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================================================================
  // TAB 5: CONTRIBUTOR / UPLOADER VERIFICATION REQUESTS MANAGER
  // ===================================================================

  Widget _buildUploaderRequestsManager(
    List<UploaderRequestModel> requests,
    List<StudentVerificationRequestModel> studentVerifications,
    List<UserModel> users,
  ) {
    final pendingStudentReqs =
        studentVerifications.where((r) => r.isPending).toList();
    final query = _uploaderReqSearch.trim().toLowerCase();
    final filtered = requests.where((r) {
      if (_uploaderReqFilter == 'pending' && !r.isPending) return false;
      if (_uploaderReqFilter == 'approved' && !r.isApproved) return false;
      if (_uploaderReqFilter == 'rejected' && !r.isRejected) return false;
      if (query.isNotEmpty) {
        final matchEmail = r.googleEmail.toLowerCase().contains(query);
        final matchName = r.name.toLowerCase().contains(query);
        final matchRoll = r.rollNo.toLowerCase().contains(query);
        if (!matchEmail && !matchName && !matchRoll) return false;
      }
      return true;
    }).toList();

    final pendingCount = requests.where((r) => r.isPending).length;
    final approvedCount = requests.where((r) => r.isApproved).length;
    final rejectedCount = requests.where((r) => r.isRejected).length;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(uploaderRequestsProvider.notifier).refresh();
        await ref
            .read(studentVerificationRequestsProvider.notifier)
            .refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Verified Student Badge Requests Section (Anti-Fake Account Gate)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_rounded,
                        color: AppColors.primary, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verified Student Badge Requests',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${pendingStudentReqs.length} PENDING',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Verify Name & Roll No before granting the Verified Student Badge (required for Note Bounties). Existing verified accounts are unaffected.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                if (pendingStudentReqs.isEmpty)
                  Text(
                    'No pending Student Badge requests right now.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  for (final sReq in pendingStudentReqs) ...[
                    Builder(builder: (_) {
                      final normReqUid = UuidUtil.fromString(sReq.userId);
                      final cleanReqRoll = sReq.rollNo.trim().toUpperCase();
                      final clash = users.cast<UserModel?>().firstWhere(
                            (u) =>
                                u != null &&
                                u.isKzynovexVerified &&
                                UuidUtil.fromString(u.id) != normReqUid &&
                                (u.rollNo ?? '').trim().toUpperCase() ==
                                    cleanReqRoll &&
                                cleanReqRoll.isNotEmpty,
                            orElse: () => null,
                          );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: clash != null
                              ? AppColors.dangerBg
                              : AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: clash != null
                                ? AppColors.danger.withValues(alpha: 0.45)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${sReq.name} (${sReq.rollNo})',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    sReq.email,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (clash != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '⚠️ Roll No already verified on ${clash.name} (${clash.email})',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Approve Badge',
                              icon: const Icon(Icons.check_circle_rounded,
                                  color: AppColors.success),
                              onPressed: () async {
                                await ref
                                    .read(studentVerificationRequestsProvider
                                        .notifier)
                                    .approveRequest(sReq.id);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Verified badge granted to ${sReq.name} (${sReq.rollNo})!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: 'Reject Badge',
                              icon: const Icon(Icons.cancel_rounded,
                                  color: AppColors.danger),
                              onPressed: () async {
                                await ref
                                    .read(studentVerificationRequestsProvider
                                        .notifier)
                                    .rejectRequest(sReq.id);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Student badge request rejected.'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Banner card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF3730A3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3730A3).withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.verified_user_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Uploader Verification Portal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white70, size: 18),
                      tooltip: 'Refresh Requests',
                      onPressed: () =>
                          ref.read(uploaderRequestsProvider.notifier).refresh(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Review student requests to post lecture notes & study materials. Verify their Roll Number against the official roster.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_rounded, size: 14, color: Colors.amber),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Verified Administrator Console (Elevated Privilege)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatPill(
                      label: 'Total Requests',
                      count: requests.length,
                      icon: Icons.list_alt_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      label: 'Pending',
                      count: pendingCount,
                      icon: Icons.hourglass_top_rounded,
                      color: AppColors.warningBorder,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      label: 'Approved',
                      count: approvedCount,
                      icon: Icons.check_circle_rounded,
                      color: AppColors.successBorder,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search bar
          TextField(
            controller: _uploaderSearchCtrl,
            onChanged: (val) => setState(() => _uploaderReqSearch = val),
            decoration: InputDecoration(
              hintText: 'Search by Name, Roll No or Google Email...',
              hintStyle:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _uploaderReqSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _uploaderSearchCtrl.clear();
                        setState(() => _uploaderReqSearch = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceSubtle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildUploaderFilterChip('all', 'All (${requests.length})'),
                const SizedBox(width: 8),
                _buildUploaderFilterChip('pending', 'Pending ($pendingCount)'),
                const SizedBox(width: 8),
                _buildUploaderFilterChip('approved', 'Approved ($approvedCount)'),
                const SizedBox(width: 8),
                _buildUploaderFilterChip('rejected', 'Rejected ($rejectedCount)'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Requests List
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 40, color: AppColors.borderStrong),
                    const SizedBox(height: 8),
                    Text(
                      _uploaderReqSearch.isNotEmpty
                          ? 'No verification requests matching "$_uploaderReqSearch"'
                          : 'No $_uploaderReqFilter verification requests found',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((req) => _buildUploaderRequestCard(req)),
        ],
      ),
    );
  }

  Widget _buildUploaderRequestCard(UploaderRequestModel req) {
    final isPending = req.isPending;
    final isApproved = req.isApproved;

    Color badgeColor = const Color(0xFFD97706);
    Color badgeBg = AppColors.warningBg;
    String statusLabel = 'PENDING VERIFICATION';

    if (isApproved) {
      badgeColor = const Color(0xFF059669);
      badgeBg = AppColors.successBgStrong;
      statusLabel = 'APPROVED CONTRIBUTOR';
    } else if (req.isRejected) {
      badgeColor = AppColors.danger;
      badgeBg = AppColors.dangerBgStrong;
      statusLabel = 'DECLINED';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? AppColors.warningBorder
              : (isApproved ? AppColors.successBorder : AppColors.border),
          width: isPending ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: badgeColor.withValues(alpha: 0.12),
                  child: Text(
                    req.name.isNotEmpty ? req.name[0].toUpperCase() : 'S',
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              req.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: badgeColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: badgeColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.badge_outlined,
                                    size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Roll No: ${req.rollNo}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              req.googleEmail,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Submitted: ${req.submittedAt.day}/${req.submittedAt.month}/${req.submittedAt.year} at ${req.submittedAt.hour.toString().padLeft(2, '0')}:${req.submittedAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  if (req.reviewedBy != null) ...[
                    const Spacer(),
                    Text(
                      'Reviewed by: ${req.reviewedBy}',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ACTION BUTTONS
            if (isPending) ...[
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await ref
                            .read(uploaderRequestsProvider.notifier)
                            .approve(req.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Verified & Authorized: ${req.name} (${req.rollNo}) can now post notes!'),
                              backgroundColor: AppColors.snackBarBg,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Verify & Authorize Posting'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () async {
                        await ref
                            .read(uploaderRequestsProvider.notifier)
                            .reject(req.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Request declined.'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: BorderSide(color: AppColors.dangerBorder),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ] else if (isApproved) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.successBgStrong,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '✓ Active Contributor Access',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await ref
                          .read(uploaderRequestsProvider.notifier)
                          .reject(req.id, reason: 'Revoked by admin.');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Posting access revoked for ${req.name}.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.block_rounded,
                        size: 14, color: AppColors.danger),
                    label: const Text('Revoke Access',
                        style: TextStyle(fontSize: 11, color: AppColors.danger)),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Text(
                    req.rejectionReason ?? 'Declined by Admin.',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await ref
                          .read(uploaderRequestsProvider.notifier)
                          .approve(req.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Re-verified and approved for ${req.name}!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.replay_rounded,
                        size: 14, color: Color(0xFF059669)),
                    label: const Text('Re-verify & Approve',
                        style: TextStyle(fontSize: 11, color: Color(0xFF059669))),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // TAB 6: USERS & STUDENTS ROSTER MANAGER
  // ===================================================================

  Widget _buildUsersManager(List<UserModel> users) {
    final query = _userSearchQuery.trim().toLowerCase();
    final filteredUsers = users.where((u) {
      // Search matching
      if (query.isNotEmpty) {
        final nameMatch = u.name.toLowerCase().contains(query);
        final rollMatch = (u.rollNo ?? '').toLowerCase().contains(query);
        final emailMatch = u.email.toLowerCase().contains(query);
        if (!nameMatch && !rollMatch && !emailMatch) return false;
      }

      // Filter category
      if (_userRoleFilter == 'student' && u.role != 'student') return false;
      if (_userRoleFilter == 'admin' && u.role != 'admin') return false;
      if (_userRoleFilter == 'verified' && !u.isKzynovexVerified) return false;

      return true;
    }).toList();

    final totalCount = users.length;
    final studentCount = users.where((u) => u.role == 'student').length;
    final adminCount = users.where((u) => u.role == 'admin').length;
    final verifiedCount = users.where((u) => u.isKzynovexVerified).length;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(usersListProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stat Highlights Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF312E81).withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.manage_accounts_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Student & Admin Registry',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white70, size: 18),
                      tooltip: 'Refresh Roster',
                      onPressed: () =>
                          ref.read(usersListProvider.notifier).refresh(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatPill(
                      label: 'Total Users',
                      count: totalCount,
                      icon: Icons.people_rounded,
                      color: const Color(0xFF93C5FD),
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      label: 'Students',
                      count: studentCount,
                      icon: Icons.school_rounded,
                      color: AppColors.successBorder,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      label: 'Admins',
                      count: adminCount,
                      icon: Icons.shield_rounded,
                      color: AppColors.warningBorder,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      label: 'Verified',
                      count: verifiedCount,
                      icon: Icons.verified_rounded,
                      color: const Color(0xFFFBCFE8),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search bar and + Add User Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userSearchCtrl,
                  onChanged: (val) {
                    setState(() => _userSearchQuery = val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name, roll no, or email...',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _userSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _userSearchCtrl.clear();
                              setState(() => _userSearchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _openAddUserSheet(context),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Add User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All ($totalCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('student', 'Students ($studentCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('admin', 'Admins ($adminCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('verified', 'Verified Scholars ($verifiedCount)'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // User list
          if (filteredUsers.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_search_rounded,
                        size: 36, color: AppColors.primary),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No users found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _userSearchQuery.isNotEmpty
                        ? 'No user matches "$_userSearchQuery". Try another keyword or clear search.'
                        : 'No users registered under this filter.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _openAddUserSheet(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('Add New Student / User'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...filteredUsers.map((user) => _buildUserCard(user)),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _userRoleFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _userRoleFilter = key);
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.cardSurface,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _buildUploaderFilterChip(String key, String label) {
    final isSelected = _uploaderReqFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _uploaderReqFilter = key);
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.cardSurface,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    final isAdmin = user.role == 'admin';
    final initials = user.name.trim().isNotEmpty
        ? user.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAdmin
              ? AppColors.warningBorder
              : AppColors.border,
          width: isAdmin ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isAdmin
                      ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                      : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isAdmin
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF6366F1))
                        .withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and role tag
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isKzynovexVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? AppColors.warningBg
                              : AppColors.blueBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isAdmin
                                ? AppColors.warningBorder
                                : AppColors.blueBorder,
                          ),
                        ),
                        child: Text(
                          isAdmin ? 'ADMIN' : 'STUDENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isAdmin
                                ? const Color(0xFFD97706)
                                : const Color(0xFF2563EB),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Roll number & email
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.badge_rounded,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              user.rollNo ?? 'No Roll No',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (user.email.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.email_outlined,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Stats pills: Credits & Streak
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars_rounded,
                                size: 13, color: Color(0xFF9333EA)),
                            const SizedBox(width: 4),
                            Text(
                              '${user.credits} pts',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7E22CE),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded,
                                size: 13, color: Color(0xFFEA580C)),
                            const SizedBox(width: 4),
                            Text(
                              '${user.streakCount}d streak',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFC2410C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions popup menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: AppColors.textSecondary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (val) async {
                switch (val) {
                  case 'edit':
                    _openEditUserSheet(context, user);
                    break;
                  case 'toggle_upload':
                    final newCanUpload = !user.isUploaderVerified;
                    final updated = user.copyWith(
                      canUpload: newCanUpload,
                      uploadRequestStatus: newCanUpload ? 'approved' : 'none',
                    );
                    await ref.read(usersListProvider.notifier).updateUser(updated);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(newCanUpload
                              ? 'Upload posting access granted to ${user.name}!'
                              : 'Upload posting access revoked for ${user.name}.'),
                        ),
                      );
                    }
                    break;
                  case 'reset_pin':
                    _openResetPinDialog(context, user);
                    break;
                  case 'delete':
                    _confirmDeleteUser(context, user);
                    break;
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded,
                          size: 18, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Edit Details'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_upload',
                  child: Row(
                    children: [
                      Icon(
                        user.isUploaderVerified
                            ? Icons.block_rounded
                            : Icons.cloud_done_rounded,
                        size: 18,
                        color: user.isUploaderVerified
                            ? AppColors.danger
                            : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 10),
                      Text(user.isUploaderVerified
                          ? 'Revoke Upload Access'
                          : 'Grant Upload Access'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset_pin',
                  child: Row(
                    children: [
                      Icon(Icons.lock_reset_rounded,
                          size: 18, color: AppColors.warning),
                      SizedBox(width: 10),
                      Text('Reset PIN'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppColors.danger),
                      SizedBox(width: 10),
                      Text(
                        'Delete Account',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // USER CRUD DIALOGS & BOTTOM SHEETS
  // ===================================================================

  void _openAddUserSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final pinCtrl = TextEditingController(text: '1234');
    String selectedRole = 'student';
    bool isVerified = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.person_add_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Pre-Register Student / User',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),

                // Name
                Text(
                  'Full Student Name *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Ali Ahmed Khan',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 14),

                // Roll No
                Text(
                  'Roll Number (Unique ID) *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: rollCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 23-SE-402',
                    prefixIcon: Icon(Icons.badge_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 14),

                // Email
                Text(
                  'Email Address (Optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'e.g. ali@university.edu.pk',
                    prefixIcon: Icon(Icons.email_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 14),

                // Initial PIN
                Text(
                  'Initial 4-Digit Security PIN *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 1234',
                    counterText: '',
                    prefixIcon: Icon(Icons.pin_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 14),

                // Role selector
                Text(
                  'Account Role',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Student'),
                          ],
                        ),
                        selected: selectedRole == 'student',
                        onSelected: (_) =>
                            setSheetState(() => selectedRole = 'student'),
                        selectedColor: AppColors.primarySoft,
                        side: BorderSide(
                          color: selectedRole == 'student'
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Admin'),
                          ],
                        ),
                        selected: selectedRole == 'admin',
                        onSelected: (_) =>
                            setSheetState(() => selectedRole = 'admin'),
                        selectedColor: AppColors.warningBg,
                        side: BorderSide(
                          color: selectedRole == 'admin'
                              ? AppColors.warning
                              : AppColors.border,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Verified Scholar switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isVerified,
                  onChanged: (val) => setSheetState(() => isVerified = val),
                  title: const Text(
                    'Verified Scholar Badge',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Grants official student verification checkmark in class',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),

                const SizedBox(height: 20),

                // Create button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final roll = rollCtrl.text.trim().toUpperCase();
                      final email = emailCtrl.text.trim();
                      final pin = pinCtrl.text.trim();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter the student\'s name.')),
                        );
                        return;
                      }
                      if (roll.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter the Roll Number.')),
                        );
                        return;
                      }
                      if (pin.length < 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Security PIN must be at least 4 digits.')),
                        );
                        return;
                      }

                      final newUser = UserModel(
                        id: UuidUtil.generate(),
                        name: name,
                        rollNo: roll,
                        email: email,
                        role: selectedRole,
                        credits: 30,
                        streakCount: 1,
                        isKzynovexVerified: isVerified,
                      );

                      final result = await ref
                          .read(usersListProvider.notifier)
                          .createUser(newUser, pin);

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.message),
                            backgroundColor: result.success
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Create User & Enroll',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openEditUserSheet(BuildContext context, UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    final creditsCtrl = TextEditingController(text: '${user.credits}');
    final streakCtrl = TextEditingController(text: '${user.streakCount}');
    final newPinCtrl = TextEditingController();
    String selectedRole = user.role;
    bool isVerified = user.isKzynovexVerified;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.edit_note_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit User: ${user.name}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Roll No: ${user.rollNo ?? "N/A"}',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 10),

                // Name
                Text(
                  'Full Student Name',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 14),

                // Email
                Text(
                  'Email Address',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 14),

                // Credits & Streak row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credits',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: creditsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.stars_rounded, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Streak Days',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: streakCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.local_fire_department_rounded, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Optional new PIN
                Text(
                  'Set New PIN (Leave blank to keep current)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: newPinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    hintText: 'Optional new 4-digit PIN',
                    counterText: '',
                    prefixIcon: Icon(Icons.pin_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 14),

                // Role Selector
                Text(
                  'Account Role',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Student'),
                          ],
                        ),
                        selected: selectedRole == 'student',
                        onSelected: (_) =>
                            setSheetState(() => selectedRole = 'student'),
                        selectedColor: AppColors.primarySoft,
                        side: BorderSide(
                          color: selectedRole == 'student'
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Admin'),
                          ],
                        ),
                        selected: selectedRole == 'admin',
                        onSelected: (_) =>
                            setSheetState(() => selectedRole = 'admin'),
                        selectedColor: AppColors.warningBg,
                        side: BorderSide(
                          color: selectedRole == 'admin'
                              ? AppColors.warning
                              : AppColors.border,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Verified Scholar switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isVerified,
                  onChanged: (val) => setSheetState(() => isVerified = val),
                  title: const Text(
                    'Verified Scholar Badge',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Grants official student verification checkmark in class',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),

                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final creds = int.tryParse(creditsCtrl.text.trim()) ?? user.credits;
                      final streak = int.tryParse(streakCtrl.text.trim()) ?? user.streakCount;
                      final newPin = newPinCtrl.text.trim();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Name cannot be empty.')),
                        );
                        return;
                      }

                      final updatedUser = user.copyWith(
                        name: name,
                        email: email,
                        role: selectedRole,
                        credits: creds,
                        streakCount: streak,
                        isKzynovexVerified: isVerified,
                      );

                      final ok = await ref
                          .read(usersListProvider.notifier)
                          .updateUser(
                            updatedUser,
                            newPin: newPin.isNotEmpty ? newPin : null,
                          );

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'User "${updatedUser.name}" successfully updated!'
                                : 'Failed to update user.'),
                            backgroundColor:
                                ok ? AppColors.success : AppColors.danger,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save User Changes',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openResetPinDialog(BuildContext context, UserModel user) {
    final pinCtrl = TextEditingController(text: '1234');
    final identifier = user.rollNo?.trim().isNotEmpty == true
        ? user.rollNo!.trim()
        : (user.email.trim().isNotEmpty ? user.email.trim() : user.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.lock_reset_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Reset Security PIN'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resetting PIN for ${user.name} ($identifier).',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'New 4-Digit PIN',
                counterText: '',
                prefixIcon: Icon(Icons.pin_rounded, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPin = pinCtrl.text.trim();
              if (newPin.length < 4) return;
              final ok = await ref
                  .read(usersListProvider.notifier)
                  .resetPin(identifier, newPin);
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'PIN for ${user.name} reset to $newPin!'
                        : 'Failed to reset PIN.'),
                    backgroundColor: ok ? AppColors.success : AppColors.danger,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset PIN'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUser(BuildContext context, UserModel user) {
    final identifier = user.rollNo?.trim().isNotEmpty == true
        ? user.rollNo!.trim()
        : (user.email.trim().isNotEmpty ? user.email.trim() : user.id);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete ${user.name}?'),
        content: Text(
          'Are you sure you want to delete user "${user.name}" ($identifier)? Their account data will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await ref
                  .read(usersListProvider.notifier)
                  .deleteUser(identifier);
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'User "${user.name}" deleted from registry.'
                        : 'Failed to delete user.'),
                    backgroundColor: ok ? AppColors.success : AppColors.danger,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// ADMIN HELPER CARDS
// ===================================================================

class _AdminSlotCard extends StatelessWidget {
  final TimetableSlotModel slot;
  final SubjectModel subject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onQuickOverride;

  const _AdminSlotCard({
    required this.slot,
    required this.subject,
    required this.onEdit,
    required this.onDelete,
    required this.onQuickOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Time badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  slot.formattedStartTime,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  slot.formattedEndTime,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Course info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: subject.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        subject.code,
                        style: TextStyle(
                          color: subject.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        slot.defaultRoom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subject.professor,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (slot.hasMeetingUrl) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => Formatters.launchMeetingUrl(
                        context, slot.effectiveMeetingUrl),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.video_call_rounded,
                              size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'Join Class Meeting',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.open_in_new_rounded,
                              size: 11, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Quick actions
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary),
            onSelected: (val) {
              if (val == 'edit') onEdit();
              if (val == 'delete') onDelete();
              if (val == 'broadcast') onQuickOverride();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'broadcast',
                child: Row(
                  children: [
                    Icon(Icons.campaign_rounded,
                        size: 18, color: AppColors.warning),
                    SizedBox(width: 8),
                    Text('Direct Broadcast (Cancel/Shift)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded,
                        size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Edit Slot'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Delete Slot'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminSubjectCard extends StatelessWidget {
  final SubjectModel subject;
  final int slotCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminSubjectCard({
    required this.subject,
    required this.slotCount,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 48,
            decoration: BoxDecoration(
              color: subject.color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: subject.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        subject.code,
                        style: TextStyle(
                          color: subject.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$slotCount weekly lectures',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subject.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${subject.professor} • Min target: ${subject.minAttendancePct}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            icon: Icon(Icons.edit_rounded,
                size: 20, color: AppColors.primary),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 20, color: AppColors.danger),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AdminOverrideCard extends StatelessWidget {
  final DailyOverrideModel dailyOverride;
  final List<TimetableSlotModel> slots;
  final List<SubjectModel> subjects;
  final VoidCallback onDelete;

  const _AdminOverrideCard({
    required this.dailyOverride,
    required this.slots,
    required this.subjects,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final targetSlotUuid = UuidUtil.fromString(dailyOverride.slotId);
    final slot = slots.cast<TimetableSlotModel?>().firstWhere(
          (s) => s != null && (s.id == dailyOverride.slotId || UuidUtil.fromString(s.id) == targetSlotUuid),
          orElse: () => null,
        );

    final targetSubjectUuid = slot != null ? UuidUtil.fromString(slot.subjectId) : null;
    final subject = slot != null
        ? subjects.firstWhere(
            (s) => s.id == slot.subjectId || (targetSubjectUuid != null && UuidUtil.fromString(s.id) == targetSubjectUuid),
            orElse: () => subjects.first,
          )
        : null;

    final isCancelled = dailyOverride.status == OverrideStatus.cancelled;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCancelled
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? AppColors.danger.withValues(alpha: 0.1)
                      : AppColors.warningBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCancelled
                          ? Icons.cancel_rounded
                          : Icons.schedule_rounded,
                      size: 12,
                      color:
                          isCancelled ? AppColors.danger : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCancelled ? 'CLASS CANCELLED' : 'RESCHEDULED / SHIFTED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color:
                            isCancelled ? AppColors.danger : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.textSecondary),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subject != null
                ? '${subject.code} - ${subject.name}'
                : 'Lecture Slot #${dailyOverride.slotId}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (slot != null) ...[
            const SizedBox(height: 2),
            Text(
              'Scheduled: ${slot.formattedTimeRange} (Orig: ${slot.defaultRoom})',
              style: TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          if (dailyOverride.rescheduledDate != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Rescheduled Date: ${dailyOverride.rescheduledDate!.year}-${dailyOverride.rescheduledDate!.month.toString().padLeft(2, '0')}-${dailyOverride.rescheduledDate!.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
          if (dailyOverride.actualStartTime != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 13, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  'New Meeting Time: ${Formatters.formatTimeString(dailyOverride.actualStartTime)}${dailyOverride.actualEndTime != null ? ' - ${Formatters.formatTimeString(dailyOverride.actualEndTime)}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ],
          if (dailyOverride.actualRoom != null && dailyOverride.actualRoom!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.room_rounded, size: 13, color: AppColors.textPrimary),
                const SizedBox(width: 4),
                Text(
                  'Relocated To: ${dailyOverride.actualRoom}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
          if (dailyOverride.topicCovered != null) ...[
            const SizedBox(height: 4),
            Text(
              'Notice: "${dailyOverride.topicCovered}"',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (!isCancelled &&
              (dailyOverride.hasMeetingUrl || (slot?.hasMeetingUrl ?? false))) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => Formatters.launchMeetingUrl(
                context,
                dailyOverride.effectiveMeetingUrl ?? slot?.effectiveMeetingUrl,
              ),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.video_call_rounded,
                        size: 15, color: AppColors.primary),
                    SizedBox(width: 5),
                    Text(
                      'Join Class Meeting',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.open_in_new_rounded,
                        size: 12, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminModResourceCard extends StatelessWidget {
  final ResourceModel resource;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onEdit;

  const _AdminModResourceCard({
    required this.resource,
    required this.onApprove,
    required this.onReject,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(resource.type.icon,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'By ${resource.uploaderName}',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit Submission',
              icon: Icon(Icons.edit_outlined, color: AppColors.primary),
              onPressed: onEdit,
            ),
          IconButton(
            tooltip: 'Approve Submission',
            icon: const Icon(Icons.check_circle_rounded,
                color: AppColors.success),
            onPressed: onApprove,
          ),
          IconButton(
            tooltip: 'Reject & Delete Submission',
            icon: const Icon(Icons.cancel_rounded, color: AppColors.danger),
            onPressed: onReject,
          ),
        ],
      ),
    );
  }
}

class _AdminModOverrideCard extends StatelessWidget {
  final DailyOverrideModel dailyOverride;
  final List<SubjectModel> subjects;
  final List<TimetableSlotModel> slots;
  final List<UserModel> users;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _AdminModOverrideCard({
    required this.dailyOverride,
    required this.subjects,
    required this.slots,
    required this.users,
    required this.onApprove,
    required this.onReject,
  });

  String _resolveReporterLabel() {
    if (dailyOverride.reportedByName != null &&
        dailyOverride.reportedByName!.trim().isNotEmpty) {
      return dailyOverride.reportedByName!.trim();
    }
    final reporterId = dailyOverride.reportedBy;
    if (reporterId != null && reporterId.isNotEmpty) {
      final normReporter = UuidUtil.fromString(reporterId);
      final match = users.cast<UserModel?>().firstWhere(
            (u) =>
                u != null &&
                (u.id == reporterId || UuidUtil.fromString(u.id) == normReporter),
            orElse: () => null,
          );
      if (match != null) {
        final roll = match.rollNo?.trim();
        return (roll != null && roll.isNotEmpty)
            ? '${match.name} ($roll)'
            : match.name;
      }
      return 'User #${reporterId.substring(0, reporterId.length.clamp(0, 8))}';
    }
    return 'Unknown Student';
  }

  @override
  Widget build(BuildContext context) {
    final targetSlotUuid = UuidUtil.fromString(dailyOverride.slotId);
    final slot = slots.cast<TimetableSlotModel?>().firstWhere(
          (s) =>
              s != null &&
              (s.id == dailyOverride.slotId ||
                  UuidUtil.fromString(s.id) == targetSlotUuid),
          orElse: () => null,
        );
    final subject = slot != null
        ? resolveSubjectById(subjects, slot.subjectId)
        : null;
    final reporterLabel = _resolveReporterLabel();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.flag_rounded,
                color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject != null
                      ? '${subject.code} - ${subject.name}'
                      : 'Report: ${dailyOverride.status.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${dailyOverride.status.label}${slot != null ? ' • Orig: ${slot.formattedTimeRange}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Requested by: $reporterLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (dailyOverride.actualStartTime != null || dailyOverride.actualRoom != null || dailyOverride.rescheduledDate != null)
                  Text(
                    [
                      if (dailyOverride.actualStartTime != null) '${Formatters.formatTimeString(dailyOverride.actualStartTime)}${dailyOverride.actualEndTime != null ? ' - ${Formatters.formatTimeString(dailyOverride.actualEndTime)}' : ''}',
                      if (dailyOverride.actualRoom != null) '@ ${dailyOverride.actualRoom}',
                      if (dailyOverride.rescheduledDate != null) 'on ${dailyOverride.rescheduledDate!.month}/${dailyOverride.rescheduledDate!.day}',
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                if (dailyOverride.topicCovered != null)
                  Text(
                    dailyOverride.topicCovered!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_rounded,
                color: AppColors.success),
            onPressed: onApprove,
          ),
          IconButton(
            icon: const Icon(Icons.cancel_rounded, color: AppColors.danger),
            onPressed: onReject,
          ),
        ],
      ),
    );
  }
}
