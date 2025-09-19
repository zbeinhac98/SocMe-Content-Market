import SwiftUI
import LinkKit

struct FundTransferView: View {
    var username: String
    var leftToUse: Double
    @StateObject private var bankAccountManager: BankAccountManager
    @State private var transferAmount: String = ""
    @State private var transferType: TransferType = .deposit
    @State private var selectedAccountId: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var plaidHandler: PLKHandler?
    @State private var verificationInProgress = false
    
    enum TransferType: String, CaseIterable {
            case deposit = "Deposit"
            case withdraw = "Withdraw"
        }
        
        init(username: String, leftToUse: Double) {
            self.username = username
            self.leftToUse = leftToUse
            self._bankAccountManager = StateObject(wrappedValue: BankAccountManager(username: username))
        }
    
    private let plaidServerURL = "http://localhost:5000"
    
    var body: some View {
        VStack {
            HStack {
                Text("Transfer Funds")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            
            Form {
                Section(header: Text("Bank Account")) {
                    if bankAccountManager.linkedAccounts.isEmpty {
                        NavigationLink(destination: BankAccountLinkView(username: username).environmentObject(bankAccountManager)) {
                            Text("Link Bank Account")
                                .foregroundColor(.blue)
                        }
                    } else {
                        Picker("Select Account", selection: $selectedAccountId) {
                            ForEach(bankAccountManager.linkedAccounts) { account in
                                Text(account.institutionName).tag(account.id.uuidString)
                            }
                        }
                        .onAppear {
                            selectedAccountId = bankAccountManager.linkedAccounts.first?.id.uuidString ?? ""
                        }
                    }
                }
                
                Section(header: Text("Transfer Type")) {
                    Picker("Transfer Type", selection: $transferType) {
                        ForEach(TransferType.allCases, id: \.self) { type in
                            Text(type.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Amount")) {
                    TextField("Enter amount", text: $transferAmount)
                        .keyboardType(.decimalPad)
                        .onChange(of: transferAmount) { newValue in
                            transferAmount = validateAmountInput(newValue)
                        }
                }
                
                Section {
                    Button(action: initiateTransfer) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Submit Transfer")
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                    .disabled(isLoading || bankAccountManager.linkedAccounts.isEmpty)
                }
                
                Section(header: Text("Account Management")) {
                    if !bankAccountManager.linkedAccounts.isEmpty {
                        Button(action: {
                            removeSelectedAccount()
                        }) {
                            Text("Remove Selected Account")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                        .disabled(selectedAccountId.isEmpty)
                    }
                }
                
            }
        }
        .environmentObject(bankAccountManager)
                .navigationBarTitle("Fund Transfer", displayMode: .inline)
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("Transfer Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                }
                .onAppear {
                    verifyAccounts()
                }
            }
            
            // MARK: - Private Methods
            
            private func verifyAccounts() {
                verificationInProgress = true
                bankAccountManager.verifyLinkedAccounts { success in
                    DispatchQueue.main.async {
                        verificationInProgress = false
                        if !success {
                            alertMessage = "Failed to verify account status. Please try again."
                            showAlert = true
                        }
                        // Update selected account if current selection became invalid
                        if !bankAccountManager.linkedAccounts.contains(where: { $0.id.uuidString == selectedAccountId }) {
                            selectedAccountId = bankAccountManager.linkedAccounts.first?.id.uuidString ?? ""
                        }
                    }
                }
            }
    
    // MARK: - Transfer Functionality
    
    private func initiateTransfer() {
        guard !bankAccountManager.linkedAccounts.isEmpty else {
            alertMessage = "Please link a bank account first"
            showAlert = true
            return
        }
        
        guard let amount = Double(transferAmount), amount > 0 else {
            alertMessage = "Please enter a valid amount"
            showAlert = true
            return
        }
        
        if transferType == .withdraw && amount > leftToUse {
            alertMessage = "Withdrawal amount exceeds your available balance"
            showAlert = true
            return
        }
        
        guard let account = bankAccountManager.linkedAccounts.first(where: { $0.id.uuidString == selectedAccountId }) else {
            alertMessage = "Please select a valid account"
            showAlert = true
            return
        }
        
        isLoading = true
        
        // First authorize the transfer
        authorizeTransfer(amount: amount, accessToken: account.accessToken) { authData in
            if let authData = authData {
                // Use the account_id returned from authorization
                self.createTransfer(amount: amount,
                                  authorizationId: authData.authorizationId,
                                  accountId: authData.accountId, // Use the correct account ID
                                  accessToken: account.accessToken) { success in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if success {
                            self.alertMessage = "\(self.transferType.rawValue) of $\(String(format: "%.2f", amount)) completed successfully"
                        } else {
                            self.alertMessage = "Failed to process \(self.transferType.rawValue.lowercased())"
                        }
                        self.showAlert = true
                        self.transferAmount = ""
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.alertMessage = "Failed to authorize transfer"
                    self.showAlert = true
                }
            }
        }
    }
    
    // Struct to hold authorization response data
    struct AuthorizationData {
        let authorizationId: String
        let accountId: String
    }
    
    private func authorizeTransfer(amount: Double, accessToken: String, completion: @escaping (AuthorizationData?) -> Void) {
        let urlString = "\(plaidServerURL)/api/transfer_authorize"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "access_token": accessToken,
            "amount": String(format: "%.2f", amount),
            "type": transferType == .deposit ? "credit" : "debit",
            "user_id": username
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("Authorization request body: \(requestBody)") // Debug print
        } catch {
            print("Error creating request body: \(error)")
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Authorization error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion(nil)
                return
            }
            
            // Print raw response for debugging
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw authorization response: \(rawResponse)")
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                print("Authorization JSON: \(String(describing: json))") // Debug print
                
                if let error = json?["error"] as? String {
                    print("Authorization failed: \(error)")
                    completion(nil)
                    return
                }
                
                guard let authorizationId = json?["authorization_id"] as? String,
                      let accountId = json?["account_id"] as? String else {
                    print("Missing authorization_id or account_id in response")
                    completion(nil)
                    return
                }
                
                let authData = AuthorizationData(authorizationId: authorizationId, accountId: accountId)
                completion(authData)
            } catch {
                print("JSON parsing error: \(error)")
                completion(nil)
            }
        }.resume()
    }

    private func createTransfer(amount: Double, authorizationId: String, accountId: String, accessToken: String, completion: @escaping (Bool) -> Void) {
        let urlString = "\(plaidServerURL)/api/transfer_create"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "access_token": accessToken,
            "authorization_id": authorizationId,
            "account_id": accountId, // Use the account ID from authorization response
            "amount": String(format: "%.2f", amount),
            "user_id": username,
            "type": transferType == .deposit ? "credit" : "debit"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("Transfer request body: \(requestBody)")
        } catch {
            print("Error creating request body: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Transfer error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion(false)
                return
            }
            
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw transfer response: \(rawResponse)")
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                print("Transfer JSON: \(String(describing: json))")
                
                if let error = json?["error"] as? String {
                    print("Transfer failed: \(error)")
                    completion(false)
                    return
                }
                
                guard let success = json?["success"] as? Bool else {
                    print("No success status in response")
                    completion(false)
                    return
                }
                
                completion(success)
            } catch {
                print("JSON parsing error: \(error)")
                completion(false)
            }
        }.resume()
    }
    
    private func removeSelectedAccount() {
        guard let selectedAccount = bankAccountManager.linkedAccounts.first(where: { $0.id.uuidString == selectedAccountId }) else {
            alertMessage = "Please select a valid account to remove"
            showAlert = true
            return
        }
        
        isLoading = true
        
        bankAccountManager.removeAccountFromServer(accessToken: selectedAccount.accessToken) { success, message in
            DispatchQueue.main.async {
                self.isLoading = false
                self.alertMessage = message // This will now be the clean message
                
                if success {
                    // Reset selection if needed
                    if self.bankAccountManager.linkedAccounts.isEmpty {
                        self.selectedAccountId = ""
                    } else if !self.bankAccountManager.linkedAccounts.contains(where: { $0.id.uuidString == self.selectedAccountId }) {
                        self.selectedAccountId = self.bankAccountManager.linkedAccounts.first?.id.uuidString ?? ""
                    }
                }
                
                self.showAlert = true
            }
        }
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
    
    private func validateAmountInput(_ input: String) -> String {
        // Remove any non-numeric characters except decimal point
        var filtered = input.filter { "0123456789.".contains($0) }
        
        // Ensure only one decimal point
        if filtered.filter({ $0 == "." }).count > 1 {
            filtered = String(filtered.dropLast())
        }
        
        // Limit to 2 decimal places
        if let dotIndex = filtered.firstIndex(of: ".") {
            let decimalPlaces = filtered[dotIndex...].dropFirst()
            if decimalPlaces.count > 2 {
                filtered = String(filtered.prefix(upTo: dotIndex) + "." + decimalPlaces.prefix(2))
            }
        }
        
        return filtered
    }
}

struct FundTransferView_Previews: PreviewProvider {
    static var previews: some View {
        FundTransferView(username: "testuser", leftToUse: 1000.0)
    }
}
