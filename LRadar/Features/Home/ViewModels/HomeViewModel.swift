import SwiftUI
import MapKit

@Observable // iOS 17+ 的新写法，不需要继承 ObservableObject
class HomeViewModel {
    // 1. 默认地图视角 (伦敦)
    var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    
    // 2. 帖子数据
    var posts: [Post] = [
        Post(coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278), caption: "Hello London!", color: .purple, icon: "star.fill"),
        Post(coordinate: CLLocationCoordinate2D(latitude: 51.509, longitude: -0.126), caption: "Coffee Time", color: .orange, icon: "cup.and.saucer.fill")
    ]
    
    // 3. 交互状态
    var selectedLocation: CLLocationCoordinate2D?
    var isShowingInputSheet = false
    var inputText = ""
    
    // --- 逻辑 ---
    
    func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation {
            selectedLocation = coordinate
            isShowingInputSheet = true
        }
    }
    
    // 🚀 新增功能：把镜头聚焦到用户位置
    func focusOnUserLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation(.spring(duration: 1.0)) { // 加个弹簧动画更顺滑
            self.cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) // 0.01 大概是街道级缩放
                )
            )
        }
    }
    
    func submitPost() {
        guard let coord = selectedLocation else { return }
        let newPost = Post(coordinate: coord, caption: inputText, color: .pink, icon: "heart.fill")
        
        withAnimation {
            posts.append(newPost)
            cancelPost() // 提交后关闭
        }
    }
    
    func cancelPost() {
        withAnimation {
            isShowingInputSheet = false
            selectedLocation = nil
            inputText = ""
        }
    }
}
