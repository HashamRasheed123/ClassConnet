import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Represents a single captured page of an assignment
class AssignmentPhoto {
  final String id;
  final String path;
  final Uint8List bytes;
  final int width;
  final int height;
  int rotationDegrees; // 0, 90, 180, 270

  AssignmentPhoto({
    required this.id,
    required this.path,
    required this.bytes,
    required this.width,
    required this.height,
    this.rotationDegrees = 0,
  });

  bool get isLandscape {
    final effectiveWidth = (rotationDegrees % 180 == 0) ? width : height;
    final effectiveHeight = (rotationDegrees % 180 == 0) ? height : width;
    return effectiveWidth > effectiveHeight;
  }
}

class AssignmentPdfService {
  /// Processes raw image bytes, extracts dimensions and creates an AssignmentPhoto
  static Future<AssignmentPhoto> processImage({
    required String path,
    required Uint8List bytes,
  }) async {
    int w = 1200;
    int h = 1600;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        w = decoded.width;
        h = decoded.height;
      }
    } catch (e) {
      debugPrint('Error decoding image dimensions: $e');
    }

    return AssignmentPhoto(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      path: path,
      bytes: bytes,
      width: w,
      height: h,
    );
  }

  /// Generates a local, 100% private PDF document containing the assignment title,
  /// student name, roll number, and images in the exact order captured.
  /// Automatically adapts page orientation to portrait or landscape for each image.
  static Future<Uint8List> generateAssignmentPdf({
    required String assignmentTitle,
    required String studentName,
    required String rollNumber,
    required List<AssignmentPhoto> photos,
    String? subjectName,
  }) async {
    final pdf = pw.Document(
      title: assignmentTitle,
      author: studentName,
      subject: subjectName ?? 'Academic Assignment',
      keywords: 'assignment, student, offline, $rollNumber',
    );

    final formattedDate =
        DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(DateTime.now());
    final totalPages = photos.isEmpty ? 1 : photos.length;

    // Load PDF font (defaults to Helvetica / Courier built into standard PDF)
    const baseColor = PdfColors.blueGrey900;
    const accentColor = PdfColor.fromInt(0xFF2563EB); // AppColors.primary
    const subtleBg = PdfColor.fromInt(0xFFF8FAFC);
    const borderColor = PdfColor.fromInt(0xFFE2E8F0);

    if (photos.isEmpty) {
      // Empty document placeholder
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    assignmentTitle,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: baseColor,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('Student: $studentName ($rollNumber)'),
                  pw.SizedBox(height: 20),
                  pw.Text('No document images attached.'),
                ],
              ),
            );
          },
        ),
      );
      return pdf.save();
    }

    // Convert photos into PDF image memory representations
    final pwImages = <pw.MemoryImage>[];
    for (final photo in photos) {
      pwImages.add(pw.MemoryImage(photo.bytes));
    }

    // Build Page 1: Top Assignment Header + First Image
    final firstPhoto = photos[0];
    final firstPwImage = pwImages[0];
    final firstIsLandscape = firstPhoto.isLandscape;
    final firstPageFormat =
        firstIsLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

    pdf.addPage(
      pw.Page(
        pageFormat: firstPageFormat,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. TOP ASSIGNMENT HEADER (Assignment Title, Name, Roll No)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: subtleBg,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: borderColor, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Title
                    pw.Text(
                      assignmentTitle.trim().isEmpty
                          ? 'Assignment Submission'
                          : assignmentTitle.trim(),
                      style: pw.TextStyle(
                        fontSize: firstIsLandscape ? 18 : 20,
                        fontWeight: pw.FontWeight.bold,
                        color: baseColor,
                      ),
                      maxLines: 2,
                    ),
                    if (subjectName != null && subjectName.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        subjectName,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: accentColor,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 8),
                    // Student details row
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              const pw.TextSpan(
                                text: 'STUDENT: ',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey700,
                                ),
                              ),
                              pw.TextSpan(
                                text: studentName,
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                  color: baseColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              const pw.TextSpan(
                                text: 'ROLL NO: ',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey700,
                                ),
                              ),
                              pw.TextSpan(
                                text: rollNumber,
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Text(
                          formattedDate,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // 2. FIRST DOCUMENT IMAGE (Fitting page, respecting aspect ratio)
              pw.Expanded(
                child: pw.Center(
                  child: pw.ClipRRect(
                    horizontalRadius: 4,
                    verticalRadius: 4,
                    child: pw.Image(
                      firstPwImage,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              ),

              pw.SizedBox(height: 6),

              // Running bottom footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Class Connect • Verified Submission',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey500),
                  ),
                  pw.Text(
                    'Page 1 of $totalPages',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Build Subsequent Pages (Page 2, Page 3, ...)
    for (int i = 1; i < photos.length; i++) {
      final photo = photos[i];
      final pwImg = pwImages[i];
      final isLandscape = photo.isLandscape;
      final pageFormat =
          isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
      final pageIndex = i + 1;

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Minimal header on consecutive pages
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      assignmentTitle,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      '$studentName ($rollNumber)',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),

                // Consecutive Image
                pw.Expanded(
                  child: pw.Center(
                    child: pw.ClipRRect(
                      horizontalRadius: 4,
                      verticalRadius: 4,
                      child: pw.Image(
                        pwImg,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                pw.SizedBox(height: 6),

                // Running bottom footer
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Page $pageIndex of $totalPages',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      '100% Offline Generation',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Downloads/saves the generated PDF file locally to the device storage
  static Future<File> savePdfLocally({
    required Uint8List pdfBytes,
    required String filename,
  }) async {
    final sanitizedName = filename
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    Directory? dir;
    if (!kIsWeb && Platform.isAndroid) {
      // Try external storage directory or downloads on Android
      try {
        dir = await getExternalStorageDirectory();
      } catch (_) {}
    }
    dir ??= await getApplicationDocumentsDirectory();

    final filePath = '${dir.path}/$sanitizedName.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }

  /// Shares the generated PDF locally via native share sheet (WhatsApp, Drive, Files, etc.)
  static Future<void> sharePdf({
    required Uint8List pdfBytes,
    required String filename,
  }) async {
    final sanitizedName = filename
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '$sanitizedName.pdf',
    );
  }

  /// Prints or opens native system print / save dialog
  static Future<void> printPdf({
    required Uint8List pdfBytes,
    required String name,
  }) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: name,
    );
  }
}
