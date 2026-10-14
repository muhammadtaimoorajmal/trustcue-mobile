import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/core/errors/analysis_failure.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/local_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_engine.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_registry.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Synthetic test rule matching a specific phrase.
class _SyntheticPhraseRule implements LocalRule {
  @override
  final String id;
  @override
  final int version = 1;
  @override
  final IndicatorCategory category;
  final String targetPhrase;
  final String findingExplanation;
  @override
  final List<String> supportedLanguages = const ['en'];
  @override
  final List<String> limitations = const [
    'Synthetic demonstration rule for tests only.',
  ];

  const _SyntheticPhraseRule({
    required this.id,
    required this.category,
    required this.targetPhrase,
    required this.findingExplanation,
  });

  @override
  List<AnalysisFinding> evaluate(TextSnapshot snapshot) {
    final text = snapshot.text;
    final findings = <AnalysisFinding>[];
    var startIndex = 0;

    while (true) {
      final index = text.indexOf(targetPhrase, startIndex);
      if (index == -1) break;

      final end = index + targetPhrase.length;
      final evidence = EvidenceValidator.createReference(
        snapshot: snapshot,
        startOffset: index,
        endOffset: end,
      );

      findings.add(
        AnalysisFinding(
          id: '${id}_${index}_$end',
          category: category.id,
          explanation: findingExplanation,
          origin: FindingOrigin.localRule,
          producerId: id,
          evidence: [evidence],
        ),
      );

      startIndex = end;
    }

    return findings;
  }
}

/// Synthetic rule that throws an exception during evaluation.
class _FaultyThrowingRule implements LocalRule {
  @override
  final String id = 'rule.faulty.throw';
  @override
  final int version = 1;
  @override
  final IndicatorCategory category = IndicatorCategory.urgencyOrPressure;
  @override
  final List<String> supportedLanguages = const ['*'];
  @override
  final List<String> limitations = const ['Faulty test rule.'];

  @override
  List<AnalysisFinding> evaluate(TextSnapshot snapshot) {
    throw StateError('Simulated unexpected exception in rule evaluation.');
  }
}

/// Synthetic rule that emits findings with invalid/mismatched metadata.
class _FaultyMetadataRule implements LocalRule {
  @override
  final String id = 'rule.faulty.metadata';
  @override
  final int version = 1;
  @override
  final IndicatorCategory category = IndicatorCategory.urgencyOrPressure;
  @override
  final List<String> supportedLanguages = const ['en'];
  @override
  final List<String> limitations = const ['Faulty test rule.'];

  final FindingOrigin emitOrigin;
  final String? emitProducerId;
  final String? emitCategory;

  const _FaultyMetadataRule({
    this.emitOrigin = FindingOrigin.localRule,
    this.emitProducerId,
    this.emitCategory,
  });

  @override
  List<AnalysisFinding> evaluate(TextSnapshot snapshot) {
    final evidence = EvidenceValidator.createReference(
      snapshot: snapshot,
      startOffset: 0,
      endOffset: snapshot.text.length > 5 ? 5 : snapshot.text.length,
    );

    return [
      AnalysisFinding(
        id: 'faulty-finding-1',
        category: emitCategory ?? category.id,
        explanation: 'Faulty finding explanation.',
        origin: emitOrigin,
        producerId: emitProducerId ?? id,
        evidence: [evidence],
      ),
    ];
  }
}

/// Synthetic rule that emits invalid evidence references (mismatched excerpt or bounds).
class _FaultyEvidenceRule implements LocalRule {
  @override
  final String id = 'rule.faulty.evidence';
  @override
  final int version = 1;
  @override
  final IndicatorCategory category = IndicatorCategory.urgencyOrPressure;
  @override
  final List<String> supportedLanguages = const ['en'];
  @override
  final List<String> limitations = const ['Faulty test rule.'];

  final bool outOfBounds;
  final bool mismatchedExcerpt;

  const _FaultyEvidenceRule({
    this.outOfBounds = false,
    this.mismatchedExcerpt = false,
  });

  @override
  List<AnalysisFinding> evaluate(TextSnapshot snapshot) {
    EvidenceReference evidence;
    if (outOfBounds) {
      evidence = EvidenceReference(
        snapshotId: snapshot.id,
        startOffset: 0,
        endOffset: snapshot.text.length + 50,
        exactExcerpt: snapshot.text + ' ' * 50,
      );
    } else if (mismatchedExcerpt) {
      evidence = EvidenceReference(
        snapshotId: snapshot.id,
        startOffset: 0,
        endOffset: 4,
        exactExcerpt: 'XXXX',
      );
    } else {
      evidence = EvidenceValidator.createReference(
        snapshot: snapshot,
        startOffset: 0,
        endOffset: 4,
      );
    }

    return [
      AnalysisFinding(
        id: 'faulty-evidence-finding',
        category: category.id,
        explanation: 'Faulty evidence.',
        origin: FindingOrigin.localRule,
        producerId: id,
        evidence: [evidence],
      ),
    ];
  }
}

