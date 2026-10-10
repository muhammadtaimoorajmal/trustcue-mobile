# TrustCue

TrustCue is a Mobile Application Development project for CS3643, BSCS Semester 5-1, Fall 2026, at Riphah International University.
The application is designed to help people worldwide understand potential scam indicators in suspicious digital communication.

## Project Status
Currently, the project contains only the Flutter foundation scaffold. Product features and backend integration have not yet been implemented.

## Repository Structure
- `frontend/`: The Flutter application (TrustCue), including its client services and future local-storage adapters.
- `backend/`: Future server APIs and protected AI-provider integration.
- `database/`: Future database definitions, migrations, synthetic fixtures, and documentation.

## Project Documentation
- [Project State](docs/PROJECT_STATE.md)
- [Module Log](docs/MODULE_LOG.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Design Specification](docs/DESIGN_SPEC.md)
- [Design Brand Board](docs/design/brand_board.svg)

## Development & Phone Verification
To verify the development baseline, navigate to the `frontend/` directory and run the following checks:

```bash
cd frontend
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

### Verified Toolchain
- **Flutter:** 3.47.4
- **Dart SDK:** 3.13.3
- **NDK:** 30.0.16138531 (Configured in `frontend/android/app/build.gradle.kts`)
- **Gradle Wrapper:** 9.3.1

### Physical Phone Testing via VS Code
1. Enable **Developer Options** and **USB Debugging** on your Android device.
2. Connect your device via USB (select "File Transfer" or "PTP" mode if prompted).
3. Open a terminal and run `flutter devices` to ensure your device is listed and authorized. If it says "unauthorized", check your phone screen to accept the USB debugging prompt.
4. In VS Code, go to the **Run and Debug** view (`Ctrl+Shift+D`).
5. Select **"TrustCue Mobile"** from the dropdown configuration and click the green Play button to launch.
6. Verify the sample counter increments and hot reload works upon saving `main.dart`.

### Running Integration Tests
To run automated device integration tests, first get your device identifier by running:
```bash
flutter devices
```
Then run the integration test suite, replacing `<ACTUAL_DEVICE_ID>` with your specific device ID:
```bash
flutter test integration_test/app_smoke_test.dart -d "<ACTUAL_DEVICE_ID>"
```

### Component Preview
To launch the standalone component development preview on your connected phone:
```bash
flutter run -d "ACTUAL_DEVICE_ID" -t lib/dev/component_preview.dart
```

To restore the normal application after checking the preview:
```bash
flutter run -d "ACTUAL_DEVICE_ID" -t lib/main.dart
```