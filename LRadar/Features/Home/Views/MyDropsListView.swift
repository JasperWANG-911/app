import SwiftUI

struct MyDropsListView: View {
    // 这里需要把 viewModel 变成 @Bindable 或者直接引用，因为我们需要修改它的数据
    // 由于 ViewModel 是 class (Reference Type)，直接传递引用即可
    var viewModel: HomeViewModel
    @Binding var currentTab: Tab
    
    var body: some View {
        List {
            // 使用 ForEach 才能支持 onDelete
            ForEach(viewModel.posts) { post in
                Button(action: {
                    viewModel.jumpToPost(post)
                    currentTab = .map
                }) {
                    HStack(spacing: 16) {
                        // 左侧小图
                        ZStack {
                            // 1. 优先尝试云端图片
                            if let urlString = post.imageURLs.first, let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.1)
                                }
                            }
                            // 2. 其次尝试本地图片 (兼容旧数据)
                            else if let filename = post.imageFilenames.first,
                                    let image = DataManager.shared.loadImage(filename: filename) {
                                Image(uiImage: image).resizable().scaledToFill()
                            }
                            // 3. 都没有 -> 显示默认图标
                            else {
                                Rectangle().fill(Color(post.color).gradient)
                                Image(systemName: post.icon).foregroundStyle(.white)
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        // 中间文字
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.title).font(.headline).foregroundStyle(.black)
                            // 显示点赞数
                            HStack {
                                Text(post.caption).font(.caption).foregroundStyle(.gray).lineLimit(1)
                                if post.isLiked {
                                    Image(systemName: "heart.fill").font(.caption2).foregroundStyle(.red)
                                }
                            }
                            
                            HStack {
                                Image(systemName: post.icon).font(.caption2)
                                Text(post.category.rawValue).font(.caption2).bold()
                            }.foregroundStyle(Color(post.color))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.gray.opacity(0.5))
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                .listRowSeparator(.hidden)
                .buttonStyle(.plain)
            }
            // ✅ 添加删除修饰符
            .onDelete { indexSet in
                for index in indexSet {
                    let post = viewModel.posts[index]
                    viewModel.deletePost(post)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("My Drops")
        .navigationBarTitleDisplayMode(.inline)
    }
}
