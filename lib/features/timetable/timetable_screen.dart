import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/uuid_util.dart';
import '../../models/models.dart';
import '../../providers/class_providers.dart';
import '../../core/widgets/admin_passcode_dialog.dart';
import '../../core/services/auth_service.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  int _selectedDay = 1; // 1 = Monday ... 6 = Saturday
  int _currentTab = 0; // 0 = Schedule, 1 = Timetable Sheet Image, 2 = Bunk Radar

  static const List<Map<String, dynamic>> _days = [
    {'day': 1, 'label': 'Mon', 'fullName': 'Monday'},
    {'day': 2, 'label': 'Tue', 'fullName': 'Tuesday'},
    {'day': 3, 'label': 'Wed', 'fullName': 'Wednesday'},
    {'day': 4, 'label': 'Thu', 'fullName': 'Thursday'},
    {'day': 5, 'label': 'Fri', 'fullName': 'Friday'},
    {'day': 6, 'label': 'Sat', 'fullName': 'Saturday'},
    {'day': 7, 'label': 'Sun', 'fullName': 'Sunday'},
  ];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().weekday;
    if (today >= 1 && today <= 7) {
      _selectedDay = today;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final allSlots = ref.watch(timetableSlotsProvider);
    final subjects = ref.watch(subjectsProvider);
    // ignore: unused_local_variable
    final attendanceMap = ref.watch(attendanceProvider);
    final overrides = ref.watch(dailyOverridesProvider);

    final filteredSlots =
        allSlots.where((s) => s.dayOfWeek == _selectedDay).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final selectedDayName =
        _days.firstWhere((d) => d['day'] == _selectedDay)['fullName'] as String;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Timetable & Attendance'),
        actions: [
          if (user.isAdmin || AuthService.isAdminEmail(user.email))
            IconButton(
              tooltip: 'Admin Management Console',
              icon: const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.warning,
              ),
              onPressed: () async {
                await showAdminPasscodeDialog(
                  context,
                  ref,
                  autoOpenConsole: true,
                );
              },
            ),
          // 2-Way Mode Switcher: Daily Schedule & Official Sheet Image (Bunk Radar moved to Future Updates)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  icon: Icon(Icons.view_agenda_rounded, size: 16),
                  tooltip: 'Daily Schedule',
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: Icon(Icons.image_rounded, size: 16),
                  tooltip: 'Official Timetable Sheet',
                ),
              ],
              selected: {_currentTab > 1 ? 0 : _currentTab},
              onSelectionChanged: (set) =>
                  setState(() => _currentTab = set.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: (user.isAdmin && _currentTab == 0)
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _openSlotFormDialog(context, subjects),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Lecture'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : (user.isAdmin && _currentTab == 1)
              ? FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: () => _showUpdateTimetableImageDialog(context),
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text('Set Timetable Image'),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                )
              : null,
      body: SafeArea(
        bottom: false,
        child: _currentTab == 1
            ? _buildOfficialTimetableImageView(user.isAdmin)
            : _buildTimetableGridView(
                filteredSlots,
                subjects,
                selectedDayName,
                user.isAdmin,
                overrides,
              ),
      ),
    );
  }

  // ===================================================================
  // TIMETABLE GRID VIEW WITH DAY SELECTOR PILLS
  // ===================================================================

  Widget _buildTimetableGridView(
    List<TimetableSlotModel> slots,
    List<SubjectModel> subjects,
    String dayName,
    bool isAdmin,
    List<DailyOverrideModel> overrides,
  ) {
    return Column(
      children: [
        // Horizontal Day Selector Pills
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final d = _days[index];
              final dayNum = d['day'] as int;
              final label = d['label'] as String;
              final isSelected = dayNum == _selectedDay;

              return InkWell(
                onTap: () => setState(() => _selectedDay = dayNum),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Day Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$dayName Schedule',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${slots.length} Lectures',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _openSlotFormDialog(context, subjects),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.add_rounded,
                                size: 14, color: AppColors.primary),
                            SizedBox(width: 2),
                            Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Slots List
        Expanded(
          child: slots.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_busy_rounded,
                          size: 44, color: AppColors.border),
                      const SizedBox(height: 10),
                      Text(
                        'No lectures scheduled on $dayName.',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _openSlotFormDialog(context, subjects),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text('Schedule Lecture for $dayName'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: slots.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    final targetUuid = UuidUtil.fromString(slot.subjectId);
                    final subject = subjects.firstWhere(
                      (s) => s.id == slot.subjectId || UuidUtil.fromString(s.id) == targetUuid,
                      orElse: () => subjects.isNotEmpty
                          ? subjects.first
                          : const SubjectModel(
                              id: 'unknown',
                              name: 'Class Lecture',
                              code: 'LEC',
                              professor: 'Instructor',
                            ));
                    final slotOverride = overrides.cast<DailyOverrideModel?>().firstWhere(
                      (o) => o != null && o.slotId == slot.id && o.isApproved,
                      orElse: () => null,
                    );

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left time block
                          SizedBox(
                            width: 92,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  slot.formattedStartTime,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  slot.formattedEndTime,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Color strip
                          Container(
                            width: 3,
                            height: 50,
                            decoration: BoxDecoration(
                              color: subject.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            subject.color.withValues(alpha: 0.1),
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
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          const Icon(Icons.room_outlined,
                                              size: 13,
                                              color: AppColors.textSecondary),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              slot.defaultRoom,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subject.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subject.professor,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (slotOverride != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: slotOverride.status ==
                                              OverrideStatus.cancelled
                                          ? AppColors.danger
                                              .withValues(alpha: 0.1)
                                          : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          slotOverride.status ==
                                                  OverrideStatus.cancelled
                                              ? Icons.cancel_rounded
                                              : Icons.schedule_rounded,
                                          size: 12,
                                          color: slotOverride.status ==
                                                  OverrideStatus.cancelled
                                              ? AppColors.danger
                                              : AppColors.warning,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            slotOverride.status ==
                                                    OverrideStatus.cancelled
                                                ? 'CANCELLED'
                                                : 'RESCHEDULED: ${slotOverride.formattedStartTime ?? slot.formattedStartTime}${slotOverride.formattedEndTime != null ? " - ${slotOverride.formattedEndTime}" : ""}${slotOverride.actualRoom != null ? " • ${slotOverride.actualRoom}" : ""}${slotOverride.rescheduledDate != null ? " • ${_dayNameFromWeekday(slotOverride.rescheduledDate!.weekday)}" : ""}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: slotOverride.status ==
                                                      OverrideStatus.cancelled
                                                  ? AppColors.danger
                                                  : AppColors.warning,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (slotOverride?.status !=
                                        OverrideStatus.cancelled &&
                                    ((slotOverride?.hasMeetingUrl ?? false) ||
                                        slot.hasMeetingUrl)) ...[
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => Formatters.launchMeetingUrl(
                                      context,
                                      slotOverride?.effectiveMeetingUrl ??
                                          slot.effectiveMeetingUrl,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySoft,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.video_call_rounded,
                                              size: 15,
                                              color: AppColors.primary),
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
                                              size: 12,
                                              color: AppColors.primary),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Admin Action Menu
                          if (isAdmin)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded,
                                  color: AppColors.textSecondary, size: 20),
                              padding: EdgeInsets.zero,
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _openSlotFormDialog(context, subjects,
                                      existingSlot: slot);
                                } else if (val == 'broadcast') {
                                  _openQuickOverrideDialog(
                                      context, slot, subject);
                                } else if (val == 'delete') {
                                  _confirmDeleteSlot(context, slot, subject);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'broadcast',
                                  child: Row(
                                    children: [
                                      Icon(Icons.campaign_rounded,
                                          size: 18, color: AppColors.warning),
                                      SizedBox(width: 8),
                                      Text('Broadcast Override'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
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
                  },
                ),
        ),
      ],
    );
  }

  // ===================================================================
  // ADMIN TIMETABLE INTERACTIVE MODALS
  // ===================================================================

  void _openSlotFormDialog(
    BuildContext context,
    List<SubjectModel> subjects, {
    TimetableSlotModel? existingSlot,
  }) {
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one course/subject first.'),
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
              decoration: const BoxDecoration(
                color: Colors.white,
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
                          style: const TextStyle(
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

                    const Text(
                      'Course / Subject',
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
                        color: const Color(0xFFF8FAFC),
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

                    const Text(
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

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
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
                                    color: const Color(0xFFF8FAFC),
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
                                      const Icon(Icons.access_time_rounded,
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
                              const Text(
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
                                    color: const Color(0xFFF8FAFC),
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
                                      const Icon(Icons.access_time_rounded,
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

                    const Text(
                      'Default Room / Hall',
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
                        hintText: 'e.g. Hall A-102, Lab 3, Online',
                        prefixIcon: const Icon(Icons.room_outlined, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
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
                            'e.g. https://meet.google.com/... or Zoom link',
                        prefixIcon:
                            const Icon(Icons.video_call_rounded, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

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
                              startTime: Formatters.normalizeTime(startTime),
                              endTime: Formatters.normalizeTime(endTime),
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
                              startTime: Formatters.normalizeTime(startTime),
                              endTime: Formatters.normalizeTime(endTime),
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

                          final baseMsg = isEditing
                              ? 'Timetable slot updated (${Formatters.formatTimeRangeString(startTime, endTime)})!'
                              : 'New slot added to timetable!';

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error == null ? baseMsg : '$baseMsg (Cloud: $error)',
                              ),
                              backgroundColor:
                                  error == null ? AppColors.success : AppColors.warning,
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
          'Remove ${subject.name} slot (${slot.formattedTimeRange})?',
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

  void _openQuickOverrideDialog(
    BuildContext context,
    TimetableSlotModel slot,
    SubjectModel subject,
  ) {
    final roomController = TextEditingController(text: slot.defaultRoom);
    final meetingUrlController =
        TextEditingController(text: slot.meetingUrl ?? '');
    final topicController = TextEditingController();
    OverrideStatus status = OverrideStatus.rescheduled;
    String startTime = Formatters.normalizeTime(slot.startTime);
    String endTime = Formatters.normalizeTime(slot.endTime);

    final now = DateTime.now();
    int dayDiff = slot.dayOfWeek - now.weekday;
    if (dayDiff < 0) dayDiff += 7;
    final DateTime originDate =
        DateTime(now.year, now.month, now.day).add(Duration(days: dayDiff));
    DateTime selectedDate = originDate;
    bool alsoUpdatePermanentSlot = false;

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
              decoration: const BoxDecoration(
                color: Colors.white,
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
                      'Broadcast Override: ${subject.code}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Regular: ${slot.formattedTimeRange} • ${slot.defaultRoom}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    const Text(
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
                      const Text(
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
                            firstDate: DateTime.now().subtract(const Duration(days: 7)),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${_dayNameFromWeekday(selectedDate.weekday)}, ${selectedDate.day} ${_monthName(selectedDate.month)} ${selectedDate.year}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
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
                                    color: selectedDate.weekday == (d['day'] as int)
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                  backgroundColor: selectedDate.weekday == (d['day'] as int)
                                      ? AppColors.primary
                                      : const Color(0xFFF1F5F9),
                                  onPressed: () {
                                    final targetW = d['day'] as int;
                                    final now = DateTime.now();
                                    int diff = targetW - now.weekday;
                                    if (diff < 0) diff += 7;
                                    setModalState(() {
                                      selectedDate = DateTime(now.year, now.month, now.day)
                                          .add(Duration(days: diff));
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Meeting Time (Start & End)
                      const Text(
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
                                final parts = norm.split(':').map(int.parse).toList();
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(hour: parts[0], minute: parts[1]),
                                );
                                if (picked != null) {
                                  final h = picked.hour.toString().padLeft(2, '0');
                                  final m = picked.minute.toString().padLeft(2, '0');
                                  setModalState(() => startTime = '$h:$m');
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Start Time', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                        Text(Formatters.formatTimeString(startTime), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
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
                                final parts = norm.split(':').map(int.parse).toList();
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(hour: parts[0], minute: parts[1]),
                                );
                                if (picked != null) {
                                  final h = picked.hour.toString().padLeft(2, '0');
                                  final m = picked.minute.toString().padLeft(2, '0');
                                  setModalState(() => endTime = '$h:$m');
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 18, color: AppColors.warning),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('End Time', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                        Text(Formatters.formatTimeString(endTime), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        value: alsoUpdatePermanentSlot,
                        onChanged: (val) => setModalState(
                            () => alsoUpdatePermanentSlot = val ?? false),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        title: const Text(
                          'Also update permanent weekly timetable slot',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Room / Venue
                      const Text(
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
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Meeting / Online Class URL (Optional)
                      const Text(
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
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    const Text(
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
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final normStart = Formatters.normalizeTime(startTime);
                          final normEnd = Formatters.normalizeTime(endTime);
                          final roomText = roomController.text.trim();
                          final meetingUrlText =
                              meetingUrlController.text.trim();

                          if (status == OverrideStatus.rescheduled &&
                              alsoUpdatePermanentSlot) {
                            await ref
                                .read(timetableSlotsProvider.notifier)
                                .updateSlot(
                                  slot.copyWith(
                                    dayOfWeek: selectedDate.weekday,
                                    startTime: normStart,
                                    endTime: normEnd,
                                    defaultRoom: roomText.isNotEmpty
                                        ? roomText
                                        : slot.defaultRoom,
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
                                slotId: slot.id,
                                status: status,
                                date: status == OverrideStatus.cancelled
                                    ? selectedDate
                                    : originDate,
                                actualRoom: status == OverrideStatus.rescheduled
                                    ? roomText
                                    : null,
                                actualStartTime: status == OverrideStatus.rescheduled
                                    ? normStart
                                    : null,
                                actualEndTime: status == OverrideStatus.rescheduled
                                    ? normEnd
                                    : null,
                                rescheduledDate: status == OverrideStatus.rescheduled
                                    ? selectedDate
                                    : null,
                                meetingUrl: status == OverrideStatus.rescheduled &&
                                        meetingUrlText.isNotEmpty
                                    ? meetingUrlText
                                    : null,
                                topicCovered: topicController.text.trim().isNotEmpty
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

  // ===================================================================
  // OFFICIAL TIMETABLE SHEET IMAGE VIEW (Google Drive Streamed)
  // ===================================================================

  Widget _buildOfficialTimetableImageView(bool isAdmin) {
    final imageUrl = ref.watch(timetableImageUrlProvider);

    if (imageUrl == null || imageUrl.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.image_search_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Timetable Sheet Published',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'The administrator has not uploaded the official class timetable image yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _showUpdateTimetableImageDialog(context),
                  icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: const Text('Set Google Drive Timetable Image'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Helper Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.zoom_in_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Pinch to zoom • Drag to navigate timetable sheet',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary),
                ),
              ),
              if (isAdmin)
                TextButton.icon(
                  onPressed: () => _showUpdateTimetableImageDialog(context),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('Update',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),

        // Interactive Zoomable Timetable Sheet
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.8,
              maxScale: 6.0,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    final total = progress.expectedTotalBytes;
                    final loaded = progress.cumulativeBytesLoaded;
                    final pct = total != null ? (loaded / total) : null;
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(value: pct),
                          const SizedBox(height: 12),
                          const Text(
                            'Streaming timetable sheet from Google Drive...',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  },
                  errorBuilder: (ctx, err, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image_rounded,
                              size: 48, color: AppColors.danger),
                          const SizedBox(height: 10),
                          const Text(
                            'Could not stream image from Google Drive',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Please ensure file access in Google Drive is set to "Anyone with the link can view".',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(height: 14),
                            FilledButton.tonal(
                              onPressed: () =>
                                  _showUpdateTimetableImageDialog(context),
                              child: const Text('Update Google Drive Link'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showUpdateTimetableImageDialog(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final currentUrl = ref.read(timetableImageUrlProvider) ?? '';
    final controller = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Timetable Sheet Image',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the Google Drive sharing link of your official timetable image. Make sure file access is set to "Anyone with the link can view":',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Google Drive Sharing Link',
                hintText: 'https://drive.google.com/file/d/...',
                prefixIcon: const Icon(Icons.link_rounded, size: 20),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel'),
          ),
          if (currentUrl.isNotEmpty)
            TextButton(
              onPressed: () async {
                await ref.read(timetableImageUrlProvider.notifier).clearImage();
                if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Timetable image removed.')),
                );
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Remove Image'),
            ),
          FilledButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid Google Drive image link.')),
                );
                return;
              }
              await ref
                  .read(timetableImageUrlProvider.notifier)
                  .updateImage(url);
              if (dlgCtx.mounted) Navigator.pop(dlgCtx);
              messenger.showSnackBar(
                const SnackBar(
                  content:
                      Text('Official timetable image published successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save & Publish'),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // BUNK CALCULATOR ("ATTENDANCE RADAR")
  // ===================================================================


  // ignore: unused_element
  Widget _buildBunkRadarView(
    List<SubjectModel> subjects,
    Map<String, AttendanceRecord> attendanceMap,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Radar Header Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.radar_rounded,
                    size: 24, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Radar (75% Safe Threshold)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Real-time bunk margin predictor. 1-tap Present / Absent logging.',
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
        ),
        const SizedBox(height: 16),

        // Subjects Attendance Cards
        for (final subject in subjects) ...[
          _AttendanceSubjectCard(
            subject: subject,
            record: attendanceMap[subject.id] ??
                AttendanceRecord(subjectId: subject.id, attended: 0, total: 0),
            onPresent: () =>
                ref.read(attendanceProvider.notifier).markPresent(subject.id),
            onAbsent: () =>
                ref.read(attendanceProvider.notifier).markAbsent(subject.id),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AttendanceSubjectCard extends StatelessWidget {
  final SubjectModel subject;
  final AttendanceRecord record;
  final VoidCallback onPresent;
  final VoidCallback onAbsent;

  const _AttendanceSubjectCard({
    required this.subject,
    required this.record,
    required this.onPresent,
    required this.onAbsent,
  });

  @override
  Widget build(BuildContext context) {
    final pct = record.percentage;
    final isSafe = pct >= subject.minAttendancePct;
    final margin = record.bunkAllowance(subject.minAttendancePct);

    final statusColor = isSafe ? AppColors.success : AppColors.danger;

    String adviceText;
    if (isSafe) {
      if (margin == 0) {
        adviceText = 'On the edge! Missing the next lecture drops below 75%.';
      } else {
        adviceText = 'Safe: You can bunk $margin more lecture${margin == 1 ? '' : 's'} before hitting 75%.';
      }
    } else {
      final needed = margin.abs();
      adviceText = 'Danger: Attend the next $needed lecture${needed == 1 ? '' : 's'} consecutively to hit 75%.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSafe ? AppColors.border : AppColors.danger.withValues(alpha: 0.35),
          width: isSafe ? 1.0 : 1.3,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Code + Name + Percentage
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: subject.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subject.code,
                  style: TextStyle(
                    color: subject.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100.0,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 10),

          // Attendance fraction + Radar margin advice
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attended: ${record.attended} / ${record.total} classes',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isSafe ? 'SAFE' : 'CRITICAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Advice banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  isSafe
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  size: 15,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    adviceText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1-Tap Present / Absent Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPresent,
                  icon: const Icon(Icons.check_rounded,
                      size: 16, color: AppColors.success),
                  label: const Text(
                    'Present (+1)',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppColors.success.withValues(alpha: 0.3)),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAbsent,
                  icon: const Icon(Icons.close_rounded,
                      size: 16, color: AppColors.danger),
                  label: const Text(
                    'Absent (-1)',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.3)),
                    minimumSize: const Size(0, 40),
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
