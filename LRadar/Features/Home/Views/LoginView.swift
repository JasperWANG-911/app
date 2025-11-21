import SwiftUI
import FirebaseAuth

struct LoginView: View {
    // 状态变量
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false // 切换登录/注册模式
    @State private var errorMessage = ""
    @State private var successMessage = "" // 成功提示（如重置邮件已发送）
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
            TextField("Email (must be .ac.uk for signup)", text: $email)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
            
            VStack(alignment: .leading, spacing: 4) {
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                
                // 密码规则提示
                if isSignUpMode {
                    Text("Password must be at least 6 characters.")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
            
            // 忘记密码按钮 (仅在登录模式显示)
            if !isSignUpMode {
                HStack {
                    Spacer()
                    Button("Forgot Password?") {
                        handlePasswordReset()
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
            
            // 3. 错误与成功提示
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            if !successMessage.isEmpty {
                Text(successMessage)
                    .foregroundStyle(.green)
                    .font(.caption)
                    .multilineTextAlignment(.center)
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
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            
            // 5. 切换模式按钮
            Button(action: {
                withAnimation {
                    isSignUpMode.toggle()
                    errorMessage = ""
                    successMessage = ""
                }
            }) {
                Text(isSignUpMode ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                    .font(.footnote)
            }
        }
        .padding()
    }
    
    // MARK: - 核心逻辑：大学名称自动推断
    func inferUniversity(from email: String) -> String {
        let lowerEmail = email.lowercased()
        
        // 伦敦及周边主要大学映射表
        let universityMapping: [String: String] = [
            "ucl.ac.uk": "UCL",
            "imperial.ac.uk": "Imperial College London",
            "kcl.ac.uk": "KCL",
            "lse.ac.uk": "LSE",
            "qmul.ac.uk": "Queen Mary University of London",
            "gold.ac.uk": "Goldsmiths, University of London",
            "city.ac.uk": "City, University of London",
            "brunel.ac.uk": "Brunel University London",
            "bbk.ac.uk": "Birkbeck, University of London",
            "soas.ac.uk": "SOAS University of London",
            "westminster.ac.uk": "University of Westminster",
            "arts.ac.uk": "UAL",
            "lsbu.ac.uk": "London South Bank University",
            "uel.ac.uk": "University of East London",
            "uwl.ac.uk": "University of West London",
            "londonmet.ac.uk": "London Metropolitan University",
            "mdx.ac.uk": "Middlesex University",
            "kingston.ac.uk": "Kingston University",
            "roehampton.ac.uk": "University of Roehampton",
            "sgul.ac.uk": "St George's, University of London",
            "rhul.ac.uk": "Royal Holloway, University of London",
            "gre.ac.uk": "University of Greenwich",
            // 补充几个著名的非伦敦大学，防止误判
            "cam.ac.uk": "University of Cambridge",
            "ox.ac.uk": "University of Oxford"
        ]
        
        // 遍历查找后缀匹配 (例如 student.ucl.ac.uk 也会匹配 ucl.ac.uk)
        for (domain, name) in universityMapping {
            if lowerEmail.hasSuffix(domain) {
                return name
            }
        }
        
        // 兜底：如果是其他 .ac.uk，但不在名单里
        if lowerEmail.hasSuffix(".ac.uk") {
            return "UK University"
        }
        
        return "Other University"
    }
    
    // MARK: - 忘记密码逻辑
    func handlePasswordReset() {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address first."
            return
        }
        
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                successMessage = "Reset link sent! Check your email."
            }
        }
    }
    
    // MARK: - 登录/注册逻辑处理
    func handleAction() {
        // 清除旧消息
        errorMessage = ""
        successMessage = ""
        
        // --- 1. 基础校验 ---
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters long."
            return
        }
        
        // --- 2. 注册时的特殊校验 ---
        if isSignUpMode {
            // 🔥 强制检查 .ac.uk 后缀
            let lowercasedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !lowercasedEmail.hasSuffix(".ac.uk") {
                errorMessage = "Registration is restricted to university emails ending in .ac.uk"
                return
            }
        }
        
        isLoading = true
        
        if isSignUpMode {
            // --- 注册逻辑 ---
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    isLoading = false
                    errorMessage = error.localizedDescription
                } else if let user = result?.user {
                    print("✅ 账号注册成功！UID: \(user.uid)")
                    
                    // 1. 自动推断信息
                    let defaultName = email.components(separatedBy: "@").first ?? "New User"
                    // 🔥 使用新逻辑自动填充学校
                    let detectedSchool = inferUniversity(from: email)
                    
                    let newProfile = UserProfile(
                        id: user.uid,
                        name: defaultName,
                        handle: "@\(defaultName)",
                        school: detectedSchool, // ✅ 自动填入
                        major: "Undeclared",
                        bio: "New to LRadar!",
                        rating: 5.0,
                        avatarFilename: nil,
                        avatarURL: nil
                    )
                    
                    // 2. 写入 Firestore
                    DataManager.shared.saveUserProfileToCloud(profile: newProfile)
                    
                    // 3. 延迟跳转
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isLoading = false
                        onLoginSuccess()
                    }
                }
            }
        } else {
            // --- 登录逻辑 ---
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
