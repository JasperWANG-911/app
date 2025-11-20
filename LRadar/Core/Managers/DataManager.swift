import SwiftUI

class DataManager {
    static let shared = DataManager()
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func saveImage(_ image: UIImage, name: String) -> String? {
        // 依赖于 Extensions.swift 里的 resized 方法
        guard let resizedImage = image.resized(toWidth: 800),
              let data = resizedImage.jpegData(compressionQuality: 0.7) else { return nil }
              
        let filename = name + ".jpg"
        let url = documentsDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: url)
            return filename
        } catch {
            print("保存图片失败: \(error)")
            return nil
        }
    }
    
    func loadImage(filename: String) -> UIImage? {
        let url = documentsDirectory.appendingPathComponent(filename)
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
    
    func saveUserProfile(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            let url = documentsDirectory.appendingPathComponent("user_profile.json")
            try? data.write(to: url)
        }
    }
    
    func loadUserProfile() -> UserProfile? {
        let url = documentsDirectory.appendingPathComponent("user_profile.json")
        if let data = try? Data(contentsOf: url),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return profile
        }
        return nil
    }
    
    func savePosts(_ posts: [Post]) {
        if let data = try? JSONEncoder().encode(posts) {
            let url = documentsDirectory.appendingPathComponent("posts.json")
            try? data.write(to: url)
        }
    }
    
    func loadPosts() -> [Post] {
        let url = documentsDirectory.appendingPathComponent("posts.json")
        if let data = try? Data(contentsOf: url),
           let posts = try? JSONDecoder().decode([Post].self, from: data) {
            return posts
        }
        return []
    }
}
