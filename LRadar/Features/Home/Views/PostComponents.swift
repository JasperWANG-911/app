import SwiftUI
import PhotosUI
import FirebaseAuth

// MARK: - 0. 用户信息行 (修改：增加显示头衔)
struct PostAuthorRow: View {
    let userId: String
    @State private var userProfile: UserProfile?
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. 头像部分 (保持不变)
            if let avatarURL = userProfile?.avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 40, height: 40).clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable().foregroundStyle(.gray.opacity(0.5))
                    .frame(width: 40, height: 40)
            }
            
            // 2. 文字部分
            VStack(alignment: .leading, spacing: 2) {
                // 名字 + 头衔 (新增)
                HStack(spacing: 4) {
                    Text(userProfile?.name ?? "Loading...")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    // ✅ 新增：显示用户的声望头衔
                    if let title = userProfile?.rankTitle {
                        Text(title)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                
                Text(userProfile?.school ?? "UCL Student")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
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

// MARK: - 3. 发帖卡片 (修改：删除了评分输入)
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
                    
                    // ❌ 原来的 Rating 输入框已删除
                    
                    TextField("What's happening here?", text: $viewModel.inputCaption, axis: .vertical)
                        .lineLimit(3...6).padding(12).background(Color(UIColor.secondarySystemBackground)).cornerRadius(12)
                }
                
                // ... (照片选择部分保持不变) ...
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Photos (Max 9)").font(.caption).foregroundStyle(.gray)
                        Spacer()
                        PhotosPicker(selection: $viewModel.imageSelections, maxSelectionCount: 9, matching: .images) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Add Photos")
                            }
                            .font(.caption.bold()).foregroundStyle(.blue)
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
                                        .resizable().scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 20)
                
                Button(action: { viewModel.submitPost() }) {
                    Text("Post Drop (+10 pts)") // ✅ 提示：发帖加分
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

// MARK: - 4. 帖子详情卡片 (修正顶部按钮逻辑)
struct PostDetailCard: View {
    let post: Post
    var onDismiss: () -> Void
    var onLike: () -> Void
    var onDelete: () -> Void
    var onReport: (String, String) -> Void
    
    // 收藏相关
    var onBookmark: () -> Void
    var isBookmarked: Bool
    
    @State private var showDeleteAlert = false
    @State private var showReportSheet = false
    @State private var showToast = false
    
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
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                
                // --- 1. 图片轮播区域 ---
                ZStack(alignment: .topTrailing) {
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
                    
                    // --- 顶部悬浮按钮组 ---
                    HStack {
                        // A. 左上角：功能按钮 (删除 或 举报)
                        if isMyPost {
                            Button(action: { showDeleteAlert = true }) {
                                Image(systemName: "trash.fill")
                                    .font(.headline).foregroundStyle(.red)
                                    .padding(8).background(.white.opacity(0.8)).clipShape(Circle())
                            }
                        } else {
                            Button(action: { showReportSheet = true }) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.headline).foregroundStyle(.red)
                                    .padding(8).background(.white.opacity(0.8)).clipShape(Circle())
                            }
                        }
                        
                        Spacer()
                        
                        // B. 右上角：关闭按钮 (始终是 X)
                        Button(action: onDismiss) {
                            Image(systemName: "xmark") // ✅ 确认是关闭图标
                                .font(.headline).foregroundStyle(.black)
                                .padding(8).background(.white.opacity(0.8)).clipShape(Circle())
                        }
                    }
                    .padding(16)
                }
                
                // --- 2. 文字内容区域 ---
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: post.icon)
                            Text(post.category.rawValue)
                        }
                        .font(.caption.bold()).foregroundStyle(.white)
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .background(Capsule().fill(Color(post.color)))
                        
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
                        
                        // 收藏按钮 (Bookmarked)
                        Button(action: onBookmark) {
                            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                .font(.title2)
                                .foregroundStyle(isBookmarked ? .orange : .black)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .padding(.trailing, 16)
                        
                        // 点赞按钮 (Like)
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
            
            if showToast {
                ToastView(message: "Report submitted.")
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { showToast = false }
                        }
                    }
            }
        }
        .alert("Delete this Drop?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheetView { type, details in
                handleReport(type: type, details: details)
            }
            .presentationDetents([.medium])
            .presentationCornerRadius(24)
        }
    }
    
    private func handleReport(type: String, details: String) {
        let fullReason = "[\(type)] \(details)"
        onReport(type, details)
        withAnimation { showToast = true }
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

// MARK: - 6. 新版举报弹窗 (UI 升级)
struct ReportSheetView: View {
    @Environment(\.dismiss) var dismiss
    var onSubmit: (String, String) -> Void
    
    @State private var selectedType = "Spam or Scam"
    @State private var description = ""
    
    let reportTypes = [
        "Inappropriate Content",
        "Spam or Scam",
        "Harassment",
        "False Information",
        "Other"
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // 顶部指示条
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            
            Text("Report Drop")
                .font(.title3).bold()
            
            VStack(alignment: .leading, spacing: 20) {
                // 1. 类型选择
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason").font(.caption).foregroundStyle(.gray).textCase(.uppercase)
                    
                    Menu {
                        ForEach(reportTypes, id: \.self) { type in
                            Button(type) { selectedType = type }
                        }
                    } label: {
                        HStack {
                            Text(selectedType)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption).foregroundStyle(.gray)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
                
                // 2. 详细描述 (限字数)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Details (Optional)").font(.caption).foregroundStyle(.gray).textCase(.uppercase)
                        Spacer()
                        Text("\(description.count)/100")
                            .font(.caption)
                            .foregroundStyle(description.count > 100 ? .red : .gray)
                    }
                    
                    TextField("Please describe the issue...", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .onChange(of: description) { _, newValue in
                            if newValue.count > 100 {
                                description = String(newValue.prefix(100))
                            }
                        }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 3. 提交按钮
            Button(action: {
                onSubmit(selectedType, description)
                dismiss()
            }) {
                Text("Submit Report")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(Color.white)
    }
}
