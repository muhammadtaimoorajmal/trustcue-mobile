import 'package:get/get.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_analysis_pipeline.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_engine.dart';
import 'package:trustcue_mobile/features/analysis/presentation/controllers/analysis_results_controller.dart';
import 'package:trustcue_mobile/features/analysis/presentation/models/analysis_results_args.dart';

/// GetX dependency injection binding for the local analysis results flow.
class AnalysisResultsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LocalAnalysisPipeline>(() {
      final registry = LocalRuleCatalog.createRegistry();
      final engine = LocalRuleEngine(registry: registry);
      final synthesizer = LocalAssessmentSynthesizer();
      return LocalAnalysisPipeline(
        engine: engine,
        synthesizer: synthesizer,
        registry: registry,
      );
    });

    Get.lazyPut<AnalysisResultsController>(() {
      final rawArgs = Get.arguments;
      final args = rawArgs is AnalysisResultsArgs ? rawArgs : null;
      return AnalysisResultsController(
        pipeline: Get.find<LocalAnalysisPipeline>(),
        args: args,
      );
    });
  }
}
