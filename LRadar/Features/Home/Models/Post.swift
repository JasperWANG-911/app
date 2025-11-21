import SwiftUI
import CoreLocation

struct Post: Identifiable, Codable {
    var id = UUID()
    var authorID: String
    var title: String
    var caption: String
    var category: PostCategory
    var latitude: Double
    var longitude: Double
    
    // 🔥 关键修改：添加了这个字段，ViewModel 里的报错才会消失
    var imageFilenames: [String] // 兼容旧数据
    var imageURLs: [String] = [] // ✅ 新增：云端图片链接
    
    var timestamp: Date
    var rating: Double
    var likeCount: Int
    var isLiked: Bool
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // 辅助属性，方便 UI 调用颜色和图标
    var color: UIColor { category.color }
    var icon: String { category.icon }
}

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

// 用户资料模型保持不变
struct UserProfile: Codable, Identifiable {
    var id: String
    var name: String
    var handle: String
    var school: String
    var major: String
    var bio: String
    var rating: Double
    var avatarFilename: String?
    var avatarURL: String?
}
