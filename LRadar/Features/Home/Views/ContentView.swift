import SwiftUI
import MapKit

struct ContentView: View {
    @State private var viewModel = HomeViewModel()
    @ObservedObject var locationManager = LocationManager.shared
    
    // 记录是否已经完成首次居中
    @State private var hasInitialCentered = false
    
    var body: some View {
        ZStack {
            // --- 1. 地图层 ---
            MapReader { proxy in
                Map(position: $viewModel.cameraPosition) {
                    // 用户蓝点
                    UserAnnotation()
                    
                    // 帖子气泡
                    ForEach(viewModel.posts) { post in
                        Annotation("", coordinate: post.coordinate) {
                            PostAnnotationView(color: post.color, icon: post.icon)
                                .onTapGesture {
                                    print("点击了帖子: \(post.caption)")
                                }
                        }
                    }
                    
                    // 选点光标
                    if let tempLoc = viewModel.selectedLocation {
                        Annotation("New", coordinate: tempLoc) {
                            Circle().fill(.orange).frame(width: 16, height: 16)
                                .overlay(Circle().stroke(.white, lineWidth: 3))
                                .shadow(radius: 5)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .onTapGesture { position in
                    if let coordinate = proxy.convert(position, from: .local) {
                        viewModel.handleMapTap(at: coordinate)
                    }
                }
            }
            .ignoresSafeArea()
            
            // --- 2. 顶部 UI 层 (已删除标题，只保留按钮) ---
            VStack {
                HStack {
                    Spacer() // 把按钮推到最右边
                    
                    // 回到定位按钮
                    Button(action: {
                        if let userLoc = locationManager.userLocation {
                            viewModel.focusOnUserLocation(userLoc)
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .font(.title2)
                            .padding(12)
                            // 给按钮单独加个磨砂背景，而不是整条栏
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                }
                .padding(.top, 60) // 避开刘海屏
                .padding(.horizontal)
                
                Spacer() // 把上面内容顶到最上面
            }
            
            // --- 3. 底部弹窗 ---
            if viewModel.isShowingInputSheet {
                VStack {
                    Spacer()
                    PostInputCard(
                        text: $viewModel.inputText,
                        onCancel: { viewModel.cancelPost() },
                        onPost: { viewModel.submitPost() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(1)
            }
        }
        .onAppear {
            locationManager.requestPermission()
        }
        // 监听位置变化，首次自动居中
        .onChange(of: locationManager.userLocation) { oldLocation, newLocation in
            if !hasInitialCentered, let location = newLocation {
                viewModel.focusOnUserLocation(location)
                hasInitialCentered = true
            }
        }
    }
}

#Preview {
    ContentView()
}
