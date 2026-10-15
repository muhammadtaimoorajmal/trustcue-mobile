import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/upload_consent.dart';
import 'package:trustcue_mobile/features/analysis/presentation/widgets/upload_consent_dialog.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

void main() {
  group('UploadConsentDialog Widget Tests', () {
    late TextSnapshot snapshot;
    const accountId = 'user-test-789';

    setUp(() {
      snapshot = TextSnapshot(
        id: 'snap-dialog-001',
        text: 'Suspicious invoice payment request \$2500.',
        source: InputSource.messageText,
        createdAt: DateTime.utc(2026, 10, 15, 12, 0, 0),
      );
    });

    testWidgets('renders all disclosures, text preview, and version badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => UploadConsentDialog.show(
                  context,
                  snapshot: snapshot,
                  accountId: accountId,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify header & titles
      expect(find.text('Upload text for AI review'), findsOneWidget);
      expect(find.text('Optional cloud-assisted evaluation'), findsOneWidget);

      // Verify disclosures
      expect(find.text('Destination & Transit'), findsOneWidget);
      expect(find.text('Ephemeral Processing'), findsOneWidget);
      expect(find.text('No Images Uploaded'), findsOneWidget);

      // Verify preview
      expect(
        find.textContaining('Suspicious invoice payment request \$2500.'),
        findsOneWidget,
      );
      expect(find.text('${snapshot.text.length} characters'), findsOneWidget);
      expect(find.textContaining('Disclosure v1.0.0'), findsOneWidget);

      // Verify buttons
      expect(find.text('Keep on-device only'), findsOneWidget);
      expect(find.text('Agree & send'), findsOneWidget);
    });

    testWidgets('cancelling returns null and keeps local analysis intact', (
      tester,
    ) async {
      UploadConsent? returnedConsent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedConsent = await UploadConsentDialog.show(
                    context,
                    snapshot: snapshot,
                    accountId: accountId,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('Keep on-device only'));
      await tester.pumpAndSettle();

      expect(returnedConsent, isNull);
      expect(find.byType(UploadConsentDialog), findsNothing);
    });

    testWidgets(
      'agreeing returns affirmative UploadConsent bound to snapshot and user',
      (tester) async {
        UploadConsent? returnedConsent;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    returnedConsent = await UploadConsentDialog.show(
                      context,
                      snapshot: snapshot,
                      accountId: accountId,
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Tap agree
        await tester.tap(find.text('Agree & send'));
        await tester.pumpAndSettle();

        expect(returnedConsent, isNotNull);
        expect(returnedConsent!.granted, isTrue);
        expect(returnedConsent!.snapshotId, equals(snapshot.id));
        expect(returnedConsent!.text, equals(snapshot.text));
        expect(returnedConsent!.accountId, equals(accountId));
        expect(returnedConsent!.disclosureVersion, equals('1.0.0'));
        expect(
          returnedConsent!.isValidFor(snapshot, candidateAccountId: accountId),
          isTrue,
        );
      },
    );
  });
}
