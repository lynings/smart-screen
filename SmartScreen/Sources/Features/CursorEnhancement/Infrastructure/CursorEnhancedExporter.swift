import Foundation
import AVFoundation
import CoreGraphics
import SwiftUI

/// Exports video with click highlight effects
/// Note: The original video already contains the system cursor (showsCursor = true)
///       This exporter only adds click highlight animations around clicks
actor CursorEnhancedExporter {
    
    // MARK: - Properties
    
    nonisolated let smoothingLevel: SmoothingLevel
    nonisolated let highlightEnabled: Bool
    
    private let renderer: CursorRenderer
    private var _isExporting = false
    private var _progress: Double = 0
    
    var isExporting: Bool { _isExporting }
    var progress: Double { _progress }
    
    // MARK: - Initialization
    
    init(
        smoothingLevel: SmoothingLevel = .medium,
        highlightEnabled: Bool = true,
        highlightRadius: CGFloat = 30
    ) {
        self.smoothingLevel = smoothingLevel
        self.highlightEnabled = highlightEnabled
        self.renderer = CursorRenderer(highlightRadius: highlightRadius)
    }
    
    // MARK: - Export
    
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
        
        // 1. Load source video
        let asset = AVURLAsset(url: videoURL)
        
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExportError.invalidSourceFile
        }
        
        let duration = try await asset.load(.duration)
        let videoSize = try await videoTrack.load(.naturalSize)
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        
        print("[CursorEnhancedExporter] Video size: \(videoSize)")
        print("[CursorEnhancedExporter] Click events: \(cursorSession.clickEvents.count)")
        print("[CursorEnhancedExporter] Highlight enabled: \(highlightEnabled)")
        
        // 2. Setup reader
        let reader = try AVAssetReader(asset: asset)
        let readerOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
        reader.add(readerOutput)
        
        // 3. Setup writer
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
        
        // 4. Copy audio track if exists
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            reader.add(audioOutput)
            
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            writer.add(audioInput)
        }
        
        // 5. Start processing
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
                
                // Get active click highlights for this frame
                let highlights = activeHighlights(
                    at: timeSeconds,
                    cursorSession: cursorSession,
                    videoSize: videoSize
                )
                
                if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                    let context = CIContext()
                    
                    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                        // Render click highlights (cursor is already in the video)
                        if let enhancedImage = renderer.renderFrame(
                            source: cgImage,
                            highlights: highlights
                        ) {
                            if let pixelBuffer = createPixelBuffer(from: enhancedImage, pool: adaptor.pixelBufferPool) {
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
        
        // 6. Finish writing
        writerInput.markAsFinished()
        await writer.finishWriting()
        
        _progress = 1.0
        progressHandler?(1.0)
    }
    
    // MARK: - Highlight Calculation
    
    /// Get active click highlight animations at the specified time
    nonisolated func activeHighlights(
        at time: TimeInterval,
        cursorSession: CursorTrackSession,
        videoSize: CGSize
    ) -> [ActiveHighlight] {
        guard highlightEnabled else { return [] }
        
        return cursorSession.clickEvents.compactMap { click in
            let clickTime = click.timestamp
            let duration = click.type.animationDuration
            
            guard time >= clickTime && time <= clickTime + duration else {
                return nil
            }
            
            let progress = (time - clickTime) / duration
            let style: HighlightAnimation.HighlightStyle = click.type == .doubleClick ? .doubleRing : .pulse
            
            // Convert normalized position to video pixels
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
