import Foundation
import AppKit

/// Tracks keyboard events during screen recording
/// Used to detect typing activity and trigger zoom-out
@MainActor
final class KeyboardEventTracker {
    
    // MARK: - Properties
    
    private(set) var isTracking = false
    private(set) var startTime: Date?
    private(set) var events: [KeyboardEvent] = []
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    // MARK: - Computed Properties
    
    /// Check if there was keyboard activity at a specific time
    func hasActivityAt(time: TimeInterval) -> Bool {
        // Check if any keyboard event occurred within the activity window
        events.contains { event in
            let windowStart = event.timestamp
            let windowEnd = event.timestamp + KeyboardEvent.activityWindowDuration
            return time >= windowStart && time <= windowEnd
        }
    }
    
    /// Get keyboard activity ranges (periods where typing was active)
    var activityRanges: [ClosedRange<TimeInterval>] {
        guard !events.isEmpty else { return [] }
        
        var ranges: [ClosedRange<TimeInterval>] = []
        var rangeStart: TimeInterval?
        var rangeEnd: TimeInterval = 0
        
        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            if rangeStart == nil {
                rangeStart = event.timestamp
                rangeEnd = event.timestamp + KeyboardEvent.activityWindowDuration
            } else if event.timestamp <= rangeEnd + 0.1 {
                // Extend current range
                rangeEnd = event.timestamp + KeyboardEvent.activityWindowDuration
            } else {
                // Start new range
                if let start = rangeStart {
                    ranges.append(start...rangeEnd)
                }
                rangeStart = event.timestamp
                rangeEnd = event.timestamp + KeyboardEvent.activityWindowDuration
            }
        }
        
        // Add last range
        if let start = rangeStart {
            ranges.append(start...rangeEnd)
        }
        
        return ranges
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
    
    // MARK: - Event Recording
    
    func recordEvent(_ event: KeyboardEvent) {
        guard isTracking else { return }
        events.append(event)
    }
    
    // MARK: - Event Monitor Setup
    
    private func setupEventMonitors() {
        let keyMask: NSEvent.EventTypeMask = [.keyDown]
        
        // Global monitor for key events
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: keyMask) { [weak self] event in
            Task { @MainActor in
                self?.handleNSEvent(event)
            }
        }
        
        // Local monitor for key events (when app is focused)
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
        
        let keyboardEvent = KeyboardEvent(
            timestamp: timestamp,
            type: .keyDown
        )
        recordEvent(keyboardEvent)
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
