/// Enumeration of standardized failure categories for analysis operations.
enum AnalysisFailureCode {
  invalidInput,
  unsupportedInput,
  unavailable,
  timeout,
  cancelled,
  malformedData,
}

/// Represents an operational or validation failure in input processing or analysis.
///
/// Designed to be strictly privacy-preserving: user-submitted text, credentials,
/// provider response payloads, and raw stack traces must NEVER be placed in
/// [message] or [safeDetails].
class AnalysisFailure {
  final AnalysisFailureCode code;
  final String message;
  final String? safeDetails;

  const AnalysisFailure({
    required this.code,
    required this.message,
    this.safeDetails,
  });

  const AnalysisFailure.invalidInput(String message, [String? safeDetails])
    : this(
        code: AnalysisFailureCode.invalidInput,
        message: message,
        safeDetails: safeDetails,
      );

  const AnalysisFailure.unsupportedInput(String message, [String? safeDetails])
    : this(
        code: AnalysisFailureCode.unsupportedInput,
        message: message,
        safeDetails: safeDetails,
      );

  const AnalysisFailure.unavailable(String message, [String? safeDetails])
    : this(
        code: AnalysisFailureCode.unavailable,
        message: message,
        safeDetails: safeDetails,
      );

  const AnalysisFailure.timeout(String message, [String? safeDetails])
    : this(
        code: AnalysisFailureCode.timeout,
        message: message,
        safeDetails: safeDetails,
      );

  const AnalysisFailure.cancelled(String message, [String? safeDetails])
    : this(
        code: AnalysisFailureCode.cancelled,
        message: message,
        safeDetails: safeDetails,
      );

  const AnalysisFailure.malformedData(String message, [String? safeDetails])
    : this(
        code: AnalysisFailureCode.malformedData,
        message: message,
        safeDetails: safeDetails,
      );

  @override
  String toString() {
    if (safeDetails == null || safeDetails!.isEmpty) {
      return 'AnalysisFailure(${code.name}): $message';
    }
    return 'AnalysisFailure(${code.name}): $message ($safeDetails)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnalysisFailure &&
        other.code == code &&
        other.message == message &&
        other.safeDetails == safeDetails;
  }

  @override
  int get hashCode => Object.hash(code, message, safeDetails);
}
