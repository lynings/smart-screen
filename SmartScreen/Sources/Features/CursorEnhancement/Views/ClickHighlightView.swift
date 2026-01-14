import SwiftUI

struct ClickHighlightView: View {
    let animation: HighlightAnimation
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1.0
    
    var body: some View {
        ZStack {
            // Primary ring
            Circle()
                .stroke(animation.color.opacity(opacity), lineWidth: 3)
                .frame(width: 40 * scale, height: 40 * scale)
            
            // Secondary ring for double click
            if animation.style == .doubleRing {
                Circle()
                    .stroke(animation.color.opacity(opacity * 0.6), lineWidth: 2)
                    .frame(width: 60 * scale, height: 60 * scale)
            }
            
            // Center dot
            Circle()
                .fill(animation.color.opacity(opacity * 0.5))
                .frame(width: 8, height: 8)
        }
        .position(animation.position)
        .onAppear {
            withAnimation(.easeOut(duration: animation.duration)) {
                scale = 2.0
                opacity = 0
            }
        }
    }
}

/// Container view that renders all active highlights
struct ClickHighlightsOverlay: View {
    let highlights: [HighlightAnimation]
    
    var body: some View {
        ZStack {
            ForEach(Array(highlights.enumerated()), id: \.offset) { _, highlight in
                ClickHighlightView(animation: highlight)
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview("Single Click") {
    ZStack {
        Color.black
        
        ClickHighlightView(animation: HighlightAnimation(
            position: CGPoint(x: 200, y: 200),
            color: .blue,
            duration: 0.5,
            style: .pulse
        ))
    }
}

#Preview("Double Click") {
    ZStack {
        Color.black
        
        ClickHighlightView(animation: HighlightAnimation(
            position: CGPoint(x: 200, y: 200),
            color: .blue,
            duration: 0.5,
            style: .doubleRing
        ))
    }
}
