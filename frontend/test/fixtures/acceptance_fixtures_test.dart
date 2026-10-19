import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/core_warning_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_engine.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_registry.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_analysis_pipeline.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/domain/services/url_inspection_service.dart';
import 'package:trustcue_mobile/features/input/domain/services/local_sensitive_data_detector.dart';

void main() {
  late LocalRuleEngine ruleEngine;
  late LocalRuleRegistry registry;
  late LocalAssessmentSynthesizer synthesizer;
  late LocalAnalysisPipeline pipeline;
  const urlService = UrlInspectionService();
  const piiDetector = LocalSensitiveDataDetector();

  setUp(() {
    final rules = [
      ...CoreWarningRuleCatalog.createRules(),
      ...LocalRuleCatalog.createExtendedRules(),
    ];
    registry = LocalRuleRegistry(rules);
    ruleEngine = LocalRuleEngine(registry: registry);
    synthesizer = LocalAssessmentSynthesizer();
    pipeline = LocalAnalysisPipeline(
      engine: ruleEngine,
      synthesizer: synthesizer,
      registry: registry,
    );
  });

  TextSnapshot createSnapshot(String text, {String id = 'snap-test'}) {
    return TextSnapshot(
      id: id,
      text: text,
      source: InputSource.messageText,
      createdAt: DateTime.utc(2026, 10, 18, 12, 0),
    );
  }

  group('Fixtures Acceptance: Text Messages & Benign Counterexamples', () {
    final benignCases = <Map<String, String>>[
      {
        'id': 'BEN-01',
        'title': 'Family dinner check',
        'text': 'Hi Mom, what time is dinner tonight? Can you please ask Dad to pick up milk on his way home from work? Thanks!',
      },
      {
        'id': 'BEN-02',
        'title': 'Doctor appointment confirmation',
        'text': 'Your appointment with Dr. Malik is confirmed for tomorrow, Tuesday Oct 19 at 11:30 AM at Maroof Hospital. Please arrive 15 minutes early.',
      },
      {
        'id': 'BEN-03',
        'title': 'Work calendar reminder',
        'text': 'Team meeting rescheduled to 3 PM in Conference Room B. Please review the quarterly presentation slides beforehand.',
      },
      {
        'id': 'BEN-04',
        'title': 'University study group update',
        'text': 'Hey, I sent you the project files via university email. Let me know when you receive them so we can submit by Monday.',
      },
      {
        'id': 'AMB-01',
        'title': 'Delivery notification without links',
        'text': 'Your package has been delivered to your front porch. Carrier tracking #9400100000000000000000.',
      },
      {
        'id': 'AMB-02',
        'title': 'Gym membership notice',
        'text': 'Hi, this is a reminder from your gym that your monthly membership renews on the 1st. Visit the front desk if you have any questions.',
      },
    ];

    for (final b in benignCases) {
      test(
        'Evaluates ${b['id']} (${b['title']}) without false-positive scam alarms',
        () async {
          final snapshot = createSnapshot(b['text']!, id: b['id']!);
          final result = await pipeline.process(snapshot);
          expect(result.isSuccess, isTrue);
          final assessment = result.valueOrNull!;
          expect(
            assessment.outcomeState,
            equals(AssessmentOutcomeState.noIndicatorsMatched),
          );
          expect(assessment.groupedIndicators, isEmpty);
          expect(assessment.uncertaintyNotes, isNotEmpty);
        },
      );
    }

    test(
      'Loads and evaluates Scam Text Messages from fixture folder',
      () async {
        final file = File(
          r'd:\ALL DATA\PROJECTS\TrustCue\Testing Data\Scam Text Messages.txt',
        );
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();
        final blocks = content.split(RegExp(r'\n\s*\n'));

        var evaluatedCount = 0;
        var indicatorsFoundCount = 0;
        for (var i = 0; i < blocks.length && i < 26; i++) {
          final lines = blocks[i]
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();
          if (lines.length >= 2) {
            final title = lines[0];
            final rawMsg = lines[1];
            // Test with normalized realistic URL if defanged
            final msgText = rawMsg
                .replaceAll('hxxps://', 'https://')
                .replaceAll('[.]', '.');
            final snapshot = createSnapshot(msgText, id: 'fixture-scam-$i');
            final result = await pipeline.process(snapshot);
            expect(
              result.isSuccess,
              isTrue,
              reason: 'Failed evaluating block $i: $title',
            );
            final assessment = result.valueOrNull!;

            final isMatched =
                assessment.outcomeState ==
                AssessmentOutcomeState.indicatorsDetected;
            if (isMatched) {
              indicatorsFoundCount++;
              for (final group in assessment.groupedIndicators) {
                for (final f in group.findings) {
                  for (final span in f.evidence) {
                    expect(span.startOffset, greaterThanOrEqualTo(0));
                    expect(
                      span.endOffset,
                      lessThanOrEqualTo(snapshot.text.length),
                    );
                    final excerpt = snapshot.text.substring(
                      span.startOffset,
                      span.endOffset,
                    );
                    expect(
                      excerpt,
                      equals(span.exactExcerpt),
                      reason:
                          'Excerpt mismatch in $title: ${span.exactExcerpt}',
                    );
                  }
                }
              }
            }
            evaluatedCount++;
          }
        }
        expect(evaluatedCount, greaterThanOrEqualTo(20));
        expect(indicatorsFoundCount, greaterThanOrEqualTo(15));
      },
    );
  });

  group('Fixtures Acceptance: URLs and Links', () {
    test('Inspects all links from Links.txt without crashing or making network calls', () {
      final file = File(
        r'd:\ALL DATA\PROJECTS\TrustCue\Testing Data\Links.txt',
      );
      expect(file.existsSync(), isTrue);
      final lines = file
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      var inspectedCount = 0;
      var ipCount = 0;
      for (final line in lines) {
        if (line.startsWith('http://') || line.startsWith('https://')) {
          final url = line.split(' ')[0].trim();
          final res = urlService.inspect(url);
          expect(res.rawInput, equals(url));
          if (res.isIpAddress) {
            ipCount++;
          }
          inspectedCount++;
        }
      }
      expect(inspectedCount, greaterThanOrEqualTo(40));
      expect(ipCount, greaterThan(0));
    });

    test('Rejects dangerous schemes and malformed input safely', () {
      final dangerous = [
        'javascript:alert(1)',
        'data:text/html;base64,PHNjcmlwdD4=',
        'file:///etc/passwd',
        'intent://scan/#Intent;scheme=zxing;package=com.google.zxing.client.android;end',
      ];
      for (final d in dangerous) {
        final res = urlService.inspect(d);
        expect(
          res.isValid,
          isFalse,
          reason: 'Dangerous scheme should not be valid: $d',
        );
        expect(
          res.isLaunchable,
          isFalse,
          reason: 'Dangerous scheme should not be launchable: $d',
        );
      }
    });
  });

  group('Fixtures Acceptance: PII Redaction on Test Fixtures', () {
    test('Detects phone numbers, emails, and payment cards accurately', () {
      final testInput =
          'Please call 1-555-0100 or email support@example.com. Card 4532-0150-1234-5671.';
      final detections = piiDetector.detect(text: testInput, revision: 'rev-1');
      expect(detections.isNotEmpty, isTrue);
      final types = detections.map((d) => d.type.name).toSet();
      expect(types, contains('email'));
      expect(types, contains('phone'));
      expect(types, contains('paymentCard'));
    });
  });
}
