import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @State var profileCopy: UserProfile
    // 回调：同时返回修改后的 Profile 和 新选的图片(如果有)
    var onSave: (UserProfile, UIImage?) -> Void
    
    // 状态
    @State private var imageSelection: PhotosPickerItem? = nil
    @State private var tempAvatarImage: UIImage? = nil // 临时显示图片
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. 头像编辑区
                    VStack(spacing: 12) {
                        PhotosPicker(selection: $imageSelection, matching: .images) {
                            ZStack {
                                // A. 优先显示刚选的临时图
                                if let temp = tempAvatarImage {
                                    Image(uiImage: temp)
                                        .resizable().scaledToFill()
                                        .frame(width: 100, height: 100).clipShape(Circle())
                                }
                                // B. 其次显示云端 URL (新增逻辑)
                                else if let avatarURL = profileCopy.avatarURL, let url = URL(string: avatarURL) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 100, height: 100).clipShape(Circle())
                                }
                                // C. 其次显示本地缓存 (兼容旧数据)
                                else if let filename = profileCopy.avatarFilename,
                                        let savedImage = DataManager.shared.loadImage(filename: filename) {
                                    Image(uiImage: savedImage)
                                        .resizable().scaledToFill()
                                        .frame(width: 100, height: 100).clipShape(Circle())
                                }
                                // D. 默认占位符
                                else {
                                    Circle().fill(Color(UIColor.secondarySystemBackground)).frame(width: 100, height: 100)
                                        .overlay(Image(systemName: "person.fill").foregroundStyle(.gray))
                                }
                                
                                Circle().fill(.black).frame(width: 32, height: 32)
                                    .overlay(Image(systemName: "camera.fill").foregroundStyle(.white).font(.caption))
                                    .offset(x: 35, y: 35)
                            }
                        }
                        Text("Change Photo").font(.caption).foregroundStyle(.blue)
                    }
                    .padding(.top, 20)
                    
                    // 2. 表单区域
                    VStack(alignment: .leading, spacing: 20) {
                        InputGroup(title: "Name", text: $profileCopy.name)
                        InputGroup(title: "Username", text: $profileCopy.handle)
                        
                        // 学校 (不可编辑)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("University (Verified)").font(.caption).foregroundStyle(.gray)
                            HStack {
                                Image(systemName: "graduationcap.fill").foregroundStyle(.gray)
                                Text(profileCopy.school).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "lock.fill").foregroundStyle(.gray.opacity(0.5)).font(.caption)
                            }
                            .padding(12).background(Color(UIColor.secondarySystemBackground).opacity(0.5)).cornerRadius(12)
                        }
                        
                        InputGroup(title: "Major", text: $profileCopy.major)
                        InputGroup(title: "Bio", text: $profileCopy.bio, isMultiLine: true)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.black)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onSave(profileCopy, tempAvatarImage) // 传回文字和图片
                        dismiss()
                    }
                    .bold().foregroundStyle(.black)
                }
            }
            // 处理图片选择
            .onChange(of: imageSelection) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        tempAvatarImage = uiImage // 只更新临时显示状态
                    }
                }
            }
        }
    }
}

struct InputGroup: View {
    let title: String
    @Binding var text: String
    var isMultiLine: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.gray)
            
            if isMultiLine {
                TextField("", text: $text, axis: .vertical)
                    .lineLimit(3...5).padding(12)
                    .background(Color(UIColor.secondarySystemBackground)).cornerRadius(12)
            } else {
                TextField("", text: $text)
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground)).cornerRadius(12)
            }
        }
    }
}
