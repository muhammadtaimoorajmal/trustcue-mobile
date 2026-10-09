# Architecture Conventions

TrustCue is structured to grow sustainably while maintaining a clean separation of concerns.

## Directory Structure

*   `app/`: Contains application composition, root configurations (like `MaterialApp`), and will eventually handle navigation and dependency registration.
*   `core/`: Contains genuinely shared, cross-feature concerns (e.g., `theme/`, logging).
*   `features/<feature>/presentation/`: Contains the feature's UI screens, widgets, and (when introduced) its state controllers.
*   *Future Data/Domain:* Feature-specific data access, models, and business logic will be placed within the owning feature when implemented. Business rules, network calls, OCR, and persistence must remain completely separated from UI components. Domain layers or additional abstractions should be introduced *only* when actual complexity requires them.

## State Management

*   GetX is the planned state-management approach. No other state-management framework will be installed.
*   The sample counter retains its standard local `setState` behavior until the dedicated state-management module. We avoid creating temporary scaffolding that will only be replaced later.

## Repository Separation

*   `frontend/`: The complete Flutter application and its client-side integrations.
*   `backend/`: Server implementation.
*   `database/`: Database definitions, migrations, fixtures, and DB documentation.
*   `docs/`: Shared project documentation.

Dart database adapters and client models belong inside the `frontend/` Flutter package. We do not enforce moving Flutter-related code out of `frontend/` just to conceptually match a Git branch name.
