import SwiftUI
import DGCharts

struct ChartView: View {
    @State var labels: [String]
    @State var values: [Double]
    var userInput: String
    var username: String
    @State var amountOwned: Double
    @State var cashToTrade: Double
    @State var nextBuyPrice: Double = 0
    @State var nextSellPrice: Double = 0
    var selectedPlatform: ContentView.Platform
    @Environment(\.presentationMode) var presentationMode
    // Add an onNavigateBack callback
    var onNavigateBack: () -> Void
    
    @State private var selectedRange: TimeRange = .oneMonth // Default selection
    @State private var filteredLabels: [String] = []
    @State private var filteredValues: [Double] = []
    @State private var buyResponseMessage: String = ""
    @State private var showBuyResponse: Bool = false
    @State private var showBuyPopup: Bool = false
    @State private var showSellPopup: Bool = false
    @State private var buyAmount: String = ""
    @State private var sellAmount: String = ""
    @State private var currentPrice: Double = 0
    @State private var showBuyLimitPopup: Bool = false
    @State private var showSellLimitPopup: Bool = false
    @State private var orderType: String = "market"
    @State private var limitPrice: String = ""
    
    private var isBuyAmountValid: Bool {
        // Check if input matches the pattern of numbers with up to 2 decimal places
        let pattern = "^\\d+(\\.\\d{0,2})?$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        
        // Check if the input is valid and greater than 0
        if let amount = Float(buyAmount), amount > 0, predicate.evaluate(with: buyAmount) && !buyAmount.isEmpty {
            return true
        }
        return false
    }
    
    private var isLimitPriceValid: Bool {
            // Same validation as for buy/sell amounts
            let pattern = "^\\d+(\\.\\d{0,2})?$"
            let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
            
            if let price = Float(limitPrice), price > 0, predicate.evaluate(with: limitPrice) && !limitPrice.isEmpty {
                return true
            }
            return false
        }
    
    private var isSellAmountValid: Bool {
        // Check if input matches the pattern of numbers with up to 2 decimal places
        let pattern = "^\\d+(\\.\\d{0,2})?$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        
        // Check if the input is valid and greater than 0
        if let amount = Float(sellAmount), amount > 0, predicate.evaluate(with: sellAmount) && !sellAmount.isEmpty {
            return true
        }
        return false
    }
    
    // Enum to represent the different time ranges
    enum TimeRange: String, CaseIterable {
        case oneDay = "1D"
        case fiveDay = "5D"
        case oneMonth = "1M"
        case threeMonth = "3M"
        case oneYear = "1Y"
        
        // Helper to get the number of days to look back
        var daysToSubtract: Int {
            switch self {
            case .oneDay: return 1
            case .fiveDay: return 5
            case .oneMonth: return 30
            case .threeMonth: return 90
            case .oneYear: return 365
            }
        }
    }
    
