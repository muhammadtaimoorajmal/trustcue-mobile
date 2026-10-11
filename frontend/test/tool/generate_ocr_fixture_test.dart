import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Verify synthetic OCR test fixture asset exists and is valid PNG', () {
    final file = File('assets/fixtures/ocr_test_card.png');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'ocr_test_card.png fixture should exist',
    );
    final bytes = file.readAsBytesSync();
    expect(bytes.length, greaterThan(1000));
    // Verify standard PNG magic header: 0x89 0x50 0x4E 0x47
    expect(bytes[0], 0x89);
    expect(bytes[1], 0x50);
    expect(bytes[2], 0x4E);
    expect(bytes[3], 0x47);
  });
}
