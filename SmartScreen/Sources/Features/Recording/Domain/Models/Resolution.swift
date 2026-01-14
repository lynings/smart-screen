import Foundation

enum Resolution: Equatable, Codable {
    case p720
    case p1080
    case p4K
    case custom(width: Int, height: Int)
    
    var width: Int {
        switch self {
        case .p720: return 1280
        case .p1080: return 1920
        case .p4K: return 3840
        case .custom(let width, _): return width
        }
    }
    
    var height: Int {
        switch self {
        case .p720: return 720
        case .p1080: return 1080
        case .p4K: return 2160
        case .custom(_, let height): return height
        }
    }
}