    var body: some View {
        ZStack {
            let _ = print("ChartView received amountOwned: \(amountOwned)")
            ScrollView {
                VStack {
                    // Title and Cash to Trade display
                    VStack(spacing: 6) {
                        // Cash to Trade display
                        HStack {
                            Text("Available Cash to Trade:")
                                .font(.headline)
                            Text(String(format: "$%.2f", cashToTrade))
                                .font(.headline)
                                .foregroundColor(.green)
                            Text("Amount of Stock Owned:")
                                .font(.headline)
                            Text(String(format: "$%.2f", amountOwned))
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Smaller time range selector buttons
                    HStack(spacing: 6) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Button(action: {
                                selectedRange = range
                                filterChartDataByRange(range)
                            }) {
                                Text(range.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(selectedRange == range ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedRange == range ? .white : .primary)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)

                    // Chart view
                    ChartViewRepresentable(labels: filteredLabels.isEmpty ? labels : filteredLabels,
                                           values: filteredValues.isEmpty ? values : filteredValues)
                        .id("chart_\(filteredLabels.count)_\(filteredValues.count)_\(values.count)")  // Updated ID with values.count
                        .frame(height: 300)
                        .padding()
                    
                    // Display the last value from the filtered values array
                    if let lastValue = (filteredValues.isEmpty ? values : filteredValues).last {
                        HStack {
                            Text("\(selectedPlatform.rawValue) Last Executed Price:")
                                .font(.headline)
                            Text(String(format: "$%.2f", currentPrice == 0 ? (filteredValues.isEmpty ? values.last ?? 0 : filteredValues.last ?? 0) : currentPrice))
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 8)
                    } else {
                        Text("No data available")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
            
                    HStack {
                        Text("Next Buy Price:")
                            .font(.subheadline)
                        Text(String(format: "$%.2f", nextBuyPrice))
                            .font(.subheadline)
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        Text("Next Sell Price:")
                            .font(.subheadline)
                        Text(String(format: "$%.2f", nextSellPrice))
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding(.top, 4)
                    
                    // Buy and Sell buttons
                    VStack(spacing: 12) {
                                            // Market orders row
                                            HStack(spacing: 20) {
                                                Button(action: {
                                                    orderType = "market"
                                                    showBuyPopup = true
                                                }) {
                                                    Text("Buy Market")
                                                        .font(.headline)
                                                        .padding()
                                                        .frame(minWidth: 120)
                                                        .background(Color.green)
                                                        .foregroundColor(.white)
                                                        .cornerRadius(10)
                                                }
                                                
                                                Button(action: {
                                                    orderType = "market"
                                                    showSellPopup = true
                                                }) {
                                                    Text("Sell Market")
                                                        .font(.headline)
                                                        .padding()
                                                        .frame(minWidth: 120)
                                                        .background(Color.red)
                                                        .foregroundColor(.white)
                                                        .cornerRadius(10)
                                                }
                                            }
                                            
                                            // Limit orders row
                                            HStack(spacing: 20) {
                                                Button(action: {
                                                    orderType = "limit"
                                                    showBuyLimitPopup = true
                                                }) {
                                                    Text("Buy Limit")
                                                        .font(.headline)
                                                        .padding()
                                                        .frame(minWidth: 120)
                                                        .background(Color.green)
                                                        .foregroundColor(.white)
                                                        .cornerRadius(10)
                                                }
                                                
                                                Button(action: {
                                                    orderType = "limit"
                                                    showSellLimitPopup = true
                                                }) {
                                                    Text("Sell Limit")
                                                        .font(.headline)
                                                        .padding()
                                                        .frame(minWidth: 120)
                                                        .background(Color.red)
                                                        .foregroundColor(.white)
                                                        .cornerRadius(10)
                                                }
                                            }
                                        }
                                        .padding(.top, 16)
                    
                    // Response message for buy/sell action
                    if showBuyResponse {
                        Text(buyResponseMessage)
                            .font(.subheadline)
                            .padding(.top, 8)
                            .foregroundColor(buyResponseMessage.contains("Error") ? .red :
                                                buyResponseMessage.contains("Not enough funds") ? .red :
                                                buyResponseMessage.contains("Not enough stock owned") ? .red : .black)
                    }
                }
            }
            .padding()
            .navigationTitle(userInput)
            .onAppear {
                // Apply default filter when view appears
                filterChartDataByRange(selectedRange)
            }
            
            .onDisappear {
                onNavigateBack()
            }
            // Buy popup
            if showBuyPopup || showBuyLimitPopup {
                            Color.black.opacity(0.4)
                                .edgesIgnoringSafeArea(.all)
                                .onTapGesture {
                                    showBuyPopup = false
                                    showBuyLimitPopup = false
                                    limitPrice = ""
                                }
                            
                            VStack(spacing: 20) {
                                Text("Enter Amount to Buy \(orderType == "limit" ? "Limit" : "Market")")
                                    .font(.headline)
                                    .padding(.top)
                                Text("Only numbers greater than 0 with up to two decimal places accepted")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                
                                // Amount to buy
                                HStack {
                                    Text("$")
                                        .font(.title2)
                                    TextField("Amount", text: $buyAmount)
                                        .keyboardType(.decimalPad)
                                        .font(.title2)
                                        .multilineTextAlignment(.leading)
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                        .onChange(of: buyAmount) { newValue in
                                            buyAmount = newValue.filter { $0.isNumber || $0 == "." }
                                        }
                                }
                                .padding(.horizontal)
                                
                                // Limit price field (only shown for limit orders)
                                if orderType == "limit" {
                                    HStack {
                                        Text("@")
                                            .font(.title2)
                                        TextField("Limit Price", text: $limitPrice)
                                            .keyboardType(.decimalPad)
                                            .font(.title2)
                                            .multilineTextAlignment(.leading)
                                            .padding()
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                            .onChange(of: limitPrice) { newValue in
                                                limitPrice = newValue.filter { $0.isNumber || $0 == "." }
                                            }
                                    }
                                    .padding(.horizontal)
                                }
                                
                                HStack {
                                    Button(action: {
                                        showBuyPopup = false
                                        showBuyLimitPopup = false
                                        limitPrice = ""
                                    }) {
                                        Text("Cancel")
                                            .font(.headline)
                                            .padding()
                                            .frame(minWidth: 100)
                                            .background(Color.gray.opacity(0.2))
                                            .foregroundColor(.primary)
                                            .cornerRadius(10)
                                    }
                                    
                                    Button(action: {
                                        let action = orderType == "limit" ? "buy limit" : "buy"
                                        let message = orderType == "limit" ?
                                            "\(action) \(userInput): \(buyAmount) @ \(limitPrice)" :
                                            "\(action) \(userInput): \(buyAmount)"
                                        sendRequestToPythonServer(message: message)
                                        showBuyPopup = false
                                        showBuyLimitPopup = false
                                        limitPrice = ""
                                    }) {
                                        Text("Submit")
                                            .font(.headline)
                                            .padding()
                                            .frame(minWidth: 100)
                                            .background(isSubmitEnabled ? Color.green : Color.gray)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                    .disabled(!isSubmitEnabled)
                                }
                                .padding(.bottom)
                            }
                            .frame(width: 300)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(radius: 10)
                        }
                        
                        // Sell popup - Modified to show order type and price field for limit orders
                        if showSellPopup || showSellLimitPopup {
                            Color.black.opacity(0.4)
                                .edgesIgnoringSafeArea(.all)
                                .onTapGesture {
                                    showSellPopup = false
                                    showSellLimitPopup = false
                                    limitPrice = ""
                                }
                            
                            VStack(spacing: 20) {
                                Text("Enter Amount to Sell \(orderType == "limit" ? "Limit" : "Market")")
                                    .font(.headline)
                                    .padding(.top)
                                
                                Text("Only numbers greater than 0 with up to two decimal places accepted")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                
                                // Amount to sell
                                HStack {
                                    Text("$")
                                        .font(.title2)
                                    TextField("Amount", text: $sellAmount)
                                        .keyboardType(.decimalPad)
                                        .font(.title2)
                                        .multilineTextAlignment(.leading)
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                        .onChange(of: sellAmount) { newValue in
                                            sellAmount = newValue.filter { $0.isNumber || $0 == "." }
                                        }
                                }
                                .padding(.horizontal)
                                
                                // Limit price field (only shown for limit orders)
                                if orderType == "limit" {
                                    HStack {
                                        Text("@")
                                            .font(.title2)
                                        TextField("Limit Price", text: $limitPrice)
                                            .keyboardType(.decimalPad)
                                            .font(.title2)
                                            .multilineTextAlignment(.leading)
                                            .padding()
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                            .onChange(of: limitPrice) { newValue in
                                                limitPrice = newValue.filter { $0.isNumber || $0 == "." }
                                            }
                                    }
                                    .padding(.horizontal)
                                }
                                
                                HStack {
                                    Button(action: {
                                        showSellPopup = false
                                        showSellLimitPopup = false
                                        limitPrice = ""
                                    }) {
                                        Text("Cancel")
                                            .font(.headline)
                                            .padding()
                                            .frame(minWidth: 100)
                                            .background(Color.gray.opacity(0.2))
                                            .foregroundColor(.primary)
                                            .cornerRadius(10)
                                    }
                                    
                                    Button(action: {
                                        let action = orderType == "limit" ? "sell limit" : "sell"
                                        let message = orderType == "limit" ?
                                            "\(action) \(userInput): \(sellAmount) @ \(limitPrice)" :
                                            "\(action) \(userInput): \(sellAmount)"
                                        sendRequestToPythonServer(message: message)
                                        showSellPopup = false
                                        showSellLimitPopup = false
                                        limitPrice = ""
                                    }) {
                                        Text("Submit")
                                            .font(.headline)
                                            .padding()
                                            .frame(minWidth: 100)
                                            .background(isSubmitEnabled ? Color.red : Color.gray)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                    .disabled(!isSubmitEnabled)
                                }
                                .padding(.bottom)
                            }
                            .frame(width: 300)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(radius: 10)
                        }
                    }
                    .navigationTitle(userInput)
                }
    
    private var isSubmitEnabled: Bool {
           if orderType == "limit" {
               // For limit orders, both amount and price must be valid
               let isBuyValid = (showBuyPopup || showBuyLimitPopup) ? isBuyAmountValid && isLimitPriceValid : false
               let isSellValid = (showSellPopup || showSellLimitPopup) ? isSellAmountValid && isLimitPriceValid : false
               return isBuyValid || isSellValid
           } else {
               // For market orders, just the amount needs to be valid
               return (showBuyPopup && isBuyAmountValid) || (showSellPopup && isSellAmountValid)
           }
       }
    
    // Function to send request to Python server
    private func sendRequestToPythonServer(message: String) {
        // Define the URL of the Python server
        let url = URL(string: "http://127.0.0.1:5000/api/data")!
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prepare the JSON data to send
        let json: [String: Any] = ["message": "\(username) \(message)"]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        
        request.httpBody = jsonData
        
        // Send the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Check for network errors
            if let error = error {
                DispatchQueue.main.async {
                    buyResponseMessage = "Network Error: \(error.localizedDescription)"
                    showBuyResponse = true
                }
                return
            }
            
            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    buyResponseMessage = "Invalid server response"
                    showBuyResponse = true
                }
                return
            }
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    buyResponseMessage = "Server Error: HTTP \(httpResponse.statusCode)"
                    showBuyResponse = true
                }
                return
            }
            
            // Ensure data exists
            guard let data = data else {
                DispatchQueue.main.async {
                    buyResponseMessage = "No data received from server"
                    showBuyResponse = true
                }
                return
            }
            
            do {
                   // Print raw response for debugging
                   if let rawString = String(data: data, encoding: .utf8) {
                       print("Raw server response: \(rawString)")
                   }
                   
                   // Parse JSON
                   guard let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                       DispatchQueue.main.async {
                           buyResponseMessage = "Failed to parse server response"
                           showBuyResponse = true
                       }
                       return
                   }
                   
                   // Extract values based on the new response format
                   let responseMessage = jsonResponse["message"] as? String ?? "No message"
                   
                   // Differentiate between buy and sell responses
                   if message.contains("buy") {
                       // Handle string values by converting them to Double
                       let accountTotal = Double(jsonResponse["account_total"] as? String ?? "0") ?? 0.0
                       let buyTotal = Double(jsonResponse["buy_total"] as? String ?? "0") ?? 0.0
                    let totalStockOwned = Double(jsonResponse["total_stock_owned"] as? String ?? "0") ?? 0.0
                       let currentPriceResponse = Double(jsonResponse["current_price"] as? String ?? "0") ?? 0.0
                       
                       // Handle stock value array (convert string array to double array)
                       let stockValueDicStrings = jsonResponse["stock_value_dic"] as? [String] ?? []
                       let stockValueDic = stockValueDicStrings.compactMap { Double($0) }
                       
                       let stockDateDic = jsonResponse["stock_date_dic"] as? [String] ?? []
                    let nextBuyPriceResponse = Double(jsonResponse["next_buy_price"] as? String ?? "0") ?? 0.0
                    let nextSellPriceResponse = Double(jsonResponse["next_sell_price"] as? String ?? "0") ?? 0.0
                       
                       DispatchQueue.main.async {
                           cashToTrade = accountTotal
                           currentPrice = currentPriceResponse
                           nextBuyPrice = nextBuyPriceResponse
                           nextSellPrice = nextSellPriceResponse
                            buyResponseMessage = """
                            Buy Transaction:
                            Message: \(responseMessage)
                            Cash Left to Trade: $\(String(format: "%.2f", accountTotal))
                            Buy Total: $\(String(format: "%.2f", buyTotal))
                            Total Amount of Stock: $\(String(format: "%.2f", totalStockOwned))
                            """
                           amountOwned = totalStockOwned
                           if !stockValueDic.isEmpty && !stockDateDic.isEmpty {
                               self.values = stockValueDic
                               self.labels = stockDateDic
                               self.filterChartDataByRange(self.selectedRange) // Re-apply current filter
                           }
                           
                           showBuyResponse = true
                       }
                   } else if message.contains("sell") {
                       // Handle string values by converting them to Double
                       let accountTotal = Double(jsonResponse["account_total"] as? String ?? "0") ?? 0.0
                       let sellTotal = Double(jsonResponse["sell_total"] as? String ?? "0") ?? 0.0
                       let totalStockOwned_sell = Double(jsonResponse["total_stock_owned"] as? String ?? "0") ?? 0.0
                       let currentPriceResponse = Double(jsonResponse["current_price"] as? String ?? "0") ?? 0.0
                       
                       // Handle stock value array (convert string array to double array)
                       let stockValueDicStrings = jsonResponse["stock_value_dic"] as? [String] ?? []
                       let stockValueDic = stockValueDicStrings.compactMap { Double($0) }
                       
                       let stockDateDic = jsonResponse["stock_date_dic"] as? [String] ?? []
                       let nextBuyPriceResponse = Double(jsonResponse["next_buy_price"] as? String ?? "0") ?? 0.0
                       let nextSellPriceResponse = Double(jsonResponse["next_sell_price"] as? String ?? "0") ?? 0.0
                       
                       DispatchQueue.main.async {
                           cashToTrade = accountTotal
                           currentPrice = currentPriceResponse
                           nextBuyPrice = nextBuyPriceResponse
                           nextSellPrice = nextSellPriceResponse
                           buyResponseMessage = """
                           Sell Transaction:
                           Message: \(responseMessage)
                           Cash Left to Trade: $\(String(format: "%.2f", accountTotal))
                           Sell Total: $\(String(format: "%.2f", sellTotal))
                           Total Amount of Stock: $\(String(format: "%.2f", totalStockOwned_sell))
                           """
                           amountOwned = totalStockOwned_sell
                           if !stockValueDic.isEmpty && !stockDateDic.isEmpty {
                               self.values = stockValueDic
                               self.labels = stockDateDic
                               self.filterChartDataByRange(self.selectedRange) // Re-apply current filter
                           }
                           showBuyResponse = true
                       }
                   } else {
                       DispatchQueue.main.async {
                           buyResponseMessage = responseMessage
                           showBuyResponse = true
                       }
                   }
               } catch {
                   DispatchQueue.main.async {
                       buyResponseMessage = "Error parsing response: \(error.localizedDescription)"
                       showBuyResponse = true
                   }
               }
           }
        
        task.resume()
    }
    
    // New filter method that filters based on the selected time range
    private func filterChartDataByRange(_ range: TimeRange) {
        // Get the current date
        let currentDate = Date()
        
        // Calculate the start date based on the selected range
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -range.daysToSubtract, to: currentDate) else {
            return
        }
        
        // Initialize date formatter with the format of your labels
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Adjust to match your actual label format
        
        // Filter the data
        var newLabels: [String] = []
        var newValues: [Double] = []
        
        for (index, label) in labels.enumerated() {
            // Try to parse the date from the label
            if let labelDate = dateFormatter.date(from: label) {
                // Include the data point if it falls within our date range
                if labelDate >= startDate && labelDate <= currentDate {
                    newLabels.append(label)
                    newValues.append(values[index])
                }
            }
        }
        
        // Update the filtered data
        filteredLabels = newLabels
        filteredValues = newValues
    }
}

