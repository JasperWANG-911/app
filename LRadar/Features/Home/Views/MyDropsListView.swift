import SwiftUI
import MapKit

// 注意：HomeViewModel, Post, Tab, DataManager 必须在其他文件里定义且可见

struct MyDropsListView: View {
    // 接收 ViewModel 和 Tab 绑定
    var viewModel: HomeViewModel
    @Binding var currentTab: Tab
    
    var body: some View {
        List {
            ForEach(viewModel.posts) { post in
                // 整个 Row 作为一个按钮，点击跳转
                Button(action: {
                    // 1. 镜头飞过去
                    viewModel.jumpToPost(post)
                    // 2. 切换 Tab
                    currentTab = .map
                }) {
                    HStack(spacing: 16) {
                        // 左侧小图
                        ZStack {
                            // ⚠️ 修改点：取第一张图作为缩略图
                            if let filename = post.imageFilenames.first,
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
                            Text(post.caption).font(.caption).foregroundStyle(.gray).lineLimit(1)
                            HStack {
                                Image(systemName: post.icon).font(.caption2)
                                Text(post.category.rawValue).font(.caption2).bold()
                            }.foregroundStyle(Color(post.color))
                        }
                        
                        Spacer()
                        
                        // 右侧定位图标
                        Image(systemName: "location.fill")
                            .foregroundStyle(Color.blue.opacity(0.6))
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                .listRowSeparator(.hidden)
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .navigationTitle("My Drops")
        .navigationBarTitleDisplayMode(.inline)
    }
}
