# Architecture Conventions

TrustCue is structured to grow sustainably while maintaining a clean separation of concerns.

## Directory Structure

*   `app/`: Contains application composition, root configurations (like `MaterialApp`), and will eventually handle navigation and dependency registration.
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
*   **Routing:** Handled via centralized `app_routes.dart` (route constants) and `app_pages.dart` (route definitions mapped to bindings).
*   **Bindings:** Feature-specific dependencies (like `HomeController`) are lazily registered in their respective bindings (e.g., `HomeBinding`).
*   **Controllers:** Reactive state is owned by `GetxController` subclasses. They are disposed automatically by GetX when their corresponding route is popped.
*   **Presentation:** Screens extend `GetView<T>` to strictly separate UI from state logic, reacting to changes via scoped `Obx` widgets. Business logic remains out of widget build methods.

## Repository Separation

*   `frontend/`: The complete Flutter application and its client-side integrations.
*   `backend/`: Server implementation.
*   `database/`: Database definitions, migrations, fixtures, and DB documentation.
*   `docs/`: Shared project documentation.

Dart database adapters and client models belong inside the `frontend/` Flutter package. We do not enforce moving Flutter-related code out of `frontend/` just to conceptually match a Git branch name.