// UIViewRepresentable wrapper for ChartView
struct ChartViewRepresentable: UIViewRepresentable {
    var labels: [String]
    var values: [Double]
    
    // Add this to force SwiftUI to update the view when data changes
    var id: String {
        labels.joined() + values.map { String($0) }.joined()
    }

    func makeUIView(context: Context) -> LineChartView {
        let chartView = LineChartView()
        configureChart(chartView: chartView)
        updateChartData(chartView: chartView)
        return chartView
    }

    func updateUIView(_ chartView: LineChartView, context: Context) {
        updateChartData(chartView: chartView)
    }

    private func configureChart(chartView: LineChartView) {
        // Keep all your existing chart configuration
        chartView.noDataText = "No data available"
        chartView.noDataTextColor = .lightGray
        
        // X-axis configuration
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.avoidFirstLastClippingEnabled = true
        xAxis.drawGridLinesEnabled = false
        
        // Left axis configuration
        let leftAxis = chartView.leftAxis
        leftAxis.drawZeroLineEnabled = true
        leftAxis.valueFormatter = DefaultAxisValueFormatter { value, _ in
            return String(format: "$%.2f", value)
        }
        
        // Disable right axis
        chartView.rightAxis.enabled = false
        
        // Chart interaction settings
        chartView.dragEnabled = true
        chartView.setScaleEnabled(false)
        chartView.pinchZoomEnabled = false
        chartView.highlightPerDragEnabled = true
        chartView.extraTopOffset = 30
    }

