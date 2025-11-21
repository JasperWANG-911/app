import SwiftUI

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.black.opacity(0.8))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(radius: 5)
            .padding(.bottom, 50) // 距离底部的距离
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(100) // 保证浮在最上层
    }
}
