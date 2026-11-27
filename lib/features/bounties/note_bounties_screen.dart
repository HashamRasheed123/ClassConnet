import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/uuid_util.dart';
import '../../models/models.dart';
import '../../providers/class_providers.dart';

class NoteBountiesScreen extends ConsumerStatefulWidget {
  const NoteBountiesScreen({super.key});

  @override
  ConsumerState<NoteBountiesScreen> createState() => _NoteBountiesScreenState();
}

class _NoteBountiesScreenState extends ConsumerState<NoteBountiesScreen> {
  int _tab = 0; // 0 = Open, 1 = My Requests, 2 = Review / Helped, 3 = Completed

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final bounties = ref.watch(noteBountiesProvider);
    final subjects = ref.watch(subjectsProvider);
    final verificationReqs = ref.watch(studentVerificationRequestsProvider);
    final palette = context.palette;

    final isVerified = user.isKzynovexVerified || user.isAdmin;
    final normUserId = UuidUtil.fromString(user.id);

    final myPendingReq = verificationReqs.cast<StudentVerificationRequestModel?>().firstWhere(
          (r) =>
              r != null &&
              ((r.userId.isNotEmpty && UuidUtil.fromString(r.userId) == normUserId) ||
                  (user.email.isNotEmpty &&
                      r.email.toLowerCase() == user.email.toLowerCase())),
          orElse: () => null,
        );

