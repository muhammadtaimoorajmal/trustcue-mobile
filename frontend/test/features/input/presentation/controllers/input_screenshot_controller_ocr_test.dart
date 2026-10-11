import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trustcue_mobile/core/types/result.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/image_picker_adapter.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/screenshot_storage_service.dart';
import 'package:trustcue_mobile/features/input/domain/contracts/text_recognition_service.dart';
import 'package:trustcue_mobile/features/input/domain/models/input_source.dart';
import 'package:trustcue_mobile/features/input/domain/models/ocr_failure.dart';
import 'package:trustcue_mobile/features/input/domain/models/ocr_result.dart';
import 'package:trustcue_mobile/features/input/domain/models/selected_image_descriptor.dart';
import 'package:trustcue_mobile/features/input/domain/models/text_snapshot.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/input_screenshot_controller.dart';
import 'package:trustcue_mobile/features/input/presentation/controllers/screenshot_recovery_coordinator.dart';

class FakePickerAdapter implements ImagePickerAdapter {
  XFile? candidateFile;
  @override
  Future<XFile?> pickImage() async => candidateFile;
  @override
  Future<LostDataResponse?> retrieveLostData() async => null;
}

class FakeStorageService implements ScreenshotStorageService {
  final List<String> deletedFiles = [];
  int importCount = 0;

  @override
  Future<Directory> getScreenshotDirectory() async => Directory.systemTemp;

  @override
  Future<File> importCandidateFile(
    XFile sourceFile, {
    String? fileExtension,
  }) async {
    importCount++;
    return File(sourceFile.path);
  }

  @override
  Future<bool> deleteOwnedFile(String filePath) async {
    deletedFiles.add(filePath);
    return true;
  }

  @override
  Future<int> cleanupOrphanFiles({
    Set<String> keepFilePaths = const {},
  }) async => 0;
}

class FakeTextRecognitionService implements TextRecognitionService {
  Result<OcrResult>? nextResult;
  Completer<Result<OcrResult>>? inFlightCompleter;
  int processCalls = 0;
  String? lastFilePath;
  String? lastImageRevision;
  String? lastOperationToken;
  final Set<String> cancelledTokens = {};
  bool isDisposed = false;

