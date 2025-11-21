import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @Bindable var viewModel: HomeViewModel
    @Binding var isUserLoggedIn: Bool
    
    // 状态控制
    @State private var showDeleteAlert = false
    @State private var showResetPasswordAlert = false
    @State private var resetPasswordMessage = ""
    @State private var notificationsEnabled = true // 这是一个 UI 演示状态，实际需结合系统权限
    
    // 获取当前版本号
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var userEmail: String {
        Auth.auth().currentUser?.email ?? "Unknown"
    }
    
    var body: some View {
        List {
            // MARK: - 1. 账号信息
            Section(header: Text("Account")) {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(userEmail)
                        .foregroundStyle(.gray)
                }
                
                Button(action: handlePasswordReset) {
                    Text("Reset Password")
                        .foregroundStyle(.blue)
                }
            }
            
            // MARK: - 2. 偏好设置
            Section(header: Text("Preferences")) {
                Toggle("Notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        // 这里可以加入实际的请求权限逻辑
                        if newValue {
                            // UNUserNotificationCenter.current().requestAuthorization...
                        }
                    }
                
                // 预留功能：清除缓存
                Button(action: {
                    // DataManager.shared.clearCache() // 未来实现
                }) {
                    Text("Clear Cache")
                        .foregroundStyle(.primary)
                }
            }
            
            // MARK: - 3. 关于与法律
            Section(header: Text("About")) {
                NavigationLink("Privacy Policy") {
                    ScrollView { Text("Privacy Policy content goes here...").padding() }
                        .navigationTitle("Privacy Policy")
                }
                
                NavigationLink("Terms of Service") {
                    ScrollView { Text("Terms of Service content goes here...").padding() }
                        .navigationTitle("Terms of Service")
                }
                
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
            }
            
            // MARK: - 4. 危险区域 (操作)
            Section {
                Button(role: .destructive, action: handleLogout) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Log Out")
                    }
                }
                
                Button(role: .destructive, action: { showDeleteAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Account")
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        
        // 弹窗处理
        .alert("Delete Account?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteAccount { success in
                    if success { isUserLoggedIn = false }
                }
            }
        } message: {
            Text("This will permanently delete your profile, posts, and data. This action cannot be undone.")
        }
        .alert("Password Reset", isPresented: $showResetPasswordAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(resetPasswordMessage)
        }
    }
    
    // MARK: - 辅助方法
    func handleLogout() {
        do {
            try Auth.auth().signOut()
            isUserLoggedIn = false
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    func handlePasswordReset() {
        if let email = Auth.auth().currentUser?.email {
            Auth.auth().sendPasswordReset(withEmail: email) { error in
                resetPasswordMessage = error?.localizedDescription ?? "Reset link sent to \(email)"
                showResetPasswordAlert = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewModel: HomeViewModel(), isUserLoggedIn: .constant(true))
    }
}
