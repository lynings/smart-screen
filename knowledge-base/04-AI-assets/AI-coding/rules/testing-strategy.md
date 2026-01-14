---
description: Swift Testing Strategy - TDD workflow, Given-When-Then pattern, naming conventions and test organization
alwaysApply: true
---

# Testing Strategy

## Overview

Adopt **Test-Driven Development (TDD)** with **behavior-driven** naming. Write tests first to drive design, focus on behavior not implementation.

## TDD Workflow

```
Red → Green → Refactor
 │       │        │
 │       │        └── Improve code without changing behavior
 │       └── Write minimal code to pass
 └── Write failing test first
```

### Cycle

1. **Write a failing test** (Red)
   - Define expected behavior
   - Test should fail initially
   
2. **Make it pass** (Green)
   - Write minimal code to pass
   - No premature optimization
   
3. **Refactor** (Clean)
   - Improve code structure
   - Tests must still pass

## Test Types

| Type | Purpose | Coverage | Location |
|------|---------|----------|----------|
| **Unit Tests** | Test isolated logic | ViewModels, UseCases, Services | `Tests/UnitTests/` |
| **Integration Tests** | Test layer interactions | System client integration | `Tests/IntegrationTests/` |
| **UI Tests** | Test user flows | Critical user journeys | `SmartScreenUITests/` |

### Coverage Strategy

- **Unit Tests**: Core business logic, error handling, edge cases
- **Integration Tests**: System API interactions, data flow
- **UI Tests**: Happy path only, critical flows

## Given-When-Then Structure

### Required Structure

```swift
func test_should_start_recording_when_permission_granted() async throws {
    // given
    let mockEngine = MockCaptureEngine()
    mockEngine.hasPermission = true
    let sut = RecordingViewModel(captureEngine: mockEngine)
    
    // when
    await sut.startRecording()
    
    // then
    XCTAssertTrue(sut.isRecording)
    XCTAssertEqual(mockEngine.startCaptureCallCount, 1)
}
```

### Comment Rules

- Use ONLY: `// given`, `// when`, `// then`
- No other comments in test methods
- Each section clearly separated

## Naming Conventions

### Test Methods (BDD Style)

Use **Behavior-Driven Development** naming that describes what the system **should do**, not how it's implemented.

> ⚠️ **Important**: Swift XCTest **requires** the `test` prefix. Methods without it will NOT be recognized as tests.

**Format**: `test_should_<expected_behavior>_when_<condition>`

```swift
// ✅ Correct - XCTest will run this
func test_should_start_recording_when_permission_granted() async { }

// ❌ Wrong - XCTest will NOT run this (missing test prefix)
func should_start_recording_when_permission_granted() async { }
```

| Component | Description | Example |
|-----------|-------------|---------|
| `test_` | **Required** XCTest prefix | Must be present |
| `should_` | Expected behavior (outcome) | `should_start_recording` |
| `when_` | Condition/scenario | `when_permission_granted` |

✅ **Good** (BDD - describes behavior):
- `test_should_start_recording_when_permission_granted`
- `test_should_show_error_when_disk_full`
- `test_should_export_video_when_preset_selected`
- `test_should_return_empty_when_no_items`
- `test_should_disable_button_when_loading`

❌ **Avoid** (implementation-focused):
- `test_viewModel_calls_engine` → `test_should_capture_screen_when_recording_starts`
- `test_repository_returns_data` → `test_should_load_presets_when_app_launches`
- `test_mapper_converts_dto` → `test_should_display_session_duration`
- `testStartRecording` → `test_should_start_recording_when_button_tapped`

### Variable Naming

```swift
// Given variables: use `given` prefix
let givenSession = RecordingSession.fixture()
let givenPreset = ExportPreset.highQuality

// Expected variables: use `expected` prefix
let expectedDuration: TimeInterval = 60
let expectedError = RecordingError.permissionDenied

// System Under Test
let sut = RecordingViewModel(...)
```

## Test Organization

### File Structure

