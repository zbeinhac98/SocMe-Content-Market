import SwiftUI

struct Transaction: Identifiable {
    var id = UUID()
    let date: String
    let type: String
    let symbol: String?
    let amount: Double
}

struct TransactionHistoryView: View {
    let username: String
    @State private var transfers: [Transaction] = []
    @State private var buySellTransactions: [Transaction] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var noTransactionsMessage: String? = nil
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            ZStack {
                VStack(spacing: 0) {
                    // Transfers Section
                    if !transfers.isEmpty {
                        SectionHeader(title: "Deposits & Withdrawals")
                        TransfersTable(transactions: transfers)
                    }
                    
                    // Buy/Sell Transactions Section
                    if !buySellTransactions.isEmpty {
                        SectionHeader(title: "Buy & Sell History")
                        BuySellTable(transactions: buySellTransactions)
                    }
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                            .frame(minHeight: 200)
                        Spacer()
                    } else if let error = errorMessage {
                        Spacer()
                        ErrorView(error: error, action: fetchHistory)
                        Spacer()
                    } else if transfers.isEmpty && buySellTransactions.isEmpty {
                        Spacer()
                        NoDataView(message: "No transaction history found")
                        Spacer()
                    }
                }
                .padding(.top)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            fetchHistory()
        }
        .navigationBarTitle("Transaction History", displayMode: .inline)
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
    }
    
    // Replace the entire fetchHistory() function with this improved version:

    func fetchHistory() {
        isLoading = true
        errorMessage = nil
        noTransactionsMessage = nil
        
        let url = URL(string: "http://127.0.0.1:5000/api/data")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let json: [String: Any] = ["message": "history \(username)"]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Failed to prepare request"
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received"
                    return
                }
                
                // Debug: Print raw response
                let responseString = String(data: data, encoding: .utf8) ?? "Invalid data"
                print("Raw transaction history response:", responseString)
                
                do {
                    guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        self.errorMessage = "Invalid server response format"
                        return
                    }
                    
                    print("Parsed JSON Response:", jsonResponse)
                    print("Available keys:", Array(jsonResponse.keys))
                    
                    // Helper function to safely convert values to Double
                    func safeDoubleConversion(_ value: Any) -> Double? {
                        if let doubleValue = value as? Double {
                            return doubleValue
                        } else if let stringValue = value as? String {
                            return Double(stringValue)
                        } else if let intValue = value as? Int {
                            return Double(intValue)
                        } else if let floatValue = value as? Float {
                            return Double(floatValue)
                        } else {
                            // Handle Decimal or other numeric types by converting to string first
                            let stringRep = String(describing: value)
                            return Double(stringRep)
                        }
                    }
                    
                    // Parse transfer history
                    var parsedTransfers: [Transaction] = []
                    if let transferData = jsonResponse["transfer_array"] as? [[Any]] {
                        print("Found transfer_array with \(transferData.count) items")
                        for (index, transfer) in transferData.enumerated() {
                            print("Processing transfer \(index): \(transfer)")
                            
                            guard transfer.count >= 3,
                                  let date = transfer[0] as? String,
                                  let type = transfer[1] as? String else {
                                print("Skipping transfer \(index): invalid format")
                                continue
                            }
                            
                            guard let amount = safeDoubleConversion(transfer[2]) else {
                                print("Could not parse amount for transfer \(index): \(transfer[2])")
                                continue
                            }
                            
                            let transaction = Transaction(date: date, type: type, symbol: nil, amount: amount)
                            parsedTransfers.append(transaction)
                            print("Successfully parsed transfer: \(date), \(type), \(amount)")
                        }
                    } else {
                        print("No transfer_array found or invalid format")
                    }
                    
                    // Parse buy/sell history
                    var parsedBuySell: [Transaction] = []
                    if let buySellData = jsonResponse["buy_sell_array"] as? [[Any]] {
                        print("Found buy_sell_array with \(buySellData.count) items")
                        for (index, transaction) in buySellData.enumerated() {
                            print("Processing buy/sell \(index): \(transaction)")
                            
                            guard transaction.count >= 4,
                                  let date = transaction[0] as? String,
                                  let type = transaction[1] as? String,
                                  let symbol = transaction[2] as? String else {
                                print("Skipping buy/sell \(index): invalid format")
                                continue
                            }
                            
                            guard let amount = safeDoubleConversion(transaction[3]) else {
                                print("Could not parse amount for buy/sell \(index): \(transaction[3])")
                                continue
                            }
                            
                            let trans = Transaction(date: date, type: type, symbol: symbol, amount: amount)
                            parsedBuySell.append(trans)
                            print("Successfully parsed buy/sell: \(date), \(type), \(symbol), \(amount)")
                        }
                    } else {
                        print("No buy_sell_array found or invalid format")
                    }
                    
                    self.transfers = parsedTransfers
                    self.buySellTransactions = parsedBuySell
                    
                    print("Final result: \(parsedTransfers.count) transfers, \(parsedBuySell.count) buy/sell transactions")
                    
                    if parsedTransfers.isEmpty && parsedBuySell.isEmpty {
                        self.noTransactionsMessage = "No transaction history found"
                    }
                    
                } catch {
                    print("Error parsing transaction history:", error)
                    self.errorMessage = "Failed to parse transaction history: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

// MARK: - Subviews
// Replace just the TransfersTable struct with this version:

struct TransfersTable: View {
    let transactions: [Transaction]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Date")
                        .frame(width: 100, alignment: .leading)
                    
                    Text("Type")
                        .frame(width: 60, alignment: .leading)
                    
                    Text("")
                        .frame(width: 80, alignment: .leading)
                    
                    Text("Amount")
                        .frame(width: 100, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .font(.caption)
                .foregroundColor(.gray)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.3))
                
                // Transaction rows
                ForEach(transactions) { transaction in
                    VStack(spacing: 0) {
                        HStack {
                            Text(formatDate(transaction.date))
                                .font(.caption)
                                .frame(width: 100, alignment: .leading)
                            
                            Text(transaction.type.capitalized)
                                .font(.caption)
                                .foregroundColor(transaction.type == "deposit" ? .green : .red)
                                .frame(width: 60, alignment: .leading)
                            
                            Text("")
                                .frame(width: 80, alignment: .leading)
                            
                            Text("$\(String(format: "%.2f", transaction.amount))")
                                .font(.caption)
                                .frame(width: 100, alignment: .trailing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.2))
                    }
                }
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = inputFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMM d, yyyy"
            return outputFormatter.string(from: date)
        }
        return dateString
    }
}

