# Repository Guidelines

## Project Structure & Module Organization
iCodec is the sole app target housed under `iCodec/`. `Core/` contains shared infrastructure such as `AppCoordinator`, persistence, and cross-feature state managers; expand this when introducing new agents or services. Keep UI surface areas in `Features/<Domain>/`, each with its own `View` and optional `ViewModel`. Place reusable SwiftUI elements inside `UI/Components/`, theme utilities in `UI/ThemeManager.swift`, and share service abstractions from `Services/`. Assets live in `Assets.xcassets`, while preview mocks go in `Preview Content/`.

## Build, Test, and Development Commands
- `open iCodec.xcodeproj` launches Xcode with the default workspace.
- `xcodebuild -scheme iCodec -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' build` performs a simulator build without opening the UI.
- `xcodebuild test -scheme iCodec -destination 'platform=iOS Simulator,name=iPhone 15'` runs XCTest bundles once they exist.
Use the iCodec scheme for all automation; update shared schemes if you add new targets.

## Coding Style & Naming Conventions
Follow Swift API Design Guidelines: `UpperCamelCase` for types, `lowerCamelCase` for properties/functions. Indent with 4 spaces; keep computed properties and modifiers on separate lines as in `ContentView`. Collocate stateful objects at the top of a `View`, and keep feature-specific view models under `Features/<Domain>/`. When adding files, use names such as `MapOverlayView` or `IntelService` to mirror their module.

## Testing Guidelines
Adopt `XCTest` with a dedicated `iCodecTests` target. Mirror production folders inside `Tests/` (e.g., `Features/MapTests`). Name test cases `<Feature>Tests` and methods `test_whenCondition_expectOutcome`. For quick local checks run `xcodebuild test ...`; for UI verifications rely on SwiftUI previews but add snapshot or UI tests when flows become interactive. Aim for coverage on coordinators and services before shipping.

## Commit & Pull Request Guidelines
Keep commits concise with lowercase, action-focused summaries (`xcode 16 update`, `add map overlays`). Reference tickets in the body when relevant. PRs should state the scenario, screenshots or screen recordings for UI updates, test evidence (`xcodebuild test` output), and any follow-up work. Request review whenever feature boundaries cross modules, especially `Core/` or shared components.

## Agent-Specific Notes
Centralize shared intelligence or data gathering in `SharedDataManager` so agents can subscribe via `EnvironmentObject`. When wiring new feature agents, register navigation routes through `AppCoordinator` and expose reusable styling via `ThemeManager` to maintain the HUD aesthetic.
