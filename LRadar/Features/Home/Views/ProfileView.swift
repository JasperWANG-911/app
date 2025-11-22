import SwiftUI
import FirebaseAuth

// MARK: - 枚举：内容选项卡
enum ProfileContentTab {
    case drops
    case saved
}

// MARK: - 主视图
struct ProfileView: View {
    var viewModel: HomeViewModel
    @Binding var currentTab: Tab
    
    @AppStorage("isUserLoggedIn") private var isUserLoggedIn: Bool = false
    
    // 状态控制
    @State private var isShowingEdit = false
    @State private var isShowingShare = false
    @State private var isShowingReputationDetail = false
    @State private var showSettings = false
    
    // 控制跳转到 "全部动态" 列表
    @State private var showAllDrops = false
    
    // 控制当前展示的内容 (Drops 还是 Saved)
    @State private var selectedContent: ProfileContentTab = .drops
    
    // 冻结排序 ID (用于 My Top Drops)
    @State private var frozenTopIDs: [UUID] = []
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. 头部身份卡片
                    ProfileHeaderView(
                        user: viewModel.currentUser,
                        onEditTap: { isShowingEdit = true },
                        onShareTap: { isShowingShare = true },
                        onReputationTap: { isShowingReputationDetail = true }
                    )
                    
                    // 2. 数据统计栏 (点击切换 Tabs)
                    ProfileStatsView(
                        postsCount: viewModel.myDropsCount,
                        savedCount: viewModel.myBookmarkedPosts.count,
                        selectedTab: $selectedContent
                    )
                    
                    Divider().padding(.horizontal)
                    
