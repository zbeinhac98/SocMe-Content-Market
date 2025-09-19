import SwiftUI
import CoreData
import UIKit
import DGCharts

// MARK: - Main ContentView
struct ContentView: View {
    enum Platform: String, CaseIterable {
            case youtube = "YouTube"
            case instagram = "Instagram"
            case tiktok = "TikTok"
            
            var prefix: String {
                switch self {
                case .youtube: return "Youtube"
                case .instagram: return "Instagram"
                case .tiktok: return "TikTok"
                }
            }
        }
    var username: String
    @State var accountTotal: Double
    @State private var leftToUse: Double = 0.0
    @State private var showSettingsView: Bool = false
    @State private var dailyTotalArray: [Double] = []
    @State private var dailyLabels: [String] = []
    @State private var selectedRange: TimeRange = .oneMonth
    @State private var filteredDailyLabels: [String] = []
    @State private var filteredDailyValues: [Double] = []
    @StateObject private var bankAccountManager: BankAccountManager
    @State private var selectedPlatform: Platform = .youtube
    init(username: String, accountTotal: Double, dailyTotalArray: [Double] = []) {
        self.username = username
        self._accountTotal = State(initialValue: accountTotal)
        self._dailyTotalArray = State(initialValue: dailyTotalArray)
        self._bankAccountManager = StateObject(wrappedValue: BankAccountManager(username: username))
        self._selectedPlatform = State(initialValue: .youtube)
    }
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isLoggedOut: Bool = false
    @State private var showTopStocksView: Bool = false
    @State private var showBankLinkView: Bool = false
    @State private var showPositionsView: Bool = false
    @State private var showOrdersView: Bool = false
    @State private var showMenu: Bool = false
    @State private var showFAQView: Bool = false
    @State private var showTermsView: Bool = false
    @State private var hasAgreedToTerms: Bool = false
    @State private var showFundTransferView: Bool = false
    @State private var showTransactionHistoryView: Bool = false
    @State private var refreshFlag = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>
    
    @State private var responseMessage: String = "Waiting for response..."
    @State private var userInput: String = ""
    @State private var labels: [String] = []
    @State private var values: [Double] = []
    @State private var cashToTrade: Double = 0.0
    @State private var amountOwned: Double = 0.0
    @State private var nextBuyPrice: Double = 0
    @State private var nextSellPrice: Double = 0
    @State private var showChart: Bool = false
    @State private var hasFetchedAccountTotal = false
    @State private var errorMessage: String = ""
    
    @State private var navigateToBankLink: Bool = false
    @State private var navigateToLogin: Bool = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    mainContentView(geometry: geometry)
                    
                    if showMenu {
                        menuView(geometry: geometry)
                            .transition(.scale)
                            .zIndex(1)
                    }
                    
