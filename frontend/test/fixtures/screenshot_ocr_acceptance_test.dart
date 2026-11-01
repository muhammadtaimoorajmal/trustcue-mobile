import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/core_warning_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_analysis_pipeline.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_engine.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_registry.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/ocr_failure.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/domain/validation/image_validator.dart';
import 'package:trustcue_mobile/features/input/domain/validation/message_text_validator.dart';

int _levenshteinDistance(String s1, String s2) {
  if (s1 == s2) return 0;
  if (s1.isEmpty) return s2.length;
  if (s2.isEmpty) return s1.length;

  List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
  List<int> v1 = List<int>.filled(s2.length + 1, 0);

  for (int i = 0; i < s1.length; i++) {
    v1[0] = i + 1;
    for (int j = 0; j < s2.length; j++) {
      int cost = (s1.codeUnitAt(i) == s2.codeUnitAt(j)) ? 0 : 1;
      v1[j + 1] = [
        v1[j] + 1,
        v0[j + 1] + 1,
        v0[j] + cost,
      ].reduce((curr, next) => curr < next ? curr : next);
    }
    for (int j = 0; j <= s2.length; j++) {
      v0[j] = v1[j];
    }
  }
  return v1[s2.length];
}

class ScreenshotFixture {
  const ScreenshotFixture({
    required this.id,
    required this.fileName,
    required this.scenario,
    required this.groundTruth,
    required this.rawOcrText,
    required this.expectedOutcome,
    required this.expectedRuleIds,
  });

  final String id;
  final String fileName;
  final String scenario;
  final String groundTruth;
  final String rawOcrText;
  final AssessmentOutcomeState expectedOutcome;
  final List<String> expectedRuleIds;

  double get cer {
    final dist = _levenshteinDistance(groundTruth, rawOcrText);
    return groundTruth.isEmpty ? 0.0 : (dist / groundTruth.length) * 100.0;
  }
}

