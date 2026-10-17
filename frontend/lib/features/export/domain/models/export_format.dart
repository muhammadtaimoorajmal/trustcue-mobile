/// Supported export file formats for TrustCue reports.
enum ExportFormat {
  /// Human-readable UTF-8 plain text file (.txt).
  ///
  /// Guarantees 100% character fidelity for all languages including
  /// Urdu (اردو), emojis, and non-Latin scripts.
  plainText,

  /// Portable Document Format (.pdf).
  ///
  /// Clean, paginated document with structured layout. Uses standard
  /// Latin typography with safe escaping for non-Latin runes.
  pdf;

  /// File extension including leading dot.
  String get fileExtension {
    switch (this) {
      case ExportFormat.plainText:
        return '.txt';
      case ExportFormat.pdf:
        return '.pdf';
    }
  }

  /// Standard MIME type for sharing intents.
  String get mimeType {
    switch (this) {
      case ExportFormat.plainText:
        return 'text/plain';
      case ExportFormat.pdf:
        return 'application/pdf';
    }
  }

  /// Readable display label.
  String get displayName {
    switch (this) {
      case ExportFormat.plainText:
        return 'Plain Text (.txt)';
      case ExportFormat.pdf:
        return 'PDF Document (.pdf)';
    }
  }
}