    private func updateChartData(chartView: LineChartView) {
        // Clear previous data
        chartView.clear()
        
        // Only proceed if we have valid data
        guard !labels.isEmpty, !values.isEmpty, labels.count == values.count else {
            chartView.data = nil
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var dataEntries: [ChartDataEntry] = []
        var timestamps: [Double] = []
        
        // Create data entries - ensure we're using ALL values in the array
        for (index, label) in labels.enumerated() {
            // Ensure we include all values regardless of date parsing success
            if index < values.count {
                // Use the actual index instead of creating new indices
                let entry = ChartDataEntry(x: Double(index), y: Double(values[index]))
                dataEntries.append(entry)
                
                // Parse date if possible
                if let date = dateFormatter.date(from: label) {
                    timestamps.append(date.timeIntervalSince1970)
                } else {
                    timestamps.append(Double(index))
                }
            }
        }

        // Create dataset and ensure it includes ALL entries
        let dataSet = LineChartDataSet(entries: dataEntries, label: "Price Data")
        
        // Rest of your styling remains the same
        dataSet.colors = [NSUIColor.lightGray]
        dataSet.circleRadius = 0
        dataSet.mode = .linear
        dataSet.lineWidth = 2
        dataSet.drawValuesEnabled = false

        let chartData = LineChartData(dataSet: dataSet)
        chartView.data = chartData
        
        // Configure x-axis labels
        configureXAxisLabels(chartView: chartView, timestamps: timestamps)
        
        // Configure marker
        configureMarker(chartView: chartView, timestamps: timestamps)
        
        // Force redraw
        chartView.notifyDataSetChanged()
    }
    
    private func configureXAxisLabels(chartView: LineChartView, timestamps: [Double]) {
        guard !timestamps.isEmpty else { return }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MM/dd"
        
        var dateLabels = Array(repeating: "", count: timestamps.count)
        
        if let firstTimestamp = timestamps.first, let lastTimestamp = timestamps.last {
            dateLabels[0] = displayFormatter.string(from: Date(timeIntervalSince1970: firstTimestamp))
            if dateLabels.count > 1 {
                dateLabels[dateLabels.count - 1] = displayFormatter.string(from: Date(timeIntervalSince1970: lastTimestamp))
            }
        }
        
        chartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: dateLabels)
        chartView.xAxis.labelCount = dateLabels.count
        chartView.xAxis.granularity = 1
    }
    
