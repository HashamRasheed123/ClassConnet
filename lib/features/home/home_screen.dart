import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/alert_scheduler.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/admin_passcode_dialog.dart';
import '../../models/models.dart';
import '../../providers/class_providers.dart';
import '../assignment_scanner/assignment_scanner_screen.dart';
import '../assignments/assignment_tracker_screen.dart';
import '../quizzes/quiz_center_screen.dart';
import '../vault/vault_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final todayLectures = ref.watch(todayLecturesProvider);
    final nextLecture = ref.watch(nextLectureProvider);
    final syncState = ref.watch(syncStateProvider);
    final allAssignments = ref.watch(assignmentsProvider);
    final completedAssignmentIds = ref.watch(assignmentCompletionProvider);
    final allQuizzes = ref.watch(quizzesProvider);
    final subjects = ref.watch(subjectsProvider);
    final subjectMap = {for (var s in subjects) s.id: s};

    final dueTomorrowAssignments = allAssignments.where((a) {
      final isDone = completedAssignmentIds.contains(a.id);
      return !isDone && (a.isOverdue || a.isDueToday || a.isDueTomorrow);
    }).toList();

    final now = DateTime.now();
    final dateFormatted = DateFormat('EEEE, d MMMM').format(now);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: user.isAdmin
          ? FloatingActionButton.extended(
              heroTag: null,
              backgroundColor: AppColors.primary,
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onPressed: () => showUploadModal(context, ref),
              icon:
                  const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Upload Resource',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // TOP HEADER
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar: Date + Role Switcher
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dateFormatted,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Role Mode Toggle (Only visible to Admin accounts)
                        if (user.isAdmin || AuthService.isAdminEmail(user.email)) ...[
                          InkWell(
                            onTap: () async {
                              if (user.isAdmin) {
                                ref.read(currentUserProvider.notifier).downgradeToStudent();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Switched to Student Mode'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                final unlocked = await showAdminPasscodeDialog(
                                  context,
                                  ref,
                                  autoOpenConsole: true,
                                );
                                if (unlocked && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Admin View Enabled: Console Unlocked'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: user.isAdmin
                                    ? const Color(0xFFFEF3C7) // Amber tint
                                    : AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: user.isAdmin
                                      ? AppColors.warning
                                      : AppColors.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    user.isAdmin
                                        ? Icons.admin_panel_settings_rounded
                                        : Icons.school_rounded,
                                    size: 13,
                                    color: user.isAdmin
                                        ? AppColors.warning
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    user.isAdmin ? 'ADMIN VIEW' : 'STUDENT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: user.isAdmin
                                          ? AppColors.warning
                                          : AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // Cloud Sync Quick Indicator
                        InkWell(
                          onTap: syncState.isSyncing
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
                                            ? AppColors.textPrimary
                                            : AppColors.danger,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: syncState.pendingCount > 0
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: syncState.pendingCount > 0
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (syncState.isSyncing)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: AppColors.primary,
                                    ),
                                  )
                                else
                                  Icon(
                                    syncState.pendingCount > 0
                                        ? Icons.cloud_upload_rounded
                                        : Icons.cloud_done_rounded,
                                    size: 13,
                                    color: syncState.pendingCount > 0
                                        ? AppColors.warning
                                        : AppColors.success,
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  syncState.pendingCount > 0
                                      ? '${syncState.pendingCount}'
                                      : 'Sync',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: syncState.pendingCount > 0
                                        ? const Color(0xFFB45309)
                                        : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Greeting + Credits Pill
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_getGreeting()}, ${user.name.trim().isEmpty ? 'Scholar' : user.name.trim().split(' ').first}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        // Royal Purple Credit Balance Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt_rounded,
                                  size: 16, color: Colors.amberAccent),
                              const SizedBox(width: 4),
                              Text(
                                '${user.credits} Credits',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
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
            ),

            // ACTIVE LECTURE / MEETING ALARM PANEL (Brought to front when alarm rings)
            SliverToBoxAdapter(
              child: ValueListenableBuilder<ActiveLectureAlarm?>(
                valueListenable: AlertScheduler.instance.activeAlarmNotifier,
                builder: (context, activeAlarm, _) {
                  if (activeAlarm == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _ActiveMeetingAlarmPanel(alarm: activeAlarm),
                  );
                },
              ),
            ),

            // URGENT ASSIGNMENTS DUE TOMORROW BANNER
            if (dueTomorrowAssignments.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: UrgentAssignmentsBanner(
                    assignments: dueTomorrowAssignments,
                    subjectMap: subjectMap,
                  ),
                ),
              ),

            // NEXT LECTURE HERO CARD
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: NextLectureHeroCard(lecture: nextLecture),
              ),
            ),

            // DUAL QUICK LAUNCHERS: ASSIGNMENT TRACKER + SCANNER (2-Column Action Row)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    // Assignment Tracker Launcher
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AssignmentTrackerScreen(),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.06),
                                blurRadius: 10,
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
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.assignment_turned_in_rounded,
                                      color: Color(0xFF4F46E5),
                                      size: 20,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${allAssignments.where((a) => !completedAssignmentIds.contains(a.id)).length} Due',
                                      style: const TextStyle(
                                        color: Color(0xFF4F46E5),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Assignments',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Deadlines & Tasks',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Assignment PDF Maker Launcher
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AssignmentScannerScreen(),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.25),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.06),
                                blurRadius: 10,
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
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.document_scanner_rounded,
                                      color: Color(0xFF059669),
                                      size: 20,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Offline',
                                      style: TextStyle(
                                        color: Color(0xFF059669),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Doc Scanner',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Make Clean PDFs',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // NOTEBOOKLM & COURSE MCQ QUIZ CENTER QUICK LAUNCHER
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QuizCenterScreen(),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.psychology_alt_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MCQ Quizzes & Practice Tests',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'NotebookLM Quizzes • Check MCQs or Take Scored Test',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${allQuizzes.length} Quizzes',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // TODAY'S TIMELINE SECTION HEADER
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateTime.now().weekday == 7
                          ? "Sunday's Schedule"
                          : "Today's Timeline",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      todayLectures.isEmpty
                          ? 'No Classes'
                          : '${todayLectures.length} Classes',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // TIMELINE LIST
            if (todayLectures.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.wb_sunny_rounded,
                              size: 26, color: Color(0xFFD97706)),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No classes scheduled for today 🎉',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Enjoy your day off or review your study materials.',
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
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = todayLectures[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: LectureTimelineCard(
                          item: item,
                          onReport: () => _showReportSheet(context, ref, item),
                        ),
                      );
                    },
                    childCount: todayLectures.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showReportSheet(
      BuildContext context, WidgetRef ref, LectureItem lecture) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ReportUpdateModal(lecture: lecture),
    );
  }
}

