import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/data/services/analysis_api_client.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/analysis_execution_context.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/analysis_service.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_action.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/assessment_coverage_info.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/upload_consent.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_analysis_pipeline.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_engine.dart';
import 'package:trustcue_mobile/features/analysis/presentation/controllers/analysis_results_controller.dart';
import 'package:trustcue_mobile/features/analysis/presentation/models/analysis_results_args.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/review_input.dart';
import 'package:trustcue_mobile/features/input/domain/models/reviewed_text_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/sensitive_data_type.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/domain/services/local_sensitive_data_detector.dart';
import 'package:trustcue_mobile/features/input/domain/validation/message_text_validator.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_review_controller.dart';

import '../../../auth/mocks/fake_auth_repository.dart';

class _MockEngine implements AnalysisService {
  _MockEngine();

  @override
  Future<Result<AnalysisReport>> analyze(TextSnapshot snapshot) async {
    return Result.success(
      AnalysisReport(
        id: 'rep-mock-58',
        snapshot: snapshot,
        analyzedAt: DateTime.utc(2026, 11, 2, 10, 0),
        findings: const [],
        limitations: const [],
        suggestedActions: const [],
      ),
    );
  }
}

class _MockSynthesizer implements AssessmentSynthesizer {
  final LocalAssessment assessment;

  _MockSynthesizer(this.assessment);

  @override
  Result<LocalAssessment> synthesize({
    required AnalysisReport report,
    required AnalysisExecutionContext executionContext,
  }) {
    return Result.success(assessment);
  }
}