    private func configureMarker(chartView: LineChartView, timestamps: [Double]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let marker = CustomMarker(
            font: UIFont.systemFont(ofSize: 10),
            textColor: .darkGray,
            lineColor: .blue,
            lineWidth: 1.0,
            timestamps: timestamps,
            dateFormatter: dateFormatter
        )
        marker.chartView = chartView
        chartView.marker = marker
    }
}

// Custom marker that displays date and value
class CustomMarker: MarkerView {
    var valueText = ""
    var dateText = ""
    var font: UIFont
    var textColor: UIColor
    var lineColor: UIColor
    var lineWidth: CGFloat
    var timestamps: [Double]
    var dateFormatter: DateFormatter
    
    var size: CGSize {
        let valueTextSize = valueText.size(withAttributes: [.font: font])
        let dateTextSize = dateText.size(withAttributes: [.font: font])
        let width = max(valueTextSize.width, dateTextSize.width)
        let height = valueTextSize.height + dateTextSize.height
        return CGSize(width: width, height: height)
    }

    init(font: UIFont = UIFont.systemFont(ofSize: 10),
         textColor: UIColor = .black,
         lineColor: UIColor = .black,
         lineWidth: CGFloat = 1.0,
         timestamps: [Double],
         dateFormatter: DateFormatter) {
        self.font = font
        self.textColor = textColor
        self.lineColor = lineColor
        self.lineWidth = lineWidth
        self.timestamps = timestamps
        self.dateFormatter = dateFormatter
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        // Format the value text
        valueText = String(format: "$%.2f", entry.y)
        
        // Get the correct timestamp for this index
        let index = Int(entry.x)
        if index >= 0 && index < timestamps.count {
            let timestamp = timestamps[index]
            let date = Date(timeIntervalSince1970: timestamp)
            
            // Format the date
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd"
            dateText = displayFormatter.string(from: date)
        } else {
            dateText = "Unknown"
        }
        
        setNeedsDisplay()
    }

