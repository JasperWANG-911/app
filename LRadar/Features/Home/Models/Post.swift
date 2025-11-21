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

struct Post: Identifiable, Codable {
    var id = UUID() // 建议改为 var，虽然 let 也可以，但在某些解码场景下 var 更灵活
    let latitude: Double
    let longitude: Double
    let title: String
    let caption: String
    let category: PostCategory
    let rating: Int // 可以保留作为帖子的评分
    
    // 新增字段
    var isLiked: Bool = false
    var likeCount: Int = 0
    
    var imageFilenames: [String] = []
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    var color: UIColor { category.color }
    var icon: String { category.icon }
    
    var hasImage: Bool { !imageFilenames.isEmpty }
}

struct UserProfile: Codable {
    var name: String
    var handle: String
    var school: String
    var major: String
    var bio: String
    var rating: Double
    var avatarFilename: String?
}
