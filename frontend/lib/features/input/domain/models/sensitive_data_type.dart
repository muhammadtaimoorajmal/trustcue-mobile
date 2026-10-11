/// Category of potentially sensitive data detected by the local heuristic scanner.
enum SensitiveDataType {
  paymentCard,
  verificationCode,
  phone,
  email;

  /// User-facing descriptive name for UI presentation.
  String get label {
    switch (this) {
      case SensitiveDataType.paymentCard:
        return 'Payment card';
      case SensitiveDataType.verificationCode:
        return 'Verification code';
      case SensitiveDataType.phone:
        return 'Phone number';
      case SensitiveDataType.email:
        return 'Email address';
    }
  }

  /// Exact placeholder string inserted into the final text upon redaction.
  String get placeholder {
    switch (this) {
      case SensitiveDataType.paymentCard:
        return '[CARD NUMBER]';
      case SensitiveDataType.verificationCode:
        return '[VERIFICATION CODE]';
      case SensitiveDataType.phone:
        return '[PHONE]';
      case SensitiveDataType.email:
        return '[EMAIL]';
    }
  }

  /// Deterministic priority used when resolving overlapping detection spans.
  /// Higher priority candidates take precedence over lower priority ones.
  int get priority {
    switch (this) {
      case SensitiveDataType.paymentCard:
        return 4;
      case SensitiveDataType.verificationCode:
        return 3;
      case SensitiveDataType.phone:
        return 2;
      case SensitiveDataType.email:
        return 1;
    }
  }

  String toSerializedString() => name;

  static SensitiveDataType fromSerializedString(String value) {
    for (final type in SensitiveDataType.values) {
      if (type.name == value) {
        return type;
      }
    }
    throw FormatException('Unknown SensitiveDataType: "$value"');
  }
}
