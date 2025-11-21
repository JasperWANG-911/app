import SwiftUI
import CoreLocation

// MARK: - 1. 帖子模型 (Post)
struct Post: Identifiable, Codable, Equatable {
    var id = UUID()
    var authorID: String
    var title: String       // 这是帖子的标题 (例如 "Great Coffee")
    var caption: String
    var category: PostCategory
    var latitude: Double
    var longitude: Double
    
    var imageFilenames: [String] // 兼容旧数据
    var imageURLs: [String] = [] // 云端图片链接
    
    var timestamp: Date
    
    var likeCount: Int
    var isLiked: Bool
    
    // 计算属性：方便 MapKit 使用
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var color: UIColor { category.color }
    var icon: String { category.icon }
    
    static func == (lhs: Post, rhs: Post) -> Bool {
        return lhs.id == rhs.id &&
               lhs.isLiked == rhs.isLiked &&
               lhs.likeCount == rhs.likeCount
    }
}

// MARK: - 2. 帖子分类 (PostCategory)
enum PostCategory: String, CaseIterable, Identifiable, Codable {
    case alert = "Alert"
    case food = "Foodie"
    case thrift = "Market"
    case explore = "Explore"
    case campus = "Campus"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .alert: return "exclamationmark.triangle.fill"
        case .food: return "fork.knife"
        case .thrift: return "sterlingsign.circle.fill"
        case .explore: return "camera.fill"
        case .campus: return "graduationcap.fill"
        }
    }
    
    var color: UIColor {
        switch self {
        case .alert: return .systemRed
        case .food: return .systemOrange
        case .thrift: return .systemGreen
        case .explore: return .systemBlue
        case .campus: return .systemPurple
        }
    }
}

// MARK: - 3. 用户资料模型 (UserProfile)
struct UserProfile: Codable, Identifiable {
    var id: String
    var name: String
    var handle: String
    var school: String
    var major: String
    var bio: String
    
    var avatarFilename: String?
    var avatarURL: String?
    
    // ✅ 新增：声望值 (默认 0)
    var reputation: Int = 0
    
    // ✅ 新增：根据声望计算的头衔 (这里用 rankTitle 以免和帖子 title 混淆)
    var rankTitle: String {
        switch reputation {
        case 0..<50: return "Freshman"
        case 50..<200: return "Explorer"
        case 200..<500: return "Guide"
        default: return "Legend"
        }
    }
}
