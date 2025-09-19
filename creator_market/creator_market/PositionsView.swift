import SwiftUI

struct Position: Identifiable, Decodable {
    var id = UUID()
    let symbol: String
    let name: String
    let accountId: Double // Added field for p_account
    let shares: Double
    let averagePrice: Double
    let currentPrice: Double
    let totalValue: Double
    let profitLoss: Double
    let percentChange: Double
    
    enum CodingKeys: String, CodingKey {
        case symbol, name, shares, accountId
        case averagePrice = "average_price"
        case currentPrice = "current_price"
        case totalValue = "total_value"
        case profitLoss = "profit_loss"
        case percentChange = "percent_change"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(String.self, forKey: .symbol)
        name = try container.decode(String.self, forKey: .name)
        accountId = try container.decodeIfPresent(Double.self, forKey: .accountId) ?? 0
        shares = try container.decode(Double.self, forKey: .shares)
        averagePrice = try container.decode(Double.self, forKey: .averagePrice)
        currentPrice = try container.decode(Double.self, forKey: .currentPrice)
        totalValue = try container.decode(Double.self, forKey: .totalValue)
        profitLoss = try container.decode(Double.self, forKey: .profitLoss)
        percentChange = try container.decode(Double.self, forKey: .percentChange)
    }
    
    // For preview data - updated to include accountId parameter
    init(symbol: String, name: String, accountId: Double, shares: Double, averagePrice: Double, currentPrice: Double, totalValue: Double, profitLoss: Double, percentChange: Double) {
        self.symbol = symbol
        self.name = name
        self.accountId = accountId
        self.shares = shares
        self.averagePrice = averagePrice
        self.currentPrice = currentPrice
        self.totalValue = totalValue
        self.profitLoss = profitLoss
        self.percentChange = percentChange
    }
}

struct PositionsView: View {
    let username: String
    @State private var positions: [Position] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var noStocksMessage: String? = nil
    @State private var navigateToChart: Bool = false
    @State private var selectedSymbol: String = ""
    @Environment(\.presentationMode) var presentationMode
    
