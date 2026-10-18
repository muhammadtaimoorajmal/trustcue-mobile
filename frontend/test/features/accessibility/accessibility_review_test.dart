import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/core/theme/app_colors.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/finding_origin.dart';
import 'package:trustcue_mobile/features/analysis/domain/models/local_assessment.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/presentation/bindings/auth_binding.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/account_screen.dart';
import 'package:trustcue_mobile/features/export/data/services/export_storage_service.dart';
import 'package:trustcue_mobile/features/export/data/services/share_launcher.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_options.dart';
import 'package:trustcue_mobile/features/export/domain/models/export_report_data.dart';
import 'package:trustcue_mobile/features/export/presentation/controllers/export_controller.dart';
import 'package:trustcue_mobile/features/export/presentation/widgets/export_report_sheet.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/localization/domain/models/app_language.dart';
import 'package:trustcue_mobile/features/localization/presentation/translations/app_translations.dart';
import 'package:trustcue_mobile/features/reports/presentation/widgets/delete_confirmation_dialog.dart';
import 'package:trustcue_mobile/features/reports/presentation/widgets/history_filter_bar.dart';

import '../auth/mocks/fake_auth_repository.dart';

class _MockStorageService implements ExportStorageService {
  @override
  Future<File> writePlainTextReport(
    String content, {
    DateTime? timestamp,
  }) async => File('dummy.txt');

  @override
  Future<File> writePdfReport(Uint8List bytes, {DateTime? timestamp}) async =>
      File('dummy.pdf');

  @override
  Future<int> pruneOldExports({
    Duration maxAge = const Duration(hours: 2),
  }) async => 0;

  @override
  Future<int> cleanupAllExports({
    bool force = false,
    Duration activeGraceDuration = Duration.zero,
  }) async => 0;

  @override
  void acquireLease(String filePath) {}

  @override
  void releaseLease(String filePath) {}

  @override
  bool isLeased(String filePath) => false;
}

class _MockShareLauncher implements ShareLauncher {
  @override
  Future<ShareStatus> shareFile({
    required File file,
    required String mimeType,
    required String subject,
    required String text,
    Rect? sharePositionOrigin,
  }) async => ShareStatus.success;
}

double _luminance(Color color) => color.computeLuminance();

