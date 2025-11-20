import SwiftUI

// 定义 Tab 枚举
enum Tab {
    case friends
    case map
    case profile
}

struct CustomTabBar: View {
    @Binding var currentTab: Tab
    var onAddTap: () -> Void // 当在地图页点击加号时的回调
    
    var body: some View {
        HStack {
            // --- 左侧：好友 ---
            Button(action: { currentTab = .friends }) {
                VStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 22))
                    Text("Friends").font(.caption2)
                }
                .foregroundStyle(currentTab == .friends ? .purple : .gray)
                .frame(maxWidth: .infinity)
            }
            
            // --- 中间：动态按钮 (智能切换) ---
            Button(action: {
                if currentTab == .map {
                    // 场景 A: 如果已经在地图页，执行“添加动态”逻辑
                    onAddTap()
                } else {
                    // 场景 B: 如果在其他页，执行“回到地图”逻辑
                    withAnimation {
                        currentTab = .map
                    }
                }
            }) {
                ZStack {
                    // 渐变背景圆
                    Circle()
                        .fill(
                            LinearGradient(
                                // 如果是回主页，颜色稍微变一下提示用户（可选，这里保持一致也很漂亮）
                                colors: [.purple, .pink, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: .purple.opacity(0.4), radius: 10, y: 5)
                    
                    // 核心修改：图标根据状态切换
                    Image(systemName: currentTab == .map ? "plus" : "map.fill") // 在地图页显示+, 其他页显示地图图标
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        // 加个简单的旋转动画效果 (可选)
                        .contentTransition(.symbolEffect(.replace))
                }
                .offset(y: -20)
            }
            .frame(maxWidth: .infinity)
            
            // --- 右侧：个人 ---
            Button(action: { currentTab = .profile }) {
                VStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 22))
                    Text("Profile").font(.caption2)
                }
                .foregroundStyle(currentTab == .profile ? .orange : .gray)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.white)
        .shadow(color: .black.opacity(0.05), radius: 5, y: -5)
    }
}

#Preview {
    CustomTabBar(currentTab: .constant(.profile), onAddTap: {})
}

