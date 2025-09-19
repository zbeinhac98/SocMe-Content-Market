import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.presentationMode) var presentationMode
    var username: String
    @State private var isAcknowledged: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var hasAcceptedTerms: Bool = false
    @State private var isLoading: Bool = false
    
    init(username: String) {
        self.username = username
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("Terms of Service")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Terms of Service")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 20)
                    
                    Group {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("1. Acceptance of Terms")
                                .font(.headline)
                            Text("By using this application, you agree to be bound by these Terms of Service.")
                                .font(.body)
                            
                            Text("2. Description of Service")
                                .font(.headline)
                            Text("This application provides trading and investment tools, including account management and market analysis features.")
                                .font(.body)
                            
                            Text("3. User Responsibilities")
                                .font(.headline)
                            Text("You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account.")
                                .font(.body)
                            
                            Text("4. Investment Risks")
                                .font(.headline)
                            Text("All investments carry risk. Past performance does not guarantee future results. Please invest responsibly.")
                                .font(.body)
                            
                            Text("5. Privacy Policy")
                                .font(.headline)
                            Text("We are committed to protecting your privacy and personal information in accordance with applicable laws.")
                                .font(.body)
                        }
                        
                        VStack(alignment: .leading, spacing: 15) {
                            Text("6. Limitation of Liability")
                                .font(.headline)
                            Text("The service is provided 'as is' without warranties of any kind. We are not liable for any losses incurred through use of this application.")
                                .font(.body)
                            
                            Text("7. Termination")
                                .font(.headline)
                            Text("We reserve the right to terminate or suspend your account at any time for violation of these terms.")
                                .font(.body)
                            
                            Text("8. Changes to Terms")
                                .font(.headline)
                            Text("We reserve the right to modify these terms at any time. Continued use of the service constitutes acceptance of modified terms.")
                                .font(.body)
                        }
                    }
                    
                    if !hasAcceptedTerms {
                                            VStack(spacing: 20) {
                                                HStack {
                                                    Toggle(isOn: $isAcknowledged) {
                                                        Text("I acknowledge that I have read and agree to the Terms of Service")
                                                            .font(.body)
                                                    }
                                                    .toggleStyle(CheckboxToggleStyle())
                                                }
                                                
                                                Button(action: {
                                                    submitAcknowledgement()
                                                }) {
                                                    if isLoading {
                                                        ProgressView()
                                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    } else {
                                                        Text("Submit Acknowledgement")
                                                            .font(.headline)
                                                            .foregroundColor(.white)
                                                            .padding()
                                                            .frame(maxWidth: .infinity)
                                                            .background(isAcknowledged ? Color.blue : Color.gray)
                                                            .cornerRadius(10)
                                                    }
                                                }
                                                .disabled(!isAcknowledged || isLoading)
                                            }
                                            .padding(.top, 30)
                                        } else {
                                            Text("Thank you for accepting our Terms of Service")
                                                .font(.headline)
                                                .foregroundColor(.green)
                                                .padding(.top, 30)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding()
                                }
                            }
                            .navigationBarHidden(true)
                            .alert(isPresented: $showAlert) {
                                Alert(title: Text("Terms Acknowledgement"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                            }
                            .onAppear {
                                checkTermsStatus()
                            }
                        }
                        
                        private func checkTermsStatus() {
                            isLoading = true
                            sendRequestToServer(message: "terms \(username)") { response in
                                isLoading = false
                                if response == 1 {
                                    hasAcceptedTerms = true
                                } else {
                                    hasAcceptedTerms = false
                                }
                            }
                        }
                        
                        private func submitAcknowledgement() {
                            isLoading = true
                            sendRequestToServer(message: "check \(username)") { response in
                                isLoading = false
                                if response == 1 {
                                    hasAcceptedTerms = true
                                    alertMessage = "Terms accepted successfully!"
                                } else {
                                    alertMessage = "Failed to accept terms. Please try again."
                                }
                                showAlert = true
                            }
                        }
                        
                        private func sendRequestToServer(message: String, completion: @escaping (Int) -> Void) {
                            let url = URL(string: "http://127.0.0.1:5000/api/data")!
                            var request = URLRequest(url: url)
                            request.httpMethod = "POST"
                            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                            
                            let json: [String: Any] = ["message": message]
                            let jsonData = try? JSONSerialization.data(withJSONObject: json)
                            request.httpBody = jsonData
                            
                            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                                if let error = error {
                                    DispatchQueue.main.async {
                                        alertMessage = "Error: \(error.localizedDescription)"
                                        showAlert = true
                                        completion(0)
                                    }
                                    return
                                }
                                
                                if let data = data {
                                    do {
                                        if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                                           let responseValue = jsonResponse["acknowledged"] as? Int {
                                            DispatchQueue.main.async {
                                                completion(responseValue)
                                            }
                                            return
                                        }
                                    } catch {
                                        print("JSON parsing error: \(error)")
                                    }
                                }
                                
                                DispatchQueue.main.async {
                                    completion(0)
                                }
                            }
                            
                            task.resume()
                        }
                    }

                    // Keep the same CheckboxToggleStyle
                    struct CheckboxToggleStyle: ToggleStyle {
                        func makeBody(configuration: Configuration) -> some View {
                            HStack {
                                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(configuration.isOn ? .blue : .gray)
                                    .onTapGesture { configuration.isOn.toggle() }
                                
                                configuration.label
                            }
                        }
                    }
