import SwiftUI

enum SortOption: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case mostLiked = "Most Liked"
    
    var id: String { self.rawValue }
}

struct MyDropsListView: View {
    var viewModel: HomeViewModel
    @Binding var currentTab: Tab
    
    @State private var sortOption: SortOption = .newest
    
    var sortedPosts: [Post] {
        switch sortOption {
        case .newest:
            return viewModel.myDrops.sorted { $0.timestamp > $1.timestamp }
        case .mostLiked:
            return viewModel.myDrops.sorted { $0.likeCount > $1.likeCount }
        }
    }
    
    var body: some View {
        List {
            ForEach(sortedPosts) { post in
                Button(action: {
                    viewModel.jumpToPost(post)
                    currentTab = .map
                }) {
                    HStack(spacing: 16) {
                        // 1. Thumbnail
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
                        
                        // 2. Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.title)
                                .font(.headline)
                                .foregroundStyle(.black)
                            
                            HStack {
                                // Like Count
                                Image(systemName: "heart.fill").font(.caption2).foregroundStyle(.gray)
                                Text("\(post.likeCount)").font(.caption).foregroundStyle(.gray)
                                
                                Text("•").foregroundStyle(.gray)
                                Text(post.category.rawValue).font(.caption).foregroundStyle(Color(post.color))
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .listRowSeparator(.hidden)
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let post = sortedPosts[index]
                    viewModel.deletePost(post)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("My Drops")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Label(option.rawValue, systemImage: icon(for: option)).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundStyle(.black)
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    func icon(for option: SortOption) -> String {
        switch option {
        case .newest: return "clock"
        case .mostLiked: return "heart.fill"
        }
    }
}
