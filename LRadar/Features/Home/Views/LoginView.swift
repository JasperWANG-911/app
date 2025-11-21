import SwiftUI
import FirebaseAuth // 🔥 引入 Firebase Auth

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
                .textInputAutocapitalization(.never) // 邮箱不要自动大写
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
            // 注册逻辑
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    print("注册成功！User ID: \(result?.user.uid ?? "")")
                    onLoginSuccess() // 通知父视图
                }
            }
        } else {
            // 登录逻辑
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    print("登录成功！")
                    onLoginSuccess() // 通知父视图
                }
            }
        }
    }
}

#Preview {
    LoginView(onLoginSuccess: {})
}
