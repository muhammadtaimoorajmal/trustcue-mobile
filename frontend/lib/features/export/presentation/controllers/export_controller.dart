import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/export/data/services/export_storage_service.dart';
import 'package:trustcue_mobile/features/export/data/services/pdf_export_builder.dart';
import 'package:trustcue_mobile/features/export/data/services/plain_text_export_formatter.dart';
import 'package:trustcue_mobile/features/export/data/services/share_launcher.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_format.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_options.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_report_data.dart';

/// Presentation controller managing report export options, real-time preview,
/// file generation, and sharing intents.
///
/// Invariants & Guarantees:
/// - Options default to strict privacy preservation:
///   reviewed text, evidence quotes, and AI explanations are OFF by default.
/// - Never writes files outside the app-private `<cacheDir>/exports/` directory.
/// - Catches platform sharing failures gracefully without crashing.
class ExportController extends GetxController {
  final ExportReportData Function(ExportOptions options) dataFactory;
  final ExportStorageService storageService;
  final ShareLauncher shareLauncher;
  final bool hasSourceText;
  final bool hasAiFindings;
  final bool hasEvidenceQuotes;

  ExportController({
    required this.dataFactory,
    ExportStorageService? storageService,
    ShareLauncher? shareLauncher,
    this.hasSourceText = true,
    this.hasAiFindings = false,
    this.hasEvidenceQuotes = true,
    ExportOptions initialOptions = const ExportOptions(),
  }) : storageService = storageService ?? DefaultExportStorageService(),
       shareLauncher = shareLauncher ?? DefaultShareLauncher(),
       options = Rx<ExportOptions>(initialOptions);

  final Rx<ExportOptions> options;
  late final Rx<ExportReportData> reportData;
  final RxString previewText = ''.obs;
  final RxBool isGenerating = false.obs;
  final RxBool isSharing = false.obs;
  final RxnString errorMessage = RxnString();
  final RxBool wasCopied = false.obs;

  @override
  void onInit() {
    super.onInit();
    reportData = Rx<ExportReportData>(dataFactory(options.value));
    _refreshPreview();
  }

  /// Whether the current report data can be faithfully rendered in PDF format.
  bool get isPdfSupported =>
      PdfExportBuilder.canRenderFaithfully(reportData.value);

  /// Explanatory reason if PDF export is unavailable due to unsupported script.
  String? get pdfUnsupportedReason =>
      PdfExportBuilder.checkUnsupportedScript(reportData.value);

  void setFormat(ExportFormat format) {
    if (options.value.format == format) return;
    options.value = options.value.copyWith(format: format);
    _recomputeData();
  }

  void toggleIncludeReviewedText(bool value) {
    if (options.value.includeReviewedText == value) return;
    options.value = options.value.copyWith(includeReviewedText: value);
    _recomputeData();
  }

  void toggleIncludeEvidenceQuotes(bool value) {
    if (options.value.includeEvidenceQuotes == value) return;
    options.value = options.value.copyWith(includeEvidenceQuotes: value);
    _recomputeData();
  }

  void toggleIncludeAiExplanations(bool value) {
    if (options.value.includeAiExplanations == value) return;
    options.value = options.value.copyWith(includeAiExplanations: value);
    _recomputeData();
  }

  void _recomputeData() {
    reportData.value = dataFactory(options.value);
    _refreshPreview();
  }

  void _refreshPreview() {
    if (options.value.format == ExportFormat.pdf && !isPdfSupported) {
      previewText.value =
          '[PDF EXPORT UNAVAILABLE - SCRIPT LIMITATION]\n\n'
          '${pdfUnsupportedReason!}\n\n'
          'Please select Plain Text (.txt) format above for complete, unredacted UTF-8 fidelity.';
      return;
    }
    final text = PlainTextExportFormatter.format(reportData.value);
    previewText.value = text;
  }

  /// Copies the formatted plain text report to the clipboard.
  Future<bool> copyPlainTextToClipboard() async {
    if (isGenerating.value || isSharing.value) return false;

    try {
      final text = PlainTextExportFormatter.format(reportData.value);
      await Clipboard.setData(ClipboardData(text: text));
      wasCopied.value = true;
      Future.delayed(const Duration(seconds: 2), () {
        wasCopied.value = false;
      });
      return true;
    } catch (e) {
      errorMessage.value = 'Failed to copy to clipboard: ${e.toString()}';
      return false;
    }
  }

  /// Generates the exported file in the selected format and invokes
  /// the native platform share sheet.
  Future<ShareStatus?> shareReport({Rect? sharePositionOrigin}) async {
    if (isGenerating.value || isSharing.value) return null;

    final format = options.value.format;
    if (format == ExportFormat.pdf && !isPdfSupported) {
      errorMessage.value = pdfUnsupportedReason;
      return ShareStatus.unavailable;
    }

    isGenerating.value = true;
    errorMessage.value = null;

    File? exportedFile;

    try {
      final currentData = reportData.value;

      if (format == ExportFormat.plainText) {
        final content = PlainTextExportFormatter.format(currentData);
        exportedFile = await storageService.writePlainTextReport(content);
      } else {
        final pdfBytes = await PdfExportBuilder.buildPdf(currentData);
        exportedFile = await storageService.writePdfReport(pdfBytes);
      }

      // Acquire active lease to protect file from cleanup while external apps read it
      storageService.acquireLease(exportedFile.path);

      isGenerating.value = false;
      isSharing.value = true;

      final status = await shareLauncher.shareFile(
        file: exportedFile,
        mimeType: format.mimeType,
        subject: 'TrustCue Scam Analysis Report (${currentData.reportId})',
        text: 'TrustCue Scam Indicator Analysis Report',
        sharePositionOrigin: sharePositionOrigin,
      );

      return status;
    } catch (e) {
      errorMessage.value = 'Export error: ${e.toString()}';
      return ShareStatus.unavailable;
    } finally {
      isGenerating.value = false;
      isSharing.value = false;
      if (exportedFile != null) {
        // Safe lease window: delay lease release by 2 minutes to allow external app
        // (e.g. Gmail, Drive, WhatsApp) to finish reading via FileProvider
        final path = exportedFile.path;
        Future.delayed(const Duration(minutes: 2), () {
          storageService.releaseLease(path);
        });
      }
    }
  }
}
