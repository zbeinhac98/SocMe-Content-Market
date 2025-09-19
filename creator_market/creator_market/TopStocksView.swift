import SwiftUI

struct Stock: Identifiable, Decodable {
    var id = UUID()
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let percentChange: Double
    
    enum CodingKeys: String, CodingKey {
        case symbol, name, price, change
        case percentChange = "percent_change"
    }
    
    // For preview data
    init(symbol: String, name: String, price: Double, change: Double, percentChange: Double) {
        self.symbol = symbol
        self.name = name
        self.price = price
        self.change = change
        self.percentChange = percentChange
    }
}

struct StockMetric: Identifiable {
    let id = UUID()
    let name: String
    let value: String
}

struct TopStocksView: View {
    let username: String
    @State private var valueMetrics: [StockMetric] = []
    @State private var timeMetrics: [StockMetric] = []
    @State private var priceMetrics: [StockMetric] = []
    @State private var lowPriceMetrics: [StockMetric] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var navigateToChart: Bool = false
    @State private var selectedSymbol: String = ""
    
    // Chart data states
    @State private var chartLabels: [String] = []
    @State private var chartValues: [Double] = []
    @State private var stockAmountOwned: Double = 0
    @State private var cashToTrade: Double = 0
    @State private var nextBuyPrice: Double = 0
    @State private var nextSellPrice: Double = 0
    @State private var isLoadingChartData: Bool = false
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
            
