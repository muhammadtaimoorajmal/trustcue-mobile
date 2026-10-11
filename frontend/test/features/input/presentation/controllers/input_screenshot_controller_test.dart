import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/image_picker_adapter.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/screenshot_storage_service.dart';
import 'package:trustcue_mobile/features/input/domain/models/selected_image_descriptor.dart';
import 'package:trustcue_mobile/features/input/domain/validation/image_validation_policy.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_screenshot_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/screenshot_recovery_coordinator.dart';

class FakeImagePickerAdapter implements ImagePickerAdapter {
  XFile? nextPickResult;
  bool pickCalled = false;

  @override
  Future<XFile?> pickImage() async {
    pickCalled = true;
    return nextPickResult;
  }

  @override
  Future<LostDataResponse?> retrieveLostData() async => null;
}

class FakeScreenshotStorageService implements ScreenshotStorageService {
  final List<String> deletedPaths = [];
  final Set<String> managedFiles = {};
  int cleanupCallCount = 0;
  Set<String>? lastKeepFilePaths;
  late Directory tempDir;

  @override
  Future<Directory> getScreenshotDirectory() async => tempDir;

  @override
  Future<File> importCandidateFile(
    XFile sourceFile, {
    String? fileExtension,
  }) async {
    final targetFile = File(
      '${tempDir.path}/imported-${managedFiles.length}${fileExtension ?? ".png"}',
    );
    final bytes = await sourceFile.readAsBytes();
    await targetFile.writeAsBytes(bytes);
    managedFiles.add(targetFile.path);
    return targetFile;
  }

  @override
  Future<bool> deleteOwnedFile(String filePath) async {
    deletedPaths.add(filePath);
    managedFiles.remove(filePath);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  @override
  Future<int> cleanupOrphanFiles({Set<String> keepFilePaths = const {}}) async {
    cleanupCallCount++;
    lastKeepFilePaths = keepFilePaths;
    return 0;
  }
}

Uint8List _createValidPngBytes({int width = 200, int height = 300}) {
  return Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    (width >> 24) & 0xFF,
    (width >> 16) & 0xFF,
    (width >> 8) & 0xFF,
    width & 0xFF,
    (height >> 24) & 0xFF,
    (height >> 16) & 0xFF,
    (height >> 8) & 0xFF,
    height & 0xFF,
    0x08,
    0x02,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x44,
    0x41,
    0x54,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeImagePickerAdapter fakePicker;
  late FakeScreenshotStorageService fakeStorage;
  late InputScreenshotController controller;
  var idCounter = 0;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('trustcue_ctrl_test_');
    fakePicker = FakeImagePickerAdapter();
    fakeStorage = FakeScreenshotStorageService()..tempDir = tempDir;
    idCounter = 0;

    controller = InputScreenshotController(
      pickerAdapter: fakePicker,
      storageService: fakeStorage,
      idGenerator: () => '${++idCounter}',
    );
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  test(
    'Initial controller state has no selection and triggers orphan cleanup',
    () {
      controller.onInit();
      expect(controller.hasImage, isFalse);
      expect(controller.selectedImage.value, isNull);
      expect(controller.isProcessing.value, isFalse);
      expect(controller.validationError.value, isNull);
      expect(fakeStorage.cleanupCallCount, 1);
    },
  );

  test('Picker cancellation preserves state without error', () async {
    controller.onInit();
    fakePicker.nextPickResult = null;

    final success = await controller.chooseImage();
    expect(success, isFalse);
    expect(controller.hasImage, isFalse);
    expect(controller.validationError.value, isNull);
  });

  test(
    'Selecting valid PNG imports file, validates, and sets selectedImage',
    () async {
      controller.onInit();
      final sourceFile = File('${tempDir.path}/source.png');
      await sourceFile.writeAsBytes(
        _createValidPngBytes(width: 800, height: 600),
      );
      fakePicker.nextPickResult = XFile(sourceFile.path);

      final success = await controller.chooseImage();
      expect(success, isTrue);
      expect(controller.hasImage, isTrue);
      expect(controller.selectedImage.value, isNotNull);
      expect(controller.selectedImage.value!.width, 800);
      expect(controller.selectedImage.value!.height, 600);
      expect(controller.selectedImage.value!.format, ImageFormat.png);
      expect(controller.validationError.value, isNull);
      expect(fakeStorage.managedFiles.length, 1);
    },
  );

  test('Invalid file sets validationError and leaves existing selection intact', () async {
    controller.onInit();
    // First select a valid image
    final validFile = File('${tempDir.path}/valid.png');
    await validFile.writeAsBytes(_createValidPngBytes());
    fakePicker.nextPickResult = XFile(validFile.path);
    await controller.chooseImage();
    final initialImage = controller.selectedImage.value;
    expect(initialImage, isNotNull);

    // Now try selecting an invalid image (e.g. corrupt or unsupported)
    final invalidFile = File('${tempDir.path}/invalid.png');
    await invalidFile.writeAsBytes([1, 2, 3, 4, 5]); // Invalid format
    fakePicker.nextPickResult = XFile(invalidFile.path);

    final success = await controller.chooseImage();
    expect(success, isFalse);
    expect(controller.validationError.value, isNotNull);
    expect(
      controller.validationError.value!.reason,
      ImageValidationReason.unsupportedFormat,
    );
    // Transactional guarantee: original preview was NOT cleared or overwritten
    expect(controller.selectedImage.value, equals(initialImage));
  });

  test(
    'Transactional replacement deletes old owned copy on new success',
    () async {
      controller.onInit();
      final file1 = File('${tempDir.path}/first.png');
      await file1.writeAsBytes(_createValidPngBytes(width: 400, height: 400));
      fakePicker.nextPickResult = XFile(file1.path);
      await controller.chooseImage();
      final firstDescriptor = controller.selectedImage.value!;
      final firstPath = firstDescriptor.filePath;

      final file2 = File('${tempDir.path}/second.png');
      await file2.writeAsBytes(_createValidPngBytes(width: 600, height: 600));
      fakePicker.nextPickResult = XFile(file2.path);
      final success = await controller.chooseImage();

      expect(success, isTrue);
      expect(controller.selectedImage.value!.width, 600);
      expect(fakeStorage.deletedPaths, contains(firstPath));
    },
  );

  test('Recovery coordinator populates initial selection if recovered image exists', () {
    final recoveredDescriptor = SelectedImageDescriptor(
      id: 'img-recovered',
      format: ImageFormat.png,
      width: 1000,
      height: 1000,
      byteCount: 5000,
      filePath: '${tempDir.path}/recovered.png',
    );

    final coordinator = ScreenshotRecoveryCoordinator()
      ..pendingRecoveredImage.value = recoveredDescriptor;

    final recoveryController = InputScreenshotController(
      pickerAdapter: fakePicker,
      storageService: fakeStorage,
      recoveryCoordinator: coordinator,
    );

    recoveryController.onInit();
    expect(recoveryController.hasImage, isTrue);
    expect(recoveryController.selectedImage.value, equals(recoveredDescriptor));
  });

  test('onClose cleans up owned file', () async {
    controller.onInit();
    final file = File('${tempDir.path}/img.png');
    await file.writeAsBytes(_createValidPngBytes());
    fakePicker.nextPickResult = XFile(file.path);
    await controller.chooseImage();

    final path = controller.selectedImage.value!.filePath;
    controller.onClose();
    expect(fakeStorage.deletedPaths, contains(path));
  });
}
