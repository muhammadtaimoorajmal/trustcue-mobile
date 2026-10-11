import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/analysis/domain/contracts/analysis_service.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/analysis_report.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';

/// Test-only fake implementation of [AnalysisService].
///
/// Demonstrates contract adherence without wiring mock or production logic
/// into the live application.
class FakeAnalysisService implements AnalysisService {
  Result<AnalysisReport>? nextResult;
  TextSnapshot? lastAnalyzedSnapshot;
  int callCount = 0;

  FakeAnalysisService({this.nextResult});

  @override
  Future<Result<AnalysisReport>> analyze(TextSnapshot snapshot) async {
    callCount++;
    lastAnalyzedSnapshot = snapshot;
    if (nextResult != null) {
      return nextResult!;
    }
    // Default safe outcome: empty findings report
    return Result.success(
      AnalysisReport(
        id: 'fake-report-${DateTime.now().millisecondsSinceEpoch}',
        snapshot: snapshot,
        analyzedAt: DateTime.now().toUtc(),
        findings: const [],
        limitations: const ['Analysis is performed by a test-only fake.'],
        suggestedActions: const ['Verify with independent sources.'],
      ),
    );
  }
}
