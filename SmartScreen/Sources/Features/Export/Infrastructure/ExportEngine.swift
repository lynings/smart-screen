import Foundation
import AVFoundation

actor ExportEngine: ExportEngineProtocol {
    
    // MARK: - Properties
    
    private var exportSession: AVAssetExportSession?
    private var progressTimer: Timer?
    
    private(set) var progress: Double = 0
    private(set) var isExporting = false
    
    // MARK: - Export
    
    func export(session: RecordingSession, preset: ExportPreset, to url: URL) async throws {
        print("[Export] Starting export")
        print("[Export] Source: \(session.outputURL.path)")
        print("[Export] Target: \(url.path)")
        
        // 1. Verify source file exists
        guard FileManager.default.fileExists(atPath: session.outputURL.path) else {
            print("[Export] ERROR: Source file not found")
            throw ExportError.sessionNotFound
        }
        
        // 2. Remove existing output file
        try? FileManager.default.removeItem(at: url)
        
        // 3. Load source asset and verify it's readable
        let asset = AVURLAsset(url: session.outputURL)
        let isReadable = try await asset.load(.isReadable)
        guard isReadable else {
            print("[Export] ERROR: Source not readable")
            throw ExportError.exportFailed(reason: "Source video is not readable")
        }
        print("[Export] Source is readable")
        
        // 4. Create export session with passthrough for same format
        let presetName = await selectExportPreset(for: asset, targetPreset: preset)
        print("[Export] Using preset: \(presetName)")
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: presetName) else {
            print("[Export] ERROR: Cannot create export session")
            throw ExportError.exportFailed(reason: "Cannot create export session")
        }
        
        // 5. Configure export
        exportSession.outputURL = url
        exportSession.outputFileType = outputFileType(for: preset.format)
        
        self.exportSession = exportSession
        isExporting = true
        progress = 0
        
        // 6. Start export
        await exportSession.export()
        
        // 7. Check result
        isExporting = false
        print("[Export] Status: \(exportSession.status.rawValue)")
        
        switch exportSession.status {
        case .completed:
            progress = 1.0
            print("[Export] Completed successfully")
        case .cancelled:
            print("[Export] Cancelled")
            throw ExportError.cancelled
        case .failed:
            let reason = exportSession.error?.localizedDescription ?? "Unknown error"
            print("[Export] Failed: \(reason)")
            throw ExportError.exportFailed(reason: reason)
        default:
            print("[Export] Unknown status")
            break
        }
    }
    
    private func selectExportPreset(for asset: AVAsset, targetPreset: ExportPreset) async -> String {
        // Try target resolution first, fallback to passthrough
        let targetPresetName = exportPresetName(for: targetPreset)
        let presets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        
        if presets.contains(targetPresetName) {
            return targetPresetName
        }
        if presets.contains(AVAssetExportPresetPassthrough) {
            return AVAssetExportPresetPassthrough
        }
        return AVAssetExportPresetHighestQuality
    }
    
    func cancel() async {
        exportSession?.cancelExport()
        isExporting = false
    }
    
    // MARK: - Private Helpers
    
    private func exportPresetName(for preset: ExportPreset) -> String {
        switch preset.resolution {
        case .p720:
            return AVAssetExportPreset1280x720
        case .p1080:
            return AVAssetExportPreset1920x1080
        case .p4K:
            return AVAssetExportPreset3840x2160
        case .custom:
            return AVAssetExportPresetHighestQuality
        }
    }
    
    private func outputFileType(for format: ExportFormat) -> AVFileType {
        switch format {
        case .mp4:
            return .mp4
        case .mov:
            return .mov
        }
    }
}