// ===================================================================
// NEXT LECTURE HERO CARD WITH TICKING TIMER & 1-TAP ALERTS
// ===================================================================

class NextLectureHeroCard extends ConsumerStatefulWidget {
  final LectureItem? lecture;

  const NextLectureHeroCard({super.key, required this.lecture});

  @override
  ConsumerState<NextLectureHeroCard> createState() =>
      _NextLectureHeroCardState();
}

class _NextLectureHeroCardState extends ConsumerState<NextLectureHeroCard> {
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant NextLectureHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lecture != widget.lecture) {
      _startTimer();
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _calculateRemaining();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _calculateRemaining();
    });
  }

  void _calculateRemaining() {
    if (widget.lecture == null) return;
    final now = DateTime.now();
    final target = widget.lecture!.isOngoing
        ? widget.lecture!.endsAt
        : widget.lecture!.startsAt;

    final diff = target.difference(now);
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) {
      final days = d.inDays;
      final hours = (d.inHours % 24).toString().padLeft(2, '0');
      final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '${days}d ${hours}h ${minutes}m ${seconds}s';
    }
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours : $minutes : $seconds';
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lecture;
    final alertMode = ref.watch(alertModeProvider);

    if (l == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: const [
            Icon(Icons.check_circle_outline_rounded,
                color: AppColors.success, size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'All lectures finished for today! Time to review your notes.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isLive = l.isOngoing;
    final now = DateTime.now();
    final isToday = l.startsAt.year == now.year &&
        l.startsAt.month == now.month &&
        l.startsAt.day == now.day;
    final dayName = DateFormat('EEEE').format(l.startsAt);

    String statusTitle;
    if (isLive) {
      statusTitle = 'LIVE NOW';
    } else if (l.isTimeChanged) {
      statusTitle = isToday ? 'TIME UPDATED • TODAY' : 'TIME UPDATED • ${dayName.toUpperCase()}';
    } else if (l.isDayRescheduled) {
      statusTitle = isToday ? 'RESCHEDULED • TODAY' : 'RESCHEDULED • ${dayName.toUpperCase()}';
    } else if (isToday) {
      statusTitle = 'UPCOMING LECTURE';
    } else {
      statusTitle = 'NEXT: ${dayName.toUpperCase()}';
    }

    String timerSubtitle;
    if (isLive) {
      timerSubtitle = 'CLASS ENDS IN';
    } else if (isToday) {
      timerSubtitle = 'STARTS TODAY AT ${l.formattedStartTime} IN';
    } else {
      timerSubtitle = 'STARTS ${dayName.toUpperCase()} AT ${l.formattedStartTime} IN';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.hero,
      ),
      child: Stack(
        children: [
          // Subtle diagonal line accent
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.school_rounded,
              size: 150,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Status pill + Alert Mode button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLive
                            ? const Color(0xFFEF4444) // Bright red for live
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 1-Tap Alert Mode Pill (Ring -> Vibrate -> Silent)
                    InkWell(
                      onTap: () async {
                        await ref.read(alertModeProvider.notifier).cycleNext();
                        final newMode = ref.read(alertModeProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                newMode == AlertMode.ring
                                    ? '🔔 Alarm Clock: Mobile will ring aloud before class!'
                                    : (newMode == AlertMode.vibrate
                                        ? '📳 Vibrate Mode: Mobile will vibrate before class.'
                                        : '🔕 Silent Mode: Lecture alarms silenced.'),
                              ),
                              duration: const Duration(seconds: 4),
                              behavior: SnackBarBehavior.floating,
                              action: newMode != AlertMode.silent
                                  ? SnackBarAction(
                                      label: 'Test Alarm',
                                      textColor: Colors.amberAccent,
                                        onPressed: () {
                                          AlertScheduler.instance.testAlarmNow(
                                            mode: newMode,
                                            subjectName: l.subject.name,
                                            subjectCode: l.subject.code,
                                            professor: l.subject.professor,
                                            room: l.effectiveRoom,
                                            timeRangeFormatted:
                                                l.formattedTimeRange,
                                          );
                                        },
                                      )
                                    : null,
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(alertMode.emoji,
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 5),
                              Text(
                                alertMode.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Center Ticking Timer
                  Text(
                    timerSubtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(_remaining),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Bottom details
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.location_on_rounded,
                              size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.subject.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${l.effectiveRoom} · ${l.subject.professor}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: l.isTimeChanged
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: l.isTimeChanged
                                ? Border.all(
                                    color: Colors.amberAccent.withValues(alpha: 0.6))
                                : null,
                          ),
                          child: Text(
                            l.formattedTimeRange,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (l.hasMeetingUrl) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () =>
                            Formatters.launchMeetingUrl(context, l.meetingUrl),
                        icon: const Icon(Icons.video_call_rounded, size: 20),
                        label: const Text(
                          'Join Class Meeting',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

// ===================================================================
// TIMELINE CARD FOR EACH LECTURE TODAY
// ===================================================================

class LectureTimelineCard extends StatelessWidget {
  final LectureItem item;
  final VoidCallback onReport;

  const LectureTimelineCard({
    super.key,
    required this.item,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final l = item;
    final isCancelled = l.isCancelled;
    final isRoomChanged = l.isRoomChanged;
    final isTimeChanged = l.isTimeChanged;
    final isDayRescheduled = l.isDayRescheduled;
    final isDayMovedAway = l.isDayMovedAway;
    final isModified = isRoomChanged || isTimeChanged || isDayRescheduled;

    final statusColor = isCancelled
        ? AppColors.danger
        : isModified
            ? AppColors.warning
            : AppColors.success;

    final statusLabel = isCancelled
        ? 'Cancelled'
        : isDayMovedAway
            ? 'Moved to Another Day'
            : (isTimeChanged && isRoomChanged)
                ? 'Time & Room Updated'
                : isTimeChanged
                    ? 'Time Updated'
                    : isRoomChanged
                        ? 'Room Changed'
                        : isDayRescheduled
                            ? 'Rescheduled'
                            : 'Scheduled';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCancelled
              ? AppColors.danger.withValues(alpha: 0.4)
              : isModified
                  ? AppColors.warning.withValues(alpha: 0.45)
                  : AppColors.border,
          width: (isCancelled || isModified) ? 1.4 : 1.0,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Course code + Time badge + Status
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: l.subject.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    l.subject.code,
                    style: TextStyle(
                      color: l.subject.color,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isTimeChanged) ...[
                        Text(
                          l.slot.formattedStartTime,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          l.formattedTimeRange,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isTimeChanged
                                ? const Color(0xFFB45309)
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: isTimeChanged
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Status pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Subject Title
            Text(
              l.subject.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isCancelled
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                decoration: isCancelled ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 4),

            // Professor & Room
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  l.subject.professor,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.room_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  l.effectiveRoom,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isRoomChanged
                        ? FontWeight.w700
                        : FontWeight.normal,
                    color: isRoomChanged
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            if (l.topicCovered != null && l.topicCovered!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Topic: ${l.topicCovered!}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            if (l.hasMeetingUrl) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      Formatters.launchMeetingUrl(context, l.meetingUrl),
                  icon: const Icon(Icons.video_call_rounded, size: 18),
                  label: const Text(
                    'Join Class Meeting',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primarySoft,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),

            // Bottom action: Report Update button (+30 credits)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Know of a room or schedule change?',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onReport,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_calendar_rounded,
                            size: 13, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Report (+30 ⚡)',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// REPORT OVERRIDE BOTTOM SHEET
// ===================================================================

class ReportUpdateModal extends ConsumerStatefulWidget {
  final LectureItem lecture;

  const ReportUpdateModal({super.key, required this.lecture});

  @override
  ConsumerState<ReportUpdateModal> createState() => _ReportUpdateModalState();
}

class _ReportUpdateModalState extends ConsumerState<ReportUpdateModal> {
  OverrideStatus _selectedStatus = OverrideStatus.rescheduled;
  final TextEditingController _roomCtrl = TextEditingController();
  final TextEditingController _topicCtrl = TextEditingController();
  String? _startTime;
  String? _endTime;
  DateTime? _rescheduledDate;

  @override
  void initState() {
    super.initState();
    _startTime = widget.lecture.slot.startTime;
    _endTime = widget.lecture.slot.endTime;
  }

  @override
  void dispose() {
    _roomCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lecture;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Report Lecture Update',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '+30 ⚡ Reward',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${l.subject.name} (${l.slot.formattedTimeRange})',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            // Status choice chips
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Reschedule / Shift'),
                    selected: _selectedStatus == OverrideStatus.rescheduled,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedStatus = OverrideStatus.rescheduled);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Cancelled'),
                    selected: _selectedStatus == OverrideStatus.cancelled,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedStatus = OverrideStatus.cancelled);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_selectedStatus == OverrideStatus.rescheduled) ...[
              TextField(
                controller: _roomCtrl,
                decoration: const InputDecoration(
                  labelText: 'New Room / Location',
                  hintText: 'e.g., Seminar Hall B or Lab 4',
                  prefixIcon: Icon(Icons.room_rounded),
                ),
              ),
              const SizedBox(height: 12),

              // Meeting Time Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_rounded, size: 16),
                      label: Text('Start: ${Formatters.formatTimeString(_startTime ?? l.slot.startTime)}'),
                      onPressed: () async {
                        final initialParts = (_startTime ?? l.slot.startTime).split(':').map(int.parse).toList();
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: initialParts[0], minute: initialParts[1]),
                        );
                        if (picked != null) {
                          final h = picked.hour.toString().padLeft(2, '0');
                          final m = picked.minute.toString().padLeft(2, '0');
                          setState(() => _startTime = '$h:$m');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_rounded, size: 16),
                      label: Text('End: ${Formatters.formatTimeString(_endTime ?? l.slot.endTime)}'),
                      onPressed: () async {
                        final initialParts = (_endTime ?? l.slot.endTime).split(':').map(int.parse).toList();
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: initialParts[0], minute: initialParts[1]),
                        );
                        if (picked != null) {
                          final h = picked.hour.toString().padLeft(2, '0');
                          final m = picked.minute.toString().padLeft(2, '0');
                          setState(() => _endTime = '$h:$m');
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Meeting Day / Date
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(_rescheduledDate != null
                    ? 'Shifted Date: ${_rescheduledDate!.year}-${_rescheduledDate!.month}-${_rescheduledDate!.day}'
                    : 'Shift Date (Optional)'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _rescheduledDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 7)),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) {
                    setState(() => _rescheduledDate = picked);
                  }
                },
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _topicCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason / Topic Note (Optional)',
                hintText: 'e.g., Shifted for mid-term review session',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 20),

            FilledButton(
              onPressed: () {
                final user = ref.read(currentUserProvider);
                ref.read(dailyOverridesProvider.notifier).submitReport(
                      slotId: l.slot.id,
                      status: _selectedStatus,
                      actualRoom: _roomCtrl.text.trim().isEmpty
                          ? null
                          : _roomCtrl.text.trim(),
                      actualStartTime: _selectedStatus == OverrideStatus.rescheduled
                          ? _startTime
                          : null,
                      actualEndTime: _selectedStatus == OverrideStatus.rescheduled
                          ? _endTime
                          : null,
                      rescheduledDate: _selectedStatus == OverrideStatus.rescheduled
                          ? _rescheduledDate
                          : null,
                      topicCovered: _topicCtrl.text.trim().isEmpty
                          ? null
                          : _topicCtrl.text.trim(),
                      reportedBy: user.id,
                    );

                // Reward student +30 credits
                ref.read(currentUserProvider.notifier).addCredits(30);

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Report submitted to Mod Queue! +30 ⚡ added to your credits.'),
                  ),
                );
              },
              child: const Text('Submit Report (+30 ⚡)'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// LIVE MEETING / LECTURE ALARM PANEL (SHOWN ON HOME SCREEN)
// ===================================================================

class _ActiveMeetingAlarmPanel extends StatelessWidget {
  final ActiveLectureAlarm alarm;

  const _ActiveMeetingAlarmPanel({required this.alarm});

  @override
  Widget build(BuildContext context) {
    final isRinging = alarm.isRinging;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amberAccent.withValues(alpha: 0.7),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRinging
                          ? Icons.notifications_active_rounded
                          : Icons.event_available_rounded,
                      color: Colors.amberAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isRinging
                          ? 'LIVE MEETING ALARM • RINGING'
                          : (alarm.isUpdated
                              ? 'MEETING TIME UPDATED'
                              : 'MEETING STARTING NOW'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  alarm.subjectCode,
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alarm.subjectName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time_filled_rounded,
                  size: 15, color: Colors.amberAccent),
              const SizedBox(width: 6),
              Text(
                alarm.timeRangeFormatted,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.location_on_rounded,
                  size: 15, color: Colors.white70),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${alarm.room} • ${alarm.professor}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (alarm.topicCovered != null &&
              alarm.topicCovered!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Note: ${alarm.topicCovered}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (alarm.meetingUrl != null &&
              alarm.meetingUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Formatters.launchMeetingUrl(
                    context, alarm.meetingUrl),
                icon: const Icon(Icons.video_call_rounded, size: 19),
                label: const Text(
                  'Join Class Meeting Now',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  foregroundColor: const Color(0xFF7F1D1D),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (isRinging) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      AlertScheduler.instance
                          .stopActiveAlarm(dismissPanel: false);
                    },
                    icon: const Icon(Icons.volume_off_rounded, size: 18),
                    label: const Text(
                      'Stop Ringing',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    AlertScheduler.instance.stopActiveAlarm(dismissPanel: true);
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      size: 17, color: Colors.white),
                  label: Text(
                    isRinging ? 'Dismiss' : 'Close Panel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.6), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// URGENT ASSIGNMENTS BANNER
// ===================================================================

class UrgentAssignmentsBanner extends ConsumerWidget {
  final List<AssignmentModel> assignments;
  final Map<String, SubjectModel> subjectMap;

  const UrgentAssignmentsBanner({
    super.key,
    required this.assignments,
    required this.subjectMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (assignments.isEmpty) return const SizedBox.shrink();
    final subjects = subjectMap.values.toList();
    final hasOverdueOrToday =
        assignments.any((a) => a.isOverdue || a.isDueToday);
    final headerText = hasOverdueOrToday ? 'URGENT DEADLINES' : 'DUE TOMORROW';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Warm amber background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.alarm_on_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            headerText,
                            style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB45309),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${assignments.length} Action Required',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap Scan PDF to prepare submission or check off when done',
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AssignmentTrackerScreen()),
                  ),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: Color(0xFFB45309)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFFDE68A)),

          // List of urgent assignments
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: assignments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final a = assignments[index];
              final subject =
                  resolveSubjectById(subjects, a.subjectId) ??
                  subjectMap[a.subjectId];
              final badgeLabel = a.isOverdue
                  ? 'OVERDUE'
                  : (a.isDueToday ? 'DUE TODAY' : 'TOMORROW');

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox to mark true/false client-side
                    InkWell(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(assignmentCompletionProvider.notifier)
                            .toggleCompleted(a.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Marked "${a.title}" as completed! 🎉 (Client-side)'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFD97706), width: 1.8),
                        ),
                        child: const Icon(Icons.check,
                            size: 16, color: Colors.transparent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AssignmentTrackerScreen()),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    subject?.code ?? 'CLASS',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    subject?.name ?? 'Course Assignment',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              a.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (a.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                a.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 12, color: Color(0xFFB45309)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    a.formattedDeadline,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AssignmentScannerScreen(
                                        initialAssignment: a,
                                      ),
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.document_scanner_rounded,
                                            size: 11, color: AppColors.primary),
                                        SizedBox(width: 4),
                                        Text(
                                          'Scan PDF',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
