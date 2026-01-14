import Foundation
import AppKit

/// Singleton manager for mouse tracking across actors
@MainActor
final class MouseTrackerManager {
    
    // MARK: - Singleton
    
    static let shared = MouseTrackerManager()
    
    // MARK: - Properties
    
    private(set) var isTracking = false
    private(set) var startTime: Date?
    private(set) var events: [MouseEvent] = []
    private(set) var keyboardEvents: [KeyboardEvent] = []
    
    /// Recording screen info (captured at start of tracking)
    private var recordingScreen: NSScreen?
    private var recordingFrame: CGRect = .zero
    private var backingScaleFactor: CGFloat = 1.0
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var keyboardGlobalMonitor: Any?
    private var keyboardLocalMonitor: Any?
    private var positionTimer: Timer?
    private var lastPosition: CGPoint?
    
    var trackingDuration: TimeInterval {
        guard let startTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Tracking Control
    
    func startTracking() {
        guard !isTracking else { return }
        
        // Check and request accessibility permission
        let trusted = AXIsProcessTrusted()
        print("[MouseTrackerManager] Accessibility trusted: \(trusted)")
        
        if !trusted {
            // Request permission (will show system dialog)
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            print("[MouseTrackerManager] ⚠️ Accessibility permission required for click tracking")
        }
        
        isTracking = true
        startTime = Date()
        events.removeAll()
        keyboardEvents.removeAll()
        lastPosition = nil
        
        // 1. Capture recording screen info at start
        captureScreenInfo()
        
        print("[MouseTrackerManager] Starting tracking...")
        print("[MouseTrackerManager] Recording frame: \(recordingFrame)")
        print("[MouseTrackerManager] Backing scale: \(backingScaleFactor)")
        
        // 2. Setup event monitors
        setupEventMonitors()
        setupKeyboardMonitors()
        setupPositionPolling()
        
        print("[MouseTrackerManager] Tracking started")
    }
    
    func stopTracking() {
        print("[MouseTrackerManager] Stopping tracking, events recorded: \(events.count)")
        print("[MouseTrackerManager] Move events: \(events.filter { $0.type == .move }.count)")
        print("[MouseTrackerManager] Click events: \(events.filter { $0.type != .move }.count)")
        
        isTracking = false
        teardownEventMonitors()
    }
    
    func reset() {
        stopTracking()
        events.removeAll()
        keyboardEvents.removeAll()
        startTime = nil
        lastPosition = nil
        recordingScreen = nil
        recordingFrame = .zero
        backingScaleFactor = 1.0
    }
    
    // MARK: - Screen Info Capture
    
    private func captureScreenInfo() {
        // Use main screen for full-screen recording
        guard let screen = NSScreen.main else {
            print("[MouseTrackerManager] ⚠️ No main screen found")
            return
        }
        
        recordingScreen = screen
        recordingFrame = screen.frame
        backingScaleFactor = screen.backingScaleFactor
    }
    
    // MARK: - Event Recording
    
    private func recordEvent(_ event: MouseEvent) {
        guard isTracking else { return }
        events.append(event)
    }
    
    /// Convert global screen position to normalized coordinates (0-1)
    /// - Origin: bottom-left (same as screen coordinate system)
    /// - X: 0 = left edge, 1 = right edge
    /// - Y: 0 = bottom edge, 1 = top edge
    /// Note: ScreenCaptureKit video frames use the same coordinate system as the screen
    private func normalizePosition(_ globalPosition: CGPoint) -> CGPoint? {
        guard recordingFrame.width > 0, recordingFrame.height > 0 else {
            return nil
        }
        
        // 1. Convert global position to position relative to recording screen
        let relativeX = globalPosition.x - recordingFrame.origin.x
        let relativeY = globalPosition.y - recordingFrame.origin.y
        
        // 2. Normalize to 0-1 range
        // No Y-flip needed: ScreenCaptureKit output matches screen coordinate system
        let normalizedX = relativeX / recordingFrame.width
        let normalizedY = relativeY / recordingFrame.height
        
        // 3. Clamp to valid range (mouse might be outside recording area)
        return CGPoint(
            x: max(0, min(1, normalizedX)),
            y: max(0, min(1, normalizedY))
        )
    }
    
    // MARK: - Event Monitor Setup
    
    private func setupEventMonitors() {
        let clickMask: NSEvent.EventTypeMask = [
            .leftMouseDown,
            .rightMouseDown
        ]
        
        // Global monitor for clicks
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: clickMask) { [weak self] event in
            Task { @MainActor in
                self?.handleNSEvent(event)
            }
        }
        
        // Local monitor for clicks (when app is focused)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: clickMask) { [weak self] event in
            Task { @MainActor in
                self?.handleNSEvent(event)
            }
            return event
        }
        
