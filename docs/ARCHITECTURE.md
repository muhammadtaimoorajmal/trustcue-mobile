# Architecture Conventions

TrustCue is structured to grow sustainably while maintaining a clean separation of concerns.

## Directory Structure

*   `app/`: Owns application composition (`GetMaterialApp`), centralized route definitions, exact route resolution, and route bindings.
*   `core/`: Contains genuinely shared, cross-feature concerns (e.g., logging).
    *   `core/errors/`: Owns structured failure categories (`AnalysisFailure`, `AnalysisFailureCode`).
    *   `core/types/`: Owns typed monads and outcome types (`Result<T>`, `Success<T>`, `Failure<T>`).
    *   `core/theme/`: Owns the visual design system (`AppTheme`, `AppColors`, `AppSemanticColors`). Feature widgets must consume these centralized theme roles (e.g., `Theme.of(context)`) rather than hardcoding raw colors or using template defaults.
    *   `core/widgets/`: Contains reusable, cross-feature UI components (`AppButton`, `AppTextField`, `AppCard`, `AppPageBody`). These wrap Material components with consistent styling, behaviors, and accessibility defaults. They do not contain business logic or domain models.
*   `dev/`: Contains development-only utilities and standalone previews (e.g., `component_preview.dart`). These must not be imported by production routes.
*   `features/<feature>/presentation/`: Contains the feature's UI screens, widgets, and state controllers.
*   `features/<feature>/domain/`: Contains platform-independent business models, invariants, and abstract service contracts (e.g., `TextSnapshot`, `AnalysisReport`, `AnalysisService`). Domain entities must never import Flutter widgets, GetX, or platform plugins.
*   `features/<feature>/data/`: Contains feature data sources and serialization codecs (e.g., `TextSnapshotCodec`, `AnalysisReportCodec`).
*   *Future Data/Domain:* Feature-specific data access, models, and business logic remain strictly isolated within the owning feature. Business rules, network calls, OCR, and persistence must remain completely separated from UI components. Domain layers or additional abstractions should be introduced *only* when actual complexity requires them.

## Layout and Boundaries

*   **Responsive Layouts:** Handled by `AppPageBody` (in `core/widgets/`). This wrapper establishes the maximum content width (720px), shared responsive padding based on screen width, and scrollability.
*   **System Insets (Safe Area):** `AppPageBody` owns the primary `SafeArea` wrapping the page content. Screens should not manually pad system insets already consumed by `AppPageBody` or the `Scaffold` app bar.
*   **Keyboard Handling:** The application relies on `Scaffold`'s default `resizeToAvoidBottomInset` behavior. `AppPageBody` uses a `SingleChildScrollView` which allows users to naturally scroll to lower inputs and controls when the keyboard appears. Do not use custom keyboard-padding logic inside screens.

## State Management

*   GetX is the primary state-management and dependency registration approach. No other state-management framework will be installed.
*   **Routing:** GetX is pinned exactly to `4.7.3`. `app_routes.dart` owns names; `AppPages.pages` is the authoritative destination/binding registry. Home is `/`, About is `/about`, and the fallback is `/not-found`. `Get.toNamed` remains the navigation API.
*   **Exact Resolution (Module 12A):** `TrustCueApp` supplies `AppPages.resolve` and `AppPages.initialRoutes` to `GetMaterialApp`. It intentionally does not supply `getPages`, because GetX 4.7.3 would override these factories with its ancestor-matching resolver. The application resolver selects an exact URI path from `AppPages.pages`, otherwise the fallback, and creates a `GetPageRoute` with the destination's binding. This preserves GetX route-owned lifecycle behavior. Initial resolution creates just one route; it does not insert Home beneath an unsupported startup path.
*   **Route Policy:** Query strings are ignored and are not exposed as application parameters; `/about?source=synthetic` opens About. Route settings use the canonical destination name and preserve the caller's `arguments`. Trailing slashes are distinct (`/about/` is unsupported); unknown descendants such as `/about/does-not-exist` fall back rather than matching an ancestor. Relative paths, absolute URLs/authorities, fragments, and unparseable names are unsupported. These are internal named routes, not platform deep-link support.
*   **Recovery:** `NotFoundScreen._recoverToHome` pops intervening pages to an existing named `/`, preserving its route and controller. If none exists, it uses `Get.offAllNamed('/')` to clear the remaining stack and enter Home through its binding. This is ordinary navigation, not an application restart. Repeated recovery is tested against actual Navigator stack observations; controllers are not permanent and do not use `fenix`.
*   **Bindings:** Feature-specific dependencies (like `HomeController`) are lazily registered in their respective bindings (e.g., `HomeBinding`).
*   **Controllers:** Reactive state is owned by `GetxController` subclasses. They are disposed automatically by GetX when their corresponding route is popped (e.g., pressing back on the `AboutScreen` does not destroy the underlying `HomeController` because it remains on the stack).
*   **Presentation:** Screens extend `GetView<T>` to strictly separate UI from state logic, reacting to changes via scoped `Obx` widgets. Business logic remains out of widget build methods.

