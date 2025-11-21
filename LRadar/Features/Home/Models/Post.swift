import SwiftUI
import CoreLocation

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

struct Post: Identifiable, Codable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let title: String
    let caption: String
    let category: PostCategory
    let rating: Int
    
    // ⚠️ 关键修改：支持多张图片
    var imageFilenames: [String] = []
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    var color: UIColor { category.color }
    var icon: String { category.icon }
    
    // 辅助判断
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