        if globalMonitor == nil {
            print("[MouseTrackerManager] ⚠️ Failed to create global monitor")
        } else {
            print("[MouseTrackerManager] ✅ Global click monitor created")
        }
    }
    
    private func setupKeyboardMonitors() {
        let keyMask: NSEvent.EventTypeMask = [.keyDown]
        
        // Global keyboard monitor
        keyboardGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: keyMask) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyboardEvent(event)
            }
        }
        
        // Local keyboard monitor
        keyboardLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: keyMask) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyboardEvent(event)
            }
            return event
        }
        
        if keyboardGlobalMonitor == nil {
            print("[MouseTrackerManager] ⚠️ Failed to create keyboard monitor")
        } else {
            print("[MouseTrackerManager] ✅ Keyboard monitor created")
        }
    }
    
    private func handleKeyboardEvent(_ event: NSEvent) {
        guard isTracking, let startTime else { return }
        
        let timestamp = Date().timeIntervalSince(startTime)
        let keyEvent = KeyboardEvent(timestamp: timestamp, keyCode: event.keyCode)
        keyboardEvents.append(keyEvent)
        
        if !keyEvent.isModifier {
            print("[MouseTrackerManager] ⌨️ Key pressed: \(event.keyCode) at \(timestamp)")
        }
    }
    
    private func setupPositionPolling() {
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordCurrentPosition()
            }
        }
        print("[MouseTrackerManager] ✅ Position polling started at 30fps")
    }
    
    private func recordCurrentPosition() {
        guard isTracking, let startTime else { return }
        
        let globalPosition = NSEvent.mouseLocation
        let timestamp = Date().timeIntervalSince(startTime)
        
        // Convert to normalized coordinates
        guard let normalizedPosition = normalizePosition(globalPosition) else {
            return
        }
        
        // Only record if position changed significantly (in normalized space)
        if let lastPos = lastPosition {
            let distance = hypot(
                normalizedPosition.x - lastPos.x,
                normalizedPosition.y - lastPos.y
            )
            // Skip if moved less than 0.1% of screen size
            if distance < 0.001 { return }
        }
        
        lastPosition = normalizedPosition
        let mouseEvent = MouseEvent(type: .move, position: normalizedPosition, timestamp: timestamp)
        recordEvent(mouseEvent)
    }
    
    private func handleNSEvent(_ event: NSEvent) {
        guard isTracking, let startTime else { return }
        
        let globalPosition = NSEvent.mouseLocation
        let timestamp = Date().timeIntervalSince(startTime)
        
        // Convert to normalized coordinates
        guard let normalizedPosition = normalizePosition(globalPosition) else {
            return
        }
        
        let eventType: MouseEventType
        switch event.type {
        case .leftMouseDown:
            eventType = event.clickCount >= 2 ? .doubleClick : .leftClick
            print("[MouseTrackerManager] 🖱️ Left click at normalized: \(normalizedPosition)")
        case .rightMouseDown:
            eventType = .rightClick
            print("[MouseTrackerManager] 🖱️ Right click at normalized: \(normalizedPosition)")
        default:
            return
        }
        
        let mouseEvent = MouseEvent(type: eventType, position: normalizedPosition, timestamp: timestamp)
        recordEvent(mouseEvent)
    }
    
    private func teardownEventMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        
        if let keyboardGlobalMonitor {
            NSEvent.removeMonitor(keyboardGlobalMonitor)
            self.keyboardGlobalMonitor = nil
        }
        
        if let keyboardLocalMonitor {
            NSEvent.removeMonitor(keyboardLocalMonitor)
            self.keyboardLocalMonitor = nil
        }
        
        positionTimer?.invalidate()
        positionTimer = nil
        
        print("[MouseTrackerManager] Monitors removed")
    }
}
