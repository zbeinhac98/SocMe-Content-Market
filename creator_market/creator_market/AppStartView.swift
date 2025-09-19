// AppStartView.swift
import SwiftUI

struct AppStartView: View {
    @State private var isCheckingAuth = true
    @State private var isUserLoggedIn = false
    @State private var username = ""
    @State private var accountTotal: Double = 0.0  // Change type to Float to match ContentView
    
    var body: some View {
        Group {
            if isCheckingAuth {
                // Show loading view while checking auth status
                ProgressView("Loading...")
                    .onAppear {
                        checkAuthStatus()
                    }
            } else if isUserLoggedIn {
                // User is logged in - go to ContentView
                ContentView(username: username, accountTotal: accountTotal)
                    .transition(.opacity)
            } else {
                // User is not logged in - go to LoginView
                LoginView()
                    .transition(.opacity)
            }
        }
    }
    
    private func checkAuthStatus() {
        // Check auth status with a small delay to ensure UserDefaults is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if AuthManager.shared.isUserLoggedIn() {
                username = AuthManager.shared.getLoggedInUsername()
                
                // At this point, you might want to fetch the account total from local storage
                // or make an API call to get the latest value
                // For now, we're just initializing with 0
                accountTotal = 0.0
                
                isUserLoggedIn = true
            }
            isCheckingAuth = false
        }
    }
}
