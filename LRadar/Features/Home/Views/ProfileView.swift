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
    @State private var showAllDrops = false
    
    // 🔥 新增：控制设置页面的跳转
    @State private var showSettings = false
    
    // 冻结排序 ID
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
                        onRatingTap: { isShowingRatingDetail = true }
                    )
                    
                    // 2. 数据统计
                    ProfileStatsView(
                        postsCount: viewModel.myDropsCount,
                        likesCount: viewModel.myTotalLikes,
                        onDropsTap: { showAllDrops = true }
                    )
                    
                    Divider().padding(.horizontal)
                    
                    // 3. My Top Drops
                    VStack(alignment: .leading, spacing: 16) {
                        // 3.1 标题栏
                        Button(action: { showAllDrops = true }) {
                            HStack {
                                Text("My Top Drops").font(.headline).foregroundStyle(.black)
                                Spacer()
                                Text("See All").font(.subheadline).foregroundStyle(.gray)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.gray)
                            }
                            .padding(.horizontal)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        // 3.2 内容网格
                        if frozenTopIDs.isEmpty {
                            EmptyStateView()
                        } else {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(frozenTopIDs, id: \.self) { id in
                                    if let post = viewModel.myDrops.first(where: { $0.id == id }) {
                                        ZStack(alignment: .bottomTrailing) {
                                            // A. 图片主体
                                            Group {
                                                if let urlString = post.imageURLs.first, let url = URL(string: urlString) {
                                                    AsyncImage(url: url) { image in
                                                        image.resizable().scaledToFill()
                                                    } placeholder: {
                                                        Color.gray.opacity(0.1)
                                                    }
                                                } else if let filename = post.imageFilenames.first,
                                                          let image = DataManager.shared.loadImage(filename: filename) {
                                                    Image(uiImage: image).resizable().scaledToFill()
                                                } else {
                                                    Rectangle().fill(Color(post.color).gradient)
                                                        .overlay(
                                                            Image(systemName: post.icon)
                                                                .font(.title2)
                                                                .foregroundStyle(.white.opacity(0.8))
                                                        )
                                                }
                                            }
                                            .frame(width: (UIScreen.main.bounds.width - 4) / 3, height: (UIScreen.main.bounds.width - 4) / 3)
                                            .clipped()
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                viewModel.jumpToPost(post)
                                                currentTab = .map
                                            }
                                            
                                            // B. 右下角点赞
                                            Button(action: {
                                                viewModel.toggleLike(for: post)
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                                                        .font(.caption2)
                                                        .foregroundStyle(post.isLiked ? .red : .white)
                                                        .contentTransition(.symbolEffect(.replace))
                                                    
                                                    Text("\(post.likeCount)")
                                                        .font(.caption2).bold()
                                                        .foregroundStyle(.white)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(.ultraThinMaterial)
                                                .background(.black.opacity(0.3))
                                                .clipShape(Capsule())
                                                .padding(6)
                                            }
                                            .buttonStyle(.plain)
                                        }
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
            
            // 🔥 核心修改：Toolbar 改为齿轮图标 -> 跳转 SettingsView
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill") // 使用实心齿轮更显眼
                            .foregroundStyle(.black)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            // 🔥 跳转逻辑
            .navigationDestination(isPresented: $showAllDrops) {
                MyDropsListView(viewModel: viewModel, currentTab: $currentTab)
            }
            .navigationDestination(isPresented: $showSettings) {
                // 进入设置页面，传入必要的绑定
                SettingsView(viewModel: viewModel, isUserLoggedIn: $isUserLoggedIn)
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
            // 生命周期：刷新排序
            .onAppear {
                refreshTopDropsOrder()
            }
            .onChange(of: viewModel.myDrops.isEmpty) { _, isEmpty in
                if !isEmpty && frozenTopIDs.isEmpty {
                    refreshTopDropsOrder()
                }
            }
        }
    }
    
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

// MARK: - Child Views (保持不变，直接复用即可)

struct ProfileStatsView: View {
    let postsCount: Int
    let likesCount: Int
    var onDropsTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: onDropsTap) {
                StatUnit(value: "\(postsCount)", title: "Drops")
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.01))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().frame(height: 24)
            
            StatUnit(value: "\(likesCount)", title: "Likes")
                .frame(maxWidth: .infinity)
            
            Divider().frame(height: 24)
            
            StatUnit(value: "0", title: "Friends")
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
    }
}

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
                    } else if let filename = user.avatarFilename,
                              let image = DataManager.shared.loadImage(filename: filename) {
                        Image(uiImage: image)
                            .resizable().scaledToFill()
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

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
