import SwiftUI
import PhotosUI
import FirebaseAuth // 🔥 引入 Auth 用于判断当前用户

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

// MARK: - 2. 发帖卡片 (支持多图)
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

// MARK: - 3. 帖子详情卡片 (支持点赞与删除)
struct PostDetailCard: View {
    let post: Post
    var onDismiss: () -> Void
    var onLike: () -> Void
    var onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    
    // 🔥 辅助计算属性：格式化相对时间
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full // 显示完整单词，如 "2 hours ago"
        return formatter.localizedString(for: post.timestamp, relativeTo: Date())
    }
    
    // 🔥 辅助计算属性：判断是否是当前用户的帖子
    private var isMyPost: Bool {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return false }
        return post.authorID == currentUserID
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // 图片轮播区域
            ZStack(alignment: .topTrailing) {
                // 优先加载云端 URL
                if !post.imageURLs.isEmpty {
                    TabView {
                        ForEach(post.imageURLs, id: \.self) { urlString in
                            AsyncImage(url: URL(string: urlString)) { phase in
                                switch phase {
                                case .empty:
                                    ZStack {
                                        Color.gray.opacity(0.1)
                                        ProgressView()
                                    }
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                case .failure:
                                    ZStack {
                                        Color.gray.opacity(0.1)
                                        Image(systemName: "photo.badge.exclamationmark").foregroundStyle(.gray)
                                    }
                                @unknown default: EmptyView()
                                }
                            }
                            .frame(height: 300).clipped()
                        }
                    }
                    .frame(height: 300)
                    .tabViewStyle(.page)
                }
                // 兼容旧数据：本地文件名
                else if !post.imageFilenames.isEmpty {
                    TabView {
                        ForEach(post.imageFilenames, id: \.self) { filename in
                            if let image = DataManager.shared.loadImage(filename: filename) {
                                Image(uiImage: image).resizable().scaledToFill().frame(height: 300).clipped()
                            }
                        }
                    }
                    .frame(height: 300).tabViewStyle(.page)
                }
                // 无图
                else {
                    Rectangle()
                        .fill(Color(post.color).gradient)
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: post.icon)
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.5))
                        )
                }
                
                // 顶部按钮组
                HStack {
                    // 🔥 只有作者本人才能看到删除按钮
                    if isMyPost {
                        Button(action: { showDeleteAlert = true }) {
                            Image(systemName: "trash.fill")
                                .font(.headline)
                                .foregroundStyle(.red)
                                .padding(8)
                                .background(.white.opacity(0.8))
                                .clipShape(Circle())
                        }
                    }
                    
                    Spacer()
                    
                    // 关闭按钮
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(8)
                            .background(.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                }
                .padding(16)
            }
            
            // 文字内容区域
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: post.icon)
                        Text(post.category.rawValue)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(Color(post.color)))
                    
                    Spacer()
                    // 🔥 动态时间显示
                    Text(timeAgo)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                Text(post.title).font(.title2).bold()
                
                Text(post.caption).font(.body).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider().padding(.vertical, 8)
                
                // 底部用户信息栏
                HStack {
                    Circle().fill(Color(UIColor.secondarySystemBackground)).frame(width: 40, height: 40)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(.gray))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        // 显示是否是本人
                        Text(isMyPost ? "Posted by You" : "Posted by User")
                            .font(.subheadline).bold()
                        
                        Text("UCL Student").font(.caption).foregroundStyle(.gray)
                    }
                    
                    Spacer()
                    
                    // 点赞按钮
                    Button(action: onLike) {
                        HStack(spacing: 6) {
                            Image(systemName: post.isLiked ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundStyle(post.isLiked ? .red : .black)
                                .contentTransition(.symbolEffect(.replace))
                            
                            if post.likeCount > 0 {
                                Text("\(post.likeCount)")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
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
        .alert("Delete this Drop?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - 4. 辅助组件：分类药丸
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
