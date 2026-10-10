# Architecture Conventions

TrustCue is structured to grow sustainably while maintaining a clean separation of concerns.

## Directory Structure

*   `app/`: Owns application composition (`GetMaterialApp`), centralized route definitions, exact route resolution, and route bindings.
*   `core/`: Contains genuinely shared, cross-feature concerns (e.g., logging).
    *   `core/theme/`: Owns the visual design system (`AppTheme`, `AppColors`, `AppSemanticColors`). Feature widgets must consume these centralized theme roles (e.g., `Theme.of(context)`) rather than hardcoding raw colors or using template defaults.
    *   `core/widgets/`: Contains reusable, cross-feature UI components (`AppButton`, `AppTextField`, `AppCard`). These wrap Material components with consistent styling, behaviors, and accessibility defaults. They do not contain business logic or domain models.
*   `dev/`: Contains development-only utilities and standalone previews (e.g., `component_preview.dart`). These must not be imported by production routes.
*   `features/<feature>/presentation/`: Contains the feature's UI screens, widgets, and state controllers.
*   *Future Data/Domain:* Feature-specific data access, models, and business logic will be placed within the owning feature when implemented. Business rules, network calls, OCR, and persistence must remain completely separated from UI components. Domain layers or additional abstractions should be introduced *only* when actual complexity requires them.

## Layout and Boundaries

*   **Responsive Layouts:** Handled by `AppPageBody` (in `core/widgets/`). This wrapper establishes the maximum content width (720px), shared responsive padding based on screen width, and scrollability.
*   **System Insets (Safe Area):** `AppPageBody` owns the primary `SafeArea` wrapping the page content. Screens should not manually pad system insets already consumed by `AppPageBody` or the `Scaffold` app bar.
*   **Keyboard Handling:** The application relies on `Scaffold`'s default `resizeToAvoidBottomInset` behavior. `AppPageBody` uses a `SingleChildScrollView` which allows users to naturally scroll to lower inputs and controls when the keyboard appears. Do not use custom keyboard-padding logic inside screens.

## State Management

*   GetX is the primary state-management and dependency registration approach. No other state-management framework will be installed.
*   **Routing:** GetX is pinned exactly to `4.7.3`. `app_routes.dart` owns names; `AppPages.pages` is the authoritative destination/binding registry. Home is `/`, About is `/about`, and the fallback is `/not-found`. `Get.toNamed` remains the navigation API.
*   **Exact Resolution (Module 12A):** `TrustCueApp` supplies `AppPages.resolve` and `AppPages.initialRoutes` to `GetMaterialApp`. It intentionally does not supply `getPages`, because GetX 4.7.3 would override these factories with its ancestor-matching resolver. The application resolver selects an exact URI path from `AppPages.pages`, otherwise the fallback, and creates a `GetPageRoute` with the destination's binding. This preserves GetX route-owned lifecycle behavior. Initial resolution creates just one route; it does not insert Home beneath an unsupported startup path.
*   **Route Policy:** Query strings are ignored and are not exposed as application parameters; `/about?source=synthetic` opens About. Route settings use the canonical destination name and preserve the caller's `arguments`. Trailing slashes are distinct (`/about/` is unsupported); unknown descendants such as `/about/does-not-exist` fall back rather than matching an ancestor. Relative paths, absolute URLs/authorities, fragments, and unparseable names are unsupported. These are internal named routes, not platform deep-link support.
*   **Recovery:** `NotFoundScreen._recoverToHome` pops intervening pages to an existing named `/`, preserving its route, controller, and counter. If none exists, it uses `Get.offAllNamed('/')` to clear the remaining stack and enter Home through its binding. This is ordinary navigation, not an application restart. Repeated recovery is tested against actual Navigator stack observations; controllers are not permanent and do not use `fenix`.
*   **Bindings:** Feature-specific dependencies (like `HomeController`) are lazily registered in their respective bindings (e.g., `HomeBinding`).
*   **Controllers:** Reactive state is owned by `GetxController` subclasses. They are disposed automatically by GetX when their corresponding route is popped (e.g., pressing back on the `AboutScreen` does not destroy the underlying `HomeController` because it remains on the stack).
*   **Presentation:** Screens extend `GetView<T>` to strictly separate UI from state logic, reacting to changes via scoped `Obx` widgets. Business logic remains out of widget build methods.

## Navigation Verification

The production `TrustCueApp` accepts an initial route and Navigator observers so regression tests can exercise the same router and bindings as the app. Tests observe route identity/stack contents, retained controller identity, disposal, fresh registration, and repeated production action callbacks. Actual UI taps and framework back requests are tested separately. Navigation-result expectations are attached immediately and awaited only after the pushed route is popped or removed.

Navigation widget tests specify a 20-second timeout explicitly. `frontend/tool/test.ps1` adds a wall-clock bound (180 seconds by default) around the entire test process and captures logs under ignored `build/test-runner/`. On timeout it stops only that invocation's process tree. The CLI timeout alone does not override Flutter's explicit widget-test timeout. Device tests use a two-minute test-body timeout and a longer bounded runner allowance for build/install.

Module 12's original `unknownRoute` configuration did not enforce this policy: GetX could match `/` or `/about` as an ancestor. Its explicit `/not-found` tests did not establish unknown-route resolution. Module 12A records and repairs that defect without changing the original checkpoint.

## Repository Separation

*   `frontend/`: The complete Flutter application and its client-side integrations.
*   `backend/`: Server implementation.
*   `database/`: Database definitions, migrations, fixtures, and DB documentation.
*   `docs/`: Shared project documentation.

Dart database adapters and client models belong inside the `frontend/` Flutter package. We do not enforce moving Flutter-related code out of `frontend/` just to conceptually match a Git branch name.