    // Add states to store chart data
    @State private var chartLabels: [String] = []
    @State private var chartValues: [Double] = []
    @State private var stockAmountOwned: Double = 0
    @State private var cashToTrade: Double = 0
    @State private var isLoadingChartData: Bool = false
    @State private var nextBuyPrice: Double = 0
    @State private var nextSellPrice: Double = 0
    
    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 8) {
                        if isLoading {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.5)
                                .frame(minHeight: 200)
                            Spacer()
                        } else if let error = errorMessage {
                            Spacer()
                            VStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 50))
                                    .foregroundColor(.orange)
                                    .padding()
                                
                                Text(error)
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                
                                Button(action: {
                                    fetchPositions()
                                }) {
                                    Text("Try Again")
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                                .padding(.top)
                            }
                            .padding()
                            .frame(minHeight: 200)
                            Spacer()
                        } else if let noStocksMessage = noStocksMessage {
                            Spacer()
                            VStack {
                                Image(systemName: "tray")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                    .padding()
                                
                                Text(noStocksMessage)
                                    .font(.headline)
                            }
                            .frame(minHeight: 200)
                            Spacer()
                        } else {
                            // Single horizontal scroll view for the entire table
                            ScrollView(.horizontal, showsIndicators: false) {
                                VStack(spacing: 0) {
                                    // Header row
                                    HStack {
                                        Text("Symbol")
                                            .frame(width: 70, alignment: .leading)
                                        
                                        Text("Tot. P/L")
                                            .frame(width: 70, alignment: .trailing)
                                        
                                        Text("Day P/L")
                                            .frame(width: 70, alignment: .trailing)
                                        
                                        Text("% Acc")
                                            .frame(width: 50, alignment: .trailing)
                                        
                                        Text("Shares")
                                            .frame(width: 60, alignment: .trailing)
                                            .padding(.leading, 12)
                                        
                                        Text("Cost Basis")
                                            .frame(width: 70, alignment: .trailing)
                                            .offset(x: 6)
                                        
                                        Text("Price")
                                            .frame(width: 60, alignment: .trailing)
                                        
                                        Text("Value")
                                            .frame(width: 70, alignment: .trailing)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(Color.gray.opacity(0.3))
                                    
                                    // Position rows
                                    ForEach(positions) { position in
                                        VStack(spacing: 0) {
                                            HStack {
                                                // Symbol column with account ID underneath
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Button(action: {
                                                        selectedSymbol = position.symbol
                                                        fetchChartData(for: position.symbol)
                                                    }) {
                                                        Text(position.symbol)
                                                            .font(.caption)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(.blue)
                                                    }
                                                }
                                                .frame(width: 70, alignment: .leading)
                                                
                                                // Total P/L column
                                                Text("\(position.profitLoss >= 0 ? "+" : "")\(String(format: "$%.2f", position.profitLoss))")
                                                    .foregroundColor(position.profitLoss >= 0 ? .green : .red)
                                                    .frame(width: 70, alignment: .trailing)
                                                
                                                // Daily P/L column
                                                Text("\(position.percentChange >= 0 ? "+" : "")\(String(format: "$%.2f", position.percentChange))")
                                                    .foregroundColor(position.percentChange >= 0 ? .green : .red)
                                                    .frame(width: 70, alignment: .trailing)
                                                
                                                // % Acc column
                                                Text("\(String(format: "%.2f", Double(position.accountId)))%")
                                                    .frame(width: 50, alignment: .trailing)
                                                    .padding(.leading, 12)
                                                    . font(. system(size: 12))
                                                
                                                // Shares column
                                                Text(String(format: "%.2f", position.shares))
                                                    .frame(width: 60, alignment: .trailing)
                                                
                                                // Cost Basis column
                                                Text("$\(String(format: "%.2f", position.averagePrice))")
                                                    .frame(width: 70, alignment: .trailing)
                                                
                                                // Current price column
                                                Text("$\(String(format: "%.2f", position.currentPrice))")
                                                    .frame(width: 60, alignment: .trailing)
                                                
                                                // Total value column
                                                Text("$\(String(format: "%.2f", position.totalValue))")
                                                    .frame(width: 70, alignment: .trailing)
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
                            
                            // Summary - Added Daily Total Gain
                            VStack {
                                HStack {
                                    Text("Total Portfolio Value:")
                                        .fontWeight(.bold)
                                    Spacer()
                                    Text("$\(String(format: "%.2f", positions.reduce(0) { $0 + $1.totalValue }))")
                                        .fontWeight(.bold)
                                }
                                
                                HStack {
                                    Text("Total Profit/Loss:")
                                        .fontWeight(.bold)
                                    Spacer()
                                    let totalProfitLoss = positions.reduce(0) { $0 + $1.profitLoss }
                                    Text("\(totalProfitLoss >= 0 ? "+" : "")\(String(format: "$%.2f", totalProfitLoss))")
                                        .fontWeight(.bold)
                                        .foregroundColor(totalProfitLoss >= 0 ? .green : .red)
                                }
                                
                                // ADDED: Daily Total Gain
                                HStack {
                                    Text("Daily Total Gain:")
                                        .fontWeight(.bold)
                                    Spacer()
                                    let dailyTotalGain = positions.reduce(0) { $0 + $1.percentChange }
                                    Text("\(dailyTotalGain >= 0 ? "+" : "")\(String(format: "$%.2f", dailyTotalGain))")
                                        .fontWeight(.bold)
                                        .foregroundColor(dailyTotalGain >= 0 ? .green : .red)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            .padding()
                        }
                    }
                }
            }
            
            // Overlay loading indicator
            if isLoadingChartData {
                ZStack {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                        
                        Text("Loading chart data...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.7))
                    .cornerRadius(10)
                }
            }
        }
        .onAppear {
            fetchPositions()
        }
        
        // Hidden navigation link - updated to ensure proper navigation display
        .background(
            NavigationLink(
                destination:
                    ChartView(
                        labels: chartLabels,
                        values: chartValues,
                        userInput: selectedSymbol,
                        username: username,
                        amountOwned: stockAmountOwned,
                        cashToTrade: cashToTrade,
                        nextBuyPrice: nextBuyPrice,
                        nextSellPrice: nextSellPrice,
                        selectedPlatform: .youtube,
                        onNavigateBack: { fetchPositions() }
                    )
                    .navigationBarTitle(selectedSymbol, displayMode: .inline),
                isActive: $navigateToChart
            ) { EmptyView() }
            .isDetailLink(false)
        )
        // Configure navigation appearance for this view
        .navigationBarTitle("Positions", displayMode: .inline)
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
    
    // Function to fetch chart data for a specific symbol
    func fetchChartData(for symbol: String) {
        isLoadingChartData = true
        
        let url = URL(string: "http://127.0.0.1:5000/api/data")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let json: [String: Any] = ["message": "\(username) Youtuber: \(symbol)"]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        } catch {
            isLoadingChartData = false
            print("Failed to prepare request: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoadingChartData = false
                
                if let error = error {
                    print("Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("No data received from server")
                    return
                }
                
                // Print raw response for debugging
                let responseString = String(data: data, encoding: .utf8) ?? "Invalid data"
                print("Raw chart data response:", responseString)
                
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Handle string values that should be numbers
                        if let labels = jsonResponse["labels"] as? [String],
                           let values = jsonResponse["values"] as? [String] { // Changed to expect strings
                            
                            let floatValues = values.compactMap { Double($0) } // Convert strings to doubles
                            let cashToTrade = (jsonResponse["cash to trade"] as? String).flatMap(Double.init) ?? 0.0
                            let amountOwned = (jsonResponse["amount of stock owned"] as? String).flatMap(Double.init) ?? 0.0
                            let nextBuyPrice = (jsonResponse["next buy price"] as? String).flatMap(Double.init) ?? 0.0
                            let nextSellPrice = (jsonResponse["next sell price"] as? String).flatMap(Double.init) ?? 0.0
                            
                            guard !floatValues.isEmpty else {
                                print("Failed to convert values to numbers")
                                return
                            }
                            
                            self.chartLabels = labels
                            self.chartValues = floatValues
                            self.cashToTrade = cashToTrade
                            self.stockAmountOwned = amountOwned
                            self.nextBuyPrice = nextBuyPrice  // Add these properties to PositionsView
                            self.nextSellPrice = nextSellPrice // Add these properties to PositionsView
                            self.navigateToChart = true
                        } else {
                            print("Missing or invalid 'labels' or 'values' in the JSON response")
                        }
                    }
                } catch {
                    print("Error parsing response: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    func fetchPositions() {
        isLoading = true
        errorMessage = nil
        noStocksMessage = nil
        
        let url = URL(string: "http://127.0.0.1:5000/api/data")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let json: [String: Any] = ["message": "positions \(username)"]
        
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
                
                let responseString = String(data: data, encoding: .utf8) ?? "Invalid data"
                print("Raw server response:", responseString)
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let message = json["message"] as? String {
                            self.noStocksMessage = message
                            self.positions = []
                            return
                        }
                        
                        // Convert string arrays to double arrays
                        func convertStringArray(_ array: [String]) -> [Double] {
                            return array.compactMap { Double($0) }
                        }
                        
                        guard let stocks = json["stocks_owned"] as? [String],
                              let values = (json["current_value"] as? [String])?.compactMap({ Double($0) }) ?? json["current_value"] as? [Double],
                              let quantities = (json["quantity"] as? [String])?.compactMap({ Double($0) }) ?? json["quantity"] as? [Double],
                              let costBases = (json["cost_basis"] as? [String])?.compactMap({ Double($0) }) ?? json["cost_basis"] as? [Double],
                              let stockPrices = (json["current_stock_value"] as? [String])?.compactMap({ Double($0) }) ?? json["current_stock_value"] as? [Double],
                              let totalGainStocks = (json["total_gain_stock"] as? [String])?.compactMap({ Double($0) }) ?? json["total_gain_stock"] as? [Double],
                              let dailyGainStocks = (json["daily_gain_stock"] as? [String])?.compactMap({ Double($0) }) ?? json["daily_gain_stock"] as? [Double],
                              let accountIds = (json["p_account"] as? [String])?.compactMap({ Double($0) }) ?? json["p_account"] as? [Double] else {
                            self.errorMessage = "Missing required fields in response"
                            return
                        }
                        
                        var newPositions: [Position] = []
                        for i in 0..<stocks.count {
                            guard i < values.count &&
                                  i < quantities.count &&
                                  i < costBases.count &&
                                  i < stockPrices.count &&
                                  i < totalGainStocks.count &&
                                  i < dailyGainStocks.count &&
                                  i < accountIds.count else {
                                continue
                            }
                            
                            let position = Position(
                                symbol: stocks[i],
                                name: "\(stocks[i]) Account",
                                accountId: accountIds[i],
                                shares: quantities[i],
                                averagePrice: costBases[i],
                                currentPrice: stockPrices[i],
                                totalValue: values[i],
                                profitLoss: totalGainStocks[i],
                                percentChange: dailyGainStocks[i]
                            )
                            newPositions.append(position)
                        }
                        
                        self.positions = newPositions
                        self.errorMessage = newPositions.isEmpty ? "No valid positions found" : nil
                    }
                } catch {
                    self.errorMessage = "Error parsing response: \(error.localizedDescription)"
                }
            }
        }
        .resume()
    }

    private func tryManualParsing(data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Check for message first
                if let message = json["message"] as? String {
                    self.noStocksMessage = message
                    self.positions = []
                    return
                }
                
                // Extract arrays and single values manually
                guard let stocks = json["stocks_owned"] as? [String],
                      let values = json["current_value"] as? [Double],
                      let stockPrices = json["current_stock_value"] as? [Double],
                      let quantities = json["quantity"] as? [Double],
                      let accountIds = json["p_account"] as? [Double],
                      let costBases = json["cost_basis"] as? [Double],
                      let totalGainStocks = json["total_gain_stock"] as? [Double],
                      let dailyGainStocks = json["daily_gain_stock"] as? [Double] else {
                    print("Manual parsing failed: missing or invalid data")
                    return
                }
                
                print("Manual parsing successful")
                
                var newPositions: [Position] = []
                
                for i in 0..<min(stocks.count, values.count, stockPrices.count, quantities.count,
                                accountIds.count, costBases.count, totalGainStocks.count, dailyGainStocks.count) {
                    
                    let displayName = "\(stocks[i]) Account"
                    let totalValue = values[i]
                    let currentPrice = stockPrices[i]
                    
                    let position = Position(
                        symbol: stocks[i],
                        name: displayName,
                        accountId: accountIds[i],
                        shares: quantities[i],
                        averagePrice: costBases[i],
                        currentPrice: currentPrice,
                        totalValue: totalValue,
                        profitLoss: totalGainStocks[i],
                        percentChange: dailyGainStocks[i]
                    )
                    newPositions.append(position)
                }
                
                if !newPositions.isEmpty {
                    self.positions = newPositions
                    self.errorMessage = nil
                    print("Created \(newPositions.count) positions via manual parsing")
                }
            }
        } catch {
            print("Manual JSON parsing failed: \(error)")
        }
    }
}

struct PositionsView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview with navigation context
        NavigationView {
            PositionsView(username: "PreviewUser")
        }
    }
}
