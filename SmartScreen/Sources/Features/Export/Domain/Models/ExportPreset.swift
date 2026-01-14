import Foundation

struct ExportPreset: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let resolution: Resolution
    let fps: Int
    let bitrate: Int
    let format: ExportFormat
    let isBuiltIn: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        resolution: Resolution,
        fps: Int,
        bitrate: Int,
        format: ExportFormat,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.resolution = resolution
        self.fps = fps
        self.bitrate = bitrate
        self.format = format
        self.isBuiltIn = isBuiltIn
    }
    
    func estimatedFileSize(forDuration duration: TimeInterval) -> Int64 {
        // bitrate is in bits per second, convert to bytes
        let bytesPerSecond = Double(bitrate) / 8.0
        return Int64(bytesPerSecond * duration)
    }
}

// MARK: - Built-in Presets

extension ExportPreset {
    static let web = ExportPreset(
        name: "Web",
        resolution: .p1080,
        fps: 30,
        bitrate: 8_000_000,
        format: .mp4,
        isBuiltIn: true
    )
    
    static let highQuality = ExportPreset(
        name: "High Quality",
        resolution: .p4K,
        fps: 60,
        bitrate: 25_000_000,
        format: .mov,
        isBuiltIn: true
    )
    
    static let social = ExportPreset(
        name: "Social",
        resolution: .custom(width: 1080, height: 1080),
        fps: 30,
        bitrate: 6_000_000,
        format: .mp4,
        isBuiltIn: true
    )
    
    static let vertical = ExportPreset(
        name: "Vertical",
        resolution: .custom(width: 1080, height: 1920),
        fps: 30,
        bitrate: 8_000_000,
        format: .mp4,
        isBuiltIn: true
    )
    
    static let compact = ExportPreset(
        name: "Compact",
        resolution: .p720,
        fps: 30,
        bitrate: 4_000_000,
        format: .mp4,
        isBuiltIn: true
    )
    
    static let allBuiltIn: [ExportPreset] = [.web, .highQuality, .social, .vertical, .compact]
}
