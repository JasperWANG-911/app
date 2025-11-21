import SwiftUI
import CoreLocation

enum PostCategory: String, CaseIterable, Identifiable, Codable {
    case alert = "Alert"
    case food = "Foodie"
    case thrift = "Market"
    case explore = "Explore"
    case campus = "Campus"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .alert: return "exclamationmark.triangle.fill" // 警示
        case .food: return "fork.knife"                     // 干饭
        case .thrift: return "sterlingsign.circle.fill"     // 省钱/交易 (英镑符号，如果不喜欢可以用 dollarsign)
        case .explore: return "camera.fill"                 // 玩乐/拍照
        case .campus: return "graduationcap.fill"           // 校园生活
        }
    }
    
    var color: UIColor {
        switch self {
        case .alert: return .systemRed       // 红色：危险/紧急
        case .food: return .systemOrange     // 橙色：食欲
        case .thrift: return .systemGreen    // 绿色：金钱/交易
        case .explore: return .systemBlue    // 蓝色：户外/天空
        case .campus: return .systemPurple   // 紫色：智慧/学校
        }
    }
}

// MARK: - 核心数据模型 (Cloud Ready)

struct UserProfile: Codable, Identifiable {
    // 🔥 新增: 唯一用户ID (未来对应 Firebase UID)
    var id: String
    
    var name: String
    var handle: String
    var school: String
    var major: String
    var bio: String
    var rating: Double
    
    // 头像：本地存文件名，云端存 URL
    var avatarFilename: String?
    var avatarURL: String?
}

struct Post: Identifiable, Codable {
    var id = UUID()
    
    // 🔥 新增: 作者ID (关联到 UserProfile.id)
    let authorID: String
    
    // 核心内容
    let title: String
    let caption: String
    let category: PostCategory
    
    // 地理位置
    let latitude: Double
    let longitude: Double
    
    // 媒体资源
    var imageFilenames: [String] = [] // 本地图片名 (缓存)
    var imageURLs: [String] = []      // 云端图片链接 (未来使用)
    
    // 🔥 新增: 时间戳 (用于排序)
    var timestamp: Date = Date()
    
    // 互动数据
    var rating: Int = 0
    var likeCount: Int = 0
    var isLiked: Bool = false // 注意：这个状态在云端通常是单独查询的，但在本地模型中先保留方便 UI 显示
    
    // 辅助计算属性
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    var color: UIColor { category.color }
    var icon: String { category.icon }
    var hasImage: Bool { !imageFilenames.isEmpty }
}
