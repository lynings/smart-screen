---
description: TDD Implementation - Execute tasks using Test-Driven Development cycle
---

# TDD Implementation

## Overview

Execute technical tasks using strict **Test-Driven Development**. Write tests first, then implement, then refactor.

> **📖 Reference**: For test naming conventions, Given-When-Then structure, fixtures, and mocks, see [Testing Strategy](../rules/testing-strategy.md).

## Workflow

```
Pick task → Write failing test (Red) → Implement (Green) → Refactor → Verify → Next task → Update spec
```

> **📝 Important**: After completing all TDD cycles for a feature, update the corresponding `*-spec.md` file (e.g., `technical-spec.md`, `functional-spec.md`) to reflect the actual implementation and ensure documentation stays in sync with code.

## Prerequisites

- Technical tasking completed
- Test environment set up
- Understanding of [Testing Strategy](../rules/testing-strategy.md)

## TDD Cycle

### 1. Red: Write Failing Test

Write test following the conventions in [Testing Strategy](../rules/testing-strategy.md):

```swift
// FIRST: Write the test (behavior-driven naming: test_should_xxx_when_xxx)
func test_should_start_recording_when_permission_granted() async {
    // given
    let mockEngine = MockCaptureEngine()
    mockEngine.hasPermission = true
    let sut = RecordingViewModel(captureEngine: mockEngine)
    
    // when
    await sut.startRecording()
    
    // then
    XCTAssertTrue(sut.isRecording)
}
```

**Run test → It should FAIL** (class doesn't exist yet)

### 2. Green: Minimal Implementation

```swift
// THEN: Write minimal code to pass
@Observable
final class RecordingViewModel {
    private let captureEngine: CaptureEngineProtocol
    
    var isRecording = false
    
    init(captureEngine: CaptureEngineProtocol) {
        self.captureEngine = captureEngine
    }
    
    func startRecording() async {
        do {
            try await captureEngine.startCapture()
            isRecording = true
        } catch {
            // Handle later
        }
    }
}
```

**Run test → It should PASS**

### 3. Refactor: Improve Code

```swift
// FINALLY: Refactor while keeping tests green
@Observable
final class RecordingViewModel {
    private let captureEngine: CaptureEngineProtocol
    
    private(set) var isRecording = false
    private(set) var error: RecordingError?
    
    init(captureEngine: CaptureEngineProtocol) {
        self.captureEngine = captureEngine
    }
    
    @MainActor
    func startRecording() async {
        error = nil
        do {
            try await captureEngine.startCapture()
            isRecording = true
        } catch let captureError as RecordingError {
            error = captureError
        } catch {
            error = .captureSessionFailed(underlying: error)
        }
    }
}
```

**Run test → Still PASSES**

## Implementation Steps

### Step 1: Setup Test File

```swift
import XCTest
@testable import SmartScreen

final class RecordingViewModelTests: XCTestCase {
    
    // MARK: - Fixtures
    
    private func makeSUT(
        captureEngine: CaptureEngineProtocol = MockCaptureEngine()
    ) -> RecordingViewModel {
        RecordingViewModel(captureEngine: captureEngine)
    }
}
```

### Step 2: Write First Test (Red)

Follow [Testing Strategy](../rules/testing-strategy.md) for naming and structure.

### Step 3: Run Test (Verify Red)

```bash
# Run specific test
xcodebuild test -scheme SmartScreen -only-testing:SmartScreenTests/RecordingViewModelTests/test_should_start_recording_when_permission_granted
```

### Step 4: Implement (Green)

Write minimal code to make test pass.

### Step 5: Run Test (Verify Green)

```bash
# Run all tests
xcodebuild test -scheme SmartScreen
```

### Step 6: Refactor

- Extract common code
- Improve naming
- Add documentation
- **Keep tests passing**

### Step 7: Add Next Test

Repeat cycle with next behavior scenario.

### Step 8: Update Specification Document

After completing all TDD cycles for the feature, update the corresponding specification document:

**What to update:**

1. **Implementation Status**
   - Mark completed features as `✅ Implemented`
   - Update any "TODO" or "Pending" items

2. **Actual Implementation Details**
   - Document the final API design (if different from initial spec)
   - Update class/function names to match actual code
   - Note any design decisions made during implementation

3. **Test Coverage**
   - Document what test scenarios were covered
   - Note any edge cases discovered during TDD

4. **Known Limitations**
   - Document any simplifications or trade-offs made
   - Note future improvements identified during implementation

**Example spec update:**

```markdown
## Implementation Status

### ✅ Completed Features

- [x] RecordingViewModel with start/stop functionality
- [x] Permission handling
- [x] Error state management

### Implementation Notes

- Used `@Observable` macro instead of `ObservableObject` protocol
- Error handling uses `RecordingError` enum with associated values
- Tests cover: permission granted/denied, capture failures, state transitions

### Test Coverage

- `test_should_start_recording_when_permission_granted`
- `test_should_show_permission_error_when_denied`
- `test_should_handle_capture_failure_gracefully`
```

**Spec file locations:**

- Technical specs: `knowledge-base/03-specifications/<feature>/technical-spec.md`
- Functional specs: `knowledge-base/03-specifications/<feature>/functional-spec.md`
- UI specs: `knowledge-base/03-specifications/<feature>/ui-spec.md`

## Quality Gates

### Before Commit

```bash
# 1. Run all tests
xcodebuild test -scheme SmartScreen

# 2. Run linter
swiftlint

# 3. Build for release
xcodebuild build -scheme SmartScreen -configuration Release
```

### Test Coverage Check

```bash
# Generate coverage report
xcodebuild test -scheme SmartScreen -enableCodeCoverage YES
```

## Outputs

| Output | Required | Notes |
|--------|----------|-------|
| Test file | Yes | Following [Testing Strategy](../rules/testing-strategy.md) |
| Implementation | Yes | Minimal to pass tests |
| Mock/Fixture | As needed | See [Testing Strategy - Mock Pattern](../rules/testing-strategy.md#mock-pattern) |
| Updated spec | Yes | Update `*-spec.md` after completing all TDD cycles |

## Validation Checklist

- [ ] Test written BEFORE implementation
- [ ] Test fails initially (Red verified)
- [ ] Implementation is minimal (no over-engineering)
- [ ] Test passes after implementation (Green verified)
- [ ] Code refactored while tests pass
- [ ] Follows [Testing Strategy](../rules/testing-strategy.md) conventions
- [ ] All quality gates pass
- [ ] Specification document (`*-spec.md`) updated to reflect actual implementation
- [ ] Spec updates include: implementation status, actual API design, test coverage, known limitations
- [ ] Commit follows git standards

## Common Pitfalls

### ❌ Writing implementation first

Always write the test first, even if you "know" what the implementation will be.

### ❌ Testing implementation details

```swift
// Bad: Testing internal state
XCTAssertEqual(sut.internalBuffer.count, 5)

// Good: Testing behavior
XCTAssertTrue(sut.isRecording)
```

### ❌ Over-mocking

Only mock external dependencies (system APIs, network, persistence). Don't mock value objects or simple domain logic.

### ❌ Skipping refactor step

Always look for opportunities to improve code after making the test pass.

### ❌ Forgetting to update spec

After completing implementation, update the specification document to keep it in sync with the actual code. This ensures documentation accuracy and helps future developers understand what was actually built.
