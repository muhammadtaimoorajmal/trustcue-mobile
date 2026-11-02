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
    debugPrint('AuthCallbackCoordinator: handleCallbackUri: $uri');
    // Check if URI targets TrustCue auth callback
    final isCallback =
        (uri.scheme == 'trustcue' && uri.host == 'auth-callback') ||
        uri.path.contains('auth-callback');
    if (!isCallback) return;

    if (_isHandling) return;
    _isHandling = true;

    try {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      final allParams = <String, String>{
        ...uri.queryParameters,
        ...fragmentParams,
      };

      final type = allParams['type'];
      final error = allParams['error_description'] ?? allParams['error'];
      final errorCode = allParams['error_code'];

      // 1. Explicit error in callback (e.g. expired link, access denied)
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

      // 2. Delegate token/code exchange to repository
      await authRepository.handleAuthCallback(uri);

      // 3. Password recovery route
      if (type == 'recovery' ||
          authRepository.currentStatus == AuthStatus.recoverySession) {
        _onNavigate(AppRoutes.authResetPassword);
        return;
      }

      // Explicit profile setup route
      if (type == 'profile-setup' || type == 'setup') {
        _onNavigate(AppRoutes.profileSetup);
        return;
      }

      // 4. Successful authenticated session
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

      // 5. Signup confirmation succeeded on server or requires manual password entry
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
    } finally {
      _isHandling = false;
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
