import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/export/data/services/export_storage_service.dart';
import 'package:trustcue_mobile/features/export/data/services/share_launcher.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_format.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_options.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_report_data.dart';
import 'package:trustcue_mobile/features/export/presentation/controllers/export_controller.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';

class FakeExportStorageService implements ExportStorageService {
  String? lastWrittenContent;
  Uint8List? lastWrittenBytes;

  @override
  Future<File> writePlainTextReport(String content, {DateTime? timestamp}) async {
    lastWrittenContent = content;
    final file = File('${Directory.systemTemp.path}/test_report.txt');
    await file.writeAsString(content);
    return file;
  }

  @override
  Future<File> writePdfReport(Uint8List bytes, {DateTime? timestamp}) async {
    lastWrittenBytes = bytes;
    final file = File('${Directory.systemTemp.path}/test_report.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  @override
  Future<int> pruneOldExports({Duration maxAge = const Duration(hours: 2)}) async => 0;

  @override
  Future<int> cleanupAllExports() async => 0;
}

class FakeShareLauncher implements ShareLauncher {
  File? sharedFile;
  String? sharedMimeType;
  ShareStatus returnStatus = ShareStatus.success;

  @override
  Future<ShareStatus> shareFile({
    required File file,
    required String mimeType,
    required String subject,
    required String text,
    Rect? sharePositionOrigin,
  }) async {
    sharedFile = file;
    sharedMimeType = mimeType;
    return returnStatus;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExportController Tests', () {
    late FakeExportStorageService fakeStorage;
    late FakeShareLauncher fakeLauncher;

    ExportReportData createTestData(ExportOptions options) {
      return ExportReportData(
        reportId: 'tc-ctrl-test',
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
        exportedAt: DateTime.utc(2026, 10, 17, 10, 0, 0),
        inputSource: InputSource.messageText,
        hasAiAnalysis: true,
        outcomeState: AssessmentOutcomeState.indicatorsDetected,
        outcomeSummary: '1 warning indicator detected.',
        findings: [
          ExportFindingItem(
            category: 'urgency',
            origin: FindingOrigin.localRule,
            producerId: 'rule.urgency',
            explanation: 'Immediate payment required.',
            evidenceQuotes: options.includeEvidenceQuotes ? ['Act now!'] : const [],
          ),
          if (options.includeAiExplanations)
            const ExportFindingItem(
              category: 'paymentRequest',
              origin: FindingOrigin.remoteAi,
              producerId: 'groq.analysis',
              explanation: 'Wire transfer requested.',
              evidenceQuotes: [],
            ),
        ],
        limitations: const ['Honest limitations.'],
        suggestedActions: const ['Contact your bank.'],
        reviewedText: options.includeReviewedText ? 'Dear user, Act now!' : null,
      );
    }

    setUp(() {
      fakeStorage = FakeExportStorageService();
      fakeLauncher = FakeShareLauncher();
    });

    test('initializes with strict privacy defaults and generates initial preview', () {
      final controller = ExportController(
        dataFactory: createTestData,
        storageService: fakeStorage,
        shareLauncher: fakeLauncher,
      );
      controller.onInit();

      expect(controller.options.value.format, ExportFormat.plainText);
      expect(controller.options.value.includeReviewedText, isFalse);
      expect(controller.options.value.includeEvidenceQuotes, isFalse);
      expect(controller.options.value.includeAiExplanations, isFalse);

      expect(controller.previewText.value, contains('TRUSTCUE SCAM ANALYSIS REPORT'));
      expect(controller.previewText.value, contains('[Reviewed message text excluded by user for privacy]'));
    });

    test('toggling options reactively updates preview', () {
      final controller = ExportController(
        dataFactory: createTestData,
        storageService: fakeStorage,
        shareLauncher: fakeLauncher,
      );
      controller.onInit();

      // Toggle reviewed text to ON
      controller.toggleIncludeReviewedText(true);
      expect(controller.options.value.includeReviewedText, isTrue);
      expect(controller.previewText.value, contains('Dear user, Act now!'));

      // Toggle evidence quotes to ON
      controller.toggleIncludeEvidenceQuotes(true);
      expect(controller.previewText.value, contains('* "Act now!"'));

      // Toggle AI explanations to ON
      controller.toggleIncludeAiExplanations(true);
      expect(controller.previewText.value, contains('[2] paymentRequest'));

      // Toggle format to PDF
      controller.setFormat(ExportFormat.pdf);
      expect(controller.options.value.format, ExportFormat.pdf);
    });

    test('shares plain text report successfully', () async {
      final controller = ExportController(
        dataFactory: createTestData,
        storageService: fakeStorage,
        shareLauncher: fakeLauncher,
      );
      controller.onInit();

      final status = await controller.shareReport();

      expect(status, ShareStatus.success);
      expect(fakeStorage.lastWrittenContent, isNotNull);
      expect(fakeStorage.lastWrittenContent, contains('TRUSTCUE SCAM ANALYSIS REPORT'));
      expect(fakeLauncher.sharedMimeType, 'text/plain');
    });

    test('shares PDF report successfully', () async {
      final controller = ExportController(
        dataFactory: createTestData,
        storageService: fakeStorage,
        shareLauncher: fakeLauncher,
        initialOptions: const ExportOptions(format: ExportFormat.pdf),
      );
      controller.onInit();

      final status = await controller.shareReport();

      expect(status, ShareStatus.success);
      expect(fakeStorage.lastWrittenBytes, isNotNull);
      expect(fakeLauncher.sharedMimeType, 'application/pdf');
    });

    test('copies plain text to clipboard', () async {
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String?;
          return null;
        } else if (call.method == 'Clipboard.getData') {
          return {'text': copiedText};
        }
        return null;
      });

      final controller = ExportController(
        dataFactory: createTestData,
        storageService: fakeStorage,
        shareLauncher: fakeLauncher,
      );
      controller.onInit();

      final success = await controller.copyPlainTextToClipboard();
      expect(success, isTrue);
      expect(controller.wasCopied.value, isTrue);
      expect(copiedText, contains('TRUSTCUE SCAM ANALYSIS REPORT'));
    });
  });
}
