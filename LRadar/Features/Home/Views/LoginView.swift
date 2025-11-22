import SwiftUI
import FirebaseAuth

struct LoginView: View {
    // 状态变量
    @State private var email = ""
    @State private var password = ""
    
    // 注册专用字段
    @State private var inputName = ""
    @State private var inputUsername = ""
    @State private var inputMajor = ""
    
    @State private var isSignUpMode = false // 切换登录/注册模式
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var isLoading = false
    
    // 回调：登录成功后通知 ContentView
    var onLoginSuccess: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. 标题
                Text(isSignUpMode ? "Create Account" : "Welcome Back")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 20)
                
                // 2. 注册专用输入框
                if isSignUpMode {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Display Name (e.g. Jasper Wang)", text: $inputName)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Username (e.g. jasper_911)", text: $inputUsername)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: inputUsername) { _, newValue in
                                    inputUsername = newValue.filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                }
                            Text("Only letters, numbers, and underscores allowed.")
                                .font(.caption2).foregroundStyle(.gray)
                        }
                        
                        TextField("Major (Optional)", text: $inputMajor)
                            .textFieldStyle(.roundedBorder)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 3. 通用输入框
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
                .disabled(isButtonDisabled)
                
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
    
    var isButtonDisabled: Bool {
        if isLoading || email.isEmpty || password.isEmpty { return true }
        if isSignUpMode {
            return inputName.isEmpty || inputUsername.isEmpty
        }
        return false
    }
    
    func isValidUsername(_ name: String) -> Bool {
        let regex = "^[a-zA-Z0-9_]+$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: name)
    }
    
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
        
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters long."
            return
        }
        
        if isSignUpMode {
            let lowercasedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !lowercasedEmail.hasSuffix(".ac.uk") {
                errorMessage = "Registration is restricted to university emails ending in .ac.uk"
                return
            }
            if !isValidUsername(inputUsername) {
                errorMessage = "Username can only contain letters, numbers, and underscores."
                return
            }
        }
        
        isLoading = true
        
        if isSignUpMode {
            // --- 注册逻辑 ---
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error as NSError? {
                    isLoading = false
                    
                    // 🔥 核心修改：捕获“邮箱已注册”错误
                    if let errorCode = AuthErrorCode(rawValue: error.code), errorCode == .emailAlreadyInUse {
                        withAnimation {
                            errorMessage = "This email is already registered. Please Log In."
                            // 可选：如果你希望自动帮用户切回登录模式，可以取消下面这行的注释
                            // isSignUpMode = false
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    
                } else if let user = result?.user {
                    print("✅ 账号注册成功！UID: \(user.uid)")
                    
                    let detectedSchool = inferUniversity(from: email)
                    let finalMajor = inputMajor.isEmpty ? "" : inputMajor
                    
                    let newProfile = UserProfile(
                        id: user.uid,
                        name: inputName,
                        handle: "@\(inputUsername)",
                        school: detectedSchool,
                        major: finalMajor,
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
            // --- 登录逻辑 ---
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                isLoading = false
                if let error = error {
                    errorMessage = "Incorrect email or password." // 稍微优化了一下登录失败的文案
                    // 也可以用 error.localizedDescription 查看具体原因
                } else {
                    print("✅ 登录成功！")
                    onLoginSuccess()
                }
            }
        }
    }
}
