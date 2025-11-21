import SwiftUI
import MapKit
import PhotosUI
import FirebaseAuth // 🔥 必须引入，用于获取 currentUser.uid

@Observable
class HomeViewModel {
    // MARK: - 1. 地图相机位置
    var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
    )
    
    // MARK: - 2. 数据源
    var posts: [Post] = []
    var currentUser: UserProfile
    
    // MARK: - 3. UI 交互状态
    var isSelectingMode = false
    var selectedLocation: CLLocationCoordinate2D?
    var isShowingInputSheet = false
    var activePost: Post? = nil
    
    // 表单输入状态
    var inputTitle = ""
    var inputCaption = ""
    var inputCategory: PostCategory = .food
    
    // 多图选择
    var selectedImages: [UIImage] = []
    var imageSelections: [PhotosPickerItem] = [] {
        didSet {
            loadSelectedImages()
        }
    }
    
    // UI 反馈
    var showToast = false
    var toastMessage = ""
    
    // 🔥 新增：专门筛选出“我的帖子” (用于 ProfileView 和 MyDropsListView)
    var myDrops: [Post] {
        posts.filter { $0.authorID == currentUser.id }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var myDropsCount: Int {
        myDrops.count
    }
    
    var myTotalLikes: Int {
        posts.filter { $0.authorID == currentUser.id }
            .reduce(0) { $0 + $1.likeCount }
    }

    
    // MARK: - 初始化
    init() {
        // 1. 加载本地用户资料作为缓存 (防止 UI 空白)
        if let savedProfile = DataManager.shared.loadUserProfile() {
            self.currentUser = savedProfile
        } else {
            // 默认占位符
            self.currentUser = UserProfile(
                id: UUID().uuidString,
                name: "New User",
                handle: "@new_user",
                school: "UCL",
                major: "Undeclared",
                bio: "Write something...",
                rating: 5.0,
                avatarFilename: nil
            )
        }
        
        // 2. 启动时异步拉取云端帖子
        Task {
            await fetchPosts()
        }
    }
    
    // 从云端拉取数据
    @MainActor
    func fetchPosts() async {
        self.posts = await DataManager.shared.fetchPostsFromCloud()
    }
    
    // MARK: - 核心交互逻辑
    
    func handleAddButtonTap() {
        activePost = nil
        withAnimation { isSelectingMode = true }
        
        if let userLoc = LocationManager.shared.userLocation {
            withAnimation(.spring(duration: 1.0)) {
                cameraPosition = .region(
                    MKCoordinateRegion(center: userLoc, span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002))
                )
            }
        }
    }
    
    func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        if activePost != nil {
            withAnimation { activePost = nil }
            return
        }
        
        guard isSelectingMode else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation {
            selectedLocation = coordinate
            isShowingInputSheet = true
        }
    }
    
    // MARK: - 🔥 核心功能：发帖 (云端版)
    func submitPost() {
        guard let coord = selectedLocation else { return }
        
        // 1. 准备数据
        let currentTitle = inputTitle
        let currentCaption = inputCaption
        let currentCategory = inputCategory
        let imagesToUpload = selectedImages
        // 优先使用 Firebase 登录用户的 UID，没有则用本地 ID 兜底
        let authorID = Auth.auth().currentUser?.uid ?? currentUser.id
        
        // 2. 立即关闭 UI，给用户“发送中”的流畅感
        exitSelectionMode()
        
        // 3. 后台异步上传
        Task(priority: .userInitiated) {
            var uploadedURLs: [String] = []
            
            // A. 循环上传每一张图片到 Firebase Storage
            for image in imagesToUpload {
                if let url = await DataManager.shared.uploadImage(image) {
                    uploadedURLs.append(url)
                    print("📸 图片上传成功: \(url)")
                }
            }
            
            // B. 创建 Post 对象
            // 注意：imageFilenames 留空，数据存入 imageURLs
            let newPost = Post(
                authorID: authorID,
                title: currentTitle,
                caption: currentCaption,
                category: currentCategory,
                latitude: coord.latitude,
                longitude: coord.longitude,
                imageFilenames: [],          // 本地字段不再使用
                imageURLs: uploadedURLs,     // ✅ 填入云端 URL
                timestamp: Date(),
                rating: 0,
                likeCount: 0,
                isLiked: false
            )
            
            // C. 保存到 Firestore 数据库
            let success = await DataManager.shared.savePostToCloud(post: newPost)
            
            // D. 成功后更新本地列表
            if success {
                await MainActor.run {
                    self.posts.insert(newPost, at: 0) // 插入到顶部
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } else {
                print("❌ 发帖失败")
            }
        }
    }
    
    func cancelPost() { exitSelectionMode() }
    
    func exitSelectionMode() {
        withAnimation {
            isSelectingMode = false
            isShowingInputSheet = false
            selectedLocation = nil
            
            inputTitle = ""
            inputCaption = ""
            inputCategory = .food
            
            selectedImages = []
            imageSelections = []
            
            if let userLoc = LocationManager.shared.userLocation {
                cameraPosition = .region(MKCoordinateRegion(center: userLoc, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
            }
        }
    }
    
    func closePostDetail() {
        withAnimation { activePost = nil }
    }
    
    func jumpToPost(_ post: Post) {
        isSelectingMode = false
        isShowingInputSheet = false
        selectedLocation = nil
        
        withAnimation { self.activePost = post }
        
        withAnimation(.spring(duration: 1.5)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: post.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )
            )
        }
    }
    
    // MARK: - 辅助方法
    
    private func loadSelectedImages() {
        selectedImages = []
        guard !imageSelections.isEmpty else { return }
        
        Task {
            var loadedImages: [UIImage] = []
            for item in imageSelections {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    loadedImages.append(uiImage)
                }
            }
            await MainActor.run {
                self.selectedImages = loadedImages
            }
        }
    }
    
    func updateUserProfile(_ newProfile: UserProfile) {
        self.currentUser = newProfile
        DataManager.shared.saveUserProfile(currentUser)
    }
    
    func updateUserAvatar(_ image: UIImage) {
        // 目前头像还是本地保存，后续可以参考 uploadImage 改为上传
        let filename = DataManager.shared.saveImage(image, name: "avatar_\(UUID().uuidString)")
        var updatedProfile = currentUser
        updatedProfile.avatarFilename = filename
        updateUserProfile(updatedProfile)
    }
    
    // MARK: - 点赞与删除 (已适配云端)
    
    func toggleLike(for post: Post) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            // 1. 本地立即更新 UI
            posts[index].isLiked.toggle()
            if posts[index].isLiked {
                posts[index].likeCount += 1
            } else {
                posts[index].likeCount = max(0, posts[index].likeCount - 1)
            }
            
            // 同步更新当前详情页
            if activePost?.id == post.id {
                activePost = posts[index]
            }
            
            // 2. 异步保存单个帖子到云端
            Task {
                _ = await DataManager.shared.savePostToCloud(post: posts[index])
            }
        }
    }
    
    func deletePost(_ post: Post) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            // 1. 本地移除
            posts.remove(at: index)
            
            // 2. 如果正在看这个帖子，关闭详情
            if activePost?.id == post.id {
                closePostDetail()
            }
            
            // 3. 云端删除
            DataManager.shared.deletePostFromCloud(post: post)
            
            // 4. 反馈
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    func focusOnUserLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation(.spring(duration: 1.0)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        }
    }
}
