import SwiftUI
import FirebaseCore
import FirebaseAuth

// 1. 使用 AppDelegate 初始化 Firebase (这是官方推荐的最稳妥方式)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("✅ Firebase Configured via AppDelegate")
        return true
    }
}

@main
struct LRadarApp: App {
    // 绑定 AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // 使用 AppStorage 持久化登录状态
    @AppStorage("isUserLoggedIn") private var isUserLoggedIn: Bool = false
    
    // 新增：一个临时的加载状态，防止白屏
    @State private var isCheckingAuth = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isCheckingAuth {
                    // A. 启动时的过渡画面 (防止白屏)
                    Color.white.ignoresSafeArea()
                    VStack {
                        ProgressView()
                            .controlSize(.large)
                        Text("LRadar")
                            .font(.headline)
                            .foregroundStyle(.gray)
                            .padding(.top, 8)
                    }
                } else {
                    // B. 检查完毕，根据状态显示主页或登录页
                    if isUserLoggedIn {
                        ContentView()
                    } else {
                        LoginView {
                            withAnimation {
                                isUserLoggedIn = true
                            }
                        }
                    }
                }
            }
            .onAppear {
                // 🔥 关键修改：在界面加载后，再检查用户状态
                checkUserStatus()
            }
        }
    }
    
    func checkUserStatus() {
        // 给 Firebase 一点点时间准备，避免竞争条件
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if Auth.auth().currentUser != nil {
                print("✅ 用户已登录")
                isUserLoggedIn = true
            } else {
                print("⚠️ 用户未登录")
                isUserLoggedIn = false
            }
            
            // 检查完成，关闭加载页，显示真实界面
            withAnimation {
                isCheckingAuth = false
            }
        }
    }
}
