import SwiftUI

struct ProfileView: View {
    var viewModel: HomeViewModel
    
    // 状态控制
    @Binding var currentTab: Tab
    
    @State private var isShowingEdit = false
    @State private var isShowingShare = false
    @State private var isShowingRatingDetail = false
    
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
                    ProfileStatsView(postsCount: viewModel.posts.count)
                    
                    Divider().padding(.horizontal)
                    
                    // 3. My Top Drops (预览区)
                    VStack(alignment: .leading, spacing: 16) {
                        // NavigationLink 引用 MyDropsListView (必须在单独文件里)
                        NavigationLink(destination: MyDropsListView(viewModel: viewModel, currentTab: $currentTab)) {
                            HStack {
                                Text("My Top Drops").font(.headline).foregroundStyle(.black)
                                Spacer()
                                Text("See All").font(.subheadline).foregroundStyle(.gray)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.gray)
                            }
                            .padding(.horizontal)
                        }
                        
                        if viewModel.posts.isEmpty {
                            EmptyStateView()
                        } else {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(viewModel.posts.prefix(6)) { post in
                                    ZStack {
                                        if let filename = post.imageFilename,
                                           let image = DataManager.shared.loadImage(filename: filename) {
                                            Image(uiImage: image)
                                                .resizable().scaledToFill()
                                                .frame(width: (UIScreen.main.bounds.width - 4) / 3, height: (UIScreen.main.bounds.width - 4) / 3)
                                                .clipped()
                                        } else {
                                            Rectangle().fill(Color(post.color).gradient).aspectRatio(1, contentMode: .fit)
                                            Image(systemName: post.icon).font(.title2).foregroundStyle(.white.opacity(0.8))
                                        }
                                    }
                                    .onTapGesture {
                                        viewModel.jumpToPost(post)
                                        currentTab = .map
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
            // ... (Toolbar, Sheets, etc. 保持不变) ...
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { print("Settings") } label: { Label("Settings", systemImage: "gear") }
                        Divider()
                        Button(role: .destructive) { print("Logout") } label: { Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right") }
                    } label: {
                        Image(systemName: "line.3.horizontal").foregroundStyle(.black).fontWeight(.semibold)
                    }
                }
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

// MARK: - 必须的子组件定义 (修复 Cannot find in scope 错误)
// 这就是你刚才丢失的所有 struct

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
                    if let filename = user.avatarFilename,
                       let avatar = DataManager.shared.loadImage(filename: filename) {
                        Image(uiImage: avatar).resizable().scaledToFill()
                            .frame(width: 96, height: 96).clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 4)).shadow(color: .black.opacity(0.05), radius: 5)
                    } else {
                        Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(Color(UIColor.secondarySystemBackground))
                            .frame(width: 96, height: 96).overlay(Circle().stroke(Color.white, lineWidth: 4))
                    }
                    Button(action: onRatingTap) {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                            Text(String(format: "%.2f", user.rating)).font(.caption).bold().foregroundStyle(.white).monospacedDigit()
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.gray)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(.black)).overlay(Capsule().stroke(Color.white, lineWidth: 2))
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
                Text(user.bio).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40).padding(.top, 4)
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
    var body: some View {
        HStack(spacing: 0) {
            StatUnit(value: "\(postsCount)", title: "Drops")
            Divider().frame(height: 24)
            StatUnit(value: "1.2k", title: "Likes")
            Divider().frame(height: 24)
            StatUnit(value: "342", title: "Friends")
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
        .frame(maxWidth: .infinity)
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
            Divider()
            VStack(spacing: 8) {
                RatingBar(star: 5, percentage: 0.8)
                RatingBar(star: 4, percentage: 0.15)
                RatingBar(star: 3, percentage: 0.03)
                RatingBar(star: 2, percentage: 0.01)
                RatingBar(star: 1, percentage: 0.01)
            }
            .padding(.horizontal)
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

#Preview {
    ProfileView(viewModel: HomeViewModel(), currentTab: .constant(.profile))
}
