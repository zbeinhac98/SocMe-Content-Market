import SwiftUI

struct SettingsView: View {
    let username: String
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var originalPassword: String = ""
    @State private var originalEmail: String = ""
    @State private var passwordErrorMessage: String = ""
    @State private var confirmPasswordErrorMessage: String = ""
    // Address and phone fields
    @State private var streetAddress: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zipCode: String = ""
    @State private var phoneNumber: String = ""
    @State private var originalStreetAddress: String = ""
    @State private var originalCity: String = ""
    @State private var originalState: String = ""
    @State private var originalZipCode: String = ""
    @State private var originalPhoneNumber: String = ""
    @State private var addressErrorMessage: String = ""
    @State private var phoneErrorMessage: String = ""
    private let usStates = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
    ]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Manage your account information")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    
                    // Form Content
                    VStack(spacing: 24) {
                        // Personal Information Section
                        sectionCard(title: "Personal Information") {
                            VStack(spacing: 16) {
                                modernDisplayField("First Name", value: firstName, icon: "person")
                                modernDisplayField("Last Name", value: lastName, icon: "person")
                                modernEmailField()
                            }
                        }
                        
                        // Address Information Section
                        sectionCard(title: "Address Information") {
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
                        
                        // Phone Number Section
                        sectionCard(title: "Phone Number") {
                            VStack(spacing: 16) {
                                modernPhoneField()
                            }
                        }
                        
                        // Password Change Section
                        sectionCard(title: "Password Change") {
                            VStack(spacing: 16) {
                                modernSecureField("Current Password", text: $currentPassword, icon: "lock")
                                modernPasswordField()
                                modernConfirmPasswordField()
                            }
                        }
                        
                        // Save Button
                        Button(action: updateSettings) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Save Changes")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundColor(.white)
                            .background(hasChanges ? Color.blue : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading || !hasChanges)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            
            // Loading Overlay
            if isLoading {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {} // Prevent interaction
            }
        }
        .navigationBarTitle("Settings", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .foregroundColor(.blue)
            }
        )
        .onAppear {
            fetchUserSettings()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertMessage.isEmpty ? "Success" : "Error"),
                message: Text(alertMessage.isEmpty ? "Settings updated successfully!" : alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertMessage.isEmpty {
                        // Clear password fields on success
                        currentPassword = ""
                        newPassword = ""
                        confirmPassword = ""
                    }
                }
            )
        }
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
    private func modernDisplayField(_ placeholder: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            Text(placeholder)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private func modernTextField(_ placeholder: String, text: Binding<String>, icon: String, keyboardType: UIKeyboardType = .default) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private func modernSecureField(_ placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            
            SecureField(placeholder, text: text)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private func modernEmailField() -> some View {
        HStack {
            Image(systemName: "envelope")
                .foregroundColor(.gray)
                .frame(width: 20)
            
            TextField("Email", text: $email)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.emailAddress)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
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
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                SecureField("New Password", text: $newPassword)
                    .onChange(of: newPassword) { _ in
                        validatePassword()
                    }
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
                Image(systemName: "lock.rotation")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                SecureField("Confirm New Password", text: $confirmPassword)
                    .onChange(of: confirmPassword) { _ in
                        validateConfirmPassword()
                    }
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
    
    // MARK: - Computed Properties and Functions (Unchanged)
    
    private var hasChanges: Bool {
        let emailChanged = email != originalEmail
        let passwordChanged = !newPassword.isEmpty
        let addressChanged = streetAddress != originalStreetAddress ||
                            city != originalCity ||
                            state != originalState ||
                            zipCode != originalZipCode
        let phoneChanged = phoneNumber != originalPhoneNumber
        
        return emailChanged || passwordChanged || addressChanged || phoneChanged
    }
    
    private func fetchUserSettings() {
        isLoading = true
        let url = URL(string: "http://127.0.0.1:5000/api/data")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let json: [String: Any] = ["message": "settings \(username)"]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    alertMessage = "Error fetching settings: \(error.localizedDescription)"
                    showAlert = true
                }
                return
            }
            
            if let data = data {
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let settingsArray = jsonResponse["settings_array"] as? [String], settingsArray.count >= 9 {
                        
                        DispatchQueue.main.async {
                            originalPassword = settingsArray[0]
                            firstName = settingsArray[1]
                            lastName = settingsArray[2]
                            email = settingsArray[3]
                            originalEmail = settingsArray[3]
                            
                            // Address and phone information
                            streetAddress = settingsArray[4]
                            originalStreetAddress = settingsArray[4]
                            city = settingsArray[5]
                            originalCity = settingsArray[5]
                            state = settingsArray[6]
                            originalState = settingsArray[6]
                            zipCode = settingsArray[7]
                            originalZipCode = settingsArray[7]
                            phoneNumber = settingsArray[8]
                            originalPhoneNumber = settingsArray[8]
                        }
                    } else {
                        DispatchQueue.main.async {
                            alertMessage = "Invalid settings format received from server"
                            showAlert = true
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        alertMessage = "Failed to parse settings: \(error.localizedDescription)"
                        showAlert = true
                    }
                }
            }
        }
        
        task.resume()
    }
    
    private func validatePassword() {
        var errorMessages: [String] = []
        
        // Check length
        if !newPassword.isEmpty && newPassword.count < 8 {
            errorMessages.append("At least 8 characters")
        }
        
        // Check for at least one number
        if !newPassword.isEmpty && !newPassword.contains(where: { $0.isNumber }) {
            errorMessages.append("At least one number")
        }
        
        // Check for at least one special character
        let specialCharacterSet = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")
        if !newPassword.isEmpty && newPassword.rangeOfCharacter(from: specialCharacterSet) == nil {
            errorMessages.append("At least one special character")
        }
        
        // Set error message
        passwordErrorMessage = errorMessages.isEmpty ? "" : "Password must include:\n" + errorMessages.joined(separator: "\n")
        
        // Also validate confirm password when password changes
        validateConfirmPassword()
    }
    
    private func validateConfirmPassword() {
        if newPassword.isEmpty && confirmPassword.isEmpty {
            confirmPasswordErrorMessage = ""
        } else if newPassword != confirmPassword {
            confirmPasswordErrorMessage = "Passwords do not match"
        } else {
            confirmPasswordErrorMessage = ""
        }
    }
    
    private func validateAddress() {
        if streetAddress.isEmpty || city.isEmpty || state.isEmpty || zipCode.isEmpty {
            addressErrorMessage = "Please complete all address fields"
            return
        }
        
        if zipCode.count != 5 || Int(zipCode) == nil {
            addressErrorMessage = "Invalid Zip Code"
            return
        }
        
        if !usStates.contains(state) {
            addressErrorMessage = "Please select a valid state"
            return
        }
        
        addressErrorMessage = ""
    }
    
    private func validatePhoneNumber() {
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
    
    private func updateSettings() {
        // Validate email if changed
        if email != originalEmail {
            guard isValidEmail(email) else {
                alertMessage = "Please enter a valid email address"
                showAlert = true
                return
            }
        }
        
        // Validate address if changed
        if streetAddress != originalStreetAddress || city != originalCity || state != originalState || zipCode != originalZipCode {
            validateAddress()
            if !addressErrorMessage.isEmpty {
                alertMessage = addressErrorMessage
                showAlert = true
                return
            }
        }
        
        // Validate phone if changed
        if phoneNumber != originalPhoneNumber {
            validatePhoneNumber()
            if !phoneErrorMessage.isEmpty {
                alertMessage = phoneErrorMessage
                showAlert = true
                return
            }
        }
        
        // Validate password changes if new password is provided
        if !newPassword.isEmpty {
            // Check if new password meets requirements
            guard passwordErrorMessage.isEmpty else {
                alertMessage = "Please correct the password requirements"
                showAlert = true
                return
            }
            
            guard newPassword != currentPassword else {
                alertMessage = "New password must be different from current password"
                showAlert = true
                return
            }
            
            guard newPassword == confirmPassword else {
                alertMessage = "New passwords don't match"
                showAlert = true
                return
            }
            
            guard !currentPassword.isEmpty else {
                alertMessage = "Please enter your current password"
                showAlert = true
                return
            }
            
            guard currentPassword == originalPassword else {
                alertMessage = "Current password is incorrect"
                showAlert = true
                return
            }
        }
        
        isLoading = true
        
        let url = URL(string: "http://127.0.0.1:5000/api/data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prepare the message for the server
        let finalPassword = newPassword.isEmpty ? originalPassword : newPassword
        
        // Format message similar to the account creation view
        let message = "change_settings \(username) \(finalPassword) \(email) street:\(streetAddress) city:\(city) state:\(state) zip:\(zipCode) phone:\(phoneNumber)"
        
        let json: [String: Any] = [
            "message": message,
            "username": username,
            "new_password": finalPassword,
            "email": email,
            "street_address": streetAddress,
            "city": city,
            "state": state,
            "zip_code": zipCode,
            "phone_number": phoneNumber
        ]
        
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    alertMessage = "Error updating settings: \(error.localizedDescription)"
                    showAlert = true
                }
                return
            }
            
            if let data = data {
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let settingsArray = jsonResponse["settings_array"] as? [String], settingsArray.count >= 9 {
                        
                        DispatchQueue.main.async {
                            // Update all fields with the server's response
                            originalPassword = settingsArray[0]
                            firstName = settingsArray[1]
                            lastName = settingsArray[2]
                            email = settingsArray[3]
                            originalEmail = settingsArray[3]
                            
                            // Address and phone information
                            streetAddress = settingsArray[4]
                            originalStreetAddress = settingsArray[4]
                            city = settingsArray[5]
                            originalCity = settingsArray[5]
                            state = settingsArray[6]
                            originalState = settingsArray[6]
                            zipCode = settingsArray[7]
                            originalZipCode = settingsArray[7]
                            phoneNumber = settingsArray[8]
                            originalPhoneNumber = settingsArray[8]
                            
                            // Clear password fields
                            currentPassword = ""
                            newPassword = ""
                            confirmPassword = ""
                            
                            alertMessage = ""
                            showAlert = true
                        }
                    } else {
                        DispatchQueue.main.async {
                            alertMessage = "Invalid response format from server"
                            showAlert = true
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        alertMessage = "Failed to parse server response: \(error.localizedDescription)"
                        showAlert = true
                    }
                }
            }
        }
        
        task.resume()
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}