                    if showMenu {
                        Color.black.opacity(0.1)
                            .onTapGesture {
                                withAnimation {
                                    showMenu = false
                                }
                            }
                            .edgesIgnoringSafeArea(.all)
                    }
                }
                .navigationBarHidden(true)
                .navigationBarBackButtonHidden(true)
                .background(navigationLinks)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            print("ContentView appeared with dailyTotalArray: \(dailyTotalArray)")
            fetchAccountTotal()
            if !dailyTotalArray.isEmpty {
                generateDailyLabels()
                filterDailyDataByRange(selectedRange)
            }
        }
        .onChange(of: showTermsView) { _ in
            fetchAccountTotal()
            }
        .onChange(of: showPositionsView) { _ in
            fetchAccountTotal()
            }
        .onChange(of: showOrdersView) { _ in
            fetchAccountTotal()
            }
        .onChange(of: showTopStocksView) { _ in
            fetchAccountTotal()
            }
        .onChange(of: showBankLinkView) { _ in
            fetchAccountTotal()
            }
        .onChange(of: showFundTransferView) { _ in
            fetchAccountTotal()
            }
        .onChange(of: showTransactionHistoryView) { _ in
            fetchAccountTotal()
            }
        .onChange(of: showSettingsView) { _ in
            fetchAccountTotal()
            }
        .onChange(of: showFAQView) { _ in
            fetchAccountTotal()
            }
    }
    
    // MARK: - Subviews
    
    private func mainContentView(geometry: GeometryProxy) -> some View {
        VStack {
            menuButton
                .padding(.horizontal)
                .frame(height: geometry.size.height * 0.10)
            
            pythonServerRequestUI
            
            accountTotalView
            
            if dailyTotalArray.isEmpty {
                noDataPlaceholder
            } else {
                chartSection
            }
            
            termsAndLinksSection
            
            Spacer()
        }
        .padding(.top)
        .blur(radius: showMenu ? 3 : 0)
    }
    
    private var menuButton: some View {
        HStack {
            Button(action: {
                withAnimation {
                    showMenu.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "line.horizontal.3")
                        .font(.system(size: 20))
                    Text("Menu")
                        .font(.headline)
                }
                .foregroundColor(.black)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .accessibilityLabel("Open Menu")
            .accessibilityHint("Tap to open the menu dropdown")
            
            Spacer()
        }
    }
    
    private var pythonServerRequestUI: some View {
        VStack {
            Text("Search for a Creator")
                .font(.largeTitle)
                .padding(.bottom, 20)
            
            // Platform selector tabs
            platformSelectorTabs
                .padding(.horizontal)
            
            VStack(spacing: 15) {
                TextField("Enter a \(selectedPlatform.rawValue) creator", text: $userInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .padding(.top, -26)
                
                //Text(responseMessage)
                Text("")
                    .font(.body)
                    .multilineTextAlignment(.center)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, -10)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                }
                
                Button(action: {
                    sendRequestToPythonServer()
                }) {
                    Text("Search")
                        .font(.title2)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
    }
    
    private var platformSelectorTabs: some View {
        HStack(spacing: 0) {
            ForEach(Platform.allCases, id: \.self) { platform in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPlatform = platform
                    }
                }) {
                    Text(platform.rawValue)
                        .font(.caption)
                        .fontWeight(selectedPlatform == platform ? .semibold : .regular)
                        .foregroundColor(selectedPlatform == platform ? .black : .gray)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .background(
                            ZStack {
                                TabShape(isSelected: selectedPlatform == platform)
                                    .fill(selectedPlatform == platform ? Color.white : Color.gray.opacity(0.3))
                                    .shadow(
                                        color: selectedPlatform == platform ? .gray.opacity(0.4) : .clear,
                                        radius: selectedPlatform == platform ? 3 : 0,
                                        x: 0,
                                        y: selectedPlatform == platform ? -2 : 0
                                    )
                            }
                        )
                        .zIndex(selectedPlatform == platform ? 1 : 0)
                }
                .padding(.horizontal, 1)
            }
        }
    }
    
    struct TabShape: Shape {
        let isSelected: Bool
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            
            let cornerRadius: CGFloat = 8
            let tabHeight = isSelected ? rect.height : rect.height * 0.85
            
            // Start from bottom left
            path.move(to: CGPoint(x: 0, y: rect.height))
            
            // Left edge going up
            path.addLine(to: CGPoint(x: 0, y: cornerRadius))
            
            // Top left corner
            path.addQuadCurve(
                to: CGPoint(x: cornerRadius, y: 0),
                control: CGPoint(x: 0, y: 0)
            )
            
            // Top edge
            path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))
            
            // Top right corner
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: cornerRadius),
                control: CGPoint(x: rect.width, y: 0)
            )
            
            // Right edge going down
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            
            return path
        }
    }
    
    private var accountTotalView: some View {
        VStack {
            Text("Account Total")
                .font(.headline)
                .padding(.top, 20)
            
            Text("$\(String(format: "%.2f", accountTotal))")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var noDataPlaceholder: some View {
        VStack {
            Text("No historical data available")
                .foregroundColor(.gray)
                .padding()
            
            Button(action: {
                fetchAccountTotal()
            }) {
                Text("Refresh Data")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .frame(height: 200)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private var chartSection: some View {
        VStack {
            timeRangeSelector
            
            ChartViewRepresentable_2(
                labels: filteredDailyLabels.isEmpty ? dailyLabels : filteredDailyLabels,
                values: filteredDailyValues.isEmpty ? dailyTotalArray : filteredDailyValues
            )
            .frame(height: 200)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .padding(.top)
    }
    
    private var timeRangeSelector: some View {
        HStack(spacing: 6) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    selectedRange = range
                    filterDailyDataByRange(range)
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
    }
    
    private var termsAndLinksSection: some View {
        VStack(spacing: 8) {
            if !hasAgreedToTerms {
                Text("Please accept our Terms of Service to link your bank account and start trading.")
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    showFAQView = true
                }) {
                    Text("FAQ")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    showTermsView = true
                }) {
                    Text("Terms of Service")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.top, 10)
    }
    
    private func menuView(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            menuItemGroup1
            menuItemGroup2
        }
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 5)
        .frame(width: geometry.size.width * 0.5)
        .position(
            x: geometry.size.width * 0.25,
            y: geometry.safeAreaInsets.top + 35 + (menuHeight / 2) // Dynamic positioning: safe area + 50px + half menu height for centering
        )
    }
    
    private var menuHeight: CGFloat {
        // Calculate approximate height based on number of menu items
        // Each menu item is roughly 44 points (standard iOS touch target)
        // Plus dividers and padding
        let menuItemCount: CGFloat = 8 // Total number of menu items
        let itemHeight: CGFloat = 44
        let dividerHeight: CGFloat = 1
        let totalDividers: CGFloat = menuItemCount - 1
        
        return (menuItemCount * itemHeight) + (totalDividers * dividerHeight)
    }
    
    private var menuItemGroup1: some View {
        Group {
            menuButtonItem(title: "Positions", icon: "chart.bar", action: { showPositionsView = true })
            Divider()
            menuButtonItem(title: "Orders", icon: "list.bullet", action: { showOrdersView = true })
            Divider()
            menuButtonItem(title: "Top Stocks", icon: "chart.line.uptrend.xyaxis", action: { showTopStocksView = true })
        }
    }
    
    private var menuItemGroup2: some View {
        Group {
            Divider()
            menuButtonItem(title: "Link Bank Account", icon: "creditcard", action: { showBankLinkView = true }, disabled: !hasAgreedToTerms)
            Divider()
            menuButtonItem(title: "Transfer Funds", icon: "arrow.left.arrow.right", action: { showFundTransferView = true }, disabled: !hasAgreedToTerms)
            Divider()
            menuButtonItem(title: "Transaction History", icon: "clock.arrow.circlepath", action: { showTransactionHistoryView = true })
            Divider()
            menuButtonItem(title: "Settings", icon: "gearshape", action: { showSettingsView = true })
            Divider()
            menuButtonItem(title: "Logout", icon: "arrow.right.square", action: {
                AuthManager.shared.logoutUser()
                isLoggedOut = true
            })
        }
    }
    
    private func menuButtonItem(title: String, icon: String, action: @escaping () -> Void, disabled: Bool = false) -> some View {
        Button(action: {
            withAnimation {
                showMenu = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: action)
        }) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .foregroundColor(disabled ? .gray : .black)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(disabled)
    }
    
    private var navigationLinks: some View {
        VStack(spacing: 0) {
            Group {
                NavigationLink(
                    destination: LoginView()
                        .navigationBarHidden(true)
                        .navigationBarBackButtonHidden(true),
                    isActive: $isLoggedOut
                ) { EmptyView() }
                
                NavigationLink(
                    destination: PositionsView(username: username),
                    isActive: $showPositionsView
                ) { EmptyView() }
                
                NavigationLink(
                    destination: OrdersView(username: username),
                    isActive: $showOrdersView
                ) { EmptyView() }
                
                NavigationLink(
                    destination: BankAccountLinkView(username: username)
                        .environmentObject(bankAccountManager),
                    isActive: $showBankLinkView
                ) { EmptyView() }
                
                NavigationLink(
                    destination: SettingsView(username: username),
                    isActive: $showSettingsView
                ) { EmptyView() }
            }
            
            Group {
                NavigationLink(
                    destination: TopStocksView(username: username),
                    isActive: $showTopStocksView
                ) { EmptyView() }
                
                NavigationLink(
                    destination: ChartView(labels: labels, values: values, userInput: userInput, username: username, amountOwned: amountOwned, cashToTrade: Double(cashToTrade), nextBuyPrice: nextBuyPrice, nextSellPrice: nextSellPrice, selectedPlatform: selectedPlatform, onNavigateBack: {
                        fetchAccountTotal()
                    }),
                    isActive: $showChart
                ) { EmptyView() }
                
                NavigationLink(
                    destination: FAQView(),
                    isActive: $showFAQView
                ) { EmptyView() }
                
                NavigationLink(
                    destination: TransactionHistoryView(username: username),
                    isActive: $showTransactionHistoryView
                ) { EmptyView() }

                NavigationLink(
                    destination: TermsOfServiceView(username: username),
                    isActive: $showTermsView
                ) { EmptyView() }
            }
            
            NavigationLink(
                destination: FundTransferView(username: username, leftToUse: leftToUse)
                    .environmentObject(bankAccountManager),
                isActive: $showFundTransferView
            ) { EmptyView() }
        }
    }
    
    // MARK: - TimeRange Enum
    enum TimeRange: String, CaseIterable {
        case oneDay = "1D"
        case fiveDay = "5D"
        case oneMonth = "1M"
        case threeMonth = "3M"
        case oneYear = "1Y"
        
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
    
    // MARK: - Data Methods (unchanged from original)
    func fetchAccountTotal() {
        print("Fetching account total...")
        
        let url = URL(string: "http://127.0.0.1:5000/api/data")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let json: [String: Any] = ["message": "accounttotal \(username)"]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching account total: \(error.localizedDescription)")
                return
            }
            
            if let data = data {
                print("Raw response data: \(String(data: data, encoding: .utf8) ?? "No data")")
                
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print("Full response: \(jsonResponse)")
                        
                        // Handle account total
                        if let total = jsonResponse["account_total"] as? Double {
                            DispatchQueue.main.async {
                                self.accountTotal = total
                            }
                        } else if let totalString = jsonResponse["account_total"] as? String,
                                  let total = Double(totalString) {
                            DispatchQueue.main.async {
                                self.accountTotal = total
                            }
                        }
                        if let stockOwned = jsonResponse["amount of stock owned"] as? Double {
                            DispatchQueue.main.async {
                                self.amountOwned = stockOwned
                            }
                        } else if let stockOwnedString = jsonResponse["amount of stock owned"] as? String,
                                  let stockOwned = Double(stockOwnedString) {
                            DispatchQueue.main.async {
                                self.amountOwned = stockOwned
                            }
                        }
                        
                        if let agreed = jsonResponse["agreed"] as? Int {
                            DispatchQueue.main.async {
                                self.hasAgreedToTerms = (agreed == 1)
                            }
                        } else if let agreedString = jsonResponse["agreed"] as? String,
                                  let agreed = Int(agreedString) {
                            DispatchQueue.main.async {
                                self.hasAgreedToTerms = (agreed == 1)
                            }
                        }
                        
                        if let leftToUse = jsonResponse["left_to_use"] as? Double {
                            DispatchQueue.main.async {
                                self.leftToUse = leftToUse
                            }
                        } else if let leftToUseString = jsonResponse["left_to_use"] as? String,
                                  let leftToUse = Double(leftToUseString) {
                            DispatchQueue.main.async {
                                self.leftToUse = leftToUse
                            }
                        }
                        
                        // Parse account_total_array with multiple type checks
                        var dailyTotals: [Double] = []
                        
                        // First try the new key name "account_total_array"
                        if let floatArray = jsonResponse["account_total_array"] as? [Double] {
                            dailyTotals = floatArray
                        } else if let doubleArray = jsonResponse["account_total_array"] as? [Double] {
                            dailyTotals = doubleArray.map { Double($0) }
                        } else if let numberArray = jsonResponse["account_total_array"] as? [NSNumber] {
                            dailyTotals = numberArray.map { $0.doubleValue }
                        } else if let anyArray = jsonResponse["account_total_array"] as? [Any] {
                            dailyTotals = anyArray.compactMap { element in
                                if let num = element as? NSNumber {
                                    return num.doubleValue
                                } else if let str = element as? String {
                                    return Double(str)
                                }
                                return nil
                            }
                        }
                        // Fallback to old key name "daily_total_array" if needed
                        else if let floatArray = jsonResponse["daily_total_array"] as? [Double] {
                            dailyTotals = floatArray
                        } else if let doubleArray = jsonResponse["daily_total_array"] as? [Double] {
                            dailyTotals = doubleArray.map { Double($0) }
                        }
                        
                        DispatchQueue.main.async {
                            if !dailyTotals.isEmpty {
                                print("Daily totals parsed successfully: \(dailyTotals)")
                                self.dailyTotalArray = dailyTotals
                            } else if let total = jsonResponse["account_total"] as? Double {
                                print("No daily totals in response, using account total as single data point")
                                self.dailyTotalArray = [total]
                            }
                            
                            self.generateDailyLabels()
                            self.filterDailyDataByRange(self.selectedRange)
                        }
                    }
                } catch {
                    print("Failed to parse account total: \(error.localizedDescription)")
                }
            }
        }
        
        task.resume()
    }
    
    private func debugChartData() {
        print("Daily totals array count: \(dailyTotalArray.count)")
        print("Daily labels count: \(dailyLabels.count)")
        print("Filtered daily values count: \(filteredDailyValues.count)")
        print("Filtered daily labels count: \(filteredDailyLabels.count)")
        
        // Check if the chart will have valid data
        let displayValues = filteredDailyValues.isEmpty ? dailyTotalArray : filteredDailyValues
        let displayLabels = filteredDailyLabels.isEmpty ? dailyLabels : filteredDailyLabels
        
        if displayValues.isEmpty || displayLabels.isEmpty {
            print("⚠️ Chart has no data to display")
        } else if displayValues.count != displayLabels.count {
            print("⚠️ Chart has mismatched data: \(displayValues.count) values vs \(displayLabels.count) labels")
        } else {
            print("✅ Chart has valid data: \(displayValues.count) points")
        }
    }
    
    private func generateDailyLabels() {
        print("Generating daily labels for array count: \(dailyTotalArray.count)")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var labels: [String] = []
        let calendar = Calendar.current
        let today = Date()
        
        // If we have data, generate proper labels
        if !dailyTotalArray.isEmpty {
            // Generate one label per data point
            for i in 0..<dailyTotalArray.count {
                // For single point, just use today's date
                if dailyTotalArray.count == 1 {
                    labels.append(dateFormatter.string(from: today))
                } else {
                    // For multiple points, create a date sequence
                    // The most recent value is the last in the array
                    if let date = calendar.date(byAdding: .day, value: -(dailyTotalArray.count - 1 - i), to: today) {
                        labels.append(dateFormatter.string(from: date))
                    }
                }
            }
        }
        
        print("Generated labels: \(labels)")
        dailyLabels = labels
        
        // Make sure we have proper filtered data ready
        if !dailyLabels.isEmpty && !dailyTotalArray.isEmpty {
            filterDailyDataByRange(selectedRange)
        }
    }

    private func filterDailyDataByRange(_ range: TimeRange) {
        print("Filtering for range: \(range.rawValue)")
        if dailyTotalArray.isEmpty || dailyLabels.isEmpty {
            print("No data to filter yet")
            return
        }
        
        // For single datapoint, don't filter - just use the data we have
        if dailyTotalArray.count == 1 {
            print("Single datapoint - using as is without filtering")
            filteredDailyLabels = dailyLabels
            filteredDailyValues = dailyTotalArray
            return
        }
        
        let currentDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -range.daysToSubtract, to: currentDate) else {
            print("Failed to calculate start date")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var newLabels: [String] = []
        var newValues: [Double] = []
        
        print("Daily labels count: \(dailyLabels.count), Daily values count: \(dailyTotalArray.count)")
        
        // Make sure arrays have the same count
        let minCount = min(dailyLabels.count, dailyTotalArray.count)
        
        for i in 0..<minCount {
            let label = dailyLabels[i]
            if let labelDate = dateFormatter.date(from: label) {
                if labelDate >= startDate && labelDate <= currentDate {
                    newLabels.append(label)
                    newValues.append(dailyTotalArray[i])
                }
            } else {
                print("Could not parse date: \(label)")
            }
        }
        
        print("Filtered labels count: \(newLabels.count), Filtered values count: \(newValues.count)")
        
        // If no filtered data or just one point, use all data
        if newLabels.isEmpty || newValues.isEmpty {
            print("No filtered data, using all data")
            filteredDailyLabels = dailyLabels
            filteredDailyValues = dailyTotalArray
        } else {
            filteredDailyLabels = newLabels
            filteredDailyValues = newValues
        }
        
        print("After filtering: \(filteredDailyValues.count) values for display")
        debugChartData()  // Call debug to log data before chart display
    }
    
    func sendRequestToPythonServer() {
        errorMessage = ""
        let url = URL(string: "http://127.0.0.1:5000/api/data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let json: [String: Any] = ["message": username + " \(selectedPlatform.prefix): " + userInput]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                }
                return
            }
            
            if let data = data {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw Response: \(responseString)")
                }
                
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print("Parsed JSON Response: \(jsonResponse)")
                        
                        // Check for error message first
                        if let errorMessage = jsonResponse["message"] as? String,
                           errorMessage.contains("doesn't have enough subscribers") || errorMessage.contains("hasn't posted recently") {
                            DispatchQueue.main.async {
                                self.errorMessage = "Can't IPO this creator please try a different one"
                            }
                            return
                        }
                        
                        // Extract all values including the new prices
                        let cashToTrade: Double
                        if let cashString = jsonResponse["cash to trade"] as? String {
                            cashToTrade = Double(cashString) ?? 0.0
                        } else {
                            cashToTrade = jsonResponse["cash to trade"] as? Double ?? 0.0
                        }
                        
                        let amountOwned: Double
                        if let amountString = jsonResponse["amount of stock owned"] as? String {
                            amountOwned = Double(amountString) ?? 0.0
                        } else {
                            amountOwned = jsonResponse["amount of stock owned"] as? Double ?? 0.0
                        }
                        
                        // Add parsing for next buy/sell prices
                        let nextBuyPrice: Double
                        if let buyPriceString = jsonResponse["next buy price"] as? String {
                            nextBuyPrice = Double(buyPriceString) ?? 0.0
                        } else {
                            nextBuyPrice = jsonResponse["next buy price"] as? Double ?? 0.0
                        }
                        
                        let nextSellPrice: Double
                        if let sellPriceString = jsonResponse["next sell price"] as? String {
                            nextSellPrice = Double(sellPriceString) ?? 0.0
                        } else {
                            nextSellPrice = jsonResponse["next sell price"] as? Double ?? 0.0
                        }
                        
                        guard let labels = jsonResponse["labels"] as? [String] else {
                            DispatchQueue.main.async {
                                self.errorMessage = "Invalid data format: Missing or incorrect 'labels'"
                            }
                            return
                        }
                        
                        var values: [Double] = []
                        if let numberValues = jsonResponse["values"] as? [NSNumber] {
                            values = numberValues.map { $0.doubleValue }
                        } else if let doubleValues = jsonResponse["values"] as? [Double] {
                            values = doubleValues
                        } else if let stringValues = jsonResponse["values"] as? [String] {
                            values = stringValues.compactMap { Double($0) }
                        } else {
                            DispatchQueue.main.async {
                                self.errorMessage = "Invalid data format: Missing or incorrect 'values'"
                            }
                            return
                        }
                        
                        DispatchQueue.main.async {
                            self.labels = labels
                            self.values = values
                            self.cashToTrade = cashToTrade
                            self.amountOwned = amountOwned
                            self.nextBuyPrice = nextBuyPrice
                            self.nextSellPrice = nextSellPrice
                            self.showChart = true
                            self.responseMessage = "Data fetched successfully!"
                        }
                    }
                } catch {
                    print("Failed to parse JSON: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to parse server response"
                    }
                }
            }
        }
        
        task.resume()
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Chart Components (unchanged from original)
struct ChartViewRepresentable_2: UIViewRepresentable {
    var labels: [String]
    var values: [Double]
    
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
        chartView.noDataText = "No data available"
        chartView.noDataTextColor = .lightGray
        
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.avoidFirstLastClippingEnabled = true
        xAxis.drawGridLinesEnabled = false
        