            // Main content
            ScrollView {
                VStack(spacing: 0) {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error: error)
                    } else {
                        contentViews
                    }
                }
            }
            
            // Overlay loading indicator for chart data
            if isLoadingChartData {
                chartLoadingView
            }
        }
        .onAppear {
            fetchTopStocks()
        }
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
                        onNavigateBack: { fetchTopStocks() }
                    )
                    .navigationBarTitle(selectedSymbol, displayMode: .inline),
                isActive: $navigateToChart
            ) { EmptyView() }
            .isDetailLink(false)
        )
        .navigationBarTitle("Top Stocks", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            Text("Loading market data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(minHeight: 200)
        .padding()
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            
            Text(error)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            
            Button(action: {
                fetchTopStocks()
            }) {
                Text("Try Again")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(minHeight: 200)
    }
    
    private var contentViews: some View {
        VStack(spacing: 0) {
            // Most Traded by Value Section
            if !valueMetrics.isEmpty {
                modernSectionView(title: "Most Traded by Value", metrics: valueMetrics, prefix: "$")
            }
            
            // Recently Traded Section
            if !timeMetrics.isEmpty {
                modernSectionView(title: "Recently Traded", metrics: timeMetrics)
            }
            
            // Highest Priced Section
            if !priceMetrics.isEmpty {
                modernSectionView(title: "Highest Priced", metrics: priceMetrics, prefix: "$")
            }
            
            // Lowest Priced Section
            if !lowPriceMetrics.isEmpty {
                modernSectionView(title: "Lowest Priced", metrics: lowPriceMetrics, prefix: "$")
            }
        }
    }
    
    private func modernSectionView(title: String, metrics: [StockMetric], prefix: String = "") -> some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                Spacer()
            }
            .background(Color(.systemGray6))
            
            // Table content
            VStack(spacing: 0) {
                // Header row with dynamic column title
                HStack {
                    Text("Symbol")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                    
                    Spacer()
                    
                    Text(getColumnTitle(for: title))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 150, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.separator))
                
                // Data rows
                ForEach(metrics) { metric in
                    VStack(spacing: 0) {
                        HStack {
                            Button(action: {
                                selectedSymbol = metric.name
                                fetchChartData(for: metric.name)
                            }) {
                                Text(metric.name.uppercased())
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                            .frame(width: 100, alignment: .leading)
                            
                            Spacer()
                            
                            Text(metric.value)
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(.primary)
                                .frame(minWidth: 150, alignment: .trailing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        
                        if metric.id != metrics.last?.id {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color(.separator))
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            
            // Bottom spacing
            Rectangle()
                .frame(height: 16)
                .foregroundColor(Color(.systemGroupedBackground))
        }
    }
    
    private var chartLoadingView: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                
                Text("Loading chart data...")
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color(.systemGray))
            .cornerRadius(10)
        }
    }
    
    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                Text("Back")
                    .font(.body)
            }
            .foregroundColor(.blue)
        }
    }
    
    // Updated parsing functions
    private func parseDecimalValue(_ value: Any) -> String {
        if let stringValue = value as? String {
            if stringValue.hasPrefix("Decimal(") {
                let cleaned = stringValue
                    .replacingOccurrences(of: "Decimal('", with: "")
                    .replacingOccurrences(of: "')", with: "")
                    .replacingOccurrences(of: "Decimal(\"", with: "")
                    .replacingOccurrences(of: "\")", with: "")
                // Trim to 2 decimal places
                if let doubleValue = Double(cleaned) {
                    return String(format: "%.2f", doubleValue)
                }
                // If we can't convert to Double, just take first part before any spaces
                return cleaned.components(separatedBy: " ").first ?? cleaned
            }
            // Handle regular string numbers - also cap at 2 decimals
            if let doubleValue = Double(stringValue) {
                return String(format: "%.2f", doubleValue)
            }
            return stringValue
        }
        return "0.00"
    }
    
    private func getColumnTitle(for sectionTitle: String) -> String {
        switch sectionTitle {
        case "Most Traded by Value":
            return "Total Value Traded"
        case "Recently Traded":
            return "Date"
        case "Highest Priced":
            return "Price"
        case "Lowest Priced":
            return "Price"
        default:
            return "Value"
        }
    }

    private func parseDateTime(_ value: Any) -> String {
        if let stringValue = value as? String {
            // Handle GMT format (e.g., "Sun, 22 Jun 2025 20:16:01 GMT")
            let gmtFormatter = DateFormatter()
            gmtFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            gmtFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let date = gmtFormatter.date(from: stringValue) {
                let outputFormatter = DateFormatter()
                outputFormatter.dateStyle = .medium
                outputFormatter.timeStyle = .short
                return outputFormatter.string(from: date)
            }
            
            // Handle Python datetime format (fallback)
            if stringValue.hasPrefix("datetime.datetime(") {
                let components = stringValue
                    .replacingOccurrences(of: "datetime.datetime(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                
                guard components.count >= 6 else { return "Unknown date" }
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
                
                if let year = Int(components[0]),
                   let month = Int(components[1]),
                   let day = Int(components[2]),
                   let hour = Int(components[3]),
                   let minute = Int(components[4]),
                   let second = Int(components[5]) {
                    
                    let dateString = String(format: "%04d/%02d/%02d %02d:%02d:%02d",
                                          year, month, day, hour, minute, second)
                    if let date = formatter.date(from: dateString) {
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        return formatter.string(from: date)
                    }
                }
            }
        }
        return "Unknown date"
    }
    
    private func parseDateTimeToDate(_ value: Any) -> Date {
        if let stringValue = value as? String {
            // Handle GMT format first
            let gmtFormatter = DateFormatter()
            gmtFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            gmtFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let date = gmtFormatter.date(from: stringValue) {
                return date
            }
            
            // Handle Python datetime format
            if stringValue.hasPrefix("datetime.datetime(") {
                let components = stringValue
                    .replacingOccurrences(of: "datetime.datetime(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                
                guard components.count >= 6,
                      let year = Int(components[0]),
                      let month = Int(components[1]),
                      let day = Int(components[2]),
                      let hour = Int(components[3]),
                      let minute = Int(components[4]),
                      let second = Int(components[5]) else {
                    return Date.distantPast
                }
                
                var dateComponents = DateComponents()
                dateComponents.year = year
                dateComponents.month = month
                dateComponents.day = day
                dateComponents.hour = hour
                dateComponents.minute = minute
                dateComponents.second = second
                
                return Calendar.current.date(from: dateComponents) ?? Date.distantPast
            }
        }
        return Date.distantPast
    }
    
    private func parseResponse(data: Data) -> Bool {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            
            guard let dict = json as? [String: Any] else {
                print("Error: Response is not a dictionary")
                return false
            }
            
            // Parse value metrics (maintain order)
            if let valueDict = dict["sorted_by_value"] as? [String: Any] {
                valueMetrics = valueDict.map { (key, value) in
                    (key, parseDecimalValue(value))
                }.sorted(by: { Double($0.1) ?? 0 > Double($1.1) ?? 0 }) // Sort by value descending
                 .map { StockMetric(name: $0.0, value: "$\($0.1)") }
            }
            
            // Parse time metrics (maintain order)
            if let timeDict = dict["sorted_by_time"] as? [String: Any] {
                timeMetrics = timeDict.map { (key, value) -> (String, Date, String) in
                    let formattedString = parseDateTime(value)
                    let originalDate = parseDateTimeToDate(value) // New helper function
                    return (key, originalDate, formattedString)
                }.sorted(by: { $0.1 > $1.1 }) // Sort by actual Date objects
                 .map { StockMetric(name: $0.0, value: $0.2) } // Use formatted string for display
            }
            
            // Parse price metrics (maintain order)
            if let priceDict = dict["sorted_by_price"] as? [String: Any] {
                priceMetrics = priceDict.map { (key, value) in
                    (key, parseDecimalValue(value))
                }.sorted(by: { Double($0.1) ?? 0 > Double($1.1) ?? 0 }) // Sort by price descending
                 .map { StockMetric(name: $0.0, value: "$\($0.1)") }
            }
            if let lowPriceDict = dict["sorted_by_price_low"] as? [String: Any] {
                lowPriceMetrics = lowPriceDict.map { (key, value) in
                    (key, parseDecimalValue(value))
                }.sorted(by: { Double($0.1) ?? 0 < Double($1.1) ?? 0 })
                 .map { StockMetric(name: $0.0, value: "$\($0.1)") }
            }
            
            return true
        } catch {
            print("Parsing failed:", error)
            return false
        }
    }
    
    // Updated fetchTopStocks function
    func fetchTopStocks() {
        isLoading = true
        errorMessage = nil
        
        let url = URL(string: "http://127.0.0.1:5000/api/data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8 // Timeout after 8 seconds
        
        let json: [String: Any] = ["message": "top stocks"]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        } catch {
            isLoading = false
            errorMessage = "Failed to create request"
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                // Handle network errors
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                // Check HTTP status
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid server response"
                    return
                }
                
                print("HTTP Status:", httpResponse.statusCode)
                
                // Handle 500 errors
                if httpResponse.statusCode == 500 {
                    self.errorMessage = "Server error (500)"
                    return
                }
                
                // Validate successful response
                guard (200...299).contains(httpResponse.statusCode) else {
                    self.errorMessage = "Server error: HTTP \(httpResponse.statusCode)"
                    return
                }
                
                // Parse data
                guard let data = data else {
                    self.errorMessage = "No data received"
                    return
                }
                
                // Debug output
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Server response:", responseString)
                }
                
                // Attempt to parse
                if self.parseResponse(data: data) {
                    print("Data parsed successfully")
                } else {
                    self.errorMessage = "Data format error"
                }
            }
        }.resume()
    }

    // Helper function to parse dictionaries
    private func parseDictionary(_ metrics: inout [StockMetric], from value: Any?, prefix: String = "") {
        metrics.removeAll()
        
        guard let dict = value as? [String: Any] else {
            print("Warning: Expected dictionary but got \(type(of: value))")
            return
        }
        
        for (key, rawValue) in dict {
            let value: String
            if prefix == "$" {
                value = prefix + parseDecimalValue(rawValue)
            } else {
                value = parseDateTime(rawValue)
            }
            metrics.append(StockMetric(name: key, value: value))
        }
    }
    
    private func formatTimestamp(_ timestamp: String) -> String {
        // Handle Python datetime string format
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = inputFormatter.date(from: timestamp) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "d MMM yyyy"
            return outputFormatter.string(from: date)
        }
        
        // Fallback - try alternative format or return cleaned string
        return timestamp.components(separatedBy: " ").first ?? timestamp
    }
    
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
                        if let labels = jsonResponse["labels"] as? [String],
                           let values = jsonResponse["values"] as? [String] {
                            
                            let floatValues = values.compactMap { Double($0) }
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
                            self.nextBuyPrice = nextBuyPrice
                            self.nextSellPrice = nextSellPrice
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
}

struct TopStocksView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TopStocksView(username: "PreviewUser")
        }
    }
}