    final filtered = bounties.where((b) {
      final isMine = UuidUtil.fromString(b.requesterId) == normUserId;
      final isHelper = b.helperId != null &&
          UuidUtil.fromString(b.helperId!) == normUserId;
      switch (_tab) {
        case 0:
          return b.isOpen;
        case 1:
          return isMine && !b.isCancelled;
        case 2:
          return (isMine && b.needsReview) ||
              isHelper ||
              (user.isAdmin && b.needsReview);
        case 3:
          return b.isCompleted;
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Note Bounties & Help'),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: palette.primarySoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: palette.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 14, color: palette.primary),
                  const SizedBox(width: 3),
                  Text(
                    '${user.credits} ⚡',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: palette.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh Bounties',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(noteBountiesProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () {
          if (!isVerified) {
            _openStudentVerificationDialog(context, user);
            return;
          }
          _openPostBountyDialog(context, subjects, user);
        },
        icon: Icon(isVerified ? Icons.add_task_rounded : Icons.verified_user_rounded),
        label: Text(isVerified ? 'Post Note Bounty' : 'Verify to Post'),
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Verification Gate Banner (only shown if NOT yet verified)
          if (!isVerified)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        color: AppColors.warning, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verified Student Badge Required',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.warningTextDeep,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            myPendingReq != null && myPendingReq.isPending
                                ? 'Verification pending admin approval (${myPendingReq.rollNo}).'
                                : (myPendingReq != null && myPendingReq.isRejected
                                    ? 'Rejected: ${myPendingReq.rejectionReason ?? "Check details"}. Tap to resubmit.'
                                    : 'Submit your Name & Roll No to stop fake accounts and unlock Bounties.'),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.warningTextDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (myPendingReq == null || !myPendingReq.isPending) ...[
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () =>
                            _openStudentVerificationDialog(context, user),
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
            ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                _tabChip(0, 'Open (${bounties.where((b) => b.isOpen).length})'),
                const SizedBox(width: 8),
                _tabChip(1, 'My Requests'),
                const SizedBox(width: 8),
                _tabChip(
                  2,
                  user.isAdmin
                      ? 'Review Queue (${bounties.where((b) => b.needsReview).length})'
                      : 'Submissions / Helped',
                ),
                const SizedBox(width: 8),
                _tabChip(3, 'Completed'),
              ],
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volunteer_activism_outlined,
                              size: 46, color: palette.textSecondary),
                          const SizedBox(height: 10),
                          Text(
                            'No Note Bounties Here Yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Need missing lecture notes? Offer escrowed ⚡ credits and only release payout after verifying the half-locked preview.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(noteBountiesProvider.notifier).refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final bounty = filtered[idx];
                        final subject =
                            resolveSubjectById(subjects, bounty.subjectId);
                        return _NoteBountyCard(
                          bounty: bounty,
                          subject: subject,
                          currentUser: user,
                          onClaim: () =>
                              _openSubmitSolutionDialog(context, bounty),
                          onPreviewAndConfirm: () =>
                              _openLockedPreviewSheet(context, bounty, false),
                          onAdminInspect: () =>
                              _openLockedPreviewSheet(context, bounty, true),
                          onCancel: () async {
                            final err = await ref
                                .read(noteBountiesProvider.notifier)
                                .cancelOpenBounty(bounty.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(err ??
                                    'Bounty cancelled and ${bounty.rewardCredits} ⚡ refunded.'),
                                backgroundColor: err != null
                                    ? AppColors.danger
                                    : AppColors.success,
                              ),
                            );
                          },
                          onHelperEscalate: () async {
                            final err = await ref
                                .read(noteBountiesProvider.notifier)
                                .disputeSubmission(
                                  bounty.id,
                                  'Helper escalated: awaiting requester confirmation.',
                                );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(err ??
                                    'Escalated to Admin Queue for verification & payout!'),
                                backgroundColor: err != null
                                    ? AppColors.danger
                                    : AppColors.warning,
                              ),
                            );
                          },
                          onViewFull: () =>
                              _openFullCompletedSheet(context, bounty),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(int idx, String label) {
    final selected = _tab == idx;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _tab = idx),
    );
  }

  Future<void> _openStudentVerificationDialog(
    BuildContext context,
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
              'Enter your official Full Name and University Roll Number. Admins verify these details to prevent fake credit accounts.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
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
                  .submitRequest(
                    name: nameCtrl.text,
                    rollNo: rollCtrl.text,
                  );
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
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    rollCtrl.dispose();
  }

  Future<void> _openPostBountyDialog(
    BuildContext context,
    List<SubjectModel> subjects,
    UserModel user,
  ) async {
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No courses found yet.')),
      );
      return;
    }

    String selectedSubjectId = subjects.first.id;
    int selectedReward = 30;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Post Note Bounty (Escrow Protected)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your balance: ${user.credits} ⚡ • Credits are held in escrow and ONLY paid once you confirm the half-locked preview (or Admin verifies).',
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedSubjectId,
                  decoration: const InputDecoration(labelText: 'Course / Subject'),
                  items: subjects
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.code} - ${s.name}',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedSubjectId = val);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'What notes do you need?',
                    hintText: 'e.g. Week 6 Calculus Lecture Notes + Solved Ex 4.2',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Specific details / acceptance criteria',
                    hintText: 'Specify topics, date, or format you require.',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Escrow Reward Amount',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [20, 30, 50, 75, 100].map((amt) {
                    return ChoiceChip(
                      label: Text('$amt ⚡'),
                      selected: selectedReward == amt,
                      onSelected: (_) =>
                          setModalState(() => selectedReward = amt),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final err = await ref
                          .read(noteBountiesProvider.notifier)
                          .createBounty(
                            subjectId: selectedSubjectId,
                            title: titleCtrl.text,
                            description: descCtrl.text,
                            rewardCredits: selectedReward,
                          );
                      if (err != null) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(err),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                        return;
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Bounty posted! $selectedReward ⚡ placed safely in escrow.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    child: Text('Escrow $selectedReward ⚡ & Post Bounty'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    titleCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _openSubmitSolutionDialog(
    BuildContext context,
    NoteBountyModel bounty,
  ) async {
    final notesCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fulfill Bounty (+${bounty.rewardCredits} ⚡)',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Anti-Scam Escrow: The requester only sees the first half of your notes & a locked attachment badge until they confirm payout or an Admin verifies.',
                style:
                    TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notesCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Notes Summary / Solution Content',
                  hintText:
                      'Paste lecture notes, summary, or solution explanation (15+ characters)...',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Google Drive / PDF Link (Locked until payout)',
                  hintText: 'https://drive.google.com/...',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final err = await ref
                        .read(noteBountiesProvider.notifier)
                        .submitSolution(
                          bountyId: bounty.id,
                          solutionText: notesCtrl.text,
                          solutionUrl: urlCtrl.text,
                        );
                    if (err != null) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(err),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Solution submitted! Payout will release once requester or Admin confirms.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  child: const Text('Submit Solution for Review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    notesCtrl.dispose();
    urlCtrl.dispose();
  }

  Future<void> _openLockedPreviewSheet(
    BuildContext context,
    NoteBountyModel bounty,
    bool asAdmin,
  ) async {
    final preview = bounty.buildLockedPreview();
    final disputeCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    asAdmin ? Icons.admin_panel_settings_rounded : Icons.lock_rounded,
                    color: asAdmin ? AppColors.warning : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      asAdmin
                          ? 'Admin Bounty Verification'
                          : 'Half-Locked Preview (Confirm to Unlock)',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Submitted by: ${bounty.helperName ?? "Verified Student"}${bounty.helperRollNo != null ? " (${bounty.helperRollNo})" : ""}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              if (bounty.disputeReason != null &&
                  bounty.disputeReason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Flagged Dispute Reason: ${bounty.disputeReason}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Text Section: Admin sees FULL unblurred text; Requester sees half clear + half garbled/blurred
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.palette.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.palette.border),
                ),
                child: asAdmin
                    ? SelectableText(
                        bounty.solutionText?.trim().isNotEmpty == true
                            ? bounty.solutionText!
                            : '(No text summary provided — check attachment below)',
                        style: const TextStyle(fontSize: 13, height: 1.45),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (preview.visibleHalf.isNotEmpty)
                            Text(
                              preview.visibleHalf,
                              style: const TextStyle(
                                  fontSize: 13, height: 1.45),
                            ),
                          if (preview.garbledHalf.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ImageFiltered(
                              imageFilter:
                                  ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
                              child: Text(
                                preview.garbledHalf,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                          if (preview.visibleHalf.isEmpty &&
                              preview.garbledHalf.isEmpty)
                            Text(
                              'Attachment submitted (download locked until payout).',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary),
                            ),
                        ],
                      ),
              ),

              if (bounty.solutionUrl != null &&
                  bounty.solutionUrl!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                if (asAdmin)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Formatters.launchMeetingUrl(
                          ctx, bounty.solutionUrl),
                      icon: const Icon(Icons.open_in_new_rounded, size: 17),
                      label: const Text('Admin: Inspect Full Attachment Link'),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            size: 16, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bounty.maskedAttachmentLabel ??
                                'Attached Document — Unlock to download',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warningTextDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              const SizedBox(height: 16),
              if (asAdmin) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final err = await ref
                              .read(noteBountiesProvider.notifier)
                              .adminRejectSubmission(bounty.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err ??
                                  'Scam rejected (0 credits). Bounty re-opened.'),
                              backgroundColor: err != null
                                  ? AppColors.danger
                                  : AppColors.warning,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.danger),
                          foregroundColor: AppColors.danger,
                        ),
                        child: const Text('Reject Scam'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final err = await ref
                              .read(noteBountiesProvider.notifier)
                              .adminApproveBounty(bounty.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err ??
                                  'Verified! ${bounty.rewardCredits} ⚡ paid to helper.'),
                              backgroundColor: err != null
                                  ? AppColors.danger
                                  : AppColors.success,
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success),
                        child: Text('Pay ${bounty.rewardCredits} ⚡'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final err = await ref
                          .read(noteBountiesProvider.notifier)
                          .confirmAndReleasePayout(bounty.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err ??
                              'Full document unlocked! ${bounty.rewardCredits} ⚡ released to helper.'),
                          backgroundColor:
                              err != null ? AppColors.danger : AppColors.success,
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock_open_rounded, size: 18),
                    label: Text(
                        'Confirm & Unlock Full Notes (${bounty.rewardCredits} ⚡)'),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: disputeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Looks wrong or spam? Reason for Admin (Optional)',
                    hintText: 'e.g. Wrong lecture / gibberish text',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final err = await ref
                          .read(noteBountiesProvider.notifier)
                          .disputeSubmission(bounty.id, disputeCtrl.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err ??
                              'Flagged for Admin Review! Escrow remains safely locked.'),
                          backgroundColor:
                              err != null ? AppColors.danger : AppColors.warning,
                        ),
                      );
                    },
                    icon: const Icon(Icons.flag_outlined, size: 17),
                    label: const Text('Flag as Scam / Wrong (Hold Escrow)'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      foregroundColor: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    disputeCtrl.dispose();
  }

  Future<void> _openFullCompletedSheet(
    BuildContext context,
    NoteBountyModel bounty,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_open_rounded, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bounty.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Fulfilled by: ${bounty.helperName ?? "Verified Student"} • Paid ${bounty.rewardCredits} ⚡',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 12),
              if (bounty.solutionText != null &&
                  bounty.solutionText!.trim().isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.palette.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: SelectableText(
                    bounty.solutionText!,
                    style: const TextStyle(fontSize: 13.5, height: 1.5),
                  ),
                ),
              if (bounty.solutionUrl != null &&
                  bounty.solutionUrl!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        Formatters.launchMeetingUrl(ctx, bounty.solutionUrl),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Open / Download Full Document'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteBountyCard extends StatelessWidget {
  final NoteBountyModel bounty;
  final SubjectModel? subject;
  final UserModel currentUser;
  final VoidCallback onClaim;
  final VoidCallback onPreviewAndConfirm;
  final VoidCallback onAdminInspect;
  final VoidCallback onCancel;
  final VoidCallback onHelperEscalate;
  final VoidCallback onViewFull;

  const _NoteBountyCard({
    required this.bounty,
    required this.subject,
    required this.currentUser,
    required this.onClaim,
    required this.onPreviewAndConfirm,
    required this.onAdminInspect,
    required this.onCancel,
    required this.onHelperEscalate,
    required this.onViewFull,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final normCurrent = UuidUtil.fromString(currentUser.id);
    final isRequester = UuidUtil.fromString(bounty.requesterId) == normCurrent;
    final isHelper = bounty.helperId != null &&
        UuidUtil.fromString(bounty.helperId!) == normCurrent;

    final (statusLabel, statusColor) = switch (bounty.status) {
      'open' => ('OPEN BOUNTY', palette.primary),
      'submitted' => ('AWAITING CONFIRMATION', AppColors.warning),
      'disputed' => ('DISPUTED (ADMIN)', AppColors.danger),
      'completed' => ('UNLOCKED & PAID', AppColors.success),
      _ => ('CANCELLED', AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
              if (subject != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: subject!.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    subject!.code,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: subject!.color,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${bounty.rewardCredits} ⚡',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.warningText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            bounty.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          if (bounty.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              bounty.description,
              style: TextStyle(
                fontSize: 12,
                color: palette.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Requested by: ${bounty.requesterName}${bounty.requesterRollNo != null && bounty.requesterRollNo!.isNotEmpty ? " (${bounty.requesterRollNo})" : ""}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.textSecondary,
            ),
          ),
          if (bounty.helperName != null) ...[
            const SizedBox(height: 2),
            Text(
              'Helper: ${bounty.helperName}${bounty.helperRollNo != null && bounty.helperRollNo!.isNotEmpty ? " (${bounty.helperRollNo})" : ""}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (bounty.isOpen && !isRequester)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onClaim,
                icon: const Icon(Icons.upload_file_rounded, size: 17),
                label: Text('Help & Claim ${bounty.rewardCredits} ⚡'),
              ),
            ),
          if (bounty.isOpen && isRequester)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, size: 17),
                label: const Text('Cancel Bounty & Refund Escrow'),
              ),
            ),
          if (bounty.needsReview && isRequester)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPreviewAndConfirm,
                icon: const Icon(Icons.visibility_rounded, size: 17),
                label: const Text('Preview Notes & Confirm Payout'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.warning),
              ),
            ),
          if (bounty.needsReview && currentUser.isAdmin) ...[
            if (isRequester) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAdminInspect,
                icon: const Icon(Icons.admin_panel_settings_rounded, size: 17),
                label: const Text('Admin Full Inspect & Judge'),
              ),
            ),
          ],
          if (bounty.isSubmitted && isHelper && !isRequester) ...[
            if (currentUser.isAdmin) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onHelperEscalate,
                icon: const Icon(Icons.support_agent_rounded, size: 17),
                label: const Text('Requester Unresponsive? Escalate to Admin'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.warning),
                  foregroundColor: AppColors.warning,
                ),
              ),
            ),
          ],
          if (bounty.isCompleted &&
              (isRequester || isHelper || currentUser.isAdmin))
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onViewFull,
                icon: const Icon(Icons.lock_open_rounded, size: 17),
                label: const Text('View / Download Full Notes'),
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.success),
              ),
            ),
        ],
      ),
    );
  }
}
