import SwiftUI
import LinkKit

struct BankAccountLinkView: View {
    var username: String
    @State private var linkStatus: String = ""
    @State private var isLoading: Bool = false
    @State private var linkedBankName: String = ""
    @State private var plaidHandler: PLKHandler? // Keeps the handler reference
    @SwiftUI.Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var bankAccountManager: BankAccountManager
    
    private let plaidServerURL = "http://localhost:5000"
    
    var body: some View {
            VStack {
                // Back button
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    Spacer()
                }
                
                Spacer()
                
                // Main content
                VStack(spacing: 32) {
                    // Bank icon
                    Image(systemName: "building.columns")
                        .font(.system(size: 80, weight: .light))
                        .foregroundColor(.blue)
                    
                    // Title and description
                    VStack(spacing: 16) {
                        Text("Connect Your Bank Account")
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)
                        
                        Text("Securely connect through Plaid.\nWe don't touch your banking information.")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    
                    // Status messages
                    if !linkStatus.isEmpty {
                        Text(linkStatus)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(linkStatus.contains("Success") ? .green : .red)
                            .multilineTextAlignment(.center)
                    }
                    
                    if !linkedBankName.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected to \(linkedBankName)")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Connect button
                    Button(action: startPlaidLink) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(linkedBankName.isEmpty ? "Connect Bank Account" : "Link Another Account")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isLoading ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 40)
                }
                
                Spacer()
                Spacer()
            }
            .navigationBarHidden(true)
        }
    
    // MARK: - All functionality remains exactly the same as the working version
    private func startPlaidLink() {
        isLoading = true
        linkStatus = ""
        
        createLinkToken { token in
            DispatchQueue.main.async {
                if let token = token {
                    self.openPlaidLink(with: token)
                } else {
                    self.linkStatus = "Failed to connect to Plaid"
                    self.isLoading = false
                }
            }
        }
    }

    private func openPlaidLink(with token: String) {
        let linkConfiguration = PLKLinkTokenConfiguration(
            token: token,
            onSuccess: { success in
                let institutionName = success.metadata.institution.name
                self.handlePlaidSuccess(success.publicToken, institutionName)
                self.plaidHandler = nil
            }
        )
        
        linkConfiguration.onEvent = { event in
            DispatchQueue.main.async {
                // Get the event name as a String
                let eventName = String(describing: event.eventName)
                
                if eventName == "HANDOFF" {
                    self.linkStatus = "Account verified - finalizing..."
                }
                // Check for custom exit
                else if eventName == "EXIT" {
                    // Access metadata through the event's metadata property
                    if let metadata = event.eventMetadata as? [String: Any],
                       let exitStatus = metadata["status"] as? String,
                       exitStatus == "USER_CUSTOM_EXIT" {
                        self.linkStatus = "Finishing connection..."
                    }
                }
            }
        }
        
        linkConfiguration.onExit = { exit in
            DispatchQueue.main.async {
                if let error = exit.error {
                    self.handlePlaidFailure(error.localizedDescription)
                } else {
                    self.handlePlaidExit()
                }
                self.plaidHandler = nil
            }
        }
        
        var error: NSError?
        guard let handler = PLKPlaid.createWithLinkTokenConfiguration(linkConfiguration, error: &error) else {
            self.linkStatus = "Failed to initialize Plaid"
            self.isLoading = false
            return
        }
        
        self.plaidHandler = handler
        
        if let viewController = getCurrentViewController() {
            handler.open(withContextViewController: viewController)
        } else {
            self.linkStatus = "Failed to present Plaid"
            self.isLoading = false
        }
    }
    
    private func getCurrentViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
    
    private func handlePlaidSuccess(_ publicToken: String, _ institutionName: String) {
        self.isLoading = true
        self.linkStatus = "Finalizing connection..."
        
        exchangePublicToken(publicToken) { success, accessToken, itemId in
            DispatchQueue.main.async {
                if success, let accessToken = accessToken, let itemId = itemId {
                    // Store in MongoDB via your server
                    self.storeBankAccountInBackend(
                        name: institutionName,
                        token: accessToken,
                        itemId: itemId
                    )
                    
                    // Also store locally
                    self.bankAccountManager.addAccount(
                        name: institutionName,
                        token: accessToken,
                        itemId: itemId
                    )
                    
                    self.linkStatus = "Successfully linked to \(institutionName)"
                    self.linkedBankName = institutionName
                } else {
                    self.linkStatus = "Failed to complete linking"
                    self.linkedBankName = ""
                }
                self.isLoading = false
            }
        }
    }

    private func storeBankAccountInBackend(name: String, token: String, itemId: String) {
        guard let url = URL(string: "\(plaidServerURL)/api/store_bank_account") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "user_id": username,
            "institution_name": name,
            "access_token": token,
            "item_id": itemId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("Error creating request body: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    private func handlePlaidFailure(_ error: String) {
        DispatchQueue.main.async {
            self.linkStatus = "Error: \(error)"
            self.isLoading = false
        }
    }
    
    private func handlePlaidExit() {
        DispatchQueue.main.async {
               self.linkStatus = ""
               self.linkedBankName = ""
               self.isLoading = false
           }
    }
    
    private func createLinkToken(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(plaidServerURL)/api/create_link_token") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["user_id": username]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["link_token"] as? String else {
                completion(nil)
                return
            }
            completion(token)
        }.resume()
    }
    
    private func exchangePublicToken(_ publicToken: String, completion: @escaping (Bool, String?, String?) -> Void) {
        guard let url = URL(string: "\(plaidServerURL)/api/set_access_token") else {
            print("Invalid URL for token exchange")
            completion(false, nil, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "public_token": publicToken,
            "user_id": username
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("Failed to encode request body: \(error)")
            completion(false, nil, nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Token exchange error: \(error)")
                completion(false, nil, nil)
                return
            }
            
            guard let data = data else {
                print("No data received in token exchange")
                completion(false, nil, nil)
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let accessToken = json?["access_token"] as? String
                let itemId = json?["item_id"] as? String
                
                if accessToken == nil || itemId == nil {
                    print("Missing access token or item ID in response: \(String(describing: json))")
                }
                
                completion(accessToken != nil && itemId != nil, accessToken, itemId)
            } catch {
                print("Failed to parse token exchange response: \(error)")
                completion(false, nil, nil)
            }
        }.resume()
    }
}

struct BankAccountLinkView_Previews: PreviewProvider {
    static var previews: some View {
        BankAccountLinkView(username: "testuser")
    }
}