                    // 3. 内容展示区域 (根据 Tab 切换)
                    VStack(alignment: .leading, spacing: 16) {
                        
                        if selectedContent == .drops {
                            // ========= A. My Drops 模式 (恢复 Top Drops 逻辑) =========
                            
                            // 标题栏 + See All 按钮
                            HStack {
                                Text("My Top Drops")
                                    .font(.headline).foregroundStyle(.black)
                                
                                Spacer()
                                
                                // 点击跳转到完整列表
                                Button(action: { showAllDrops = true }) {
                                    HStack(spacing: 4) {
                                        Text("See All").font(.subheadline)
                                        Image(systemName: "chevron.right").font(.caption)
                                    }
                                    .foregroundStyle(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
                            
                            // Top Drops 网格 (只显示前 6 个)
                            if frozenTopIDs.isEmpty {
                                EmptyStateView(message: "No drops yet")
                            } else {
                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(frozenTopIDs, id: \.self) { id in
                                        if let post = viewModel.myDrops.first(where: { $0.id == id }) {
                                            Button(action: {
                                                viewModel.jumpToPost(post)
                                                currentTab = .map
                                            }) {
                                                SimplePostGridItem(post: post)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            
                        } else {
                            // ========= B. Collection 模式 (显示所有收藏) =========
                            
                            // 标题栏 (收藏一般不需要 See All，直接显示全部即可)
                            HStack {
                                Text("Collection")
                                    .font(.headline).foregroundStyle(.black)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            // Collection 网格
                            let savedPosts = viewModel.myBookmarkedPosts
                            
                            if savedPosts.isEmpty {
                                EmptyStateView(message: "No saved items yet")
                            } else {
                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(savedPosts) { post in
                                        Button(action: {
                                            viewModel.jumpToPost(post)
                                            currentTab = .map
                                        }) {
                                            // 使用增强版网格 (带作者头像)
                                            CollectedPostGridItem(post: post)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.black)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            // 跳转：点击 See All 去完整列表
            .navigationDestination(isPresented: $showAllDrops) {
                MyDropsListView(viewModel: viewModel, currentTab: $currentTab)
            }
            // 跳转：设置页
            .navigationDestination(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel, isUserLoggedIn: $isUserLoggedIn)
            }
            // 弹窗：编辑资料
            .sheet(isPresented: $isShowingEdit) {
                EditProfileView(profileCopy: viewModel.currentUser, onSave: { updatedProfile, newImage in
                    viewModel.updateUserProfile(updatedProfile)
                    if let img = newImage { viewModel.updateUserAvatar(img) }
                })
            }
            // 弹窗：分享
            .sheet(isPresented: $isShowingShare) {
                ShareSheet(items: ["Check out \(viewModel.currentUser.name)'s profile on LRadar!"])
                    .presentationDetents([.medium])
            }
            // 弹窗：声望详情
            .sheet(isPresented: $isShowingReputationDetail) {
                ReputationBreakdownView(user: viewModel.currentUser, totalLikesReceived: viewModel.myTotalLikes)
                    .presentationDetents([.height(450)])
                    .presentationCornerRadius(24)
            }
            // 生命周期：计算 Top Drops
            .onAppear { refreshTopDropsOrder() }
            .onChange(of: viewModel.myDrops.isEmpty) { _, isEmpty in
                if !isEmpty && frozenTopIDs.isEmpty { refreshTopDropsOrder() }
            }
        }
    }
    
    // 重新计算 Top Drops (逻辑：先按赞数，再按时间，取前6)
    private func refreshTopDropsOrder() {
        let sorted = viewModel.myDrops.sorted {
            if $0.likeCount != $1.likeCount {
                return $0.likeCount > $1.likeCount
            } else {
                return $0.timestamp > $1.timestamp
            }
        }
        frozenTopIDs = sorted.prefix(6).map { $0.id }
    }
}

// MARK: - 子组件 (保持不变，但也放这里方便你直接复制)

struct ProfileHeaderView: View {
    var user: UserProfile
    var onEditTap: () -> Void
    var onShareTap: () -> Void
    var onReputationTap: () -> Void
    
    var formattedHandle: String {
        let raw = user.handle.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.hasPrefix("@") ? raw : "@\(raw)"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: onEditTap) {
                ZStack(alignment: .bottomTrailing) {
                    if let avatarURL = user.avatarURL, let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else { Color.gray.opacity(0.1) }
                        }
                        .frame(width: 96, height: 96).clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    } else if let filename = user.avatarFilename,
                              let image = DataManager.shared.loadImage(filename: filename) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: 96, height: 96).clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().foregroundStyle(Color(UIColor.secondarySystemBackground))
                            .frame(width: 96, height: 96).clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    }
                    
                    Button(action: onReputationTap) {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill").font(.caption2).foregroundStyle(.yellow)
                            Text("\(user.reputation)").font(.caption).bold().foregroundStyle(.white).monospacedDigit()
                            Text("• \(user.rankTitle)").font(.caption2).bold().foregroundStyle(.white.opacity(0.9))
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.gray)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(.black))
                        .overlay(Capsule().stroke(Color.white, lineWidth: 2))
                    }
                    .offset(x: 20, y: 5)
                }
            }.buttonStyle(.plain)
            
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(user.name).font(.title2).bold().foregroundStyle(.black)
                    Text(formattedHandle).font(.subheadline).foregroundStyle(.gray)
                }
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "graduationcap.fill").font(.caption).foregroundStyle(.purple)
                        Text(user.school).font(.subheadline).fontWeight(.medium).foregroundStyle(.primary)
                    }
                    if !user.major.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill").font(.caption).foregroundStyle(.gray)
                            Text(user.major).font(.subheadline).foregroundStyle(.gray)
                        }
                    }
                }
                .padding(.top, 2)
                
                Text(user.bio).font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40).padding(.top, 4)
            }
            
            HStack(spacing: 12) {
                Button(action: onEditTap) {
                    Text("Edit Profile").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground)).foregroundStyle(.black).cornerRadius(8)
                }
                Button(action: onShareTap) {
                    Text("Share").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground)).foregroundStyle(.black).cornerRadius(8)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 10)
    }
}

struct ProfileStatsView: View {
    let postsCount: Int
    let savedCount: Int
    @Binding var selectedTab: ProfileContentTab
    
