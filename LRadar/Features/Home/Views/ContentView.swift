import SwiftUI
import MapKit

struct ContentView: View {
    @State private var viewModel = HomeViewModel()
    @ObservedObject var locationManager = LocationManager.shared
    
    @State private var currentTab: Tab = .map
    @State private var hasInitialCentered = false
    
    // 🔥 1. 新增：用于控制地图原生的选中状态
    @State private var selectedPostID: UUID?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // --- 1. 页面内容区域 ---
            Group {
                switch currentTab {
                case .map:
                    mapView
                case .friends:
                    FriendsView()
                case .profile:
                    ProfileView(viewModel: viewModel, currentTab: $currentTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, viewModel.isShowingInputSheet || viewModel.activePost != nil ? 0 : 60)
            
            // --- 2. 底部导航栏 ---
            if !viewModel.isShowingInputSheet && viewModel.activePost == nil {
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
            
            // --- 4. 发帖弹窗 ---
            if viewModel.isShowingInputSheet {
                Color.black.opacity(0.3).ignoresSafeArea().onTapGesture { viewModel.cancelPost() }.transition(.opacity)
                
                VStack {
                    Spacer()
                    PostInputCard(viewModel: viewModel)
                        .transition(.move(edge: .bottom))
                }
                .zIndex(100)
            }
            
            // --- 5. 帖子详情弹窗 ---
            if let post = viewModel.activePost {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture {
                        viewModel.closePostDetail()
                        selectedPostID = nil // 🔥 关闭时记得同步清空选中状态
                    }
                    .transition(.opacity)
                
                VStack {
                    Spacer()
                    PostDetailCard(
                        post: post,
                        onDismiss: {
                            viewModel.closePostDetail()
                            selectedPostID = nil // 🔥
                        },
                        onLike: { viewModel.toggleLike(for: post) },
                        onDelete: { viewModel.deletePost(post) }
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
        }
        // 🔥 核心修复：监听选中状态的变化
        // 当 selectedPostID 变化时（用户点了气泡），自动通知 ViewModel 打开详情
        .onChange(of: selectedPostID) { oldValue, newValue in
            if let id = newValue, let post = viewModel.posts.first(where: { $0.id == id }) {
                // 点到了气泡 -> 跳转
                viewModel.jumpToPost(post)
            } else {
                // 点到了空白处 (newValue 为 nil) -> 关闭详情
                viewModel.closePostDetail()
            }
        }
        // 反向同步：如果 ViewModel 里的 activePost 被清空了（比如切 Tab 了），也要把地图选中态清空
        .onChange(of: viewModel.activePost) { oldValue, newValue in
            if newValue == nil {
                selectedPostID = nil
            }
        }
    }
    
    // --- 抽离的地图组件 ---
    var mapView: some View {
        ZStack {
            MapReader { proxy in
                // 🔥 2. 修改 Map 初始化：绑定 selection
                Map(position: $viewModel.cameraPosition, selection: $selectedPostID) {
                    
                    UserAnnotation()
                    
                    if let userLoc = locationManager.userLocation {
                        MapCircle(center: userLoc, radius: 100)
                            .foregroundStyle(Color.purple.opacity(0.15))
                            .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                    }
                    
                    // 🔥 3. 修改气泡逻辑
                    ForEach(viewModel.posts) { post in
                        // 去掉了原来的 .onTapGesture，改用 .tag
                        Annotation("", coordinate: post.coordinate, anchor: .bottom) {
                            PostAnnotationView(color: post.color, icon: post.icon)
                            // ⚠️ 注意：这里不要加 onTapGesture 了！
                        }
                        .tag(post.id) // 🔑 关键：给气泡打上标签，Map 就会自动处理点击选中
                    }
                    
                    if let tempLoc = viewModel.selectedLocation {
                        Annotation("New", coordinate: tempLoc) {
                            Circle().fill(.orange).frame(width: 16, height: 16).overlay(Circle().stroke(.white, lineWidth: 3)).shadow(radius: 5)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                // 🔥 4. 限制背景点击逻辑：只有在“选点模式”下才允许背景点击
                // 这样平时浏览时，背景点击完全交给 Map 原生处理（用于取消选中），不会和气泡冲突
                .onTapGesture { position in
                    guard viewModel.isSelectingMode else { return } // 👈 加上这个卫语句
                    
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
