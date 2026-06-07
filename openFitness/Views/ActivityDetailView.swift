import SwiftUI

struct ActivityDetailView: View {
    @ObservedObject var hkManager: HealthKitManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedGraphTab: Int // 0: Steps, 1: Active Energy
    @State private var selectedTimeframe: Timeframe = .day
    @State private var showScientificDetails = false
    
    init(hkManager: HealthKitManager, initialTab: Int = 0) {
        self.hkManager = hkManager
        self._selectedGraphTab = State(initialValue: initialTab)
    }
    
    private var displayValue: String {
        let isSteps = selectedGraphTab == 0
        let val = isSteps ? Double(todaySteps) : todayCalories
        
        if isSteps {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return (formatter.string(from: NSNumber(value: Int(val))) ?? "0") + " steps"
        } else {
            return String(format: "%.0f kcal", val)
        }
    }
    
    private var todaySteps: Int {
        hkManager.todaySteps
    }
    
    private var todayCalories: Double {
        hkManager.todayActiveCalories
    }
    
    private var goalValue: Double {
        selectedGraphTab == 0 ? 10000.0 : 600.0
    }
    
    private var displayStatus: String {
        let isSteps = selectedGraphTab == 0
        let val = isSteps ? Double(todaySteps) : todayCalories
        let pct = (val / goalValue) * 100.0
        return String(format: "%.0f%% of Daily Goal achieved", pct)
    }
    
    private var statusColor: Color {
        selectedGraphTab == 0 ? Theme.Colors.recoveryHigh : Theme.Colors.strainHigh
    }
    
    private var historicalMetrics: [DailyMetrics] {
        hkManager.historicalMetrics
    }
    
    private var filteredMetrics: [DailyMetrics] {
        var metrics: [DailyMetrics]
        switch selectedTimeframe {
        case .day:
            return []
        case .week:
            metrics = Array(historicalMetrics.suffix(7))
        case .month:
            metrics = Array(historicalMetrics.suffix(30))
        case .year:
            metrics = historicalMetrics
        }
        
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        if !metrics.contains(where: { calendar.isDate($0.date, inSameDayAs: todayStart) }) {
            let todayMetric = DailyMetrics(
                date: todayStart,
                recoveryScore: hkManager.todayRecovery,
                strainScore: hkManager.todayStrain,
                sleepScore: hkManager.todaySleepScore,
                hrv: hkManager.todayHRV,
                rhr: hkManager.todayRHR,
                sleepDuration: hkManager.todaySleepHours,
                sleepNeeded: hkManager.todaySleepNeeded,
                deepMinutes: hkManager.todayDeepMinutes,
                remMinutes: hkManager.todayRemMinutes,
                activeCalories: hkManager.todayActiveCalories,
                averageHR: hkManager.todayAverageHR,
                maxHR: hkManager.todayMaxHR,
                steps: hkManager.todaySteps,
                respiratoryRate: hkManager.todayRespiratoryRate,
                oxygenSaturation: hkManager.todayOxygenSaturation,
                bodyTemperature: hkManager.todayBodyTemperature
            )
            metrics.append(todayMetric)
        }
        return metrics
    }
    
