import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/class_providers.dart';
import '../assignments/assignment_tracker_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../timetable/timetable_screen.dart';
import '../vault/vault_screen.dart';

import '../../core/services/alert_scheduler.dart';
import '../../core/services/update_service.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    TimetableScreen(),
    AssignmentTrackerScreen(),
    VaultScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
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

      // 2. Initial timetable exact alarm synchronization
      try {
        final slots = ref.read(timetableSlotsProvider);
        final subjects = ref.read(subjectsProvider);
        final mode = ref.read(alertModeProvider);
        final leadTime = ref.read(alertLeadTimeProvider);
        final subjectMap = {for (var s in subjects) s.id: s};
        await AlertScheduler.instance.syncAllTimetableAlerts(
          slots: slots,
          subjectMap: subjectMap,
          mode: mode,
          leadTimeMinutes: leadTime,
        );
      } catch (e) {
        debugPrint('Initial alarm sync: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Re-sync alarms whenever timetable slots or alert mode updates
    ref.listen(timetableSlotsProvider, (previous, next) {
      final subjects = ref.read(subjectsProvider);
      final mode = ref.read(alertModeProvider);
      final leadTime = ref.read(alertLeadTimeProvider);
      final subjectMap = {for (var s in subjects) s.id: s};
      AlertScheduler.instance.syncAllTimetableAlerts(
        slots: next,
        subjectMap: subjectMap,
        mode: mode,
        leadTimeMinutes: leadTime,
      );
    });

    ref.listen(alertModeProvider, (previous, next) {
      final slots = ref.read(timetableSlotsProvider);
      final subjects = ref.read(subjectsProvider);
      final leadTime = ref.read(alertLeadTimeProvider);
      final subjectMap = {for (var s in subjects) s.id: s};
      AlertScheduler.instance.syncAllTimetableAlerts(
        slots: slots,
        subjectMap: subjectMap,
        mode: next,
        leadTimeMinutes: leadTime,
      );
    });
    final pendingCount = ref.watch(pendingModQueueCountProvider);
    final user = ref.watch(currentUserProvider);
    final completedIds = ref.watch(assignmentCompletionProvider);
    final urgentAssignmentsCount = ref.watch(assignmentsProvider).where((a) {
      final isDone = completedIds.contains(a.id);
      return !isDone && (a.isDueTomorrow || a.isDueToday);
    }).length;
    final updateState = ref.watch(updateStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border, width: 1.2),
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
                badgeCount: urgentAssignmentsCount > 0 ? urgentAssignmentsCount : null,
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.folder_copy_outlined,
                activeIcon: Icons.folder_copy_rounded,
                label: 'Vault',
              ),
              _buildNavItem(
                index: 4,
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
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : Colors.transparent,
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
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
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
                style: const TextStyle(
                  color: AppColors.primary,
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
