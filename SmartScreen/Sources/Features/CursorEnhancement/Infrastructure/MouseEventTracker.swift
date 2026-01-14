import Foundation
import AppKit

/// Tracks mouse and keyboard events during screen recording
@MainActor
final class MouseEventTracker {
    
    // MARK: - Properties
    
    private(set) var isTracking = false
    private(set) var startTime: Date?
    private(set) var events: [MouseEvent] = []
    private(set) var keyboardEvents: [KeyboardEvent] = []
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var keyboardGlobalMonitor: Any?
    private var keyboardLocalMonitor: Any?
    private var positionTimer: Timer?
    
    // MARK: - Computed Properties
    
    var moveEvents: [MouseEvent] {
        events.filter { $0.type == .move }
    }
    
    var clickEvents: [MouseEvent] {
        events.filter { $0.type != .move }
    }
    
    // MARK: - Tracking Control
    
    func startTracking() {
        guard !isTracking else { return }
        
        isTracking = true
        startTime = Date()
        events.removeAll()
        keyboardEvents.removeAll()
        
        print("[MouseTracker] Starting tracking...")
        
        setupEventMonitors()
        setupKeyboardMonitors()
        setupPositionPolling()
        
        print("[MouseTracker] Tracking started")
    }
    
    func stopTracking() {
        print("[MouseTracker] Stopping tracking, events recorded: \(events.count)")
        isTracking = false
        teardownEventMonitors()
    }
    
    func reset() {
        stopTracking()
        events.removeAll()
        keyboardEvents.removeAll()
        startTime = nil
    }
    
    // MARK: - Event Recording
    
    func recordEvent(_ event: MouseEvent) {
        guard isTracking else { return }
        events.append(event)
    }
    
    // MARK: - Event Monitor Setup
    
    private func setupEventMonitors() {
        // Monitor click events using NSEvent
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
            print("[MouseTracker] ⚠️ Failed to create global monitor - may need accessibility permission")
        } else {
            print("[MouseTracker] Global click monitor created")
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
            print("[MouseTracker] ⚠️ Failed to create keyboard monitor - may need accessibility permission")
        } else {
            print("[MouseTracker] Keyboard monitor created")
        }
    }
    
    private func handleKeyboardEvent(_ event: NSEvent) {
        guard isTracking, let startTime else { return }
        
        let timestamp = Date().timeIntervalSince(startTime)
        let keyEvent = KeyboardEvent(timestamp: timestamp, keyCode: event.keyCode)
        keyboardEvents.append(keyEvent)
        
        if !keyEvent.isModifier {
            print("[MouseTracker] Key pressed: \(event.keyCode) at \(timestamp)")
        }
    }
    
    private func setupPositionPolling() {
        // Poll mouse position at ~30fps for smooth tracking
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordCurrentPosition()
            }
        }
        print("[MouseTracker] Position polling started at 30fps")
    }
    
    private func recordCurrentPosition() {
        guard isTracking, let startTime else { return }
        
        let position = NSEvent.mouseLocation
        let timestamp = Date().timeIntervalSince(startTime)
        
        // Convert from screen coordinates (bottom-left origin) to top-left origin
        guard let screen = NSScreen.main else { return }
        let flippedY = screen.frame.height - position.y
        let adjustedPosition = CGPoint(x: position.x, y: flippedY)
        
        // Only record if position changed significantly
        if let lastEvent = events.last(where: { $0.type == .move }) {
            let distance = hypot(
                adjustedPosition.x - lastEvent.position.x,
                adjustedPosition.y - lastEvent.position.y
            )
            // Skip if moved less than 2 pixels
            if distance < 2 { return }
        }
        
        let mouseEvent = MouseEvent(type: .move, position: adjustedPosition, timestamp: timestamp)
        recordEvent(mouseEvent)
    }
    
    private func handleNSEvent(_ event: NSEvent) {
        guard isTracking, let startTime else { return }
        
        let position = NSEvent.mouseLocation
        let timestamp = Date().timeIntervalSince(startTime)
        
        // Convert coordinates
        guard let screen = NSScreen.main else { return }
        let flippedY = screen.frame.height - position.y
        let adjustedPosition = CGPoint(x: position.x, y: flippedY)
        
        let eventType: MouseEventType
        switch event.type {
        case .leftMouseDown:
            eventType = event.clickCount >= 2 ? .doubleClick : .leftClick
            print("[MouseTracker] Left click at \(adjustedPosition)")
        case .rightMouseDown:
            eventType = .rightClick
            print("[MouseTracker] Right click at \(adjustedPosition)")
        default:
            return
        }
        
        let mouseEvent = MouseEvent(type: eventType, position: adjustedPosition, timestamp: timestamp)
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
        
        print("[MouseTracker] Monitors removed")
    }
    
    deinit {
        // Note: deinit is nonisolated, monitors should be removed in stopTracking
    }
}
