import SwiftUI
import PhotosUI
import FirebaseAuth

// MARK: - 0. 用户信息行 (自动拉取资料)
struct PostAuthorRow: View {
    let userId: String
    @State private var userProfile: UserProfile? // 暂存加载到的用户资料
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. 头像部分
            if let avatarURL = userProfile?.avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Color.gray.opacity(0.3)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                // 没有头像时的默认图
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.gray.opacity(0.5))
                    .frame(width: 40, height: 40)
            }
            
            // 2. 文字部分
            VStack(alignment: .leading, spacing: 2) {
                // 名字
                Text(userProfile?.name ?? "Loading...")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                // 学校
                Text(userProfile?.school ?? "UCL Student")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        // 🔥 关键：视图出现时，自动去云端查这个人是谁
        .task {
            if userProfile == nil {
                userProfile = await DataManager.shared.fetchUserProfileFromCloud(userId: userId)
            }
        }
    }
}

// MARK: - 1. 地图上的气泡 (Annotation)
struct PostAnnotationView: View {
    var color: UIColor
    var icon: String
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. 上半部分：圆形图标
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 46, height: 46)
                    .shadow(radius: 4)
                
                Circle()
                    .fill(Color(color).gradient)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundStyle(.white)
                            .font(.caption)
                            .bold()
                    )
            }
            .zIndex(1)
            
            // 2. 下半部分：倒三角
            Image(systemName: "triangle.fill")
                .resizable()
                .frame(width: 12, height: 10)
                .foregroundStyle(.white)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
                .shadow(radius: 2)
                .zIndex(0)
        }
    }
}

// MARK: - 2. 星星评分组件 (新增)
struct StarRatingView: View {
    var rating: Int             // 当前分数
    var maxRating: Int = 5      // 满分
    var interactive: Bool = false // 是否可交互 (输入模式)
    var onRatingChanged: ((Int) -> Void)? = nil // 点击回调
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(interactive ? .title3 : .caption) // 交互模式大一点，展示模式小一点
                    .foregroundStyle(star <= rating ? .yellow : .gray.opacity(0.3))
                    .onTapGesture {
                        if interactive {
                            onRatingChanged?(star)
                        }
                    }
            }
        }
    }
}

// MARK: - 3. 发帖卡片 (支持多图 + 评分)
struct PostInputCard: View {
    @Bindable var viewModel: HomeViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                HStack {
                    Text("New Drop").font(.title2).bold()
                    Spacer()
                    Button(action: { viewModel.cancelPost() }) {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.gray.opacity(0.4))
                    }
                }
                
                Text("Type").font(.caption).foregroundStyle(.gray)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PostCategory.allCases) { category in
                            CategoryPill(
                                category: category,
                                isSelected: viewModel.inputCategory == category,
                                onTap: { viewModel.inputCategory = category }
                            )
                        }
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Details").font(.caption).foregroundStyle(.gray)
                    
                    TextField("Title (e.g. Great Coffee)", text: $viewModel.inputTitle)
                        .font(.headline).padding(12).background(Color(UIColor.secondarySystemBackground)).cornerRadius(12)
                    
                    // 🔥 新增：评分输入
                    HStack {
                        Text("Rating:")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        StarRatingView(
                            rating: viewModel.inputRating,
                            interactive: true,
                            onRatingChanged: { newRating in
                                viewModel.inputRating = newRating
                            }
                        )
                    }
                    .padding(.vertical, 4)
                    
                    TextField("What's happening here?", text: $viewModel.inputCaption, axis: .vertical)
                        .lineLimit(3...6).padding(12).background(Color(UIColor.secondarySystemBackground)).cornerRadius(12)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Photos (Max 9)").font(.caption).foregroundStyle(.gray)
                        Spacer()
                        PhotosPicker(selection: $viewModel.imageSelections, maxSelectionCount: 9, matching: .images) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Add Photos")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                        }
                    }
                    
                    if viewModel.selectedImages.isEmpty {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground).opacity(0.5))
                            .frame(height: 100)
                            .overlay(Image(systemName: "photo.on.rectangle").foregroundStyle(.gray))
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(viewModel.selectedImages, id: \.self) { img in
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 20)
                
                Button(action: { viewModel.submitPost() }) {
                    Text("Post Drop")
                        .bold().frame(maxWidth: .infinity).padding()
                        .background(canSubmit ? Color.black : Color.gray.opacity(0.3))
                        .foregroundStyle(.white).cornerRadius(16)
                }
                .disabled(!canSubmit)
            }
            .padding(24)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.1), radius: 20)
    }
    
    var canSubmit: Bool { !viewModel.inputTitle.isEmpty }
}

// MARK: - 4. 帖子详情卡片 (支持点赞、删除 + 评分展示 + 举报)
struct PostDetailCard: View {
    let post: Post
    var onDismiss: () -> Void
    var onLike: () -> Void
    var onDelete: () -> Void
    // 这里的 onReport 我们让它带一个原因参数，方便扩展
    var onReport: (String) -> Void
    
    @State private var showDeleteAlert = false
    @State private var showReportAlert = false // 🔥 控制举报确认弹窗
    @State private var showToast = false       // 🔥 控制成功提示显示
    
