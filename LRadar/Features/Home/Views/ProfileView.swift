import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    var viewModel: HomeViewModel
    
    @Binding var currentTab: Tab
    
    @AppStorage("isUserLoggedIn") private var isUserLoggedIn: Bool = false
    
    // 状态控制
    @State private var isShowingEdit = false
    @State private var isShowingShare = false
    @State private var isShowingRatingDetail = false
    
    // 控制跳转到 All Drops 的状态
    @State private var showAllDrops = false
    
    @State private var showDeleteAccountAlert = false
    
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
                        onRatingTap: { isShowingRatingDetail = true }
                    )
                    
                    // 2. 数据统计 (修复点击跳转)
                    ProfileStatsView(
                        postsCount: viewModel.myDropsCount,
                        likesCount: viewModel.myTotalLikes,
                        onDropsTap: {
                            print("🔵 Drops tapped - Navigating")
                            showAllDrops = true
                        }
                    )
                    
                    Divider().padding(.horizontal)
                    
                    // 3. My Top Drops (预览区)
                    // 整个区域都是按钮，点击去列表页
                    Button(action: {
                        print("🔵 My Top Drops tapped")
                        showAllDrops = true
                    }) {
                        VStack(alignment: .leading, spacing: 16) {
                            // 3.1 标题栏
                            HStack {
                                Text("My Top Drops").font(.headline).foregroundStyle(.black)
                                Spacer()
                                Text("See All").font(.subheadline).foregroundStyle(.gray)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.gray)
                            }
                            .padding(.horizontal)
                            
                            // 3.2 内容网格
                            // 🔥 关键修复：这里必须检查 myDrops，而不是 posts (posts 是全网所有帖子)
                            if viewModel.myDrops.isEmpty {
                                EmptyStateView()
                            } else {
                                LazyVGrid(columns: columns, spacing: 2) {
                                    // 只显示前 6 张图
                                    ForEach(viewModel.myDrops.prefix(6)) { post in
                                        ZStack {
                                            // 1. 云端图片
                                            if let urlString = post.imageURLs.first, let url = URL(string: urlString) {
                                                AsyncImage(url: url) { image in
                                                    image.resizable().scaledToFill()
                                                } placeholder: {
                                                    Color.gray.opacity(0.1)
                                                }
                                                .frame(width: (UIScreen.main.bounds.width - 4) / 3, height: (UIScreen.main.bounds.width - 4) / 3)
                                                .clipped()
                                            }
                                            // 2. 本地图片兼容
                                            else if let filename = post.imageFilenames.first,
                                                    let image = DataManager.shared.loadImage(filename: filename) {
                                                Image(uiImage: image)
                                                    .resizable().scaledToFill()
                                                    .frame(width: (UIScreen.main.bounds.width - 4) / 3, height: (UIScreen.main.bounds.width - 4) / 3)
                                                    .clipped()
                                            }
                                            // 3. 默认占位
                                            else {
                                                Rectangle().fill(Color(post.color).gradient)
                                                    .frame(width: (UIScreen.main.bounds.width - 4) / 3, height: (UIScreen.main.bounds.width - 4) / 3)
                                                    .overlay(
                                                        Image(systemName: post.icon)
                                                            .font(.title2)
                                                            .foregroundStyle(.white.opacity(0.8))
                                                    )
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 100)
                        .contentShape(Rectangle()) // 确保点击空白处也能触发
                    }
                    .buttonStyle(.plain) // 避免按钮点击时的灰色闪烁
                }
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Menu {
                                    Button { print("Settings") } label: { Label("Settings", systemImage: "gear") }
                                    
                                    Divider()
                                    
                                    // 退出登录
                                    Button(role: .destructive) {
                                        try? Auth.auth().signOut()
                                        isUserLoggedIn = false
                                    } label: {
                                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                    }
                                    
                                    // 🔥 新增：删除账号
                                    Button(role: .destructive) {
                                        showDeleteAccountAlert = true
                                    } label: {
                                        Label("Delete Account", systemImage: "trash")
                                    }
                                    
                                } label: {
                                    Image(systemName: "line.3.horizontal").foregroundStyle(.black).fontWeight(.semibold)
                                }
                            }
                        }
                        // 🔥 新增：删除账号的 Alert 处理
                        .alert("Delete Account?", isPresented: $showDeleteAccountAlert) {
                            Button("Cancel", role: .cancel) { }
                            Button("Delete", role: .destructive) {
                                viewModel.deleteAccount { success in
                                    if success {
                                        // 删除成功，切回登录页
                                        isUserLoggedIn = false
                                    } else {
                                        // 失败通常是因为需要重新认证
                                        // 这里可以加个简单的 Toast 提示，或者直接打印日志
                                        print("Require recent login to delete")
                                    }
                                }
                            }
                        } message: {
                            Text("This will permanently delete your profile, posts, and data. This action cannot be undone.")
                        }
            // ✅ 跳转目的地
            .navigationDestination(isPresented: $showAllDrops) {
                MyDropsListView(viewModel: viewModel, currentTab: $currentTab)
            }
            .sheet(isPresented: $isShowingEdit) {
                EditProfileView(profileCopy: viewModel.currentUser, onSave: { updatedProfile, newImage in
                    viewModel.updateUserProfile(updatedProfile)
                    if let img = newImage { viewModel.updateUserAvatar(img) }
                })
            }
            .sheet(isPresented: $isShowingShare) {
                ShareSheet(items: ["Check out \(viewModel.currentUser.name)'s profile!"])
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $isShowingRatingDetail) {
                RatingBreakdownView(user: viewModel.currentUser)
                    .presentationDetents([.height(400)])
                    .presentationCornerRadius(24)
            }
        }
    }
}

