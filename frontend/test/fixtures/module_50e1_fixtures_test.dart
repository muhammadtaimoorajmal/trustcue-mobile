import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/core_warning_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_analysis_pipeline.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_engine.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_registry.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/domain/services/url_inspection_service.dart';

File _resolveFixtureFile(String fileName) {
  final candidatePaths = [
    'test/fixtures/data/$fileName',
    'frontend/test/fixtures/data/$fileName',
    '../test/fixtures/data/$fileName',
    '../../test/fixtures/data/$fileName',
    'D:/ALL DATA/PROJECTS/TrustCue/Testing Data/$fileName',
    'd:/ALL DATA/PROJECTS/TrustCue/Testing Data/$fileName',
  ];
  for (final path in candidatePaths) {
    final file = File(path);
    if (file.existsSync()) {
      return file;
    }
  }
  throw StateError(
    'Fixture file not found: $fileName across candidate paths: $candidatePaths',
  );
}

class ScoredScamFixture {
  final String id;
  final String title;
  final String rawText;
  final String normalizedText;
  final String notes;

  ScoredScamFixture({
    required this.id,
    required this.title,
    required this.rawText,
    required this.normalizedText,
    required this.notes,
  });
}

List<ScoredScamFixture> loadAll26ScamFixtures() {
  final file = _resolveFixtureFile('Scam Text Messages.txt');
  final rawContent = file.readAsStringSync().replaceAll('\r\n', '\n');
  final blocks = rawContent.split(RegExp(r'\n\n+'));

  final fixtures = <ScoredScamFixture>[];
  var index = 1;

  for (final block in blocks) {
    final lines = block
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length >= 2 && index <= 26) {
      final title = lines[0];
      final msg = lines[1];
      final notes = lines.length > 2 ? lines.sublist(2).join(' ') : '';
      final norm = msg
          .replaceAll('hxxps://', 'https://')
          .replaceAll('hxxp://', 'http://')
          .replaceAll('[.]', '.');
      final idStr = 'MSG-${index.toString().padLeft(3, '0')}';
      fixtures.add(
        ScoredScamFixture(
          id: idStr,
          title: title,
          rawText: msg,
          normalizedText: norm,
          notes: notes,
        ),
      );
      index++;
    }
  }
  return fixtures;
}

class UrlFixture {
  final String id;
  final String rawLine;
  final String url;
  final String? annotation;

  UrlFixture({
    required this.id,
    required this.rawLine,
    required this.url,
    this.annotation,
  });
}

List<UrlFixture> loadAll57UrlFixtures() {
  final file = _resolveFixtureFile('Links.txt');
  final rawLines = file
      .readAsLinesSync()
      .map((l) => l.trim())
      .where(
        (l) =>
            l.isNotEmpty &&
            (l.startsWith('http://') || l.startsWith('https://')),
      )
      .toList();

  final fixtures = <UrlFixture>[];
  var index = 1;
  for (final line in rawLines) {
    final spaceIdx = line.indexOf(' ');
    final String url;
    final String? annotation;
    if (spaceIdx != -1) {
      url = line.substring(0, spaceIdx).trim();
      annotation = line.substring(spaceIdx + 1).trim();
    } else {
      url = line;
      annotation = null;
    }
    final idStr = 'URL-${index.toString().padLeft(3, '0')}';
    fixtures.add(
      UrlFixture(id: idStr, rawLine: line, url: url, annotation: annotation),
    );
    index++;
  }
  return fixtures;
}