    // 辅助计算属性
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: post.timestamp, relativeTo: Date())
    }
    
    private var isMyPost: Bool {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return false }
        return post.authorID == currentUserID
    }
    
    var body: some View {
        ZStack(alignment: .bottom) { // 使用 ZStack 以便让 Toast 浮在上面
            VStack(alignment: .leading, spacing: 0) {
                
                // --- 1. 图片轮播区域 ---
                ZStack(alignment: .topTrailing) {
                    // ... (图片显示代码保持不变，省略以节省篇幅，请保留你原有的 AsyncImage/TabView 代码) ...
                    // 这里为了演示，我只保留占位符逻辑，你记得保留原有的图片加载逻辑！
                    if !post.imageURLs.isEmpty {
                        TabView {
                            ForEach(post.imageURLs, id: \.self) { urlString in
                                AsyncImage(url: URL(string: urlString)) { phase in
                                    if let image = phase.image { image.resizable().scaledToFill() }
                                    else { Color.gray.opacity(0.1) }
                                }.frame(height: 300).clipped()
                            }
                        }
                        .frame(height: 300).tabViewStyle(.page)
                    } else {
                        Rectangle().fill(Color(post.color).gradient).frame(height: 200)
                            .overlay(Image(systemName: post.icon).font(.system(size: 60)).foregroundStyle(.white.opacity(0.5)))
                    }
                    
                    // D. 顶部悬浮按钮
                    HStack {
                        if isMyPost {
                            Button(action: { showDeleteAlert = true }) {
                                Image(systemName: "trash.fill")
                                    .font(.headline).foregroundStyle(.red)
                                    .padding(8).background(.white.opacity(0.8)).clipShape(Circle())
                            }
                        } else {
                            // 🔥 举报入口
                            Menu {
                                Button(role: .destructive) {
                                    showReportAlert = true // 点击后弹出确认框
                                } label: {
                                    Label("Report Post", systemImage: "exclamationmark.bubble")
                                }
                                // 屏蔽功能暂时隐藏，等想好逻辑再加
                                // Button(...) { ... }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.headline).foregroundStyle(.black)
                                    .padding(8).background(.white.opacity(0.8)).clipShape(Circle())
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.headline).foregroundStyle(.black)
                                .padding(8).background(.white.opacity(0.8)).clipShape(Circle())
                        }
                    }
                    .padding(16)
                }
                
                // --- 2. 文字内容区域 ---
                VStack(alignment: .leading, spacing: 12) {
                    // ... (文字部分代码保持不变，保留你原有的 HStack/Text 逻辑) ...
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: post.icon)
                            Text(post.category.rawValue)
                        }
                        .font(.caption.bold()).foregroundStyle(.white)
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(Capsule().fill(Color(post.color)))
                        
                        if post.rating > 0 {
                            Spacer().frame(width: 8)
                            HStack(spacing: 2) {
                                Text(String(format: "%.1f", post.rating)).font(.caption.bold()).foregroundStyle(.yellow)
                                StarRatingView(rating: Int(post.rating), interactive: false)
                            }
                        }
                        Spacer()
                        Text(timeAgo).font(.caption).foregroundStyle(.gray)
                    }
                    
                    Text(post.title).font(.title2).bold()
                    Text(post.caption).font(.body).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider().padding(.vertical, 8)
                    
                    // --- 3. 底部用户信息栏 ---
                    HStack {
                        PostAuthorRow(userId: post.authorID)
                        Spacer()
                        Button(action: onLike) {
                            HStack(spacing: 6) {
                                Image(systemName: post.isLiked ? "heart.fill" : "heart")
                                    .font(.title2).foregroundStyle(post.isLiked ? .red : .black)
                                    .contentTransition(.symbolEffect(.replace))
                                if post.likeCount > 0 {
                                    Text("\(post.likeCount)").font(.subheadline).foregroundStyle(.gray)
                                }
                            }
                        }
                    }
                }
                .padding(24)
                .background(Color.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .padding(.horizontal)
            .padding(.bottom, 40)
            
            // 🔥 关键：Toast 提示层
            if showToast {
                ToastView(message: "Thanks for reporting. Admins will review shortly.")
                    .onAppear {
                        // 2秒后自动消失
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { showToast = false }
                        }
                    }
            }
        }
        // 🔥 删除确认弹窗
        .alert("Delete this Drop?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This action cannot be undone.")
        }
        // 🔥 举报确认弹窗
        .confirmationDialog("Report this post?", isPresented: $showReportAlert, titleVisibility: .visible) {
            Button("Inappropriate Content", role: .destructive) {
                handleReport(reason: "Inappropriate Content")
            }
            Button("Spam or Scam", role: .destructive) {
                handleReport(reason: "Spam or Scam")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please select a reason. Our team will review this report.")
        }
    }
    
    // 内部处理函数：触发回调并显示 Toast
    private func handleReport(reason: String) {
        onReport(reason) // 调用外部传入的 ViewModel 逻辑写入数据库
        withAnimation {
            showToast = true // 显示成功提示
        }
    }
}

// MARK: - 5. 辅助组件：分类药丸
struct CategoryPill: View {
    let category: PostCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: category.icon)
                Text(category.rawValue)
            }
            .font(.subheadline.bold())
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(isSelected ? Color(category.color) : Color(UIColor.secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .gray)
            .clipShape(Capsule())
        }
    }
}
