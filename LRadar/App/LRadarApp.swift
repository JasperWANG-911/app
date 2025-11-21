import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct LRadarApp: App {
    // 1. 这里的 State 不要直接赋值，改为只声明类型
    @State private var isUserLoggedIn: Bool
    
    // 2. 添加 init 方法，确保初始化顺序
    init() {
        // 第一步：启动 Firebase (必须最先执行)
        FirebaseApp.configure()
        
        // 第二步：手动初始化 State
        // 这样确保了调用 Auth.auth() 时，Firebase 已经配置好了
        _isUserLoggedIn = State(initialValue: Auth.auth().currentUser != nil)
    }
    
    var body: some Scene {
        WindowGroup {
            if isUserLoggedIn {
                ContentView()
            } else {
                // 登录成功的回调
                LoginView {
                    isUserLoggedIn = true
                }
            }
        }
    }
}