void main() {
  const detector = LocalSensitiveDataDetector();

  group('Module 58: Payment Card Detection & Luhn Boundaries', () {
    test('detects valid Luhn cards formatted with spaces, hyphens, and continuous digits', () {
      final validCards = [
        'Pay with 4532 0150 0000 0007 today.', // 16-digit Visa/MC with spaces
        'Pay with 4532-0150-0000-0007 today.', // 16-digit Visa/MC with hyphens
        'Pay with 4532015000000007 today.', // 16-digit continuous
        'Pay with 3782 822463 10005 today.', // 15-digit Amex
        'Pay with 4012 8888 8888 1 today.', // 13-digit Visa
      ];

      for (final text in validCards) {
        final candidates = detector.detect(text: text, revision: 'rev-1');
        final cards = candidates
            .where((c) => c.type == SensitiveDataType.paymentCard)
            .toList();
        expect(cards.length, 1, reason: 'Expected 1 card match in "$text"');
        expect(cards.first.maskedLabel, startsWith('•••• '));
        final digits = cards.first.matchedText.replaceAll(RegExp(r'\D'), '');
        expect(LocalSensitiveDataDetector.isValidLuhn(digits), isTrue);
      }
    });

    test('rejects card-like sequences failing Luhn and avoids partial phone false positives', () {
      final invalidCards = [
        'Ref 4532 0150 0000 0003 invalid.', // 16 digits spaced failing Luhn
        'Ref 4532-0150-0000-0003 invalid.', // 16 digits hyphenated failing Luhn
        'Ref 4532015000000003 invalid.', // 16 digits continuous failing Luhn
      ];

      for (final text in invalidCards) {
        final candidates = detector.detect(text: text, revision: 'rev-1');
        final cards = candidates.where(
          (c) => c.type == SensitiveDataType.paymentCard,
        );
        expect(
          cards,
          isEmpty,
          reason: 'Failed card should not match paymentCard',
        );

        // Crucial regression: invalid card should NOT have its 12-digit prefix falsely matched as a phone!
        final phones = candidates.where(
          (c) => c.type == SensitiveDataType.phone,
        );
        expect(
          phones,
          isEmpty,
          reason:
              'Invalid card must not be partially matched as phone in "$text"',
        );
      }
    });
  });

  group('Module 58: Phone Numbers (Pakistan-Style & International)', () {
    test('detects Pakistan-style mobile and landline formats', () {
      final pakFormats = [
        'Call +92 300 1234567 for info', // international +92 with space
        'Call +92-300-1234567 for info', // international +92 with hyphen
        'Call +923001234567 for info', // international +92 continuous
        'Call 0300 1234567 for info', // national 03xx with space
        'Call 0300-1234567 for info', // national 03xx with hyphen
        'Call 03001234567 for info', // national 03xx continuous
        'Call 0321 9876543 for info', // national other operator
        'Call 051 111 222 333 for info', // Islamabad UAN / landline multi-group
        'Call (051) 1234567 for info', // Landline with parenthesized area code
      ];

      for (final text in pakFormats) {
        final candidates = detector.detect(text: text, revision: 'rev-1');
        final phones = candidates
            .where((c) => c.type == SensitiveDataType.phone)
            .toList();
        expect(phones.length, 1, reason: 'Expected phone match in "$text"');
        expect(phones.first.maskedLabel, startsWith('•••• '));
      }
    });

    test('detects international formats cleanly', () {
      final intlFormats = [
        'US: +1 (555) 234-5678 call now',
        'UK: +44 20 7946 0958 call now',
        'FR: 01 42 68 55 55 call now',
        'US local: 555-0199 call now',
      ];

      for (final text in intlFormats) {
        final candidates = detector.detect(text: text, revision: 'rev-1');
        final phones = candidates
            .where((c) => c.type == SensitiveDataType.phone)
            .toList();
        expect(
          phones.length,
          1,
          reason: 'Expected international phone match in "$text"',
        );
      }
    });
  });

  group('Module 58: Benign Numeric Counterexamples (Negative Cases)', () {
    test('correctly rejects dates, prices, order IDs, invoice numbers, and serials', () {
      final benignCases = [
        'Date: 2026-10-11 confirmed.',
        'Date: 11/10/2026 confirmed.',
        'Date: 10-11-2026 confirmed.',
        'Price: \$500.00 total.',
        'Price: 1500 PKR total.',
        'Total: Rs 25000 due.',
        'Total: 250 EUR due.',
        'Order ID: 100293847 confirmed.',
        'Order #98234123 placed.',
        'Item #98234123 shipped.',
        'Invoice #4582910 issued.',
        'Serial: 9876543210 registered.',
        'Tracking #: 9400111899562 updated.',
        'Ref: 9823410 logged.',
        'Ticket #1234567 opened.',
      ];

      for (final text in benignCases) {
        final candidates = detector.detect(text: text, revision: 'rev-1');
        final phones = candidates.where(
          (c) => c.type == SensitiveDataType.phone,
        );
        expect(
          phones,
          isEmpty,
          reason:
              'Benign numeric sequence falsely identified as phone in "$text"',
        );
      }
    });
  });

  group('Module 58: Emails and Contextual Verification Codes', () {
    test('detects email addresses and strips trailing sentence punctuation', () {
      const text =
          'Reach admin at support@trustcue.app, or contact jane.doe+filter@domain.co.uk.';
      final candidates = detector.detect(text: text, revision: 'rev-1');
      final emails = candidates
          .where((c) => c.type == SensitiveDataType.email)
          .toList();

      expect(emails.length, 2);
      expect(emails[0].matchedText, 'support@trustcue.app');
      expect(emails[1].matchedText, 'jane.doe+filter@domain.co.uk');
    });

    test(
      'detects verification code only when nearby context triggers exist',
      () {
        const withContext =
            'Security alert: your verification code is 492810. Do not share.';
        final candidates = detector.detect(
          text: withContext,
          revision: 'rev-1',
        );
        final otps = candidates
            .where((c) => c.type == SensitiveDataType.verificationCode)
            .toList();

        expect(otps.length, 1);
        expect(otps.first.matchedText, '492810');
        expect(otps.first.maskedLabel, '•••• 810');
      },
    );

    test('rejects isolated 4-8 digit numbers lacking OTP context triggers', () {
      const noContext = 'Room 404 on floor 2. Total cost was 5000. Year 2026.';
      final candidates = detector.detect(text: noContext, revision: 'rev-1');
      final otps = candidates.where(
        (c) => c.type == SensitiveDataType.verificationCode,
      );
      expect(otps, isEmpty);
    });
  });

  group('Module 58: Repeated Occurrences & Overlap Resolution', () {
    test(
      'detects repeated occurrences with distinct IDs and sequential offsets',
      () {
        const text =
            'Send copy to alert@bank.com and CC alert@bank.com immediately.';
        final candidates = detector.detect(text: text, revision: 'rev-1');
        final emails = candidates
            .where((c) => c.type == SensitiveDataType.email)
            .toList();

        expect(emails.length, 2);
        expect(emails[0].id, isNot(equals(emails[1].id)));
        expect(emails[0].startIndex, lessThan(emails[1].startIndex));
        expect(emails[0].matchedText, 'alert@bank.com');
        expect(emails[1].matchedText, 'alert@bank.com');

        final redacted = detector.applyRedactions(
          text: text,
          selectedCandidateIds: {emails[0].id, emails[1].id},
          candidates: candidates,
        );
        expect(redacted, 'Send copy to [EMAIL] and CC [EMAIL] immediately.');
      },
    );

    test('resolves overlapping candidates by priority (Card > OTP > Phone > Email)', () {
      const text = 'Card: 4532 0150 0000 0007';
      final candidates = detector.detect(text: text, revision: 'rev-1');

      expect(candidates.length, 1);
      expect(candidates.first.type, SensitiveDataType.paymentCard);
    });
  });

  group('Module 58: Multiple Redactions Applied Together Without Offset Shifting', () {
    test('applies 4 distinct redactions in descending order preserving unredacted content', () {
      const text =
          'User user@test.com with card 4532 0150 0000 0007, phone 0300 1234567, and verification code 982341.';
      final candidates = detector.detect(text: text, revision: 'rev-1');

      expect(candidates.length, 4);

      final allIds = candidates.map((c) => c.id).toSet();
      final redacted = detector.applyRedactions(
        text: text,
        selectedCandidateIds: allIds,
        candidates: candidates,
      );

      expect(
        redacted,
        'User [EMAIL] with card [CARD NUMBER], phone [PHONE], and verification code [VERIFICATION CODE].',
      );
      expect(redacted, isNot(contains('user@test.com')));
      expect(redacted, isNot(contains('4532 0150 0000 0007')));
      expect(redacted, isNot(contains('0300 1234567')));
      expect(redacted, isNot(contains('982341')));
    });

    test('applies selective subset of redactions leaving unselected candidates intact', () {
      const text = 'Email: a@b.com, Phone: 0300 1234567, Code: 123456';
      final candidates = detector.detect(text: text, revision: 'rev-1');

      final emailCand = candidates.firstWhere(
        (c) => c.type == SensitiveDataType.email,
      );
      final codeCand = candidates.firstWhere(
        (c) => c.type == SensitiveDataType.verificationCode,
      );

      final redacted = detector.applyRedactions(
        text: text,
        selectedCandidateIds: {emailCand.id, codeCand.id},
        candidates: candidates,
      );

      expect(
        redacted,
        'Email: [EMAIL], Phone: 0300 1234567, Code: [VERIFICATION CODE]',
      );
      expect(redacted, contains('0300 1234567'));
    });
  });

  group('Module 58: Unicode, Emojis, and Urdu Text Redaction Safety', () {
    test('redacts phone and OTP in Urdu text with emojis without offset corruption', () {
      const text =
          'براہ کرم اپنا تصدیقی کوڈ 492015 کسی کو نہ دیں۔ رابطہ 0300 1234567 پر کریں۔ 🛡️🔒';
      final candidates = detector.detect(text: text, revision: 'rev-1');

      expect(candidates.length, 2);
      final allIds = candidates.map((c) => c.id).toSet();

      final redacted = detector.applyRedactions(
        text: text,
        selectedCandidateIds: allIds,
        candidates: candidates,
      );

      expect(redacted, contains('[VERIFICATION CODE]'));
      expect(redacted, contains('[PHONE]'));
      expect(redacted, contains('براہ کرم اپنا تصدیقی کوڈ'));
      expect(redacted, contains('🛡️🔒'));
      expect(redacted, isNot(contains('492015')));
      expect(redacted, isNot(contains('0300 1234567')));
    });
  });

  group('Module 58: Review Controller Stale Suggestions & Confirmation Invalidation', () {
    test('editing text invalidates candidates, preview, and confirmation', () {
      final initialSnapshot = TextSnapshot(
        id: 'snap-58-1',
        text: 'Contact user@test.com for details',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 11, 2, 10, 0),
      );

      final controller = InputReviewController(
        reviewInput: ReviewInput(
          snapshot: initialSnapshot,
          sourceRevision: 'rev-1',
        ),
      );
      controller.onInit();

      expect(controller.candidates.length, 1);
      controller.toggleCandidate(controller.candidates.first.id);
      expect(controller.previewText.value, 'Contact [EMAIL] for details');

      // Confirm
      controller.confirmReviewedText();
      expect(controller.isConfirmed.value, isTrue);
      expect(controller.confirmedResult.value, isNotNull);

      // Now edit text in editor
      controller.textEditingController.text =
          'Contact new.user@test.com for details';

      // Stale state must be immediately invalidated
      expect(controller.candidates, isEmpty);
      expect(controller.selectedCandidateIds, isEmpty);
      expect(controller.hasDetected.value, isFalse);
      expect(controller.isConfirmed.value, isFalse);
      expect(controller.confirmedResult.value, isNull);
      expect(
        controller.previewText.value,
        'Contact new.user@test.com for details',
      );

      controller.onClose();
    });

    test('empty or whitespace-only text is rejected during confirmation', () {
      final initialSnapshot = TextSnapshot(
        id: 'snap-58-2',
        text: 'Initial text',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 11, 2, 10, 0),
      );

      final controller = InputReviewController(
        reviewInput: ReviewInput(
          snapshot: initialSnapshot,
          sourceRevision: 'rev-1',
        ),
      );
      controller.onInit();

      // Clear text to whitespace
      controller.textEditingController.text = '   ';
      controller.confirmReviewedText();

      expect(controller.isConfirmed.value, isFalse);
      expect(controller.confirmedResult.value, isNull);
      expect(
        controller.validationError.value?.reason,
        MessageTextValidationReason.onlyWhitespace,
      );

      controller.onClose();
    });
  });

  group('Module 58: End-to-End Pipeline & Transport Redacted Payload Verification', () {
    test('local analysis evaluates confirmed redacted snapshot, not raw input', () async {
      final registry = LocalRuleCatalog.createRegistry();
      final fixedClock = DateTime.utc(2026, 11, 2, 10, 0);
      final engine = LocalRuleEngine(
        registry: registry,
        clock: () => fixedClock,
        idGenerator: () => 'rep-e2e-58',
      );
      final synthesizer = LocalAssessmentSynthesizer(clock: () => fixedClock);
      final pipeline = LocalAnalysisPipeline(
        engine: engine,
        synthesizer: synthesizer,
        registry: registry,
      );

      const rawText =
          'URGENT: Call 0300 1234567 immediately to verify account 4532 0150 0000 0007.';
      final candidates = detector.detect(text: rawText, revision: 'rev-1');
      final allIds = candidates.map((c) => c.id).toSet();
      final redactedText = detector.applyRedactions(
        text: rawText,
        selectedCandidateIds: allIds,
        candidates: candidates,
      );

      final redactedSnapshot = TextSnapshot(
        id: 'snap-redacted-58',
        text: redactedText,
        source: InputSource.messageText,
        createdAt: fixedClock,
      );

      final result = await pipeline.process(redactedSnapshot);
      expect(result.isSuccess, isTrue);
      final assessment = result.valueOrNull!;

      // Verify evaluated assessment snapshotId and findings excerpts
      expect(assessment.snapshotId, redactedSnapshot.id);
      for (final group in assessment.groupedIndicators) {
        for (final finding in group.findings) {
          // Evidence spans must never contain the sensitive numbers
          for (final ev in finding.evidence) {
            expect(ev.exactExcerpt, isNot(contains('4532 0150 0000 0007')));
            expect(ev.exactExcerpt, isNot(contains('0300 1234567')));
          }
        }
      }
    });

    test('AnalysisApiClient transmits strictly redacted text and excludes removed values', () async {
      const rawSensitiveText =
          'Suspicious alert: pay card 4532 0150 0000 0007 call +92 300 1234567';
      final candidates = detector.detect(
        text: rawSensitiveText,
        revision: 'rev-1',
      );
      final redactedText = detector.applyRedactions(
        text: rawSensitiveText,
        selectedCandidateIds: candidates.map((c) => c.id).toSet(),
        candidates: candidates,
      );

      final redactedSnapshot = TextSnapshot(
        id: 'snap-upload-58',
        text: redactedText,
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 11, 2, 10, 0),
      );

      final consent = UploadConsent.affirmative(
        snapshot: redactedSnapshot,
        accountId: 'test-user-id-58',
      );

      Map<String, dynamic>? capturedPayload;

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/analysis/ai');
        expect(request.headers['authorization'], 'Bearer fake.test.jwt');
        capturedPayload = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({
            'reportId': 'ai-rep-58',
            'snapshotId': redactedSnapshot.id,
            'provider': 'groq',
            'model': 'llama-3.3-70b-versatile',
            'factualSummary': 'AI analysis completed.',
            'findings': [],
            'uncertaintyNotes': ['Heuristic AI analysis.'],
            'suggestedActions': [],
            'analyzedAt': DateTime.utc(2026, 11, 2, 10, 6).toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = AnalysisApiClient(
        baseUrl: 'http://mock-api.test',
        httpClient: mockClient,
        tokenProvider: () async => 'fake.test.jwt',
      );

      final result = await apiClient.analyzeWithAi(
        snapshot: redactedSnapshot,
        consent: consent,
        sourceRevision: 'rev-1',
        currentAccountId: 'test-user-id-58',
      );

      expect(result.isSuccess, isTrue);
      expect(capturedPayload, isNotNull);
      // Strictly assert transmitted text excludes sensitive values!
      expect(capturedPayload!['text'], redactedText);
      expect(capturedPayload!['text'], isNot(contains('4532 0150 0000 0007')));
      expect(capturedPayload!['text'], isNot(contains('+92 300 1234567')));
      expect(capturedPayload!['text'], contains('[CARD NUMBER]'));
      expect(capturedPayload!['text'], contains('[PHONE]'));
    });

    test('cancelling consent prevents API transmission and preserves local assessment', () async {
      var apiInvoked = false;
      final mockClient = MockClient((request) async {
        apiInvoked = true;
        return http.Response('{}', 500);
      });

      final snapshot = TextSnapshot(
        id: 'snap-cancelled-58',
        text: 'Text without consent transmission',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 11, 2, 10, 0),
      );

      final reviewResult = ReviewedTextResult(
        snapshot: snapshot,
        sourceSnapshotId: 'orig-snap-58',
        sourceRevision: 'rev-1',
        reviewedAt: DateTime.utc(2026, 11, 2, 10, 0),
      );

      final mockAssessment = LocalAssessment(
        reportId: 'rep-c-1',
        snapshotId: snapshot.id,
        snapshotSource: snapshot.source,
        outcomeState: AssessmentOutcomeState.noIndicatorsMatched,
        factualSummary: 'No indicators detected by local rules.',
        groupedIndicators: const [],
        coverageInfo: AssessmentCoverageInfo(
          executedRuleIds: const ['rule.urgency'],
          evaluatedCategories: const [IndicatorCategory.urgencyOrPressure],
        ),
        actionableSteps: [
          AssessmentAction(
            id: 'act-1',
            title: 'Review message context',
            description: 'No matching warning signs.',
            priority: AssessmentActionPriority.recommended,
            supportingFindingIds: const [],
            supportingCategoryIds: const [],
          ),
        ],
        uncertaintyNotes: const ['Evaluated using local heuristic rules.'],
        createdAt: DateTime.utc(2026, 11, 2, 10, 0),
      );

      final registry = LocalRuleCatalog.createRegistry();
      final pipeline = LocalAnalysisPipeline(
        engine: _MockEngine(),
        synthesizer: _MockSynthesizer(mockAssessment),
        registry: registry,
      );

      final apiClient = AnalysisApiClient(
        baseUrl: 'http://mock-api.test',
        httpClient: mockClient,
        tokenProvider: () async => 'fake.test.jwt',
      );

      final authRepo = FakeAuthRepository(
        initialStatus: AuthStatus.authenticated,
        initialUser: const AuthUser(
          id: 'test-user-id-58',
          email: 'test@example.com',
          emailVerified: true,
        ),
      );

      final controller = AnalysisResultsController(
        pipeline: pipeline,
        args: AnalysisResultsArgs(reviewResult: reviewResult),
        apiClient: apiClient,
        authRepository: authRepo,
      );

      controller.onInit();
      controller.startAnalysis();

      // Await pipeline execution
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.state.value, AnalysisState.completedWithNoMatches);
      expect(controller.assessment.value, isNotNull);

      // Simulate consent cancellation:
      // When user dismisses or cancels, consentCancelled is set and request returns without network call
      controller.consentCancelled.value = true;
      expect(apiInvoked, isFalse);
      expect(controller.currentConsent.value, isNull);
      expect(controller.aiState.value, AiAnalysisState.idle);

      // Local assessment remains 100% visible and intact
      expect(controller.assessment.value!.snapshotId, snapshot.id);
      expect(
        controller.assessment.value!.outcomeState,
        AssessmentOutcomeState.noIndicatorsMatched,
      );

      controller.onClose();
    });
  });
}