struct BuySellTable: View {
    let transactions: [Transaction]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Date")
                        .frame(width: 100, alignment: .leading)
                    
                    Text("Type")
                        .frame(width: 60, alignment: .leading)
                    
                    Text("Symbol")
                        .frame(width: 80, alignment: .leading)
                    
                    Text("Amount")
                        .frame(width: 100, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .font(.caption)
                .foregroundColor(.gray)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.3))
                
                // Transaction rows
                ForEach(transactions) { transaction in
                    VStack(spacing: 0) {
                        HStack {
                            Text(formatDate(transaction.date))
                                .font(.caption)
                                .frame(width: 100, alignment: .leading)
                            
                            Text(transaction.type.capitalized)
                                .font(.caption)
                                .foregroundColor(transaction.type == "buy" ? .green : .red)
                                .frame(width: 60, alignment: .leading)
                            
                            Text(transaction.symbol ?? "")
                                .font(.caption)
                                .frame(width: 80, alignment: .leading)
                            
                            Text("$\(String(format: "%.2f", transaction.amount))")
                                .font(.caption)
                                .frame(width: 100, alignment: .trailing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.2))
                    }
                }
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        if let date = inputFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMM d, yyyy"
            return outputFormatter.string(from: date)
        }
        return dateString
    }
}

struct TransactionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleTransfers = [
            Transaction(date: "2025-07-28", type: "deposit", symbol: nil, amount: 100.0),
            Transaction(date: "2025-07-27", type: "withdrawal", symbol: nil, amount: 50.0)
        ]
        
        let sampleBuySell = [
            Transaction(date: "2025-07-28", type: "buy", symbol: "MRBEAST", amount: 105.50),
            Transaction(date: "2025-07-27", type: "sell", symbol: "PEWDIEPIE", amount: 95.75)
        ]
        
        NavigationView {
            TransactionHistoryView(username: "testuser")
        }
    }
}
