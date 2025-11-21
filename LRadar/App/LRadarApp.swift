import SwiftUI
import FirebaseCore // 👈 引入 Firebase 核心库
import FirebaseAuth

// 1. 创建 AppDelegate 来进行初始化
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure() // 👈 这里启动 Firebase
    return true
  }
}

@main
struct LRadarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // 监听 Firebase 认证状态
    @State private var isUserLoggedIn = (Auth.auth().currentUser != nil)
    
    var body: some Scene {
        WindowGroup {
            if isUserLoggedIn {
                // 已登录，进入主界面
                ContentView()
            } else {
                // 未登录，显示登录页
                LoginView {
                    // 登录成功后的回调：切换状态
                    isUserLoggedIn = true
                }
            }
        }
    }
}
