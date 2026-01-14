import Foundation
import AppKit

/// Represents a keyboard event
struct KeyboardEvent: Equatable {
    let type: KeyboardEventType
    let timestamp: TimeInterval
    let keyCode: UInt16
    
    enum KeyboardEventType: Equatable {
        case keyDown
        case keyUp
    }
}

/// Tracks keyboard events during screen recording
/// Used to detect typing activity for Auto Zoom zoom-out trigger
@MainActor
final class KeyboardEventTracker {
    
    // MARK: - Properties
    
    private(set) var isTracking = false
    private(set) var startTime: Date?
    private(set) var events: [KeyboardEvent] = []
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    // MARK: - Computed Properties
    
    /// Last keyboard event timestamp
    var lastEventTime: TimeInterval? {
        events.last?.timestamp
    }
    
    /// Check if there was keyboard activity within a time window
    func hasRecentActivity(within seconds: TimeInterval, at time: TimeInterval) -> Bool {
        events.contains { event in
            let timeDiff = time - event.timestamp
            return timeDiff >= 0 && timeDiff < seconds
        }
    }
    
    // MARK: - Tracking Control
    
    func startTracking() {
        guard !isTracking else { return }
        
        isTracking = true
        startTime = Date()
        events.removeAll()
        
        print("[KeyboardTracker] Starting tracking...")
        setupEventMonitors()
        print("[KeyboardTracker] Tracking started")
    }
    
    func stopTracking() {
        print("[KeyboardTracker] Stopping tracking, events recorded: \(events.count)")
        isTracking = false
        teardownEventMonitors()
    }
    
    func reset() {
        stopTracking()
        events.removeAll()
        startTime = nil
    }
    
    // MARK: - Event Monitor Setup
    
    private func setupEventMonitors() {
        let keyMask: NSEvent.EventTypeMask = [.keyDown, .keyUp]
        
        // Global monitor for keyboard events
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: keyMask) { [weak self] event in
            Task { @MainActor in
                self?.handleNSEvent(event)
            }
        }
        
        // Local monitor for keyboard events (when app is focused)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: keyMask) { [weak self] event in
            Task { @MainActor in
                self?.handleNSEvent(event)
            }
            return event
        }
        
        if globalMonitor == nil {
            print("[KeyboardTracker] ⚠️ Failed to create global monitor - may need accessibility permission")
        } else {
            print("[KeyboardTracker] Global keyboard monitor created")
        }
    }
    
    private func handleNSEvent(_ event: NSEvent) {
        guard isTracking, let startTime else { return }
        
        let timestamp = Date().timeIntervalSince(startTime)
        
        let eventType: KeyboardEvent.KeyboardEventType
        switch event.type {
        case .keyDown:
            eventType = .keyDown
        case .keyUp:
            eventType = .keyUp
        default:
            return
        }
        
        let keyboardEvent = KeyboardEvent(
            type: eventType,
            timestamp: timestamp,
            keyCode: event.keyCode
        )
        
        events.append(keyboardEvent)
        
        if eventType == .keyDown {
            print("[KeyboardTracker] Key down at \(timestamp)")
        }
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
        
        print("[KeyboardTracker] Monitors removed")
    }
}