    var body: some View {
        HStack(spacing: 0) {
            // 1. Drops
            Button(action: { withAnimation { selectedTab = .drops } }) {
                StatUnit(
                    value: "\(postsCount)",
                    title: "Drops",
                    isActive: selectedTab == .drops
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().frame(height: 24)
            
            // 2. Saved
            Button(action: { withAnimation { selectedTab = .saved } }) {
                StatUnit(
                    value: "\(savedCount)",
                    title: "Saved",
                    isActive: selectedTab == .saved
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Divider().frame(height: 24)
            
            // 3. Friends
            StatUnit(value: "0", title: "Friends", isActive: false)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
    }
}

struct ReputationBreakdownView: View {
    var user: UserProfile
    var totalLikesReceived: Int
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Reputation Status").font(.headline).padding(.top, 20)
            
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.1)).frame(width: 80, height: 80)
                    Image(systemName: "trophy.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.yellow.gradient)
                }
                Text(user.rankTitle).font(.title).bold().foregroundStyle(.primary)
                Text("\(user.reputation) Points").font(.title3).monospacedDigit().foregroundStyle(.secondary)
            }
            
            HStack(spacing: 20) {
                HStack {
                    Image(systemName: "heart.fill").foregroundStyle(.red)
                    Text("\(totalLikesReceived) Likes Received")
                        .font(.subheadline).bold()
                }
                .padding(.vertical, 8).padding(.horizontal, 16)
                .background(Color(UIColor.secondarySystemBackground)).cornerRadius(12)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("How to earn points?").font(.headline)
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("Post a new Drop").bold()
                        Text("+10 pts").font(.caption).foregroundStyle(.gray)
                    }
                }
                HStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill").font(.title2).foregroundStyle(.red)
                    VStack(alignment: .leading) {
                        Text("Get a Like").bold()
                        Text("+2 pts").font(.caption).foregroundStyle(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
}

struct SimplePostGridItem: View {
    let post: Post
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let urlString = post.imageURLs.first, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.1) }
                } else if let filename = post.imageFilenames.first, let image = DataManager.shared.loadImage(filename: filename) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Rectangle().fill(Color(post.color).gradient)
                        .overlay(Image(systemName: post.icon).font(.title2).foregroundStyle(.white.opacity(0.8)))
                }
            }
            .frame(width: (UIScreen.main.bounds.width - 4) / 3, height: (UIScreen.main.bounds.width - 4) / 3)
            .clipped()
            .contentShape(Rectangle())
            
            HStack(spacing: 2) {
                Image(systemName: "heart.fill").font(.system(size: 10))
                Text("\(post.likeCount)").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white).padding(4).background(.black.opacity(0.4)).cornerRadius(4).padding(4)
        }
    }
}

struct CollectedPostGridItem: View {
    let post: Post
    @State private var authorAvatarURL: String?
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let urlString = post.imageURLs.first, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.1) }
                } else if let filename = post.imageFilenames.first, let image = DataManager.shared.loadImage(filename: filename) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Rectangle().fill(Color(post.color).gradient)
                        .overlay(Image(systemName: post.icon).font(.title2).foregroundStyle(.white.opacity(0.8)))
                }
            }
            .frame(width: (UIScreen.main.bounds.width - 4) / 3, height: (UIScreen.main.bounds.width - 4) / 3)
            .clipped()
            .overlay(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom))
            
            HStack(spacing: 4) {
                Group {
                    if let avatarURL = authorAvatarURL, let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray }
                    } else {
                        Image(systemName: "person.circle.fill").foregroundStyle(.gray)
                    }
                }
                .frame(width: 20, height: 20).clipShape(Circle()).overlay(Circle().stroke(.white, lineWidth: 1))
                
                Spacer()
                
                Image(systemName: "heart.fill").font(.system(size: 8)).foregroundStyle(.white)
                Text("\(post.likeCount)").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
            }
            .padding(6)
        }
        .task {
            if authorAvatarURL == nil {
                let profile = await DataManager.shared.fetchUserProfileFromCloud(userId: post.authorID)
                authorAvatarURL = profile?.avatarURL
            }
        }
    }
}

struct StatUnit: View {
    let value: String
    let title: String
    var isActive: Bool = false
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).bold().foregroundStyle(isActive ? .purple : .black)
            Text(title).font(.caption2).foregroundStyle(isActive ? .purple : .gray).textCase(.uppercase).fontWeight(isActive ? .bold : .regular)
        }
    }
}

struct EmptyStateView: View {
    var message: String = "No drops yet"
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.aperture").font(.system(size: 50)).foregroundStyle(.gray.opacity(0.3))
            Text(message).font(.subheadline).foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity).padding(.top, 40)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
