import SwiftUI
import FirebaseFirestore
import FirebaseStorage

class DataManager {
    static let shared = DataManager()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // 本地文档目录 (用于旧的本地缓存逻辑)
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - 1. 图片上传 (支持自定义文件夹)
    /// 上传图片到 Firebase Storage
    /// - Parameters:
    ///   - image: 要上传的 UIImage
    ///   - folder: 目标文件夹，默认为 "post_images"，头像可用 "avatars"
    /// - Returns: 下载链接字符串 (URL String)
    func uploadImage(_ image: UIImage, folder: String = "post_images") async -> String? {
        // 1. 压缩图片 (调用 Extensions.swift 里的 resized)
        guard let resizedImage = image.resized(toWidth: 1080),
              let data = resizedImage.jpegData(compressionQuality: 0.7) else { return nil }
        
        // 2. 生成文件名
        let filename = "\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child(folder).child(filename)
        
        // 3. 上传并获取 URL
        do {
            let _ = try await storageRef.putDataAsync(data)
            let url = try await storageRef.downloadURL()
            return url.absoluteString
        } catch {
            print("🔥 图片上传失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 2. 帖子管理 (实时监听 & 增删改)
    
    /// 保存或更新帖子到 Firestore
    func savePostToCloud(post: Post) async -> Bool {
        do {
            try db.collection("posts").document(post.id.uuidString).setData(from: post)
            return true
        } catch {
            print("🔥 保存帖子失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 🔥 核心功能：实时监听帖子变化
    /// - Parameter completion: 数据更新时的回调
    /// - Returns: 监听器注册对象 (用于取消监听)
    func listenToPosts(completion: @escaping ([Post]) -> Void) -> ListenerRegistration {
        return db.collection("posts")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("🔥 监听帖子出错: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                // 解析数据
                let posts = documents.compactMap { try? $0.data(as: Post.self) }
                completion(posts)
            }
    }
    
    /// 仅拉取一次数据 (备用，目前主要用 listenToPosts)
    func fetchPostsFromCloud() async -> [Post] {
        do {
            let snapshot = try await db.collection("posts")
                .order(by: "timestamp", descending: true)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: Post.self) }
        } catch {
            print("🔥 拉取帖子失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 删除帖子 (同时清理云端图片)
    func deletePostFromCloud(post: Post) {
        let postID = post.id.uuidString
        
        // 1. 删除 Firestore 文档
        db.collection("posts").document(postID).delete()
        
        // 2. 异步清理 Storage 里的图片 (Fire-and-forget，不阻塞 UI)
        Task {
            for urlString in post.imageURLs {
                // Firebase SDK 可以直接从 URL 创建引用
                let storageRef = storage.reference(forURL: urlString)
                do {
                    try await storageRef.delete()
                    print("🗑️ 已删除关联图片: \(urlString)")
                } catch {
                    print("⚠️ 删除图片失败 (可能是已经删了): \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - 3. 用户资料管理
    
    /// 保存用户资料到云端
    func saveUserProfileToCloud(profile: UserProfile) {
        do {
            try db.collection("users").document(profile.id).setData(from: profile)
        } catch {
            print("🔥 保存用户资料失败: \(error.localizedDescription)")
        }
    }
    
    /// 从云端获取用户资料
    func fetchUserProfileFromCloud(userId: String) async -> UserProfile? {
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            return try doc.data(as: UserProfile.self)
        } catch {
            print("⚠️ 获取用户资料失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 4. 本地缓存辅助 (UserDefaults & FileSystem)
    
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
    
    // (保留旧方法以兼容可能存在的本地图片逻辑，虽然现在主要用云端 URL)
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
}
