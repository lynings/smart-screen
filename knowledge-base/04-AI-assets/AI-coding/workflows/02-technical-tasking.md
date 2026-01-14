---
description: Technical Tasking - Break down technical solution into executable TDD tasks
---

# Technical Tasking

## Overview

Transform technical solution into **executable TDD tasks**. Each task should be small, testable, and independently verifiable.

## Workflow

```
Review solution → Identify test cases → Create task list → Order by dependency → Validate coverage
```

## Prerequisites

- Approved technical solution
- Understanding of TDD workflow
- Testing strategy familiarity

## Inputs

| Input | Required | Source | If Missing |
|-------|----------|--------|------------|
| Technical solution | Yes | `03-specifications/<feature>/` | Run technical-solution workflow first |
| Acceptance criteria | Yes | Feature spec | Extract from solution doc |
| Existing tests | No | `Tests/` | Review test patterns |

## Steps

### Step 1: Identify Test Cases

For each acceptance criterion, derive test cases:

```markdown
## AC1: User can start screen recording

### Test Cases
1. should_start_recording_when_permission_granted
2. should_show_error_when_permission_denied
3. should_show_region_selector_when_region_mode_selected
```

### Step 2: Create TDD Task List

Each task follows Red-Green-Refactor:

```markdown
## Task: Implement recording start

### T1: Test - permission granted happy path
- [ ] Write failing test: `test_should_start_recording_when_permission_granted`
- [ ] Implement minimal code to pass
- [ ] Refactor if needed

### T2: Test - permission denied error
- [ ] Write failing test: `test_should_show_error_when_permission_denied`
- [ ] Implement error handling
- [ ] Refactor if needed
```

### Step 3: Order by Dependency

```markdown
## Execution Order

1. **Core Domain** (no dependencies)
   - T1: RecordingSession model
   - T2: SessionState enum

2. **Infrastructure** (depends on domain)
   - T3: CaptureEngineProtocol
   - T4: ScreenCaptureEngine implementation

3. **ViewModel** (depends on infrastructure)
   - T5: RecordingViewModel tests
   - T6: RecordingViewModel implementation

4. **View** (depends on ViewModel)
   - T7: RecordingView integration
```

### Step 4: Define Done Criteria

Each task needs clear done criteria:

```markdown
### T5: RecordingViewModel tests

**Done when:**
- [ ] Test file created: `RecordingViewModelTests.swift`
- [ ] Happy path test passes
- [ ] Error path test passes
- [ ] All tests use Given-When-Then structure
- [ ] Mock dependencies injected
```

## Task Template

```markdown
## Task: <Task Title>

**Type**: Test / Implementation / Refactor
**Layer**: Domain / Infrastructure / Presentation
**Depends on**: T1, T2 (or "None")

### Description
[What needs to be done]

### Test Cases (if Test task)
- `test_should_<outcome>_when_<scenario>`

### Implementation Notes (if Implementation task)
- Key classes/methods to create/modify
- Patterns to follow

### Done Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Tests pass
- [ ] No lint errors
```

## Outputs

| Output | Required | Notes |
|--------|----------|-------|
| Task list (Markdown) | Yes | Ordered by dependency |
| Test case mapping | Yes | AC → Test cases |
| Dependency graph | Recommended | Simple text or diagram |

## Output Path

```
03-specifications/<feature>/technical-tasking.md
```

## Example Output

```markdown
# Technical Tasking: Recording Feature

## AC Coverage

| AC | Test Cases | Tasks |
|----|------------|-------|
| AC1: Start recording | T1, T2 | T-01, T-02, T-03 |
| AC2: Stop recording | T3 | T-04, T-05 |

## Execution Order

```
Domain Models → Protocols → Infrastructure → ViewModel → View
     T-01        T-02          T-03          T-04-05    T-06
```

## Tasks

### T-01: RecordingSession domain model
**Type**: Implementation
**Layer**: Domain
**Depends on**: None

Create domain model for recording session.

**Done Criteria:**
- [ ] `RecordingSession.swift` created
- [ ] Properties: id, state, duration, startTime
- [ ] Unit test for state transitions

### T-02: CaptureEngineProtocol
**Type**: Test + Implementation
**Layer**: Domain

Define protocol for capture engine abstraction.

**Test Cases:**
- `test_should_define_start_capture_method`
- `test_should_define_stop_capture_method`

**Done Criteria:**
- [ ] Protocol in `Core/Domain/Protocols/`
- [ ] Methods: startCapture(), stopCapture()
- [ ] Error types defined

### T-03: ScreenCaptureEngine implementation
**Type**: Test + Implementation
**Layer**: Infrastructure
**Depends on**: T-02

Implement ScreenCaptureKit wrapper.

**Test Cases:**
- `test_should_request_permission_on_first_capture`
- `test_should_start_stream_when_permitted`

**Done Criteria:**
- [ ] Implementation in `Core/Infrastructure/Capture/`
- [ ] Integration test with mock content
- [ ] Error handling for permission denied
```

## Validation Checklist

- [ ] All ACs have corresponding test cases
- [ ] Each task is small (< 2 hours work)
- [ ] Dependencies are explicit
- [ ] Done criteria are verifiable
- [ ] TDD cycle (Red-Green-Refactor) is clear
- [ ] Layer boundaries respected
