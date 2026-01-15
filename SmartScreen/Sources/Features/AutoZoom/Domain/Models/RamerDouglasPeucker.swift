import Foundation
import CoreGraphics

/// A time-keyed point for path simplification.
struct RDPPoint: Equatable {
    let time: TimeInterval
    let position: CGPoint
}

/// Ramer–Douglas–Peucker line simplification for 2D paths.
enum RamerDouglasPeucker {
    
    /// Simplify points with epsilon tolerance (in normalized coordinate space).
    /// - Keeps first and last points.
    static func simplify(points: [RDPPoint], epsilon: CGFloat) -> [RDPPoint] {
        guard points.count > 2 else { return points }
        let first = points.first!
        let last = points.last!
        
        var index = 0
        var dmax: CGFloat = 0
        
        for i in 1..<(points.count - 1) {
            let d = perpendicularDistance(
                point: points[i].position,
                lineStart: first.position,
                lineEnd: last.position
            )
            if d > dmax {
                index = i
                dmax = d
            }
        }
        
        if dmax > epsilon {
            let left = simplify(points: Array(points[0...index]), epsilon: epsilon)
            let right = simplify(points: Array(points[index...]), epsilon: epsilon)
            return left.dropLast() + right
        } else {
            return [first, last]
        }
    }
    
    // MARK: - Distance
    
    private static func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        
        if dx == 0 && dy == 0 {
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }
        
        // Distance from point to infinite line via area formula.
        let numerator = abs(dy * point.x - dx * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x)
        let denominator = hypot(dx, dy)
        return numerator / denominator
    }
}

