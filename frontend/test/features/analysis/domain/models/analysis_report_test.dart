import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  group('AnalysisReport Model Tests', () {
    final snapshot = TextSnapshot(
      id: 'snap-rep-01',
      source: InputSource.messageText,
      text: 'Action required: verify your account at https://example.com/login',
      createdAt: DateTime.utc(2026, 10, 11, 10, 0),
    );

    final finding1 = AnalysisFinding(
      id: 'f-01',
      category: 'urgency_indicator',
      explanation: 'Action required language creates artificial pressure.',
      origin: FindingOrigin.localRule,
      producerId: 'rule.urgency.v1',
      evidence: [
        EvidenceReference(
          snapshotId: 'snap-rep-01',
          startOffset: 0,
          endOffset: 15,
          exactExcerpt: 'Action required',
        ),
      ],
    );

    final finding2 = AnalysisFinding(
      id: 'f-02',
      category: 'link_indicator',
      explanation: 'Message contains an unverified external link.',
      origin: FindingOrigin.localRule,
      producerId: 'rule.links.v1',
      evidence: [
        EvidenceReference(
          snapshotId: 'snap-rep-01',
          startOffset: 40,
          endOffset: 65,
          exactExcerpt: 'https://example.com/login',
        ),
      ],
    );

    test('Valid construction with defensive copying and UTC analyzedAt', () {
      final findings = [finding1];
      final limitations = ['Deterministic rules only.'];
      final actions = ['Contact the organization directly.'];
      final localTime = DateTime(2026, 10, 11, 11, 0);

      final report = AnalysisReport(
        id: 'rep-001',
        snapshot: snapshot,
        analyzedAt: localTime,
        findings: findings,
        limitations: limitations,
        suggestedActions: actions,
      );

      expect(report.id, 'rep-001');
      expect(report.schemaVersion, AnalysisReport.currentSchemaVersion);
      expect(report.snapshot, snapshot);
      expect(report.analyzedAt.isUtc, isTrue);
      expect(report.analyzedAt, localTime.toUtc());
      expect(report.findings.length, 1);
      expect(report.limitations.length, 1);
      expect(report.suggestedActions.length, 1);

      // Defensively copied - mutating inputs does not change report
      findings.add(finding2);
      limitations.add('Extra');
      actions.add('Extra');
      expect(report.findings.length, 1);
      expect(report.limitations.length, 1);
      expect(report.suggestedActions.length, 1);

      // Immutability - mutating report lists throws UnsupportedError
      expect(() => report.findings.add(finding2), throwsUnsupportedError);
      expect(() => report.limitations.add('New'), throwsUnsupportedError);
      expect(() => report.suggestedActions.add('New'), throwsUnsupportedError);
    });

    test('Empty findings list is valid and represents no findings (not a safe verdict)', () {
      final report = AnalysisReport(
        id: 'rep-clean',
        snapshot: snapshot,
        analyzedAt: DateTime.utc(2026, 10, 11, 12, 0),
        findings: const [],
        limitations: const [
          'No findings recorded by active rules. This is not a guarantee of safety.',
        ],
        suggestedActions: const [
          'Always verify through official channels if unsure.',
        ],
      );

      expect(report.findings, isEmpty);
      expect(report.limitations, isNotEmpty);
      expect(report.suggestedActions, isNotEmpty);
    });

    test('Rejects duplicate finding IDs in report', () {
      final duplicateFinding = AnalysisFinding(
        id: 'f-01', // Same ID as finding1
        category: 'another_category',
        explanation: 'Another explanation.',
        origin: FindingOrigin.localRule,
        producerId: 'rule.another.v1',
        evidence: [
          EvidenceReference(
            snapshotId: 'snap-rep-01',
            startOffset: 0,
            endOffset: 15,
            exactExcerpt: 'Action required',
          ),
        ],
      );

      expect(
        () => AnalysisReport(
          id: 'rep-dup',
          snapshot: snapshot,
          analyzedAt: DateTime.utc(2026, 10, 11),
          findings: [finding1, duplicateFinding],
          limitations: const [],
          suggestedActions: const [],
        ),
        throwsArgumentError,
      );
    });

    test('Rejects finding attached to a different snapshot ID', () {
      final wrongSnapshotFinding = AnalysisFinding(
        id: 'f-wrong',
        category: 'mismatch',
        explanation: 'Points to other snapshot',
        origin: FindingOrigin.localRule,
        producerId: 'rule.x.v1',
        evidence: [
          EvidenceReference(
            snapshotId: 'snap-DIFFERENT',
            startOffset: 0,
            endOffset: 5,
            exactExcerpt: 'Hello',
          ),
        ],
      );

      expect(
        () => AnalysisReport(
          id: 'rep-wrong-snap',
          snapshot: snapshot,
          analyzedAt: DateTime.utc(2026, 10, 11),
          findings: [wrongSnapshotFinding],
          limitations: const [],
          suggestedActions: const [],
        ),
        throwsArgumentError,
      );
    });

    test('Rejects empty report ID and unsupported schema version', () {
      expect(
        () => AnalysisReport(
          id: '',
          snapshot: snapshot,
          analyzedAt: DateTime.utc(2026, 10, 11),
          findings: const [],
          limitations: const [],
          suggestedActions: const [],
        ),
        throwsArgumentError,
      );

      expect(
        () => AnalysisReport(
          id: 'rep-bad-version',
          schemaVersion: 999, // Unsupported
          snapshot: snapshot,
          analyzedAt: DateTime.utc(2026, 10, 11),
          findings: const [],
          limitations: const [],
          suggestedActions: const [],
        ),
        throwsArgumentError,
      );
    });

    test('Safe toString does not expose raw text or findings details', () {
      final report = AnalysisReport(
        id: 'rep-safe',
        snapshot: snapshot,
        analyzedAt: DateTime.utc(2026, 10, 11),
        findings: [finding1],
        limitations: const ['Limitation A'],
        suggestedActions: const ['Action B'],
      );

      final str = report.toString();
      expect(str, contains('rep-safe'));
      expect(str, contains('snapshotId: snap-rep-01'));
      expect(str, contains('findingsCount: 1'));
      expect(str, isNot(contains('Action required')));
    });

    test('Equality and hashCode', () {
      final r1 = AnalysisReport(
        id: 'rep-eq',
        snapshot: snapshot,
        analyzedAt: DateTime.utc(2026, 10, 11, 12, 0),
        findings: [finding1],
        limitations: const ['lim'],
        suggestedActions: const ['act'],
      );

      final r2 = AnalysisReport(
        id: 'rep-eq',
        snapshot: snapshot,
        analyzedAt: DateTime.utc(2026, 10, 11, 12, 0),
        findings: [finding1],
        limitations: const ['lim'],
        suggestedActions: const ['act'],
      );

      final r3 = AnalysisReport(
        id: 'rep-diff',
        snapshot: snapshot,
        analyzedAt: DateTime.utc(2026, 10, 11, 12, 0),
        findings: const [],
        limitations: const ['lim'],
        suggestedActions: const ['act'],
      );

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
      expect(r1, isNot(equals(r3)));
    });
  });
}
