import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia

actor ScreenCaptureEngine: CaptureEngineProtocol {
    
    // MARK: - Properties
    
    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartTime: Date?
    private var outputURL: URL?
    private var firstFrameTime: CMTime?
    
    private var mouseTrackerEvents: [MouseEvent] = []
    private var mouseTrackerDuration: TimeInterval = 0
    
    private(set) var isRecording: Bool = false
    private var _isPaused: Bool = false
    
    var duration: TimeInterval {
        guard let startTime else { return 0 }
        let elapsed = Date().timeIntervalSince(startTime)
        return max(0, elapsed - pausedDuration)
    }
    
    // MARK: - Permission
    
    func requestPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.current
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Capture Control
    
    func startCapture(config: CaptureConfig) async throws {
        let startTime = Date()
        
        do {
            // 1. Get shareable content (also verifies permission)
            let content = try await SCShareableContent.current
            print("[Capture] SCShareableContent loaded in \(Date().timeIntervalSince(startTime))s")
            
            // 2. Build capture pipeline
            let filter = try createFilter(for: config.source, from: content)
            let streamConfig = createStreamConfiguration(for: config)
            print("[Capture] Filter created in \(Date().timeIntervalSince(startTime))s")
            
            // 3. Setup output file
            outputURL = generateOutputURL()
            try setupAssetWriter(url: outputURL!, config: config)
            print("[Capture] AssetWriter setup in \(Date().timeIntervalSince(startTime))s")
            
            // 4. Create stream with output handler
            stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
            
            streamOutput = StreamOutput(engine: self)
            try stream?.addStreamOutput(streamOutput!, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.smartscreen.capture"))
            print("[Capture] Stream created in \(Date().timeIntervalSince(startTime))s")
            
            // 5. Start capture
            try await stream?.startCapture()
            print("[Capture] Capture started in \(Date().timeIntervalSince(startTime))s")
            
            // 6. Start mouse tracking on main actor
            await MainActor.run {
                MouseTrackerManager.shared.startTracking()
            }
            print("[Capture] Mouse tracking started")
            
            self.startTime = Date()
            pausedDuration = 0
            firstFrameTime = nil
            isRecording = true
            
        } catch let error as RecordingError {
            throw error
        } catch let error as NSError {
            print("[Capture] Error: \(error)")
            // Check for permission denied
            if error.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain" {
                throw RecordingError.permissionDenied
            }
            throw RecordingError.captureSessionFailed(underlying: error)
        }
    }
    
    func pauseCapture() async {
        guard isRecording, !_isPaused else { return }
        _isPaused = true
        pauseStartTime = Date()
    }
    
    func resumeCapture() async {
        guard isRecording, _isPaused, let pauseStart = pauseStartTime else { return }
        pausedDuration += Date().timeIntervalSince(pauseStart)
        pauseStartTime = nil
        _isPaused = false
    }
    
    func stopCapture() async -> RecordingSession {
        print("[Capture] stopCapture called")
        
        // 1. Stop mouse tracking and capture cursor data
        let (trackerEvents, trackerDuration) = await MainActor.run {
            MouseTrackerManager.shared.stopTracking()
            let events = MouseTrackerManager.shared.events
            let duration = MouseTrackerManager.shared.trackingDuration
            return (events, duration)
        }
        let cursorTrackSession = CursorTrackSession(
            events: trackerEvents,
            duration: trackerDuration
        )
        print("[Capture] Mouse tracking stopped, \(trackerEvents.count) events recorded")
        
        // 2. Finalize pause duration
        if _isPaused, let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        
        // 3. Capture final state BEFORE cleanup
        let finalDuration = duration
        guard let finalOutputURL = outputURL else {
            print("[Capture] ERROR: No output URL - recording may have failed to start")
            return RecordingSession(outputURL: generateOutputURL(), duration: 0)
        }
        print("[Capture] Output URL: \(finalOutputURL.path)")
        
        // 4. Stop stream
        do {
            try await stream?.stopCapture()
            print("[Capture] Stream stopped")
        } catch {
            print("[Capture] Error stopping stream: \(error)")
        }
        stream = nil
        streamOutput = nil
        
        // 5. Finalize asset writer (only if actually writing)
        if let assetWriter {
            print("[Capture] AssetWriter status: \(assetWriter.status.rawValue)")
            if assetWriter.status == .writing {
                videoInput?.markAsFinished()
                await assetWriter.finishWriting()
                print("[Capture] AssetWriter finished, final status: \(assetWriter.status.rawValue)")
                if let error = assetWriter.error {
                    print("[Capture] AssetWriter error: \(error)")
                }
            }
        } else {
            print("[Capture] WARNING: No AssetWriter")
        }
        
        // Check if file exists and has content
        if FileManager.default.fileExists(atPath: finalOutputURL.path) {
            let attrs = try? FileManager.default.attributesOfItem(atPath: finalOutputURL.path)
            let size = attrs?[.size] as? Int64 ?? 0
            print("[Capture] Output file size: \(size) bytes")
        } else {
            print("[Capture] ERROR: Output file does not exist!")
        }
        
        assetWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        
        // 6. Reset state
        isRecording = false
        _isPaused = false
        startTime = nil
        pausedDuration = 0
        pauseStartTime = nil
        firstFrameTime = nil
        outputURL = nil
        
        return RecordingSession(
            outputURL: finalOutputURL,
            duration: finalDuration,
            cursorTrackSession: cursorTrackSession
        )
    }
    
    // MARK: - Frame Handling
    
    nonisolated func handleVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        Task { await processVideoFrame(sampleBuffer) }
    }
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording, !_isPaused else { return }
        guard let assetWriter else { return }
        guard let pixelBufferAdaptor else { return }
        
        // 1. Check if frame contains valid content
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let statusValue = attachments.first?[.status] as? Int,
              statusValue == SCFrameStatus.complete.rawValue else {
            return
        }
        
        // 2. Get pixel buffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // 3. Start writing session on first valid frame
        if firstFrameTime == nil {
            guard assetWriter.status == .unknown else { return }
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: timestamp)
            firstFrameTime = timestamp
        }
        
        // 4. Write frame
        guard assetWriter.status == .writing else { return }
        guard let videoInput, videoInput.isReadyForMoreMediaData else { return }
        
        pixelBufferAdaptor.append(imageBuffer, withPresentationTime: timestamp)
    }
    
    // MARK: - Private Helpers
    
    private func createFilter(
        for source: CaptureSource,
        from content: SCShareableContent
    ) throws -> SCContentFilter {
        switch source {
        case .fullScreen(let displayID):
            let display = content.displays.first { $0.displayID == displayID }
                ?? content.displays.first
            guard let display else {
                throw RecordingError.deviceUnavailable(deviceType: "Display")
            }
            return SCContentFilter(display: display, excludingWindows: [])
            
        case .window(let windowID):
            let window: SCWindow?
            if windowID == 0 {
                window = content.windows.first { $0.isOnScreen && $0.title != nil && !$0.title!.isEmpty }
            } else {
                window = content.windows.first { $0.windowID == windowID }
            }
            guard let window else {
                throw RecordingError.deviceUnavailable(deviceType: "Window")
            }
            return SCContentFilter(desktopIndependentWindow: window)
            
        case .region:
            guard let mainDisplay = content.displays.first else {
                throw RecordingError.deviceUnavailable(deviceType: "Display")
            }
            return SCContentFilter(display: mainDisplay, excludingWindows: [])
        }
    }
    
    private func createStreamConfiguration(for config: CaptureConfig) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = config.resolution.width
        configuration.height = config.resolution.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(config.fps))
        configuration.showsCursor = true
        configuration.capturesAudio = false
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        return configuration
    }
    
    private func setupAssetWriter(url: URL, config: CaptureConfig) throws {
        // Remove existing file
        try? FileManager.default.removeItem(at: url)
        
        assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
        
        // Video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: config.resolution.width,
            AVVideoHeightKey: config.resolution.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoExpectedSourceFrameRateKey: config.fps,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        
        // Pixel buffer adaptor
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: config.resolution.width,
            kCVPixelBufferHeightKey as String: config.resolution.height
        ]
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        if let videoInput, assetWriter?.canAdd(videoInput) == true {
            assetWriter?.add(videoInput)
        }
    }
    
    private func generateOutputURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let fileName = "Recording-\(dateFormatter.string(from: Date())).mp4"
        return documentsPath.appendingPathComponent(fileName)
    }
}

// MARK: - Stream Output Handler

private class StreamOutput: NSObject, SCStreamOutput {
    private let engine: ScreenCaptureEngine
    
    init(engine: ScreenCaptureEngine) {
        self.engine = engine
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        engine.handleVideoFrame(sampleBuffer)
    }
}
