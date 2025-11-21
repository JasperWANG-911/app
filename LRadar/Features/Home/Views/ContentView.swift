import SwiftUI
import MapKit

struct ContentView: View {
    @State private var viewModel = HomeViewModel()
    @ObservedObject var locationManager = LocationManager.shared
    
    // 确保 Tab 枚举在 CustomTabBar.swift 中定义且可见
    @State private var currentTab: Tab = .map
    @State private var hasInitialCentered = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // --- 1. 页面内容区域 (负责切换 Map, Friends, Profile) ---
            Group {
                switch currentTab {
                case .map:
                    mapView
                case .friends:
                    FriendsView() // 使用 SideViews.swift 里定义的 FriendsView
                case .profile:
                    // 传入 ProfileView 的数据
                    ProfileView(viewModel: viewModel, currentTab: $currentTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 动态调整底部边距
            .padding(.bottom, viewModel.isShowingInputSheet || viewModel.activePost != nil ? 0 : 60)
            
            // --- 2. 底部导航栏 (CustomTabBar) ---
            // 逻辑：只有在无任何浮层弹窗时才显示 TabBar
            if !viewModel.isShowingInputSheet && viewModel.activePost == nil {
                // 如果不处于选点模式，显示 TabBar。否则显示取消按钮（逻辑在下面）
                if !viewModel.isSelectingMode {
                    CustomTabBar(
                        currentTab: $currentTab,
                        onAddTap: { viewModel.handleAddButtonTap() }
                    )
                    .transition(.move(edge: .bottom))
                }
            }
            
            // --- 3. 选点模式下的“取消”按钮 ---
            if viewModel.isSelectingMode && !viewModel.isShowingInputSheet {
                Button(action: { viewModel.exitSelectionMode() }) {
                    Image(systemName: "xmark").font(.title).bold().foregroundStyle(.white)
                        .padding().background(Circle().fill(.black.opacity(0.6)))
                }
                .padding(.bottom, 40).transition(.scale).zIndex(10)
            }
            
            // --- 4. 发帖弹窗 (Post Input) ---
            if viewModel.isShowingInputSheet {
                Color.black.opacity(0.3).ignoresSafeArea().onTapGesture { viewModel.cancelPost() }.transition(.opacity)
                
                VStack {
                    Spacer()
                    PostInputCard(viewModel: viewModel)
                        .transition(.move(edge: .bottom))
                }
                .zIndex(100)
            }
            
            // --- 5. 帖子详情弹窗 (Post Detail) ---
            // ⚠️ 关键修改：连接了点赞和删除功能
            if let post = viewModel.activePost {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { viewModel.closePostDetail() }
                    .transition(.opacity)
                
                VStack {
                    Spacer()
                    PostDetailCard(
                        post: post,
                        onDismiss: { viewModel.closePostDetail() },
                        onLike: { viewModel.toggleLike(for: post) },    // ✅ 连接 ViewModel 的点赞逻辑
                        onDelete: { viewModel.deletePost(post) }        // ✅ 连接 ViewModel 的删除逻辑
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(101)
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear { locationManager.requestPermission() }
        .onChange(of: locationManager.userLocation) { oldLocation, newLocation in
            guard let location = newLocation else { return }
            
            if !hasInitialCentered {
                viewModel.focusOnUserLocation(location)
                hasInitialCentered = true
            }
            
            if viewModel.isSelectingMode {
                withAnimation(.linear(duration: 0.5)) {
                    viewModel.cameraPosition = .region(MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)))
                }
            }
        }
    }
    
    // --- 抽离的地图组件 ---
    var mapView: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $viewModel.cameraPosition) {
                    // 1. 用户当前位置
                    UserAnnotation()
                    
                    if let userLoc = locationManager.userLocation {
                        MapCircle(center: userLoc, radius: 100)
                            .foregroundStyle(Color.purple.opacity(0.15))
                            .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                    }
                    
                    // 2. 帖子气泡 (这就是你要添加逻辑的地方)
                    ForEach(viewModel.posts) { post in
                        // ⚠️ 修改点：添加 anchor: .bottom
                        Annotation("", coordinate: post.coordinate, anchor: .bottom) {
                            PostAnnotationView(color: post.color, icon: post.icon)
                                .onTapGesture {
                                    viewModel.jumpToPost(post)
                                }
                        }
                    }
                    
                    // 3. 正在选点时的临时气泡
                    if let tempLoc = viewModel.selectedLocation {
                        Annotation("New", coordinate: tempLoc) {
                            Circle().fill(.orange).frame(width: 16, height: 16).overlay(Circle().stroke(.white, lineWidth: 3)).shadow(radius: 5)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                // ... 地图背景点击逻辑保持不变 ...
                .onTapGesture { position in
                    if let coordinate = proxy.convert(position, from: .local) {
                        viewModel.handleMapTap(at: coordinate)
                    }
                }
            }
            .ignoresSafeArea()
            
            // 右下角定位按钮
            if !viewModel.isSelectingMode {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            if let userLoc = locationManager.userLocation {
                                viewModel.focusOnUserLocation(userLoc)
                            }
                        }) {
                            Image(systemName: "location.fill").font(.title2).padding(12)
                                .background(.ultraThinMaterial).clipShape(Circle()).shadow(radius: 4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, viewModel.activePost != nil ? 300 : 40)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
