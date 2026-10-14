import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_finding.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/evidence_reference.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/presentation/widgets/analyzed_text_evidence_viewer.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('AnalyzedTextEvidenceViewer', () {
    testWidgets('renders plain text with exact UTF-16 highlighted spans', (
      tester,
    ) async {
      const analyzedText =
          'URGENT: Your account has been compromised. Send your password now.';
      final start = analyzedText.indexOf('password');
      final end = start + 'password'.length;

      final finding = AnalysisFinding(
        id: 'f-1',
        category: 'requests_for_credentials',
        explanation: 'Requests sensitive password.',
        origin: FindingOrigin.localRule,
        producerId: 'rule.credential_request',
        evidence: [
          EvidenceReference(
            snapshotId: 'snap-1',
            startOffset: start,
            endOffset: end,
            exactExcerpt: 'password',
          ),
        ],
      );

      await tester.pumpWidget(
        wrapWidget(
          AnalyzedTextEvidenceViewer(
            analyzedText: analyzedText,
            finding: finding,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Evidence in analyzed text'), findsOneWidget);
      expect(find.text('Requests sensitive password.'), findsOneWidget);
      expect(
        find.text(
          'Rule provenance: rule.credential_request (on-device local rule)',
        ),
        findsOneWidget,
      );
      expect(find.text('Span [$start, $end): "password"'), findsOneWidget);
      expect(find.text('password'), findsWidgets);

      // Verify highlighted container key
      expect(find.byKey(ValueKey('evidence-highlight-$start')), findsOneWidget);
    });

    testWidgets('handles emoji without splitting UTF-16 surrogate pairs', (
      tester,
    ) async {
      const analyzedText = 'Security alert 🔒: Send PIN immediately.';
      final start = analyzedText.indexOf('PIN');
      final end = start + 'PIN'.length;

      final finding = AnalysisFinding(
        id: 'f-emoji',
        category: 'requests_for_credentials',
        explanation: 'Requests payment PIN.',
        origin: FindingOrigin.localRule,
        producerId: 'rule.credential_request',
        evidence: [
          EvidenceReference(
            snapshotId: 'snap-1',
            startOffset: start,
            endOffset: end,
            exactExcerpt: 'PIN',
          ),
        ],
      );

      await tester.pumpWidget(
        wrapWidget(
          AnalyzedTextEvidenceViewer(
            analyzedText: analyzedText,
            finding: finding,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Span [$start, $end): "PIN"'), findsOneWidget);
      expect(find.byKey(ValueKey('evidence-highlight-$start')), findsOneWidget);
      expect(find.text('PIN'), findsWidgets);
    });

    testWidgets('merges overlapping or adjacent evidence spans gracefully', (
      tester,
    ) async {
      const analyzedText = 'Click https://secure-login.example.com to verify.';
      final start1 = analyzedText.indexOf('secure-login');
      final end1 = start1 + 'secure-login'.length;
      final start2 = analyzedText.indexOf('login.example.com');
      final end2 = start2 + 'login.example.com'.length;

      final finding = AnalysisFinding(
        id: 'f-overlap',
        category: 'link_structural_indicators',
        explanation: 'Deceptive URL domain structure.',
        origin: FindingOrigin.localRule,
        producerId: 'rule.link_structural',
        evidence: [
          EvidenceReference(
            snapshotId: 'snap-1',
            startOffset: start1,
            endOffset: end1,
            exactExcerpt: 'secure-login',
          ),
          EvidenceReference(
            snapshotId: 'snap-1',
            startOffset: start2,
            endOffset: end2,
            exactExcerpt: 'login.example.com',
          ),
        ],
      );

      await tester.pumpWidget(
        wrapWidget(
          AnalyzedTextEvidenceViewer(
            analyzedText: analyzedText,
            finding: finding,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Merged span should start at start1
      expect(
        find.byKey(ValueKey('evidence-highlight-$start1')),
        findsOneWidget,
      );
      expect(find.text('secure-login.example.com'), findsOneWidget);
    });

    testWidgets(
      'malformed evidence offsets fail safely and display unavailable message',
      (tester) async {
        const analyzedText = 'Short message.';
        final malformedFinding = AnalysisFinding(
          id: 'f-malformed',
          category: 'requests_for_credentials',
          explanation: 'Out of bounds finding.',
          origin: FindingOrigin.localRule,
          producerId: 'rule.test',
          evidence: [
            EvidenceReference(
              snapshotId: 'snap-1',
              startOffset: 0,
              endOffset: 5,
              exactExcerpt: 'Wrong', // Doesn't match 'Short'
            ),
          ],
        );

        await tester.pumpWidget(
          wrapWidget(
            AnalyzedTextEvidenceViewer(
              analyzedText: analyzedText,
              finding: malformedFinding,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Evidence highlight unavailable'), findsOneWidget);
        expect(
          find.text(
            'The evidence references could not be verified against the analyzed text snapshot. No replacement excerpt was fabricated.',
          ),
          findsOneWidget,
        );
        // Raw snapshot text is still visible
        expect(find.text('Short message.'), findsOneWidget);
      },
    );

    testWidgets('redacted text placeholder remains redacted and visible', (
      tester,
    ) async {
      const analyzedText =
          'Contact [EMAIL] to claim your prize [AMOUNT] immediately.';
      final start = analyzedText.indexOf('prize');
      final end = start + 'prize'.length;

      final finding = AnalysisFinding(
        id: 'f-prize',
        category: 'rewards_or_prizes',
        explanation: 'Suspicious prize claim.',
        origin: FindingOrigin.localRule,
        producerId: 'rule.reward_claim',
        evidence: [
          EvidenceReference(
            snapshotId: 'snap-1',
            startOffset: start,
            endOffset: end,
            exactExcerpt: 'prize',
          ),
        ],
      );

      await tester.pumpWidget(
        wrapWidget(
          AnalyzedTextEvidenceViewer(
            analyzedText: analyzedText,
            finding: finding,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure [EMAIL] and [AMOUNT] placeholders are preserved as plain text
      expect(find.textContaining('[EMAIL]'), findsWidgets);
      expect(find.textContaining('[AMOUNT]'), findsWidgets);
      expect(find.byKey(ValueKey('evidence-highlight-$start')), findsOneWidget);
    });
  });
}
