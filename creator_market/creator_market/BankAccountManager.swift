import Foundation

class BankAccountManager: ObservableObject {
    @Published var linkedAccounts: [LinkedAccount] = []
    private let username: String
    @Published var isLoading: Bool = false
    @Published var lastVerified: Date?
    
    struct LinkedAccount: Identifiable, Codable {
        let id = UUID()
        let institutionName: String
        let accessToken: String
        let itemId: String
        let dateLinked: Date
        let userId: String // Add user association
    }
    
    init(username: String) {
        self.username = username
        loadAccounts()
    }
    
    func addAccount(name: String, token: String, itemId: String) {
        let newAccount = LinkedAccount(
            institutionName: name,
            accessToken: token,
            itemId: itemId,
            dateLinked: Date(),
            userId: username // Associate with current user
        )
        linkedAccounts.append(newAccount)
        saveAccounts()
    }
    
    func verifyLinkedAccounts(completion: @escaping (Bool) -> Void) {
            isLoading = true
            
            // Call your backend API to verify accounts
            let url = URL(string: "http://127.0.0.1:5000/api/verify-linked-accounts")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = ["username": username]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("Verification failed: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    guard let data = data,
                          let result = try? JSONDecoder().decode([String: [String]].self, from: data) else {
                        completion(false)
                        return
                    }
                    
                    // Get the valid account IDs from MongoDB
                    let validItemIds = result["valid_accounts"] ?? []
                    
                    // Filter out any locally stored accounts that aren't in MongoDB
                    self.linkedAccounts = self.linkedAccounts.filter { account in
                        validItemIds.contains(account.itemId)
                    }
                    
                    self.saveAccounts()
                    self.lastVerified = Date()
                    completion(true)
                }
            }.resume()
        }
    
    func removeAccountFromServer(accessToken: String, completion: @escaping (Bool, String) -> Void) {
        isLoading = true
        
        let url = URL(string: "http://127.0.0.1:5000/api/remove-linked-accounts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "username": username,
            "access_token": accessToken
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    completion(false, "No data received from server")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["message"] as? String {
                        if message == "Successfully Removed Account" {
                            // Remove from local storage
                            self.linkedAccounts.removeAll { $0.accessToken == accessToken }
                            self.saveAccounts()
                            completion(true, "Successfully removed account") // Cleaned up message
                        } else {
                            completion(false, message)
                        }
                    } else {
                        completion(false, "Invalid server response format")
                    }
                } catch {
                    completion(false, "Error parsing server response")
                }
            }
        }.resume()
    }
    
    private func saveAccounts() {
        // Only save accounts for this user
        let userAccounts = linkedAccounts.filter { $0.userId == username }
        if let encoded = try? JSONEncoder().encode(userAccounts) {
            UserDefaults.standard.set(encoded, forKey: "linkedBankAccounts_\(username)")
        }
    }
    
    private func loadAccounts() {
            if let data = UserDefaults.standard.data(forKey: "linkedBankAccounts_\(username)"),
               let decoded = try? JSONDecoder().decode([LinkedAccount].self, from: data) {
                linkedAccounts = decoded
                // Verify accounts when loading
                verifyLinkedAccounts { _ in }
            }
        }
    
    func removeAccount(accountId: UUID) {
        linkedAccounts.removeAll { $0.id == accountId }
        saveAccounts()
    }
}
