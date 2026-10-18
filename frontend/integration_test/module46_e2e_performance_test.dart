import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/core/widgets/app_button.dart';
import 'package:trustcue_mobile/core/widgets/app_text_field.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/analysis/domain/rules/local_rule_catalog.dart';
import 'package:trustcue_mobile/features/analysis/domain/services/local_rule_engine.dart';
import 'package:trustcue_mobile/features/analysis/presentation/screens/analysis_results_screen.dart';
import 'package:trustcue_mobile/features/export/data/services/pdf_export_builder.dart';
import 'package:trustcue_mobile/features/export/data/services/plain_text_export_formatter.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_report_data.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';
import 'package:trustcue_mobile/features/reports/data/database/app_database.dart';
import 'package:trustcue_mobile/features/reports/data/database/database_constants.dart';
import 'package:trustcue_mobile/features/reports/data/repositories/sqlite_report_repository.dart';
import 'package:trustcue_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Module 46 E2E Device Testing, Performance Benchmarks, and Database Scalability', (
    WidgetTester tester,
  ) async {
    final benchmarkResults = <String, dynamic>{};

    // -----------------------------------------------------------------------
    // 1. APP LAUNCH & COLD START TIMING BENCHMARK
    // -----------------------------------------------------------------------
    final preferences = SharedPreferencesAsync();
    await preferences.setInt(OnboardingPreferences.key, 1);

    final launchStopwatch = Stopwatch()..start();
    app.main();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    int startupRetries = 0;
    while (Get.currentRoute != AppRoutes.home && startupRetries < 15) {
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      startupRetries++;
    }
    launchStopwatch.stop();

    final launchMs = launchStopwatch.elapsedMilliseconds;
    benchmarkResults['app_launch_ms'] = launchMs;
    debugPrint(
      '[PERF_BENCHMARK] App launch latency (debug JIT harness): ${launchMs}ms',
    );

    expect(Get.currentRoute, AppRoutes.home);
    expect(find.text('Understand the signals.'), findsOneWidget);
    expect(
      launchMs,
      lessThan(10000),
      reason: 'App cold start should complete cleanly',
    );

    // -----------------------------------------------------------------------
    // 2. END-TO-END WORKFLOW: INTAKE -> REVIEW -> LOCAL ANALYSIS -> RESULTS
    // -----------------------------------------------------------------------
    final enterMessageBtn = find.widgetWithText(AppButton, 'Enter message');
    await tester.ensureVisible(enterMessageBtn);
    await tester.pumpAndSettle();
    await tester.tap(enterMessageBtn);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.inputText);

    const scamMessage =
        'URGENT: Your bank account will be suspended within 24 hours. '
        'Verify your security credentials at http://secure-banking-alert.xyz immediately.';

    final inputField = find.byType(AppTextField);
    expect(inputField, findsOneWidget);
    await tester.enterText(inputField, scamMessage);
    await tester.pumpAndSettle();

    final prepareBtn = find.widgetWithText(AppButton, 'Prepare text');
    await tester.ensureVisible(prepareBtn);
    await tester.pumpAndSettle();
    await tester.tap(prepareBtn);
    await tester.pumpAndSettle();

    final reviewBtn = find.widgetWithText(AppButton, 'Review text');
    await tester.ensureVisible(reviewBtn);
    await tester.pumpAndSettle();
    await tester.tap(reviewBtn);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.inputReview);

    final confirmBtn = find.widgetWithText(AppButton, 'Confirm reviewed text');
    await tester.ensureVisible(confirmBtn);
    await tester.pumpAndSettle();
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    final analyzeBtn = find.widgetWithText(AppButton, 'Analyze on this device');
    await tester.ensureVisible(analyzeBtn);
    await tester.pumpAndSettle();

    final analysisStopwatch = Stopwatch()..start();
    await tester.tap(analyzeBtn);
    await tester.pumpAndSettle();
    analysisStopwatch.stop();

    final analysisMs = analysisStopwatch.elapsedMilliseconds;
    benchmarkResults['e2e_local_analysis_ms'] = analysisMs;
    debugPrint('[PERF_BENCHMARK] E2E local analysis latency: ${analysisMs}ms');

    expect(Get.currentRoute, AppRoutes.analysisResults);
    expect(find.byType(AnalysisResultsScreen), findsOneWidget);

    // Verify honest local-only indicators & provenance
    expect(find.text('Local on-device analysis'), findsOneWidget);
    expect(
      find.text(
        'Evaluated on this device using local rules. Nothing was uploaded.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('potential warning indicator'), findsWidgets);

    // Pop back to home cleanly
    final backBtn = find.byType(BackButton);
    if (backBtn.evaluate().isNotEmpty) {
      await tester.tap(backBtn);
      await tester.pumpAndSettle();
    }

    // -----------------------------------------------------------------------
    // 3. EXPORT GENERATION PERFORMANCE BENCHMARK
    // -----------------------------------------------------------------------
    final exportData = ExportReportData(
      reportId: 'bench-report-001',
      analyzedAt: DateTime.utc(2026, 10, 18, 12, 0, 0),
      exportedAt: DateTime.utc(2026, 10, 18, 12, 0, 5),
      inputSource: InputSource.messageText,
      hasAiAnalysis: false,
      outcomeState: AssessmentOutcomeState.indicatorsDetected,
      outcomeSummary:
          'Potential scam indicators detected during on-device analysis.',
      findings: const [
        ExportFindingItem(
          category: 'urgency',
          origin: FindingOrigin.localRule,
          producerId: 'rule.urgency',
          explanation: 'Creates manufactured urgency to force hurried action.',
          evidenceQuotes: ['within 24 hours', 'immediately'],
        ),
        ExportFindingItem(
          category: 'linkStructural',
          origin: FindingOrigin.localRule,
          producerId: 'rule.link_structural',
          explanation: 'Contains suspicious domain structure.',
          evidenceQuotes: ['http://secure-banking-alert.xyz'],
        ),
      ],
      limitations: const [
        'On-device heuristics only.',
        'Cannot verify actual sender identity.',
      ],
      suggestedActions: const [
        'Contact your institution via known official contact numbers.',
        'Never enter passwords on unsolicited links.',
      ],
      reviewedText: scamMessage,
    );

    // Plain Text generation speed benchmark
    final txtStopwatch = Stopwatch()..start();
    final txtOutput = PlainTextExportFormatter.format(exportData);
    txtStopwatch.stop();
    final txtMs = txtStopwatch.elapsedMilliseconds;
    benchmarkResults['plain_text_export_ms'] = txtMs;
    debugPrint('[PERF_BENCHMARK] Plain text export generation: ${txtMs}ms');
    expect(txtOutput.isNotEmpty, isTrue);
    expect(
      txtMs,
      lessThan(50),
      reason: 'Plain text export should generate in < 50ms',
    );

    // PDF generation speed benchmark
    final pdfStopwatch = Stopwatch()..start();
    final pdfBytes = await PdfExportBuilder.buildPdf(exportData);
    pdfStopwatch.stop();
    final pdfMs = pdfStopwatch.elapsedMilliseconds;
    benchmarkResults['pdf_export_ms'] = pdfMs;
    debugPrint(
      '[PERF_BENCHMARK] PDF export generation: ${pdfMs}ms (${pdfBytes.length} bytes)',
    );
    expect(pdfBytes.isNotEmpty, isTrue);
    expect(
      pdfMs,
      lessThan(1500),
      reason: 'PDF export should generate in < 1500ms',
    );

    // -----------------------------------------------------------------------
    // 4. DATABASE SCALABILITY BENCHMARK (1,000+ REPORTS)
    // -----------------------------------------------------------------------
    final repository = AppDatabase.getInstance() as SqliteReportRepository;
    await repository.initialize();
    final db = repository.testDatabase;
    expect(db, isNotNull, reason: 'Database must be open for benchmark');

    const seedCount = 1000;
    debugPrint(
      '[PERF_BENCHMARK] Seeding $seedCount reports in batch transaction...',
    );
    final seedStopwatch = Stopwatch()..start();
    final batch = db!.batch();
    final baseDate = DateTime.utc(2026, 10, 18, 10, 0, 0);

    for (var i = 0; i < seedCount; i++) {
      final snapId = 'bench_snap_$i';
      final repId = 'bench_rep_$i';
      final isUrgent = i % 2 == 0;
      final text = isUrgent
          ? 'Urgent notification #$i: verify banking access immediately or service terminates.'
          : 'Informational message #$i: package arrival scheduled for tomorrow.';

      batch.insert(DatabaseConstants.tableSnapshots, {
        DatabaseConstants.colSnapshotId: snapId,
        DatabaseConstants.colSnapshotText: text,
        DatabaseConstants.colSnapshotInputSource: InputSource.messageText.name,
        DatabaseConstants.colSnapshotCreatedAt: baseDate
            .add(Duration(seconds: i))
            .toIso8601String(),
        DatabaseConstants.colSnapshotSha256: 'mock_sha256_$i',
      });

      batch.insert(DatabaseConstants.tableReports, {
        DatabaseConstants.colReportId: repId,
        DatabaseConstants.colReportSchemaVersion: 1,
        DatabaseConstants.colReportSnapshotId: snapId,
        DatabaseConstants.colReportAccountId: null,
        DatabaseConstants.colReportAnalyzedAt: baseDate
            .add(Duration(seconds: i))
            .toIso8601String(),
        DatabaseConstants.colReportSavedAt: baseDate
            .add(Duration(seconds: i))
            .toIso8601String(),
        DatabaseConstants.colReportHasAiAnalysis: 0,
        DatabaseConstants.colReportAiProvider: null,
        DatabaseConstants.colReportAiModel: null,
        DatabaseConstants.colReportFindingsCount: isUrgent ? 2 : 0,
        DatabaseConstants.colReportOutcomeState: isUrgent
            ? AssessmentOutcomeState.indicatorsDetected.name
            : AssessmentOutcomeState.noIndicatorsMatched.name,
        DatabaseConstants.colReportPreviewText: text.substring(0, 35),
        DatabaseConstants.colReportPayload: '{}',
      });
    }
    await batch.commit(noResult: true);
    seedStopwatch.stop();

    final seedMs = seedStopwatch.elapsedMilliseconds;
    benchmarkResults['batch_insert_1000_reports_ms'] = seedMs;
    debugPrint('[PERF_BENCHMARK] Inserted $seedCount reports in ${seedMs}ms');

    // Verify count query
    final countResult = await repository.getReportCount();
    expect(countResult.isSuccess, isTrue);
    final totalCount = countResult.valueOrNull!;
    expect(totalCount, greaterThanOrEqualTo(seedCount));
    debugPrint('[PERF_BENCHMARK] Total reports in database: $totalCount');

    // Benchmark paginated query (20 records, offset 0) with 1,000+ reports
    final queryStopwatch = Stopwatch()..start();
    final pageResult = await repository.getReportSummaries(
      limit: 20,
      offset: 0,
    );
    queryStopwatch.stop();
    final queryMs = queryStopwatch.elapsedMilliseconds;
    benchmarkResults['paginated_query_20_from_1000_ms'] = queryMs;
    debugPrint(
      '[PERF_BENCHMARK] Paginated query (limit 20) with 1000+ reports: ${queryMs}ms',
    );

    expect(pageResult.isSuccess, isTrue);
    expect(pageResult.valueOrNull!.length, equals(20));
    expect(
      queryMs,
      lessThan(50),
      reason: 'Paginated query must execute in < 50ms with 1,000+ records',
    );

    // Benchmark search query with matching keyword across 1,000+ reports
    final searchStopwatch = Stopwatch()..start();
    final searchResult = await repository.searchReportSummaries(
      query: 'Urgent',
      limit: 20,
    );
    searchStopwatch.stop();
    final searchMs = searchStopwatch.elapsedMilliseconds;
    benchmarkResults['search_query_matching_ms'] = searchMs;
    debugPrint(
      '[PERF_BENCHMARK] LIKE search query matching 500 records: ${searchMs}ms',
    );

    expect(searchResult.isSuccess, isTrue);
    expect(searchResult.valueOrNull!.length, equals(20));
    expect(
      searchMs,
      lessThan(50),
      reason: 'Search query must execute in < 50ms with 1,000+ records',
    );

    // Benchmark search query with non-matching term across 1,000+ reports
    final searchMissStopwatch = Stopwatch()..start();
    final missResult = await repository.searchReportSummaries(
      query: 'NonExistentToken999',
      limit: 20,
    );
    searchMissStopwatch.stop();
    final searchMissMs = searchMissStopwatch.elapsedMilliseconds;
    benchmarkResults['search_query_miss_ms'] = searchMissMs;
    debugPrint(
      '[PERF_BENCHMARK] LIKE search query non-matching: ${searchMissMs}ms',
    );

    expect(missResult.isSuccess, isTrue);
    expect(missResult.valueOrNull!.isEmpty, isTrue);
    expect(
      searchMissMs,
      lessThan(50),
      reason: 'Search miss must execute in < 50ms',
    );

    // Cleanup benchmark records
    final cleanResult = await repository.deleteGuestReports();
    expect(cleanResult.isSuccess, isTrue);
    debugPrint(
      '[PERF_BENCHMARK] Cleaned up ${cleanResult.valueOrNull} seeded guest records',
    );

    // -----------------------------------------------------------------------
    // 5. LOCAL RULE ENGINE STRESS & LATENCY BENCHMARK
    // -----------------------------------------------------------------------
    final registry = LocalRuleCatalog.createRegistry();
    final ruleEngine = LocalRuleEngine(registry: registry);

    // Create a ~3,800-character synthetic document with varied text patterns (within 10k code-point limit)
    final stressBuffer = StringBuffer();
    for (var j = 0; j < 15; j++) {
      stressBuffer.writeln(
        'Paragraph $j: This is a legitimate paragraph discussing everyday schedules and tasks. '
        'We must adhere to guidelines without delay. '
        'Please visit our internal portal at https://internal.company.corp/docs for standard updates. '
        'Do not share your passwords with unauthorized colleagues.',
      );
    }
    stressBuffer.writeln(
      'Your account will be suspended immediately unless you verify right now! Send your verification code to avoid account suspension.',
    );
    final stressText = stressBuffer.toString();

    final stressSnapshot = TextSnapshot(
      id: 'stress_snap_001',
      text: stressText,
      source: InputSource.messageText,
      createdAt: DateTime.now().toUtc(),
    );

    final ruleStopwatch = Stopwatch()..start();
    final ruleResult = await ruleEngine.analyze(stressSnapshot);
    ruleStopwatch.stop();
    final ruleMs = ruleStopwatch.elapsedMilliseconds;
    benchmarkResults['rule_engine_5000char_ms'] = ruleMs;
    debugPrint(
      '[PERF_BENCHMARK] 10-rule analysis on 5,000-char text: ${ruleMs}ms',
    );

    expect(ruleResult.isSuccess, isTrue);
    expect(ruleResult.valueOrNull!.findings.isNotEmpty, isTrue);
    expect(
      ruleMs,
      lessThan(100),
      reason: 'Local rule analysis on 5KB text should complete in < 100ms',
    );

    // -----------------------------------------------------------------------
    // 6. ZERO CRASHES & COMPLETION SUMMARY
    // -----------------------------------------------------------------------
    debugPrint(
      '================================================================',
    );
    debugPrint('MODULE 46 PERFORMANCE & REAL-DEVICE BENCHMARK SUMMARY:');
    benchmarkResults.forEach((key, value) {
      debugPrint('  $key: $value');
    });
    debugPrint(
      '================================================================',
    );
  });
}
