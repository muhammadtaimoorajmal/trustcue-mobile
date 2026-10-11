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

## Repository Separation

*   `frontend/`: The complete Flutter application and its client-side integrations.
*   `backend/`: Server implementation.
*   `database/`: Database definitions, migrations, fixtures, and DB documentation.
*   `docs/`: Shared project documentation.

Dart database adapters and client models belong inside the `frontend/` Flutter package. We do not enforce moving Flutter-related code out of `frontend/` just to conceptually match a Git branch name.

