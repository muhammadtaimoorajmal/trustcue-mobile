import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/indicator_category.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/link_structural_rule.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/evidence_validator.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  late LinkStructuralRule rule;

  setUp(() {
    rule = LinkStructuralRule();
  });

  TextSnapshot createSnapshot(String text) {
    return TextSnapshot(
      id: 'snap-link-1',
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 14, 12, 0),
    );
  }

  group('LinkStructuralRule metadata', () {
    test('declares stable ID, version, category, and limitations', () {
      expect(rule.id, 'rule.link.structural_risk');
      expect(rule.version, 1);
      expect(rule.category, IndicatorCategory.linkStructuralIndicators);
      expect(rule.supportedLanguages, contains('*'));
      expect(rule.limitations, isNotEmpty);
      expect(
        rule.limitations.any((l) => l.contains('unformatted text snapshots')),
        isTrue,
      );
    });
  });

  group('LinkStructuralRule positive structural anomaly detections', () {
    test('detects numerical IP address host', () {
      final snapshot = createSnapshot(
        'Please log in at http://192.168.1.100/admin now.',
      );
      final findings = rule.evaluate(snapshot);

      expect(findings, hasLength(1));
      final finding = findings.first;
      expect(finding.category, IndicatorCategory.linkStructuralIndicators.id);
      expect(finding.producerId, rule.id);
      expect(finding.explanation, contains('numerical IP address'));
      expect(finding.explanation, contains('192.168.1.100'));

      // Validate evidence offsets
      final excerpt = snapshot.text.substring(
        finding.evidence.first.startOffset,
        finding.evidence.first.endOffset,
      );
      expect(excerpt, 'http://192.168.1.100/admin');
      expect(
        () => EvidenceValidator.validateFinding(finding, snapshot),
        returnsNormally,
      );
    });

    test('detects user-info credentials without echoing sensitive data', () {
      final snapshot = createSnapshot(
        'Click here: http://admin:supersecret123@evil-host.com/login to verify.',
      );
      final findings = rule.evaluate(snapshot);

      expect(findings, hasLength(1));
      final finding = findings.first;
      expect(
        finding.explanation,
        contains('embedded user information before the host'),
      );
      expect(finding.explanation, contains('evil-host.com'));
      // Must NOT leak user or password in explanation
      expect(finding.explanation, isNot(contains('admin')));
      expect(finding.explanation, isNot(contains('supersecret123')));

      final excerpt = snapshot.text.substring(
        finding.evidence.first.startOffset,
        finding.evidence.first.endOffset,
      );
      expect(excerpt, 'http://admin:supersecret123@evil-host.com/login');
      expect(
        () => EvidenceValidator.validateFinding(finding, snapshot),
        returnsNormally,
      );
    });

    test('detects internationalized punycode label in host', () {
      final snapshot = createSnapshot(
        'Security update available at https://xn--e1afmkfd.xn--p1ai/update.',
      );
      final findings = rule.evaluate(snapshot);

      expect(findings, hasLength(1));
      final finding = findings.first;
      expect(finding.explanation, contains('punycode'));
      expect(
        () => EvidenceValidator.validateFinding(finding, snapshot),
        returnsNormally,
      );
    });

    test('detects non-standard network ports', () {
      final snapshot = createSnapshot(
        'Admin console accessible at http://example.com:8080/dashboard.',
      );
      final findings = rule.evaluate(snapshot);

      expect(findings, hasLength(1));
      final finding = findings.first;
      expect(
        finding.explanation,
        contains('non-standard network port (:8080)'),
      );
      expect(
        () => EvidenceValidator.validateFinding(finding, snapshot),
        returnsNormally,
      );
    });

    test('detects open destination redirection query parameter', () {
      final snapshot = createSnapshot(
        'Sign in: https://legit-site.com/auth?redirect=https://phishing.net/steal.',
      );
      final findings = rule.evaluate(snapshot);

      expect(findings, hasLength(1));
      final finding = findings.first;
      expect(finding.explanation, contains('destination redirection'));
      expect(finding.explanation, contains('redirect'));
      expect(
        () => EvidenceValidator.validateFinding(finding, snapshot),
        returnsNormally,
      );
    });
  });

  group('LinkStructuralRule punctuation and parenthesis handling', () {
    test('trims trailing sentence punctuation cleanly', () {
      final snapshot = createSnapshot(
        'Check this: http://10.0.0.1/status, and http://10.0.0.2:8443/api!',
      );
      final findings = rule.evaluate(snapshot);

      expect(findings, hasLength(2));
      final excerpt1 = snapshot.text.substring(
        findings[0].evidence.first.startOffset,
        findings[0].evidence.first.endOffset,
      );
      expect(excerpt1, 'http://10.0.0.1/status');

      final excerpt2 = snapshot.text.substring(
        findings[1].evidence.first.startOffset,
        findings[1].evidence.first.endOffset,
      );
      expect(excerpt2, 'http://10.0.0.2:8443/api');
    });

    test('correctly handles balanced vs unbalanced parentheses', () {
      // Unbalanced closing paren from prose: should be stripped
      final snapshot1 = createSnapshot('(see http://192.168.1.1/router)');
      final findings1 = rule.evaluate(snapshot1);
      expect(findings1, hasLength(1));
      final excerpt1 = snapshot1.text.substring(
        findings1.first.evidence.first.startOffset,
        findings1.first.evidence.first.endOffset,
      );
      expect(excerpt1, 'http://192.168.1.1/router');

      // Balanced parentheses inside URL path: should be preserved
      final snapshot2 = createSnapshot(
        'Check http://192.168.1.1/wiki/Page_(v1)',
      );
      final findings2 = rule.evaluate(snapshot2);
      expect(findings2, hasLength(1));
      final excerpt2 = snapshot2.text.substring(
        findings2.first.evidence.first.startOffset,
        findings2.first.evidence.first.endOffset,
      );
      expect(excerpt2, 'http://192.168.1.1/wiki/Page_(v1)');
    });
  });

  group('LinkStructuralRule negative cases and standard URLs', () {
    test('does not flag standard benign HTTPS or HTTP URLs', () {
      final snapshot = createSnapshot(
        'Visit https://flutter.dev/docs and https://dart.dev/guides for learning materials.',
      );
      final findings = rule.evaluate(snapshot);
      expect(findings, isEmpty);
    });

    test(
      'does not flag standard query parameters or fragments as deception',
      () {
        final snapshot = createSnapshot(
          'Search at https://example.com/search?q=flutter&page=2#top for results.',
        );
        final findings = rule.evaluate(snapshot);
        expect(findings, isEmpty);
      },
    );

    test('does not flag default ports :80 and :443', () {
      final snapshot = createSnapshot(
        'Standard ports: http://example.com:80/ and https://example.com:443/ are standard.',
      );
      final findings = rule.evaluate(snapshot);
      expect(findings, isEmpty);
    });

    test(
      'handles malformed URL candidates without crashing or hiding findings',
      () {
        final snapshot = createSnapshot(
          'Invalid http:// alone, and http://192.168.1.1/valid is valid.',
        );
        final findings = rule.evaluate(snapshot);
        expect(findings, hasLength(1));
        final excerpt = snapshot.text.substring(
          findings.first.evidence.first.startOffset,
          findings.first.evidence.first.endOffset,
        );
        expect(excerpt, 'http://192.168.1.1/valid');
      },
    );
  });

  group('LinkStructuralRule unicode and multiple URLs', () {
    test('handles emojis and Urdu text preceding URLs accurately', () {
      final snapshot = createSnapshot(
        '🌐 ویب سائٹ لنک: http://192.168.0.1/setup',
      );
      final findings = rule.evaluate(snapshot);

      expect(findings, hasLength(1));
      expect(
        () => EvidenceValidator.validateFinding(findings.first, snapshot),
        returnsNormally,
      );
      final excerpt = snapshot.text.substring(
        findings.first.evidence.first.startOffset,
        findings.first.evidence.first.endOffset,
      );
      expect(excerpt, 'http://192.168.0.1/setup');
    });
  });
}
