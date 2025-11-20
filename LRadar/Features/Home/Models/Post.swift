import SwiftUI
import CoreLocation

// ✅ 1. 帖子分类枚举 (PostCategory)
enum PostCategory: String, CaseIterable, Identifiable, Codable {
    case food = "Food"
    case view = "View"
    case alert = "Alert"
    case fun = "Fun"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .view: return "camera.fill"
        case .alert: return "exclamationmark.triangle.fill"
        case .fun: return "party.popper.fill"
        }
    }
    
    var color: UIColor {
        switch self {
        case .food: return .systemOrange
        case .view: return .systemBlue
        case .alert: return .systemRed
        case .fun: return .systemPurple
        }
    }
}

// ✅ 2. 帖子结构 (Post - 必须 Codable 且使用 Double 存坐标)
struct Post: Identifiable, Codable {
    let id = UUID()
    let latitude: Double // 存储用
    let longitude: Double // 存储用
    
    let title: String
    let caption: String
    let category: PostCategory
    let rating: Int
    let imageFilename: String? // 单图文件名
    
    var coordinate: CLLocationCoordinate2D { // 计算属性，用于 MapKit
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var color: UIColor { category.color }
    var icon: String { category.icon }
    var hasImage: Bool { imageFilename != nil }
}

// ✅ 3. 用户资料结构 (UserProfile)
struct UserProfile: Codable {
    var name: String
    var handle: String
    var school: String
    var major: String
    var bio: String
    var rating: Double
    var avatarFilename: String?
}
