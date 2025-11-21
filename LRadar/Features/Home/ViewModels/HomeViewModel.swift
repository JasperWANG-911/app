import SwiftUI
import MapKit
import PhotosUI

@Observable
class HomeViewModel {
    // 1. 地图相机位置 (决定地图的中心点和缩放级别)
    var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
    )
    
    // 2. 数据源
    var posts: [Post] = []
    var currentUser: UserProfile
    
    // 3. UI 交互状态
    var isSelectingMode = false
    var selectedLocation: CLLocationCoordinate2D?
    var isShowingInputSheet = false
    var activePost: Post? = nil
    
    // 表单输入状态
    var inputTitle = ""
    var inputCaption = ""
    var inputCategory: PostCategory = .food
    
    // ⚠️ 修改点：支持多图选择
    var selectedImages: [UIImage] = []
    var imageSelections: [PhotosPickerItem] = [] {
        didSet {
            loadSelectedImages()
        }
    }
    
    // 5. UI 反馈
    var showToast = false
    var toastMessage = ""
    
    // --- 初始化：加载本地数据 ---
    init() {
        if let savedProfile = DataManager.shared.loadUserProfile() {
            self.currentUser = savedProfile
        } else {
            self.currentUser = UserProfile(
                name: "New User",
                handle: "@new_user",
                school: "UCL",
                major: "Undeclared",
                bio: "Write something about yourself...",
                rating: 5.0,
                avatarFilename: nil
            )
        }
        self.posts = DataManager.shared.loadPosts()
    }
    
    // --- 核心逻辑 ---
    
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
    
    // 提交发布 (回溯到单图保存)
    func submitPost() {
            guard let coord = selectedLocation else { return }
            
            let currentTitle = inputTitle
            let currentCaption = inputCaption
            let currentCategory = inputCategory
            let imagesToSave = selectedImages // 获取当前选中的所有图片
            
            exitSelectionMode()
            
            Task(priority: .userInitiated) {
                var savedFilenames: [String] = []
                
                // 循环保存每一张图片
                for img in imagesToSave {
                    let uniqueName = UUID().uuidString
                    if let savedName = DataManager.shared.saveImage(img, name: uniqueName) {
                        savedFilenames.append(savedName)
                    }
                }
                
                // 创建帖子
                let newPost = Post(
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    title: currentTitle,
                    caption: currentCaption,
                    category: currentCategory,
                    rating: 0,
                    imageFilenames: savedFilenames // 存入数组
                )
                
                await MainActor.run {
                    self.posts.append(newPost)
                    DataManager.shared.savePosts(self.posts)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            }
    }
    
    func cancelPost() { exitSelectionMode() }
    
    // 退出选点模式 & 重置表单
    func exitSelectionMode() {
            withAnimation {
                isSelectingMode = false
                isShowingInputSheet = false
                selectedLocation = nil
                
                inputTitle = ""
                inputCaption = ""
                inputCategory = .food
                
                selectedImages = []     // 清空图片
                imageSelections = []    // 清空选择器
                
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
    
    // --- 辅助方法 (回溯到单图加载) ---
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
        let filename = DataManager.shared.saveImage(image, name: "avatar_\(UUID().uuidString)")
        
        var updatedProfile = currentUser
        updatedProfile.avatarFilename = filename
        updateUserProfile(updatedProfile)
    }
    
    func toggleLike(for post: Post) {
            // 在数组中找到对应的帖子索引
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                // 切换点赞状态
                posts[index].isLiked.toggle()
                // 更新数字
                if posts[index].isLiked {
                    posts[index].likeCount += 1
                } else {
                    posts[index].likeCount = max(0, posts[index].likeCount - 1)
                }
                
                // 如果当前正在查看这张卡片，也需要同步更新 activePost，否则 UI 不会立即变化
                if activePost?.id == post.id {
                    activePost = posts[index]
                }
                
                // 保存到本地
                DataManager.shared.savePosts(posts)
            }
        }
        
    func deletePost(_ post: Post) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            // 1. 从数组移除
            posts.remove(at: index)
            
            // 2. 如果当前正在看这个帖子，关闭详情页
            if activePost?.id == post.id {
                closePostDetail()
            }
            
            // 3. 保存更新后的数组
            DataManager.shared.savePosts(posts)
            
            // 4. 反馈震动
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
