import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import '../../core/services/assignment_pdf_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/class_providers.dart';

class AssignmentScannerScreen extends ConsumerStatefulWidget {
  final AssignmentModel? initialAssignment;

  const AssignmentScannerScreen({
    super.key,
    this.initialAssignment,
  });

  @override
  ConsumerState<AssignmentScannerScreen> createState() =>
      _AssignmentScannerScreenState();
}

class _AssignmentScannerScreenState
    extends ConsumerState<AssignmentScannerScreen> {
  late final TextEditingController _titleCtrl;
  ImagePicker? _lazyPicker;
  ImagePicker get _imagePicker => _lazyPicker ??= ImagePicker();

  AssignmentModel? _linkedAssignment;
  String? _selectedSubject;
  final List<AssignmentPhoto> _photos = [];
  bool _isProcessingImage = false;
  bool _isGeneratingPdf = false;
  Uint8List? _generatedPdfBytes;

  @override
  void initState() {
    super.initState();
    _linkedAssignment = widget.initialAssignment;
    _titleCtrl = TextEditingController(
      text: widget.initialAssignment?.title ?? 'Lab Assignment 1',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final subjects = ref.read(subjectsProvider);
      if (_linkedAssignment != null) {
        final sub = resolveSubjectById(subjects, _linkedAssignment!.subjectId);
        if (sub != null) {
          setState(() {
            _selectedSubject = '${sub.code} - ${sub.name}';
          });
        }
      } else {
        // Auto-select first pending assignment if available
        final completed = ref.read(assignmentCompletionProvider);
        final pending = ref
            .read(assignmentsProvider)
            .where((a) => !completed.contains(a.id))
            .toList();
        if (pending.isNotEmpty) {
          _applyAssignmentSelection(pending.first, subjects);
        }
      }
    });
  }

  void _applyAssignmentSelection(
      AssignmentModel assignment, List<SubjectModel> subjects) {
    final sub = resolveSubjectById(subjects, assignment.subjectId);
    setState(() {
      _linkedAssignment = assignment;
      _titleCtrl.text = assignment.title;
      if (sub != null) {
        _selectedSubject = '${sub.code} - ${sub.name}';
      }
      _generatedPdfBytes = null;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // IMAGE CAPTURE ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _captureSinglePhoto(ImageSource source) async {
    try {
      setState(() => _isProcessingImage = true);
      final xfile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (xfile != null) {
        final bytes = await xfile.readAsBytes();
        final photo = await AssignmentPdfService.processImage(
          path: xfile.path,
          bytes: bytes,
        );
        setState(() {
          _photos.add(photo);
          _generatedPdfBytes = null; // Invalidate previously built PDF
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
      if (mounted) {
        _showPermissionOrDeviceDialog(e.toString());
      }
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  void _showPermissionOrDeviceDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.photo_camera_rounded,
                color: AppColors.warning, size: 24),
            SizedBox(width: 10),
            Text('Camera / Image Access',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Could not open camera on this device. If camera access is restricted or not available, you can choose assignment pages directly from your Gallery or Files.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Detail: $error',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _pickMultipleFromGallery();
            },
            icon: const Icon(Icons.photo_library_rounded, size: 16),
            label: const Text('Pick from Gallery'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  /// Multi-snap mode: snaps a photo and immediately asks if user wants to snap another
  Future<void> _multiSnapCamera() async {
    bool keepSnapping = true;
    int snappedCount = 0;

    while (keepSnapping && mounted) {
      try {
        final xfile = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
        );

        if (xfile == null) {
          keepSnapping = false;
          break;
        }

        final bytes = await xfile.readAsBytes();
        final photo = await AssignmentPdfService.processImage(
          path: xfile.path,
          bytes: bytes,
        );

        setState(() {
          _photos.add(photo);
        });
        snappedCount++;
        HapticFeedback.mediumImpact();

        if (!mounted) break;

        // Ask user if they want to capture the next page
        final next = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 24),
                const SizedBox(width: 8),
                Text('Page ${_photos.length} Added!'),
              ],
            ),
            content: Text(
              'Total ${_photos.length} pages captured so far.\nWould you like to snap the next page now?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Done Scanning'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                label: const Text('Snap Next Page'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
              ),
            ],
          ),
        );

        if (next != true) {
          keepSnapping = false;
        }
      } catch (e) {
        keepSnapping = false;
        _showSnackbar('Camera error: $e', isError: true);
      }
    }

    if (snappedCount > 0 && mounted) {
      _showSnackbar('Added $snappedCount pages to assignment.');
    }
  }

  Future<void> _pickMultipleFromGallery() async {
    try {
      setState(() => _isProcessingImage = true);
      final xfiles = await _imagePicker.pickMultiImage(imageQuality: 90);

      if (xfiles.isNotEmpty) {
        for (final xfile in xfiles) {
          final bytes = await xfile.readAsBytes();
          final photo = await AssignmentPdfService.processImage(
            path: xfile.path,
            bytes: bytes,
          );
          _photos.add(photo);
        }
        setState(() {
          _generatedPdfBytes = null;
        });
        HapticFeedback.lightImpact();
        _showSnackbar('Added ${xfiles.length} images.');
      }
    } catch (e) {
      _showSnackbar('Error selecting images: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  // ---------------------------------------------------------------------------
  // PAGE REORDERING & EDITING
  // ---------------------------------------------------------------------------

  void _movePhoto(int oldIndex, int newIndex) {
    setState(() {
      final photo = _photos.removeAt(oldIndex);
      _photos.insert(newIndex, photo);
      _generatedPdfBytes = null;
    });
    HapticFeedback.selectionClick();
  }

  void _rotatePhoto(int index) {
    setState(() {
      _photos[index].rotationDegrees =
          (_photos[index].rotationDegrees + 90) % 360;
      _generatedPdfBytes = null;
    });
    HapticFeedback.lightImpact();
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      _generatedPdfBytes = null;
    });
    HapticFeedback.mediumImpact();
  }

  // ---------------------------------------------------------------------------
  // PDF GENERATION & ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _buildPdf() async {
    if (_photos.isEmpty) {
      _showSnackbar('Please take or select at least 1 photo first!',
          isError: true);
      return;
    }

    final user = ref.read(currentUserProvider);
    final title = _titleCtrl.text.trim().isEmpty
        ? 'Assignment Submission'
        : _titleCtrl.text.trim();
    final studentName = user.name.trim().isEmpty ? 'Student' : user.name.trim();
    final rollNo = (user.rollNo?.trim().isEmpty ?? true)
        ? 'N/A'
        : user.rollNo!.trim();

    if (_generatedPdfBytes != null) {
      _openPdfPreviewSheet(_generatedPdfBytes!, title, studentName, rollNo);
      return;
    }

    setState(() => _isGeneratingPdf = true);

    try {
      final pdfBytes = await AssignmentPdfService.generateAssignmentPdf(
        assignmentTitle: title,
        studentName: studentName,
        rollNumber: rollNo,
        photos: _photos,
        subjectName: _selectedSubject,
      );

      setState(() {
        _generatedPdfBytes = pdfBytes;
      });

      if (mounted) {
        _openPdfPreviewSheet(pdfBytes, title, studentName, rollNo);
      }
    } catch (e) {
      _showSnackbar('Failed to compile PDF: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _openPdfPreviewSheet(
    Uint8List pdfBytes,
    String title,
    String studentName,
    String rollNo,
  ) {
    final sanitizedFileName =
        '${title}_$rollNo'.replaceAll(RegExp(r'\s+'), '_');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Modal Handle
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded,
                            color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Student: $studentName • Roll: $rollNo • ${_photos.length} pages',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),

                // Privacy Indicator Banner
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFFF0FDF4),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_rounded,
                          size: 14, color: AppColors.success),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '100% Offline & Private: Processed locally. No images uploaded.',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Interactive PDF Preview View
                Expanded(
                  child: PdfPreview(
                    build: (format) => pdfBytes,
                    useActions: false, // We provide custom styled actions
                    scrollViewDecoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                    ),
                  ),
                ),

                // Download, Share & Print Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await AssignmentPdfService.sharePdf(
                              pdfBytes: pdfBytes,
                              filename: sanitizedFileName,
                            );
                          },
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Share PDF'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            try {
                              final file =
                                  await AssignmentPdfService.savePdfLocally(
                                pdfBytes: pdfBytes,
                                filename: sanitizedFileName,
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              if (mounted) {
                                _showSaveSuccessDialog(file.path);
                              }
                            } catch (e) {
                              _showSnackbar('Save error: $e', isError: true);
                            }
                          },
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Download PDF'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSaveSuccessDialog(String path) {
    final linked = _linkedAssignment;
    final isAlreadyDone = linked != null &&
        ref.read(assignmentCompletionProvider).contains(linked.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 24),
            SizedBox(width: 10),
            Text('PDF Downloaded!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your assignment PDF was compiled and saved locally on your device storage:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                path,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (linked != null && !isAlreadyDone) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.task_alt_rounded,
                        size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Linked to "${linked.title}". Mark it completed in your Assignment Tracker?',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (linked != null && !isAlreadyDone)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
          if (linked != null && !isAlreadyDone)
            FilledButton.icon(
              onPressed: () {
                ref
                    .read(assignmentCompletionProvider.notifier)
                    .markCompleted(linked.id);
                Navigator.pop(ctx);
                _showSnackbar('Marked "${linked.title}" as completed!');
              },
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Mark Completed'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Great!'),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EDIT STUDENT IDENTITY DIALOG (One-time only, editable later)
  // ---------------------------------------------------------------------------

  void _openEditIdentityDialog() {
    final user = ref.read(currentUserProvider);
    final nameCtrl = TextEditingController(text: user.name);
    final rollCtrl = TextEditingController(text: user.rollNo ?? '');

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
              child: const Icon(Icons.badge_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Student Details',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This name and roll number will appear on all your generated assignment PDFs. It is saved locally on your device.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            const Text(
              'Student Name',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Rayyan',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Roll Number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: rollCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. 23-SE-402',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              final newRoll = rollCtrl.text.trim();
              if (newName.isNotEmpty) {
                ref.read(currentUserProvider.notifier).updateProfile(
                      name: newName,
                      rollNo: newRoll,
                    );
                Navigator.pop(ctx);
                setState(() => _generatedPdfBytes = null);
                _showSnackbar('Student details saved successfully!');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Details'),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD SCREEN UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    try {
      final user = ref.watch(currentUserProvider);
      final subjects = ref.watch(subjectsProvider);

      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Assignment PDF Maker',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Offline Document Scanner & Formatter',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            // Privacy badge
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lock_rounded, size: 12, color: AppColors.success),
                  SizedBox(width: 4),
                  Text(
                    '100% Local',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // 1. STUDENT IDENTITY CARD ("One time only, editable later")
            _buildStudentIdentityCard(user),

            const SizedBox(height: 16),

            // 2. ASSIGNMENT TITLE & SUBJECT
            _buildAssignmentDetailsCard(subjects),

            const SizedBox(height: 16),

            // 3. DOCUMENT CAPTURE ACTIONS (CAMERA / MULTI-SNAP / GALLERY)
            _buildCaptureActionBar(),

            const SizedBox(height: 16),

            // 4. PAGES PREVIEW & REORDER SECTION
            _buildPagesListSection(),
          ],
        ),

        // BOTTOM GENERATE & PREVIEW BAR
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_photos.length} ${_photos.length == 1 ? 'Page' : 'Pages'} Ready',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Text(
                        'Header + Auto Portrait/Landscape',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: (_photos.isEmpty || _isGeneratingPdf)
                      ? null
                      : _buildPdf,
                  icon: _isGeneratingPdf
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(
                    _isGeneratingPdf
                        ? 'Compiling...'
                        : (_generatedPdfBytes != null
                            ? 'View PDF'
                            : 'Create PDF'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e, stack) {
      debugPrint('Error in AssignmentScannerScreen: $e\n$stack');
      return Scaffold(
        appBar: AppBar(
          title: const Text('Assignment Scanner'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: AppColors.danger),
                const SizedBox(height: 12),
                Text(
                  'Diagnostic Error: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // WIDGET BUILDERS
  // ---------------------------------------------------------------------------

  Widget _buildStudentIdentityCard(UserModel user) {
    final rollNo = (user.rollNo?.trim().isNotEmpty ?? false)
        ? user.rollNo!
        : 'Not set yet (Tap edit)';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Details (Header Info)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Saved on device • Printed below assignment title',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _openEditIdentityDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.edit_rounded,
                          size: 13, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STUDENT NAME',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 26,
                  color: AppColors.border,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ROLL NUMBER',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rollNo,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentDetailsCard(List<SubjectModel> subjects) {
    final allAssignments = ref.watch(assignmentsProvider);
    final completedIds = ref.watch(assignmentCompletionProvider);
    final pendingAssignments =
        allAssignments.where((a) => !completedIds.contains(a.id)).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pendingAssignments.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.assignment_turned_in_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Link to Class Assignment (Auto-fills Title & Course):',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (_linkedAssignment != null)
                  InkWell(
                    onTap: () => setState(() => _linkedAssignment = null),
                    child: const Text(
                      'Unlink',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: pendingAssignments.map((a) {
                  final sub = resolveSubjectById(subjects, a.subjectId);
                  final isSelected = _linkedAssignment?.id == a.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        sub != null ? '${sub.code}: ${a.title}' : a.title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color:
                              isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      onSelected: (sel) {
                        if (sel) {
                          _applyAssignmentSelection(a, subjects);
                        } else {
                          setState(() => _linkedAssignment = null);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
          ],
          Row(
            children: const [
              Icon(Icons.title_rounded, size: 18, color: AppColors.textPrimary),
              SizedBox(width: 8),
              Text(
                'Assignment Title',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            onChanged: (_) => setState(() => _generatedPdfBytes = null),
            decoration: InputDecoration(
              hintText: 'e.g. Software Architecture - Assignment 2',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          // Subject Quick Selector
          if (subjects.isNotEmpty) ...[
            const Text(
              'Course / Subject (Optional):',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('None'),
                    selected: _selectedSubject == null,
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedSubject = null);
                    },
                  ),
                  const SizedBox(width: 6),
                  ...subjects.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(s.code),
                        selected: _selectedSubject == '${s.code} - ${s.name}',
                        onSelected: (sel) {
                          setState(() {
                            _selectedSubject =
                                sel ? '${s.code} - ${s.name}' : null;
                            _generatedPdfBytes = null;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCaptureActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_rounded,
                  size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              const Text(
                'Add Document Photos',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_isProcessingImage)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Single Photo from Camera
              Expanded(
                child: InkWell(
                  onTap: _isProcessingImage
                      ? null
                      : () => _captureSinglePhoto(ImageSource.camera),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.photo_camera_rounded,
                            size: 22, color: AppColors.primary),
                        SizedBox(height: 4),
                        Text(
                          'Camera',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Multi-Snap Camera Mode
              Expanded(
                child: InkWell(
                  onTap: _isProcessingImage ? null : _multiSnapCamera,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.burst_mode_rounded,
                            size: 22, color: AppColors.primary),
                        SizedBox(height: 4),
                        Text(
                          'Multi-Snap',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Pick Multiple from Gallery
              Expanded(
                child: InkWell(
                  onTap: _isProcessingImage ? null : _pickMultipleFromGallery,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.photo_library_rounded,
                            size: 22, color: AppColors.textSecondary),
                        SizedBox(height: 4),
                        Text(
                          'Gallery',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
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

  Widget _buildPagesListSection() {
    if (_photos.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.document_scanner_rounded,
                  size: 36, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Pages Captured Yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Click photos of your assignment pages using Camera, Multi-Snap, or pick from Gallery.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _captureSinglePhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Take Photo'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _multiSnapCamera,
                    icon: const Icon(Icons.burst_mode_rounded, size: 18),
                    label: const Text('Multi-Snap'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickMultipleFromGallery,
              icon: const Icon(Icons.photo_library_rounded,
                  size: 16, color: AppColors.textSecondary),
              label: const Text(
                'Or select existing photos from Gallery',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Document Pages (${_photos.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Order: Page 1 to ${_photos.length}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _photos.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (ctx, index) {
            final photo = _photos[index];
            final isFirst = index == 0;
            final isLandscape = photo.isLandscape;

            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isFirst ? AppColors.primary : AppColors.border,
                  width: isFirst ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  // Page Thumbnail with orientation indicator
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: RotatedBox(
                          quarterTurns: photo.rotationDegrees ~/ 90,
                          child: Image.memory(
                            photo.bytes,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${index + 1}',
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
                  const SizedBox(width: 12),

                  // Page Details & Orientation Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                isFirst
                                    ? 'Page 1 (Header)'
                                    : 'Page ${index + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isFirst
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isFirst) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Top Title',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              isLandscape
                                  ? Icons.stay_current_landscape_rounded
                                  : Icons.stay_current_portrait_rounded,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                isLandscape
                                    ? 'Landscape (${photo.width}x${photo.height})'
                                    : 'Portrait (${photo.width}x${photo.height})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions: Rotate, Move Up, Move Down, Delete
                  IconButton(
                    tooltip: 'Rotate 90°',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.rotate_right_rounded,
                        size: 20, color: AppColors.textSecondary),
                    onPressed: () => _rotatePhoto(index),
                  ),
                  if (index > 0)
                    IconButton(
                      tooltip: 'Move Up',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.arrow_upward_rounded,
                          size: 18, color: AppColors.textSecondary),
                      onPressed: () => _movePhoto(index, index - 1),
                    ),
                  if (index < _photos.length - 1)
                    IconButton(
                      tooltip: 'Move Down',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.arrow_downward_rounded,
                          size: 18, color: AppColors.textSecondary),
                      onPressed: () => _movePhoto(index, index + 1),
                    ),
                  IconButton(
                    tooltip: 'Remove',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 20, color: AppColors.danger),
                    onPressed: () => _removePhoto(index),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
