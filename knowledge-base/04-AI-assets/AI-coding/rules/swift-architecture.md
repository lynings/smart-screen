---
description: Swift App Layered Architecture - Layer structure, responsibilities, dependency rules and code organization
alwaysApply: true
---

# Swift App Layered Architecture

> Applicable: SmartScreen macOS App

## Layer Structure

```
┌─────────────────────────────────────────┐
│            Presentation Layer           │  ← SwiftUI Views, ViewModels
├─────────────────────────────────────────┤
│             Domain Layer                │  ← Business Logic, Use Cases
├─────────────────────────────────────────┤
│           Infrastructure Layer          │  ← System APIs, Persistence
└─────────────────────────────────────────┘
```

## Layer Responsibilities

### Presentation Layer

| Member | Responsibility |
|--------|----------------|
| Views (SwiftUI) | UI rendering, user interaction, state binding |
| ViewModels (@Observable) | UI state management, user action handling, domain coordination |
| Coordinators | Navigation flow, screen transitions |

**Path**: `Features/<Feature>/Views/`, `Features/<Feature>/ViewModels/`

### Domain Layer

| Member | Responsibility |
|--------|----------------|
| Use Cases | Single business operation, orchestration logic |
| Services | Cross-cutting business logic, shared operations |
| Models | Domain entities, value objects |
| Protocols | Abstractions for dependencies |

**Path**: `Core/Domain/`, `Features/<Feature>/Domain/`

### Infrastructure Layer

| Member | Responsibility |
|--------|----------------|
| System Clients | ScreenCaptureKit, AVFoundation, Metal wrappers |
| Repositories | Data persistence, file management |
| Mappers | DTO/Entity conversion |
| Config | App configuration, feature flags |

**Path**: `Core/Infrastructure/`, `Features/<Feature>/Infrastructure/`

## Dependency Rules

### Allowed Direction

```
Presentation  →  Domain  →  Infrastructure
     ↓             ↓
  (depends)    (depends)
```

### Dependency Injection

```swift
// Protocol in Domain layer
protocol CaptureEngineProtocol {
    func startCapture() async throws
    func stopCapture() async
}

// Implementation in Infrastructure layer
final class ScreenCaptureEngine: CaptureEngineProtocol {
    // ...
}

// Injection in Presentation layer
@MainActor
final class RecordingViewModel: ObservableObject {
    private let captureEngine: CaptureEngineProtocol
    
    init(captureEngine: CaptureEngineProtocol = ScreenCaptureEngine()) {
        self.captureEngine = captureEngine
    }
}
```

### Prohibited Dependencies

- ❌ Infrastructure → Domain
- ❌ Domain → Presentation
- ❌ Presentation → Infrastructure (layer skipping)
- ❌ Circular dependencies between features

## Code Organization

### Project Structure

```
SmartScreen/
├── App/
│   ├── SmartScreenApp.swift
│   └── AppDelegate.swift
├── Core/
│   ├── Domain/
│   │   ├── Models/
│   │   ├── Protocols/
│   │   └── Services/
│   ├── Infrastructure/
│   │   ├── Capture/
│   │   ├── Audio/
│   │   ├── Storage/
│   │   └── Metal/
│   └── Extensions/
├── Features/
│   ├── Recording/
│   │   ├── Domain/
│   │   ├── Views/
│   │   └── ViewModels/
│   ├── Enhancement/
│   ├── Editor/
│   └── Export/
├── Resources/
│   ├── Assets.xcassets
│   └── Localizable.strings
└── Tests/
    ├── UnitTests/
    └── IntegrationTests/
```

### Feature Module Structure

```
Features/<Feature>/
├── Domain/
│   ├── <Feature>UseCase.swift
│   └── <Feature>Model.swift
├── Views/
│   ├── <Feature>View.swift
│   └── Components/
├── ViewModels/
│   └── <Feature>ViewModel.swift
└── Infrastructure/  (if feature-specific)
    └── <Feature>Client.swift
```

## Naming Conventions

### Files and Types

| Type | Convention | Example |
|------|------------|---------|
| View | `<Name>View` | `RecordingView` |
| ViewModel | `<Name>ViewModel` | `RecordingViewModel` |
| UseCase | `<Action><Entity>UseCase` | `StartRecordingUseCase` |
| Protocol | `<Name>Protocol` | `CaptureEngineProtocol` |
| Client | `<System>Client` | `ScreenCaptureClient` |

### SwiftUI Modifiers

```swift
// Prefer extracted modifiers for reusability
extension View {
    func recordingControlStyle() -> some View {
        self
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

## State Management

### View State

```swift
@Observable
final class RecordingViewModel {
    // UI State
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var error: RecordingError?
    
    // Dependencies
    private let captureEngine: CaptureEngineProtocol
    
    // Actions
    func startRecording() async {
        // ...
    }
}
```

### Global State (if needed)

```swift
@Observable
final class AppState {
    static let shared = AppState()
    
    var currentSession: RecordingSession?
    var preferences: UserPreferences
    
    private init() {
        preferences = UserPreferences.load()
    }
}
```

## Error Handling

### Domain Errors

```swift
enum RecordingError: LocalizedError {
    case permissionDenied
    case captureSessionFailed(underlying: Error)
    case exportFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission is required"
        case .captureSessionFailed(let error):
            return "Capture failed: \(error.localizedDescription)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        }
    }
}
```

### Error Propagation

```
Infrastructure (throws) → Domain (maps to domain error) → Presentation (displays)
```

## Validation Checklist

- [ ] Each layer has clear, single responsibility
- [ ] Dependencies flow downward only
- [ ] Protocols define boundaries between layers
- [ ] Feature modules are self-contained
- [ ] Shared code lives in Core/
- [ ] No business logic in Views
- [ ] ViewModels are testable (dependencies injectable)
