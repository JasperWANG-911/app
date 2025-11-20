
import SwiftUI

// 好友页面 (FriendsView)
struct FriendsView: View {
    var body: some View {
        VStack {
            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple.gradient)
                .padding()
            Text("Friends List")
                .font(.title).bold()
            Text("Coming Soon...")
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}
