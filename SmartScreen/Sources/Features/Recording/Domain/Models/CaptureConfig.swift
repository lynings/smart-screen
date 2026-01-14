import Foundation

/// Configuration for screen capture session
struct CaptureConfig: Equatable {
    let source: CaptureSource
    let audioDevice: AudioDevice?
    let fps: Int
    let resolution: Resolution
    
    init(
        source: CaptureSource,
        audioDevice: AudioDevice? = nil,
        fps: Int = 30,
        resolution: Resolution = .p1080
    ) {
        self.source = source
        self.audioDevice = audioDevice
        self.fps = fps
        self.resolution = resolution
    }
}
