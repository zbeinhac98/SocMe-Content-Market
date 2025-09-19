import SwiftUI

struct Order: Identifiable, Decodable {
    var id = UUID()
    let youtuberName: String
    let price: Double
    let shares: Double
    let timestamp: String
    let total: Double
    var isBuyOrder: Bool
    
    enum CodingKeys: String, CodingKey {
        case youtuberName = "youtuber_name"
        case price
        case shares
        case timestamp
        case total
    }
    
    init(youtuberName: String, price: Double, shares: Double, timestamp: String, total: Double, isBuyOrder: Bool) {
        self.youtuberName = youtuberName
        self.price = price
        self.shares = shares
        self.timestamp = timestamp
        self.total = total
        self.isBuyOrder = isBuyOrder
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        youtuberName = try container.decode(String.self, forKey: .youtuberName)
        
        // Handle price which might be String or Double
        if let stringPrice = try? container.decode(String.self, forKey: .price) {
            price = Double(stringPrice) ?? 0
        } else {
            price = try container.decode(Double.self, forKey: .price)
        }
        
        // Handle shares which might be String or Double
        if let stringShares = try? container.decode(String.self, forKey: .shares) {
            shares = Double(stringShares) ?? 0
        } else {
            shares = try container.decode(Double.self, forKey: .shares)
        }
        
        // Handle total which might be String or Double
        if let stringTotal = try? container.decode(String.self, forKey: .total) {
            total = Double(stringTotal) ?? 0
        } else {
            total = try container.decode(Double.self, forKey: .total)
        }
        
        timestamp = try container.decode(String.self, forKey: .timestamp)
        isBuyOrder = true // Will be set correctly after initialization
    }
}

struct OrdersView: View {
    let username: String
    @State private var buyOrders: [Order] = []
    @State private var sellOrders: [Order] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var noOrdersMessage: String? = nil
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
           ScrollView {  // Add ScrollView here
               ZStack {
                   // Main content
                   VStack(spacing: 0) {
                       // Buy Orders Section
                       if !buyOrders.isEmpty {
                           SectionHeader(title: "Buy Orders")
                           OrdersTable(orders: buyOrders, username: username, onOrderCancelled: fetchOrders)
                       }
                       
                       // Sell Orders Section
                       if !sellOrders.isEmpty {
                           SectionHeader(title: "Sell Orders")
                           OrdersTable(orders: sellOrders, username: username, onOrderCancelled: fetchOrders)
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
                           ErrorView(error: error, action: fetchOrders)
                           Spacer()
                       } else if let message = noOrdersMessage {
                           Spacer()
                           NoDataView(message: message)
                           Spacer()
                       }
                   }
                   .padding(.top)
                   .frame(maxWidth: .infinity)  // Ensure content takes full width
               }
           }
           .onAppear {
               fetchOrders()
           }
           .navigationBarTitle("Open Orders", displayMode: .inline)
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
    
    func fetchOrders() {
        isLoading = true
        errorMessage = nil
        noOrdersMessage = nil
        
        let url = URL(string: "http://127.0.0.1:5000/api/data")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let json: [String: Any] = ["message": "orders \(username)"]
        
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
                
                do {
                    // First parse the raw JSON to inspect structure
                    guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        self.errorMessage = "Invalid server response format"
                        return
                    }
                    
                    print("Orders response:", jsonResponse)
                    
                    // Parse buy orders
                    var parsedBuyOrders: [Order] = []
                    if let buyOrdersData = jsonResponse["buy_orders"] as? [[String: Any]] {
                        for orderDict in buyOrdersData {
                            do {
                                let jsonData = try JSONSerialization.data(withJSONObject: orderDict)
                                var order = try JSONDecoder().decode(Order.self, from: jsonData)
                                order.isBuyOrder = true
                                parsedBuyOrders.append(order)
                            } catch {
                                print("Error parsing buy order:", error)
                            }
                        }
                    }
                    
                    // Parse sell orders
                    var parsedSellOrders: [Order] = []
                    if let sellOrdersData = jsonResponse["sell_orders"] as? [[String: Any]] {
                        for orderDict in sellOrdersData {
                            do {
                                let jsonData = try JSONSerialization.data(withJSONObject: orderDict)
                                var order = try JSONDecoder().decode(Order.self, from: jsonData)
                                order.isBuyOrder = false
                                parsedSellOrders.append(order)
                            } catch {
                                print("Error parsing sell order:", error)
                            }
                        }
                    }
                    
                    self.buyOrders = parsedBuyOrders
                    self.sellOrders = parsedSellOrders
                    
                    if parsedBuyOrders.isEmpty && parsedSellOrders.isEmpty {
                        self.noOrdersMessage = "No open orders found"
                    } else {
                        print("Successfully parsed \(parsedBuyOrders.count) buy orders and \(parsedSellOrders.count) sell orders")
                    }
                } catch {
                    print("Error parsing orders:", error)
                    self.errorMessage = "Failed to parse orders data"
                }
            }
        }.resume()
    }
}

