import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/kzynovex_branding.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/uuid_util.dart';
import '../../core/widgets/admin_passcode_dialog.dart';
import '../../models/models.dart';
import '../../providers/class_providers.dart';
import '../admin/admin_management_screen.dart';
import '../auth/login_screen.dart';
import '../bounties/note_bounties_screen.dart';
import '../cosmetics/cosmetics_store_screen.dart';
import '../../core/services/alert_scheduler.dart';
import '../../core/services/update_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final leadTime = ref.watch(alertLeadTimeProvider);
    final leaderboard = ref.watch(leaderboardProvider);
    final pendingResources =
        ref.watch(resourcesProvider).where((r) => !r.isApproved).toList();
    final pendingOverrides =
        ref.watch(dailyOverridesProvider).where((o) => !o.isApproved).toList();
    final subjects = ref.watch(subjectsProvider);
    final slots = ref.watch(timetableSlotsProvider);
    final users = ref.watch(usersListProvider);
    final updateState = ref.watch(updateStateProvider);
    final alertMode = ref.watch(alertModeProvider);
    final cosmetics = ref.watch(cosmeticsProvider);
    final verificationReqs = ref.watch(studentVerificationRequestsProvider);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        actions: [
          // Role Switcher / Admin Console entry (ONLY visible to Admin accounts)
          if (user.isAdmin || AuthService.isAdminEmail(user.email))
            TextButton.icon(
              onPressed: () async {
                await showAdminPasscodeDialog(context, ref, autoOpenConsole: true);
              },
              icon: const Icon(
                Icons.admin_panel_settings_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              label: const Text(
                'Admin Console',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.warning,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            // USER PROFILE CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.cardSurface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: palette.border),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: palette.heroGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Name & Role
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (user.isKzynovexVerified) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.verified_rounded,
                                      size: 16, color: AppColors.primary),
                                ],
                                const Spacer(),
                                InkWell(
                                  onTap: () => _openEditProfileDialog(
                                      context, ref, user),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceMuted,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_rounded,
                                            size: 12,
                                            color: AppColors.textSecondary),
                                        SizedBox(width: 3),
                                        Text(
                                          'Edit',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (user.rollNo != null && user.rollNo!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Roll No: ${user.rollNo}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: user.isAdmin
                                        ? AppColors.warningBg
                                        : AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    user.isAdmin
                                        ? (AuthService.isAdminEmail(user.email)
                                            ? 'DESIGNATED ADMIN'
                                            : 'ADMIN & MODERATOR')
                                        : 'STUDENT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: user.isAdmin
                                          ? AppColors.warning
                                          : AppColors.primary,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.menu_book_rounded,
                                        size: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Read-Only Student',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textSecondary,
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
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 14),

                  // Stats row: Credits + Streak
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          label: (!user.isKzynovexVerified && !user.isAdmin)
                              ? 'Credits (Verify to Use)'
                              : 'Academic Credits',
                          value: '${user.credits} pts',
                          color: (!user.isKzynovexVerified && !user.isAdmin)
                              ? AppColors.warning
                              : AppColors.primary,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: AppColors.border,
                      ),
                      Expanded(
                        child: _buildStatItem(
                          label: 'Attendance Streak',
                          value: '${user.streakCount} Days 🔥',
                          color: const Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // VERIFIED STUDENT BADGE REQUEST (Shown ONLY if NOT yet verified)
            if (!user.isKzynovexVerified && !user.isAdmin) ...[
              _buildStudentVerificationCard(
                context,
                ref,
                user,
                verificationReqs,
              ),
              const SizedBox(height: 14),
            ],

            // THEMES & COSMETICS STORE + NOTE BOUNTIES SHORTCUTS
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CosmeticsStoreScreen(),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: palette.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.palette_rounded,
                                size: 18, color: palette.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Themes & Sounds',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                Text(
                                  cosmetics.activeTheme.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NoteBountiesScreen(),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.volunteer_activism_rounded,
                              size: 18,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Note Bounties',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Escrow help',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // CLOUD & OFFLINE SYNC CARD
            _buildCloudSyncCard(context, ref),
            const SizedBox(height: 18),

            // ALERT LEAD TIME SETTING
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: palette.cardSurface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: palette.border),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.alarm_rounded,
                          size: 18, color: palette.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Class Alert Lead-Time',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Receive scheduled notifications before your lecture begins.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [5, 10, 15].map((mins) {
                      final isSelected = leadTime == mins;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () {
                              ref
                                  .read(alertLeadTimeProvider.notifier)
                                  .setMinutes(mins);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Alarm scheduled for $mins mins before lecture'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$mins mins before',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ADMIN MANAGEMENT HUB ENTRY CARD
            if (user.isAdmin) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2D1B69), Color(0xFF1E1B2E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  boxShadow: AppShadows.hero,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.shield_rounded,
                                  size: 13, color: Colors.amber),
                              SizedBox(width: 4),
                              Text(
                                'ADMINISTRATION SUITE',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminManagementScreen(),
                              ),
                            );
                          },
                          child: const Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Admin Management Console',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure weekly timetables, add/edit courses, broadcast lecture cancellations or room shifts, and manage moderation.',
                      style: TextStyle(
                        color: AppColors.borderStrong,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Quick Action Pills
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AdminManagementScreen(initialTabIndex: 0),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_month_rounded,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  'Slots (${slots.length})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AdminManagementScreen(initialTabIndex: 1),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.school_rounded,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  'Courses (${subjects.length})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AdminManagementScreen(initialTabIndex: 2),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.broadcast_on_personal_rounded,
                                    size: 14, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Live Overrides',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AdminManagementScreen(initialTabIndex: 4),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people_alt_rounded,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  'Users (${users.length})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showAdminPasscodeDialog(
                            context,
                            ref,
                            autoOpenConsole: true,
                          );
                        },
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text('Open Full Admin Console'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ZERO-FRICTION ADMIN MOD QUEUE
            if (user.isAdmin) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Admin Moderation Queue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${pendingResources.length + pendingOverrides.length} PENDING',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (pendingResources.isEmpty && pendingOverrides.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text(
                      'Mod Queue is clean! All student submissions reviewed.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else ...[
                // Pending Resources
                for (final res in pendingResources) ...[
                  _ModQueueResourceCard(
                    resource: res,
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
                      ref
                          .read(resourcesProvider.notifier)
                          .rejectResource(res.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Resource rejected.')),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Pending Overrides
                for (final ov in pendingOverrides) ...[
                  _ModQueueOverrideCard(
                    dailyOverride: ov,
                    subjects: subjects,
                    slots: slots,
                    users: users,
                    onApprove: () {
                      ref
                          .read(dailyOverridesProvider.notifier)
                          .approveOverride(ov.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Lecture update approved & broadcast!')),
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
              const SizedBox(height: 24),
            ],

            // CLASS LEADERBOARD
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Academic Leaderboard',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Top Contributors',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (leaderboard.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        size: 36, color: AppColors.borderStrong),
                    SizedBox(height: 8),
                    Text(
                      'No Contributors Ranked Yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sign in with Google and share study notes to top the leaderboard!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: leaderboard.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                  final rank = index + 1;
                  final entry = leaderboard[index];
                  final isTop3 = rank <= 3;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Rank badge
                        SizedBox(
                          width: 28,
                          child: Text(
                            '#$rank',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isTop3
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        // Avatar initial
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isTop3
                              ? AppColors.primarySoft
                              : AppColors.surfaceMuted,
                          child: Text(
                            entry.name[0],
                            style: TextStyle(
                              color: isTop3
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Name + Flairs
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      entry.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (entry.isKzynovexVerified) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.verified_rounded,
                                        size: 14, color: AppColors.primary),
                                  ],
                                ],
                              ),
                              if (isTop3) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Top Contributor',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Credits
                        Text(
                          '${entry.credits} pts',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // KZYNOVEX OFFICIAL PROMO CARD
            const KzynovexPromoCard(),
            const SizedBox(height: 24),

            // Backend Status Indicator
            Center(
              child: Text(
                AppConfig.isSupabaseConfigured
                    ? 'Connected to Live Supabase'
                    : 'Running in Local Offline Demo Mode',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // LECTURE ALARM CLOCK & REMINDER SETTINGS
            _buildAlarmSettingsCard(context, ref, alertMode, leadTime, slots.length),
            const SizedBox(height: 20),

            // APP VERSION & UPDATE MANAGER
            _buildUpdateManagerCard(context, ref, updateState),
            const SizedBox(height: 20),

            // FUTURE UPDATES & ROADMAP SECTION
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.blueBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.rocket_launch_rounded,
                          size: 18,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Future Updates & Roadmap',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Features currently in development & fine-tuning',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Feature 1: Student Uploads
                  _buildFutureFeatureItem(
                    icon: Icons.cloud_upload_outlined,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: AppColors.blueBg,
                    title: 'Community Note Uploads',
                    badge: 'Coming Soon',
                    badgeColor: const Color(0xFF2563EB),
                    badgeBg: AppColors.blueBorder,
                    description:
                        'Student contribution system for uploading lecture slides, notes, and past papers with +50 ⚡ reward credits. Currently disabled so students have a clean, verified reading experience.',
                  ),
                  const SizedBox(height: 12),

                  // Feature 2: Bunk Radar (Now Live)
                  _buildFutureFeatureItem(
                    icon: Icons.radar_rounded,
                    iconColor: const Color(0xFF059669),
                    iconBg: AppColors.successBgStrong,
                    title: 'Bunk Radar & Attendance Predictor',
                    badge: 'Live Now',
                    badgeColor: AppColors.successText,
                    badgeBg: AppColors.successBorder,
                    description:
                        'Real-time calculator showing exactly how many lectures you can safely miss or must attend to stay above 75%, with quick Present/Absent buttons on alarms & lectures.',
                  ),
                  const SizedBox(height: 12),

                  // Feature 3: Online Assignment Submissions
                  _buildFutureFeatureItem(
                    icon: Icons.task_alt_rounded,
                    iconColor: const Color(0xFF059669),
                    iconBg: AppColors.successBgStrong,
                    title: 'Assignment Submissions & Feedback',
                    badge: 'Planned',
                    badgeColor: AppColors.successText,
                    badgeBg: AppColors.successBorder,
                    description:
                        'Direct submission portal for homework solutions, professor rubric scoring, and feedback notifications.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // LOG OUT BUTTON
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Log Out?'),
                      content: const Text(
                        'Are you sure you want to log out of your academic companion account?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                          child: const Text('Log Out'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    await ref.read(currentUserProvider.notifier).logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.danger),
                label: const Text(
                  'Log Out of Account',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFutureFeatureItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String badge,
    required Color badgeColor,
    required Color badgeBg,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateManagerCard(
    BuildContext context,
    WidgetRef ref,
    UpdateCheckResult updateState,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: updateState.isUpdateAvailable
              ? const Color(0xFFF59E0B)
              : AppColors.border,
          width: updateState.isUpdateAvailable ? 1.5 : 1.0,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: updateState.isUpdateAvailable
                      ? AppColors.warningBg
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  updateState.isUpdateAvailable
                      ? Icons.system_update_rounded
                      : Icons.info_outline_rounded,
                  size: 20,
                  color: updateState.isUpdateAvailable
                      ? AppColors.warning
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'App Version & Updates',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (updateState.isUpdateAvailable) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'UPDATE AVAILABLE',
                              style: TextStyle(
                                color: AppColors.warningText,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Titan Portal OTA Distribution • ${AppConfig.appPackageName}',
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
            ],
          ),
          const SizedBox(height: 16),

          // Version info pills row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildVersionPillItem('Version', 'v${AppConfig.appVersion}'),
                Container(width: 1, height: 28, color: AppColors.border),
                _buildVersionPillItem('Build', '#${AppConfig.appVersionCode}'),
                Container(width: 1, height: 28, color: AppColors.border),
                _buildVersionPillItem('Channel', AppConfig.appBuildChannel),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Update available alert banner (if newer version detected)
          if (updateState.isUpdateAvailable) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.urgentBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.new_releases_rounded,
                          size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        'v${updateState.updateInfo!.versionName} (Build ${updateState.updateInfo!.versionCode}) Available',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warningTextDeep,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    updateState.updateInfo!.releaseNotes.trim().isNotEmpty
                        ? updateState.updateInfo!.releaseNotes.trim()
                        : 'New release with improvements and updates.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.warningText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: FilledButton.icon(
                      onPressed: () {
                        UpdateService.instance.showUpdateDialog(
                          context,
                          updateState.updateInfo!,
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('View Update & Install'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Check for Updates CTA Button
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: FilledButton.icon(
                    onPressed: updateState.status == UpdateCheckStatus.checking
                        ? null
                        : () async {
                            final res = await ref
                                .read(updateStateProvider.notifier)
                                .check(
                                  showModalIfAvailable: true,
                                  context: context,
                                  manual: true,
                                );
                            if (context.mounted && !res.isUpdateAvailable) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                    icon: updateState.status == UpdateCheckStatus.checking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      updateState.status == UpdateCheckStatus.checking
                          ? 'Checking Titan Portal...'
                          : 'Check for Updates',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Server Host Settings Button
              IconButton(
                tooltip: 'Update Server Settings',
                icon: Icon(Icons.dns_rounded, size: 20, color: AppColors.textSecondary),
                onPressed: () => _showUpdateHostDialog(context),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // API Host info line
          FutureBuilder<String>(
            future: UpdateService.instance.getBaseUrl(),
            builder: (context, snapshot) {
              final host = snapshot.data ?? AppConfig.defaultUpdateBaseUrl;
              return Row(
                children: [
                  Icon(Icons.link_rounded, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'API Host: $host',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVersionPillItem(String label, String value) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showUpdateHostDialog(BuildContext context) async {
    final currentHost = await UpdateService.instance.getBaseUrl();
    final ctrl = TextEditingController(text: currentHost);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Server Host', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specify the base URL of your Titan Portal Update Manager API instance.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'e.g. http://titan.portal.kzynovex.online',
                filled: true,
                fillColor: AppColors.surfaceSubtle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await UpdateService.instance.setCustomBaseUrl(null);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Reset Default'),
          ),
          FilledButton(
            onPressed: () async {
              await UpdateService.instance.setCustomBaseUrl(ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Host'),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudSyncCard(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);

    final lastSyncText = syncState.lastSyncedAt != null
        ? DateFormat('h:mm a, d MMM').format(syncState.lastSyncedAt!)
        : 'Never synced';

    final hasPending = syncState.pendingCount > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: hasPending ? AppColors.warningBorder : AppColors.border,
          width: hasPending ? 1.5 : 1.0,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasPending
                      ? AppColors.warningBg
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasPending
                      ? Icons.cloud_upload_rounded
                      : Icons.cloud_done_rounded,
                  color: hasPending ? AppColors.warning : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cloud Sync & Offline Queue',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      hasPending
                          ? '${syncState.pendingCount} local changes waiting to sync'
                          : 'All local changes in sync with database',
                      style: TextStyle(
                        fontSize: 11,
                        color: hasPending
                            ? const Color(0xFFD97706)
                            : AppColors.textSecondary,
                        fontWeight:
                            hasPending ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasPending
                      ? AppColors.warningBg
                      : AppColors.successBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: hasPending
                        ? AppColors.warningBorder
                        : AppColors.successBorder,
                  ),
                ),
                child: Text(
                  hasPending ? '${syncState.pendingCount} Unsynced' : 'In Sync',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: hasPending
                        ? AppColors.warningText
                        : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LAST SYNCED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lastSyncText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.border,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BACKEND STATUS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppConfig.isSupabaseConfigured
                            ? 'Supabase Live'
                            : 'Offline Mode',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppConfig.isSupabaseConfigured
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: syncState.isSyncing
                  ? null
                  : () async {
                      final result = await ref
                          .read(syncStateProvider.notifier)
                          .triggerSync();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(
                                  result.success
                                      ? Icons.check_circle_rounded
                                      : Icons.error_outline_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(result.message)),
                              ],
                            ),
                            backgroundColor: result.success
                                ? AppColors.textPrimary
                                : AppColors.danger,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              icon: syncState.isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(
                syncState.isSyncing
                    ? 'Syncing with Supabase...'
                    : (hasPending
                        ? 'Push ${syncState.pendingCount} Changes to Cloud'
                        : 'Manual Sync Now'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    hasPending ? AppColors.warning : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ===================================================================
// MOD QUEUE ITEM CARDS
// ===================================================================

class _ModQueueResourceCard extends StatelessWidget {
  final ResourceModel resource;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ModQueueResourceCard({
    required this.resource,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_add_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Note Submission',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                'By ${resource.uploaderName}',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            resource.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Reject',
                      style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Approve (+50 ⚡)',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModQueueOverrideCard extends StatelessWidget {
  final DailyOverrideModel dailyOverride;
  final List<SubjectModel> subjects;
  final List<TimetableSlotModel> slots;
  final List<UserModel> users;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ModQueueOverrideCard({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_calendar_rounded,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subject != null
                      ? '${subject.code} - ${subject.name} (${dailyOverride.status.label})'
                      : 'Schedule Report (${dailyOverride.status.label})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person_outline_rounded,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Requested by: $reporterLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (dailyOverride.rescheduledDate != null)
            Text(
              'Rescheduled Date: ${dailyOverride.rescheduledDate!.year}-${dailyOverride.rescheduledDate!.month.toString().padLeft(2, '0')}-${dailyOverride.rescheduledDate!.day.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          if (dailyOverride.actualStartTime != null)
            Text(
              'New Time: ${Formatters.formatTimeString(dailyOverride.actualStartTime)}${dailyOverride.actualEndTime != null ? ' - ${Formatters.formatTimeString(dailyOverride.actualEndTime)}' : ''}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          if (dailyOverride.actualRoom != null)
            Text(
              'New Room Reported: ${dailyOverride.actualRoom}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          if (dailyOverride.topicCovered != null)
            Text(
              'Note: ${dailyOverride.topicCovered}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Reject',
                      style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Approve & Broadcast',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _openEditProfileDialog(
    BuildContext context, WidgetRef ref, UserModel user) {
  final nameController = TextEditingController(text: user.name);
  final emailController = TextEditingController(text: user.email);
  final rollController = TextEditingController(text: user.rollNo ?? '');

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.edit_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Full Name',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
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
            const SizedBox(height: 16),
            Text(
              'Roll Number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: rollController,
              decoration: InputDecoration(
                hintText: 'e.g. 23-SE-402',
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
            const SizedBox(height: 16),
            Text(
              'Email Address',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
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
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          onPressed: () {
            final trimmedName = nameController.text.trim();
            final trimmedEmail = emailController.text.trim();
            final trimmedRoll = rollController.text.trim();
            if (trimmedName.isNotEmpty && trimmedEmail.isNotEmpty) {
              ref.read(currentUserProvider.notifier).updateProfile(
                    name: trimmedName,
                    email: trimmedEmail,
                    rollNo: trimmedRoll,
                  );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Save Changes'),
        ),
      ],
    ),
  );
}

Widget _buildAlarmSettingsCard(
  BuildContext context,
  WidgetRef ref,
  AlertMode alertMode,
  int leadTime,
  int slotCount,
) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      border: Border.all(
        color: alertMode == AlertMode.ring
            ? const Color(0xFF6366F1).withValues(alpha: 0.3)
            : AppColors.border,
        width: 1.2,
      ),
      boxShadow: AppShadows.card,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: alertMode == AlertMode.ring
                    ? AppColors.infoBg
                    : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                alertMode == AlertMode.ring
                    ? Icons.alarm_on_rounded
                    : (alertMode == AlertMode.vibrate
                        ? Icons.vibration_rounded
                        : Icons.notifications_off_rounded),
                color: alertMode == AlertMode.ring
                    ? const Color(0xFF4F46E5)
                    : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lecture Alarm Clock',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alertMode == AlertMode.ring
                        ? 'Rings aloud & vibrates before classes'
                        : (alertMode == AlertMode.vibrate
                            ? 'Vibrates before classes (Silent)'
                            : 'Alarms silenced'),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: alertMode != AlertMode.silent
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : AppColors.textSecondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                alertMode != AlertMode.silent ? 'Active' : 'Muted',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: alertMode != AlertMode.silent
                      ? const Color(0xFF059669)
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3-Way Mode Segmented Selector
        SegmentedButton<AlertMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: AlertMode.ring,
              label: Text('Ring 🔔', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ButtonSegment(
              value: AlertMode.vibrate,
              label: Text('Vibrate 📳', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ButtonSegment(
              value: AlertMode.silent,
              label: Text('Silent 🔕', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
          selected: {alertMode},
          onSelectionChanged: (set) async {
            await ref.read(alertModeProvider.notifier).setMode(set.first);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    set.first == AlertMode.ring
                        ? '🔔 Alarm Mode: Phone will ring aloud before class!'
                        : (set.first == AlertMode.vibrate
                            ? '📳 Vibrate Mode: Phone will vibrate before class.'
                            : '🔕 Silent Mode: Lecture alarms silenced.'),
                  ),
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),

        const SizedBox(height: 16),

        // Lead time selection
        Text(
          'Ring Alarm Before Class Starts:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [5, 10, 15, 30].map((mins) {
            final isSelected = leadTime == mins;
            return ChoiceChip(
              label: Text('$mins mins before'),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  ref.read(alertLeadTimeProvider.notifier).setMinutes(mins);
                }
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        // Test Alarm Button & Permission Check
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  AlertScheduler.instance.testAlarmNow(mode: alertMode);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔔 Testing alarm sound & vibration! Check notification bar.'),
                      duration: Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.play_circle_filled_rounded, size: 18),
                label: const Text('Test Alarm Sound'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Check Android Exact Alarm Permissions',
              icon: const Icon(Icons.verified_user_rounded, size: 18),
              onPressed: () async {
                final granted = await AlertScheduler.instance.requestPermissions();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(granted
                          ? '✅ Exact alarm clock permissions granted!'
                          : '⚠️ Please enable "Alarms & Reminders" permission in Android Settings.'),
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ),

        const SizedBox(height: 8),
        Text(
          '• Uses Android AlarmClock service. Alarms ring accurately even when the phone screen is off or app is closed.',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 14),
        Builder(
          builder: (context) {
            final cosmetics = ref.watch(cosmeticsProvider);
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.graphic_eq_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Alarm: ${cosmetics.activeAlarmSound.name} • Notif: ${cosmetics.activeNotificationSound.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CosmeticsStoreScreen(),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Change',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Soft Button Tap Sound',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        value: cosmetics.tapSoundEnabled,
                        onChanged: (v) => ref
                            .read(cosmeticsProvider.notifier)
                            .setTapSoundEnabled(v),
                      ),
                    ],
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

Widget _buildStudentVerificationCard(
  BuildContext context,
  WidgetRef ref,
  UserModel user,
  List<StudentVerificationRequestModel> requests,
) {
  final normId = UuidUtil.fromString(user.id);
  final existing = requests.cast<StudentVerificationRequestModel?>().firstWhere(
        (r) =>
            r != null &&
            ((r.userId.isNotEmpty && UuidUtil.fromString(r.userId) == normId) ||
                (user.email.isNotEmpty &&
                    r.email.toLowerCase() == user.email.toLowerCase())),
        orElse: () => null,
      );

  final isPending = existing != null && existing.isPending;
  final isRejected = existing != null && existing.isRejected;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.urgentBg,
      borderRadius: BorderRadius.circular(AppRadii.card),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_user_outlined,
                color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Get Your Verified Student Badge',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warningTextDeep,
                ),
              ),
            ),
            if (isPending)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warningBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'PENDING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warningTextDeep,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isPending
              ? 'Your request for ${existing.name} (${existing.rollNo}) is waiting for Admin verification. Credits remain locked until approved.'
              : (isRejected
                  ? 'Rejected: ${existing.rejectionReason ?? "Details mismatch."}. Update your Name & Roll No to resubmit.'
                  : 'Your ${user.credits} ⚡ welcome credits are locked until verified. Request Admin verification with your real Name & Roll No to spend credits on Cosmetics or Note Bounties.'),
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.warningTextDeep,
            height: 1.35,
          ),
        ),
        if (!isPending) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final nameCtrl = TextEditingController(text: user.name);
                final rollCtrl = TextEditingController(text: user.rollNo ?? '');
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Request Verified Student Badge'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Full University Name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: rollCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'University Roll No (e.g. 23-SE-402)',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final res = await ref
                              .read(studentVerificationRequestsProvider.notifier)
                              .submitRequest(
                                name: nameCtrl.text,
                                rollNo: rollCtrl.text,
                              );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res.message),
                              backgroundColor: res.success
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          );
                        },
                        child: const Text('Submit to Admin'),
                      ),
                    ],
                  ),
                );
                nameCtrl.dispose();
                rollCtrl.dispose();
              },
              icon: const Icon(Icons.verified_rounded, size: 17),
              label: Text(
                isRejected
                    ? 'Resubmit Name & Roll No'
                    : 'Request Verified Badge',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                minimumSize: const Size(0, 40),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

