import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/domain/contracts/auth_repository.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/login_controller.dart';

typedef RouteNavigationHandler = Future<dynamic>? Function(
  String route, {
  dynamic arguments,
});

/// Coordinates incoming authentication deep links (email confirmation, password recovery, OAuth/magic links)
/// and directs the user to the appropriate screen and state.
class AuthCallbackCoordinator {
  AuthCallbackCoordinator({
    required this.authRepository,
    this.authController,
    AppLinks? appLinks,
    RouteNavigationHandler? onNavigate,
  }) : _appLinks = appLinks ?? AppLinks(),
       _onNavigate =
           onNavigate ??
           ((route, {arguments}) =>
               Get.offAllNamed(route, arguments: arguments));

  final AuthRepository authRepository;
  final AuthController? authController;
  final AppLinks _appLinks;
  final RouteNavigationHandler _onNavigate;

  StreamSubscription<Uri>? _sub;
  bool _isHandling = false;
  String? _lastHandledSignature;
  DateTime? _lastHandledAt;

  void init() {
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        handleCallbackUri(uri);
      },
      onError: (Object error) {
        debugPrint('AuthCallbackCoordinator: deep link stream error: $error');
      },
    );

    // Also handle any initial link if app was launched via deep link
    _appLinks
        .getInitialLink()
        .then((uri) {
          if (uri != null) {
            handleCallbackUri(uri);
          }
        })
        .catchError((Object error) {
          debugPrint('AuthCallbackCoordinator: initial link error: $error');
        });
  }

  /// Processes an incoming URI callback and routes navigation.
  Future<void> handleCallbackUri(Uri uri) async {
    // Sanitize logging: NEVER log query or fragment containing secrets/tokens
    debugPrint(
      'AuthCallbackCoordinator: handleCallbackUri: scheme=${uri.scheme}, host=${uri.host}',
    );

    // Strict callback host and scheme validation
    final isCallback = uri.scheme == 'trustcue' && uri.host == 'auth-callback';
    if (!isCallback) return;

    // Prevent duplicate code-exchange races
    final now = DateTime.now();
    final signature =
        '${uri.scheme}://${uri.host}${uri.path}?${uri.queryParameters.keys.join(',')}&#${Uri.splitQueryString(uri.fragment).keys.join(',')}';
    if (_isHandling) return;
    if (_lastHandledSignature == signature &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!).inSeconds < 3) {
      debugPrint('AuthCallbackCoordinator: ignoring duplicate callback event');
      return;
    }

    _isHandling = true;
    _lastHandledSignature = signature;
    _lastHandledAt = now;

    try {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      final allParams = <String, String>{
        ...uri.queryParameters,
        ...fragmentParams,
      };

      final type = allParams['type'];
      final error = allParams['error_description'] ?? allParams['error'];
      final errorCode = allParams['error_code'];

      // 1. Explicit error in callback parameters (e.g. expired link, access denied)
      if (error != null || errorCode != null) {
        final message = (error != null && error.isNotEmpty)
            ? error
            : 'The confirmation link has expired or is invalid. Please sign in or request a new link.';
        if (Get.isRegistered<LoginController>()) {
          final lc = Get.find<LoginController>();
          lc.errorMessage.value = message;
        }
        _onNavigate(
          AppRoutes.authLogin,
          arguments: {'bannerMessage': message, 'isError': true},
        );
        return;
      }

      // 2. Delegate token/code exchange to repository and inspect result
      final exchangeResult = await authRepository.handleAuthCallback(uri);

      if (exchangeResult.isFailure) {
        final message =
            exchangeResult.failureOrNull?.message ??
            'Verification link is invalid or has expired. Please sign in or request a new link.';
        if (Get.isRegistered<LoginController>()) {
          final lc = Get.find<LoginController>();
          lc.errorMessage.value = message;
        }
        _onNavigate(
          AppRoutes.authLogin,
          arguments: {'bannerMessage': message, 'isError': true},
        );
        return;
      }

      // 3. Password recovery route: require authenticated/recovery state
      if (authRepository.currentStatus == AuthStatus.recoverySession ||
          (type == 'recovery' &&
              (authRepository.currentStatus == AuthStatus.authenticated ||
                  authRepository.currentStatus ==
                      AuthStatus.recoverySession))) {
        _onNavigate(AppRoutes.authResetPassword);
        return;
      }

      // 4. Authenticated session
      if (authRepository.currentStatus == AuthStatus.authenticated) {
        final ac =
            authController ??
            (Get.isRegistered<AuthController>()
                ? Get.find<AuthController>()
                : null);

        if (ac != null) {
          await ac.fetchProfile();
          final displayName = ac.profile.value?.displayName;
          if (displayName == null || displayName.trim().isEmpty) {
            _onNavigate(AppRoutes.profileSetup);
            return;
          }
        }
        _onNavigate(AppRoutes.account);
        return;
      }

      // Explicit profile setup route only permitted if authenticated
      if ((type == 'profile-setup' || type == 'setup') &&
          authRepository.currentStatus == AuthStatus.authenticated) {
        _onNavigate(AppRoutes.profileSetup);
        return;
      }

      // 5. Signup confirmation succeeded on server but requires manual sign in
      if (Get.isRegistered<LoginController>()) {
        final lc = Get.find<LoginController>();
        lc.infoMessage.value =
            'Email confirmed! Please sign in with your credentials.';
      }
      _onNavigate(
        AppRoutes.authLogin,
        arguments: {
          'bannerMessage':
              'Email confirmed! Please sign in with your credentials.',
          'isError': false,
        },
      );
    } catch (_) {
      debugPrint('AuthCallbackCoordinator: unexpected error during callback');
      _onNavigate(
        AppRoutes.authLogin,
        arguments: {
          'bannerMessage':
              'An error occurred during verification. Please sign in.',
          'isError': true,
        },
      );
    } finally {
      _isHandling = false;
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