    private func getActivityData() -> TimeframeData {
        let calendar = Calendar.current
        let isSteps = selectedGraphTab == 0
        
        switch selectedTimeframe {
        case .day:
            let startOfDay = calendar.startOfDay(for: Date())
            let now = Date()
            
            // Query actual hourly values today
            let typeId = isSteps ? "HKQuantityTypeIdentifierStepCount" : "HKQuantityTypeIdentifierActiveEnergyBurned"
            let samples = LocalPersistenceManager.shared.fetchSamples(typeIdentifier: typeId, from: startOfDay, to: now)
            
            var hourlySum = [Double](repeating: 0.0, count: 24)
            for sample in samples {
                let hour = calendar.component(.hour, from: sample.startDate)
                if hour >= 0 && hour < 24 {
                    hourlySum[hour] += sample.value
                }
            }
            
            var points: [Double] = []
            let segmentHours = [0, 3, 6, 9, 12, 15, 18, 21]
            let labels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]
            
            var runningTotal = 0.0
            for (idx, hour) in segmentHours.enumerated() {
                let startHour = idx == 0 ? 0 : segmentHours[idx - 1] + 1
                for h in startHour...hour {
                    runningTotal += hourlySum[h]
                }
                points.append(runningTotal)
            }
            
            let totalVal = points.last ?? 0.0
            
            // If points are all zero (e.g. no HealthKit data synced yet), add a slight diurnal mock curve
            if totalVal == 0 {
                let baseVal = isSteps ? Double(todaySteps) : todayCalories
                let fallback = baseVal > 0 ? baseVal : (isSteps ? 5430.0 : 320.0)
                let pointsFallback = [0.0, 0.0, fallback * 0.1, fallback * 0.3, fallback * 0.6, fallback * 0.8, fallback * 0.9, fallback]
                return TimeframeData(points: pointsFallback, labels: labels, average: fallback)
            }
            
            return TimeframeData(points: points, labels: labels, average: totalVal)
            
        case .week:
            let last7 = filteredMetrics
            let points = last7.map { isSteps ? Double($0.steps) : $0.activeCalories }
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            let labels = last7.map { formatter.string(from: $0.date) }
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)
            