double _contrastRatio(Color fg, Color bg) {
  final l1 = _luminance(fg);
  final l2 = _luminance(bg);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Module 45 Accessibility & Usability Tests', () {
    setUp(() {
      Get.clearTranslations();
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('en', 'US');
    });

    tearDown(() {
      Get.reset();
    });

    test('WCAG 2.1 AA Contrast Ratio Verification', () {
      // Light theme contrast checks
      expect(
        _contrastRatio(AppColors.textPrimaryLight, AppColors.lightSurface),
        greaterThanOrEqualTo(4.5),
        reason: 'Light textPrimary on lightSurface must satisfy >= 4.5:1',
      );
      expect(
        _contrastRatio(
          AppColors.primaryActionForegroundLight,
          AppColors.primaryActionLight,
        ),
        greaterThanOrEqualTo(4.5),
        reason: 'White text on primaryActionLight must satisfy >= 4.5:1',
      );
      expect(
        _contrastRatio(AppColors.textSecondaryLight, AppColors.lightSurface),
        greaterThanOrEqualTo(4.5),
        reason: 'Secondary text on lightSurface must meet AA standard',
      );

      // Dark theme contrast checks
      expect(
        _contrastRatio(AppColors.textPrimaryDark, AppColors.darkSurface),
        greaterThanOrEqualTo(4.5),
        reason: 'Dark textPrimary on darkSurface must satisfy >= 4.5:1',
      );
      expect(
        _contrastRatio(
          AppColors.primaryActionForegroundDark,
          AppColors.primaryActionDark,
        ),
        greaterThanOrEqualTo(4.5),
        reason: 'Dark text on primaryActionDark must satisfy >= 4.5:1',
      );
      expect(
        _contrastRatio(AppColors.textSecondaryDark, AppColors.darkSurface),
        greaterThanOrEqualTo(4.5),
        reason: 'Secondary text on darkSurface must meet AA standard',
      );
    });

    testWidgets('Touch target size meets minimum 48x48 on action buttons', (
      tester,
    ) async {
      final searchController = TextEditingController(text: 'sample search');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryFilterBar(
              searchController: searchController,
              onSearchChanged: (_) {},
              onClearSearch: () {},
              selectedSource: null,
              onSourceChanged: (_) {},
              selectedProvenance: null,
              onProvenanceChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clearButtonFinder = find.byTooltip('Clear search');
      expect(clearButtonFinder, findsOneWidget);

      final clearBox = tester.renderObject<RenderBox>(clearButtonFinder);
      expect(clearBox.size.width, greaterThanOrEqualTo(48.0));
      expect(clearBox.size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets(
      'DeleteConfirmationDialog operates gracefully at 200% font scale',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(() {
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) =>
                            const DeleteConfirmationDialog(isSyncEnabled: true),
                      );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Delete saved report?'), findsOneWidget);
        expect(find.text('Keep report'), findsOneWidget);
        expect(find.text('Device & Cloud'), findsOneWidget);
        expect(find.text('Device only'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ExportReportSheet format options wrap cleanly at 200% font scale',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(() {
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });

        ExportReportData testDataFactory(ExportOptions options) {
          return ExportReportData(
            reportId: 'tc-test-export',
            analyzedAt: DateTime.utc(2026, 10, 18),
            exportedAt: DateTime.utc(2026, 10, 18),
            inputSource: InputSource.messageText,
            hasAiAnalysis: false,
            outcomeState: AssessmentOutcomeState.indicatorsDetected,
            outcomeSummary: 'Summary of findings',
            findings: const [
              ExportFindingItem(
                category: 'urgency',
                origin: FindingOrigin.localRule,
                producerId: 'rule.urgency',
                explanation: 'Suspicious deadline',
                evidenceQuotes: ['Act within 24 hours'],
              ),
            ],
            limitations: const ['Heuristics only'],
            suggestedActions: const ['Contact provider directly'],
            reviewedText: 'Act within 24 hours to secure your funds.',
          );
        }

        final controller = ExportController(
          dataFactory: testDataFactory,
          storageService: _MockStorageService(),
          shareLauncher: _MockShareLauncher(),
          hasSourceText: true,
          hasAiFindings: false,
          hasEvidenceQuotes: true,
        );
        controller.onInit();

        await tester.pumpWidget(
          GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('en', 'US'),
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (ctx) =>
                            ExportReportSheet(controller: controller),
                      );
                    },
                    child: const Text('Export'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Export'));
        await tester.pumpAndSettle();

        expect(find.text('Export & Share Report'), findsOneWidget);
        expect(find.text('Plain Text (.txt)'), findsOneWidget);
        expect(find.text('PDF Document (.pdf)'), findsOneWidget);

        final closeButtonFinder = find.byTooltip('Close');
        expect(closeButtonFinder, findsOneWidget);
        final closeBox = tester.renderObject<RenderBox>(closeButtonFinder);
        expect(closeBox.size.width, greaterThanOrEqualTo(48.0));
        expect(closeBox.size.height, greaterThanOrEqualTo(48.0));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('AccountScreen guest view adapts to 200% font scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final fakeAuth = FakeAuthRepository();
      Get.put<AuthRepository>(fakeAuth);
      AuthBinding().dependencies();

      await tester.pumpWidget(
        GetMaterialApp(theme: AppTheme.lightTheme, home: const AccountScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Guest Mode'), findsOneWidget);
      expect(find.text('Optional Account Access'), findsOneWidget);
      expect(find.text('Privacy & Retention'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('determineExcerptDirection identifies script direction correctly', () {
      expect(
        determineExcerptDirection('Urgent: Pay immediately'),
        equals(TextDirection.ltr),
      );
      expect(
        determineExcerptDirection('https://trustcue-auth-fake.com/login'),
        equals(TextDirection.ltr),
      );
      expect(
        determineExcerptDirection('فوری طور پر رقم منتقل کریں'),
        equals(TextDirection.rtl),
      );
      expect(
        determineExcerptDirection('انتباہ: آپ کا اکاؤنٹ معطل ہو جائے گا'),
        equals(TextDirection.rtl),
      );
      expect(
        determineExcerptDirection('Alert: آپ کا PIN درج کریں'),
        equals(TextDirection.rtl),
      );
    });

    testWidgets(
      'Evidence excerpt and offset render with correct dynamic directionalities',
      (tester) async {
        const urduExcerpt = 'فوری ادائیگی کریں';
        const englishExcerpt = 'Urgent: Pay immediately';
        const offsetText = 'offset [10, 25)';

        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Column(
                  children: [
                    Directionality(
                      textDirection: determineExcerptDirection(englishExcerpt),
                      child: const Text(
                        '"$englishExcerpt"',
                        key: Key('english_excerpt'),
                      ),
                    ),
                    Directionality(
                      textDirection: determineExcerptDirection(urduExcerpt),
                      child: const Text(
                        '"$urduExcerpt"',
                        key: Key('urdu_excerpt'),
                      ),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: const Text(
                        offsetText,
                        key: Key('offset_indicator'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final englishElement = tester.element(
          find.byKey(const Key('english_excerpt')),
        );
        expect(Directionality.of(englishElement), equals(TextDirection.ltr));

        final urduElement = tester.element(
          find.byKey(const Key('urdu_excerpt')),
        );
        expect(Directionality.of(urduElement), equals(TextDirection.rtl));

        final offsetElement = tester.element(
          find.byKey(const Key('offset_indicator')),
        );
        expect(Directionality.of(offsetElement), equals(TextDirection.ltr));
      },
    );
  });
}
