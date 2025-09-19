import SwiftUI

struct AccountCreationView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var registrationErrorMessage: String = ""
    @State private var emailErrorMessage: String = ""
    @State private var passwordErrorMessage: String = ""
    @State private var confirmPasswordErrorMessage: String = ""
    @State private var isRegistrationSuccessful: Bool = false
    @State private var accountTotal: Double = 0.0
    @State private var streetAddress: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zipCode: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var phoneNumber: String = ""
    @State private var addressErrorMessage: String = ""
    @State private var dobErrorMessage: String = ""
    @State private var phoneErrorMessage: String = ""
    @State private var isLoading: Bool = false
    
    private let usStates = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.blue)
                                .imageScale(.large)
                            Text("Back")
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                    .padding()

                    ScrollView {
                        VStack(spacing: 0) {
                            // Header
                            VStack(spacing: 8) {
                                Text("Create Account")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .padding(.bottom)
                                
                                Text("Join Content Market today")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 20)
                            
                            // Form Content
                            VStack(spacing: 24) {
                                // Personal Information Section
                                sectionCard(title: "Personal Information") {
                                    VStack(spacing: 16) {
                                        HStack(spacing: 12) {
                                            modernTextField("First Name", text: $firstName, icon: "person")
                                            modernTextField("Last Name", text: $lastName, icon: "person")
                                        }
                                        
                                        modernEmailField()
                                        modernTextField("Username", text: $username, icon: "person", autocapitalization: .none)
                                    }
                                }
                                
                                // Address Section
                                sectionCard(title: "Address") {
                                    VStack(spacing: 16) {
                                        modernTextField("Street Address", text: $streetAddress, icon: "house")
                                        
                                        HStack(spacing: 12) {
                                            modernTextField("City", text: $city, icon: "building.2")
                                            modernStatePicker()
                                        }
                                        
                                        modernTextField("Zip Code", text: $zipCode, icon: "number", keyboardType: .numberPad)
                                        
                                        if !addressErrorMessage.isEmpty {
                                            errorText(addressErrorMessage)
                                        }
                                    }
                                }
                                
                                // Personal Details Section
                                sectionCard(title: "Personal Details") {
                                    VStack(spacing: 16) {
                                        modernDatePicker()
                                        modernPhoneField()
                                    }
                                }
                                
                                // Security Section
                                sectionCard(title: "Security") {
                                    VStack(spacing: 16) {
                                        modernPasswordField()
                                        modernConfirmPasswordField()
                                    }
                                }
                                
                                // Submit Button
                                Button(action: handleSubmit) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Text("Submit")
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .foregroundColor(.white)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                                .disabled(isLoading)
                                .padding(.top, 8)
                                
                                // Error Message
                                if !registrationErrorMessage.isEmpty {
                                    errorText(registrationErrorMessage)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
                
                // Loading Overlay
                if isLoading {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {} // Prevent interaction
                }
            }
            
            // Keep the original NavigationLink structure exactly the same
            NavigationLink(
                destination: ContentView(username: username, accountTotal: accountTotal),
                isActive: $isRegistrationSuccessful
            ) {
                EmptyView()
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            content()
        }
        .padding(20)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func modernTextField(_ placeholder: String, text: Binding<String>, icon: String, autocapitalization: UITextAutocapitalizationType = .words, keyboardType: UIKeyboardType = .default) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            TextField(placeholder, text: text)
                .autocapitalization(autocapitalization)
                .disableAutocorrection(autocapitalization == .none)
                .keyboardType(keyboardType)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private func modernEmailField() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                TextField("Email", text: $email)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.emailAddress)
                    .onChange(of: email) { _ in validateEmail() }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if !emailErrorMessage.isEmpty {
                errorText(emailErrorMessage)
            }
        }
    }
    
    @ViewBuilder
    private func modernStatePicker() -> some View {
        Menu {
            Picker("Select State", selection: $state) {
                ForEach(usStates, id: \.self) { state in
                    Text(state).tag(state)
                }
            }
        } label: {
            HStack {
                Image(systemName: "map")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                Text(state.isEmpty ? "State" : state)
                    .foregroundColor(state.isEmpty ? .gray : .primary)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    @ViewBuilder
    private func modernDatePicker() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    .onChange(of: dateOfBirth) { _ in validateDateOfBirth() }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if !dobErrorMessage.isEmpty {
                errorText(dobErrorMessage)
            }
        }
    }
    
    @ViewBuilder
    private func modernPhoneField() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "phone")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                TextField("Phone Number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .onChange(of: phoneNumber) { newValue in
                        phoneNumber = filterPhoneNumber(newValue)
                        validatePhoneNumber()
                    }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if !phoneErrorMessage.isEmpty {
                errorText(phoneErrorMessage)
            }
        }
    }
    
    @ViewBuilder
    private func modernPasswordField() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lock")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                SecureField("Password", text: $password)
                    .onChange(of: password) { _ in validatePassword() }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if !passwordErrorMessage.isEmpty {
                errorText(passwordErrorMessage)
            }
        }
    }
    
    @ViewBuilder
    private func modernConfirmPasswordField() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .onChange(of: confirmPassword) { _ in validateConfirmPassword() }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if !confirmPasswordErrorMessage.isEmpty {
                errorText(confirmPasswordErrorMessage)
            }
        }
    }
    
    @ViewBuilder
    private func errorText(_ message: String) -> some View {
        Text(message)
            .foregroundColor(.red)
            .font(.caption)
    }

    // MARK: - Validation Functions (Kept exactly the same)
    
    func validateEmail() {
        // Basic email validation using a regular expression
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if email.isEmpty {
            emailErrorMessage = ""
        } else if !emailPredicate.evaluate(with: email) {
            emailErrorMessage = "Please enter a valid email address"
        } else {
            emailErrorMessage = ""
        }
    }
    
    func validatePassword() {
        var errorMessages: [String] = []
        
        // Check length
        if password.count < 8 {
            errorMessages.append("At least 8 characters")
        }
        
        // Check for at least one number
        if !password.contains(where: { $0.isNumber }) {
            errorMessages.append("At least one number")
        }
        
        // Check for at least one special character
        let specialCharacterSet = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")
        if password.rangeOfCharacter(from: specialCharacterSet) == nil {
            errorMessages.append("At least one special character")
        }
        
        // Set error message
        passwordErrorMessage = errorMessages.isEmpty ? "" : "Password must include:\n" + errorMessages.joined(separator: "\n")
        
        // Also validate confirm password when password changes
        validateConfirmPassword()
    }
    
    func validateConfirmPassword() {
        if password.isEmpty && confirmPassword.isEmpty {
            confirmPasswordErrorMessage = ""
        } else if password != confirmPassword {
            confirmPasswordErrorMessage = "Passwords do not match"
        } else {
            confirmPasswordErrorMessage = ""
        }
    }
    
    func validateAddress() {
        if streetAddress.isEmpty || city.isEmpty || state.isEmpty || zipCode.isEmpty {
            addressErrorMessage = "Please complete all address fields"
        } else if zipCode.count != 5 || Int(zipCode) == nil {
            addressErrorMessage = "Invalid Zip Code"
        } else if !usStates.contains(state) {
            addressErrorMessage = "Please select a valid state"
        } else {
            addressErrorMessage = ""
        }
    }

    func validateDateOfBirth() {
        let calendar = Calendar.current
        let eighteenYearsAgo = calendar.date(byAdding: .year, value: -18, to: Date()) ?? Date()
        
        if dateOfBirth > eighteenYearsAgo {
            dobErrorMessage = "You must be at least 18 years old"
        } else {
            dobErrorMessage = ""
        }
    }

    func validatePhoneNumber() {
        if phoneNumber.isEmpty {
            phoneErrorMessage = ""
        } else if phoneNumber.count < 10 || phoneNumber.count > 15 {
            phoneErrorMessage = "Please enter a valid phone number (10 digits)"
        } else {
            phoneErrorMessage = ""
        }
    }
    
    private func filterPhoneNumber(_ input: String) -> String {
        return input.filter { $0.isNumber }
    }
    
    func handleSubmit() {
        isLoading = true
        
        // Validate inputs
        validateEmail()
        validatePassword()
        validateConfirmPassword()
        validateAddress()
        validateDateOfBirth()
        validatePhoneNumber()
        
        // Check if any field is empty
        guard !firstName.isEmpty, !lastName.isEmpty, !email.isEmpty,
              !username.isEmpty, !password.isEmpty,
              !streetAddress.isEmpty, !city.isEmpty, !state.isEmpty, !zipCode.isEmpty,
              !phoneNumber.isEmpty else {
            registrationErrorMessage = "Please fill in all fields"
            isLoading = false
            return
        }
        
        // Additional validation checks
        guard emailErrorMessage.isEmpty else {
            registrationErrorMessage = "Please correct the email address"
            isLoading = false
            return
        }
        
        guard passwordErrorMessage.isEmpty else {
            registrationErrorMessage = "Please correct the password"
            isLoading = false
            return
        }
        
        guard confirmPasswordErrorMessage.isEmpty else {
            registrationErrorMessage = "Please ensure passwords match"
            isLoading = false
            return
        }
        
        guard addressErrorMessage.isEmpty else {
            registrationErrorMessage = "Please enter a valid address"
            isLoading = false
            return
        }

        guard dobErrorMessage.isEmpty else {
            registrationErrorMessage = "Please enter a valid date of birth"
            isLoading = false
            return
        }

        guard phoneErrorMessage.isEmpty else {
            registrationErrorMessage = "Please enter a valid phone number"
            isLoading = false
            return
        }
        
        // Define the URL of the Python server
        let url = URL(string: "http://127.0.0.1:5000/api/data")!
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dobString = dateFormatter.string(from: dateOfBirth)
        
        // Prepare the JSON data to send
        let json: [String: Any] = [
            "message": """
            1ab:\(username) firstName:\(firstName) lastName:\(lastName) email:\(email) password:\(password) \
            street:\(streetAddress) city:\(city) state:\(state) zip:\(zipCode) dob:\(dobString) phone:\(phoneNumber)
            """
        ]
        
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.httpBody = jsonData
        
        // Send the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.registrationErrorMessage = "Network Error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.registrationErrorMessage = "Invalid server response"
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    self.registrationErrorMessage = "Username or email exists. Please try again."
                    return
                }
                
                guard let data = data else {
                    self.registrationErrorMessage = "No data received from server"
                    return
                }
                
                do {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Raw Registration Response: \(responseString)")
                    }
                    
                    AuthManager.shared.loginUser(username: self.username)
                    self.isRegistrationSuccessful = true
                    self.registrationErrorMessage = ""
                } catch {
                    self.registrationErrorMessage = "Error parsing server response"
                }
            }
        }
        
        task.resume()
    }
}

struct AccountCreationView_Previews: PreviewProvider {
    static var previews: some View {
        AccountCreationView()
    }
}
