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
    
    // 4. 表单输入状态 (回溯到单图支持)
    var inputTitle = ""
    var inputCaption = ""
    var inputCategory: PostCategory = .food
    
    // ✅ 回溯：使用单图属性
    var selectedImage: UIImage?
    var imageSelection: PhotosPickerItem? {
        didSet { loadSelectedImage() }
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
        let imageToSave = selectedImage // 使用单图
        
        exitSelectionMode()
        
        Task(priority: .userInitiated) {
            var finalFilename: String? = nil
            
            // 1. 保存单个图片
            if let img = imageToSave {
                let uniqueName = UUID().uuidString
                finalFilename = DataManager.shared.saveImage(img, name: uniqueName)
            }
            
            // 2. 创建帖子数据
            let newPost = Post(
                latitude: coord.latitude,
                longitude: coord.longitude,
                title: currentTitle,
                caption: currentCaption,
                category: currentCategory,
                rating: 0,
                imageFilename: finalFilename // 使用单个文件名
            )
            
            // 3. 回到主线程更新 UI 数据
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
            
            // 清空单图表单
            inputTitle = ""
            inputCaption = ""
            inputCategory = .food
            selectedImage = nil
            imageSelection = nil
            
            // 恢复浏览视角
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
    private func loadSelectedImage() {
        selectedImage = nil
        guard let item = imageSelection else { return }
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                if let data = try? result.get(), let uiImage = UIImage(data: data) {
                    self.selectedImage = uiImage
                }
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
