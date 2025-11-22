import SwiftUI
import MapKit

struct ContentView: View {
    @State private var viewModel = HomeViewModel()
    @ObservedObject var locationManager = LocationManager.shared
    
    @State private var currentTab: Tab = .map
    @State private var hasInitialCentered = false
    
    // 用于控制地图原生的选中状态
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
                        selectedPostID = nil
                    }
                    .transition(.opacity)
                
                VStack {
                    Spacer()
                    PostDetailCard(
                        post: post,
                        onDismiss: {
                            viewModel.closePostDetail()
                            selectedPostID = nil
                        },
                        onLike: { viewModel.toggleLike(for: post) },
                        onDelete: { viewModel.deletePost(post) },
                        // 🔥 修复点：这里现在接收两个参数 (type, details)
                        onReport: { type, details in
                            // 将两个参数合并成一个字符串传给 ViewModel
                            let fullReason = "[\(type)] \(details)"
                            viewModel.reportPost(post, reason: fullReason)
                        }
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
        // 监听选中状态的变化
        .onChange(of: selectedPostID) { oldValue, newValue in
            if let id = newValue, let post = viewModel.posts.first(where: { $0.id == id }) {
                viewModel.jumpToPost(post)
            } else {
                viewModel.closePostDetail()
            }
        }
        // 反向同步
        .onChange(of: viewModel.activePost) { oldValue, newValue in
            if newValue == nil {
                selectedPostID = nil
            }
        }
        // 🔥 绑定 Filter 弹窗
        .sheet(isPresented: $viewModel.showFilterSheet) {
            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                Text("Filter Options").font(.title2).bold()
                Text("Categories, Time, Distance, etc.").foregroundStyle(.gray)
                Spacer()
            }
            .presentationDetents([.medium])
            .presentationCornerRadius(24)
        }
    }
    
    // --- 抽离的地图组件 ---
    var mapView: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $viewModel.cameraPosition, selection: $selectedPostID) {
                    UserAnnotation()
                    
                    if let userLoc = locationManager.userLocation {
                        MapCircle(center: userLoc, radius: 100)
                            .foregroundStyle(Color.purple.opacity(0.15))
                            .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                    }
                    
                    ForEach(viewModel.posts) { post in
                        Annotation("", coordinate: post.coordinate, anchor: .bottom) {
                            PostAnnotationView(color: post.color, icon: post.icon)
                        }
                        .tag(post.id)
                    }
                    
                    if let tempLoc = viewModel.selectedLocation {
                        Annotation("New", coordinate: tempLoc) {
                            Circle().fill(.orange).frame(width: 16, height: 16).overlay(Circle().stroke(.white, lineWidth: 3)).shadow(radius: 5)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .onTapGesture { position in
                    guard viewModel.isSelectingMode else { return }
                    
                    if let coordinate = proxy.convert(position, from: .local) {
                        viewModel.handleMapTap(at: coordinate)
                    }
                }
            }
            .ignoresSafeArea()
            
            // 右上角悬浮按钮组 (Notification & Filter)
            if !viewModel.isSelectingMode {
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            // Notification 按钮
                            Button(action: {
                                withAnimation { viewModel.hasUnreadNotifications = false }
                            }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell.fill")
                                        .font(.title2).foregroundStyle(.primary)
                                        .padding(12).background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                    
                                    if viewModel.hasUnreadNotifications {
                                        Circle().fill(.red).frame(width: 10, height: 10)
                                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                    }
                                }
                            }
                            
                            // Filter 按钮
                            Button(action: { viewModel.showFilterSheet = true }) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title2).foregroundStyle(.primary)
                                    .padding(12).background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 60)
                    }
                    Spacer()
                }
            }
            
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
