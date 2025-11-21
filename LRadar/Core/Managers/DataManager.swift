import SwiftUI
import FirebaseFirestore
import FirebaseStorage

class DataManager {
    static let shared = DataManager()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - 1. 图片上传 (🔥 修改：增加 folder 参数，默认为 "post_images")
    func uploadImage(_ image: UIImage, folder: String = "post_images") async -> String? {
        guard let resizedImage = image.resized(toWidth: 1080),
              let data = resizedImage.jpegData(compressionQuality: 0.7) else { return nil }
        
        let filename = "\(UUID().uuidString).jpg"
        // 使用传入的 folder 参数
        let storageRef = storage.reference().child(folder).child(filename)
        
        do {
            let _ = try await storageRef.putDataAsync(data)
            let url = try await storageRef.downloadURL()
            return url.absoluteString
        } catch {
            print("🔥 图片上传失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 2. 帖子管理
    func savePostToCloud(post: Post) async -> Bool {
        do {
            try db.collection("posts").document(post.id.uuidString).setData(from: post)
            return true
        } catch {
            print("🔥 保存失败: \(error.localizedDescription)")
            return false
        }
    }
    
    func fetchPostsFromCloud() async -> [Post] {
        do {
            let snapshot = try await db.collection("posts")
                .order(by: "timestamp", descending: true)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Post.self) }
        } catch {
            print("🔥 拉取失败: \(error.localizedDescription)")
            return []
        }
    }
    
    func deletePostFromCloud(post: Post) {
        db.collection("posts").document(post.id.uuidString).delete()
    }
    
    // MARK: - 3. 辅助方法
    func saveImage(_ image: UIImage, name: String) -> String? {
        if let data = image.jpegData(compressionQuality: 0.8) {
            let filename = name + ".jpg"
            let url = documentsDirectory.appendingPathComponent(filename)
            try? data.write(to: url)
            return filename
        }
        return nil
    }
    
    func loadImage(filename: String) -> UIImage? {
        let url = documentsDirectory.appendingPathComponent(filename)
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
    
    func loadUserProfile() -> UserProfile? {
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return profile
        }
        return nil
    }
    
    func saveUserProfile(_ profile: UserProfile) {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "userProfile")
        }
    }
    
    func saveUserProfileToCloud(profile: UserProfile) {
        try? db.collection("users").document(profile.id).setData(from: profile)
    }
    
    func fetchUserProfileFromCloud(userId: String) async -> UserProfile? {
        let doc = try? await db.collection("users").document(userId).getDocument()
        return try? doc?.data(as: UserProfile.self)
    }
}
