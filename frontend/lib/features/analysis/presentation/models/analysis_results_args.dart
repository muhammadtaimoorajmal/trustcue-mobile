import 'package:trustcue_mobile/features/input/domain/models/reviewed_text_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// In-memory arguments passed to `/analysis/results`.
///
/// Invariants:
/// - Passed in-memory only via GetX route arguments.
/// - Never serialized to URLs, query strings, or persistent storage.
/// - Holds an immutable [ReviewedTextResult] capturing the exact reviewed snapshot.
class AnalysisResultsArgs {
  final ReviewedTextResult reviewResult;

  const AnalysisResultsArgs({required this.reviewResult});

  TextSnapshot get snapshot => reviewResult.snapshot;

  /// Validates that this argument object contains consistent snapshot and review data.
  bool get isValid {
    if (reviewResult.snapshot.id.trim().isEmpty) return false;
    if (reviewResult.snapshot.text.isEmpty) return false;
    if (reviewResult.sourceSnapshotId.trim().isEmpty) return false;
    return true;
  }
}
