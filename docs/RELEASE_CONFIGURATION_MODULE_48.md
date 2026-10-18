# TrustCue Module 48: Android Release Configuration, Branding, Signing, and AAB

## Executive Summary
This document provides the authoritative release engineering, visual identity, security signing, and binary verification record for **TrustCue Module 48: Android Release Configuration, Branding, Signing, and AAB**.

The release configuration establishes production-grade packaging, strict secret isolation, optimized R8 code/resource shrinking, official TrustCue brand presentation, and cryptographic signing for Google Play Store distribution and independent physical device deployment.

---

## 1. Application Identity and Target Platform Specifications

### 1.1 Package & Identity Attributes
| Attribute | Configured Value | Verification Location |
|---|---|---|
| **Application ID / Package Name** | `io.github.muhammadtaimoorajmal.trustcue` | `frontend/android/app/build.gradle.kts`<br>`frontend/android/app/src/main/AndroidManifest.xml` |
| **Application Label** | `TrustCue` | `AndroidManifest.xml` (`android:label`) |
| **Version Name** | `0.1.0` | `frontend/pubspec.yaml` |
| **Version Code** | `1` | `frontend/pubspec.yaml` |
| **Main Activity** | `io.github.muhammadtaimoorajmal.trustcue.MainActivity` | `AndroidManifest.xml` |

### 1.2 SDK, Compiler & Native Toolchain
| Toolchain Element | Version / Specification | Rationale / Enforcing Configuration |
|---|---|---|
| **Compile SDK** | `36` (Android 15+) | Evaluated by Flutter Gradle Plugin (`flutter.compileSdkVersion`) |
| **Target SDK** | `36` (Android 15+) | Evaluated by Flutter Gradle Plugin (`flutter.targetSdkVersion`) |
| **Minimum SDK** | `24` (Android 7.0 Nougat) | Evaluated by Flutter Gradle Plugin (`flutter.minSdkVersion`), aligned with modern crypto / secure storage |
| **Android NDK** | `30.0.16138531` (`r30-beta3`) | Pinned in `frontend/android/build.gradle.kts` and applied across all native subprojects (e.g. `:jni`) |
| **Java Compatibility** | Java 17 | `compileOptions.sourceCompatibility = JavaVersion.VERSION_17`<br>`compileOptions.targetCompatibility = JavaVersion.VERSION_17`<br>`kotlinOptions.jvmTarget = "17"` |
| **Gradle / AGP** | Gradle 9.3.1 / AGP 8.7.0+ | OpenJDK 21.0.12.1 Temurin LTS runner environment |

### 1.3 Security, Backup & Network Policies
- **Data Extraction Prevention (`android:allowBackup="false"`):** The application explicitly disables Android adb/cloud device backups to prevent local SQLite databases, cached files, or preferences from being extracted from unencrypted device backups.
- **Internet Permission:** Added `<uses-permission android:name="android.permission.INTERNET"/>` to `src/main/AndroidManifest.xml`. While Flutter debug harnesses inject this automatically, production release builds require explicit declaration to communicate with the hosted FastAPI backend (`https://trustcue-backend.onrender.com`) and Supabase GoTrue authentication.
- **Round Icon Declaration:** Added `android:roundIcon="@mipmap/ic_launcher_round"` to support circular launcher surfaces on modern Android OEM skins.

---

## 2. Visual Direction, Brand Assets & Splash Presentation

### 2.1 Approved Color Palette
Derived from the official TrustCue brand specification (`docs/design/brand_board.svg`):
- **Deep Navy (`#0A2540`):** Core background for brand mark, launcher background, and primary theme canvas.
- **Dark Teal (`#00695C`):** Primary brand accent, base shield fill, and action highlight.
- **Light Teal (`#4DB6AC`):** Accent highlights, shield inner contours, and dark theme primary accents.
- **Caution Amber (`#FFB300` / `#FFCA28`):** Warning indicator cue dot, focal awareness element.
- **Pure White (`#FFFFFF`):** High-contrast verification cue path within the shield.
- **Midnight Black (`#05121F`):** Deep contrast background for night-mode launcher assets.

Defined in:
- `frontend/android/app/src/main/res/values/colors.xml`
- `frontend/android/app/src/main/res/values-night/colors.xml`

### 2.2 Launcher Vector & Adaptive Assets
1. **Background Layer (`res/drawable/ic_launcher_background.xml`):**
   - 108dp x 108dp vector canvas filled with Deep Navy (`#0A2540`), supporting seamless adaptive launcher masking (circle, squircle, rounded rectangle).
2. **Foreground Layer (`res/drawable/ic_launcher_foreground.xml`):**
   - 108dp x 108dp vector canvas containing the brand shield (Dark Teal `#00695C`), inner accent highlight (Light Teal `#4DB6AC`), centered verification cue mark (Pure White `#FFFFFF`), and upper-right awareness signal dot (Caution Amber `#FFB300`).
   - Kept within the 72dp safe zone to prevent clipping across all adaptive icon mask styles.
