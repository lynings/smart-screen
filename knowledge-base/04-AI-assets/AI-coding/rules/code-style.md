---
description: Swift Code Style - Comment conventions, code structure, and readability guidelines
alwaysApply: true
---

# Swift Code Style

> Applicable: SmartScreen macOS App

## Core Principles

1. **Structured** - Code is organized with clear sections
2. **Object-oriented** - Proper encapsulation and abstractions
3. **Readable** - Self-documenting code with minimal comments
4. **Maintainable** - Easy to understand and modify

## Comment Guidelines

### When to Comment

Comments should explain **intent and why**, not **implementation details**.

| Situation | Comment? | Reason |
|-----------|----------|--------|
| Complex algorithm | ✅ Yes | Explain the approach |
| Business rule | ✅ Yes | Capture domain knowledge |
| Non-obvious workaround | ✅ Yes | Prevent future confusion |
| Simple getter/setter | ❌ No | Self-explanatory |
| Standard patterns | ❌ No | Known to developers |
| What the code does line-by-line | ❌ No | Code should be readable |

### Comment Styles

#### 1. Stage Comments (for sequential flows)

Use numbered stages for multi-step operations:

```swift
func startCapture(config: CaptureConfig) async throws {
    // 1. Verify permission before starting
    guard await requestPermission() else {
        throw RecordingError.permissionDenied
    }
    
    // 2. Build capture pipeline
    let content = try await SCShareableContent.current
    let filter = try createFilter(for: config.source, from: content)
    
    // 3. Initialize and start stream
    stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
    try await stream?.startCapture()
    
    // 4. Record start time
    startTime = Date()
    isRecording = true
}
```

**Rules for stage comments:**
- One line per stage, starts with a verb
- Describes **what/why**, not how
- Blank line between stages
- Use for 3+ step sequences

#### 2. MARK Comments (for code organization)

```swift
final class RecordingViewModel {
    
    // MARK: - Dependencies
    
    private let captureEngine: CaptureEngineProtocol
    
    // MARK: - State
    
    private(set) var isRecording = false
    private(set) var error: RecordingError?
    
    // MARK: - Actions
    
    func startRecording() async { ... }
    func stopRecording() async { ... }
}
```

**Standard MARK sections:**
- `// MARK: - Properties` or `// MARK: - Dependencies`
- `// MARK: - State`
- `// MARK: - Initialization`
- `// MARK: - Actions` or `// MARK: - Public Methods`
- `// MARK: - Private Helpers`

#### 3. Doc Comments (for public APIs and protocols)

```swift
protocol CaptureEngineProtocol {
    /// Current recording state
    var isRecording: Bool { get async }
    
    /// Start capturing with the given configuration
    /// - Parameter config: Capture configuration
    /// - Throws: `RecordingError` if capture fails
    func startCapture(config: CaptureConfig) async throws
}
```

**When to use doc comments:**
- Protocol definitions (always)
- Public APIs consumed by other modules
- Complex parameters that need clarification

**When NOT to use:**
- Internal implementation classes
- ViewModels (behavior is tested, not documented)
- Simple methods with obvious intent

## Code Structure

### Class/Struct Organization

```swift
final class FeatureViewModel {
    
    // MARK: - Dependencies
    
    private let service: ServiceProtocol
    
    // MARK: - State
    
    private(set) var isLoading = false
    private(set) var data: [Item] = []
    private(set) var error: FeatureError?
    
    // MARK: - Initialization
    
    init(service: ServiceProtocol) {
        self.service = service
    }
    
    // MARK: - Actions
    
    func loadData() async { ... }
    func refresh() async { ... }
    
    // MARK: - Private Helpers
    
    private func processItems(_ items: [Item]) -> [Item] { ... }
}
```

### Function Organization

```swift
func complexOperation() async throws -> Result {
    // 1. Validate preconditions
    guard isValid else { throw ValidationError.invalid }
    
    // 2. Prepare data
    let prepared = prepareData()
    
    // 3. Execute main operation
    let result = try await executeOperation(prepared)
    
    // 4. Post-process and return
    return postProcess(result)
}
```

### Enum Organization

```swift
enum FeatureError: LocalizedError, Equatable {
    case notFound
    case unauthorized
    case networkError(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Item not found"
        case .unauthorized:
            return "Access denied"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
```

## Readability Guidelines

### Prefer Self-Documenting Code

```swift
// ❌ Bad: Comment explains what code does
// Check if user has permission
if hasPermission == true { ... }

// ✅ Good: Code is self-explanatory
if hasPermission { ... }
```

```swift
// ❌ Bad: Magic number with comment
let timeout = 30 // seconds

// ✅ Good: Named constant
let timeoutSeconds: TimeInterval = 30
```

### Guard Early, Return Early

```swift
// ✅ Good: Guards at the top
func process(item: Item?) async {
    guard let item else { return }
    guard item.isValid else { return }
    
    // Main logic here
}
```

### Keep Functions Focused

```swift
// ❌ Bad: One function doing too much
func handleRecording() async {
    // permission check
    // setup
    // start capture
    // handle errors
    // update UI
}

// ✅ Good: Separate concerns
func startRecording() async {
    guard await checkPermission() else { return }
    try await setupCapture()
    updateState(.recording)
}
```

## Validation Checklist

- [ ] No redundant comments explaining obvious code
- [ ] Stage comments for complex sequential logic
- [ ] MARK sections for class organization
- [ ] Doc comments only for protocols and public APIs
- [ ] Self-documenting variable and function names
- [ ] Early returns with guard statements
- [ ] Single responsibility per function
