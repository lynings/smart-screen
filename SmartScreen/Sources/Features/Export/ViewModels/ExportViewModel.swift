import Foundation
import Observation

@Observable
@MainActor
final class ExportViewModel {
    
    // MARK: - Dependencies
    
    private let exportEngine: ExportEngineProtocol
    
    // MARK: - State
    
    private(set) var isExporting = false
    private(set) var progress: Double = 0
    private(set) var error: ExportError?
    private(set) var exportedURL: URL?
    
    var selectedPreset: ExportPreset = .web
    let availablePresets: [ExportPreset] = ExportPreset.allBuiltIn
    
    // MARK: - Cursor Enhancement Options
    
    var cursorEnhancementEnabled = true
    var smoothingLevel: SmoothingLevel = .medium
    var highlightEnabled = true
    
    // MARK: - Auto Zoom Options
    
    var autoZoomEnabled = true
    var autoZoomLevel: CGFloat = 2.0
    var autoZoomDuration: TimeInterval = 1.2
    var autoZoomEasing: EasingCurve = .easeInOut
    var autoZoomFollowCursor = true  // AC-FU-01, AC-FU-02
    var autoZoomCursorScale: CGFloat = 1.6  // AC-CE-01: Cursor/highlight scale during zoom
    
    var autoZoomSettings: AutoZoomSettings {
        AutoZoomSettings(
            isEnabled: autoZoomEnabled,
            zoomLevel: autoZoomLevel,
            duration: autoZoomDuration,
            easing: autoZoomEasing,
            followCursor: autoZoomFollowCursor,
            cursorScale: autoZoomCursorScale
        )
    }
    
    func applyAutoZoomPreset(_ preset: AutoZoomViewModel.Preset) {
        switch preset {
        case .subtle:
            let settings = AutoZoomSettings.subtle
            autoZoomLevel = settings.zoomLevel
            autoZoomDuration = settings.duration
        case .normal:
            let settings = AutoZoomSettings.normal
            autoZoomLevel = settings.zoomLevel
            autoZoomDuration = settings.duration
        case .dramatic:
            let settings = AutoZoomSettings.dramatic
            autoZoomLevel = settings.zoomLevel
            autoZoomDuration = settings.duration
        }
    }
    
    // MARK: - Initialization
    
    init(exportEngine: ExportEngineProtocol) {
        self.exportEngine = exportEngine
    }
    
    // MARK: - Computed Properties
    
    func hasCursorData(session: RecordingSession) -> Bool {
        guard let cursorSession = session.cursorTrackSession else { return false }
        return !cursorSession.events.isEmpty
    }
    
    // MARK: - Actions
    
    func export(session: RecordingSession, to customURL: URL? = nil) async {
        error = nil
        exportedURL = nil
        isExporting = true
        progress = 0
        
        let outputURL = customURL ?? generateOutputURL(for: session, preset: selectedPreset)
        
        do {
            let cursorSession = session.cursorTrackSession
            let hasCursorData = cursorSession != nil && !cursorSession!.events.isEmpty
            let hasClickData = cursorSession?.clickEvents.isEmpty == false
            
            // Determine export mode
            let needsCursorEnhancement = cursorEnhancementEnabled && hasCursorData
            let needsAutoZoom = autoZoomEnabled && hasClickData
            
            print("[Export] Cursor data: \(hasCursorData), clicks: \(cursorSession?.clickEvents.count ?? 0)")
            print("[Export] Cursor enhancement: \(needsCursorEnhancement), Auto Zoom: \(needsAutoZoom)")
            
            if needsCursorEnhancement || needsAutoZoom {
                // Use enhanced export with effects
                try await exportWithEffects(
                    session: session,
                    cursorSession: cursorSession ?? CursorTrackSession(events: [], duration: 0),
                    to: outputURL,
                    cursorEnabled: needsCursorEnhancement,
                    zoomEnabled: needsAutoZoom
                )
            } else {
                // Standard export
                try await exportEngine.export(session: session, preset: selectedPreset, to: outputURL)
            }
            exportedURL = outputURL
        } catch let exportError as ExportError {
            error = exportError
        } catch {
            self.error = .exportFailed(reason: error.localizedDescription)
        }
        
        isExporting = false
    }
    
    func resetExport() {
        exportedURL = nil
        error = nil
        progress = 0
    }
    
    func cancelExport() async {
        await exportEngine.cancel()
        isExporting = false
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Private Helpers
    
    private func exportWithEffects(
        session: RecordingSession,
        cursorSession: CursorTrackSession,
        to outputURL: URL,
        cursorEnabled: Bool,
        zoomEnabled: Bool
    ) async throws {
        // Build settings based on what's enabled
        let cursorSettings = CursorExportSettings(
            smoothingLevel: cursorEnabled ? smoothingLevel : .low,
            highlightEnabled: cursorEnabled && highlightEnabled
        )
        
        let zoomSettings: AutoZoomSettings
        if zoomEnabled {
            zoomSettings = autoZoomSettings
        } else {
            zoomSettings = AutoZoomSettings(isEnabled: false)
        }
        
        print("[Export] Using CombinedEffectsExporter")
        print("[Export] Cursor settings: highlight=\(cursorSettings.highlightEnabled)")
        print("[Export] Zoom settings: enabled=\(zoomSettings.isEnabled), level=\(zoomSettings.zoomLevel)")
        
        let exporter = CombinedEffectsExporter(
            cursorSettings: cursorSettings,
            autoZoomSettings: zoomSettings
        )
        
        try await exporter.export(
            videoURL: session.outputURL,
            cursorSession: cursorSession,
            to: outputURL
        ) { [weak self] progress in
            Task { @MainActor in
                self?.progress = progress
            }
        }
    }
    
    private func generateOutputURL(for session: RecordingSession, preset: ExportPreset) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let fileName = "Export-\(dateFormatter.string(from: Date())).\(preset.format.rawValue)"
        return documentsPath.appendingPathComponent(fileName)
    }
}
