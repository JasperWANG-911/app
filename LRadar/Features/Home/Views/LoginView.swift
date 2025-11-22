import SwiftUI
import FirebaseAuth

struct LoginView: View {
    // 状态变量
    @State private var email = ""
    @State private var password = ""
    
    // 🔥 新增：注册专用字段
    @State private var inputName = ""      // 显示名称 (e.g. Jasper Wang)
    @State private var inputUsername = ""  // 用户名/Handle (e.g. jasper_01)
    @State private var inputMajor = ""     // 专业 (选填)
    
    @State private var isSignUpMode = false // 切换登录/注册模式
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var isLoading = false
    
    // 回调：登录成功后通知 ContentView
    var onLoginSuccess: () -> Void
    
    var body: some View {
        ScrollView { // 改用 ScrollView 防止键盘遮挡
            VStack(spacing: 20) {
                // 1. 标题
                Text(isSignUpMode ? "Create Account" : "Welcome Back")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 20)
                
                // 2. 注册专用输入框 (仅在注册模式显示)
                if isSignUpMode {
                    VStack(alignment: .leading, spacing: 12) {
                        // Name
                        TextField("Display Name (e.g. Jasper Wang)", text: $inputName)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                        
                        // Username
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Username (e.g. jasper_911)", text: $inputUsername)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: inputUsername) { _, newValue in
                                    // 实时过滤非法字符 (只允许英文、数字、下划线)
                                    inputUsername = newValue.filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                }
                            
                            Text("Only letters, numbers, and underscores allowed.")
                                .font(.caption2).foregroundStyle(.gray)
                        }
                        
                        // Major (选填)
                        TextField("Major (Optional)", text: $inputMajor)
                            .textFieldStyle(.roundedBorder)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 3. 通用输入框 (邮箱 & 密码)
                TextField("Email (must be .ac.uk for signup)", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                
                VStack(alignment: .leading, spacing: 4) {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    
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
                
                // 4. 错误与成功提示
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
                
                // 5. 登录/注册按钮
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
                .disabled(isButtonDisabled) // 使用计算属性判断
                
                // 6. 切换模式按钮
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
    }
    
    // 计算属性：判断按钮是否可用
    var isButtonDisabled: Bool {
        if isLoading || email.isEmpty || password.isEmpty { return true }
        if isSignUpMode {
            // 注册模式下，Name 和 Username 也是必填的
            return inputName.isEmpty || inputUsername.isEmpty
        }
        return false
    }
    
    // 正则校验 Username
    func isValidUsername(_ name: String) -> Bool {
        // 允许：a-z, A-Z, 0-9, _
        let regex = "^[a-zA-Z0-9_]+$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: name)
    }
    
    // ... (inferUniversity 和 handlePasswordReset 方法保持不变，直接复用原代码) ...
    // MARK: - 核心逻辑：大学名称自动推断
    func inferUniversity(from email: String) -> String {
        let lowerEmail = email.lowercased()
        let universityMapping: [String: String] = [
            "ucl.ac.uk": "UCL", "imperial.ac.uk": "Imperial College London", "kcl.ac.uk": "KCL",
            "lse.ac.uk": "LSE", "qmul.ac.uk": "Queen Mary University of London", "gold.ac.uk": "Goldsmiths, University of London",
            "city.ac.uk": "City, University of London", "brunel.ac.uk": "Brunel University London", "bbk.ac.uk": "Birkbeck, University of London",
            "soas.ac.uk": "SOAS University of London", "westminster.ac.uk": "University of Westminster", "arts.ac.uk": "UAL",
            "lsbu.ac.uk": "London South Bank University", "uel.ac.uk": "University of East London", "uwl.ac.uk": "University of West London",
            "londonmet.ac.uk": "London Metropolitan University", "mdx.ac.uk": "Middlesex University", "kingston.ac.uk": "Kingston University",
            "roehampton.ac.uk": "University of Roehampton", "sgul.ac.uk": "St George's, University of London",
            "rhul.ac.uk": "Royal Holloway, University of London", "gre.ac.uk": "University of Greenwich",
            "cam.ac.uk": "University of Cambridge", "ox.ac.uk": "University of Oxford"
        ]
        for (domain, name) in universityMapping {
            if lowerEmail.hasSuffix(domain) { return name }
        }
        if lowerEmail.hasSuffix(".ac.uk") { return "UK University" }
        return "Other University"
    }
    
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
            if let error = error { errorMessage = error.localizedDescription }
            else { successMessage = "Reset link sent! Check your email." }
        }
    }

    // MARK: - 登录/注册逻辑处理
    func handleAction() {
        errorMessage = ""
        successMessage = ""
        
        // 基础校验
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters long."
            return
        }
        
        if isSignUpMode {
            // 1. 邮箱后缀校验
            let lowercasedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !lowercasedEmail.hasSuffix(".ac.uk") {
                errorMessage = "Registration is restricted to university emails ending in .ac.uk"
                return
            }
            
            // 2. Username 格式校验 (双重保险)
            if !isValidUsername(inputUsername) {
                errorMessage = "Username can only contain letters, numbers, and underscores."
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
                    
                    let detectedSchool = inferUniversity(from: email)
                    
                    // 🔥 使用用户输入的数据创建 Profile
                    // 如果 Major 没填，存为空字符串 ""，不再存 "Undeclared"
                    let finalMajor = inputMajor.isEmpty ? "" : inputMajor
                    
                    let newProfile = UserProfile(
                        id: user.uid,
                        name: inputName,                // 用户输入的 Name
                        handle: "@\(inputUsername)",    // 用户输入的 Username (自动加 @)
                        school: detectedSchool,
                        major: finalMajor,              // 用户输入的 Major 或空
                        bio: "New to LRadar!",
                        avatarFilename: nil,
                        avatarURL: nil,
                        reputation: 10
                    )
                    
                    DataManager.shared.saveUserProfileToCloud(profile: newProfile)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isLoading = false
                        onLoginSuccess()
                    }
                }
            }
        } else {
            // --- 登录逻辑 (保持不变) ---
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
