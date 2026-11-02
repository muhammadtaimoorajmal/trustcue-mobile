import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/app/routes/app_pages.dart';
import 'package:trustcue_mobile/app/routes/app_routes.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_callback_coordinator.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:trustcue_mobile/features/incoming_share/domain/contracts/incoming_share_adapter.dart';
import 'package:trustcue_mobile/features/incoming_share/domain/models/incoming_share_payload.dart';
import 'package:trustcue_mobile/features/incoming_share/presentation/controllers/incoming_share_coordinator.dart';
import 'package:trustcue_mobile/features/onboarding/data/onboarding_preferences.dart';

import '../mocks/fake_auth_repository.dart';

class _FakeShareAdapter implements IncomingShareAdapter {
  final _controller = StreamController<IncomingSharePayload>.broadcast();
  IncomingSharePayload? initialShare;
  final List<String> consumedIds = [];

  void emitShare(IncomingSharePayload payload) => _controller.add(payload);

  @override
  Stream<IncomingSharePayload> get shareStream => _controller.stream;

  @override
  Future<IncomingSharePayload?> getInitialShare() async => initialShare;

  @override
  Future<bool> consumeShare(String eventId) async {
    consumedIds.add(eventId);
    return true;
  }

  @override
  Future<bool> cleanStagedFile(String filePath) async => true;

  @override
  void dispose() => _controller.close();
}

class _TestPreferences implements OnboardingPreferences {
  @override
  Future<int?> readVersion() async => OnboardingPreferences.currentVersion;

  @override
  Future<void> saveVersion(int newVersion) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeShareAdapter fakeShareAdapter;
  late IncomingShareCoordinator shareCoordinator;
  late FakeAuthRepository fakeAuthRepo;
  late AuthController authController;
  late AuthCallbackCoordinator authCoordinator;
  String? lastNavigatedRoute;

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    lastNavigatedRoute = null;

    fakeShareAdapter = _FakeShareAdapter();
    shareCoordinator = IncomingShareCoordinator(
      adapter: fakeShareAdapter,
      preferences: _TestPreferences(),
    );
    await shareCoordinator.init();

    fakeAuthRepo = FakeAuthRepository();
    authController = AuthController(authRepository: fakeAuthRepo);
    Get.put<AuthController>(authController);

    authCoordinator = AuthCallbackCoordinator(
      authRepository: fakeAuthRepo,
      authController: authController,
      onNavigate: (route, {arguments}) {
        lastNavigatedRoute = route;
        return null;
      },
    );
  });

  tearDown(() {
    fakeShareAdapter.dispose();
    authCoordinator.dispose();
    Get.reset();
  });

  test(
    'auth callback intent does not emit into incoming share stream',
    () async {
      // When an auth callback deep link arrives at the app,
      // MainActivity routes it to AppLinks/Flutter, NEVER to trustcue/incoming_share.
      // Simulate auth callback delivery:
      final uri = Uri.parse(
        'trustcue://auth-callback#access_token=test_jwt&refresh_token=test_refresh&type=recovery',
      );

      await authCoordinator.handleCallbackUri(uri);

      // Incoming share state remains untouched
      expect(shareCoordinator.pendingShare.value, isNull);
      expect(shareCoordinator.isDialogVisible.value, isFalse);

      // Auth callback routed appropriately to reset password
      expect(lastNavigatedRoute, AppRoutes.authResetPassword);
    },
  );

  test(
    'genuine incoming share intent is accepted by share coordinator',
    () async {
      fakeShareAdapter.emitShare(
        IncomingSharePayload.text(
          eventId: 'share-1',
          text: 'Suspicious text message to analyze',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(shareCoordinator.pendingShare.value, isNotNull);
      expect(
        shareCoordinator.pendingShare.value?.text,
        'Suspicious text message to analyze',
      );
    },
  );

  test('unsupported multiple share intent surfaces unsupported payload in share coordinator', () async {
    fakeShareAdapter.emitShare(
      IncomingSharePayload.unsupported(
        eventId: 'share-multi',
        errorMessage: 'Sharing multiple items at once is not supported. Please share one message or one image.',
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(shareCoordinator.pendingShare.value, isNotNull);
    expect(shareCoordinator.pendingShare.value?.isUnsupported, isTrue);
    expect(
      shareCoordinator.pendingShare.value?.errorMessage,
      contains('Sharing multiple items at once is not supported'),
    );
  });

  test('AppPages.resolve maps trustcue://auth-callback routes to auth destinations rather than notFound', () {
    final pages = AppPages(_TestPreferences());
    final route1 = pages.resolve(
      const RouteSettings(name: 'trustcue://auth-callback#type=recovery'),
    );
    expect(route1.settings.name, AppRoutes.authResetPassword);

    final route2 = pages.resolve(
      const RouteSettings(name: 'trustcue://auth-callback?code=xyz'),
    );
    expect(route2.settings.name, AppRoutes.authLogin);

    final routeSetup = pages.resolve(
      const RouteSettings(name: 'trustcue://auth-callback#type=profile-setup'),
    );
    expect(routeSetup.settings.name, AppRoutes.profileSetup);

    final route3 = pages.resolve(
      const RouteSettings(name: 'https://example.com/unrelated'),
    );
    expect(route3.settings.name, AppRoutes.notFound);
  });
}