## Home Dashboard and Input Navigation (Module 14)

Module 14 retires the initial counter demonstration completely from production code and tests. `HomeController` remains the route-owned controller for `HomeScreen`, without counter state. `HomeScreen` implements the primary product dashboard layout:
* Brand header: Headline "Understand the signals." with descriptive body text and informational About action icon in the app bar.
* Status card: Honest statement that "Analysis is not available in this development build yet."
* Input options: Three vertically stacked input option cards representing the primary intake vectors: Message text (`/input/text`), Screenshot or image (`/input/screenshot`), and Link or QR code (`/input/link`). Each card displays an icon, title, description, a prominent "Coming soon" status badge, and an action button.
* Safety guidance card: "Pause before you act." card with actionable advice on verifying through independent channels, and a "Review safe-use guidance" button navigating to `/safe-use`.
* Debounced navigation: Actions prevent rapid repeated taps from pushing duplicate routes onto the stack.

The input preparation screens (`InputTextScreen`, `InputScreenshotScreen`, `InputLinkScreen`) share a responsive `InputPreparationLayout` adhering to `AppPageBody`. They clearly display the chosen method, relevant method-specific safety guidance, honest "Coming soon" status, and a "Review safe-use guidance" button linking to `/safe-use`. Exact-path routing resolution applies to all three input routes.

## Typed Data Contracts and Analysis Interfaces (Module 15)

Module 15 establishes platform-independent domain models, typed outcomes, and version-1 serialization codecs for intake and scam indicator analysis:
*   **Platform Independence:** Domain models (`TextSnapshot`, `EvidenceReference`, `AnalysisFinding`, `AnalysisReport`) and the asynchronous `AnalysisService` contract are pure Dart with zero dependencies on Flutter UI, GetX, HTTP clients, or plugins.
*   **One-Way Dependency Flow:** The analysis feature consumes input snapshot contracts, but the input feature has no dependencies on analysis models or logic.
*   **Immutability & Defensive Copying:** All domain models are immutable and defensively copy collection properties (`List.unmodifiable`), enforcing invariants in public constructors.
*   **Strict Evidence Grounding:** `EvidenceReference` uses 0-based UTF-16 code-unit offsets and enforces exact substring matching against the referenced `TextSnapshot`. Boundaries are guarded to prevent splitting UTF-16 surrogate pairs (e.g., emojis). Invented quotes or approximate spans are strictly rejected.
*   **Version-1 Serialization Policy:** `AnalysisReportCodec`, `AnalysisFindingCodec`, `EvidenceReferenceCodec`, and `TextSnapshotCodec` implement strict encoding and decoding. Timestamps require explicit timezone indicators and normalize to UTC; integer offsets reject string or float coercion. Unknown top-level fields are safely ignored for future forward compatibility while invariants remain enforced.
*   **Privacy & Diagnostic Boundaries:** Errors and `Result.failure` wrap `AnalysisFailure` with standardized codes (`invalidInput`, `unsupportedInput`, `unavailable`, `timeout`, `cancelled`, `malformedData`). Diagnostic output (`toString()`) strictly excludes user-submitted text, credentials, or provider response bodies.

## Startup and Onboarding (Module 13)

`TrustCueApp` owns one `AppPages` instance and an injectable `OnboardingPreferences`. Its default implementation uses `SharedPreferencesAsync`; widget tests inject an in-memory fake instead of invoking a platform plugin. The temporary `/startup` route reads once, shows a themed labeled loading indicator, then replaces itself with `/onboarding` or `/`. There is no hidden Home/controller beneath onboarding. Read errors (including a ten-second timeout) display Retry; missing/invalid data is not confused with an I/O exception. An explicit internal initial destination is still resolved exactly, independently of onboarding; this introduction is not an authentication boundary.

