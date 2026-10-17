import 'package:flutter/material.dart';
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
import 'package:trustcue_mobile/features/reports/presentation/controllers/history_controller.dart';

import '../../../auth/mocks/fake_auth_repository.dart';
import '../../mocks/fake_report_repository.dart';

void main() {
  group('HistoryController Tests', () {
    late FakeReportRepository fakeRepo;
    late FakeAuthRepository fakeAuth;
    late HistoryController controller;

    SavedReport createReport({
      required String id,
      required String text,
      InputSource source = InputSource.messageText,
      String? accountId,
      bool hasAi = false,
      DateTime? savedAt,
    }) {
      final snapshot = TextSnapshot(
        id: 'snap-$id',
        text: text,
        source: source,
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
        suggestedActions: const ['Verify sender'],
      );

      AiAnalysisReport? aiReport;
      if (hasAi) {
        aiReport = AiAnalysisReport(
          reportId: 'ai-$id',
          snapshotId: snapshot.id,
          provider: 'groq-cloud',
          model: 'qwen/qwen3.8-27b',
          analyzedAt: DateTime.utc(2026, 10, 15, 12, 0, 5),
          factualSummary: 'AI factual summary',
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
        savedAt: savedAt ?? DateTime.utc(2026, 10, 15, 12, 0, 0),
        localReport: localReport,
        aiReport: aiReport,
      );
    }

    setUp(() {
      fakeRepo = FakeReportRepository();
      fakeAuth = FakeAuthRepository();
    });

    test('initial load with empty database sets empty state', () async {
      controller = HistoryController(
        repository: fakeRepo,
        authRepository: fakeAuth,
      );
      controller.onInit();

      await controller.loadInitial();

      expect(controller.isLoading.value, isFalse);
      expect(controller.errorMessage.value, isNull);
      expect(controller.summaries, isEmpty);
      expect(controller.totalCount.value, equals(0));
      expect(controller.hasMore.value, isFalse);
    });

    test(
      'initial load populates reports in descending order of savedAt',
      () async {
        await fakeRepo.saveReport(
          createReport(
            id: 'rep-older',
            text: 'First report text',
            savedAt: DateTime.utc(2026, 10, 15, 10, 0, 0),
          ),
        );
        await fakeRepo.saveReport(
          createReport(
            id: 'rep-newer',
            text: 'Second report text',
            savedAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
          ),
        );

        controller = HistoryController(
          repository: fakeRepo,
          authRepository: fakeAuth,
        );
        await controller.loadInitial();

        expect(controller.summaries.length, equals(2));
        expect(controller.summaries.first.id, equals('rep-newer'));
        expect(controller.summaries.last.id, equals('rep-older'));
        expect(controller.totalCount.value, equals(2));
      },
    );

    test('account scoping isolates guest from authenticated user', () async {
      // 1. Guest report
      await fakeRepo.saveReport(
        createReport(id: 'rep-guest', text: 'Guest check', accountId: null),
      );
      // 2. User report
      await fakeRepo.saveReport(
        createReport(
          id: 'rep-user',
          text: 'User check',
          accountId: 'user-uuid-123',
        ),
      );

      // Guest session
      controller = HistoryController(
        repository: fakeRepo,
        authRepository: fakeAuth,
      );
      await controller.loadInitial();

      expect(controller.summaries.length, equals(1));
      expect(controller.summaries.first.id, equals('rep-guest'));

      // Authenticate as user
      fakeAuth.setStatus(
        AuthStatus.authenticated,
        user: const AuthUser(
          id: 'user-uuid-123',
          email: 'test@example.com',
          emailVerified: true,
        ),
      );

      final userController = HistoryController(
        repository: fakeRepo,
        authRepository: fakeAuth,
      );
      await userController.loadInitial();

      expect(userController.summaries.length, equals(1));
      expect(userController.summaries.first.id, equals('rep-user'));
    });

    test('searching updates summaries by query keyword', () async {
      await fakeRepo.saveReport(
        createReport(id: 'rep-lottery', text: 'You won 100% lottery prize'),
      );
      await fakeRepo.saveReport(
        createReport(id: 'rep-bank', text: 'Security notification from bank'),
      );

      controller = HistoryController(
        repository: fakeRepo,
        authRepository: fakeAuth,
      );
      await controller.loadInitial();
      expect(controller.summaries.length, equals(2));

      controller.onSearchQueryChanged('lottery');
      // Wait for debounce timer
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(controller.summaries.length, equals(1));
      expect(controller.summaries.first.id, equals('rep-lottery'));

      // Clear search
      controller.clearSearch();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.summaries.length, equals(2));
    });

    test('filtering by inputSource restricts results', () async {
      await fakeRepo.saveReport(
        createReport(
          id: 'rep-txt',
          text: 'Text message',
          source: InputSource.messageText,
        ),
      );
      await fakeRepo.saveReport(
        createReport(
          id: 'rep-link',
          text: 'https://test.link',
          source: InputSource.link,
        ),
      );

      controller = HistoryController(
        repository: fakeRepo,
        authRepository: fakeAuth,
      );
      await controller.loadInitial();

      controller.setInputSourceFilter(InputSource.link);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.summaries.length, equals(1));
      expect(controller.summaries.first.id, equals('rep-link'));
    });

    test('filtering by provenance restricts results', () async {
      await fakeRepo.saveReport(
        createReport(id: 'rep-local', text: 'Local check', hasAi: false),
      );
      await fakeRepo.saveReport(
        createReport(id: 'rep-ai', text: 'AI check', hasAi: true),
      );

      controller = HistoryController(
        repository: fakeRepo,
        authRepository: fakeAuth,
      );
      await controller.loadInitial();

      // Only AI
      controller.setProvenanceFilter(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.summaries.length, equals(1));
      expect(controller.summaries.first.id, equals('rep-ai'));

      // Only Local
      controller.setProvenanceFilter(false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.summaries.length, equals(1));
      expect(controller.summaries.first.id, equals('rep-local'));
    });

    test('loadMore appends next page items accurately', () async {
      for (var i = 1; i <= 25; i++) {
        await fakeRepo.saveReport(
          createReport(
            id: 'rep-$i',
            text: 'Report text $i',
            savedAt: DateTime.utc(2026, 10, 15, 12, i, 0),
          ),
        );
      }

      controller = HistoryController(
        repository: fakeRepo,
        authRepository: fakeAuth,
      );
      await controller.loadInitial();

      expect(controller.summaries.length, equals(HistoryController.pageSize));
      expect(controller.hasMore.value, isTrue);

      await controller.loadMore();

      expect(controller.summaries.length, equals(25));
      expect(controller.hasMore.value, isFalse);
    });

    test('handles repository failure gracefully', () async {
      fakeRepo.shouldFailLoad = true;
      fakeRepo.failureMessage = 'I/O failure reading reports.';

      controller = HistoryController(
        repository: fakeRepo,
        authRepository: fakeAuth,
      );
      await controller.loadInitial();

      expect(controller.isLoading.value, isFalse);
      expect(controller.errorMessage.value, contains('I/O failure'));
      expect(controller.summaries, isEmpty);
    });

    testWidgets(
      'deleteReportWithConfirmation returns immediately when isDeleting is true',
      (tester) async {
        await fakeRepo.saveReport(
          createReport(id: 'rep-hist-del', text: 'Text'),
        );

        controller = HistoryController(
          repository: fakeRepo,
          authRepository: fakeAuth,
        );
        await controller.loadInitial();
        expect(controller.summaries.length, equals(1));

        controller.isDeleting.value = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await controller.deleteReportWithConfirmation(
                      controller.summaries.first,
                      context,
                    );
                  },
                  child: const Text('Delete'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Delete'));
        await tester.pump();

        // Summary must still be present in controller and repo
        expect(controller.summaries.length, equals(1));
        final check = await fakeRepo.getReportById('rep-hist-del');
        expect(check.valueOrNull, isNotNull);
      },
    );
  });
}