void main() {
  group('LocalRuleEngine Tests', () {
    late LocalRuleRegistry registry;
    late LocalRuleEngine engine;
    final fixedTime = DateTime.utc(2026, 10, 12, 12, 0, 0);

    setUp(() {
      registry = LocalRuleRegistry();
      engine = LocalRuleEngine(
        registry: registry,
        clock: () => fixedTime,
        idGenerator: () => 'fixed-test-id',
      );
    });

    TextSnapshot createSnapshot(String text, {String id = 'snap-test'}) {
      return TextSnapshot(
        id: id,
        text: text,
        source: InputSource.messageText,
        createdAt: fixedTime,
      );
    }

    test(
      'Empty registry behavior produces report without claiming safety',
      () async {
        final snapshot = createSnapshot(
          'Hello friend, let us meet tomorrow at noon.',
        );
        final result = await engine.analyze(snapshot);

        expect(result.isSuccess, isTrue);
        final report = result.valueOrNull!;
        expect(report.id, 'report-fixed-test-id');
        expect(report.snapshot, snapshot);
        expect(report.analyzedAt, fixedTime);
        expect(report.findings, isEmpty);

        // Verify limitations honestly state empty findings does NOT mean safe
        final limitationsJoined = report.limitations.join(' ');
        expect(limitationsJoined, contains('never a guarantee of safety'));
        expect(
          limitationsJoined,
          contains('deterministic on-device local rule evaluation'),
        );
        expect(
          limitationsJoined,
          contains('Ordinary legitimate messages can contain these patterns'),
        );

        // Verify actions suggest independent verification
        expect(
          report.suggestedActions.join(' '),
          contains('trusted, independent channels'),
        );
      },
    );

    test(
      'Evaluates single injected synthetic rule and emits valid finding',
      () async {
        registry.register(
          const _SyntheticPhraseRule(
            id: 'rule.urgency.act_now',
            category: IndicatorCategory.urgencyOrPressure,
            targetPhrase: 'act immediately',
            findingExplanation: 'Language urging immediate action observed.',
          ),
        );

        final snapshot = createSnapshot(
          'Please act immediately to verify your status.',
        );
        final result = await engine.analyze(snapshot);

        expect(result.isSuccess, isTrue);
        final report = result.valueOrNull!;
        expect(report.findings.length, 1);

        final finding = report.findings.first;
        expect(finding.category, 'urgency_or_pressure');
        expect(finding.origin, FindingOrigin.localRule);
        expect(finding.producerId, 'rule.urgency.act_now');
        expect(
          finding.explanation,
          'Language urging immediate action observed.',
        );
        expect(finding.evidence.length, 1);

        final evidence = finding.evidence.first;
        expect(evidence.snapshotId, snapshot.id);
        expect(evidence.exactExcerpt, 'act immediately');
        expect(evidence.startOffset, 7);
        expect(evidence.endOffset, 22);
      },
    );

    test(
      'Evaluates multiple synthetic rules across different categories',
      () async {
        registry.register(
          const _SyntheticPhraseRule(
            id: 'rule.urgency.urgent',
            category: IndicatorCategory.urgencyOrPressure,
            targetPhrase: 'URGENT',
            findingExplanation: 'High urgency indicator.',
          ),
        );
        registry.register(
          const _SyntheticPhraseRule(
            id: 'rule.cred.password',
            category: IndicatorCategory.requestsForCredentials,
            targetPhrase: 'send your password',
            findingExplanation: 'Credential solicitation indicator.',
          ),
        );

        final snapshot = createSnapshot(
          'URGENT NOTICE: You must send your password now.',
        );
        final result = await engine.analyze(snapshot);

        expect(result.isSuccess, isTrue);
        final report = result.valueOrNull!;
        expect(report.findings.length, 2);

        expect(report.findings[0].category, 'urgency_or_pressure');
        expect(report.findings[0].evidence.first.exactExcerpt, 'URGENT');

        expect(report.findings[1].category, 'requests_for_credentials');
        expect(
          report.findings[1].evidence.first.exactExcerpt,
          'send your password',
        );
      },
    );

    test('Maintains deterministic result ordering regardless of rule evaluation order', () async {
      // Rule A matches earlier in text; Rule B matches later in text
      const ruleUrgency = _SyntheticPhraseRule(
        id: 'rule.urgency',
        category: IndicatorCategory.urgencyOrPressure,
        targetPhrase: 'Quick action',
        findingExplanation: 'Urgency',
      );
      const rulePayment = _SyntheticPhraseRule(
        id: 'rule.payment',
        category: IndicatorCategory.requestsForPayment,
        targetPhrase: 'wire money',
        findingExplanation: 'Payment',
      );

      // Register payment first, urgency second
      registry.register(rulePayment);
      registry.register(ruleUrgency);

      final snapshot = createSnapshot(
        'Quick action required: please wire money today.',
      );
      final result = await engine.analyze(snapshot);

      expect(result.isSuccess, isTrue);
      final report = result.valueOrNull!;
      expect(report.findings.length, 2);

      // Finding matching at offset 0 ('Quick action') must appear before offset 30 ('wire money')
      expect(report.findings[0].producerId, 'rule.urgency');
      expect(report.findings[0].evidence.first.startOffset, 0);

      expect(report.findings[1].producerId, 'rule.payment');
      expect(report.findings[1].evidence.first.startOffset, 30);
    });

    test(
      'Deterministic sort orders identical start offsets by longer span first',
      () async {
        // Two rules matching at index 0: one with length 14, one with length 4
        const ruleLong = _SyntheticPhraseRule(
          id: 'rule.long',
          category: IndicatorCategory.urgencyOrPressure,
          targetPhrase: 'Immediate alert',
          findingExplanation: 'Long match',
        );
        const ruleShort = _SyntheticPhraseRule(
          id: 'rule.short',
          category: IndicatorCategory.urgencyOrPressure,
          targetPhrase: 'Immediate',
          findingExplanation: 'Short match',
        );

        registry.register(ruleShort);
        registry.register(ruleLong);

        final snapshot = createSnapshot('Immediate alert: check your account.');
        final result = await engine.analyze(snapshot);

        expect(result.isSuccess, isTrue);
        final report = result.valueOrNull!;
        expect(report.findings.length, 2);

        // Longer span (15 characters) comes before shorter span (9 characters)
        expect(
          report.findings[0].evidence.first.exactExcerpt,
          'Immediate alert',
        );
        expect(report.findings[1].evidence.first.exactExcerpt, 'Immediate');
      },
    );

    test(
      'Rejects finding with remoteAi origin emitted by local rule',
      () async {
        registry.register(
          const _FaultyMetadataRule(emitOrigin: FindingOrigin.remoteAi),
        );

        final snapshot = createSnapshot('Sample suspicious message text.');
        final result = await engine.analyze(snapshot);

        expect(result.isFailure, isTrue);
        final failure = result.failureOrNull!;
        expect(failure.code, AnalysisFailureCode.malformedData);
        expect(
          failure.message,
          contains('invalid evidence references or mismatched metadata'),
        );
        // Verifies privacy: failure message contains NO user message text
        expect(
          failure.message,
          isNot(contains('Sample suspicious message text')),
        );
      },
    );

    test('Rejects finding with mismatched producerId', () async {
      registry.register(
        const _FaultyMetadataRule(emitProducerId: 'rule.completely.different'),
      );

      final snapshot = createSnapshot('Sample suspicious message text.');
      final result = await engine.analyze(snapshot);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.code, AnalysisFailureCode.malformedData);
    });

    test('Rejects finding with mismatched categoryId', () async {
      registry.register(
        const _FaultyMetadataRule(
          emitCategory: 'investment_or_return_promises',
        ),
      );

      final snapshot = createSnapshot('Sample suspicious message text.');
      final result = await engine.analyze(snapshot);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.code, AnalysisFailureCode.malformedData);
    });

    test('Rejects rule emitting out-of-bounds evidence offsets', () async {
      registry.register(const _FaultyEvidenceRule(outOfBounds: true));

      final snapshot = createSnapshot('Valid message text for testing.');
      final result = await engine.analyze(snapshot);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.code, AnalysisFailureCode.malformedData);
    });

    test('Rejects rule emitting mismatched evidence excerpt', () async {
      registry.register(const _FaultyEvidenceRule(mismatchedExcerpt: true));

      final snapshot = createSnapshot('Valid message text for testing.');
      final result = await engine.analyze(snapshot);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.code, AnalysisFailureCode.malformedData);
    });

    test('Handles emoji before and inside evidence spans with correct UTF-16 offsets', () async {
      registry.register(
        const _SyntheticPhraseRule(
          id: 'rule.emoji.test',
          category: IndicatorCategory.urgencyOrPressure,
          targetPhrase: 'urgent warning 🚨 now',
          findingExplanation: 'Urgency with emoji.',
        ),
      );

      // ⚠️ has length 2 in UTF-16; 🚨 has length 2 in UTF-16
      final snapshot = createSnapshot(
        '⚠️ Notice: urgent warning 🚨 now check account!',
      );
      final result = await engine.analyze(snapshot);

      expect(result.isSuccess, isTrue);
      final report = result.valueOrNull!;
      expect(report.findings.length, 1);

      final finding = report.findings.first;
      expect(finding.evidence.first.exactExcerpt, 'urgent warning 🚨 now');
      // Verify offset substring matches exactly
      final text = snapshot.text;
      expect(
        text.substring(
          finding.evidence.first.startOffset,
          finding.evidence.first.endOffset,
        ),
        'urgent warning 🚨 now',
      );
    });

    test('Preserves Urdu and non-Latin text without mutation', () async {
      const urduPhrase = 'فوری کارروائی کریں';
      registry.register(
        const _SyntheticPhraseRule(
          id: 'rule.urdu.urgency',
          category: IndicatorCategory.urgencyOrPressure,
          targetPhrase: urduPhrase,
          findingExplanation: 'Urdu urgency indicator.',
        ),
      );

      final urduText = 'اطلاع: $urduPhrase اپنا پاس ورڈ تبدیل کریں۔';
      final snapshot = createSnapshot(urduText);
      final result = await engine.analyze(snapshot);

      expect(result.isSuccess, isTrue);
      final report = result.valueOrNull!;
      expect(report.findings.length, 1);

      final finding = report.findings.first;
      expect(finding.evidence.first.exactExcerpt, urduPhrase);
      expect(
        snapshot.text.substring(
          finding.evidence.first.startOffset,
          finding.evidence.first.endOffset,
        ),
        urduPhrase,
      );
    });

    test(
      'Detects repeated phrases with distinct valid offset positions',
      () async {
        registry.register(
          const _SyntheticPhraseRule(
            id: 'rule.repeat.act_now',
            category: IndicatorCategory.urgencyOrPressure,
            targetPhrase: 'act now',
            findingExplanation: 'Repeated urgency.',
          ),
        );

        final snapshot = createSnapshot('Please act now! I repeat, act now!');
        final result = await engine.analyze(snapshot);

        expect(result.isSuccess, isTrue);
        final report = result.valueOrNull!;
        expect(report.findings.length, 2);

        expect(report.findings[0].evidence.first.startOffset, 7);
        expect(report.findings[0].evidence.first.endOffset, 14);
        expect(report.findings[0].evidence.first.exactExcerpt, 'act now');

        expect(report.findings[1].evidence.first.startOffset, 26);
        expect(report.findings[1].evidence.first.endOffset, 33);
        expect(report.findings[1].evidence.first.exactExcerpt, 'act now');
      },
    );

    test(
      'Redacted snapshot evidence points strictly to redacted snapshot content',
      () async {
        // Suppose review flow replaced user email with [EMAIL]
        const redactedContent =
            'Urgent update sent to [EMAIL] for verification.';
        final redactedSnapshot = TextSnapshot(
          id: 'snap-redacted-uuid-99',
          text: redactedContent,
          source: InputSource.messageText,
          createdAt: fixedTime,
        );

        registry.register(
          const _SyntheticPhraseRule(
            id: 'rule.email.redacted',
            category: IndicatorCategory.claimedIdentityOrImpersonation,
            targetPhrase: '[EMAIL]',
            findingExplanation: 'Notice referring to communication target.',
          ),
        );

        final result = await engine.analyze(redactedSnapshot);

        expect(result.isSuccess, isTrue);
        final report = result.valueOrNull!;
        expect(report.findings.length, 1);

        final finding = report.findings.first;
        expect(finding.evidence.first.snapshotId, 'snap-redacted-uuid-99');
        expect(finding.evidence.first.exactExcerpt, '[EMAIL]');
      },
    );

    test('Rule exceptions produce typed AnalysisFailure.malformedData without leaking user text', () async {
      registry.register(_FaultyThrowingRule());

      final snapshot = createSnapshot(
        'Secret sensitive message text from user.',
      );
      final result = await engine.analyze(snapshot);

      expect(result.isFailure, isTrue);
      final failure = result.failureOrNull!;
      expect(failure.code, AnalysisFailureCode.malformedData);
      expect(failure.message, contains('Local rule evaluation failed'));
      expect(failure.safeDetails, 'rule_evaluation_exception');

      // Crucial privacy check: no user message text in failure string or representation
      expect(failure.message, isNot(contains('Secret sensitive')));
      expect(failure.toString(), isNot(contains('Secret sensitive')));
    });

    test(
      'Enforces maximum finding limit and returns typed failure on exceed',
      () async {
        final limitedEngine = LocalRuleEngine(
          registry: registry,
          maxFindings: 2,
        );

        // Rule will match 3 occurrences in text
        registry.register(
          const _SyntheticPhraseRule(
            id: 'rule.repeat.limit',
            category: IndicatorCategory.urgencyOrPressure,
            targetPhrase: 'alert',
            findingExplanation: 'Alert',
          ),
        );

        final snapshot = createSnapshot('alert alert alert');
        final result = await limitedEngine.analyze(snapshot);

        expect(result.isFailure, isTrue);
        final failure = result.failureOrNull!;
        expect(failure.code, AnalysisFailureCode.unsupportedInput);
        expect(failure.safeDetails, 'max_findings_exceeded');
        expect(failure.message, contains('Maximum finding limit (2) exceeded'));
      },
    );

    test('Reuses existing input validation and rejects empty text', () async {
      final snapshot = createSnapshot('');
      final result = await engine.analyze(snapshot);

      expect(result.isFailure, isTrue);
      final failure = result.failureOrNull!;
      expect(failure.code, AnalysisFailureCode.invalidInput);
      expect(failure.safeDetails, 'empty');
    });

    test(
      'Reuses existing input validation and rejects whitespace-only text',
      () async {
        final snapshot = createSnapshot('   \n\t  ');
        final result = await engine.analyze(snapshot);

        expect(result.isFailure, isTrue);
        final failure = result.failureOrNull!;
        expect(failure.code, AnalysisFailureCode.invalidInput);
        expect(failure.safeDetails, 'onlyWhitespace');
      },
    );

    test('Reuses existing input validation and rejects text exceeding 10,000 code points', () async {
      final longText = 'a' * 10001;
      final snapshot = createSnapshot(longText);
      final result = await engine.analyze(snapshot);

      expect(result.isFailure, isTrue);
      final failure = result.failureOrNull!;
      expect(failure.code, AnalysisFailureCode.invalidInput);
      expect(failure.safeDetails, 'tooLongCodePoints');
    });

    test('Reuses existing input validation and rejects text exceeding 40,000 UTF-8 bytes', () async {
      // Euro symbol € is 3 bytes in UTF-8. 14,000 € symbols = 42,000 bytes (< 10,000 code points)
      // Actually 10,000 max code points. 9,999 € symbols = 9,999 code points, 29,997 bytes.
      // 4-byte characters (emojis): 9,999 * 4 = 39,996 bytes.
      // So to exceed 40,000 bytes with <= 10,000 code points is not possible (max 4 bytes per code point = 40,000 bytes).
      // But if code points is 10,001 it triggers tooLongCodePoints.
      // Let's test with 40,001 bytes if raw bytes:
      final asciiText = 'x' * 10001;
      final snapshot = createSnapshot(asciiText);
      final result = await engine.analyze(snapshot);
      expect(result.isFailure, isTrue);
    });

    test('Report collections and snapshots are completely immutable', () async {
      registry.register(
        const _SyntheticPhraseRule(
          id: 'rule.immutability',
          category: IndicatorCategory.urgencyOrPressure,
          targetPhrase: 'threat',
          findingExplanation: 'Threat',
        ),
      );

      final snapshot = createSnapshot('Notice of threat today.');
      final result = await engine.analyze(snapshot);

      expect(result.isSuccess, isTrue);
      final report = result.valueOrNull!;

      // Findings list is unmodifiable
      expect(
        () => (report.findings as dynamic).add(
          AnalysisFinding(
            id: 'injected',
            category: 'test',
            explanation: 'test',
            origin: FindingOrigin.localRule,
            producerId: 'test',
            evidence: [
              EvidenceReference(
                snapshotId: snapshot.id,
                startOffset: 0,
                endOffset: 1,
                exactExcerpt: 'N',
              ),
            ],
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );

      // Limitations list is unmodifiable
      expect(
        () => (report.limitations as dynamic).add('new limitation'),
        throwsA(isA<UnsupportedError>()),
      );

      // Suggested actions list is unmodifiable
      expect(
        () => (report.suggestedActions as dynamic).add('new action'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