void main() {
  late LocalRuleEngine ruleEngine;
  late LocalRuleRegistry registry;
  late LocalAssessmentSynthesizer synthesizer;
  late LocalAnalysisPipeline pipeline;
  const urlService = UrlInspectionService();

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
      createdAt: DateTime.utc(2026, 10, 19, 12, 0),
    );
  }

  group('Module 50E.1: Comprehensive Fixture Inventory Verification', () {
    test(
      'Inventory exactly 26 scam text fixtures from Scam Text Messages.txt',
      () {
        final fixtures = loadAll26ScamFixtures();
        expect(fixtures.length, equals(26));
        expect(fixtures.first.id, equals('MSG-001'));
        expect(fixtures.last.id, equals('MSG-026'));
        expect(fixtures[2].rawText, contains(r'$1.99'));
      },
    );

    test('Inventory exactly 57 URL fixtures from Links.txt', () {
      final fixtures = loadAll57UrlFixtures();
      expect(fixtures.length, equals(57));
      expect(fixtures.first.id, equals('URL-001'));
      expect(fixtures.last.id, equals('URL-057'));
    });

    test('Inventory 6 benign counterexamples (BEN-001 to BEN-004, AMB-001 to AMB-002)', () {
      final benignCases = [
        'BEN-001: Family dinner check',
        'BEN-002: Doctor appointment confirmation',
        'BEN-003: Work calendar reminder',
        'BEN-004: University study group update',
        'AMB-001: Delivery notification without links',
        'AMB-002: Gym membership notice',
      ];
      expect(benignCases.length, equals(6));
    });
  });

  group('Module 50E.1: Logic-Level Evaluation of All 26 Scam Messages', () {
    final scamFixtures = loadAll26ScamFixtures();

    for (final fixture in scamFixtures) {
      test(
        'Evaluates ${fixture.id} (${fixture.title}) with evidence span verification',
        () async {
          final snapshot = createSnapshot(
            fixture.normalizedText,
            id: fixture.id,
          );
          final result = await pipeline.process(snapshot);
          expect(
            result.isSuccess,
            isTrue,
            reason: 'Pipeline failed on ${fixture.id}',
          );

          final assessment = result.valueOrNull!;
          // Verify evidence spans
          for (final group in assessment.groupedIndicators) {
            expect(group.categoryLabel, isNotEmpty);
            for (final finding in group.findings) {
              expect(finding.producerId, isNotEmpty);
              expect(finding.explanation, isNotEmpty);
              for (final evidence in finding.evidence) {
                expect(evidence.startOffset, greaterThanOrEqualTo(0));
                expect(
                  evidence.endOffset,
                  lessThanOrEqualTo(snapshot.text.length),
                );
                expect(evidence.startOffset, lessThan(evidence.endOffset));
                final extracted = snapshot.text.substring(
                  evidence.startOffset,
                  evidence.endOffset,
                );
                expect(
                  extracted,
                  equals(evidence.exactExcerpt),
                  reason:
                      'Span mismatch in ${fixture.id} for rule ${finding.producerId}',
                );
              }
            }
          }
        },
      );
    }
  });

  group('Module 50E.1: Logic-Level Evaluation of Benign Counterexamples', () {
    final benignCases = <Map<String, String>>[
      {
        'id': 'BEN-001',
        'title': 'Family dinner check',
        'text': 'Hi Mom, what time is dinner tonight? Can you please ask Dad to pick up milk on his way home from work? Thanks!',
      },
      {
        'id': 'BEN-002',
        'title': 'Doctor appointment confirmation',
        'text': 'Your appointment with Dr. Malik is confirmed for tomorrow, Tuesday Oct 19 at 11:30 AM at Maroof Hospital. Please arrive 15 minutes early.',
      },
      {
        'id': 'BEN-003',
        'title': 'Work calendar reminder',
        'text': 'Team meeting rescheduled to 3 PM in Conference Room B. Please review the quarterly presentation slides beforehand.',
      },
      {
        'id': 'BEN-004',
        'title': 'University study group update',
        'text': 'Hey, I sent you the project files via university email. Let me know when you receive them so we can submit by Monday.',
      },
      {
        'id': 'AMB-001',
        'title': 'Delivery notification without links',
        'text': 'Your package has been delivered to your front porch. Carrier tracking #9400100000000000000000.',
      },
      {
        'id': 'AMB-002',
        'title': 'Gym membership notice',
        'text': 'Hi, this is a reminder from your gym that your monthly membership renews on the 1st. Visit the front desk if you have any questions.',
      },
    ];

    for (final b in benignCases) {
      test(
        'Evaluates ${b['id']} (${b['title']}) produces no-match outcome',
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
  });

  group('Module 50E.1: Logic-Level Evaluation of All 57 URL Fixtures', () {
    final urlFixtures = loadAll57UrlFixtures();

    for (final uf in urlFixtures) {
      test('Inspects ${uf.id}: ${uf.url}', () {
        final res = urlService.inspect(uf.url);
        expect(res.rawInput, equals(uf.url));

        if (res.isValid) {
          expect(res.isLaunchable, isTrue);
          expect(res.host, isNotEmpty);
          expect(res.scheme, isIn(['http', 'https']));
          expect(res.observations, isNotNull);
        } else {
          // If rejected, rejectionCode and rejectionReason must be populated
          expect(res.rejectionCode, isNotNull);
          expect(res.rejectionReason, isNotEmpty);
        }
      });
    }
  });

  group('Module 50E.1: Real Input Fidelity & Special Character Preservation', () {
    test(r'Preserves currency symbols and literal dollar amounts ($1.99, $487.32, €50, £100)', () async {
      const text =
          r'USPS: Pay $1.99 redelivery fee or $487.32 penalty (€50 or £100)';
      final snapshot = createSnapshot(text, id: 'currency-fidelity');
      expect(snapshot.text, equals(text));

      final result = await pipeline.process(snapshot);
      expect(result.isSuccess, isTrue);
      final assessment = result.valueOrNull!;
      expect(
        assessment.outcomeState,
        equals(AssessmentOutcomeState.indicatorsDetected),
      );

      // Check evidence preserves literal dollar signs
      bool foundDollarExcerpt = false;
      for (final g in assessment.groupedIndicators) {
        for (final f in g.findings) {
          for (final ev in f.evidence) {
            if (ev.exactExcerpt.contains(r'$')) {
              foundDollarExcerpt = true;
            }
          }
        }
      }
      expect(
        foundDollarExcerpt,
        isTrue,
        reason: 'Expected evidence excerpt with dollar sign',
      );
    });

    test('Preserves multiline text with newlines and punctuation untouched', () async {
      const multiline =
          "Line 1: Urgent threat!\nLine 2: Verify at https://bank-verify.example\nLine 3: Reply Y/N #ref?q=1&v=2";
      final snapshot = createSnapshot(multiline, id: 'multiline-fidelity');
      expect(snapshot.text, equals(multiline));
      expect(snapshot.text.contains('\n'), isTrue);

      final result = await pipeline.process(snapshot);
      expect(result.isSuccess, isTrue);
    });

    test('Preserves Urdu / non-Latin Unicode text without encoding distortion', () async {
      const urduText =
          'آپ کا بینک اکاؤنٹ معطل کر دیا گیا ہے۔ فوری تصدیق کریں: https://bank.example';
      final snapshot = createSnapshot(urduText, id: 'urdu-fidelity');
      expect(snapshot.text, equals(urduText));

      final result = await pipeline.process(snapshot);
      expect(result.isSuccess, isTrue);
    });

    test('Preserves URL query parameters, fragments, and defanged syntax', () {
      const complexUrl = 'https://example.com/checkout?id=99&ref=secure#token';
      final res = urlService.inspect(complexUrl);
      expect(res.isValid, isTrue);
      expect(res.query, equals('id=99&ref=secure'));
      expect(res.fragment, equals('token'));
      expect(res.path, equals('/checkout'));
    });
  });
}
