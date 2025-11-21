import SwiftUI
import MapKit
import PhotosUI
import FirebaseAuth // 🔥 必须引入

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
    
    // 🔥 核心修复：确保筛选 ID 的一致性
    // 使用计算属性动态获取当前登录的真实 UID，而不是依赖可能过期的 currentUser.id
    var currentUserID: String {
        Auth.auth().currentUser?.uid ?? currentUser.id
    }
    
    var myDrops: [Post] {
        // 过滤出 authorID 等于当前真实 UID 的帖子
        posts.filter { $0.authorID == currentUserID }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var myDropsCount: Int {
        myDrops.count
    }
    
    var myTotalLikes: Int {
        myDrops.reduce(0) { $0 + $1.likeCount }
    }

    
    // MARK: - 初始化
    init() {
        // 1. 加载本地用户资料作为缓存
        if let savedProfile = DataManager.shared.loadUserProfile() {
            self.currentUser = savedProfile
        } else {
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
        
        // 2. 启动时异步拉取云端数据
        Task {
            await fetchPosts()
            await refreshCurrentUser() // 🔥 新增：确保用户信息也是最新的
        }
    }
    
    @MainActor
    func fetchPosts() async {
        // 拉取并过滤掉可能的坏数据
        let cloudPosts = await DataManager.shared.fetchPostsFromCloud()
        self.posts = cloudPosts.filter { !$0.authorID.isEmpty } // 简单过滤
    }
    
    // 🔥 新增：刷新当前用户信息
    @MainActor
    func refreshCurrentUser() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if let profile = await DataManager.shared.fetchUserProfileFromCloud(userId: uid) {
            self.currentUser = profile
            DataManager.shared.saveUserProfile(profile) // 更新本地缓存
        }
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
    
    // MARK: - 🔥 核心功能：发帖
    func submitPost() {
        guard let coord = selectedLocation else { return }
        
        let currentTitle = inputTitle
        let currentCaption = inputCaption
        let currentCategory = inputCategory
        let imagesToUpload = selectedImages
        
        // 🔥 关键：使用统一的 currentUserID
        let authorID = self.currentUserID
        
        exitSelectionMode()
        
        Task(priority: .userInitiated) {
            var uploadedURLs: [String] = []
            
            for image in imagesToUpload {
                if let url = await DataManager.shared.uploadImage(image) {
                    uploadedURLs.append(url)
                }
            }
            
            let newPost = Post(
                authorID: authorID, // 确保 ID 一致
                title: currentTitle,
                caption: currentCaption,
                category: currentCategory,
                latitude: coord.latitude,
                longitude: coord.longitude,
                imageFilenames: [],
                imageURLs: uploadedURLs,
                timestamp: Date(),
                rating: 0,
                likeCount: 0,
                isLiked: false
            )
            
            let success = await DataManager.shared.savePostToCloud(post: newPost)
            
            if success {
                await MainActor.run {
                    self.posts.insert(newPost, at: 0)
                    // 强制更新一下 currentUser 的 ID，防止极端情况下 ID 不一致
                    if self.currentUser.id != authorID {
                        self.currentUser.id = authorID
                    }
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
        
        // 打印一下 ID，方便调试
        print("Jumping to post: \(post.id), Author: \(post.authorID)")
        
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
        // 🔥 同步保存到云端
        DataManager.shared.saveUserProfileToCloud(profile: newProfile)
    }
    
    func updateUserAvatar(_ image: UIImage) {
            Task(priority: .userInitiated) {
                // 🔥 修改点：指定 folder 为 "avatars"
                if let url = await DataManager.shared.uploadImage(image, folder: "avatars") {
                    await MainActor.run {
                        var updatedProfile = currentUser
                        updatedProfile.avatarURL = url
                        updateUserProfile(updatedProfile)
                        print("头像已上传到 avatars 文件夹: \(url)")
                    }
                } else {
                    print("头像上传失败")
                }
            }
        }
    
    // MARK: - 点赞与删除
    
    func toggleLike(for post: Post) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].isLiked.toggle()
            if posts[index].isLiked {
                posts[index].likeCount += 1
            } else {
                posts[index].likeCount = max(0, posts[index].likeCount - 1)
            }
            
            if activePost?.id == post.id {
                activePost = posts[index]
            }
            
            Task {
                _ = await DataManager.shared.savePostToCloud(post: posts[index])
            }
        }
    }
    
    func deletePost(_ post: Post) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts.remove(at: index)
            
            if activePost?.id == post.id {
                closePostDetail()
            }
            
            DataManager.shared.deletePostFromCloud(post: post)
            
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
