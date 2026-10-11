import 'package:flutter_test/flutter_test.dart';
import 'package:trustcue_mobile/features/input/domain/models/sensitive_data_candidate.dart';
import 'package:trustcue_mobile/features/input/domain/models/sensitive_data_type.dart';
import 'package:trustcue_mobile/features/input/domain/services/local_sensitive_data_detector.dart';

void main() {
  const detector = LocalSensitiveDataDetector();

  group('LocalSensitiveDataDetector - Category Detection', () {
    test('detects email addresses and handles sentence punctuation cleanly', () {
      const text =
          'Please reach out to support@trustcue.org or contact alice.smith@example.co.uk.';
      final candidates = detector.detect(text: text, revision: 'rev-1');

      expect(candidates.length, 2);
      expect(candidates[0].type, SensitiveDataType.email);
      expect(candidates[0].matchedText, 'support@trustcue.org');
      expect(candidates[0].maskedLabel, contains('@trustcue.org'));

      expect(candidates[1].type, SensitiveDataType.email);
      expect(candidates[1].matchedText, 'alice.smith@example.co.uk');
      expect(candidates[1].maskedLabel, contains('@example.co.uk'));
    });

    test('detects payment card with valid Luhn checksum', () {
      // 4532 0150 0000 0007 is a valid Luhn test number
      const text = 'Charge card 4532 0150 0000 0007 for renewal.';
      final candidates = detector.detect(text: text, revision: 'rev-1');

      expect(candidates.length, 1);
      expect(candidates[0].type, SensitiveDataType.paymentCard);
      expect(candidates[0].matchedText, '4532 0150 0000 0007');
      expect(candidates[0].maskedLabel, '•••• 0007');
    });

    test('rejects card-like digit sequences that fail Luhn checksum', () {
      // 4532 0150 0000 0003 fails Luhn (sum=26)
      const text = 'Ref number 4532 0150 0000 0003 is not a card.';
      final candidates = detector.detect(text: text, revision: 'rev-1');

      final cardCandidates = candidates.where(
        (c) => c.type == SensitiveDataType.paymentCard,
      );
      expect(cardCandidates, isEmpty);
    });

    test(
      'detects verification code only when contextual triggers are nearby',
      () {
        const withContext =
            'Your TrustCue verification code is 849201. Do not share it.';
        final candidates = detector.detect(
          text: withContext,
          revision: 'rev-1',
        );

        expect(candidates.length, 1);
        expect(candidates[0].type, SensitiveDataType.verificationCode);
        expect(candidates[0].matchedText, '849201');
        expect(candidates[0].maskedLabel, '•••• 201');
      },
    );

    test(
      'rejects isolated numbers lacking OTP context (negative examples)',
      () {
        const text =
            'Order #982341 placed in year 2026. Price was 1200 PKR. Room 404.';
        final candidates = detector.detect(text: text, revision: 'rev-1');

        final otpCandidates = candidates.where(
          (c) => c.type == SensitiveDataType.verificationCode,
        );
        expect(otpCandidates, isEmpty);
      },
    );

    test('detects plausible phone numbers and rejects dates/prices (negative examples)', () {
      const text =
          'Call +1 (555) 234-5678 or 0300-1234567. Date: 2026-10-11. Total: \$500.';
      final candidates = detector.detect(text: text, revision: 'rev-1');

      final phoneCandidates = candidates
          .where((c) => c.type == SensitiveDataType.phone)
          .toList();
      expect(phoneCandidates.length, 2);
      expect(phoneCandidates[0].matchedText, '+1 (555) 234-5678');
      expect(phoneCandidates[1].matchedText, '0300-1234567');

      // Date and price are not misclassified as phone numbers
      expect(
        candidates.any((c) => c.matchedText.contains('2026-10-11')),
        isFalse,
      );
      expect(candidates.any((c) => c.matchedText.contains('500')), isFalse);
    });
  });

  group('LocalSensitiveDataDetector - Overlap Resolution & Deduplication', () {
    test(
      'prioritizes payment card over phone number on identical digit sequence',
      () {
        // Valid Luhn 16 digits
        const text = 'Number: 4532 0150 0000 0007';
        final candidates = detector.detect(text: text, revision: 'rev-1');

        expect(candidates.length, 1);
        expect(candidates[0].type, SensitiveDataType.paymentCard);
      },
    );

    test('resolveOverlaps drops lower priority overlapping candidates deterministically', () {
      final card = SensitiveDataCandidate(
        id: 'cand-1',
        type: SensitiveDataType.paymentCard,
        startIndex: 5,
        endIndex: 24,
        matchedText: '4532 0150 0000 0003',
        maskedLabel: '•••• 0003',
        contextSummary: '...',
        revision: 'rev-1',
      );
      final phone = SensitiveDataCandidate(
        id: 'cand-2',
        type: SensitiveDataType.phone,
        startIndex: 10,
        endIndex: 24,
        matchedText: '0150 0000 0003',
        maskedLabel: '•••• 0003',
        contextSummary: '...',
        revision: 'rev-1',
      );

      final resolved = LocalSensitiveDataDetector.resolveOverlaps([
        phone,
        card,
      ]);
      expect(resolved.length, 1);
      expect(resolved[0].id, 'cand-1');
      expect(resolved[0].type, SensitiveDataType.paymentCard);
    });
  });

  group('LocalSensitiveDataDetector - Multilingual, Unicode & Surrogate Safety', () {
    test('preserves surrounding Urdu text and emojis correctly', () {
      const text =
          'براہ کرم کوڈ 789456 درج کریں۔ اپنا verification code کسی کو نہ بتائیں۔ 🔒';
      final candidates = detector.detect(text: text, revision: 'rev-1');

      expect(candidates.length, 1);
      expect(candidates[0].type, SensitiveDataType.verificationCode);
      expect(candidates[0].matchedText, '789456');

      final redacted = detector.applyRedactions(
        text: text,
        selectedCandidateIds: {candidates[0].id},
        candidates: candidates,
      );
      expect(redacted, contains('[VERIFICATION CODE]'));
      expect(redacted, contains('براہ کرم کوڈ'));
      expect(redacted, contains('🔒'));
    });
  });

  group('LocalSensitiveDataDetector - Redaction Application', () {
    test(
      'applies replacements in descending order without offset corruption',
      () {
        const text =
            'Email user@test.com and phone +1 555-019-2834 for support.';
        final candidates = detector.detect(text: text, revision: 'rev-1');

        expect(candidates.length, 2);

        // Select both
        final redacted = detector.applyRedactions(
          text: text,
          selectedCandidateIds: {candidates[0].id, candidates[1].id},
          candidates: candidates,
        );

        expect(redacted, 'Email [EMAIL] and phone [PHONE] for support.');
        expect(redacted, isNot(contains('user@test.com')));
        expect(redacted, isNot(contains('+1 555-019-2834')));
      },
    );

    test('preserves unselected candidates exactly', () {
      const text = 'Email user@test.com and phone +1 555-019-2834 for support.';
      final candidates = detector.detect(text: text, revision: 'rev-1');

      // Select only email
      final redacted = detector.applyRedactions(
        text: text,
        selectedCandidateIds: {candidates[0].id},
        candidates: candidates,
      );

      expect(redacted, 'Email [EMAIL] and phone +1 555-019-2834 for support.');
      expect(redacted, contains('+1 555-019-2834'));
    });

    test('handles literal placeholder text already present in user input', () {
      const text =
          'Input already contains [EMAIL] and real address real@test.com.';
      final candidates = detector.detect(text: text, revision: 'rev-1');

      expect(candidates.length, 1);
      expect(candidates[0].matchedText, 'real@test.com');

      final redacted = detector.applyRedactions(
        text: text,
        selectedCandidateIds: {candidates[0].id},
        candidates: candidates,
      );

      expect(
        redacted,
        'Input already contains [EMAIL] and real address [EMAIL].',
      );
    });

    test('processes maximum-length 10,000 character repetitive input within bounds', () {
      final longText = 'Verification code 123456. ' * 380; // ~10,000 chars
      expect(longText.length, greaterThan(9500));

      final stopwatch = Stopwatch()..start();
      final candidates = detector.detect(text: longText, revision: 'rev-1');
      stopwatch.stop();

      expect(candidates.isNotEmpty, isTrue);
      // Processing 10,000 chars of repetitive input should finish in under 1 second
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
