import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Contract for asynchronous scam indicator analysis services.
///
/// Analysis implementations evaluate a given [TextSnapshot] and return
/// a typed [Result] containing either a validated [AnalysisReport] or
/// an [AnalysisFailure].
abstract class AnalysisService {
  /// Evaluates the digital communication text in [snapshot].
  ///
  /// Returns a [Success] containing the [AnalysisReport] if analysis completes,
  /// or a [Failure] with an [AnalysisFailure] describing the failure mode.
  Future<Result<AnalysisReport>> analyze(TextSnapshot snapshot);
}
