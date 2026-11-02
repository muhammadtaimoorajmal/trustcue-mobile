import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_state.dart';
import 'package:trustcue_mobile/features/auth/domain/models/auth_user.dart';
import 'package:trustcue_mobile/features/auth/domain/models/user_profile.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:trustcue_mobile/features/auth/presentation/controllers/profile_setup_controller.dart';

import '../../mocks/fake_auth_repository.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController({required super.authRepository});

  String? lastUpdatedName;
  bool nextUpdateSuccess = true;

  @override
  Future<bool> updateDisplayName(String? newDisplayName) async {
    lastUpdatedName = newDisplayName;
    if (nextUpdateSuccess) {
      profile.value = UserProfile(
        userId: 'test-user',
        email: 'test@example.com',
        displayName: newDisplayName,
        emailVerified: true,
        createdAt: DateTime.now(),
        syncEnabled: false,
        quotaRemainingToday: 15,
      );
      return true;
    } else {
      profileError.value = 'Failed to update profile on backend.';
      return false;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository fakeRepo;
  late _FakeAuthController fakeAuthController;
  late ProfileSetupController controller;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    fakeRepo = FakeAuthRepository(
      initialStatus: AuthStatus.authenticated,
      initialUser: AuthUser(
        id: 'user-1',
        email: 'test@example.com',
        emailVerified: true,
        createdAt: DateTime.now(),
      ),
    );
    fakeAuthController = _FakeAuthController(authRepository: fakeRepo);
    Get.put<AuthController>(fakeAuthController);
    controller = ProfileSetupController(authController: fakeAuthController);
  });

  tearDown(() {
    Get.reset();
  });

  test('validates empty display name', () async {
    controller.displayNameController.text = '   ';
    await controller.saveProfile();

    expect(
      controller.errorMessage.value,
      contains('Please enter a display name or choose "Skip for now".'),
    );
    expect(fakeAuthController.lastUpdatedName, isNull);
  });

  test('validates display name exceeding 64 characters', () async {
    controller.displayNameController.text = 'A' * 65;
    await controller.saveProfile();

    expect(
      controller.errorMessage.value,
      contains('Display name cannot exceed 64 characters.'),
    );
    expect(fakeAuthController.lastUpdatedName, isNull);
  });

  test('saves valid display name and updates controller state', () async {
    controller.displayNameController.text = 'Valid Name';
    fakeAuthController.nextUpdateSuccess = true;

    await controller.saveProfile();

    expect(fakeAuthController.lastUpdatedName, 'Valid Name');
    expect(controller.errorMessage.value, isNull);
  });

  test('surfaces error when updateDisplayName fails', () async {
    controller.displayNameController.text = 'Valid Name';
    fakeAuthController.nextUpdateSuccess = false;

    await controller.saveProfile();

    expect(fakeAuthController.lastUpdatedName, 'Valid Name');
    expect(
      controller.errorMessage.value,
      'Failed to update profile on backend.',
    );
  });
}