// MARK: - 子组件修复

struct ProfileStatsView: View {
    let postsCount: Int
    let likesCount: Int
    var onDropsTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Drops 区域 (按钮)
            Button(action: onDropsTap) {
                StatUnit(value: "\(postsCount)", title: "Drops")
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.01)) // 🔥 关键：增加点击热区，防止点不到
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().frame(height: 24)
            
            // Likes 区域
            StatUnit(value: "\(likesCount)", title: "Likes")
                .frame(maxWidth: .infinity)
            
            Divider().frame(height: 24)
            
            // Friends 区域
            StatUnit(value: "0", title: "Friends")
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
    }
}

// 下面的组件保持不变，不需要改动
struct StatUnit: View {
    let value: String
    let title: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).bold()
            Text(title).font(.caption2).foregroundStyle(.gray).textCase(.uppercase)
        }
    }
}

struct ProfileHeaderView: View {
    var user: UserProfile
    var onEditTap: () -> Void
    var onShareTap: () -> Void
    var onRatingTap: () -> Void
    
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
                            } else {
                                Color.gray.opacity(0.1)
                            }
                        }
                        .frame(width: 96, height: 96).clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundStyle(Color(UIColor.secondarySystemBackground))
                            .frame(width: 96, height: 96).clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    }
                    
                    Button(action: onRatingTap) {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                            Text(String(format: "%.2f", user.rating)).font(.caption).bold().foregroundStyle(.white).monospacedDigit()
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.gray)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(.black))
                        .overlay(Capsule().stroke(Color.white, lineWidth: 2))
                    }
                    .offset(x: 10, y: 5)
                }
            }.buttonStyle(.plain)
            
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(user.name).font(.title2).bold().foregroundStyle(.black)
                    Text(formattedHandle).font(.subheadline).foregroundStyle(.gray)
                }
                HStack(spacing: 4) {
                    Image(systemName: "graduationcap.fill").font(.caption).foregroundStyle(.gray)
                    Text("\(user.school) · \(user.major)").font(.subheadline).foregroundStyle(.gray)
                }
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

// ... 其他 RatingView, ShareSheet, EmptyStateView 保持不变 ...
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.aperture").font(.system(size: 50)).foregroundStyle(.gray.opacity(0.3))
            Text("No drops yet").font(.subheadline).foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity).padding(.top, 40)
    }
}

struct RatingBreakdownView: View {
    var user: UserProfile
    var body: some View {
        VStack(spacing: 20) {
            Text("Rating Breakdown").font(.headline).padding(.top, 20)
            HStack(spacing: 20) {
                Text(String(format: "%.1f", user.rating)).font(.system(size: 60, weight: .heavy))
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text("Based on 142 reviews").font(.caption).foregroundStyle(.gray)
                }
            }
            Spacer()
        }.padding()
    }
}

struct RatingBar: View {
    let star: Int
    let percentage: CGFloat
    var body: some View {
        HStack {
            Text("\(star)").font(.caption).bold().frame(width: 20)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    Capsule().fill(Color.black).frame(width: geo.size.width * percentage)
                }
            }
            .frame(height: 6)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
