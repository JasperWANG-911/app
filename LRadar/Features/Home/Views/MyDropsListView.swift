import SwiftUI

struct MyDropsListView: View {
    // 这里需要把 viewModel 变成 @Bindable 或者直接引用，因为我们需要修改它的数据
    // 由于 ViewModel 是 class (Reference Type)，直接传递引用即可
    var viewModel: HomeViewModel
    @Binding var currentTab: Tab
    
    var body: some View {
            List {
                // 🔥 修改点 1: 这里改成 viewModel.myDrops
                ForEach(viewModel.myDrops) { post in
                    Button(action: {
                        viewModel.jumpToPost(post)
                        currentTab = .map
                    }) {
                        HStack(spacing: 16) {
                            // 左侧小图 (保持你之前改好的 AsyncImage 代码)
                            ZStack {
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
                                    Image(systemName: post.icon).foregroundStyle(.white)
                                }
                            }
                            .frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            // 中间文字
                            VStack(alignment: .leading, spacing: 4) {
                                Text(post.title).font(.headline).foregroundStyle(.black)
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
                            Image(systemName: "chevron.right").foregroundStyle(.gray.opacity(0.5)).font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowSeparator(.hidden)
                    .buttonStyle(.plain)
                }
                // ✅ 删除修饰符
                .onDelete { indexSet in
                    for index in indexSet {
                        // 🔥 修改点 2: 必须从 myDrops 里取数据，因为现在的 index 是针对 filtered 数组的
                        let post = viewModel.myDrops[index]
                        viewModel.deletePost(post)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("My Drops")
            .navigationBarTitleDisplayMode(.inline)
        }
}
