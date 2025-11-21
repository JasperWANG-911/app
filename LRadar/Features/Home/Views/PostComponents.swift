import SwiftUI
import PhotosUI

// MARK: - 1. 地图上的气泡 (Annotation)
struct PostAnnotationView: View {
    var color: UIColor // 接收 UIColor
    var icon: String
    
    var body: some View {
        ZStack {
            Image(systemName: "triangle.fill")
                .resizable()
                .frame(width: 12, height: 10)
                .foregroundStyle(.white)
                .rotationEffect(.degrees(180))
                .offset(y: 26)
                .shadow(radius: 2)
            
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
        .offset(y: -26)
    }
}

// MARK: - 2. 发帖卡片 (支持多图)
struct PostInputCard: View {
    @Bindable var viewModel: HomeViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // ... 标题栏和类型选择保持不变 ...
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
                
                // ⚠️ 修改点：多图上传与预览
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Photos").font(.caption).foregroundStyle(.gray)
                        Spacer()
                        // 这里的 selection 改为 $viewModel.imageSelections，并添加 maxSelectionCount
                        PhotosPicker(selection: $viewModel.imageSelections, maxSelectionCount: 5, matching: .images) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Add Photos")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                        }
                    }
                    
                    if viewModel.selectedImages.isEmpty {
                        // 空状态占位符
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground).opacity(0.5))
                            .frame(height: 100)
                            .overlay(Image(systemName: "photo.on.rectangle").foregroundStyle(.gray))
                    } else {
                        // 水平滚动预览选中的图片
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

// MARK: - 3. 帖子详情卡片 (支持左右滑动多图)
struct PostDetailCard: View {
    let post: Post
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // ⚠️ 修改点：使用 TabView 实现图片轮播
            ZStack(alignment: .topTrailing) {
                if !post.imageFilenames.isEmpty {
                    TabView {
                        ForEach(post.imageFilenames, id: \.self) { filename in
                            if let image = DataManager.shared.loadImage(filename: filename) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 300)
                                    .clipped() // 确保图片不溢出
                            }
                        }
                    }
                    .frame(height: 300)
                    .tabViewStyle(.page) // 启用分页圆点样式
                    .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                } else {
                    // 无图时的默认显示
                    Rectangle()
                        .fill(Color(post.color).gradient)
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: post.icon)
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.5))
                        )
                }
                
                // 关闭按钮
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(8)
                        .background(.white.opacity(0.8))
                        .clipShape(Circle())
                }
                .padding(16)
            }
            
            // ... 下方文字内容保持不变 ...
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
                    Text("Just now").font(.caption).foregroundStyle(.gray)
                }
                
                Text(post.title).font(.title2).bold()
                
                Text(post.caption).font(.body).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider().padding(.vertical, 8)
                
                HStack {
                    Circle().fill(Color(UIColor.secondarySystemBackground)).frame(width: 40, height: 40)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(.gray))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Posted by Jason").font(.subheadline).bold()
                        Text("UCL Student").font(.caption).foregroundStyle(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: { print("Like") }) {
                        Image(systemName: "heart").font(.title2).foregroundStyle(.black)
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
    }
}

// MARK: - 4. 辅助组件：分类药丸 (CategoryPill 保持不变)
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
