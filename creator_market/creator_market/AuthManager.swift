import Foundation
import SwiftUI

class AuthManager {
    static let shared = AuthManager()
    
    // Use in-memory storage instead of UserDefaults for session-only persistence
    private var isLoggedIn = false
    private var currentUsername = ""
    
    // Login the user and save their state (only for current session)
    func loginUser(username: String) {
        print("Logging in user: \(username)")
        isLoggedIn = true
        currentUsername = username
    }
    
    // Logout the user
    func logoutUser() {
        print("Logging out user")
        isLoggedIn = false
        currentUsername = ""
    }
    
    // Check if user is logged in (only for current session)
    func isUserLoggedIn() -> Bool {
        print("Checking login status: \(isLoggedIn)")
        return isLoggedIn
    }
    
    // Get the logged in username
    func getLoggedInUsername() -> String {
        print("Retrieved username: \(currentUsername)")
        return currentUsername
    }
}