  @override
  Future<Result<OcrResult>> processImage({
    required String filePath,
    required String imageRevision,
    required String operationToken,
    Duration? timeout,
  }) async {
    processCalls++;
    lastFilePath = filePath;
    lastImageRevision = imageRevision;
    lastOperationToken = operationToken;

    if (inFlightCompleter != null) {
      return inFlightCompleter!.future;
    }
    return nextResult ??
        Result.success(
          OcrResult(
            snapshot: TextSnapshot(
              id: 'snap-1',
              source: InputSource.screenshot,
              text: 'Recognized test message',
              createdAt: DateTime.now().toUtc(),
            ),
            imageRevision: imageRevision,
            extractionTimestamp: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  Future<void> cancelOperation(String operationToken) async {
    cancelledTokens.add(operationToken);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
  }
}

void main() {
  late FakePickerAdapter fakePicker;
  late FakeStorageService fakeStorage;
  late FakeTextRecognitionService fakeOcr;
  late InputScreenshotController controller;
  late Directory tempDir;
  late File samplePng;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('controller_ocr_test_');
    samplePng = File('${tempDir.path}/test.png');
    // Valid 32x32 PNG header
    samplePng.writeAsBytesSync([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // magic bytes
      0x00, 0x00, 0x00, 0x0D, // IHDR length
      0x49, 0x48, 0x44, 0x52, // IHDR
      0x00, 0x00, 0x00, 0x20, // width 32
      0x00, 0x00, 0x00, 0x20, // height 32
      0x08, 0x06, 0x00, 0x00, 0x00, // bit depth, color type, compression
      0x00, 0x00, 0x00, 0x00, // CRC
    ]);

    fakePicker = FakePickerAdapter();
    fakeStorage = FakeStorageService();
    fakeOcr = FakeTextRecognitionService();
    controller = InputScreenshotController(
      pickerAdapter: fakePicker,
      storageService: fakeStorage,
      ocrService: fakeOcr,
      ocrTimeout: const Duration(seconds: 1),
    );
  });

  tearDown(() {
    controller.onClose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  void selectSampleImage() {
    controller.selectedImage.value = SelectedImageDescriptor(
      id: 'img-1',
      format: ImageFormat.png,
      width: 32,
      height: 32,
      byteCount: samplePng.lengthSync(),
      filePath: samplePng.path,
    );
  }

  test(
    'Selecting or recovering an image does NOT trigger OCR automatically',
    () {
      final coordinator = ScreenshotRecoveryCoordinator();
      coordinator.pendingRecoveredImage.value = SelectedImageDescriptor(
        id: 'img-rec',
        format: ImageFormat.png,
        width: 32,
        height: 32,
        byteCount: 100,
        filePath: samplePng.path,
      );

      final recoveryController = InputScreenshotController(
        pickerAdapter: fakePicker,
        storageService: fakeStorage,
        ocrService: fakeOcr,
        recoveryCoordinator: coordinator,
      );
      recoveryController.onInit();

      expect(recoveryController.hasImage, isTrue);
      expect(recoveryController.hasExtractedText, isFalse);
      expect(fakeOcr.processCalls, equals(0));

      recoveryController.onClose();
    },
  );

  test(
    'Successful extractText creates OcrResult with InputSource.screenshot',
    () async {
      selectSampleImage();

      fakeOcr.nextResult = Result.success(
        OcrResult(
          snapshot: TextSnapshot(
            id: 'snap-100',
            source: InputSource.screenshot,
            text: 'Urgent: Verify your account.',
            createdAt: DateTime.now().toUtc(),
          ),
          imageRevision: 'img-1',
          extractionTimestamp: DateTime.now().toUtc(),
        ),
      );

      await controller.extractText();

      expect(fakeOcr.processCalls, equals(1));
      expect(controller.hasExtractedText, isTrue);
      expect(
        controller.ocrResult.value!.snapshot.text,
        'Urgent: Verify your account.',
      );
      expect(
        controller.ocrResult.value!.snapshot.source,
        InputSource.screenshot,
      );
      expect(controller.ocrFailure.value, isNull);
      expect(controller.isExtracting.value, isFalse);
    },
  );

  test('Empty extraction produces noReadableTextFound failure', () async {
    selectSampleImage();

    fakeOcr.nextResult = Result.failure(
      const OcrFailure.noReadableTextFound().toAnalysisFailure(),
    );

    await controller.extractText();

    expect(controller.hasExtractedText, isFalse);
    expect(controller.ocrFailure.value, isNotNull);
    expect(
      controller.ocrFailure.value!.code,
      equals(OcrFailureCode.noReadableTextFound),
    );
    expect(controller.isExtracting.value, isFalse);
  });

  test('Exceeding text limits produces outputExceedsLimits failure', () async {
    selectSampleImage();

    fakeOcr.nextResult = Result.failure(
      const OcrFailure.outputExceedsLimits().toAnalysisFailure(),
    );

    await controller.extractText();

    expect(controller.hasExtractedText, isFalse);
    expect(
      controller.ocrFailure.value!.code,
      equals(OcrFailureCode.outputExceedsLimits),
    );
  });

  test('Duplicate taps while extraction is active are ignored', () async {
    selectSampleImage();

    final completer = Completer<Result<OcrResult>>();
    fakeOcr.inFlightCompleter = completer;

    final first = controller.extractText();
    expect(controller.isExtracting.value, isTrue);

    // Second tap should be ignored
    final second = controller.extractText();
    expect(fakeOcr.processCalls, equals(1));

    completer.complete(
      Result.success(
        OcrResult(
          snapshot: TextSnapshot(
            id: 'snap-1',
            source: InputSource.screenshot,
            text: 'Text',
            createdAt: DateTime.now().toUtc(),
          ),
          imageRevision: 'img-1',
          extractionTimestamp: DateTime.now().toUtc(),
        ),
      ),
    );

    await first;
    await second;
    expect(fakeOcr.processCalls, equals(1));
  });

  test(
    'User cancellation sets userCancelled failure and notifies service',
    () async {
      selectSampleImage();

      final completer = Completer<Result<OcrResult>>();
      fakeOcr.inFlightCompleter = completer;

      final extractionFuture = controller.extractText();
      expect(controller.isExtracting.value, isTrue);

      await controller.cancelExtraction();

      expect(controller.isExtracting.value, isFalse);
      expect(
        controller.ocrFailure.value!.code,
        equals(OcrFailureCode.userCancelled),
      );
      expect(fakeOcr.cancelledTokens.isNotEmpty, isTrue);

      // Later native completion should be ignored
      completer.complete(
        Result.success(
          OcrResult(
            snapshot: TextSnapshot(
              id: 'late',
              source: InputSource.screenshot,
              text: 'Late text',
              createdAt: DateTime.now().toUtc(),
            ),
            imageRevision: 'img-1',
            extractionTimestamp: DateTime.now().toUtc(),
          ),
        ),
      );

      await extractionFuture;
      expect(controller.ocrResult.value, isNull);
      expect(
        controller.ocrFailure.value!.code,
        equals(OcrFailureCode.userCancelled),
      );
    },
  );

  test(
    'Replacing image invalidates previous OCR result and active extraction',
    () async {
      selectSampleImage();

      controller.ocrResult.value = OcrResult(
        snapshot: TextSnapshot(
          id: 'old',
          source: InputSource.screenshot,
          text: 'Old OCR text',
          createdAt: DateTime.now().toUtc(),
        ),
        imageRevision: 'img-1',
        extractionTimestamp: DateTime.now().toUtc(),
      );

      final newPng = File('${tempDir.path}/new.png');
      newPng.writeAsBytesSync(samplePng.readAsBytesSync());
      fakePicker.candidateFile = XFile(newPng.path);

      final replaced = await controller.chooseImage();
      expect(replaced, isTrue);

      // Old OCR result is invalidated
      expect(controller.ocrResult.value, isNull);
      expect(controller.ocrFailure.value, isNull);
    },
  );

  test(
    'Source file deletion is deferred while active native read is in progress',
    () async {
      selectSampleImage();

      final completer = Completer<Result<OcrResult>>();
      fakeOcr.inFlightCompleter = completer;

      final extractionFuture = controller.extractText();

      // While extraction is reading samplePng.path, user triggers image replacement
      final newPng = File('${tempDir.path}/new.png');
      newPng.writeAsBytesSync(samplePng.readAsBytesSync());
      fakePicker.candidateFile = XFile(newPng.path);

      // Pick new image
      await controller.chooseImage();

      // samplePng was NOT deleted immediately because it was being read
      expect(fakeStorage.deletedFiles.contains(samplePng.path), isFalse);

      // Now native read completes
      completer.complete(
        Result.failure(const OcrFailure.userCancelled().toAnalysisFailure()),
      );
      await extractionFuture;

      // After native read settles, pending deletion is flushed
      expect(fakeStorage.deletedFiles.contains(samplePng.path), isTrue);
    },
  );

  test('Disposal while extraction is pending cancels and cleans up without throwing', () async {
    selectSampleImage();

    final completer = Completer<Result<OcrResult>>();
    fakeOcr.inFlightCompleter = completer;

    unawaited(controller.extractText());
    expect(controller.isExtracting.value, isTrue);

    controller.onClose();
    expect(fakeOcr.isDisposed, isTrue);

    // Complete late
    completer.complete(
      Result.success(
        OcrResult(
          snapshot: TextSnapshot(
            id: 'late',
            source: InputSource.screenshot,
            text: 'Text',
            createdAt: DateTime.now().toUtc(),
          ),
          imageRevision: 'img-1',
          extractionTimestamp: DateTime.now().toUtc(),
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 10));
    // No unhandled errors thrown
  });
}
