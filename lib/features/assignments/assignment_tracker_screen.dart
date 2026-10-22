import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/class_providers.dart';

class AssignmentTrackerScreen extends ConsumerStatefulWidget {
  const AssignmentTrackerScreen({super.key});

  @override
  ConsumerState<AssignmentTrackerScreen> createState() =>
      _AssignmentTrackerScreenState();
}

class _AssignmentTrackerScreenState
    extends ConsumerState<AssignmentTrackerScreen> {
  String _selectedFilter = 'all'; // 'all', 'urgent', 'pending', 'completed'
  String? _selectedSubjectId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final assignments = ref.watch(assignmentsProvider);
    final subjects = ref.watch(subjectsProvider);
    final completedIds = ref.watch(assignmentCompletionProvider);

    // Subject mapping
    final subjectMap = {for (var s in subjects) s.id: s};

    // Filter assignments
    final filtered = assignments.where((a) {
      if (_selectedSubjectId != null && a.subjectId != _selectedSubjectId) {
        return false;
      }
      final isDone = completedIds.contains(a.id);
      if (_selectedFilter == 'pending' && isDone) return false;
      if (_selectedFilter == 'completed' && !isDone) return false;
      if (_selectedFilter == 'urgent' && !(a.isDueTomorrow || a.isDueToday)) {
        return false;
      }
      return true;
    }).toList();

    // Stats
    final total = assignments.length;
    final completedCount =
        assignments.where((a) => completedIds.contains(a.id)).length;
    final progress = total > 0 ? (completedCount / total) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Assignment Tracker'),
        actions: [
          if (user.isAdmin)
            IconButton(
              tooltip: 'Post New Assignment',
              icon: const Icon(Icons.add_task_rounded, color: AppColors.primary),
              onPressed: () => _showCreateAssignmentDialog(context, subjects),
            ),
        ],
      ),
      floatingActionButton: user.isAdmin
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _showCreateAssignmentDialog(context, subjects),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Post Assignment'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Student Progress & Privacy Header Card
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Personal Progress',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$completedCount of $total Assignments Completed',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: progress == 1.0
                              ? const Color(0xFFDCFCE7)
                              : AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: progress == 1.0
                                ? const Color(0xFF15803D)
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      color: progress == 1.0
                          ? const Color(0xFF10B981)
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      Icon(Icons.lock_outline_rounded,
                          size: 13, color: Color(0xFF94A3B8)),
                      SizedBox(width: 5),
                      Text(
                        'Checkmarks are saved privately on your device only.',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildStatusChip('all', 'All ($total)'),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    'urgent',
                    'Due Soon ⏰',
                    customColor: const Color(0xFFEA580C),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip('pending', 'Pending (${total - completedCount})'),
                  const SizedBox(width: 8),
                  _buildStatusChip('completed', 'Done ($completedCount)'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Course selector pills
            if (subjects.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All Courses',
                          style: TextStyle(fontSize: 11)),
                      selected: _selectedSubjectId == null,
                      onSelected: (_) =>
                          setState(() => _selectedSubjectId = null),
                    ),
                    ...subjects.map((sub) {
                      final isSel = _selectedSubjectId == sub.id;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: FilterChip(
                          avatar: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: sub.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          label: Text(sub.code,
                              style: const TextStyle(fontSize: 11)),
                          selected: isSel,
                          onSelected: (_) => setState(
                              () => _selectedSubjectId = isSel ? null : sub.id),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            const SizedBox(height: 10),

            // Assignments List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.assignment_turned_in_rounded,
                                size: 38,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No Assignments Here!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedFilter == 'completed'
                                  ? 'You haven\'t marked any assignments as completed yet.'
                                  : (_selectedFilter == 'urgent'
                                      ? 'No assignments due today or tomorrow. Great job staying ahead!'
                                      : 'No assignments match the selected filters.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, index) {
                        final a = filtered[index];
                        final sub = subjectMap[a.subjectId];
                        final isDone = completedIds.contains(a.id);
                        return _buildAssignmentCard(
                            context, a, sub, isDone, user.isAdmin);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String key, String label, {Color? customColor}) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected
              ? Colors.white
              : (customColor ?? AppColors.textSecondary),
        ),
      ),
      selected: isSelected,
      selectedColor: customColor ?? AppColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? Colors.transparent
            : (customColor?.withValues(alpha: 0.3) ?? AppColors.border),
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = key);
      },
    );
  }

  Widget _buildAssignmentCard(
    BuildContext context,
    AssignmentModel a,
    SubjectModel? sub,
    bool isDone,
    bool isAdmin,
  ) {
    Color statusColor = AppColors.primary;
    String statusLabel = a.formattedDeadline;

    if (a.isDueToday) {
      statusColor = const Color(0xFFDC2626);
      statusLabel = 'DUE TODAY (${a.formattedDeadline})';
    } else if (a.isDueTomorrow) {
      statusColor = const Color(0xFFEA580C);
      statusLabel = 'DUE TOMORROW (${a.formattedDeadline})';
    } else if (a.isOverdue) {
      statusColor = const Color(0xFF64748B);
      statusLabel = 'OVERDUE (${a.formattedDeadline})';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? const Color(0xFF86EFAC)
              : (a.isDueTomorrow || a.isDueToday
                  ? statusColor.withValues(alpha: 0.5)
                  : AppColors.border),
          width: (a.isDueTomorrow || a.isDueToday) ? 1.5 : 1.0,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Subject pill + Deadline badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (sub != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sub.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: sub.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          sub.code,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: sub.color,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Checkbox + Title Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.scale(
                  scale: 1.15,
                  child: Checkbox(
                    value: isDone,
                    activeColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    onChanged: (_) {
                      HapticFeedback.lightImpact();
                      ref
                          .read(assignmentCompletionProvider.notifier)
                          .toggleCompleted(a.id);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: isDone
                              ? const Color(0xFF94A3B8)
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (a.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          a.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDone
                                ? const Color(0xFFCBD5E1)
                                : AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Bottom action row: Link attachment & Admin Delete
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (a.driveUrl != null && a.driveUrl!.isNotEmpty)
                  InkWell(
                    onTap: () async {
                      final uri = Uri.parse(a.driveUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attachment_rounded,
                              size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'Open Document / Link',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.danger),
                    tooltip: 'Delete Assignment',
                    onPressed: () => _confirmDeleteAssignment(context, a),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAssignment(BuildContext context, AssignmentModel a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Assignment?'),
        content: Text('Are you sure you want to delete "${a.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(assignmentsProvider.notifier)
                  .deleteAssignment(a.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCreateAssignmentDialog(
      BuildContext context, List<SubjectModel> subjects) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String? subjectId = subjects.isNotEmpty ? subjects.first.id : null;
    DateTime deadline = DateTime.now().add(const Duration(days: 1));
    TimeOfDay deadlineTime = const TimeOfDay(hour: 23, minute: 59);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (bCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const Text(
                      'Post New Class Assignment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This assignment will sync to all students and alert them if due tomorrow.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    // Subject Dropdown
                    const Text('Course *',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: subjectId,
                          isExpanded: true,
                          items: subjects
                              .map((s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text('${s.code} - ${s.name}'),
                                  ))
                              .toList(),
                          onChanged: (val) =>
                              setModalState(() => subjectId = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    const Text('Assignment Title *',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Lab 4: Tree Traversal in C++',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    const Text('Instructions / Problem Statement',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter guidelines, submission portal, etc.',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Deadline Pickers
                    const Text('Submission Deadline *',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today_rounded,
                                size: 16),
                            label: Text(
                              '${deadline.day}/${deadline.month}/${deadline.year}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: deadline,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 7)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setModalState(() => deadline = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time_rounded,
                                size: 16),
                            label: Text(
                              deadlineTime.format(ctx),
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: deadlineTime,
                              );
                              if (picked != null) {
                                setModalState(() => deadlineTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Drive Link
                    const Text('Google Drive / Document Link (Optional)',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: urlCtrl,
                      decoration: InputDecoration(
                        hintText: 'https://drive.google.com/...',
                        prefixIcon: const Icon(Icons.link_rounded, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Submit
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty || subjectId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please enter an assignment title.')),
                          );
                          return;
                        }

                        final combinedDeadline = DateTime(
                          deadline.year,
                          deadline.month,
                          deadline.day,
                          deadlineTime.hour,
                          deadlineTime.minute,
                        );

                        await ref
                            .read(assignmentsProvider.notifier)
                            .createAssignment(
                              subjectId: subjectId!,
                              title: title,
                              description: descCtrl.text.trim(),
                              deadline: combinedDeadline,
                              driveUrl: urlCtrl.text.trim(),
                            );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Assignment posted successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      child: const Text('Publish Assignment to Class',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
