import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/ai_analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/reports/domain/models/saved_report.dart';
import 'package:trustcue_mobile/features/reports/presentation/controllers/saved_report_detail_controller.dart';

import '../../../auth/mocks/fake_auth_repository.dart';
import '../../mocks/fake_report_repository.dart';

void main() {
  group('SavedReportDetailController Tests', () {
    late FakeReportRepository fakeRepo;
    late FakeAuthRepository fakeAuth;

    SavedReport createReport({
      required String id,
      required String text,
      String? accountId,
      bool hasAi = false,
    }) {
      final snapshot = TextSnapshot(
        id: 'snap-$id',
        text: text,
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );

      final excerpt = text.substring(0, text.length >= 5 ? 5 : text.length);
      final finding = AnalysisFinding(
        id: 'f-$id',
        category: 'urgency',
        explanation: 'Suspicious urgency',
        origin: FindingOrigin.localRule,
        producerId: 'rule.urgency',
        evidence: [
          EvidenceReference(
            snapshotId: snapshot.id,
            startOffset: 0,
            endOffset: excerpt.length,
            exactExcerpt: excerpt,
          ),
        ],
      );

      final localReport = AnalysisReport(
        id: id,
        snapshot: snapshot,
        analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
        findings: [finding],
        limitations: const ['Test heuristic coverage'],
        suggestedActions: const ['Verify sender independently'],
      );

      AiAnalysisReport? aiReport;
      if (hasAi) {
        aiReport = AiAnalysisReport(
          reportId: 'ai-$id',
          snapshotId: snapshot.id,
          provider: 'groq-cloud',
          model: 'qwen/qwen3.8-27b',
          analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 5),
          factualSummary: 'AI factual summary for detail test',
          findings: [
            AnalysisFinding(
              id: 'ai-f-$id',
              category: 'urgency',
              explanation: 'Remote AI confirmed urgency',
              origin: FindingOrigin.remoteAi,
              producerId: 'groq-cloud',
              evidence: [
                EvidenceReference(
                  snapshotId: snapshot.id,
                  startOffset: 0,
                  endOffset: excerpt.length,
                  exactExcerpt: excerpt,
                ),
              ],
            ),
          ],
          uncertaintyNotes: const ['AI unverified registrar'],
          suggestedActions: const [],
        );
      }

      return SavedReport(
        id: id,
        snapshot: snapshot,
        accountId: accountId,
        analyzedAt: localReport.analyzedAt,
        savedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
        localReport: localReport,
        aiReport: aiReport,
      );
    }

    setUp(() {
      fakeRepo = FakeReportRepository();
      fakeAuth = FakeAuthRepository();
    });

    test(
      'loads saved local report and reconstructs findings faithfully',
      () async {
        final report = createReport(
          id: 'rep-det-1',
          text: 'Important wire alert',
        );
        await fakeRepo.saveReport(report);

        final controller = SavedReportDetailController(
          reportId: 'rep-det-1',
          repository: fakeRepo,
          authRepository: fakeAuth,
        );
        await controller.loadReport();

        expect(controller.isLoading.value, isFalse);
        expect(controller.errorMessage.value, isNull);
        expect(controller.report.value, isNotNull);
        expect(controller.report.value!.id, equals('rep-det-1'));
        expect(
          controller.report.value!.snapshot.text,
          equals('Important wire alert'),
        );
        expect(controller.report.value!.localReport.findings.length, equals(1));
        expect(controller.report.value!.hasAiAnalysis, isFalse);
      },
    );

    test(
      'loads AI-enriched report with both local and AI findings intact',
      () async {
        final report = createReport(
          id: 'rep-det-ai',
          text: 'Important wire alert with AI',
          hasAi: true,
        );
        await fakeRepo.saveReport(report);

        final controller = SavedReportDetailController(
          reportId: 'rep-det-ai',
          repository: fakeRepo,
          authRepository: fakeAuth,
        );
        await controller.loadReport();

        expect(controller.isLoading.value, isFalse);
        expect(controller.report.value!.hasAiAnalysis, isTrue);
        expect(controller.report.value!.aiReport, isNotNull);
        expect(
          controller.report.value!.aiReport!.provider,
          equals('groq-cloud'),
        );
        expect(controller.report.value!.aiReport!.findings.length, equals(1));
      },
    );

    test('non-existent report ID produces descriptive error', () async {
      final controller = SavedReportDetailController(
        reportId: 'rep-missing',
        repository: fakeRepo,
        authRepository: fakeAuth,
      );
      await controller.loadReport();

      expect(controller.isLoading.value, isFalse);
      expect(controller.report.value, isNull);
      expect(
        controller.errorMessage.value,
        contains('Report not found or not accessible'),
      );
    });

    test('enforces account ownership boundary', () async {
      final userReport = createReport(
        id: 'rep-user-owned',
        text: 'Private user message',
        accountId: 'owner-uuid',
      );
      await fakeRepo.saveReport(userReport);

      // 1. Guest attempting to access user report
      final guestController = SavedReportDetailController(
        reportId: 'rep-user-owned',
        repository: fakeRepo,
        authRepository: fakeAuth,
      );
      await guestController.loadReport();
      expect(guestController.report.value, isNull);
      expect(
        guestController.errorMessage.value,
        contains('Report not found or not accessible'),
      );

      // 2. Different user attempting to access user report
      fakeAuth.setStatus(
        AuthStatus.authenticated,
        user: const AuthUser(
          id: 'attacker-uuid',
          email: 'attacker@example.com',
          emailVerified: true,
        ),
      );

      final wrongUserController = SavedReportDetailController(
        reportId: 'rep-user-owned',
        repository: fakeRepo,
        authRepository: fakeAuth,
      );
      await wrongUserController.loadReport();
      expect(wrongUserController.report.value, isNull);
      expect(
        wrongUserController.errorMessage.value,
        contains('Report not found or not accessible'),
      );

      // 3. Legitimate owner accessing their report
      fakeAuth.setStatus(
        AuthStatus.authenticated,
        user: const AuthUser(
          id: 'owner-uuid',
          email: 'owner@example.com',
          emailVerified: true,
        ),
      );

      final ownerController = SavedReportDetailController(
        reportId: 'rep-user-owned',
        repository: fakeRepo,
        authRepository: fakeAuth,
      );
      await ownerController.loadReport();
      expect(ownerController.report.value, isNotNull);
      expect(ownerController.report.value!.id, equals('rep-user-owned'));
    });

    test('toggleLimitations flips showLimitations boolean', () {
      final controller = SavedReportDetailController(
        reportId: 'rep-1',
        repository: fakeRepo,
        authRepository: fakeAuth,
      );

      expect(controller.showLimitations.value, isFalse);
      controller.toggleLimitations();
      expect(controller.showLimitations.value, isTrue);
      controller.toggleLimitations();
      expect(controller.showLimitations.value, isFalse);
    });
  });
}
