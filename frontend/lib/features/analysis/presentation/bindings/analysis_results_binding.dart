import 'package:get/get.dart';
import 'package:trustcue_mobile/features/analysis/data/services/analysis_api_client.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_analysis_pipeline.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_assessment_synthesizer.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_engine.dart';
import 'package:trustcue_mobile/features/analysis/presentation/controllers/analysis_results_controller.dart';
import 'package:trustcue_mobile/features/analysis/presentation/models/analysis_results_args.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/reports/data/database/app_database.dart';
import 'package:trustcue_mobile/features/reports/domain/contracts/local_report_repository.dart';

/// GetX dependency injection binding for the analysis results flow.
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

    if (!Get.isRegistered<AnalysisApiClient>()) {
      Get.lazyPut<AnalysisApiClient>(() {
        return AnalysisApiClient(
          tokenProvider: () async {
            if (Get.isRegistered<AuthRepository>()) {
              return Get.find<AuthRepository>().getAccessToken();
            }
            return null;
          },
        );
      });
    }

    if (!Get.isRegistered<LocalReportRepository>()) {
      Get.lazyPut<LocalReportRepository>(() => AppDatabase.getInstance());
    }

    Get.lazyPut<AnalysisResultsController>(() {
      final rawArgs = Get.arguments;
      final args = rawArgs is AnalysisResultsArgs ? rawArgs : null;
      return AnalysisResultsController(
        pipeline: Get.find<LocalAnalysisPipeline>(),
        args: args,
        apiClient: Get.isRegistered<AnalysisApiClient>()
            ? Get.find<AnalysisApiClient>()
            : null,
        authRepository: Get.isRegistered<AuthRepository>()
            ? Get.find<AuthRepository>()
            : null,
        reportRepository: Get.isRegistered<LocalReportRepository>()
            ? Get.find<LocalReportRepository>()
            : null,
      );
    });
  }
}
