import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/home/presentation/bindings/home_binding.dart';
import 'package:trustcue_mobile/features/home/presentation/screens/home_screen.dart';

import 'package:trustcue_mobile/features/about/presentation/screens/about_screen.dart';
import 'package:trustcue_mobile/features/not_found/presentation/screens/not_found_screen.dart';
import 'package:trustcue_mobile/app/startup_screen.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';
import 'package:trustcue_mobile/features/onboarding/presentation/bindings/onboarding_binding.dart';
import 'package:trustcue_mobile/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:trustcue_mobile/features/input/presentation/bindings/input_link_binding.dart';
import 'package:trustcue_mobile/features/input/presentation/bindings/input_review_binding.dart';
import 'package:trustcue_mobile/features/input/presentation/bindings/input_screenshot_binding.dart';
import 'package:trustcue_mobile/features/input/presentation/bindings/input_text_binding.dart';
import 'package:trustcue_mobile/features/input/presentation/screens/input_link_screen.dart';
import 'package:trustcue_mobile/features/input/presentation/screens/input_review_screen.dart';
import 'package:trustcue_mobile/features/input/presentation/screens/input_screenshot_screen.dart';
import 'package:trustcue_mobile/features/input/presentation/screens/input_text_screen.dart';
import 'package:trustcue_mobile/features/analysis/presentation/bindings/analysis_results_binding.dart';
import 'package:trustcue_mobile/features/analysis/presentation/screens/analysis_results_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/bindings/auth_binding.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/account_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:trustcue_mobile/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:trustcue_mobile/features/privacy/presentation/bindings/privacy_binding.dart';
import 'package:trustcue_mobile/features/privacy/presentation/screens/privacy_screen.dart';
import 'package:trustcue_mobile/features/reports/presentation/bindings/history_binding.dart';
import 'package:trustcue_mobile/features/reports/presentation/bindings/saved_report_detail_binding.dart';
import 'package:trustcue_mobile/features/reports/presentation/screens/history_screen.dart';
import 'package:trustcue_mobile/features/reports/presentation/screens/saved_report_detail_screen.dart';
import 'package:trustcue_mobile/features/education/presentation/bindings/education_binding.dart';
import 'package:trustcue_mobile/features/education/presentation/screens/education_screen.dart';
import 'package:trustcue_mobile/features/education/presentation/screens/education_topic_detail_screen.dart';

class AppPages {
  AppPages(this.preferences, {this.requestedRoute});
  final OnboardingPreferences preferences;
  final String? requestedRoute;
  late final pages = [
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(title: 'TrustCue'),
      binding: HomeBinding(),
    ),
    GetPage(name: AppRoutes.about, page: () => const AboutScreen()),
    GetPage(
      name: AppRoutes.startup,
      page: () => StartupScreen(
        preferences: preferences,
        requestedRoute: requestedRoute,
      ),
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingScreen(mode: OnboardingMode.firstRun),
      binding: OnboardingBinding(preferences),
    ),
    GetPage(
      name: AppRoutes.guidance,
      page: () => const OnboardingScreen(mode: OnboardingMode.review),
    ),
    GetPage(
      name: AppRoutes.inputText,
      page: () => const InputTextScreen(),
      binding: InputTextBinding(),
    ),
    GetPage(
      name: AppRoutes.inputScreenshot,
      page: () => const InputScreenshotScreen(),
      binding: InputScreenshotBinding(),
    ),
    GetPage(
      name: AppRoutes.inputReview,
      page: () => const InputReviewScreen(),
      binding: InputReviewBinding(),
    ),
    GetPage(
      name: AppRoutes.inputLink,
      page: () => const InputLinkScreen(),
      binding: InputLinkBinding(),
    ),
    GetPage(
      name: AppRoutes.analysisResults,
      page: () => const AnalysisResultsScreen(),
      binding: AnalysisResultsBinding(),
    ),
    GetPage(
      name: AppRoutes.history,
      page: () => const HistoryScreen(),
      binding: HistoryBinding(),
    ),
    GetPage(
      name: AppRoutes.historyDetail,
      page: () => const SavedReportDetailScreen(),
      binding: SavedReportDetailBinding(),
    ),
    GetPage(
      name: AppRoutes.account,
      page: () => const AccountScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.authLogin,
      page: () => const LoginScreen(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: AppRoutes.authRegister,
      page: () => const RegisterScreen(),
      binding: RegisterBinding(),
    ),
    GetPage(
      name: AppRoutes.authVerifyEmail,
      page: () => const VerifyEmailScreen(),
      binding: VerifyEmailBinding(),
    ),
    GetPage(
      name: AppRoutes.authForgotPassword,
      page: () => const ForgotPasswordScreen(),
      binding: ForgotPasswordBinding(),
    ),
    GetPage(
      name: AppRoutes.authResetPassword,
      page: () => const ResetPasswordScreen(),
      binding: ResetPasswordBinding(),
    ),
    GetPage(
      name: AppRoutes.privacy,
      page: () => const PrivacyScreen(),
      binding: PrivacyBinding(),
    ),
    GetPage(
      name: AppRoutes.education,
      page: () => const EducationScreen(),
      binding: EducationBinding(),
    ),
    GetPage(
      name: AppRoutes.educationTopic,
      page: () => const EducationTopicDetailScreen(),
      binding: EducationBinding(),
    ),
    unknownRoute,
  ];

  static final unknownRoute = GetPage(
    name: AppRoutes.notFound,
    page: () => const NotFoundScreen(),
  );

  /// Exact paths only: queries do not select a different destination, while
  /// trailing slashes and unsupported descendants are not aliases.
  Route<dynamic> resolve(RouteSettings settings) {
    final uri = Uri.tryParse(settings.name ?? '');
    var destination = unknownRoute;
    if (uri != null &&
        !uri.hasScheme &&
        !uri.hasAuthority &&
        !uri.hasFragment) {
      for (final page in pages) {
        if (page.name == uri.path) {
          destination = page;
          break;
        }
      }
    }
    return GetPageRoute<dynamic>(
      settings: RouteSettings(
        name: destination.name,
        arguments: settings.arguments,
      ),
      page: destination.page,
      binding: destination.binding,
      transitionDuration: Get.defaultTransitionDuration,
    );
  }

  List<Route<dynamic>> initialRoutes(String name) => [
    resolve(RouteSettings(name: name)),
  ];
}
