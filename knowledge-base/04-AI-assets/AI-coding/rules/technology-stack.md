---
description: Technology Stack - Core technologies, frameworks, and dependencies for SmartScreen macOS app development
alwaysApply: true
---

# Technology Stack

> Applicable: SmartScreen macOS App

## Stack Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Application Layer                       │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │    SwiftUI      │  │     AppKit      │                   │
│  │   (Main UI)     │  │ (Custom Windows)│                   │
│  └─────────────────┘  └─────────────────┘                   │
├─────────────────────────────────────────────────────────────┤
│                       Business Layer                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │  Recording      │  │  Enhancement    │  │   Export     │ │
│  │  Engine         │  │  Pipeline       │  │   Engine     │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                       Framework Layer                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │ Screen   │ │   AV     │ │  Metal   │ │  Core    │       │
│  │ Capture  │ │Foundation│ │          │ │  Audio   │       │
│  │ Kit      │ │          │ │          │ │          │       │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
├─────────────────────────────────────────────────────────────┤
│                        System Layer                          │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              macOS 14.0+ (Sonoma)                       ││
│  │              Apple Silicon (M1/M2/M3/M4)                ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Core Technologies

### Language: Swift 5.9+

| Aspect | Requirement |
|--------|-------------|
| Version | Swift 5.9+ |
| Concurrency | async/await, Actor |
| Memory | ARC, value types preferred |

### UI Framework: SwiftUI + AppKit

| Framework | Use Case |
|-----------|----------|
| SwiftUI | Main UI, settings, dialogs |
| AppKit | Region selection overlay, custom windows |

### Screen Capture: ScreenCaptureKit

| Feature | API |
|---------|-----|
| Screen capture | `SCStream`, `SCShareableContent` |
| Window capture | `SCContentFilter` |
| Audio capture | `SCStreamConfiguration` |

**Fallback**: `AVCaptureScreenInput` for macOS < 12.3

### Media Processing: AVFoundation + VideoToolbox

| Component | Purpose |
|-----------|---------|
| AVCaptureSession | Audio capture (mic) |
| AVAssetWriter | Video encoding, file writing |
| VideoToolbox | Hardware H.264/HEVC encoding |
| AVAssetExportSession | Export with presets |

### GPU Acceleration: Metal

| Use Case | Implementation |
|----------|----------------|
| Auto Zoom rendering | Affine transform + crop |
| Cursor drawing | Real-time overlay |
| Video effects | Compute shaders |

### Audio: CoreAudio + AVAudioEngine

| Component | Purpose |
|-----------|---------|
| CoreAudio | Low-latency capture, device management |
| AVAudioEngine | Mixing, real-time processing |
| BlackHole | System audio capture (external) |

## Dependencies

### Required (Built-in)

- ScreenCaptureKit
- AVFoundation
- Metal
- CoreAudio
- SwiftUI / AppKit

### Recommended Third-Party

| Library | Purpose | Notes |
|---------|---------|-------|
| GRDB | SQLite wrapper | Recording history, presets |
| Sparkle | Auto-update | macOS standard |
| KeyboardShortcuts | Global shortcuts | Simplified management |

### Optional

| Library | Purpose | When to Use |
|---------|---------|-------------|
| FFmpeg | Complex transcoding | GIF, special formats |
| BlackHole | Virtual audio | System audio capture |

### Avoid

| Library | Reason |
|---------|--------|
| Electron | Performance, bundle size |
| Qt | Poor macOS integration |
| Heavy video libs | Feature redundancy |

## System Requirements

### Minimum

| Requirement | Value |
|-------------|-------|
| macOS | 14.0 (Sonoma) |
| Chip | Apple Silicon (M1) or Intel |
| RAM | 8GB |
| Storage | 500MB free |

### Recommended

| Requirement | Value |
|-------------|-------|
| macOS | 14.0+ (Sonoma) |
| Chip | Apple Silicon (M1 Pro/M2/M3/M4) |
| RAM | 16GB |
| Storage | SSD, 10GB+ free |

## Development Tools

### Required

| Tool | Purpose |
|------|---------|
| Xcode 15+ | IDE, build system |
| Swift Package Manager | Dependency management |
| Instruments | Performance profiling |

### Recommended

| Tool | Purpose |
|------|---------|
| SwiftLint | Code style enforcement |
| SwiftFormat | Code formatting |
| Periphery | Dead code detection |

## Code Patterns

### Async/Await for Capture

```swift
actor CaptureEngine {
    func startCapture() async throws {
        let content = try await SCShareableContent.current
        // ...
    }
}
```

### Dependency Injection

```swift
@Observable
final class RecordingViewModel {
    private let captureEngine: CaptureEngineProtocol
    
    init(captureEngine: CaptureEngineProtocol = ScreenCaptureEngine()) {
        self.captureEngine = captureEngine
    }
}
```

### Memory Management

```swift
// Use autoreleasepool for frame processing
for frame in frames {
    autoreleasepool {
        processFrame(frame)
    }
}
```

## Validation Checklist

- [ ] Target macOS version confirmed (14.0+)
- [ ] Apple Silicon primary, Intel secondary
- [ ] ScreenCaptureKit as primary capture API
- [ ] Hardware encoding via VideoToolbox
- [ ] Metal for GPU-accelerated effects
- [ ] Dependencies minimized