The single convenience key is `trustcue.onboarding.completed_version`, currently integer `1`. Missing, non-integer, negative, or older values require onboarding; an integer at least `1` is complete. The adapter reads only this key via an allow-list. It stores no messages, screenshots, identifiers, or legally recorded consent. `shared_preferences` is pinned to `2.5.6`; the resolved Android implementation requires Flutter >=3.44, satisfied by installed 3.47.4. Existing Android API 24 and iOS 15 minimums are unchanged. See the [maintainer documentation](https://pub.dev/packages/shared_preferences) for the async API and non-critical-storage limits.

`OnboardingBinding` creates a route-owned `OnboardingController`. An unchecked acknowledgment disables continuation. The controller prevents duplicate requests, awaits the version write, and replaces first-run onboarding with Home through `HomeBinding`. Save errors/timeouts clear the loading state and show a retryable error without navigation. A timeout cannot cancel an underlying platform write; a late result never triggers navigation or a claim of confirmed saving. Retrying writes the same non-sensitive version.

`/safe-use`, opened from About or from the Home/Input guidance cards, uses the same `OnboardingScreen` with the explicit `OnboardingMode.review`. It has ordinary back navigation, no acknowledgment or write, and no onboarding controller binding. The existing Home/About stack remains alive. Repeated review actions use the production route guard and GetX duplicate prevention.

The acknowledgment only confirms understanding of the introduction. It is not a waiver, legal agreement, permission to collect content, or consent to remote AI processing. The availability sentence “Analysis is not available in this development build yet.” is intentionally honest and must be updated only when actual analysis becomes available. Broader preferences, history, and real analysis capabilities remain future work.

## Navigation and Onboarding Verification

The production `TrustCueApp` accepts an initial route and Navigator observers so regression tests can exercise the same router and bindings as the app. Tests observe route identity/stack contents, retained controller identity, disposal, fresh registration, and repeated production action callbacks. Actual UI taps and framework back requests are tested separately. Navigation-result expectations are attached immediately and awaited only after the pushed route is popped or removed.

Routing tests inject a completed-onboarding fake. Onboarding tests exercise fresh startup, delayed/error/invalid reads, failed saves, duplicate submissions, relaunch logic, review, and narrow 200% text in both themes. Rebuilding a root with saved fake data is not a process restart. The Android integration test instead uses the real adapter, snapshots only the onboarding key, temporarily removes it, completes onboarding, verifies a new adapter/startup and review navigation, and restores the exact prior key value in teardown. It never clears all preferences or app data.

Navigation widget tests specify a 20-second timeout explicitly. `frontend/tool/test.ps1` adds a wall-clock bound (180 seconds by default) around the entire test process and captures logs under ignored `build/test-runner/`. On timeout it stops only that invocation's process tree. The CLI timeout alone does not override Flutter's explicit widget-test timeout. Device tests use a two-minute test-body timeout and a longer bounded runner allowance for build/install.

Module 12's original `unknownRoute` configuration did not enforce this policy: GetX could match `/` or `/about` as an ancestor. Its explicit `/not-found` tests did not establish unknown-route resolution. Module 12A records and repairs that defect without changing the original checkpoint.

## Message Text Entry, Validation, and Lifecycle (Module 16)

*   **Pure-Dart Policy Enforcement:** `MessageTextValidator` encapsulates validation and normalization rules without UI or framework dependencies.
*   **Dual Enforced Limits:** Maximum 10,000 Unicode code points (runes) and 40,000 UTF-8 bytes. Limits are evaluated against the original, unnormalized editor input so normalization or trimming cannot bypass boundaries.
*   **Line-Break Normalization:** Converts `\r\n` and `\r` to standard `\n` (LF) for stored snapshot text while preserving casing, spaces, tabs, leading/trailing whitespace, and multilingual text (including Urdu scripts and emojis).
*   **Route-Owned Lifecycle:** `InputTextController` is bound via `InputTextBinding` to `AppRoutes.inputText`. All prepared snapshots are held strictly in-memory.
*   **Immediate Draft Invalidation:** Any typing, editing, or clearing immediately invalidates the prepared snapshot, clears the inline confirmation banner, and resets transient error states.
*   **Unsaved Draft Protection:** Leaving `/input/text` with a non-empty draft (via AppBar back or system PopScope) presents a discard confirmation dialog ("Keep editing" vs "Discard"). Pushing safe-use guidance (`/safe-use`) preserves the draft without triggering discard warnings. Clearing text requires user confirmation.

## Screenshot Selection, Validation, Preview, and Storage Lifecycle (Module 17)

*   **Pure-Dart Policy & Validation:** `ImageValidator` and `ImageValidationPolicy` inspect image files independently of UI or framework code. They verify file existence, file size (<= 10MB), MIME type via magic bytes (PNG `89 50 4E 47`, JPEG `FF D8 FF`), and dimensions (minimum 32x32px, maximum 20 megapixels total pixel count).
*   **Isolated Storage Ownership:** `ScreenshotStorageService` manages temporary file copies within an app-owned cache subfolder (`trustcue_screenshots/`). Newly selected gallery images are copied immediately with timestamp and collision-resistant IDs. All operations (replacement, removal, route-exit cleanup) strictly delete only files verified to belong to the app-owned directory via canonical path verification. The user's original gallery files are never modified or deleted.
*   **Route-Owned Lifecycle:** `InputScreenshotController` is registered lazily via `InputScreenshotBinding` at `AppRoutes.inputScreenshot`. Temporary file state is tracked within the controller and automatically deleted on controller disposal unless intentionally passed forward.
*   **Privacy & User-Facing Safety:** Absolute filesystem paths and raw file names are never surfaced in user-facing UI or error messages. Only friendly image metadata (file size in KB/MB, pixel dimensions) is displayed.
*   **Android Lost-Data Recovery:** `ScreenshotRecoveryCoordinator` handles Android activity destruction during image picker interactions using `ImagePicker.retrieveLostData()`.
*   **Interactive Preview:** `InputScreenshotScreen` uses `InteractiveViewer` with constrained min/max scale factors (0.8x - 4.0x) to allow inspection of suspicious screenshots before any future extraction/analysis. Leaving with an active preview prompts for discard confirmation.

## On-Device OCR, Script Limitations, and Reader Lifecycle (Module 18)

*   **Google ML Kit On-Device Recognition:** Uses `google_mlkit_text_recognition: 0.17.1` configured strictly for Latin script (`TextRecognitionScript.latin`). The Flutter bridge is community-maintained by `flutter-ml.dev` and wraps Google's on-device C++/Java ML Kit libraries without requiring API keys, cloud accounts, or network requests.
*   **Deliberate User Request:** OCR is never triggered automatically upon image selection or picker recovery. Extraction requires an intentional tap on "Extract text from image".
*   **Script & Accuracy Transparency:** Explicit UI notices inform users of Latin alphabet limitations and that OCR is imperfect and unreviewed. Extracted text is presented in a selectable read-only container with an unreviewed warning banner.
*   **Safe Error Handling & Recovery:** Failures (`OcrFailure`) map to user-friendly messages for empty text, exceeded limits (10,000 runes / 40,000 UTF-8 bytes), unsupported platform (desktop/web), timeout, or cancellation. Users are given explicit recovery actions ("Retry extraction" or "Enter message text manually").
*   **Truthful Native Settling State:** Cancellation or timeout cannot immediately abort a background native C++ thread. The controller tracks `isNativeSettling` to prevent overlapping native calls while a prior thread finishes, resetting the settling state only when native execution completes.
*   **File Reader Lifecycle Coordination:** `InputScreenshotController` tracks `_activeReadingFiles`. Active native OCR readers prevent premature temporary file deletion during replacement, removal, or controller disposal; pending file deletions are queued and executed safely only once native readers release their handles.

## Text Review, Correction, Sensitive-Data Detection, and Redaction (Module 19)

*   **Unified Review Workflow:** `/input/review` provides a shared inspection and correction interface accessible from both typed/pasted message entry (`/input/text`) and extracted OCR output (`/input/screenshot`). Source channel provenance is strictly preserved (`InputSource.messageText` vs `InputSource.screenshot`).
*   **Pure-Dart Heuristic Detection:** `LocalSensitiveDataDetector` operates entirely on-device without network dependencies, regex-scanning for emails, phone numbers, payment cards (13–19 digits satisfying Luhn checksum), and verification codes (4–8 digits near authentication context triggers). Formatted multi-group numbers (such as phone numbers or hyphenated codes) are protected from partial OTP misclassification.
*   **Deterministic Conflict Resolution:** Overlapping matches are resolved deterministically using category priority: `paymentCard` (4) > `verificationCode` (3) > `phone` (2) > `email` (1). Ties are broken by longer match length, then earlier start index.
*   **Descending-Offset Redaction Application:** User-selected redactions are replaced with category placeholders (`[EMAIL]`, `[PHONE]`, `[CARD NUMBER]`, `[VERIFICATION CODE]`) in descending UTF-16 code-unit offset order so that earlier replacement offsets in the text are never corrupted.
*   **Reactive State & Draft Invalidation:** `InputReviewController` maintains reactive draft state. Any text modification immediately invalidates previous candidate suggestions, selections, preview, and confirmation. Selection changes immediately recalculate the real-time preview and invalidate previous confirmation.
*   **Immutable Confirmation:** Confirming produces an immutable `ReviewedTextResult` holding a newly minted `TextSnapshot` with a unique UUID, UTC timestamp, and unmodifiable `redactionCounts` map. The original input snapshot is never mutated.
*   **Ownership & Local Boundary:** For screenshot inputs, image ownership remains with `/input/screenshot`; the review screen allows visual comparison but does not delete the temporary file. All review and redaction operations are strictly local to the device memory session.

### Link Inspection, QR Decoding, and Destination Opening Architecture (Module 20 / 20A)

*   **Offline Link Inspection (`UrlInspectionService`):** Pure-Dart local parser evaluating URIs without network access, socket creation, or DNS resolution. Performs offline structural checks: RFC 1918 private/loopback IPv4/IPv6 detection, non-standard port detection, unencrypted HTTP warning, factual query parameter count, and factual observation of parameter names commonly associated with destination redirection (without claiming or concluding open redirect vulnerability). Rejects userinfo/credentials, bidi override characters, unencoded non-ASCII Unicode hostnames, and malformed structures. Conventional ASCII punycode hostnames (`xn--...`) are accepted with a factual caution observation. Does not claim to count subdomains or determine registrable domain boundaries.
*   **On-Device Barcode Scanning (`DefaultQrDecoderService`):** Wraps Google ML Kit Barcode Scanning (`google_mlkit_barcode_scanning: 0.16.1`) for `BarcodeFormat.qrCode` on on-device images. Categorizes payloads into `webUrl`, `plainText`, and `unsupported` (e.g., Wi-Fi, vCard, mailto, tel, SMS, payment/UPI, app intents). Decoded payloads exceeding 4,096 UTF-8 bytes are strictly classified as `QrPayloadType.unsupported` (`isOversized: true`), preventing recategorization as `plainText` or forwarding to review. Unsupported payloads are never executed. Duplicate identical codes in an image are deduplicated while multiple distinct codes are surfaced for explicit user selection.
*   **Explicit Destination Opening Boundary (`UrlLauncherAdapter`):** External navigation delegates to `url_launcher` using strictly `LaunchMode.externalApplication` (never in-app WebView). Opening requires an explicit two-step user confirmation dialog displaying the complete destination hostname and exact selectable URL. Any change in input immediately invalidates previous confirmation.
*   **Review Pipeline Integration:** Inspected web links and decoded QR text can be forwarded to `/input/review` creating a `TextSnapshot` with source `InputSource.link` or `InputSource.qrCode`. Oversized payloads are strictly rejected from review navigation.

## Android Incoming Shares and Lifecycle Integration (Module 21)

*   **Android Sharesheet Intake (`ACTION_SEND`):** Declares `<intent-filter>` in `AndroidManifest.xml` supporting `text/plain`, `image/png`, and `image/jpeg`. `ACTION_SEND_MULTIPLE` and non-content file URIs are safely intercepted natively and flagged as unsupported errors rather than crashing the process.
*   **Native Stream Bounding & Magic-Byte Verification (`MainActivity.kt`):** Background thread streaming via `ContentResolver` enforces an absolute 10 MiB limit on incoming images, verifying true file headers (PNG `89 50 4E 47`, JPEG `FF D8 FF`) before staging them in app-owned cache (`cacheDir/trustcue_incoming_shares/`). Oversized or invalid image streams are aborted and cleaned immediately. Shared text is bounded to 10,000 code points and 40,000 UTF-8 bytes.
*   **Platform Lifecycle Bridge (`IncomingShareAdapter`):** Handles both cold launch (`getInitialShare` via `onCreate`) and warm launch (`onShareReceived` via `onNewIntent`). Communicates via `MethodChannel("trustcue/incoming_share")` with unique UUID event tracking and explicit native consumption (`consumeShare`) and cleanup (`cleanStagedFile`).
*   **Central Coordinator & Onboarding Gate (`IncomingShareCoordinator`):** Manages pending share state across the app lifecycle. If first-run onboarding is incomplete, incoming shares are stored in `pendingShare` and deferred until `onOnboardingCompleted()` fires. Restricts pending shares to at most one, cleaning up any unconsumed predecessor.
*   **Non-Destructive Presentation & Choice Dialog (`IncomingShareDialog`):** Surfaces shared content in a clean modal dialog. Text offers "Use as message" and, if it contains a single valid web link, "Inspect as link". Images offer "Use as screenshot" and "Use as QR image". Mixed text/image intents present both elements with clear separate actions. Users can also choose "Dismiss", which discards the share and deletes the staged file.
*   **Draft Conflict Protection (`DraftConflict`):** Detects existing in-progress drafts on the target destination screen (`/input/text`, `/input/screenshot`, `/input/link`). Prompts the user with an explicit choice ("Keep current draft" vs "Replace draft with shared content"). Replacing a draft is transactional: images are imported into `ScreenshotStorageService` before replacing the active draft.
*   **Zero Automatic Processing:** Shares are strictly held for user review. No automatic OCR, QR decoding, URL opening, or network analysis is ever executed on incoming shares.

## Local Scam-Indicator Taxonomy, Rule Engine, and Evidence Integrity (Module 22)

*   **Stable Indicator Taxonomy (`IndicatorCategory`):** Establishes 10 plain-language observation categories decoupled from UI labels: `urgency_or_pressure`, `requests_for_credentials`, `requests_for_verification_codes`, `requests_for_payment`, `account_suspension_or_threats`, `claimed_identity_or_impersonation`, `rewards_or_prizes`, `job_or_recruitment_offers`, `investment_or_return_promises`, and `link_structural_indicators`. Categories describe observable patterns in digital messages rather than asserting definitive verdicts of malice.
*   **Pure-Dart Rule Contracts (`LocalRule`, `RuleRegistry`):** `LocalRule` defines an immutable interface for local pattern detection containing a stable string identifier, semantic version integer, target `IndicatorCategory`, supported language tags (e.g. `['en']`), human-readable limitation descriptions, and an asynchronous `evaluate(snapshot)` method.
*   **In-Memory Rule Registry (`LocalRuleRegistry`):** Provides synchronous rule registration and querying. Disallows duplicate rule identifiers via `ArgumentError`, enforces unmodifiable collection exposures (`List.unmodifiable`), and filters registered rules by category or language.
*   **Strict Evidence Integrity Validation (`EvidenceValidator`):** Pure-Dart validator checking that every finding's `EvidenceReference` strictly grounds findings in the provided `TextSnapshot`:
    - Referenced `snapshotId` must match target snapshot `id`.
    - Character offsets `[startOffset, endOffset]` are strictly bounded within `[0, text.length]`.
    - Character spans must not bisect UTF-16 surrogate pairs (e.g., emojis or extended astral symbols).
    - Quoted `excerpt` must match `text.substring(startOffset, endOffset)` with byte-for-byte exactness.
    - Findings must declare `FindingOrigin.localRule` and specify `producerId` matching the evaluating rule's identifier.
*   **Deterministic Local Rule Engine (`LocalRuleEngine`):** Production implementation of `AnalysisService`:
    - Reuses `MessageTextValidator` for input normalization and boundary verification (rejecting empty or oversized texts).
    - Evaluates registered rules, validates findings via `EvidenceValidator`, and discards invalid findings.
    - Caps total findings to `maxFindings = 100` to prevent memory exhaustion from runaway rules.
    - Applies a deterministic 5-tier sorting order: Severity descending (`high` > `medium` > `low` > `informational`), Category identifier ascending, Rule identifier ascending, Start offset ascending, and Finding identifier ascending.
    - Privacy-safe failure handling: maps rule exceptions or invalid inputs to typed `AnalysisFailure.malformedData` / `.unsupportedInput` without leaking raw user text, credentials, or exceptions to UI or log output.
    - Honest limitation declaration: reports empty findings with explicit caveats stating that absence of detected indicators does not guarantee safety or absence of scam intent.

## Repository Separation

*   `frontend/`: The complete Flutter application and its client-side integrations.
*   `backend/`: Server implementation.
*   `database/`: Database definitions, migrations, fixtures, and DB documentation.
*   `docs/`: Shared project documentation.

Dart database adapters and client models belong inside the `frontend/` Flutter package. We do not enforce moving Flutter-related code out of `frontend/` just to conceptually match a Git branch name.
