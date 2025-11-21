import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct LRadarApp: App {
    // 🔥 修改 1: 改用 AppStorage，这样可以在 ProfileView 里修改它
    @AppStorage("isUserLoggedIn") private var isUserLoggedIn: Bool = false
    
    init() {
        FirebaseApp.configure()
        
        // 🔥 修改 2: 启动时检查 Firebase 真实状态，同步给 AppStorage
        // 如果 Firebase 认为没登录，就强制设为 false
        if Auth.auth().currentUser != nil {
            UserDefaults.standard.set(true, forKey: "isUserLoggedIn")
        } else {
            UserDefaults.standard.set(false, forKey: "isUserLoggedIn")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if isUserLoggedIn {
                ContentView()
            } else {
                LoginView {
                    // 登录成功回调
                    isUserLoggedIn = true
                }
            }
        }
    }
}
