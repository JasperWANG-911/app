import SwiftUI

struct MyDropsListView: View {
    var viewModel: HomeViewModel
    @Binding var currentTab: Tab
    
    var body: some View {
        List {
            // 🔥 遍历当前用户的帖子 (myDrops 是计算属性，会自动过滤)
            ForEach(viewModel.myDrops) { post in
                Button(action: {
                    // 点击跳转逻辑
                    viewModel.jumpToPost(post)
                    currentTab = .map
                }) {
                    HStack(spacing: 16) {
                        // 1. 左侧小图
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
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        // 2. 中间文字信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.title)
                                .font(.headline)
                                .foregroundStyle(.black)
                            
                            // 描述 & 爱心状态
                            HStack {
                                Text(post.caption)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                    .lineLimit(1)
                                
                                if post.isLiked {
                                    Image(systemName: "heart.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                            
                            // 分类 & 评分
                            HStack {
                                // 分类图标
                                Image(systemName: post.icon).font(.caption2)
                                Text(post.category.rawValue).font(.caption2).bold()
                                
                                // 🔥 新增：显示评分 (如果有)
                                if post.rating > 0 {
                                    Text("•").foregroundStyle(.gray.opacity(0.5))
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.yellow)
                                    Text(String(format: "%.0f", post.rating)) // 显示整数分，如 "5"
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                }
                            }
                            .foregroundStyle(Color(post.color))
                        }
                        
                        Spacer() // 撑开布局
                        
                        // 3. 右侧箭头
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.gray.opacity(0.5))
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                    // ✅ 关键修复：让整个横条（包括空白处）都能响应点击
                    .contentShape(Rectangle())
                }
                .listRowSeparator(.hidden)
                .buttonStyle(.plain) // 去掉默认按钮样式
            }
            // ✅ 删除功能
            .onDelete { indexSet in
                for index in indexSet {
                    // 必须从 myDrops 里取数据，保证删除的是正确的帖子
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
