import SwiftUI
import CoreLocation

// 🔥 关键修改 1: 加上 Equatable 协议，修复 ContentView 的 onChange 报错
struct Post: Identifiable, Codable, Equatable {
    var id = UUID()
    var authorID: String
    var title: String
    var caption: String
    var category: PostCategory
    var latitude: Double
    var longitude: Double
    
    // 🔥 关键修改 2: 确保有这两个图片字段，修复 DataManager 报错
    var imageFilenames: [String] // 兼容旧数据 (本地图片)
    var imageURLs: [String] = [] // ✅ 新增：云端图片链接 (Storage URL)
    
    var timestamp: Date
    var rating: Double // ✅ 新增：评分字段
    var likeCount: Int
    var isLiked: Bool
    
    // 计算属性：方便 MapKit 使用
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // 辅助属性：方便 UI 调用颜色和图标
    var color: UIColor { category.color }
    var icon: String { category.icon }
    
    // Equatable 实现 (Swift 自动合成通常够用，但显式写出来更稳妥)
    static func == (lhs: Post, rhs: Post) -> Bool {
        return lhs.id == rhs.id &&
               lhs.isLiked == rhs.isLiked &&
               lhs.likeCount == rhs.likeCount
    }
}

// MARK: - 帖子分类枚举
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

// MARK: - 用户资料模型
// 🔥 关键修改 3: 确保包含 id 和 avatarURL，修复 LoginView 报错
struct UserProfile: Codable, Identifiable {
    var id: String          // 用户 UID
    var name: String
    var handle: String
    var school: String
    var major: String
    var bio: String
    var rating: Double
    var avatarFilename: String? // 旧字段
    var avatarURL: String?      // ✅ 新字段：云端头像链接
}
