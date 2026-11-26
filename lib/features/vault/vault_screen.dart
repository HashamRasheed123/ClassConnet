import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/offline_document_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/google_drive_util.dart';
import '../../core/utils/uuid_util.dart';
import '../../models/models.dart';
import '../../providers/class_providers.dart';
import '../assignment_scanner/assignment_scanner_screen.dart';
import '../quizzes/quiz_center_screen.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  String? _selectedSubjectId;
  String _searchQuery = '';
  bool _showVideos = false; // false = Notes & Slides, true = Lecture Videos
  bool _onlyMyUploads = false; // Filter to show user's own contributions
  bool _onlyOfflineSaved = false; // Filter to show offline-cached documents
  final TextEditingController _searchCtrl = TextEditingController();

  void _onOfflineCacheChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    OfflineDocumentService.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    OfflineDocumentService.instance.cacheVersionNotifier
        .addListener(_onOfflineCacheChanged);
  }

  @override
  void dispose() {
    OfflineDocumentService.instance.cacheVersionNotifier
        .removeListener(_onOfflineCacheChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider);
    final allResources = ref.watch(resourcesProvider);
    final user = ref.watch(currentUserProvider);
    final likedIds = ref.watch(likedResourcesProvider);

    final myUploadsCount =
        allResources.where((r) => r.uploaderId == user.id).length;
    final offlineSavedCount = allResources
        .where((r) =>
            r.type != ResourceType.youtube &&
            OfflineDocumentService.instance.peekCachedEntry(r.url) != null)
        .length;

    // Filter only approved resources (or uploaded by current user)
    final filtered = allResources.where((r) {
      if (!r.isApproved && r.uploaderId != user.id) return false;

      // Only my uploads filter
      if (_onlyMyUploads && r.uploaderId != user.id) return false;

      // Offline saved filter
      if (_onlyOfflineSaved &&
          OfflineDocumentService.instance.peekCachedEntry(r.url) == null) {
        return false;
      }

      // Type filter
      if (_showVideos && r.type != ResourceType.youtube) return false;
      if (!_showVideos && r.type == ResourceType.youtube) return false;

      // Subject filter (with normalized UUID resolution)
      if (_selectedSubjectId != null &&
          r.subjectId != _selectedSubjectId &&
          UuidUtil.fromString(r.subjectId) !=
              UuidUtil.fromString(_selectedSubjectId!)) {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty &&
          !r.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Academic Vault'),
        actions: [
          IconButton(
            tooltip: 'MCQ Quizzes & Practice Tests',
            icon: const Icon(
              Icons.psychology_alt_rounded,
              color: AppColors.primary,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuizCenterScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Assignment PDF Maker (Offline)',
            icon: const Icon(Icons.document_scanner_rounded,
                color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AssignmentScannerScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${user.credits} Credits',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: user.isAdmin
          ? FloatingActionButton.extended(
              heroTag: null,
              backgroundColor: AppColors.primary,
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onPressed: () => showUploadModal(context, ref),
              icon: const Icon(
                Icons.cloud_upload_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'Upload Resource',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Student Academic Vault Banner (Read-Only Mode for students)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      user.isAdmin ? Icons.cloud_upload_rounded : Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.isAdmin
                              ? 'Admin Resource Center'
                              : 'Academic Vault • Read & Learn',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          user.isAdmin
                              ? 'Upload PDFs, slides or materials for students.'
                              : 'All verified notes, slides and past papers are free to read.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (user.isAdmin)
                    ElevatedButton.icon(
                      onPressed: () => showUploadModal(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text('Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_rounded, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Read Only',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search notes, slides, algorithms...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Type Segmented Toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F0F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTypeSegment(
                        label: '📄 Notes & Slides',
                        isSelected: !_showVideos,
                        onTap: () => setState(() => _showVideos = false),
                      ),
                    ),
                    Expanded(
                      child: _buildTypeSegment(
                        label: '▶️ Lecture Videos',
                        isSelected: _showVideos,
                        onTap: () => setState(() => _showVideos = true),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Subject & Contribution Filter Chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  ChoiceChip(
                    label: const Text('All Resources'),
                    selected: _selectedSubjectId == null &&
                        !_onlyMyUploads &&
                        !_onlyOfflineSaved,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedSubjectId = null;
                          _onlyMyUploads = false;
                          _onlyOfflineSaved = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),

                  // Offline Saved Chip
                  ChoiceChip(
                    avatar: Icon(
                      Icons.offline_pin_rounded,
                      size: 14,
                      color: _onlyOfflineSaved
                          ? Colors.white
                          : const Color(0xFF059669),
                    ),
                    label: Text('Offline Saved ($offlineSavedCount)'),
                    selected: _onlyOfflineSaved,
                    selectedColor: const Color(0xFF059669),
                    labelStyle: TextStyle(
                      color: _onlyOfflineSaved
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (val) {
                      setState(() {
                        _onlyOfflineSaved = val;
                        if (val) _onlyMyUploads = false;
                      });
                    },
                  ),
                  const SizedBox(width: 8),

                  // My Uploads Chip
                  ChoiceChip(
                    avatar: const Text('⚡', style: TextStyle(fontSize: 12)),
                    label: Text('My Uploads ($myUploadsCount)'),
                    selected: _onlyMyUploads,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _onlyMyUploads ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (val) {
                      setState(() {
                        _onlyMyUploads = val;
                        if (val) _onlyOfflineSaved = false;
                      });
                    },
                  ),
                  const SizedBox(width: 8),

                  for (final sub in subjects) ...[
                    ChoiceChip(
                      label: Text(sub.code),
                      selected: _selectedSubjectId == sub.id &&
                          !_onlyMyUploads &&
                          !_onlyOfflineSaved,
                      onSelected: (val) {
                        setState(() {
                          _selectedSubjectId = val ? sub.id : null;
                          _onlyMyUploads = false;
                          _onlyOfflineSaved = false;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Resources List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.upload_file_rounded,
                                  size: 40, color: AppColors.primary),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _onlyMyUploads
                                  ? 'No notes uploaded by you yet.'
                                  : 'No resources found in this category.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              user.isAdmin
                                  ? 'Upload course slides, past papers, or notes for your class.'
                                  : 'Course materials and lecture notes will appear here once published.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            if (user.isAdmin) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => showUploadModal(context, ref),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Upload Resource'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final res = filtered[index];
                        final sub = subjects.firstWhere(
                          (s) => s.id == res.subjectId,
                          orElse: () => subjects.first,
                        );

                        final isLiked = likedIds.contains(res.id);
                        return _ResourceCard(
                          resource: res,
                          subject: sub,
                          isMyUpload: res.uploaderId == user.id,
                          isLiked: isLiked,
                          onUnlock: () => _handleUnlock(res),
                          onUpvote: () {
                            final nowLiked = ref
                                .read(likedResourcesProvider.notifier)
                                .toggleLike(res.id);
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  nowLiked
                                      ? 'Appreciated "${res.title}" (+5 ⚡)'
                                      : 'Removed appreciation (-5 ⚡)',
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSegment({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  void _handleUnlock(ResourceModel res) async {
    final user = ref.read(currentUserProvider);

    // If it's the user's own upload or already unlocked
    if (res.isUnlocked || res.uploaderId == user.id) {
      await _openOrCacheResource(res);
      return;
    }

    final success =
        ref.read(resourcesProvider.notifier).unlockResource(res.id);

    if (success) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening "${res.title}"...'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
    await _openOrCacheResource(res);
  }

  Future<void> _openOrCacheResource(ResourceModel res) async {
    if (res.type == ResourceType.youtube) {
      await _openResourceUrl(res.url);
      return;
    }
    await OfflineDocumentService.instance.openOrDownloadDocument(
      context,
      url: res.url,
      title: res.title,
      onCacheUpdated: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _openResourceUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Could not launch $url: $e');
      }
    }
  }
}

// ===================================================================
// RESOURCE CARD WITH UPVOTES & PAYWALL LOCK
// ===================================================================

class _ResourceCard extends StatelessWidget {
  final ResourceModel resource;
  final SubjectModel subject;
  final bool isMyUpload;
  final bool isLiked;
  final VoidCallback onUnlock;
  final VoidCallback onUpvote;

  const _ResourceCard({
    required this.resource,
    required this.subject,
    required this.isMyUpload,
    required this.isLiked,
    required this.onUnlock,
    required this.onUpvote,
  });

  @override
  Widget build(BuildContext context) {
    final res = resource;
    final isLocked = !res.isUnlocked && !isMyUpload;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMyUpload
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onUnlock,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Subject code + Type Badge + Status/Unlock Pill
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: subject.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        subject.code,
                        style: TextStyle(
                          color: subject.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(res.type.icon, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      res.type.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),

                    if (isMyUpload)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: res.isApproved
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              res.isApproved
                                  ? Icons.check_circle_rounded
                                  : Icons.hourglass_top_rounded,
                              size: 11,
                              color: res.isApproved
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              res.isApproved
                                  ? 'My Upload • Live'
                                  : 'My Upload • Reviewing',
                              style: TextStyle(
                                color: res.isApproved
                                    ? AppColors.success
                                    : AppColors.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLocked
                                  ? Icons.menu_book_rounded
                                  : Icons.lock_open_rounded,
                              size: 11,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isLocked ? 'Free Read' : 'Unlocked',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  res.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),

                // Offline Storage Status Row (for PDFs and Images)
                if (res.type != ResourceType.youtube) ...[
                  Builder(
                    builder: (context) {
                      final isFolder =
                          GoogleDriveUtil.isGoogleDriveFolder(res.url);
                      if (isFolder) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_shared_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Google Drive Folder • Tap to Open & Browse Files',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final cached = OfflineDocumentService.instance
                          .peekCachedEntry(res.url);
                      final isCached = cached != null;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCached
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCached
                                ? const Color(0xFFA7F3D0)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCached
                                  ? Icons.offline_pin_rounded
                                  : Icons.download_for_offline_outlined,
                              size: 14,
                              color: isCached
                                  ? const Color(0xFF059669)
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                isCached
                                    ? 'Offline Ready (${cached.formattedSize}) • Tap to Open Instantly'
                                    : 'Tap to Download & Save for Offline Access',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isCached
                                      ? const Color(0xFF065F46)
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Bottom row: Uploader name + Upvotes
                Row(
                  children: [
                    const Icon(Icons.account_circle_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      isMyUpload
                          ? 'Uploaded by You (+50 ⚡)'
                          : 'Shared by ${res.uploaderName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isMyUpload ? FontWeight.w700 : FontWeight.w500,
                        color: isMyUpload
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    // Upvote button (Single like per document, toggleable)
                    InkWell(
                      onTap: onUpvote,
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLiked
                              ? AppColors.primary
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.thumb_up_alt_rounded
                                  : Icons.thumb_up_alt_outlined,
                              size: 12,
                              color: isLiked ? Colors.white : AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${res.upvotes}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color:
                                    isLiked ? Colors.white : AppColors.primary,
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
      ),
    );
  }
}

// ===================================================================
// INTERACTIVE UPLOAD NOTE / DOCUMENT MODAL (STUDENT DATA CONTRIBUTION)
// ===================================================================

void showUploadModal(BuildContext context, WidgetRef ref) {
  final user = ref.read(currentUserProvider);
  if (!user.isAdmin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Uploads Disabled', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Student uploads are temporarily paused. You have full read-only access to all verified notes, slides, timetable, and assignments!\n\nCommunity uploads and contributor rewards will be enabled in an upcoming release.',
          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
    return;
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _UploadModalSheet(),
  );
}

void showUploaderVerificationGate(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _UploaderVerificationGateSheet(),
  );
}

class _UploaderVerificationGateSheet extends ConsumerStatefulWidget {
  const _UploaderVerificationGateSheet();

  @override
  ConsumerState<_UploaderVerificationGateSheet> createState() =>
      _UploaderVerificationGateSheetState();
}

class _UploaderVerificationGateSheetState
    extends ConsumerState<_UploaderVerificationGateSheet> {
  final _rollCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameCtrl.text = user.name;
    if (user.rollNo != null && user.rollNo!.isNotEmpty) {
      _rollCtrl.text = user.rollNo!;
    }
  }

  @override
  void dispose() {
    _rollCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final roll = _rollCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    if (roll.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both your Full Name and Roll Number.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ref
        .read(currentUserProvider.notifier)
        .submitUploaderRequest(rollNo: roll, name: name);
    setState(() => _isSubmitting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor:
              result.success ? AppColors.textPrimary : AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (result.success) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isPending = user.uploadRequestStatus == 'pending';
    final isRejected = user.uploadRequestStatus == 'rejected';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPending
                          ? const Color(0xFFFEF3C7)
                          : (isRejected
                              ? const Color(0xFFFEE2E2)
                              : AppColors.primarySoft),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPending
                          ? Icons.hourglass_top_rounded
                          : (isRejected
                              ? Icons.gpp_bad_rounded
                              : Icons.verified_user_rounded),
                      color: isPending
                          ? const Color(0xFFD97706)
                          : (isRejected ? AppColors.danger : AppColors.primary),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPending
                              ? 'Verification Pending Review'
                              : (isRejected
                                  ? 'Verification Declined'
                                  : 'Contributor Authorization'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          isPending
                              ? 'Awaiting Administrator Approval'
                              : 'Admin review required to post notes',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (isPending) ...[
                // STATUS PENDING CARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.pending_actions_rounded,
                              size: 18, color: Color(0xFFD97706)),
                          SizedBox(width: 8),
                          Text(
                            'Request Under Review',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your posting request has been submitted for Google account (${user.email}).',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF78350F), height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Name:',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary)),
                                Text(user.name,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Roll Number:',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary)),
                                Text(user.rollNo ?? 'Not Set',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text('Verification Status:',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary)),
                                Text('Pending Admin Approval',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFD97706))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Got It, I Will Wait'),
                ),
              ] else if (isRejected) ...[
                // STATUS REJECTED CARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.error_outline_rounded,
                              size: 18, color: AppColors.danger),
                          SizedBox(width: 8),
                          Text(
                            'Request Not Approved',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your verification request for Roll No ${user.rollNo ?? ''} was not verified by the administrator.',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF7F1D1D), height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Contact your Class Representative or administrator for authorization.',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close'),
                ),
              ] else ...[
                // REQUEST SUBMISSION FORM
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle_rounded,
                          size: 28, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              user.email,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '1 Request / Account',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Full Name *',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. John Doe',
                    prefixIcon:
                        const Icon(Icons.person_outline_rounded, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border)),
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  'Academic Roll Number *',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _rollCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'e.g. 23-SE-402',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border)),
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Notice: You can only submit 1 verification request per Google account. Administrators will verify your Roll No against the class roster.',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF92400E),
                              height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: Color(0xFFDC2626)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Academic Policy: Authorized uploaders must NEVER upload personal, private, or sensitive documents. Vault is strictly for course materials.',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF991B1B),
                              height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isSubmitting
                          ? 'Submitting Request...'
                          : 'Submit Request to Admin',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
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

class _UploadModalSheet extends ConsumerStatefulWidget {
  const _UploadModalSheet();

  @override
  ConsumerState<_UploadModalSheet> createState() => _UploadModalSheetState();
}

class _UploadModalSheetState extends ConsumerState<_UploadModalSheet> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  String? _selectedSubjectId;
  ResourceType _selectedType = ResourceType.pdf;

  PlatformFile? _pickedFile;
  int? _pickedFileSize;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFileFromDevice() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _selectedType == ResourceType.pdf
            ? ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt']
            : ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final fileSize = file.lengthSync() ?? await file.length();
        setState(() {
          _pickedFile = file;
          _pickedFileSize = fileSize;
          // Auto-fill title if empty
          if (_titleCtrl.text.trim().isEmpty) {
            final cleanName = file.name
                .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
                .replaceAll('_', ' ')
                .replaceAll('-', ' ');
            _titleCtrl.text = cleanName;
          }
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('File picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e')),
        );
      }
    }
  }

  void _submitUpload() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a note / topic title')),
      );
      return;
    }

    if (_selectedType != ResourceType.youtube &&
        _pickedFile == null &&
        _urlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a file from your device or enter a URL.')),
      );
      return;
    }

    final subjects = ref.read(subjectsProvider);
    final user = ref.read(currentUserProvider);
    final subjectId = _selectedSubjectId ?? subjects.first.id;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.2;
    });

    // Realistic upload feedback simulation
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) setState(() => _uploadProgress = 0.65);
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) setState(() => _uploadProgress = 1.0);

    final finalUrl = _urlCtrl.text.trim().isNotEmpty
        ? _urlCtrl.text.trim()
        : (_pickedFile != null
            ? 'local://vault/${UuidUtil.generate()}_${_pickedFile!.name}'
            : 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf');

    // If a file was picked from device storage, persist a local copy in OfflineDocumentService
    // so it opens offline immediately and never triggers "File Not Found".
    if (_pickedFile?.path != null && _pickedFile!.path!.isNotEmpty) {
      await OfflineDocumentService.instance.importLocalFile(
        sourceFilePath: _pickedFile!.path!,
        urlKey: finalUrl,
        title: title,
      );
    }

    final error = ref.read(resourcesProvider.notifier).submitResource(
          subjectId: subjectId,
          title: title,
          type: _selectedType,
          url: finalUrl,
          uploaderName: user.name,
          uploaderId: user.id,
        );

    setState(() => _isUploading = false);

    if (error != null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.link_off_rounded, color: AppColors.danger),
                SizedBox(width: 8),
                Text('Duplicate Link Blocked', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            content: Text(
              error,
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
      }
      return;
    }

    HapticFeedback.mediumImpact();

    if (!mounted) return;
    Navigator.of(context).pop();

    // Celebration Dialog for student contribution
    _showContributionCelebrationDialog(context, title);
  }

  void _showContributionCelebrationDialog(
      BuildContext context, String noteTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.warning.withValues(alpha: 0.3),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Text('⚡', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 16),
            const Text(
              '+50 Thunderbolts Credited!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your note "$noteTitle" has been successfully uploaded to the Academic Vault.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'You have instant unlocked access to your contribution under "My Uploads".',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Awesome, Done!',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider);

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
                const Text(
                  'Upload Study Material',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: const [
                      Text('⚡', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 3),
                      Text(
                        '+50 REWARD',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Select lecture notes or exam sheets from your device storage to earn credits.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            // Strict Personal Safety Warning Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Academic Safety: Do NOT upload personal documents or private photos. Only upload lecture notes, slides & study guides.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Material Type Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('PDF Document'),
                    selected: _selectedType == ResourceType.pdf,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedType = ResourceType.pdf;
                          _pickedFile = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.image_rounded, size: 16),
                    label: const Text('Handwritten Slides/Image'),
                    selected: _selectedType == ResourceType.image,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedType = ResourceType.image;
                          _pickedFile = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar:
                        const Icon(Icons.play_circle_filled_rounded, size: 16),
                    label: const Text('YouTube Stream'),
                    selected: _selectedType == ResourceType.youtube,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedType = ResourceType.youtube;
                          _pickedFile = null;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Course / Subject selector
            const Text(
              'Target Course',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
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
                  value: (subjects.any((s) => s.id == _selectedSubjectId))
                      ? _selectedSubjectId
                      : (subjects.isNotEmpty ? subjects.first.id : null),
                  isExpanded: true,
                  items: subjects
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: s.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${s.code} - ${s.name}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _selectedSubjectId = val),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Device File Picker for PDFs and Images
            if (_selectedType != ResourceType.youtube) ...[
              const Text(
                'Upload Document from Device',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),

              if (_pickedFile == null)
                InkWell(
                  onTap: _pickFileFromDevice,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cloud_upload_rounded,
                              color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _selectedType == ResourceType.pdf
                              ? 'Browse & Select PDF Note'
                              : 'Browse & Select Note Photos / Slides',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap to choose file from storage (up to 50MB)',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
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
                        child: Icon(
                          _selectedType == ResourceType.pdf
                              ? Icons.picture_as_pdf_rounded
                              : Icons.image_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pickedFile!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${((_pickedFileSize ?? 0) / (1024 * 1024)).toStringAsFixed(2)} MB • Ready to upload',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Change file',
                        icon: const Icon(Icons.refresh_rounded,
                            size: 20, color: AppColors.textSecondary),
                        onPressed: _pickFileFromDevice,
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close_rounded,
                            size: 20, color: AppColors.danger),
                        onPressed: () => setState(() => _pickedFile = null),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
            ],

            // Title field
            const Text(
              'Title / Topic Description',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: 'e.g., Dynamic Programming & Tree Traversal Summary',
                prefixIcon: const Icon(Icons.title_rounded, size: 20),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Link field (Optional for files, Required for YouTube)
            if (_selectedType == ResourceType.youtube || _pickedFile == null) ...[
              Text(
                _selectedType == ResourceType.youtube
                    ? 'YouTube Video Link'
                    : 'Alternative Cloud Link / Drive URL (Optional)',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _urlCtrl,
                decoration: InputDecoration(
                  hintText: _selectedType == ResourceType.youtube
                      ? 'https://www.youtube.com/watch?v=...'
                      : 'https://drive.google.com/...',
                  prefixIcon: const Icon(Icons.link_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Upload Progress Bar
            if (_isUploading) ...[
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: AppColors.primarySoft,
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Uploading notes to Academic Vault... ${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submitUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Publish Notes & Claim +50 ⚡',
                  style: TextStyle(
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
  }
}
