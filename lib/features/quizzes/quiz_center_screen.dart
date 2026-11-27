import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/quiz_import_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/uuid_util.dart';
import '../../models/models.dart';
import '../../providers/class_providers.dart';

class QuizCenterScreen extends ConsumerStatefulWidget {
  final bool embeddedInAdmin;

  const QuizCenterScreen({
    super.key,
    this.embeddedInAdmin = false,
  });

  @override
  ConsumerState<QuizCenterScreen> createState() => _QuizCenterScreenState();
}

class _QuizCenterScreenState extends ConsumerState<QuizCenterScreen> {
  String? _selectedSubjectId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final quizzes = ref.watch(quizzesProvider);
    final subjects = ref.watch(subjectsProvider);
    final scores = ref.watch(quizScoreHistoryProvider);

    final filtered = quizzes.where((q) {
      if (_selectedSubjectId == null) return true;
      return q.subjectId == _selectedSubjectId ||
          UuidUtil.fromString(q.subjectId) ==
              UuidUtil.fromString(_selectedSubjectId!);
    }).toList();

    final bodyContent = CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 1. Hero Header Banner
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: _QuizCenterHeroBanner(
              totalQuizzes: quizzes.length,
              totalQuestions:
                  quizzes.fold<int>(0, (sum, q) => sum + q.questions.length),
              isAdmin: user.isAdmin,
              onAddQuiz: () => _showQuizEditorSheet(context, subjects),
            ),
          ),
        ),

        // 2. Course Filter Chips
        SliverToBoxAdapter(
          child: SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                _SubjectChip(
                  label: 'All Courses',
                  isSelected: _selectedSubjectId == null,
                  onTap: () => setState(() => _selectedSubjectId = null),
                ),
                const SizedBox(width: 8),
                ...subjects.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SubjectChip(
                      label: '${s.code} • ${s.name}',
                      isSelected: _selectedSubjectId != null &&
                          (s.id == _selectedSubjectId ||
                              UuidUtil.fromString(s.id) ==
                                  UuidUtil.fromString(_selectedSubjectId!)),
                      onTap: () => setState(() => _selectedSubjectId = s.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // 3. Quiz Cards List
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.quiz_outlined,
                        color: AppColors.primary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No Quizzes Yet',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.isAdmin
                          ? 'Tap "+ Add / Import NotebookLM Quiz" to pull MCQs from a NotebookLM link or paste questions.'
                          : 'Your admin has not published any quizzes for this filter yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 96),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final quiz = filtered[index];
                final subject = resolveSubjectById(subjects, quiz.subjectId);
                final scoreRecord = scores[quiz.id];
                return _QuizCard(
                  quiz: quiz,
                  subject: subject,
                  scoreRecord: scoreRecord,
                  isAdmin: user.isAdmin,
                  onPractice: () => _openQuizRunner(
                    context,
                    quiz: quiz,
                    subject: subject,
                    initialPracticeMode: true,
                  ),
                  onTakeTest: () => _openQuizRunner(
                    context,
                    quiz: quiz,
                    subject: subject,
                    initialPracticeMode: false,
                  ),
                  onEdit: () => _showQuizEditorSheet(
                    context,
                    subjects,
                    existing: quiz,
                  ),
                  onDelete: () => _confirmDeleteQuiz(context, quiz),
                );
              },
            ),
          ),
      ],
    );

    if (widget.embeddedInAdmin) {
      return Scaffold(
        backgroundColor: context.palette.background,
        body: bodyContent,
        floatingActionButton: user.isAdmin
            ? FloatingActionButton.extended(
                heroTag: 'admin_quiz_fab',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onPressed: () => _showQuizEditorSheet(context, subjects),
                icon: const Icon(Icons.add_task_rounded),
                label: const Text(
                  'Add / Import Quiz',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            : null,
      );
    }

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MCQ Quizzes & Practice Center',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.palette.textPrimary,
              ),
            ),
            Text(
              'NotebookLM Quizzes • Instant Check & Scored Tests',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 3),
                Text(
                  '${user.credits} Credits',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          if (user.isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _showQuizEditorSheet(context, subjects),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text(
                  'Add Quiz',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: bodyContent,
    );
  }

  void _openQuizRunner(
    BuildContext context, {
    required QuizModel quiz,
    required SubjectModel? subject,
    required bool initialPracticeMode,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizRunnerScreen(
          quiz: quiz,
          subject: subject,
          initialPracticeMode: initialPracticeMode,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteQuiz(BuildContext context, QuizModel quiz) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quiz?'),
        content: Text(
          'Are you sure you want to delete "${quiz.title}"? This will remove it for all students.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final err =
          await ref.read(quizzesProvider.notifier).deleteQuiz(quiz.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err == null ? 'Quiz deleted from cloud' : 'Deleted locally ($err)',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showQuizEditorSheet(
    BuildContext context,
    List<SubjectModel> subjects, {
    QuizModel? existing,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _QuizEditorScreen(
          subjects: subjects,
          existing: existing,
        ),
      ),
    );
  }
}

class _QuizCenterHeroBanner extends StatelessWidget {
  final int totalQuizzes;
  final int totalQuestions;
  final bool isAdmin;
  final VoidCallback onAddQuiz;

  const _QuizCenterHeroBanner({
    required this.totalQuizzes,
    required this.totalQuestions,
    required this.isAdmin,
    required this.onAddQuiz,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppRadii.hero),
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
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NotebookLM & Course MCQ Hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalQuizzes Active Quizzes • $totalQuestions Total MCQs',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Earn +1 Credit for every correct MCQ! Practice at your own pace or Take Test to earn up to $totalQuestions Credits and climb the Leaderboard.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onAddQuiz,
                icon: const Icon(Icons.add_link_rounded, size: 19),
                label: const Text(
                  'Add / Import NotebookLM Quiz',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final QuizModel quiz;
  final SubjectModel? subject;
  final QuizScoreRecord? scoreRecord;
  final bool isAdmin;
  final VoidCallback onPractice;
  final VoidCallback onTakeTest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuizCard({
    required this.quiz,
    required this.subject,
    required this.scoreRecord,
    required this.isAdmin,
    required this.onPractice,
    required this.onTakeTest,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasSourceUrl =
        quiz.sourceUrl != null && quiz.sourceUrl!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.cardSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: context.palette.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top badges row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  subject != null
                      ? '${subject!.code} • ${subject!.name}'
                      : 'General Quiz',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  '${quiz.questions.length} MCQs',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.successText,
                  ),
                ),
              ),
              if (quiz.questions.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 13,
                        color: AppColors.warningText,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '+${quiz.questions.length} Credits',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warningText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (isAdmin) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Edit Quiz',
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete Quiz',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Title & description
          Text(
            quiz.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (quiz.description.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              quiz.description,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],

          // NotebookLM Source Link + Student Best Score Row
          if (hasSourceUrl || scoreRecord != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (hasSourceUrl)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Formatters.launchMeetingUrl(
                      context,
                      quiz.sourceUrl!,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.blueBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              const Color(0xFF2563EB).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 13,
                            color: AppColors.blueText,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Open NotebookLM Source Link',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.blueText,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 12,
                            color: AppColors.blueText,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (scoreRecord != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 14,
                          color: AppColors.warningText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Best: ${scoreRecord!.bestScore}/${scoreRecord!.totalQuestions} (${scoreRecord!.bestPercentage.round()}%) • +${scoreRecord!.creditsEarned} Credits Earned',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warningText,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // Dual Action Buttons: Practice Mode vs Take Test Mode
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  onPressed: onPractice,
                  icon: const Icon(Icons.fact_check_outlined, size: 17),
                  label: const Text(
                    'Practice MCQs',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  onPressed: onTakeTest,
                  icon: const Icon(Icons.timer_outlined, size: 17),
                  label: const Text(
                    'Take Test',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
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

// ===========================================================================
// INTERACTIVE QUIZ RUNNER SCREEN (PRACTICE MODE + SCORED TEST MODE)
// ===========================================================================

class QuizRunnerScreen extends ConsumerStatefulWidget {
  final QuizModel quiz;
  final SubjectModel? subject;
  final bool initialPracticeMode;

  const QuizRunnerScreen({
    super.key,
    required this.quiz,
    required this.subject,
    required this.initialPracticeMode,
  });

  @override
  ConsumerState<QuizRunnerScreen> createState() => _QuizRunnerScreenState();
}

class _QuizRunnerScreenState extends ConsumerState<QuizRunnerScreen> {
  late bool _isPracticeMode;
  int _currentIndex = 0;
  final Map<int, int> _selectedOptions = {};
  final Set<int> _revealedHints = {};
  bool _isTestSubmitted = false;
  int _lastAwardedCredits = 0;

  @override
  void initState() {
    super.initState();
    _isPracticeMode = widget.initialPracticeMode;
  }

  List<QuizQuestionModel> get _questions => widget.quiz.questions;

  void _selectOption(int questionIdx, int optionIdx) {
    if (_isTestSubmitted && !_isPracticeMode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedOptions[questionIdx] = optionIdx;
    });

    // In Practice Mode, also award credits live as the student gets questions right!
    if (_isPracticeMode) {
      int correctCount = 0;
      for (int i = 0; i < _questions.length; i++) {
        if (_selectedOptions[i] == _questions[i].correctOptionIndex) {
          correctCount++;
        }
      }
      ref
          .read(quizScoreHistoryProvider.notifier)
          .recordScore(
            quizId: widget.quiz.id,
            score: correctCount,
            totalQuestions: _questions.length,
          )
          .then((earned) {
        if (earned > 0 && mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              content: Text(
                'Correct! +$earned ${earned == 1 ? 'Credit' : 'Credits'} added to your balance!',
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  Future<void> _submitTest() async {
    int correctCount = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedOptions[i] == _questions[i].correctOptionIndex) {
        correctCount++;
      }
    }
    final earned = await ref.read(quizScoreHistoryProvider.notifier).recordScore(
          quizId: widget.quiz.id,
          score: correctCount,
          totalQuestions: _questions.length,
        );
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    setState(() {
      _isTestSubmitted = true;
      _lastAwardedCredits = earned;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          earned > 0
              ? 'Awesome! You got $correctCount/${_questions.length} correct and earned +$earned Credits!'
              : 'You got $correctCount/${_questions.length} correct! Beat your best score on a retake to earn more credits.',
        ),
        backgroundColor:
            earned > 0 ? const Color(0xFF059669) : AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetQuiz() {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedOptions.clear();
      _revealedHints.clear();
      _isTestSubmitted = false;
      _lastAwardedCredits = 0;
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: context.palette.background,
        appBar: AppBar(
          backgroundColor: context.palette.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.quiz.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.palette.textPrimary,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.psychology_alt_rounded,
                    color: AppColors.primary,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No MCQ Questions in This Set Yet',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Questions can be added by the Admin or opened via the NotebookLM source link below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (widget.quiz.sourceUrl != null &&
                    widget.quiz.sourceUrl!.trim().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => Formatters.launchMeetingUrl(
                      context,
                      widget.quiz.sourceUrl!,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text('Open NotebookLM Quiz Link'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];
    final selectedIdx = _selectedOptions[_currentIndex];
    final showAnswerFeedback = _isPracticeMode
        ? selectedIdx != null
        : _isTestSubmitted;

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.quiz.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: context.palette.textPrimary,
              ),
            ),
            Text(
              _isPracticeMode
                  ? 'Practice Mode • Tap any option to check immediately'
                  : (_isTestSubmitted
                      ? 'Test Results & Answer Key Review'
                      : 'Test Mode • Answered ${_selectedOptions.length}/${_questions.length}'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 3),
                Text(
                  '${ref.watch(currentUserProvider).credits}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Reset Choices',
            onPressed: _resetQuiz,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Mode Switcher + Question Palette Bar
          Container(
            color: AppColors.cardSurface,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Column(
              children: [
                // Practice vs Test segmented toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isPracticeMode = true;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _isPracticeMode
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Practice (Instant Check)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _isPracticeMode
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isPracticeMode = false;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_isPracticeMode
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Take Test (Scored Exam)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: !_isPracticeMode
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Question Number Jump Palette ("check MCQs of his choice")
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _questions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      final isCurrent = idx == _currentIndex;
                      final picked = _selectedOptions[idx];
                      final isCorrect =
                          picked == _questions[idx].correctOptionIndex;

                      Color bg = AppColors.background;
                      Color fg = AppColors.textSecondary;
                      Color borderCol = AppColors.border;

                      if (_isPracticeMode && picked != null) {
                        bg = isCorrect
                            ? AppColors.successBgStrong
                            : AppColors.dangerBgStrong;
                        fg = isCorrect
                            ? AppColors.successText
                            : AppColors.dangerText;
                        borderCol = fg.withValues(alpha: 0.4);
                      } else if (!_isPracticeMode && _isTestSubmitted) {
                        if (picked == null) {
                          bg = AppColors.warningBg;
                          fg = AppColors.warningTextDeep;
                        } else if (isCorrect) {
                          bg = AppColors.successBgStrong;
                          fg = AppColors.successText;
                        } else {
                          bg = AppColors.dangerBgStrong;
                          fg = AppColors.dangerText;
                        }
                      } else if (picked != null) {
                        bg = AppColors.primarySoft;
                        fg = AppColors.primary;
                        borderCol = AppColors.primary;
                      }

                      if (isCurrent) {
                        borderCol = AppColors.primary;
                      }

                      return GestureDetector(
                        onTap: () => setState(() => _currentIndex = idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isCurrent && picked == null
                                ? AppColors.primary
                                : bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: borderCol,
                              width: isCurrent ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isCurrent && picked == null
                                  ? Colors.white
                                  : fg,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 2. Main Scrollable Question & Options Area (plus Scorecard if Test Submitted)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              children: [
                if (!_isPracticeMode && _isTestSubmitted) ...[
                  _buildTestScorecard(),
                  const SizedBox(height: 16),
                ],

                // Question Stem Card
                Container(
                  padding: const EdgeInsets.all(18),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Text(
                              'Question ${_currentIndex + 1} of ${_questions.length}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (q.hint != null && q.hint!.trim().isNotEmpty)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: const Color(0xFFD97706),
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_revealedHints.contains(_currentIndex)) {
                                    _revealedHints.remove(_currentIndex);
                                  } else {
                                    _revealedHints.add(_currentIndex);
                                  }
                                });
                              },
                              icon: const Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 16,
                              ),
                              label: Text(
                                _revealedHints.contains(_currentIndex)
                                    ? 'Hide Hint'
                                    : 'Show Hint',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        q.question,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      if (_revealedHints.contains(_currentIndex) &&
                          q.hint != null &&
                          q.hint!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.urgentBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lightbulb_rounded,
                                size: 17,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Hint: ${q.hint}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.warningTextDeep,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Options List (A, B, C, D...)
                ...List.generate(q.options.length, (optIdx) {
                  final letter = String.fromCharCode(65 + optIdx);
                  final isSelected = selectedIdx == optIdx;
                  final isCorrectOption = optIdx == q.correctOptionIndex;

                  Color cardBg = Colors.white;
                  Color borderCol = AppColors.border;
                  Color badgeBg = AppColors.background;
                  Color badgeFg = AppColors.textPrimary;
                  Widget? trailingIcon;

                  if (showAnswerFeedback) {
                    if (isCorrectOption) {
                      cardBg = AppColors.successBg;
                      borderCol = const Color(0xFF10B981);
                      badgeBg = const Color(0xFF10B981);
                      badgeFg = Colors.white;
                      trailingIcon = const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 22,
                      );
                    } else if (isSelected && !isCorrectOption) {
                      cardBg = AppColors.dangerBg;
                      borderCol = const Color(0xFFEF4444);
                      badgeBg = const Color(0xFFEF4444);
                      badgeFg = Colors.white;
                      trailingIcon = const Icon(
                        Icons.cancel_rounded,
                        color: Color(0xFFEF4444),
                        size: 22,
                      );
                    }
                  } else if (isSelected) {
                    cardBg = AppColors.primarySoft;
                    borderCol = AppColors.primary;
                    badgeBg = AppColors.primary;
                    badgeFg = Colors.white;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _selectOption(_currentIndex, optIdx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: borderCol,
                            width: (isSelected ||
                                    (showAnswerFeedback && isCorrectOption))
                                ? 1.8
                                : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                letter,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: badgeFg,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                q.options[optIdx],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            if (trailingIcon != null) ...[
                              const SizedBox(width: 8),
                              trailingIcon,
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Explanation / Rationale Box (shown in Practice Mode upon choice or after Test Submit)
                if (showAnswerFeedback) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selectedIdx == q.correctOptionIndex
                          ? AppColors.successBg
                          : AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selectedIdx == q.correctOptionIndex
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              selectedIdx == q.correctOptionIndex
                                  ? Icons.verified_rounded
                                  : Icons.info_outline_rounded,
                              size: 18,
                              color: selectedIdx == q.correctOptionIndex
                                  ? AppColors.successText
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              selectedIdx == q.correctOptionIndex
                                  ? 'Correct Answer! (${String.fromCharCode(65 + q.correctOptionIndex)})'
                                  : 'Correct Option: ${String.fromCharCode(65 + q.correctOptionIndex)} — ${q.options[q.correctOptionIndex]}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: selectedIdx == q.correctOptionIndex
                                    ? AppColors.successText
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        if (q.explanation != null &&
                            q.explanation!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            q.explanation!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 3. Bottom Navigation & Submit Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _currentIndex > 0
                        ? () => setState(() => _currentIndex--)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    label: const Text('Previous'),
                  ),
                  const SizedBox(width: 10),
                  if (!_isPracticeMode && !_isTestSubmitted)
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _submitTest,
                        icon: const Icon(Icons.task_alt_rounded, size: 18),
                        label: Text(
                          'Submit Test (${_selectedOptions.length}/${_questions.length})',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _currentIndex < _questions.length - 1
                        ? () => setState(() => _currentIndex++)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestScorecard() {
    int correct = 0;
    int wrong = 0;
    int skipped = 0;
    for (int i = 0; i < _questions.length; i++) {
      final picked = _selectedOptions[i];
      if (picked == null) {
        skipped++;
      } else if (picked == _questions[i].correctOptionIndex) {
        correct++;
      } else {
        wrong++;
      }
    }
    final pct =
        _questions.isNotEmpty ? ((correct / _questions.length) * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$pct%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Completed! Score: $correct / ${_questions.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Correct: $correct  •  Wrong: $wrong  •  Skipped: $skipped',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 15,
                          color: Colors.amberAccent,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _lastAwardedCredits > 0
                                ? '+$_lastAwardedCredits Credits Awarded for Correct Answers!'
                                : 'Total Earned on Quiz: +${ref.watch(quizScoreHistoryProvider)[widget.quiz.id]?.creditsEarned ?? correct} Credits',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.secondary,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _resetQuiz,
                child: const Text(
                  'Retake',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// ADMIN QUIZ BUILDER & NOTEBOOKLM IMPORTER SCREEN
// ===========================================================================

class _QuizEditorScreen extends ConsumerStatefulWidget {
  final List<SubjectModel> subjects;
  final QuizModel? existing;

  const _QuizEditorScreen({
    required this.subjects,
    this.existing,
  });

  @override
  ConsumerState<_QuizEditorScreen> createState() => _QuizEditorScreenState();
}

class _QuizEditorScreenState extends ConsumerState<_QuizEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _pasteCtrl;
  late String _selectedSubjectId;
  late List<QuizQuestionModel> _questions;

  bool _isPullingUrl = false;
  bool _isSaving = false;
  String? _importStatusMessage;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _titleCtrl = TextEditingController(text: ex?.title ?? '');
    _descCtrl = TextEditingController(text: ex?.description ?? '');
    _urlCtrl = TextEditingController(text: ex?.sourceUrl ?? '');
    _pasteCtrl = TextEditingController();
    _selectedSubjectId = ex?.subjectId ??
        (widget.subjects.isNotEmpty
            ? widget.subjects.first.id
            : '11111111-1111-1111-1111-111111111111');
    _questions = ex != null
        ? List<QuizQuestionModel>.from(ex.questions)
        : <QuizQuestionModel>[];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    _pasteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pullFromNotebookLmUrl() async {
    final rawUrl = _urlCtrl.text.trim();
    if (rawUrl.isEmpty) return;

    setState(() {
      _isPullingUrl = true;
      _importStatusMessage = null;
    });

    final result = await QuizImportService.importFromUrl(rawUrl);
    if (!mounted) return;

    setState(() {
      _isPullingUrl = false;
      _importStatusMessage = result.message;
      if (_titleCtrl.text.trim().isEmpty && result.title != null) {
        _titleCtrl.text = result.title!;
      }
      if (_descCtrl.text.trim().isEmpty && result.description != null) {
        _descCtrl.text = result.description!;
      }
      if (result.questions.isNotEmpty) {
        _questions = [..._questions, ...result.questions];
      }
    });
  }

  void _parsePastedQuestions() {
    final raw = _pasteCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste your NotebookLM quiz text or JSON first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final extracted = QuizImportService.parseQuizContent(raw);
    if (extracted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not detect MCQs. Format questions with options A) B) C) D) and Answer: B, or paste JSON.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _questions = [..._questions, ...extracted];
      _pasteCtrl.clear();
      _importStatusMessage =
          'Extracted and added ${extracted.length} MCQ questions!';
    });
  }

  Future<void> _addOrEditQuestionDialog({
    QuizQuestionModel? existing,
    int? index,
  }) async {
    final qCtrl = TextEditingController(text: existing?.question ?? '');
    final optCtrls = List.generate(
      4,
      (i) => TextEditingController(
        text: existing != null && i < existing.options.length
            ? existing.options[i]
            : '',
      ),
    );
    final expCtrl = TextEditingController(text: existing?.explanation ?? '');
    final hintCtrl = TextEditingController(text: existing?.hint ?? '');
    int correctIdx = existing?.correctOptionIndex ?? 0;

    final saved = await showDialog<QuizQuestionModel>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add MCQ Question' : 'Edit Question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: qCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Question Stem *',
                    hintText: 'Enter the question...',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Options (tap radio button to mark the Correct Answer):',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                ...List.generate(4, (i) {
                  final letter = String.fromCharCode(65 + i);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: i,
                          // ignore: deprecated_member_use
                          groupValue: correctIdx,
                          // ignore: deprecated_member_use
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => correctIdx = v);
                            }
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: optCtrls[i],
                            decoration: InputDecoration(
                              labelText: 'Option $letter',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: expCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Explanation / Rationale (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: hintCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Hint (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final qText = qCtrl.text.trim();
                final opts = optCtrls
                    .map((c) => c.text.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();
                if (qText.isEmpty || opts.length < 2) return;
                Navigator.pop(
                  ctx,
                  QuizQuestionModel(
                    id: existing?.id ??
                        'q_${DateTime.now().microsecondsSinceEpoch}',
                    question: qText,
                    options: opts,
                    correctOptionIndex: correctIdx.clamp(0, opts.length - 1),
                    explanation: expCtrl.text.trim().isNotEmpty
                        ? expCtrl.text.trim()
                        : null,
                    hint: hintCtrl.text.trim().isNotEmpty
                        ? hintCtrl.text.trim()
                        : null,
                  ),
                );
              },
              child: const Text('Save Question'),
            ),
          ],
        ),
      ),
    );

    if (saved != null) {
      setState(() {
        if (index != null) {
          _questions[index] = saved;
        } else {
          _questions.add(saved);
        }
      });
    }
  }

  Future<void> _saveQuiz() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Quiz Title.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // If the admin pasted text/JSON in Step 2 and tapped "Publish Quiz" directly
    // without tapping "Auto-Extract & Add MCQs" first, auto-extract it for them!
    if (_pasteCtrl.text.trim().isNotEmpty) {
      final autoExtracted =
          QuizImportService.parseQuizContent(_pasteCtrl.text.trim());
      if (autoExtracted.isNotEmpty) {
        _questions = [..._questions, ...autoExtracted];
        _pasteCtrl.clear();
      }
    }

    if (_questions.isEmpty && _urlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least 1 MCQ question or provide a Quiz / NotebookLM URL.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final user = ref.read(currentUserProvider);
    final quiz = QuizModel(
      id: widget.existing?.id ?? UuidUtil.generate(),
      subjectId: _selectedSubjectId,
      title: title,
      description: _descCtrl.text.trim(),
      sourceUrl:
          _urlCtrl.text.trim().isNotEmpty ? _urlCtrl.text.trim() : null,
      questions: _questions,
      createdBy: user.name.isNotEmpty ? user.name : 'Admin',
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    final err = await ref.read(quizzesProvider.notifier).saveQuiz(quiz);
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err == null
              ? 'Quiz published & synced to all students!'
              : 'Saved locally ($err)',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.existing == null
              ? 'Add / Import NotebookLM Quiz'
              : 'Edit Quiz (${_questions.length} MCQs)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveQuiz,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 17),
              label: const Text(
                'Publish Quiz',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
        children: [
          // 1. NotebookLM Link Importer Card
          Container(
            padding: const EdgeInsets.all(16),
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
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Step 1: NotebookLM Link & Quiz Info',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: widget.subjects.any(
                    (s) =>
                        s.id == _selectedSubjectId ||
                        UuidUtil.fromString(s.id) ==
                            UuidUtil.fromString(_selectedSubjectId),
                  )
                      ? widget.subjects
                          .firstWhere(
                            (s) =>
                                s.id == _selectedSubjectId ||
                                UuidUtil.fromString(s.id) ==
                                    UuidUtil.fromString(_selectedSubjectId),
                          )
                          .id
                      : (widget.subjects.isNotEmpty
                          ? widget.subjects.first.id
                          : null),
                  decoration: const InputDecoration(
                    labelText: 'Course / Subject',
                    prefixIcon: Icon(Icons.menu_book_rounded, size: 19),
                  ),
                  items: widget.subjects
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.code} — ${s.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedSubjectId = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Quiz Title *',
                    hintText: 'e.g. Midterm OOP NotebookLM Quiz #1',
                    prefixIcon: Icon(Icons.title_rounded, size: 19),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Short Description (optional)',
                    hintText: 'Topics covered or instructions for students',
                    prefixIcon: Icon(Icons.notes_rounded, size: 19),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    labelText: 'NotebookLM Share Link / Quiz URL',
                    hintText: 'https://notebooklm.link.google/ELuWPoJL1iNe',
                    prefixIcon: const Icon(Icons.link_rounded, size: 19),
                    suffixIcon: IconButton(
                      tooltip: 'Open Link in Browser',
                      onPressed: () {
                        if (_urlCtrl.text.trim().isNotEmpty) {
                          Formatters.launchMeetingUrl(
                            context,
                            _urlCtrl.text.trim(),
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isPullingUrl ? null : _pullFromNotebookLmUrl,
                        icon: _isPullingUrl
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.cloud_download_outlined,
                                size: 17,
                              ),
                        label: const Text(
                          'Pull from Link',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            const ClipboardData(
                              text: QuizImportService.notebookLmExportPrompt,
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Copied NotebookLM Export Prompt! Paste it inside NotebookLM chat to get instant JSON.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_all_rounded, size: 17),
                        label: const Text(
                          'Copy AI Prompt',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_importStatusMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _importStatusMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Smart Auto-Parser Card (Paste NotebookLM Text / Markdown / JSON)
          Container(
            padding: const EdgeInsets.all(16),
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
                    Icon(
                      Icons.content_paste_go_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Step 2: Smart Paste MCQs (Text, Markdown, or JSON)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Paste questions copied from NotebookLM, or JSON exported using the AI Prompt above. Our parser automatically detects questions, options (A–D), correct answers, and explanations.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pasteCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText:
                        '1. What is polymorphism?\nA) Code reuse\nB) Many forms\nC) Data hiding\nD) Memory allocation\nAnswer: B\nExplanation: Polymorphism allows objects to take many forms.',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _parsePastedQuestions,
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 17),
                    label: const Text(
                      'Auto-Extract & Add MCQs',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Questions Builder List
          Row(
            children: [
              Text(
                'Questions in this Quiz (${_questions.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addOrEditQuestionDialog(),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text(
                  'Add Question Manually',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_questions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  'No questions added yet. Use Smart Paste above or tap "Add Question Manually".',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...List.generate(_questions.length, (idx) {
              final q = _questions[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Q${idx + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _addOrEditQuestionDialog(
                              existing: q,
                              index: idx,
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                setState(() => _questions.removeAt(idx)),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        q.question,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...List.generate(q.options.length, (optIdx) {
                        final isCorrect = optIdx == q.correctOptionIndex;
                        final letter = String.fromCharCode(65 + optIdx);
                        return Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              Icon(
                                isCorrect
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 15,
                                color: isCorrect
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '$letter) ${q.options[optIdx]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isCorrect
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: isCorrect
                                        ? AppColors.successText
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
