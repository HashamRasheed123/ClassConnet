import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/class_providers.dart';
import '../assignments/assignment_tracker_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../quizzes/quiz_center_screen.dart';
import '../timetable/timetable_screen.dart';
import '../vault/vault_screen.dart';

import '../../core/services/alert_scheduler.dart';
import '../../core/services/update_service.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  static const List<Widget> _screens = [
    HomeScreen(),
    TimetableScreen(),
    AssignmentTrackerScreen(),
    QuizCenterScreen(),
    VaultScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AlertScheduler.instance.activeAlarmNotifier
        .addListener(_onActiveAlarmChanged);
    AlertScheduler.instance.attendanceSyncVersion
        .addListener(_onAttendanceSynced);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Check for app updates
      final autoCheck = await UpdateService.instance.isAutoCheckEnabled();
      if (autoCheck && mounted) {
        ref.read(updateStateProvider.notifier).check(
              showModalIfAvailable: true,
              context: context,
              manual: false,
            );
      }

      // 2. Request alarm permissions & synchronize all lecture/assignment alarms
      try {
        await AlertScheduler.instance.ensureAlarmPermissions();
        if (mounted) _syncAllAlarms();
      } catch (e) {
        debugPrint('Initial alarm sync: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AlertScheduler.instance.activeAlarmNotifier
        .removeListener(_onActiveAlarmChanged);
    AlertScheduler.instance.attendanceSyncVersion
        .removeListener(_onAttendanceSynced);
    super.dispose();
  }

  void _onAttendanceSynced() {
    if (!mounted) return;
    ref.read(attendanceProvider.notifier).reloadFromPrefs();
    ref.read(dailyAttendanceMarksProvider.notifier).reloadFromPrefs();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Pull latest cloud overrides/timetable/assignments on resume and resync alarms
      ref.read(syncStateProvider.notifier).triggerSync();
      ref.read(attendanceProvider.notifier).reloadFromPrefs();
      ref.read(dailyAttendanceMarksProvider.notifier).reloadFromPrefs();
    }
  }

  void _onActiveAlarmChanged() {
    final alarm = AlertScheduler.instance.activeAlarmNotifier.value;
    if (alarm != null && mounted) {
      if (ref.read(mainShellTabProvider) != 0) {
        ref.read(mainShellTabProvider.notifier).setTab(0);
      }
      // If a sub-route (e.g. Admin Console) is open, bring the user to Home Screen
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _syncAllAlarms() {
    try {
      final slots = ref.read(timetableSlotsProvider);
      final subjects = ref.read(subjectsProvider);
      final mode = ref.read(alertModeProvider);
      final leadTime = ref.read(alertLeadTimeProvider);
      final overrides = ref.read(dailyOverridesProvider);
      final assignments = ref.read(assignmentsProvider);
      final completed = ref.read(assignmentCompletionProvider);
      final subjectMap = {for (var s in subjects) s.id: s};
      AlertScheduler.instance.syncAllTimetableAlerts(
        slots: slots,
        subjectMap: subjectMap,
        mode: mode,
        leadTimeMinutes: leadTime,
        overrides: overrides,
        assignments: assignments,
        completedAssignmentIds: completed,
      );
    } catch (e) {
      debugPrint('Error syncing all alarms: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-sync alarms whenever timetable slots, subjects, overrides, assignments, lead time, or alert mode updates
    ref.listen(timetableSlotsProvider, (_, _) => _syncAllAlarms());
    ref.listen(subjectsProvider, (_, _) => _syncAllAlarms());
    ref.listen(alertModeProvider, (_, _) => _syncAllAlarms());
    ref.listen(alertLeadTimeProvider, (_, _) => _syncAllAlarms());
    ref.listen(dailyOverridesProvider, (_, _) => _syncAllAlarms());
    ref.listen(assignmentsProvider, (_, _) => _syncAllAlarms());
    ref.listen(assignmentCompletionProvider, (_, _) => _syncAllAlarms());
    ref.listen<CosmeticsState>(cosmeticsProvider, (prev, next) {
      if (prev?.activeAlarmSound != next.activeAlarmSound ||
          prev?.activeNotificationSound != next.activeNotificationSound) {
        _syncAllAlarms();
      }
    });
    final pendingCount = ref.watch(pendingModQueueCountProvider);
    final user = ref.watch(currentUserProvider);
    final completedIds = ref.watch(assignmentCompletionProvider);
    final urgentAssignmentsCount = ref.watch(assignmentsProvider).where((a) {
      final isDone = completedIds.contains(a.id);
      return !isDone && (a.isDueTomorrow || a.isDueToday);
    }).length;
    final updateState = ref.watch(updateStateProvider);
    final currentIndex = ref.watch(mainShellTabProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.border, width: 1.2),
            boxShadow: AppShadows.floatingBar,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                label: 'Home',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today_rounded,
                label: 'Timetable',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.assignment_outlined,
                activeIcon: Icons.assignment_rounded,
                label: 'Tasks',
                badgeCount:
                    urgentAssignmentsCount > 0 ? urgentAssignmentsCount : null,
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.psychology_alt_outlined,
                activeIcon: Icons.psychology_alt_rounded,
                label: 'Quizzes',
              ),
              _buildNavItem(
                index: 4,
                icon: Icons.folder_copy_outlined,
                activeIcon: Icons.folder_copy_rounded,
                label: 'Vault',
              ),
              _buildNavItem(
                index: 5,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                badgeCount: (user.isAdmin && pendingCount > 0)
                    ? pendingCount
                    : (updateState.isUpdateAvailable ? 1 : null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int? badgeCount,
  }) {
    final isSelected = ref.watch(mainShellTabProvider) == index;
    final palette = context.palette;

    return InkWell(
      onTap: () => ref.read(mainShellTabProvider.notifier).setTab(index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? palette.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 20,
                  color:
                      isSelected ? palette.primary : palette.textSecondary,
                ),
                if (badgeCount != null)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: palette.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