```
Tests/
├── UnitTests/
│   ├── Features/
│   │   ├── Recording/
│   │   │   ├── RecordingViewModelTests.swift
│   │   │   └── StartRecordingUseCaseTests.swift
│   │   └── Export/
│   │       └── ExportViewModelTests.swift
│   └── Core/
│       └── Services/
│           └── PresetManagerTests.swift
├── IntegrationTests/
│   └── CaptureEngineIntegrationTests.swift
└── Fixtures/
    ├── RecordingSessionFixture.swift
    └── ExportPresetFixture.swift
```

### Nested Classes for Grouping

```swift
final class RecordingViewModelTests: XCTestCase {
    
    // MARK: - startRecording
    
    @MainActor
    func test_should_start_recording_when_permission_granted() async {
        // ...
    }
    
    @MainActor
    func test_should_show_permission_error_when_denied() async {
        // ...
    }
    
    // MARK: - stopRecording
    
    @MainActor
    func test_should_stop_recording_and_save_session() async {
        // ...
    }
}
```

## Fixtures

### Fixture Pattern

```swift
// Fixtures/RecordingSessionFixture.swift
enum RecordingSessionFixture {
    static func build(
        id: UUID = UUID(),
        duration: TimeInterval = 60,
        state: SessionState = .stopped
    ) -> RecordingSession {
        RecordingSession(
            id: id,
            duration: duration,
            state: state
        )
    }
}

// Usage in tests
let givenSession = RecordingSessionFixture.build(duration: 120)
```

### Mock Pattern

```swift
final class MockCaptureEngine: CaptureEngineProtocol {
    // Configurable state
    var hasPermission = true
    var shouldFail = false
    
    // Call tracking
    private(set) var startCaptureCallCount = 0
    private(set) var stopCaptureCallCount = 0
    
    func startCapture() async throws {
        startCaptureCallCount += 1
        if !hasPermission {
            throw RecordingError.permissionDenied
        }
        if shouldFail {
            throw RecordingError.captureSessionFailed(underlying: NSError())
        }
    }
    
    func stopCapture() async {
        stopCaptureCallCount += 1
    }
}
```

## Assertions

### Use XCTest Assertions

```swift
// Equality
XCTAssertEqual(sut.duration, expectedDuration)

// Boolean
XCTAssertTrue(sut.isRecording)
XCTAssertFalse(sut.hasError)

// Nil
XCTAssertNil(sut.error)
XCTAssertNotNil(sut.session)

// Errors (async)
await XCTAssertThrowsError(try await sut.startRecording()) { error in
    XCTAssertEqual(error as? RecordingError, .permissionDenied)
}
```

### Optional: Quick/Nimble for BDD Style

```swift
import Quick
import Nimble

final class RecordingViewModelSpec: AsyncSpec {
    override class func spec() {
        describe("RecordingViewModel") {
            context("when starting recording") {
                it("should start capture when permission granted") {
                    // given
                    let mockEngine = MockCaptureEngine()
                    let sut = await RecordingViewModel(captureEngine: mockEngine)
                    
                    // when
                    await sut.startRecording()
                    
                    // then
                    await expect(sut.isRecording).to(beTrue())
                }
            }
        }
    }
}
```

## Test Coverage Targets

| Layer | Coverage Target | Focus |
|-------|-----------------|-------|
| ViewModel | 80%+ | User actions, state changes, error handling |
| UseCase | 90%+ | Business logic, edge cases |
| Service | 80%+ | Shared logic, calculations |
| Infrastructure | 60%+ | Integration points, happy path |

## Validation Checklist

- [ ] Test written BEFORE implementation (TDD)
- [ ] Test names describe business behavior
- [ ] Given-When-Then structure used consistently
- [ ] Only `// given`, `// when`, `// then` comments
- [ ] Fixtures used for test data
- [ ] Mocks used for dependencies
- [ ] No logic in test methods (setup in fixtures)
- [ ] Tests are independent (no shared state)
- [ ] Async code properly awaited