3. **Adaptive Launcher XMLs:**
   - `res/mipmap-anydpi-v26/ic_launcher.xml`: Pairs background and foreground drawables.
   - `res/mipmap-anydpi-v26/ic_launcher_round.xml`: Pairs background and foreground drawables for circular launchers.

### 2.3 Legacy Raster Mipmaps
For legacy devices (pre-Android 8.0 API 26) and home launchers requesting raster drawables, pixel-perfect PNG mipmaps were generated with 4x supersampling and Lanczos downsampling:
| Density Qualifier | Target Dimensions | Files Generated |
|---|---|---|
| `mipmap-mdpi` | 48 x 48 px | `ic_launcher.png`, `ic_launcher_round.png` |
| `mipmap-hdpi` | 72 x 72 px | `ic_launcher.png`, `ic_launcher_round.png` |
| `mipmap-xhdpi` | 96 x 96 px | `ic_launcher.png`, `ic_launcher_round.png` |
| `mipmap-xxhdpi` | 144 x 144 px | `ic_launcher.png`, `ic_launcher_round.png` |
| `mipmap-xxxhdpi` | 192 x 192 px | `ic_launcher.png`, `ic_launcher_round.png` |

### 2.4 Branded Splash Screen
Updated `res/drawable/launch_background.xml` and `res/drawable-v21/launch_background.xml`:
- Canvas filled with Deep Navy (`#0A2540`).
- Centered 120dp vector emblem (`res/drawable/ic_splash_logo.xml`) depicting the TrustCue shield, verification cue, and amber indicator dot.
- Smooth visual transition into the Flutter engine startup screen.

---

## 3. ProGuard and R8 Optimization Configuration