// MARK: - Subviews

struct OrdersTable: View {
    let orders: [Order]
    let username: String
    let onOrderCancelled: () -> Void
    
    // Adding loading state for cancel operation
    @State private var cancellingOrderId: UUID? = nil
    
    var body: some View {
        // Single horizontal scroll view for the entire table
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Symbol")
                        .frame(width: 80, alignment: .leading) // Increased from 70
                    
                    Text("Type")
                        .frame(width: 50, alignment: .leading) // Reduced from 60
                    
                    Text("Price")
                        .frame(width: 70, alignment: .trailing)
                    
                    Text("Shares")
                        .frame(width: 70, alignment: .trailing)
                    
                    Text("Value")
                        .frame(width: 80, alignment: .trailing)
                    
                    Text("Date")
                        .frame(width: 100, alignment: .leading)
                    
                    Text("")
                        .frame(width: 80, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .font(.caption)
                .foregroundColor(.gray)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.3))
                
                // Order rows
                ForEach(orders) { order in
                    VStack(spacing: 0) {
                        HStack {
                            Text(order.youtuberName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .leading)
                            
                            Text(order.isBuyOrder ? "Buy" : "Sell")
                                .font(.caption)
                                .foregroundColor(order.isBuyOrder ? .green : .red)
                                .frame(width: 50, alignment: .leading)
                            
                            Text("$\(String(format: "%.2f", order.price))")
                                .frame(width: 70, alignment: .trailing)
                            
                            Text(String(format: "%.2f", order.shares))
                                .frame(width: 70, alignment: .trailing)
                            
                            Text("$\(String(format: "%.2f", order.total))")
                                .frame(width: 80, alignment: .trailing)
                            
                            Text(formatTimestamp(order.timestamp))
                                .font(.caption)
                                .frame(width: 100, alignment: .leading)
                            
                            if cancellingOrderId == order.id {
                                // Show loading indicator when cancelling this specific order
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(width: 80, alignment: .center)
                            } else {
                                Button(action: {
                                    cancelOrder(order: order)
                                }) {
                                    Text("Cancel")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red)
                                        .cornerRadius(4)
                                }
                                .frame(width: 80, alignment: .center)
                            }
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
    
    private func formatTimestamp(_ timestamp: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz" // Matches "Sun, 11 May 2025 20:16:35 GMT"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = inputFormatter.date(from: timestamp) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "d MMM yyyy" // Outputs "11 May 2025"
            let formatted = outputFormatter.string(from: date)
            
            return formatted
        }
        
        // Fallback - manually clean up the string
        let components = timestamp.components(separatedBy: " ")
        guard components.count >= 4 else { return timestamp }
        return "\(components[1]) \(components[2]) \(components[3])" // Returns "11 May 2025"
    }
    
    private func cancelOrder(order: Order) {
        // Set the loading state for this order
        self.cancellingOrderId = order.id
        
        let message = "cancel \(username) \(order.youtuberName) \(order.isBuyOrder) \(order.timestamp)"
        
        let url = URL(string: "http://127.0.0.1:5000/api/data")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let json: [String: Any] = ["message": message]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    // Reset the loading state
                    self.cancellingOrderId = nil
                    
                    if let error = error {
                        print("Cancel order error:", error.localizedDescription)
                        return
                    }
                    
                    if let data = data {
                        if let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("Cancel order response:", response)
                            
                            // Call the onOrderCancelled callback to refresh the orders
                            self.onOrderCancelled()
                        }
                    }
                }
            }.resume()
        } catch {
            DispatchQueue.main.async {
                // Reset the loading state on error
                self.cancellingOrderId = nil
                print("Failed to prepare cancel request:", error)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            Spacer()
        }
        .background(Color.blue)
    }
}

struct ErrorView: View {
    let error: String
    let action: () -> Void
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
                .padding()
            
            Text(error)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Button(action: action) {
                Text("Try Again")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
}

struct NoDataView: View {
    let message: String
    
    var body: some View {
        VStack {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(.gray)
                .padding()
            
            Text(message)
                .font(.headline)
        }
    }
}

struct OrdersView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleBuyOrders = [
            Order(youtuberName: "MRBEAST", price: 105.50, shares: 10, timestamp: "2023-05-15 14:30:00", total: 1055.00, isBuyOrder: true),
            Order(youtuberName: "PEWDIEPIE", price: 95.75, shares: 5, timestamp: "2023-05-15 15:45:00", total: 478.75, isBuyOrder: true)
        ]
        
        let sampleSellOrders = [
            Order(youtuberName: "MRBEAST", price: 110.25, shares: 8, timestamp: "2023-05-15 09:15:00", total: 882.00, isBuyOrder: false),
            Order(youtuberName: "DREAM", price: 85.30, shares: 15, timestamp: "2023-05-14 16:20:00", total: 1279.50, isBuyOrder: false)
        ]
        
        NavigationView {
            OrdersView(username: "testuser")
        }
    }
}
