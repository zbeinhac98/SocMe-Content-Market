import SwiftUI

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var loginErrorMessage: String = ""
    @State private var isLoggedIn: Bool = false
    @State private var showAccountCreation: Bool = false
    @State private var accountTotal: Double = 0
    @State private var dailyTotalArray: [Double] = []
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack {
                    Spacer()
                        .frame(height: geometry.size.height * 0.15)
                    
                    Text("Content Market")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 20)
                    
                    VStack(spacing: 15) {
                        TextField("Username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        if !loginErrorMessage.isEmpty {
                            Text(loginErrorMessage)
                                .foregroundColor(.red)
                        }
                        
                        Button(action: {
                            authenticateUser()
                        }) {
                            Text("Login")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            showAccountCreation = true
                        }) {
                            Text("Create Account")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    NavigationLink(
                        destination: ContentView(username: username, accountTotal: accountTotal, dailyTotalArray: dailyTotalArray),
                        isActive: $isLoggedIn
                    ) {
                        EmptyView()
                    }
                    .hidden()
                    
                    NavigationLink(
                        destination: AccountCreationView(),
                        isActive: $showAccountCreation
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
                .navigationBarHidden(true)
                .onAppear {
                    // Check if user is already logged in
                    if AuthManager.shared.isUserLoggedIn() {
                        username = AuthManager.shared.getLoggedInUsername()
                        isLoggedIn = true
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarBackButtonHidden(true)
    }
    
    func authenticateUser() {
        let url = URL(string: "http://127.0.0.1:5000/api/data")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let json: [String: Any] = [
            "message": "loginusername=\(username) password:\(password)"
        ]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    loginErrorMessage = "Network Error: \(error.localizedDescription)"
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    loginErrorMessage = "Invalid server response"
                }
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    loginErrorMessage = "Login failed. Please check your credentials."
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    loginErrorMessage = "No data received from server"
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Raw Login Response: \(responseString)")
                    }
                    
                    // Parse accountTotal
                    let accountTotalValue = (json["accountTotal"] as? NSNumber)?.doubleValue ?? 0.0
                    
                    // Parse dailyTotalArray with multiple type checks
                    var dailyTotals: [Double] = []
                    if let floatArray = json["daily_total_array"] as? [Double] {
                        dailyTotals = floatArray
                    } else if let doubleArray = json["daily_total_array"] as? [Double] {
                        dailyTotals = doubleArray.map { Double($0) }
                    } else if let numberArray = json["daily_total_array"] as? [NSNumber] {
                        dailyTotals = numberArray.map { $0.doubleValue }
                    } else if let anyArray = json["daily_total_array"] as? [Any] {
                        dailyTotals = anyArray.compactMap { element in
                            if let num = element as? NSNumber {
                                return num.doubleValue
                            } else if let str = element as? String {
                                return Double(str)
                            }
                            return nil
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.accountTotal = accountTotalValue
                        self.dailyTotalArray = dailyTotals.isEmpty ? [accountTotalValue] : dailyTotals
                        
                        // Update auth state on successful login
                        AuthManager.shared.loginUser(username: username)
                        self.isLoggedIn = true
                        self.loginErrorMessage = ""
                        
                        print("Login successful - accountTotal: \(self.accountTotal), dailyTotalArray count: \(self.dailyTotalArray.count)")
                    }
                } else {
                    DispatchQueue.main.async {
                        loginErrorMessage = "Invalid response format"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    loginErrorMessage = "Error parsing server response: \(error.localizedDescription)"
                }
            }
        }
        
        task.resume()
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
