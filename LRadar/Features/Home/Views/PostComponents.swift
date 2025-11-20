import SwiftUI

// 1. 地图上的头像气泡
struct PostAnnotationView: View {
    var color: Color
    var icon: String
    
    var body: some View {
        ZStack {
            // 针尖
            Image(systemName: "triangle.fill")
                .resizable().frame(width: 12, height: 10)
                .foregroundStyle(.white).rotationEffect(.degrees(180))
                .offset(y: 26).shadow(radius: 2)
            // 白底
            Circle().fill(.white).frame(width: 46, height: 46).shadow(radius: 4)
            // 彩色芯
            Circle().fill(color.gradient).frame(width: 38, height: 38)
                .overlay(Image(systemName: icon).foregroundStyle(.white).font(.caption).bold())
        }
        .offset(y: -26) // 修正偏移量
    }
}

// 2. 底部输入卡片
struct PostInputCard: View {
    @Binding var text: String
    var onCancel: () -> Void
    var onPost: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("New Drop").font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.gray.opacity(0.5))
                }
            }
            TextField("这里发生了什么？", text: $text)
                .textFieldStyle(.roundedBorder)
            
            Button(action: onPost) {
                Text("发布").bold().frame(maxWidth: .infinity).padding()
                    .background(text.isEmpty ? Color.gray.opacity(0.3) : Color.purple)
                    .foregroundStyle(.white).cornerRadius(12)
            }
            .disabled(text.isEmpty)
        }
        .padding(24)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 20)
        .padding(.horizontal).padding(.bottom, 20)
    }
}
