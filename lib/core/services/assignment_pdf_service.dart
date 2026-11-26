import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'offline_document_service.dart';

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

  /// Generates a clean, authentic academic PDF document containing the assignment
  /// title, student name, roll number, and scanned pages in the exact order captured.
  /// Styled like a traditional MS Word / LaTeX university submission with classic
  /// serif typography, black ink, and zero app watermarks or AI-style badges.
  static Future<Uint8List> generateAssignmentPdf({
    required String assignmentTitle,
    required String studentName,
    required String rollNumber,
    required List<AssignmentPhoto> photos,
    String? subjectName,
  }) async {
    final cleanTitle = assignmentTitle.trim().isEmpty
        ? 'Assignment'
        : assignmentTitle.trim();
    final cleanName = studentName.trim().isEmpty ? 'Student' : studentName.trim();
    final rawRoll = rollNumber.trim();
    final hasRoll = rawRoll.isNotEmpty &&
        rawRoll.toUpperCase() != 'N/A' &&
        rawRoll.toUpperCase() != 'NONE';
    final cleanSubject = subjectName?.trim() ?? '';

    final pdf = pw.Document(
      title: cleanTitle,
      author: cleanName,
      subject: cleanSubject.isNotEmpty ? cleanSubject : cleanTitle,
    );

    // Simple, natural human date (no time-of-day or bullet symbols)
    final formattedDate = DateFormat('d MMMM yyyy').format(DateTime.now());
    final totalPages = photos.isEmpty ? 1 : photos.length;

    // Classic academic serif fonts (built into every PDF viewer, looks like Word/LaTeX)
    final serifRegular = pw.Font.times();
    final serifBold = pw.Font.timesBold();
    final serifItalic = pw.Font.timesItalic();

    const inkBlack = PdfColor.fromInt(0xFF111111);
    const inkMuted = PdfColor.fromInt(0xFF333333);
    const ruleColor = PdfColor.fromInt(0xFF222222);

    final pageThemeBase = pw.ThemeData.withFont(
      base: serifRegular,
      bold: serifBold,
      italic: serifItalic,
    );

    if (photos.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pageThemeBase,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildAcademicHeader(
                  title: cleanTitle,
                  subject: cleanSubject,
                  studentName: cleanName,
                  rollNumber: hasRoll ? rawRoll : null,
                  dateText: formattedDate,
                  inkBlack: inkBlack,
                  inkMuted: inkMuted,
                  ruleColor: ruleColor,
                  isLandscape: false,
                ),
              ],
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

    // Build Page 1: Classic University Header + First Scanned Page
    final firstPhoto = photos[0];
    final firstPwImage = pwImages[0];
    final firstIsLandscape = firstPhoto.isLandscape;
    final firstPageFormat =
        firstIsLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

    pdf.addPage(
      pw.Page(
        pageFormat: firstPageFormat,
        theme: pageThemeBase,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildAcademicHeader(
                title: cleanTitle,
                subject: cleanSubject,
                studentName: cleanName,
                rollNumber: hasRoll ? rawRoll : null,
                dateText: formattedDate,
                inkBlack: inkBlack,
                inkMuted: inkMuted,
                ruleColor: ruleColor,
                isLandscape: firstIsLandscape,
              ),
              pw.SizedBox(height: 10),

              // First Scanned Document Image (no artificial rounded corners)
              pw.Expanded(
                child: pw.Center(
                  child: pw.Image(
                    firstPwImage,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),

              if (totalPages > 1) ...[
                pw.SizedBox(height: 6),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    '1 / $totalPages',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: inkMuted,
                    ),
                  ),
                ),
              ],
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
          theme: pageThemeBase,
          margin: const pw.EdgeInsets.fromLTRB(24, 20, 24, 20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Subtle top running line with Name & Roll No
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      cleanName,
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        color: inkMuted,
                      ),
                    ),
                    if (hasRoll)
                      pw.Text(
                        'Roll No: $rawRoll',
                        style: const pw.TextStyle(
                          fontSize: 9.5,
                          color: inkMuted,
                        ),
                      ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Container(height: 0.4, color: PdfColors.grey500),
                pw.SizedBox(height: 8),

                // Consecutive Scanned Page Image
                pw.Expanded(
                  child: pw.Center(
                    child: pw.Image(
                      pwImg,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),

                pw.SizedBox(height: 6),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    '$pageIndex / $totalPages',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: inkMuted,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Traditional university assignment header block (MS Word / LaTeX style).
  static pw.Widget _buildAcademicHeader({
    required String title,
    required String subject,
    required String studentName,
    required String? rollNumber,
    required String dateText,
    required PdfColor inkBlack,
    required PdfColor inkMuted,
    required PdfColor ruleColor,
    required bool isLandscape,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (subject.isNotEmpty) ...[
          pw.Text(
            subject,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 11,
              fontStyle: pw.FontStyle.italic,
              color: inkMuted,
            ),
          ),
          pw.SizedBox(height: 3),
        ],
        pw.Text(
          title,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: isLandscape ? 15 : 16.5,
            fontWeight: pw.FontWeight.bold,
            color: inkBlack,
          ),
          maxLines: 2,
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 0.8, color: ruleColor),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: 'Name: ',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: inkBlack,
                        ),
                      ),
                      pw.TextSpan(
                        text: studentName,
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: inkBlack,
                        ),
                      ),
                    ],
                  ),
                ),
                if (rollNumber != null) ...[
                  pw.SizedBox(height: 3),
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(
                          text: 'Roll No: ',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: inkBlack,
                          ),
                        ),
                        pw.TextSpan(
                          text: rollNumber,
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: inkBlack,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: 'Date: ',
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          fontWeight: pw.FontWeight.bold,
                          color: inkBlack,
                        ),
                      ),
                      pw.TextSpan(
                        text: dateText,
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          color: inkBlack,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: ruleColor),
      ],
    );
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
      // Request storage permission on legacy Android and save to public Download/ClassConnect
      await OfflineDocumentService.instance.saveToPublicDownloads(
        fileName: '$sanitizedName.pdf',
        mimeType: 'application/pdf',
        bytes: pdfBytes,
      );
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
