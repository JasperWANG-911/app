import SwiftUI
import MapKit
import PhotosUI
import FirebaseAuth
import FirebaseFirestore

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
    
    // 🔥 新增：用于管理实时监听器
    private var postsListener: ListenerRegistration?
    
    // 🔥 新增：本地记录“我点过赞的帖子ID”，防止云端数据覆盖本地状态
    // 我们只信任本地的 isLiked 状态，云端的 likeCount 仅作参考
    private var myLikedPostIDs: Set<String> = [] {
        didSet {
            // 每次变化都存入 UserDefaults
            let array = Array(myLikedPostIDs)
            UserDefaults.standard.set(array, forKey: "MyLikedPostIDs")
        }
    }
    
    // MARK: - 3. UI 交互状态
    var isSelectingMode = false
    var selectedLocation: CLLocationCoordinate2D?
    var isShowingInputSheet = false
    var activePost: Post? = nil
    
    // 表单输入状态
    var inputTitle = ""
    var inputCaption = ""
    var inputCategory: PostCategory = .food
    var inputRating: Int = 0 // 🔥 新增：评分输入 (0-5)
    
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
    
    // MARK: - 4. 计算属性
    
    // 动态获取当前登录的真实 UID
    var currentUserID: String {
        Auth.auth().currentUser?.uid ?? currentUser.id
    }
    
    var myDrops: [Post] {
        posts.filter { $0.authorID == currentUserID } // 👈 必须有这一行
            .sorted { $0.timestamp > $1.timestamp }
    }

    var myDropsCount: Int {
        myDrops.count
    }
    
    var myTotalLikes: Int {
        myDrops.reduce(0) { $0 + $1.likeCount }
    }

    // MARK: - 初始化与析构
    init() {
        // 1. 加载本地点赞记录
        if let savedIDs = UserDefaults.standard.array(forKey: "MyLikedPostIDs") as? [String] {
            self.myLikedPostIDs = Set(savedIDs)
        }
        
        // 2. 加载本地缓存的用户资料
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
        
        // 3. 启动实时监听 (替代原来的 fetchPosts)
        startListeningToPosts()
        
        // 4. 刷新用户资料
        Task {
            await refreshCurrentUser()
        }
    }
    
    deinit {
        postsListener?.remove()
    }
    
    // MARK: - 🔥 核心功能：实时监听
    func startListeningToPosts() {
        // 移除旧监听
        postsListener?.remove()
        
        // 开启新监听
        postsListener = DataManager.shared.listenToPosts { [weak self] cloudPosts in
            guard let self = self else { return }
            
            // ⚡️ 合并逻辑：信任云端的内容(标题、图片、点赞数)，但只信任本地的 isLiked 状态
            let mergedPosts = cloudPosts.map { post -> Post in
                var newPost = post
                // 强制用本地记录覆盖云端的 isLiked
                newPost.isLiked = self.myLikedPostIDs.contains(post.id.uuidString)
                return newPost
            }
            
            DispatchQueue.main.async {
                self.posts = mergedPosts.filter { !$0.authorID.isEmpty }
                
                // 如果当前打开了详情页，也要实时更新详情页里的数据 (比如点赞数变了)
                if let activeID = self.activePost?.id,
                   let updatedActivePost = self.posts.first(where: { $0.id == activeID }) {
                    self.activePost = updatedActivePost
                }
            }
        }
    }
    
    // 🔥 刷新当前用户信息
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
    
    // MARK: - 🔥 核心功能：发帖 (并行上传 + 评分)
    func submitPost() {
        guard let coord = selectedLocation else { return }
        
        // 暂存状态
        let currentTitle = inputTitle
        let currentCaption = inputCaption
        let currentCategory = inputCategory
        let currentRating = Double(inputRating) // 🔥 获取评分
        let imagesToUpload = selectedImages
        let authorID = self.currentUserID
        
        exitSelectionMode()
        
        Task(priority: .userInitiated) {
            // --- 并行上传图片 ---
            let uploadedURLs = await withTaskGroup(of: String?.self) { group -> [String] in
                for image in imagesToUpload {
                    group.addTask {
                        return await DataManager.shared.uploadImage(image)
                    }
                }
                
                var urls: [String] = []
                for await url in group {
                    if let url = url { urls.append(url) }
                }
                return urls
            }
            
            // 构建帖子
            let newPost = Post(
                authorID: authorID,
                title: currentTitle,
                caption: currentCaption,
                category: currentCategory,
                latitude: coord.latitude,
                longitude: coord.longitude,
                imageFilenames: [], // 废弃
                imageURLs: uploadedURLs,
                timestamp: Date(),
                rating: currentRating, // 🔥 写入评分
                likeCount: 0,
                isLiked: false
            )
            
            // 写入数据库
            let success = await DataManager.shared.savePostToCloud(post: newPost)
            
            if success {
                await MainActor.run {
                    // 本地虽然有监听，但可以先手动插一条，让反馈更快
                    // (监听器稍后会覆盖它，也没关系)
                    if !self.posts.contains(where: { $0.id == newPost.id }) {
                         self.posts.insert(newPost, at: 0)
                    }
                    
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
            
            // 重置表单
            inputTitle = ""
            inputCaption = ""
            inputCategory = .food
            inputRating = 0 // 🔥 重置评分
            
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
        
        print("Jumping to post: \(post.id)")
        
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
        DataManager.shared.saveUserProfileToCloud(profile: newProfile)
    }
    
    func updateUserAvatar(_ image: UIImage) {
        Task(priority: .userInitiated) {
            if let url = await DataManager.shared.uploadImage(image, folder: "avatars") {
                await MainActor.run {
                    var updatedProfile = currentUser
                    updatedProfile.avatarURL = url
                    updateUserProfile(updatedProfile)
                }
            }
        }
    }
    
    // MARK: - 点赞与删除
    
    func toggleLike(for post: Post) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        
        // 1. 切换本地状态
        let isNowLiked = !posts[index].isLiked
        posts[index].isLiked = isNowLiked
        
        // 2. 更新本地记录 (Truth Source)
        if isNowLiked {
            myLikedPostIDs.insert(post.id.uuidString)
            posts[index].likeCount += 1
        } else {
            myLikedPostIDs.remove(post.id.uuidString)
            posts[index].likeCount = max(0, posts[index].likeCount - 1)
        }
        
        // 3. 同步 UI (如果正在查看详情)
        if activePost?.id == post.id {
            activePost = posts[index]
        }
        
        // 4. 发送请求给云端 (只更新数字)
        let postToSave = posts[index]
        Task {
            // DataManager 的 savePostToCloud 会直接覆盖整个文档
            // 更好的做法是使用 FieldValue.increment，但为了兼容现有架构，暂时这样写
            // 由于其他客户端只读 myLikedPostIDs，所以这里把 isLiked=true/false 传上去也不会影响别人
            _ = await DataManager.shared.savePostToCloud(post: postToSave)
        }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
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