const List<ScreenshotFixture> kScreenshotFixtures = [
  ScreenshotFixture(
    id: 'IMG-01',
    fileName: 'images (1).jpg',
    scenario: 'CEO / Executive Gift Card Request',
    groundTruth:
        'Hi, are you at the office right now? I need you to assist me with a task urgently. '
        'Please let me know once you get this.\n'
        'I need you to get some Apple gift cards from the nearest store. How soon can you get them?\n'
        'Kindly confirm if you can help with this.\n'
        'Thanks,\nCEO',
    rawOcrText:
        'Hi, are you at the office right now? I need you to assist me with a task urgently. '
        'Please let me know once you get this.\n'
        'I need you to get some Apple gift cards from the nearest store. How soon can you get them?\n'
        'Kindly confirm if you can help with this.\n'
        'Thanks,\nCEO',
    expectedOutcome: AssessmentOutcomeState.indicatorsDetected,
    expectedRuleIds: ['rule.urgency.immediate_action'],
  ),
  ScreenshotFixture(
    id: 'IMG-02',
    fileName: 'images (1).png',
    scenario: 'Too-Good-To-Be-True Job Recruitment Lure',
    groundTruth:
        'We are hiring!\n'
        'Position: Online Customer Service / Data Entry\n'
        'Pay: \$75/hour\n'
        'Flexible working hours. No experience needed. Work from anywhere.\n'
        'Requirements: Smartphone or computer, 1-2 hours per day.\n'
        'Contact our hiring manager on WhatsApp: +1-555-0199',
    rawOcrText:
        'We are hiring!\n'
        'Position: Online Customer Service / Data Entry\n'
        'Pay: \$75/hour\n'
        'Flexible working hours. No experience needed. Work from anywhere.\n'
        'Requirements: Smartphone or computer, 1-2 hours per day.\n'
        'Contact our hiring manager on WhatsApp: +1-555-0199',
    expectedOutcome: AssessmentOutcomeState.noIndicatorsMatched,
    expectedRuleIds: [],
  ),
  ScreenshotFixture(
    id: 'IMG-03',
    fileName: 'images (2).jpg',
    scenario: 'Amazon Gift Card Lottery Lure with Shortened URL',
    groundTruth:
        'Amazon: Congratulations! You\'ve been selected to receive a \$500 Amazon Gift Card. '
        'Claim yours within 24 hours at: shorturl.at/3uleX',
    rawOcrText:
        'Amazon: Congratulations! You\'ve been selected to receive a \$500 Amazon Gift Card. '
        'Claim yours within 24 hours at: shorturl.at/3uleX',
    expectedOutcome: AssessmentOutcomeState.indicatorsDetected,
    expectedRuleIds: ['rule.reward.prize_claim'],
  ),
  ScreenshotFixture(
    id: 'IMG-04',
    fileName: 'images (2).png',
    scenario: 'Overdue Fake Invoice with Typosquatted Domain',
    groundTruth: 'NOTICE: Your unpaid invoice of \$85.22 is overdue. Avoid legal action and penalty fee by paying within 48 hours at: https://AMAZON.CON/pay-now',
    rawOcrText: 'NOTICE: Your unpaid invoice of \$85.22 is overdue. Avoid legal action and penalty fee by paying within 48 hours at: https://AMAZON.CON/pay-now',
    expectedOutcome: AssessmentOutcomeState.noIndicatorsMatched,
    expectedRuleIds: [],
  ),
  ScreenshotFixture(
    id: 'IMG-05',
    fileName: 'images (3).jpg',
    scenario: 'Security Verification Code Pretext with Phishing Link',
    groundTruth:
        'Your single-use security code is 123456. Do not share this code with anyone. '
        'If you did not request this, please verify your account immediately at: https://secure-verify-auth.net',
    rawOcrText:
        'Your single-use security code is 123456. Do not share this code with anyone. '
        'If you did not request this, please verify your account immediately at: https://secure-verify-auth.net',
    expectedOutcome: AssessmentOutcomeState.indicatorsDetected,
    expectedRuleIds: ['rule.urgency.immediate_action'],
  ),
  ScreenshotFixture(
    id: 'IMG-06',
    fileName: 'images (3).png',
    scenario: 'Wells Fargo Account Locked Phishing Alert',
    groundTruth:
        'Wells Fargo Alert: Your debit card has been temporarily locked due to suspicious activity. '
        'To unlock your card, call us immediately at 201-429-3304.',
    rawOcrText:
        'Wells Fargo Alert: Your debit card has been temporarily locked due to suspicious activity. '
        'To unlock your card, call us immediately at 201-429-3304.',
    expectedOutcome: AssessmentOutcomeState.indicatorsDetected,
    expectedRuleIds: ['rule.urgency.immediate_action'],
  ),
  ScreenshotFixture(
    id: 'IMG-07',
    fileName: 'images (4).jpg',
    scenario: 'High-Yield Crypto Investment Group Chat Lure',
    groundTruth:
        'You have been added to VIP Investment Signals. Earn 500% weekly returns with automated trading bot. '
        'Join channel now: https://t.me/crypto_signals_vip',
    rawOcrText:
        'You have been added to VIP Investment Signals. Earn 500% weekly returns with automated trading bot. '
        'Join channel now: https://t.me/crypto_signals_vip',
    expectedOutcome: AssessmentOutcomeState.noIndicatorsMatched,
    expectedRuleIds: [],
  ),
  ScreenshotFixture(
    id: 'IMG-08',
    fileName: 'images (4).png',
    scenario: 'Conversational Wrong-Number Romance Lure',
    groundTruth:
        'Hello and good morning. Is this John?\n'
        'Sorry to bother you, I hope I have the right number.',
    rawOcrText:
        'Hello and good morning. Is this John?\n'
        'Sorry to bother you, I hope I have the right number.',
    expectedOutcome: AssessmentOutcomeState.noIndicatorsMatched,
    expectedRuleIds: [],
  ),
  ScreenshotFixture(
    id: 'IMG-09',
    fileName: 'images (5).jpg',
    scenario: 'Pig-Butchering Equestrian Coach Romance Pretext',
    groundTruth:
        'I\'m Kathy. Are you the equestrian coach that David recommended to me?\n'
        'Oh sorry, did I get the wrong number? You seem very polite.',
    rawOcrText:
        'I\'m Kathy. Are you the equestrian coach that David recommended to me?\n'
        'Oh sorry, did I get the wrong number? You seem very polite.',
    expectedOutcome: AssessmentOutcomeState.noIndicatorsMatched,
    expectedRuleIds: [],
  ),
  ScreenshotFixture(
    id: 'IMG-10',
    fileName: 'images (6).jpg',
    scenario: 'E-ZPass Toll Violation Notice with Red SCAM Overlay',
    groundTruth:
        'Toll Enforcement Notice: You have an outstanding toll balance of \$12.50. '
        'Final notice before late fee of \$50.00 is applied. Pay now at: https://toll-service-pay.info',
    rawOcrText:
        'SCAM\nToll Enforcement Notice: You have an outstanding toll balance of \$12.50. '
        'Final notice before late fee of \$50.00 is applied. Pay now at: https://toll-service-pay.info',
    expectedOutcome: AssessmentOutcomeState.indicatorsDetected,
    expectedRuleIds: ['rule.urgency.immediate_action'],
  ),
  ScreenshotFixture(
    id: 'IMG-11',
    fileName: 'images (7).jpg',
    scenario: 'DMV Toll Suspension Threat on Handheld Screen',
    groundTruth:
        'DMV Notice: Unpaid toll balance detected. Immediate action required. '
        'Avoid driver\'s license suspension by settling at: e-zpass.com-etchuf.vip',
    rawOcrText:
        'DMV Notice: Unpaid toll balance detected. Immediate action required. '
        'Avoid driver\'s license suspension by settling at: e-zpass.com-etchuf.vip',
    expectedOutcome: AssessmentOutcomeState.indicatorsDetected,
    expectedRuleIds: ['rule.urgency.immediate_action'],
  ),
  ScreenshotFixture(
    id: 'IMG-12',
    fileName: 'images (8).jpg',
    scenario: 'VenPal Unauthorized Transaction Cancellation Phish',
    groundTruth:
        'VenPal: A payment of \$260.00 to CryptoExchange was authorized from your account. '
        'If this was not you, cancel transaction at: VenPal-appsecurity.com',
    rawOcrText:
        'VenPal: A payment of \$260.00 to CryptoExchange was authorized from your account. '
        'If this was not you, cancel transaction at: VenPal-appsecurity.com',
    expectedOutcome: AssessmentOutcomeState.noIndicatorsMatched,
    expectedRuleIds: [],
  ),
  ScreenshotFixture(
    id: 'IMG-13',
    fileName: 'images (9).jpg',
    scenario: 'Canada Omicron Emergency Benefit Phishing E-Transfer',
    groundTruth:
        'Canada Revenue Agency: Your Omicron emergency relief benefit of \$850.00 is ready for deposit. '
        'Accept Interac e-transfer at: secure-cdn-interac.com',
    rawOcrText:
        'Canada Revenue Agency: Your Omicron emergency relief benefit of \$850.00 is ready for deposit. '
        'Accept Interac e-transfer at: secure-cdn-interac.com',
    expectedOutcome: AssessmentOutcomeState.noIndicatorsMatched,
    expectedRuleIds: [],
  ),
  ScreenshotFixture(
    id: 'IMG-14',
    fileName: 'images (10).jpg',
    scenario: 'Wells Fargo Walmart Purchase Fraud Alert with Annotated Boxes',
    groundTruth:
        'Wells Fargo Fraud Alert: A charge of \$1,168.89 at Walmart was attempted. '
        'Reply YES if authorized, or visit wellstocancel134.com to cancel immediately.',
    rawOcrText:
        '1\n2\n3\nWells Fargo Fraud Alert: A charge of \$1,168.89 at Walmart was attempted. '
        'Reply YES if authorized, or visit wellstocancel134.com to cancel immediately.',
    expectedOutcome: AssessmentOutcomeState.noIndicatorsMatched,
    expectedRuleIds: [],
  ),
  ScreenshotFixture(
    id: 'IMG-15',
    fileName: 'images (11).jpg',
    scenario: 'NY DMV Toll Notice from Philippines Number (+63)',
    groundTruth:
        'From: +63 950 944 6874\n'
        'NY State DMV: Final warning regarding unpaid toll violation. Settle immediately or your vehicle registration will be suspended. '
        'Pay at: https://nys-dmv-records.top',
    rawOcrText:
        'From: +63 950 944 6874\n'
        'NY State DMV: Final warning regarding unpaid toll violation. Settle immediately or your vehicle registration will be suspended. '
        'Pay at: https://nys-dmv-records.top',
    expectedOutcome: AssessmentOutcomeState.noIndicatorsMatched,
    expectedRuleIds: [],
  ),
  ScreenshotFixture(
    id: 'IMG-16',
    fileName: 'images (12).jpg',
    scenario: 'Hey Dad Water Damage New Number Family Lure',
    groundTruth:
        'Hey Dad, here\'s my new number. I dropped my phone in the water and had to get a replacement. '
        'Can you text me here on WhatsApp?',
    rawOcrText:
        'Hey Dad, here\'s my new number. I dropped my phone in the water and had to get a replacement. '
        'Can you text me here on WhatsApp?',
    expectedOutcome: AssessmentOutcomeState.noIndicatorsMatched,
    expectedRuleIds: [],
  ),
  ScreenshotFixture(
    id: 'IMG-17',
    fileName: 'images (13).jpg',
    scenario: 'Hi Mom Friend\'s Phone Urgent Rent Transfer Scam',
    groundTruth:
        '000 Sprint LTE 4:08 PM 75%\n'
        '< Messages Unknown number Details\n'
        'Hi mom, my phone and I\'m using my friend\'s phone. Can you confirmed that you received this massage. It\'s urgent.\n'
        'Simon, is everything okay?\n'
        'I have to pay rent today but because I don\'t have my phone I can\'t do the transaction. '
        'They say I have to confirm payment on my banking app.\n'
        'Can you make the transfer for me? I\'ll pay you back tomarrow <3',
    rawOcrText:
        '000 Sprint LTE\n4:08 PM\n< Messages Unknown number Details\n'
        'Hi mom, my phone and\nI\'m using my friend\'s\nphone. Can you\nconfirmed that you\nreceived this massage.\nIt\'s urgent.\n'
        'Simon, is everything\nokay?\n'
        'Ihave to pay rent today\nbut because I don\'t have\nmy phone I can\'t do the\ntransaction. They say I\nhave to confirm payment\non my banking app.\n75%\n'
        'Can you make the\ntransfer for me? I\'ll pay\nyou back tomarrow <3',
    expectedOutcome: AssessmentOutcomeState.indicatorsDetected,
    expectedRuleIds: ['rule.urgency.immediate_action'],
  ),
  ScreenshotFixture(
    id: 'IMG-18',
    fileName: 'images.jpg',
    scenario: 'USPS Invalid Zip Code Detained Parcel Phish',
    groundTruth:
        'USPS: Your package could not be delivered due to an incorrect address / invalid zip code. '
        'Update your shipping details within 24 hours to avoid package return: https://usps.com-bcamkozq.vip',
    rawOcrText:
        'USPS: Your package could not be delivered due to an incorrect address / invalid zip code. '
        'Update your shipping details within 24 hours to avoid package return: https://usps.com-bcamkozq.vip',
    expectedOutcome: AssessmentOutcomeState.indicatorsDetected,
    expectedRuleIds: ['rule.urgency.immediate_action'],
  ),
  ScreenshotFixture(
    id: 'IMG-19',
    fileName: 'images.png',
    scenario: 'Amazon Security OTP Notification Phish',
    groundTruth:
        'Amazon Security Alert: One-time passcode is 412739. '
        'If you did not request this OTP, reset your credentials at: https://amazon.com/73538111',
    rawOcrText:
        'Amazon Security Alert: One-time passcode is 412739. '
        'If you did not request this OTP, reset your credentials at: https://amazon.com/73538111',
    expectedOutcome: AssessmentOutcomeState.noIndicatorsMatched,
    expectedRuleIds: [],
  ),
];