R8 code shrinking and resource shrinking are enabled for production builds in `frontend/android/app/build.gradle.kts`:
```kotlin
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

### 3.1 Hardened Rules (`proguard-rules.pro`)
A comprehensive ruleset was created at `frontend/android/app/proguard-rules.pro` to protect reflection, JNI bindings, and serialization interfaces:
1. **Flutter Engine & Embedding:**
   - Keeps Flutter embedding, plugin registries, and method channels (`io.flutter.**`).
2. **Google ML Kit Vision & Barcode Scanning:**
   - Keeps Vision, OCR, and Barcode models and native library loaders (`com.google.mlkit.**`, `com.google.android.gms.vision.**`).
3. **AndroidX Security & Hardware Keystore:**
   - Keeps `androidx.security.crypto.**` and `flutter_secure_storage` JNI wrappers to prevent Keystore encryption failures.
4. **SQLite (`sqflite`):**
   - Keeps native SQLite bindings (`com.tekartik.sqflite.**`).
5. **Protobuf & Serialization:**
   - Keeps Protobuf generated classes and reflection descriptors (`com.google.protobuf.**`).
6. **Deferred Components Suppress Warning:**
   - Adds `-dontwarn com.google.android.play.core.**` to prevent harmless missing Play Core split-install warnings from halting R8 compilation when deferred components are not utilized.

---

## 4. Release Keystore and Signing Architecture

### 4.1 Keystore Specifications
| Keystore Parameter | Value |
|---|---|
| **Keystore File** | `frontend/android/upload-keystore.jks` |
| **Keystore Format** | PKCS12 (standard Java KeyStore) |
| **Key Alias** | `trustcue-upload` |
| **Key Algorithm** | RSA 4096-bit |
| **Validity Period** | 10,000 days (~27 years) |
| **Distinguished Name** | `CN=TrustCue Release Signer, OU=Mobile Security, O=TrustCue, L=London, ST=Greater London, C=GB` |
| **Certificate SHA-256** | `66:B3:FB:99:5D:CA:5A:C2:CA:17:BE:D7:9C:9D:74:65:36:83:21:29:D4:EE:3D:38:45:61:F1:F6:09:CB:CD:9F` |
| **Certificate SHA-1** | `F4:FF:6A:B9:E1:92:4B:B5:18:1C:18:CE:57:9B:74:B3:AC:FA:7E:67` |

### 4.2 Strict Git Hygiene & Secret Exclusion
- Keystores (`*.jks`, `*.keystore`) and property files (`key.properties`) are strictly excluded in `.gitignore` across project root, `frontend/`, and `frontend/android/`.
- Neither keystore files nor passwords exist in git tracking or commit history.
- The keystore password is maintained privately by the repository owner and loaded locally via `frontend/android/key.properties`.

### 4.3 Fail-Safe Gradle Signing Validation
In `frontend/android/app/build.gradle.kts`:
- If `key.properties` exists, credentials are parsed and applied to `signingConfigs.create("release")`.
- If `key.properties` is missing, release builds actively fail with a descriptive `GradleException`:
  ```
  Release signing configuration is missing. Please create android/key.properties with storeFile, storePassword, keyAlias, and keyPassword to build release artifacts.
  ```
- **Debug Builds Resilient:** Standard debug builds (`assembleDebug`, CI test runners) do not evaluate release credentials and continue to build cleanly using default debug keystores.

---

## 5. Production Artifact Verification

### 5.1 Artifact Summary & Checksums
Both artifacts were compiled using Flutter 3.47.4 / Dart 3.11.0:

| Artifact | File Path | File Size | SHA-256 Checksum |
|---|---|---|---|
| **Signed Release APK** | `build/app/outputs/flutter-apk/app-release.apk` | 108,831,743 bytes (103.79 MB) | `883e2f04314632277b01d3df1962fa56f69a6f82f47f98ae501f0b23da330f58` |
| **Signed Release AAB** | `build/app/outputs/bundle/release/app-release.aab` | 82,213,947 bytes (78.41 MB) | `7fea32f893512ecf22c3bb229e97101502196d61e719e88c48b567866f2e94fa` |

### 5.2 APK Signature Verification (`apksigner`)
Verification command:
```powershell
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
```
Output results:
- **Verifies:** `true`
- **Number of signers:** 1
- **Signature Scheme v1 (JAR signing):** `true`
- **Signature Scheme v2 (APK Signature Scheme v2):** `true`
- **Signature Scheme v3 (APK Signature Scheme v3):** `true`
- **Signature Scheme v4:** `false`
- **Signer 1 Certificate DN:** `CN=TrustCue Release Signer, OU=Mobile Security, O=TrustCue, L=London, ST=Greater London, C=GB`
- **Signer 1 SHA-256:** `66b3fb995dca5ac2ca17bed79c9d746536832129d4ee3d384561f1f609cbcd9f`

### 5.3 Badging & Manifest Verification (`aapt`)
Inspection command:
```powershell
aapt dump badging build/app/outputs/flutter-apk/app-release.apk
```
Verified badging details:
- `package: name='io.github.muhammadtaimoorajmal.trustcue' versionCode='1' versionName='0.1.0'`
- `application-label:'TrustCue'`
- `application-icon-160:'res/mipmap-anydpi-v26/ic_launcher.xml'`
- `application-icon-640:'res/mipmap-anydpi-v26/ic_launcher.xml'`
- `uses-permission: name='android.permission.INTERNET'`
- `native-code: 'arm64-v8a' 'armeabi-v7a' 'x86_64'`
- **Non-Debuggable Flag:** Verified `android:debuggable` is **absent** (non-debuggable production binary).

### 5.4 Secret Scanning of Packaged Binaries
Extracted and inspected the contents of both `app-release.apk` and `app-release.aab`:
- Scanned for `.env`, `key.properties`, `upload-keystore.jks`, private tokens, and API secrets.
- **Result:** 0 sensitive configuration files or signing keys packaged inside release artifacts.

---

## 6. Physical Device Live Verification

Live verification was performed on connected physical hardware:
- **Device Model:** Vivo V2207 (`10AC9R1ABF0013A`)
- **Android Version:** Android 14 (API level 34)
- **Architecture:** `arm64-v8a`

### 6.1 Installation & Startup
1. **Certificate Preflight:** Checked device package manager; no conflicting debug signature or previous installation existed.
2. **Installation:**
   ```powershell
   adb -s 10AC9R1ABF0013A install -r build/app/outputs/flutter-apk/app-release.apk
   ```
   **Result:** `Performing Streamed Install` -> `Success`.
3. **Application Launch:**
   ```powershell
   adb -s 10AC9R1ABF0013A shell am start -n io.github.muhammadtaimoorajmal.trustcue/.MainActivity
   ```
   **Result:** `Starting: Intent { cmp=io.github.muhammadtaimoorajmal.trustcue/.MainActivity }`
   `Activity: io.github.muhammadtaimoorajmal.trustcue/.MainActivity` -> `Complete`.

### 6.2 Process & Native Runtime Verification
- **Active Process:** PID `21147` (`io.github.muhammadtaimoorajmal.trustcue`).
- **Foreground Activity:** `ResumedActivity: ActivityRecord{... io.github.muhammadtaimoorajmal.trustcue/.MainActivity}`.
- **Logcat Engine Inspection:**
  - Impeller OpenGLES rendering backend initialized successfully.
  - Native libraries (`libflutter.so`, `libapp.so`) loaded cleanly without link or symbol errors.
  - 0 native crashes (`SIGSEGV`, `SIGABRT`).
  - 0 Android Runtime exceptions or ANRs (`Application Not Responding`).

---

## 7. Quality Assurance & Regression Suite

| Verification Gate | Command Executed | Result |
|---|---|---|
| **Static Code Analysis** | `flutter analyze --no-pub` | **0 issues found** across all 311 files |
| **Automated Unit & Widget Tests** | `flutter test --no-pub` | **860 / 860 passed** (0 failures, 0 regressions) |
| **Debug Build Resilience** | `.\gradlew.bat :app:assembleDebug` | **Passed** (482 tasks up-to-date/executed) |
| **Missing Secret Build Halt** | `.\gradlew.bat :app:assembleRelease` without `key.properties` | **Passed** (Immediately halts with descriptive `GradleException`) |

---

## 8. Handoff to Module 49

With Module 48 complete, the Android release pipeline is fully established, signed, and physically verified. 

**Next Step (Module 49):**
- Google Play Console store listing metadata, screenshots, and localized promotional copy.
- Data Safety disclosures aligning with TrustCue's zero-upload local analysis and explicit cloud consent boundaries.
- Internal testing track deployment preparations.