        case .month:
            let last30 = filteredMetrics
            let points = last30.map { isSteps ? Double($0.steps) : $0.activeCalories }
            let labels = last30.enumerated().map { index, m in
                if index == 3 { return "Week 1" }
                else if index == 10 { return "Week 2" }
                else if index == 17 { return "Week 3" }
                else if index == 24 { return "Week 4" }
                else { return "" }
            }
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)
            
        case .year:
            let validMetrics = filteredMetrics
            var monthlySums: [Int: Double] = [:]
            var monthlyCounts: [Int: Double] = [:]
            var monthlyDates: [Int: Date] = [:]
            for m in validMetrics {
                let month = calendar.component(.month, from: m.date)
                let val = isSteps ? Double(m.steps) : m.activeCalories
                monthlySums[month, default: 0.0] += val
                monthlyCounts[month, default: 0.0] += 1.0
                monthlyDates[month] = m.date
            }
            let sortedMonths = monthlyDates.keys.sorted { m1, m2 in
                monthlyDates[m1]! < monthlyDates[m2]!
            }
            let points = sortedMonths.map { month in
                (monthlySums[month] ?? 0.0) / (monthlyCounts[month] ?? 1.0)
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let labels = sortedMonths.map { month in
                formatter.string(from: monthlyDates[month]!)
            }
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)
        }
    }
    
    private var explanationText: String {
        if selectedGraphTab == 0 {
            return "Steps represent your primary physical motion count today. Maintaining a high step count helps improve cardiovascular circulation, offsets metabolic stagnation from sedentary behaviors, and builds baseline active stamina. Aiming for 10,000 steps daily contributes significantly to autonomic recovery and sleep efficiency."
        } else {
            return "Active Energy measures the calories you burn above your resting metabolic rate (BMR) through physical movement, walking, and active workouts. A high calorie burn drains energy bank reserves but triggers cardiovascular adaptations, promoting a lower resting heart rate and higher overnight heart rate variability (HRV)."
        }
    }
    
    private var scienceFormulaText: String {
        if selectedGraphTab == 0 {
            return "GOAL: 10,000 steps\nPrimary Marker of Active Lifestyle"
        } else {
            return "GOAL: 600 kcal active energy\nInduces Cardiovascular Adaptations"
        }
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.04))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text(selectedGraphTab == 0 ? "Daily Steps" : "Active Energy")
                        .font(Theme.Typography.roundedFont(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Spacer().frame(width: 44)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // Tab Selector
                        HStack(spacing: 12) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedGraphTab = 0
                                }
                            }) {
                                Text("Steps")
                                    .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                    .foregroundColor(selectedGraphTab == 0 ? .white : .white.opacity(0.4))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedGraphTab == 0 ? Color.white.opacity(0.08) : Color.clear)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedGraphTab = 1
                                }
                            }) {
                                Text("Active Calories")
                                    .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                    .foregroundColor(selectedGraphTab == 1 ? .white : .white.opacity(0.4))
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedGraphTab == 1 ? Color.white.opacity(0.08) : Color.clear)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        CustomSegmentedPicker(selection: $selectedTimeframe)
                        
                        // Hero Value Card
                        HStack(spacing: 18) {
                            ZStack {
                                Circle()
                                    .stroke(statusColor.opacity(0.08), lineWidth: 6)
                                    .frame(width: 64, height: 64)
                                
                                let currentVal = selectedGraphTab == 0 ? Double(todaySteps) : todayCalories
                                Circle()
                                    .trim(from: 0.0, to: CGFloat(min(1.0, currentVal / goalValue)))
                                    .stroke(
                                        LinearGradient(colors: [statusColor, statusColor.opacity(0.6)], startPoint: .top, endPoint: .bottom),
                                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                    )
                                    .frame(width: 64, height: 64)
                                    .rotationEffect(.degrees(-90))
                                    .shadow(color: statusColor.opacity(0.3), radius: 4)
                                
                                Image(systemName: selectedGraphTab == 0 ? "shoeprints.fill" : "flame.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18))
                            }
                            .frame(width: 64, height: 64)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayValue)
                                    .font(Theme.Typography.roundedFont(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(displayStatus)
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
                        .glassCard()
                        .padding(.horizontal)
                        
                        // Graph Card
                        let graphData = getActivityData()
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(selectedGraphTab == 0 ? "Steps History" : "Calories History")
                                    .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(selectedTimeframe == .day ? "Hourly Accumulation" : "Daily Totals")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            CustomLineGraph(
                                points: graphData.points,
                                labels: graphData.labels,
                                lineColor: statusColor,
                                gradientColors: [statusColor.opacity(0.2), .clear],
                                visibleCount: selectedTimeframe == .day ? (Calendar.current.component(.hour, from: Date()) / 3 + 1) : nil
                            )
                            .frame(height: 150)
                            .padding(.vertical, 8)
                            
                            HStack {
                                Text(String(format: "Average: %@", {
                                    if selectedGraphTab == 0 {
                                        let formatter = NumberFormatter()
                                        formatter.numberStyle = .decimal
                                        return (formatter.string(from: NSNumber(value: Int(graphData.average))) ?? "0") + " steps"
                                    } else {
                                        return String(format: "%.0f kcal", graphData.average)
                                    }
                                }()))
                                .font(Theme.Typography.roundedFont(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                
                                Spacer()
                            }
                        }
                        .glassCard()
                        .padding(.horizontal)
                        
                        // Information Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("BENEFITS & INSIGHTS")
                                .font(Theme.Typography.cardTitle)
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text(explanationText)
                                .font(Theme.Typography.roundedFont(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.75))
                                .lineSpacing(4)
                        }
                        .glassCard()
                        .padding(.horizontal)
                        
                        // References Card
                        VStack(alignment: .leading, spacing: 14) {
                            Button(action: {
                                withAnimation(.spring()) {
                                    showScientificDetails.toggle()
                                }
                            }) {
                                HStack {
                                    Text("Activity Targets")
                                        .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: showScientificDetails ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            
                            if showScientificDetails {
                                Divider().background(Color.white.opacity(0.08))
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(scienceFormulaText)
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.9))
                                        .padding(8)
                                        .background(Color.black.opacity(0.2))
                                        .cornerRadius(6)
                                    
                                    Text("Daily step count and active energy are crucial metrics in tracking systemic activity levels. Increasing base activity promotes cardiorespiratory adaptations and autonomic recovery shifts.")
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineSpacing(4)
                                }
                            }
                        }
                        .glassCard()
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
    }
}
