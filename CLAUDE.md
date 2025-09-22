# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iCodec is an iOS tactical-style application with HUD interface targeting iOS 17.0+. The app enforces dark mode and follows a military/tactical aesthetic throughout the UI.

## Essential Commands

**Open Project:**
```bash
open iCodec.xcodeproj
```

**Build for Simulator:**
```bash
xcodebuild -scheme iCodec -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' build
```

**Run Tests (when test target exists):**
```bash
xcodebuild test -scheme iCodec -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Architecture Overview

### Core Pattern: MVVM + Coordinator
- **AppCoordinator** (`Core/AppCoordinator.swift`) manages all navigation between feature modules
- **SharedDataManager** (`Core/SharedDataManager.swift`) is a singleton providing cross-module state management
- **ThemeManager** (`UI/ThemeManager.swift`) handles tactical color schemes and sound effects
- ViewModels inherit from `BaseViewModel` and use `@ObservableObject`

### Module Structure
Features are organized under `Features/<Domain>/` with each having its own View and optional ViewModel:
- **MISSION** (OBJ) - Mission management
- **MAP** (TAC) - MapKit integration with tactical overlays
- **INTEL** (INT) - Intelligence gathering
- **ALERTS** (ALR) - Notification system
- **AUDIO** (COM) - Communication features
- **SETTINGS** (SET) - App configuration

### Key Technical Components

**Core Data + CloudKit:**
- `PersistenceController.swift` manages the Core Data stack with CloudKit sync
- Models defined in the Xcode Data Model file

**Theming System:**
- Multiple tactical themes: Tactical Green, Night Vision Blue, Thermal Orange, Custom
- Sound effects integrated via AudioToolbox for UI interactions
- Consistent HUD-style components in `UI/Components/`

**Location & Motion:**
- CoreLocation and CoreMotion integration for tactical features
- MapKit for tactical mapping functionality

## Development Notes

### Styling Conventions
- 4-space indentation (not tabs)
- Swift API Design Guidelines for naming
- Dark color scheme enforced throughout
- Custom `CodecButton` and `HUDPanel` components for consistent tactical look

### Adding New Features
1. Create feature module under `Features/<Domain>/`
2. Register navigation routes in `AppCoordinator`
3. Use `SharedDataManager` for cross-module data sharing
4. Apply tactical theming via `ThemeManager`
5. Follow existing ViewModel patterns inheriting from `BaseViewModel`

### Dependencies
- Pure SwiftUI implementation (no UIKit bridging)
- No external package managers (CocoaPods, SPM, Carthage)
- Uses only native iOS frameworks

## Important Files to Reference
- `AGENTS.md` - Comprehensive development guidelines and project structure details
- `iCodec/Core/AppCoordinator.swift` - Navigation management
- `iCodec/Core/SharedDataManager.swift` - Cross-module state
- `iCodec/UI/ThemeManager.swift` - Tactical theming system