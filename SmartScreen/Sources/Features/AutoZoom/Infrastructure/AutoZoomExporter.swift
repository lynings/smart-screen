import Foundation
import AVFoundation
import CoreGraphics
import CoreImage

/// Exports video with auto-zoom effects applied
actor AutoZoomExporter {
    
    // MARK: - Properties
    
    nonisolated let settings: AutoZoomSettings
    
    private let analyzer: HotspotAnalyzer
    private let renderer: ZoomRenderer
    
    private var _isExporting = false
    private var _progress: Double = 0
    
    var isExporting: Bool { _isExporting }
    var progress: Double { _progress }
    
    // MARK: - Initialization
    
    init(settings: AutoZoomSettings = AutoZoomSettings()) {
        self.settings = settings
        self.analyzer = HotspotAnalyzer()
        self.renderer = ZoomRenderer()
    }
    
    // MARK: - Export
    
    /// Export video with auto-zoom effects
    func export(
        videoURL: URL,
        cursorSession: CursorTrackSession,
        to outputURL: URL,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        _isExporting = true
        _progress = 0
        
        defer {
            _isExporting = false
        }
        
        // 1. Analyze session for zoom segments
        let segments = analyzeSession(cursorSession, settings: settings)
        print("[AutoZoomExporter] Generated \(segments.count) zoom segments")
        
        // 2. Load source video
        let asset = AVURLAsset(url: videoURL)
        
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExportError.invalidSourceFile
        }
        
        let duration = try await asset.load(.duration)
        let videoSize = try await videoTrack.load(.naturalSize)
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        
        print("[AutoZoomExporter] Video size: \(videoSize), duration: \(duration.seconds)s")
        
        // 3. Setup reader
        let reader = try AVAssetReader(asset: asset)
        let readerOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
        reader.add(readerOutput)
        
        // 4. Setup writer
        let writer = try AVAssetWriter(url: outputURL, fileType: .mp4)
        
        let writerInputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height)
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerInputSettings)
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(videoSize.width),
            kCVPixelBufferHeightKey as String: Int(videoSize.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        writer.add(writerInput)
        
        // 5. Copy audio track if exists
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            reader.add(audioOutput)
            
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            writer.add(audioInput)
        }
        
        // 6. Start processing
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        let totalFrames = Int(duration.seconds * Double(frameRate))
        var frameCount = 0
        
        while reader.status == .reading {
            if writerInput.isReadyForMoreMediaData,
               let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                
                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                let timeSeconds = presentationTime.seconds
                
                // Get zoom parameters for this frame
                let currentScale = scale(at: timeSeconds, segments: segments)
                let currentCenter = center(at: timeSeconds, segments: segments) ?? CGPoint(x: 0.5, y: 0.5)
                
                // Render zoomed frame
                if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                    let context = CIContext()
                    
                    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                        if let zoomedImage = renderer.renderFrame(
                            source: cgImage,
                            scale: currentScale,
                            center: currentCenter,
                            outputSize: videoSize
                        ) {
                            if let pixelBuffer = createPixelBuffer(from: zoomedImage, pool: adaptor.pixelBufferPool) {
                                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                            }
                        }
                    }
                }
                
                frameCount += 1
                _progress = Double(frameCount) / Double(totalFrames)
                progressHandler?(_progress)
            }
        }
        
        // 7. Finish writing
        writerInput.markAsFinished()
        await writer.finishWriting()
        
        _progress = 1.0
        progressHandler?(1.0)
    }
    
    // MARK: - Session Analysis
    
    nonisolated func analyzeSession(
        _ session: CursorTrackSession,
        settings: AutoZoomSettings
    ) -> [ZoomSegment] {
        // Create a new analyzer instance for nonisolated context
        let localAnalyzer = HotspotAnalyzer()
        return localAnalyzer.analyze(session: session, settings: settings)
    }
    
    // MARK: - Zoom Calculation
    
    nonisolated func scale(at time: TimeInterval, segments: [ZoomSegment]) -> CGFloat {
        // Find active segment at this time
        for segment in segments {
            if segment.contains(time: time) {
                return segment.scale(at: time)
            }
        }
        return 1.0  // No zoom
    }
    
    nonisolated func center(at time: TimeInterval, segments: [ZoomSegment]) -> CGPoint? {
        // Find active segment at this time
        for segment in segments {
            if segment.contains(time: time) {
                return segment.center(at: time)
            }
        }
        return nil
    }
    
    // MARK: - Private Helpers
    
    private func createPixelBuffer(from image: CGImage, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        guard let pool else { return nil }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        
        return buffer
    }
}
