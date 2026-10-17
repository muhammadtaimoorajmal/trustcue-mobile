import 'package:flutter/material.dart';

/// Supported application languages in TrustCue.
///
/// Invariants:
/// - Selecting a language changes user-facing UI labels and educational explanations.
/// - Scam indicator detection rules continue evaluating English message text.
/// - Optical Character Recognition (OCR) continues targeting Latin script.
/// - User text snapshots and evidence excerpts are NEVER translated or normalized,
///   guaranteeing that character offsets and evidence highlights match the exact original input.
enum AppLanguage {
  system('system', 'System default', 'سسٹم ڈیفالٹ'),
  english('en', 'English', 'انگریزی'),
  urdu('ur', 'Urdu (اردو)', 'اردو');

  const AppLanguage(this.code, this.englishLabel, this.nativeLabel);

  final String code;
  final String englishLabel;
  final String nativeLabel;

  /// Whether this language utilizes Right-To-Left (RTL) text directionality.
  bool get isRtl => this == AppLanguage.urdu;

  /// Resolves the corresponding Flutter [Locale] for this language choice.
  Locale toLocale({Locale? systemLocale}) {
    switch (this) {
      case AppLanguage.system:
        if (systemLocale != null && systemLocale.languageCode == 'ur') {
          return const Locale('ur', 'PK');
        }
        return const Locale('en', 'US');
      case AppLanguage.english:
        return const Locale('en', 'US');
      case AppLanguage.urdu:
        return const Locale('ur', 'PK');
    }
  }

  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.system;
    for (final lang in AppLanguage.values) {
      if (lang.code == code) return lang;
    }
    return AppLanguage.system;
  }
}
