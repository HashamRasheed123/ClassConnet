import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/alert_scheduler.dart';
import '../../core/services/app_sound_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/uuid_util.dart';
import '../../models/models.dart';
import '../../providers/class_providers.dart';

class CosmeticsStoreScreen extends ConsumerWidget {
  const CosmeticsStoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final cosmetics = ref.watch(cosmeticsProvider);
    final verificationReqs = ref.watch(studentVerificationRequestsProvider);
    final palette = context.palette;
    final isVerified = user.isKzynovexVerified || user.isAdmin;
    final normId = UuidUtil.fromString(user.id);
    final myReq = verificationReqs.cast<StudentVerificationRequestModel?>().firstWhere(
          (r) =>
              r != null &&
              ((r.userId.isNotEmpty && UuidUtil.fromString(r.userId) == normId) ||
                  (user.email.isNotEmpty &&
                      r.email.toLowerCase() == user.email.toLowerCase())),
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Themes & Cosmetics Store'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 15, color: palette.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${user.credits} ⚡',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: palette.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        children: [
          // Store Hero Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: palette.heroGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.palette_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customize Your Experience',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Spend earned ⚡ Credits on Obsidian OLED dark themes, luxury accents, and custom lecture alarm tones.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!isVerified) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_person_rounded,
                      color: AppColors.warning, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Credits Locked Until Verified',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warningTextDeep,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          myReq != null && myReq.isPending
                              ? 'Your verification request (${myReq.rollNo}) is pending admin approval.'
                              : 'You have ${user.credits} ⚡ credits! Request your Verified Student Badge so you can unlock paid themes & sounds.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.warningTextDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (myReq == null || !myReq.isPending) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () =>
                          _openVerificationDialog(context, ref, user),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        backgroundColor: const Color(0xFFD97706),
                      ),
                      child: const Text(
                        'Verify',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
          ] else
            const SizedBox(height: 8),

          // SECTION 1: APP THEMES
          Text(
            'App Themes (Free & Premium)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Free starter styles + flagship Obsidian OLED & Gold dark themes (50–100 ⚡).',
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),

          for (final preset in AppThemePreset.values) ...[
            _ThemePresetCard(
              preset: preset,
              isUnlocked: cosmetics.isThemeUnlocked(preset),
              isActive: cosmetics.activeTheme == preset,
              userCredits: user.credits,
              canSpend: isVerified,
              onTap: () =>
                  _handleThemeTap(context, ref, preset, cosmetics, isVerified, user),
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 22),

          // SECTION 2: CUSTOM LECTURE ALARM SOUNDS
          Text(
            'Custom Lecture Alarm Sounds',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Preview & equip distinct tones and vibration patterns for your lecture alarms.',
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),

          for (final sound in AlarmSoundPreset.values) ...[
            _AlarmSoundCard(
              preset: sound,
              isUnlocked: cosmetics.isSoundUnlocked(sound),
              isActive: cosmetics.activeAlarmSound == sound,
              userCredits: user.credits,
              canSpend: isVerified,
              onPreview: () async {
                await AlertScheduler.instance.previewAlarmSound(sound.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Playing 3.5s preview: ${sound.name}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              onTap: () =>
                  _handleSoundTap(context, ref, sound, cosmetics, isVerified, user),
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 22),

          // SECTION 3: NOTIFICATION & BUTTON SOUND EFFECTS
          Text(
            'Notification & Button Sound Effects',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose custom reminder notification tones and soft interactive button tap feedback.',
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),

          // Soft Button Tap Sound Toggle Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cosmetics.tapSoundEnabled
                    ? palette.primary.withValues(alpha: 0.45)
                    : palette.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.touch_app_rounded,
                    size: 20,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Soft Button Tap Sound',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Subtle pop sound whenever any button is pressed',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Preview Tap Sound',
                  onPressed: () =>
                      AppSoundService.instance.playTapSound(ignoreSetting: true),
                  icon: Icon(
                    Icons.play_circle_outline_rounded,
                    color: palette.primary,
                  ),
                ),
                Switch(
                  value: cosmetics.tapSoundEnabled,
                  onChanged: (val) => ref
                      .read(cosmeticsProvider.notifier)
                      .setTapSoundEnabled(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          for (final notifPreset in NotificationSoundPreset.values) ...[
            _NotificationSoundCard(
              preset: notifPreset,
              isActive: cosmetics.activeNotificationSound == notifPreset,
              onPreview: () async {
                await AlertScheduler.instance
                    .previewNotificationSound(notifPreset.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Playing notification: ${notifPreset.name}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              onSelect: () async {
                await ref
                    .read(cosmeticsProvider.notifier)
                    .selectNotificationSound(notifPreset);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Notification sound set to ${notifPreset.name}'),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Future<void> _openVerificationDialog(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) async {
    final nameCtrl = TextEditingController(text: user.name);
    final rollCtrl = TextEditingController(text: user.rollNo ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Verified Student Badge'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your Full Name and Roll Number. Once verified by an Admin, you can spend your credits across the entire app.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
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
                labelText: 'Roll Number (e.g. 23-SE-402)',
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
                  .submitRequest(name: nameCtrl.text, rollNo: rollCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res.message),
                  backgroundColor:
                      res.success ? AppColors.success : AppColors.danger,
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
  }

  Future<void> _handleThemeTap(
    BuildContext context,
    WidgetRef ref,
    AppThemePreset preset,
    CosmeticsState cosmetics,
    bool isVerified,
    UserModel user,
  ) async {
    final notifier = ref.read(cosmeticsProvider.notifier);
    if (!cosmetics.isThemeUnlocked(preset)) {
      if (!isVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Verified Student Badge required to spend credits! Request verification from an Admin.'),
            backgroundColor: AppColors.warning,
          ),
        );
        await _openVerificationDialog(context, ref, user);
        return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Unlock ${preset.name}?'),
          content: Text(
            'Spend ${preset.costCredits} ⚡ Credits to permanently unlock "${preset.name}" and apply it now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Unlock (${preset.costCredits} ⚡)'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final err = await notifier.unlockOrEquipTheme(preset);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? 'Theme equipped: ${preset.name}'),
        backgroundColor: err != null ? AppColors.danger : AppColors.success,
      ),
    );
  }

  Future<void> _handleSoundTap(
    BuildContext context,
    WidgetRef ref,
    AlarmSoundPreset preset,
    CosmeticsState cosmetics,
    bool isVerified,
    UserModel user,
  ) async {
    final notifier = ref.read(cosmeticsProvider.notifier);
    if (!cosmetics.isSoundUnlocked(preset)) {
      if (!isVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Verified Student Badge required to spend credits! Request verification from an Admin.'),
            backgroundColor: AppColors.warning,
          ),
        );
        await _openVerificationDialog(context, ref, user);
        return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Unlock ${preset.name}?'),
          content: Text(
            'Spend ${preset.costCredits} ⚡ Credits to unlock "${preset.name}" for your lecture alarms?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Unlock (${preset.costCredits} ⚡)'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final err = await notifier.unlockOrEquipSound(preset);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? 'Alarm sound equipped: ${preset.name}'),
        backgroundColor: err != null ? AppColors.danger : AppColors.success,
      ),
    );
  }
}

class _ThemePresetCard extends StatelessWidget {
  final AppThemePreset preset;
  final bool isUnlocked;
  final bool isActive;
  final int userCredits;
  final bool canSpend;
  final VoidCallback onTap;

  const _ThemePresetCard({
    required this.preset,
    required this.isUnlocked,
    required this.isActive,
    required this.userCredits,
    required this.canSpend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final swatch = AppThemePalette.forPreset(preset);
    final palette = context.palette;
    final canAfford = canSpend && userCredits >= preset.costCredits;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? palette.primary : palette.border,
          width: isActive ? 1.8 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Live mini swatch preview
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: swatch.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: swatch.border, width: 1.5),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: swatch.heroGradient,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: swatch.primary,
                      shape: BoxShape.circle,
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        preset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (preset.isDark)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'DARK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  preset.tagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: isActive ? null : onTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size(86, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              backgroundColor: isActive
                  ? AppColors.success
                  : (isUnlocked
                      ? palette.primarySoft
                      : (canAfford ? palette.primary : Colors.grey.shade400)),
              foregroundColor: isActive
                  ? Colors.white
                  : (isUnlocked ? palette.primary : Colors.white),
            ),
            child: Text(
              isActive
                  ? 'Equipped'
                  : (isUnlocked
                      ? 'Equip'
                      : '${preset.costCredits} ⚡'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlarmSoundCard extends StatelessWidget {
  final AlarmSoundPreset preset;
  final bool isUnlocked;
  final bool isActive;
  final int userCredits;
  final bool canSpend;
  final VoidCallback onPreview;
  final VoidCallback onTap;

  const _AlarmSoundCard({
    required this.preset,
    required this.isUnlocked,
    required this.isActive,
    required this.userCredits,
    required this.canSpend,
    required this.onPreview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canAfford = canSpend && userCredits >= preset.costCredits;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? palette.primary : palette.border,
          width: isActive ? 1.8 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.music_note_rounded,
                size: 20, color: palette.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preset.tagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Preview Sound',
            onPressed: onPreview,
            icon: Icon(Icons.play_circle_outline_rounded,
                color: palette.primary),
          ),
          FilledButton(
            onPressed: isActive ? null : onTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size(80, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              backgroundColor: isActive
                  ? AppColors.success
                  : (isUnlocked
                      ? palette.primarySoft
                      : (canAfford ? palette.primary : Colors.grey.shade400)),
              foregroundColor: isActive
                  ? Colors.white
                  : (isUnlocked ? palette.primary : Colors.white),
            ),
            child: Text(
              isActive
                  ? 'Active'
                  : (isUnlocked ? 'Use' : '${preset.costCredits} ⚡'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSoundCard extends StatelessWidget {
  final NotificationSoundPreset preset;
  final bool isActive;
  final VoidCallback onPreview;
  final VoidCallback onSelect;

  const _NotificationSoundCard({
    required this.preset,
    required this.isActive,
    required this.onPreview,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? palette.primary : palette.border,
          width: isActive ? 1.8 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              size: 20,
              color: palette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preset.tagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Preview Notification Sound',
            onPressed: onPreview,
            icon: Icon(
              Icons.play_circle_outline_rounded,
              color: palette.primary,
            ),
          ),
          FilledButton(
            onPressed: isActive ? null : onSelect,
            style: FilledButton.styleFrom(
              minimumSize: const Size(80, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              backgroundColor:
                  isActive ? AppColors.success : palette.primarySoft,
              foregroundColor: isActive ? Colors.white : palette.primary,
            ),
            child: Text(
              isActive ? 'Active' : 'Use',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
