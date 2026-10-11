import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  group('AnalysisFinding Model Tests', () {
    final snapshot = TextSnapshot(
      id: 'snap-42',
      source: InputSource.messageText,
      text: 'Urgent: Click http://phishing.example.com immediately to unlock your account.',
      createdAt: DateTime.utc(2026, 10, 11),
    );

    final evidence1 = EvidenceReference(
      snapshotId: 'snap-42',
      startOffset: 0,
      endOffset: 6,
      exactExcerpt: 'Urgent',
    );

    final evidence2 = EvidenceReference(
      snapshotId: 'snap-42',
      startOffset: 14,
      endOffset: 41,
      exactExcerpt: 'http://phishing.example.com',
    );

    test('Valid construction with defensive copying of evidence', () {
      final evidenceList = [evidence1];
      final finding = AnalysisFinding(
        id: 'find-001',
        category: 'urgency_indicator',
        explanation:
            'Message creates artificial urgency to bypass critical thinking.',
        origin: FindingOrigin.localRule,
        producerId: 'rule.urgency.v1',
        evidence: evidenceList,
      );

      expect(finding.id, 'find-001');
      expect(finding.category, 'urgency_indicator');
      expect(finding.origin, FindingOrigin.localRule);
      expect(finding.producerId, 'rule.urgency.v1');
      expect(finding.evidence.length, 1);

      // Mutating source list does not affect finding
      evidenceList.add(evidence2);
      expect(finding.evidence.length, 1);

      // Mutating finding.evidence directly is prohibited
      expect(() => finding.evidence.add(evidence2), throwsUnsupportedError);
    });

    test('Rejects empty or whitespace-only required fields', () {
      expect(
        () => AnalysisFinding(
          id: '   ',
          category: 'cat',
          explanation: 'exp',
          origin: FindingOrigin.localRule,
          producerId: 'p1',
          evidence: [evidence1],
        ),
        throwsArgumentError,
      );

      expect(
        () => AnalysisFinding(
          id: 'f1',
          category: '',
          explanation: 'exp',
          origin: FindingOrigin.localRule,
          producerId: 'p1',
          evidence: [evidence1],
        ),
        throwsArgumentError,
      );

      expect(
        () => AnalysisFinding(
          id: 'f1',
          category: 'cat',
          explanation: '',
          origin: FindingOrigin.localRule,
          producerId: 'p1',
          evidence: [evidence1],
        ),
        throwsArgumentError,
      );

      expect(
        () => AnalysisFinding(
          id: 'f1',
          category: 'cat',
          explanation: 'exp',
          origin: FindingOrigin.localRule,
          producerId: '',
          evidence: [evidence1],
        ),
        throwsArgumentError,
      );

      expect(
        () => AnalysisFinding(
          id: 'f1',
          category: 'cat',
          explanation: 'exp',
          origin: FindingOrigin.localRule,
          producerId: 'p1',
          evidence: [],
        ),
        throwsArgumentError,
      );
    });

    test('Validates all attached evidence references against snapshot', () {
      final finding = AnalysisFinding(
        id: 'find-both',
        category: 'phishing_link',
        explanation: 'Untrusted link detected in message.',
        origin: FindingOrigin.localRule,
        producerId: 'rule.links.v1',
        evidence: [evidence1, evidence2],
      );

      expect(() => finding.validateAgainst(snapshot), returnsNormally);

      final mismatchedSnapshot = TextSnapshot(
        id: 'snap-OTHER',
        source: InputSource.messageText,
        text: 'Different text entirely.',
        createdAt: DateTime.utc(2026, 10, 11),
      );

      expect(
        () => finding.validateAgainst(mismatchedSnapshot),
        throwsArgumentError,
      );
    });

    test('Supports FindingOrigin enum variants', () {
      const origins = [FindingOrigin.localRule, FindingOrigin.remoteAi];
      for (final orig in origins) {
        final f = AnalysisFinding(
          id: 'f-${orig.name}',
          category: 'cat',
          explanation: 'exp',
          origin: orig,
          producerId: 'prod',
          evidence: [evidence1],
        );
        expect(f.origin, orig);
      }
    });

    test('Equality and hashCode respect finding contents', () {
      final f1 = AnalysisFinding(
        id: 'f1',
        category: 'cat',
        explanation: 'exp',
        origin: FindingOrigin.localRule,
        producerId: 'p1',
        evidence: [evidence1],
      );
      final f2 = AnalysisFinding(
        id: 'f1',
        category: 'cat',
        explanation: 'exp',
        origin: FindingOrigin.localRule,
        producerId: 'p1',
        evidence: [evidence1],
      );
      final f3 = AnalysisFinding(
        id: 'f1',
        category: 'cat',
        explanation: 'exp',
        origin: FindingOrigin.remoteAi,
        producerId: 'p1',
        evidence: [evidence1],
      );

      expect(f1, equals(f2));
      expect(f1.hashCode, equals(f2.hashCode));
      expect(f1, isNot(equals(f3)));
    });

    test('Safe toString does not expose explanation or sensitive text', () {
      final finding = AnalysisFinding(
        id: 'f-safe',
        category: 'credential_harvest',
        explanation: 'Secret OTP 123456 requested',
        origin: FindingOrigin.localRule,
        producerId: 'rule.otp.v1',
        evidence: [evidence1],
      );

      final str = finding.toString();
      expect(str, contains('f-safe'));
      expect(str, contains('credential_harvest'));
      expect(str, isNot(contains('123456')));
    });
  });
}
