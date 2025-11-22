import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    var viewModel: HomeViewModel
    @Binding var currentTab: Tab
    
    @AppStorage("isUserLoggedIn") private var isUserLoggedIn: Bool = false
    
    // 状态控制
    @State private var isShowingEdit = false
    @State private var isShowingShare = false
    @State private var isShowingReputationDetail = false // ✅ 变量名改得更贴切
    @State private var showAllDrops = false
    
    // 控制设置页面的跳转
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
                        onReputationTap: { isShowingReputationDetail = true } // ✅ 传入新回调
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.black)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .navigationDestination(isPresented: $showAllDrops) {
                MyDropsListView(viewModel: viewModel, currentTab: $currentTab)
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel, isUserLoggedIn: $isUserLoggedIn)
            }
            .sheet(isPresented: $isShowingEdit) {
                EditProfileView(profileCopy: viewModel.currentUser, onSave: { updatedProfile, newImage in
                    viewModel.updateUserProfile(updatedProfile)
                    if let img = newImage { viewModel.updateUserAvatar(img) }
                })
            }
            .sheet(isPresented: $isShowingShare) {
                ShareSheet(items: ["Check out \(viewModel.currentUser.name)'s profile on LRadar!"])
                    .presentationDetents([.medium])
            }
            // ✅ 显示新的声望详情页
            .sheet(isPresented: $isShowingReputationDetail) {
                ReputationBreakdownView(user: viewModel.currentUser)
                    .presentationDetents([.height(400)])
                    .presentationCornerRadius(24)
            }
            .onAppear { refreshTopDropsOrder() }
            .onChange(of: viewModel.myDrops.isEmpty) { _, isEmpty in
                if !isEmpty && frozenTopIDs.isEmpty { refreshTopDropsOrder() }
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

// MARK: - Subviews

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
            // 1. 头像部分 (保持不变)
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
                    
                    // 声望勋章
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
            
            // 2. 文字信息部分 (🔥 修改了这里)
            VStack(spacing: 6) {
                // 名字和 Handle
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(user.name).font(.title2).bold().foregroundStyle(.black)
                    Text(formattedHandle).font(.subheadline).foregroundStyle(.gray)
                }
                
                // 🔥 将学校和专业拆分开，并增加空值判断
                VStack(spacing: 4) {
                    // 第一行：学校 (必显)
                    HStack(spacing: 6) {
                        Image(systemName: "graduationcap.fill")
                            .font(.caption).foregroundStyle(.purple) // 给个颜色区分
                        Text(user.school)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                    
                    // 第二行：专业 (选显)
                    // 只有当 major 不为空字符串时才显示
                    if !user.major.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill")
                                .font(.caption).foregroundStyle(.gray)
                            Text(user.major)
                                .font(.subheadline).foregroundStyle(.gray)
                        }
                    }
                }
                .padding(.top, 2)
                
                // Bio
                Text(user.bio).font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40).padding(.top, 4)
            }
            
            // 按钮组 (保持不变)
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

// 🔥 重写：声望详情页 (原 RatingBreakdownView)
struct ReputationBreakdownView: View {
    var user: UserProfile
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Reputation Status").font(.headline).padding(.top, 20)
            
            // 当前等级展示
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.1)).frame(width: 80, height: 80)
                    Image(systemName: "trophy.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.yellow.gradient)
                }
                
                Text(user.rankTitle)
                    .font(.title).bold()
                    .foregroundStyle(.primary)
                
                Text("\(user.reputation) Points")
                    .font(.title3).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // 积分规则说明
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
                        Text("Get a Like (Coming Soon)").bold()
                        Text("+2 pts").font(.caption).foregroundStyle(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
}

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

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.aperture").font(.system(size: 50)).foregroundStyle(.gray.opacity(0.3))
            Text("No drops yet").font(.subheadline).foregroundStyle(.gray)
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