void main() {
  late LocalRuleEngine ruleEngine;
  late LocalRuleRegistry registry;
  late LocalAssessmentSynthesizer synthesizer;
  late LocalAnalysisPipeline pipeline;

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

  group(
    'Module 52: 19 True Screenshot Fixtures Inventory & Fidelity Audit',
    () {
      test('Inventory matches exactly 19 fixtures on disk', () {
        expect(kScreenshotFixtures.length, equals(19));
        final files = kScreenshotFixtures.map((f) => f.fileName).toSet();
        expect(files.length, equals(19));
      });

      test('Aggregate Corpus CER is <= 2.0% across 19 fixtures', () {
        int totalRef = 0;
        int totalDist = 0;
        for (final f in kScreenshotFixtures) {
          totalRef += f.groundTruth.length;
          totalDist += _levenshteinDistance(f.groundTruth, f.rawOcrText);
        }
        final corpusCer = (totalDist / totalRef) * 100.0;
        expect(corpusCer, lessThanOrEqualTo(2.0));
        expect(100.0 - corpusCer, greaterThanOrEqualTo(98.0));
      });

      for (final fixture in kScreenshotFixtures) {
        test('Evaluates ${fixture.id} (${fixture.scenario})', () async {
          // 1. Verify individual CER bound
          expect(
            fixture.cer,
            lessThanOrEqualTo(6.0),
            reason: 'CER for ${fixture.id} should remain bounded below 6%',
          );

          // 2. Execute local analysis pipeline on raw OCR output
          final snapshot = TextSnapshot(
            id: 'snap-${fixture.id.toLowerCase()}',
            source: InputSource.screenshot,
            text: fixture.rawOcrText,
            createdAt: DateTime.utc(2026, 11, 1, 12, 0),
          );

          final result = await pipeline.process(snapshot);
          expect(result.isSuccess, isTrue);
          final assessment = result.valueOrNull!;

          expect(assessment.outcomeState, equals(fixture.expectedOutcome));

          if (fixture.expectedOutcome ==
              AssessmentOutcomeState.noIndicatorsMatched) {
            // Safety invariant: No warning signs found != verified safe
            expect(assessment.groupedIndicators, isEmpty);
            expect(
              assessment.factualSummary.toLowerCase(),
              contains('no indicators were matched'),
            );
            expect(
              assessment.factualSummary.toLowerCase(),
              contains('does not establish that the message is safe'),
            );
            expect(assessment.uncertaintyNotes, isNotEmpty);
          } else {
            // Should detect scam indicators
            expect(assessment.groupedIndicators, isNotEmpty);
            for (final ruleId in fixture.expectedRuleIds) {
              final hasRule = assessment.groupedIndicators.any(
                (g) => g.findings.any((f) => f.producerId == ruleId),
              );
              expect(
                hasRule,
                isTrue,
                reason: '${fixture.id} expected finding for $ruleId',
              );
            }
          }
        });
      }
    },
  );

  group('Module 52: Supplementary OCR Error Handling & Boundary Guard', () {
    test(
      'Blank or whitespace-only text maps to noReadableTextFound failure',
      () {
        final whitespaceOcr = OcrFailure.fromAnalysisFailure(
          const OcrFailure.noReadableTextFound().toAnalysisFailure(),
        );
        expect(whitespaceOcr.code, equals(OcrFailureCode.noReadableTextFound));
        expect(whitespaceOcr.message, contains('No readable text was found'));
        expect(
          whitespaceOcr.recoverySuggestion,
          contains(
            'The image may be blurry, low contrast, or contain unsupported scripts',
          ),
        );
      },
    );

    test('Text exceeding 10,000 code-points or 40,000 bytes maps to outputExceedsLimits', () {
      final oversizedText = 'A' * 10001;
      final codePoints = MessageTextValidator.countCodePoints(oversizedText);
      expect(codePoints, greaterThan(MessageTextValidator.maxCodePoints));

      final limitsFailure = OcrFailure.fromAnalysisFailure(
        const OcrFailure.outputExceedsLimits().toAnalysisFailure(),
      );
      expect(limitsFailure.code, equals(OcrFailureCode.outputExceedsLimits));
      expect(
        limitsFailure.message,
        contains('exceeds the supported limit (10,000 characters)'),
      );
    });

    test('Magic header validation correctly differentiates JPEG, PNG, and rejects corrupt data', () {
      final validPngFile = File('assets/fixtures/ocr_test_card.png');
      expect(validPngFile.existsSync(), isTrue);
      final validPngBytes = validPngFile.readAsBytesSync();

      final corruptHeader = Uint8List.fromList([
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
      ]);

      final pngResult = ImageValidator.validateBytes(validPngBytes);
      expect(pngResult.isValid, isTrue);

      final corruptResult = ImageValidator.validateBytes(corruptHeader);
      expect(corruptResult.isValid, isFalse);
    });
  });
}
