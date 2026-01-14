import Foundation
import AVFoundation
import CoreGraphics
import CoreImage

/// Settings for cursor enhancement export
struct CursorExportSettings {
    let smoothingLevel: SmoothingLevel
    let highlightEnabled: Bool
}

/// Exports video with combined cursor enhancement and auto-zoom effects
actor CombinedEffectsExporter {
    
    // MARK: - Properties
    
    nonisolated let cursorSettings: CursorExportSettings
    nonisolated let autoZoomSettings: AutoZoomSettings
    
    private let zoomRenderer: ZoomRenderer
    private let cursorRenderer: CursorRenderer
    
    private var _isExporting = false
    private var _progress: Double = 0
    
    var isExporting: Bool { _isExporting }
    var progress: Double { _progress }
    
    // MARK: - Initialization
    
    init(
        cursorSettings: CursorExportSettings,
        autoZoomSettings: AutoZoomSettings
    ) {
        self.cursorSettings = cursorSettings
        self.autoZoomSettings = autoZoomSettings
        self.zoomRenderer = ZoomRenderer()
        self.cursorRenderer = CursorRenderer()
    }
    
    // MARK: - Export
    
    /// Export video with combined effects
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
        
        // 1. Load source video first to get video size
        let asset = AVURLAsset(url: videoURL)
        
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExportError.invalidSourceFile
        }
        
        let duration = try await asset.load(.duration)
        let videoSize = try await videoTrack.load(.naturalSize)
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        
        print("[CombinedExporter] Video size: \(videoSize), duration: \(duration.seconds)s")
        
        // 2. Generate zoom timeline from click events (AC-based approach)
        let zoomTimeline = createZoomTimeline(from: cursorSession, screenSize: videoSize)
        print("[CombinedExporter] Generated \(zoomTimeline.segmentCount) zoom segments")
        
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
        let ciContext = CIContext()
        
        while reader.status == .reading {
            if writerInput.isReadyForMoreMediaData,
               let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                
                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                let timeSeconds = presentationTime.seconds
                
                // Get cursor position for follow mode (AC-FU-02)
                let cursorPosition = cursorSession.positionAt(time: timeSeconds)
                
                // Check if keyboard is active (typing triggers zoom-out)
                let hasKeyboardActivity = cursorSession.hasKeyboardActivityAt(time: timeSeconds)
                
                // Get zoom state with follow mode and keyboard activity support
                let zoomState = zoomTimeline.state(
                    at: timeSeconds,
                    cursorPosition: cursorPosition,
                    followCursor: autoZoomSettings.followCursor,
                    smoothing: autoZoomSettings.cursorSmoothing,
                    hasKeyboardActivity: hasKeyboardActivity
                )
                let currentScale = zoomState.scale
                let currentCenter = zoomState.center
                
                // Get cursor highlights for this frame
                let highlights = activeHighlights(at: timeSeconds, cursorSession: cursorSession, videoSize: videoSize)
                
                // Process frame
                if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    var processedImage: CGImage?
                    
                    // Step 1: Get source image
                    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                    if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                        
                        // Step 2: Apply zoom if active
                        let zoomedImage = zoomRenderer.renderFrame(
                            source: cgImage,
                            scale: currentScale,
                            center: currentCenter,
                            outputSize: videoSize
                        ) ?? cgImage
                        
                        // Step 3: Apply cursor highlights if any
                        if !highlights.isEmpty {
                            // Adjust highlight positions for zoom
                            let adjustedHighlights = adjustHighlightsForZoom(
                                highlights,
                                scale: currentScale,
                                center: currentCenter,
                                videoSize: videoSize
                            )
                            
                            // AC-CE-01: Scale highlight radius when zoomed
                            let highlightScale = currentScale > 1.0 ? autoZoomSettings.cursorScale : 1.0
                            
                            processedImage = cursorRenderer.renderFrame(
                                source: zoomedImage,
                                highlights: adjustedHighlights,
                                highlightScale: highlightScale
                            )
                        } else {
                            processedImage = zoomedImage
                        }
                    }
                    
                    // Write frame
                    if let finalImage = processedImage,
                       let pixelBuffer = createPixelBuffer(from: finalImage, pool: adaptor.pixelBufferPool) {
                        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
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
    
    // MARK: - Cursor Highlights
    
    private func activeHighlights(
        at time: TimeInterval,
        cursorSession: CursorTrackSession,
        videoSize: CGSize
    ) -> [ActiveHighlight] {
        guard cursorSettings.highlightEnabled else { return [] }
        
        return cursorSession.clickEvents.compactMap { click in
            let clickTime = click.timestamp
            let duration = click.type.animationDuration
            
            guard time >= clickTime && time <= clickTime + duration else {
                return nil
            }
            
            let progress = (time - clickTime) / duration
            let style: HighlightAnimation.HighlightStyle = click.type == .doubleClick ? .doubleRing : .pulse
            
            // Convert normalized position to video coordinates
            let videoPosition = CGPoint(
                x: click.position.x * videoSize.width,
                y: click.position.y * videoSize.height
            )
            
            return ActiveHighlight(
                position: videoPosition,
                style: style,
                color: click.type.highlightColor,
                progress: progress
            )
        }
    }
    
    /// Adjust highlight positions based on current zoom state
    private func adjustHighlightsForZoom(
        _ highlights: [ActiveHighlight],
        scale: CGFloat,
        center: CGPoint,
        videoSize: CGSize
    ) -> [ActiveHighlight] {
        guard scale > 1.0 else { return highlights }
        
        let cropRect = zoomRenderer.calculateCropRect(
            scale: scale,
            center: center,
            sourceSize: videoSize
        )
        
        return highlights.compactMap { highlight in
            // Convert position from source coordinates to zoomed coordinates
            // Note: highlight.position uses our coordinate system (Y=0 at top)
            // cropRect uses CGImage coordinate system (Y=0 at bottom)
            let sourceX = highlight.position.x
            // Flip Y to match CGImage coordinate system
            let sourceY = videoSize.height - highlight.position.y
            
            // Check if position is within crop rect (in CGImage coordinates)
            guard cropRect.contains(CGPoint(x: sourceX, y: sourceY)) else {
                return nil // Position not visible in zoomed view
            }
            
            // Map to output coordinates (relative position within crop rect)
            let relativeX = (sourceX - cropRect.origin.x) / cropRect.width
            let relativeY = (sourceY - cropRect.origin.y) / cropRect.height
            
            // Convert back to our coordinate system (flip Y again for output)
            let adjustedPosition = CGPoint(
                x: relativeX * videoSize.width,
                y: (1.0 - relativeY) * videoSize.height
            )
            
            return ActiveHighlight(
                position: adjustedPosition,
                style: highlight.style,
                color: highlight.color,
                progress: highlight.progress
            )
        }
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
    
    // MARK: - Zoom Timeline Creation
    
    /// Create zoom timeline from cursor session using AC-based approach
    /// AC-TR-01: Only clicks trigger zoom
    /// AC-TR-02: No clicks = no zoom
    /// AC-TR-03: Nearby clicks are merged
    private nonisolated func createZoomTimeline(
        from session: CursorTrackSession,
        screenSize: CGSize
    ) -> ZoomTimeline {
        guard autoZoomSettings.isEnabled else {
            return ZoomTimeline.empty(duration: session.duration)
        }
        
        // Create generator config from settings with optimized debouncing
        let generatorConfig = ZoomSegmentGenerator.Config(
            defaultDuration: autoZoomSettings.holdTime + autoZoomSettings.duration * 2,
            defaultZoomScale: autoZoomSettings.zoomLevel,
            clickMergeTime: 0.5,            // Optimized for debouncing rapid clicks
            clickMergeDistancePixels: 150,   // Increased for smoother experience
            segmentMergeGap: 0.5,            // Merge segments with short gaps
            segmentMergeDistance: 0.08,      // Increased for more merging
            minZoomScale: 1.0,
            maxZoomScale: 6.0,
            easing: autoZoomSettings.easing
        )
        
        // Transition duration matches segment merge gap for seamless transitions
        return ZoomTimeline.from(
            session: session,
            screenSize: screenSize,
            config: generatorConfig,
            transitionDuration: 0.4
        )
    }
}
