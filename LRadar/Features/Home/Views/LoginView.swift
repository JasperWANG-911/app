import SwiftUI
import FirebaseAuth

struct LoginView: View {
    // 状态变量
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false // 切换登录/注册模式
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    // 回调：登录成功后通知 ContentView
    var onLoginSuccess: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // 1. 标题
            Text(isSignUpMode ? "Create Account" : "Welcome Back")
                .font(.largeTitle)
                .bold()
                .padding(.bottom, 30)
            
            // 2. 输入框
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            // 3. 错误提示
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            // 4. 登录/注册按钮
            Button(action: handleAction) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(isSignUpMode ? "Sign Up" : "Log In")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLoading || email.isEmpty || password.count < 6)
            
            // 5. 切换模式按钮
            Button(action: {
                withAnimation {
                    isSignUpMode.toggle()
                    errorMessage = ""
                }
            }) {
                Text(isSignUpMode ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                    .font(.footnote)
            }
        }
        .padding()
    }
    
    // MARK: - 逻辑处理
    func handleAction() {
        isLoading = true
        errorMessage = ""
        
        if isSignUpMode {
            // 🔥 注册逻辑：注册成功后，立即去数据库建档
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    isLoading = false
                    errorMessage = error.localizedDescription
                } else if let user = result?.user {
                    print("✅ 账号注册成功！UID: \(user.uid)")
                    
                    // 1. 创建一个默认的用户资料
                    // 提取邮箱前缀作为默认昵称 (例如: jasper@ucl.ac.uk -> jasper)
                    let defaultName = email.components(separatedBy: "@").first ?? "New User"
                    
                    let newProfile = UserProfile(
                        id: user.uid, // ⚠️ 关键：必须用 Auth 返回的 uid
                        name: defaultName,
                        handle: "@\(defaultName)",
                        school: "UCL", // 默认值
                        major: "Undeclared",
                        bio: "New to LRadar!",
                        rating: 5.0,
                        avatarFilename: nil,
                        avatarURL: nil
                    )
                    
                    // 2. 写入 Firestore 的 'users' 集合
                    DataManager.shared.saveUserProfileToCloud(profile: newProfile)
                    
                    // 3. 稍微延迟一下，给写入一点时间，然后进入主页
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isLoading = false
                        onLoginSuccess()
                    }
                }
            }
        } else {
            // 登录逻辑 (保持不变)
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    print("✅ 登录成功！")
                    onLoginSuccess()
                }
            }
        }
    }
}

#Preview {
    LoginView(onLoginSuccess: {})
}