        let leftAxis = chartView.leftAxis
        leftAxis.drawZeroLineEnabled = true
        leftAxis.valueFormatter = DefaultAxisValueFormatter { value, _ in
            return String(format: "$%.2f", value)
        }
        
        chartView.rightAxis.enabled = false
        chartView.dragEnabled = true
        chartView.setScaleEnabled(false)
        chartView.pinchZoomEnabled = false
        chartView.highlightPerDragEnabled = true
        chartView.extraTopOffset = 30
    }

    private func updateChartData(chartView: LineChartView) {
        print("Updating chart with \(labels.count) labels and \(values.count) values")
        chartView.clear()
        
        // Make sure we have data to display
        guard !labels.isEmpty, !values.isEmpty else {
            print("⚠️ Cannot update chart - empty data")
            chartView.data = nil
            return
        }

        // Make sure our arrays have matching lengths
        let count = min(labels.count, values.count)
        guard count > 0 else {
            print("⚠️ Cannot update chart - no valid data")
            chartView.data = nil
            return
        }
        
        var dataEntries: [ChartDataEntry] = []
        var timestamps: [Double] = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Create entries with proper indices
        for i in 0..<count {
            let entry = ChartDataEntry(x: Double(i), y: Double(values[i]))
            dataEntries.append(entry)
            
            if let date = dateFormatter.date(from: labels[i]) {
                timestamps.append(date.timeIntervalSince1970)
            } else {
                timestamps.append(Double(i))
            }
        }
        
        // Configure the dataset
        let dataSet = LineChartDataSet(entries: dataEntries, label: "Account Value")
        dataSet.colors = [NSUIColor.systemBlue]
        dataSet.circleRadius = 3
        dataSet.circleColors = [NSUIColor.systemBlue]
        dataSet.drawCirclesEnabled = true
        dataSet.mode = .linear
        dataSet.lineWidth = 2
        dataSet.drawValuesEnabled = count <= 3
        
        // Special handling for single data point
        if count == 1 {
            dataSet.drawCirclesEnabled = true
            dataSet.circleRadius = 5
            dataSet.valueFont = .systemFont(ofSize: 12)
            dataSet.drawValuesEnabled = true
            
            // For a single point, create a dummy point to show a line
            if let entry = dataEntries.first {
                let dummyEntry = ChartDataEntry(x: entry.x + 1, y: entry.y)
                dataEntries.append(dummyEntry)
                dataSet.replaceEntries(dataEntries)
            }
        }
        
        // Set data and refresh chart
        let chartData = LineChartData(dataSet: dataSet)
        chartView.data = chartData
        
        // Configure axis labels and markers
        configureXAxisLabels(chartView: chartView, timestamps: timestamps)
        configureMarker(chartView: chartView, timestamps: timestamps)
        
        chartView.notifyDataSetChanged()
        print("Chart successfully updated with \(dataEntries.count) data points")
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
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let marker = CustomMarker_2(
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

class CustomMarker_2: MarkerView {
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
        valueText = String(format: "$%.2f", entry.y)
        
        let index = Int(entry.x)
        if index >= 0 && index < timestamps.count {
            let timestamp = timestamps[index]
            let date = Date(timeIntervalSince1970: timestamp)
            dateText = dateFormatter.string(from: date)
        } else {
            dateText = "Unknown"
        }
        
        setNeedsDisplay()
    }

    override func draw(context: CGContext, point: CGPoint) {
        guard let chart = chartView else { return }

        context.saveGState()
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(lineWidth)
        context.move(to: CGPoint(x: point.x, y: chart.viewPortHandler.contentTop))
        context.addLine(to: CGPoint(x: point.x, y: chart.viewPortHandler.contentBottom))
        context.strokePath()
        context.restoreGState()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: textColor
        ]

        let valueTextSize = valueText.size(withAttributes: attributes)
        let dateTextSize = dateText.size(withAttributes: attributes)
        
        let valueTextRect = CGRect(
            x: chart.viewPortHandler.contentLeft,
            y: chart.viewPortHandler.contentTop - valueTextSize.height - dateTextSize.height - 5,
            width: valueTextSize.width,
            height: valueTextSize.height
        )
        
        let dateTextRect = CGRect(
            x: chart.viewPortHandler.contentLeft,
            y: chart.viewPortHandler.contentTop - dateTextSize.height - 2,
            width: dateTextSize.width,
            height: dateTextSize.height
        )
        
        valueText.draw(in: valueTextRect, withAttributes: attributes)
        dateText.draw(in: dateTextRect, withAttributes: attributes)
    }

    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        return .zero
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(username: "PreviewUser", accountTotal: 1000.0)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
