import SwiftUI
import CoreLocation

// MARK: - 筛选弹窗视图
struct FilterSheetView: View {
    @Bindable var viewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // 顶部把手
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            
            Text("Filter Drops")
                .font(.title3).bold()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    
                    // 1. 时间筛选
                    FilterSection(title: "Time Posted") {
                        Picker("Time", selection: $viewModel.filterTime) {
                            ForEach(HomeViewModel.TimeFilter.allCases) { time in
                                Text(time.rawValue).tag(time)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // 2. 类型筛选
                    FilterSection(title: "Categories") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                            ForEach(PostCategory.allCases) { category in
                                CategoryPill(
                                    category: category,
                                    isSelected: viewModel.filterCategories.contains(category),
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            viewModel.toggleFilterCategory(category)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    // 3. 距离筛选
                    FilterSection(title: "Distance") {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("Distance", selection: $viewModel.filterDistance) {
                                ForEach(HomeViewModel.DistanceFilter.allCases) { dist in
                                    Text(dist.title).tag(dist)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            if LocationManager.shared.userLocation == nil && viewModel.filterDistance != .unlimited {
                                Text("⚠️ Enable location access to filter by distance")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    
                    // 4. 好友筛选 (暂时禁用)
                    FilterSection(title: "Content Source") {
                        HStack {
                            Toggle(isOn: $viewModel.filterFriendsOnly) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundStyle(.purple)
                                    Text("Friends Only")
                                        .fontWeight(.medium)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .purple))
                            .disabled(true) // 🔥 暂时禁用
                            
                            Spacer()
                            Text("Coming Soon")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .foregroundStyle(.gray)
                                .clipShape(Capsule())
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .opacity(0.6) // 视觉上也变灰一点
                    }
                }
                .padding(.horizontal)
            }
            
            // 底部按钮
            HStack(spacing: 16) {
                Button("Reset") {
                    withAnimation { viewModel.resetFilters() }
                }
                .foregroundStyle(.gray)
                .padding(.horizontal)
                
                Button(action: { dismiss() }) {
                    Text("Apply Filters")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(Color.white)
    }
}

// 辅助组件：筛选区块标题容器
struct FilterSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.gray)
                .textCase(.uppercase)
            content
        }
    }
}