    override func draw(context: CGContext, point: CGPoint) {
        guard let chart = chartView else { return }

        // Draw the vertical line
        context.saveGState()
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(lineWidth)
        context.move(to: CGPoint(x: point.x, y: chart.viewPortHandler.contentTop))
        context.addLine(to: CGPoint(x: point.x, y: chart.viewPortHandler.contentBottom))
        context.strokePath()
        context.restoreGState()

        // Create text attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: textColor
        ]

        // Calculate dimensions
        let valueTextSize = valueText.size(withAttributes: attributes)
        let dateTextSize = dateText.size(withAttributes: attributes)
        
        // Position value text
        let valueTextRect = CGRect(
            x: chart.viewPortHandler.contentLeft,
            y: chart.viewPortHandler.contentTop - valueTextSize.height - dateTextSize.height - 5,
            width: valueTextSize.width,
            height: valueTextSize.height
        )
        
        // Position date text below value text
        let dateTextRect = CGRect(
            x: chart.viewPortHandler.contentLeft,
            y: chart.viewPortHandler.contentTop - dateTextSize.height - 2,
            width: dateTextSize.width,
            height: dateTextSize.height
        )
        
        // Draw the texts
        valueText.draw(in: valueTextRect, withAttributes: attributes)
        dateText.draw(in: dateTextRect, withAttributes: attributes)
    }

    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        return .zero
    }
}
