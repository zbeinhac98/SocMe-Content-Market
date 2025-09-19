import SwiftUI

struct FAQView: View {
    @Environment(\.presentationMode) var presentationMode
    
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
                
                Text("FAQ")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("FAQ")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 20)
                    
                    // Group the terms sections to avoid the 10-view limit
                    Group {
                        VStack(alignment: .leading, spacing: 15) {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Q: How do I link my bank account?")
                                    .font(.headline)
                                Text("A: Go to Menu > Link Bank Account and follow the secure verification process.")
                                    .font(.body)
                                
                                Text("Q: How often is my account total updated?")
                                    .font(.headline)
                                Text("A: Your account total is updated in real-time whenever you refresh the data.")
                                    .font(.body)
                                
                                Text("Q: What is the YouTuber search feature?")
                                    .font(.headline)
                                Text("A: You can search for YouTubers to view their stock-related content and performance metrics.")
                                    .font(.body)
                                
                                Text("Q: How do I place an order?")
                                    .font(.headline)
                                Text("A: Navigate to Menu > Orders to view and place new trading orders.")
                                    .font(.body)
                                
                                Text("Q: Is my financial data secure?")
                                    .font(.headline)
                                Text("A: Yes, we use bank-level encryption and security measures to protect your data.")
                                    .font(.body)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
    }
}
