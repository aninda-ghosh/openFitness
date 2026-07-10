import SwiftUI

struct ActivityDetailView: View {
    @ObservedObject var hkManager: HealthKitManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedGraphTab: Int // 0: Steps, 1: Active Energy
    @State private var selectedTimeframe: Timeframe = .day
    @State private var showScientificDetails = false
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())

    private var cal: Calendar { Calendar.current }
    private var isViewingToday: Bool { cal.isDateInToday(selectedDay) }
    private var dayMetrics: DailyMetrics? {
        guard !isViewingToday else { return nil }
        return historicalMetrics.first { cal.isDate($0.date, inSameDayAs: selectedDay) }
    }

    init(hkManager: HealthKitManager, initialTab: Int = 0) {
        self.hkManager = hkManager
        self._selectedGraphTab = State(initialValue: initialTab)
    }
    
    private var displaySteps: Int {
        isViewingToday ? hkManager.todaySteps : (dayMetrics?.steps ?? 0)
    }
    private var displayCalories: Double {
        isViewingToday ? hkManager.todayActiveCalories : (dayMetrics?.activeCalories ?? 0)
    }

    private var displayValue: String {
        let isSteps = selectedGraphTab == 0
        let val = isSteps ? Double(displaySteps) : displayCalories

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
        let val = isSteps ? Double(displaySteps) : displayCalories
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
        switch selectedTimeframe {
        case .day:
            return []
        case .threeDays:
            let start = cal.date(byAdding: .day, value: -2, to: selectedDay)!
            return historicalMetrics.filter { $0.date >= start && $0.date <= selectedDay }
        case .week:
            let start = cal.date(byAdding: .day, value: -6, to: selectedDay)!
            return historicalMetrics.filter { $0.date >= start && $0.date <= selectedDay }
        case .month:
            let start = cal.date(byAdding: .day, value: -29, to: selectedDay)!
            return historicalMetrics.filter { $0.date >= start && $0.date <= selectedDay }
        case .sixMonths:
            let start = cal.date(byAdding: .day, value: -179, to: selectedDay)!
            return historicalMetrics.filter { $0.date >= start && $0.date <= selectedDay }
        case .year:
            let start = cal.date(byAdding: .day, value: -364, to: selectedDay)!
            return historicalMetrics.filter { $0.date >= start && $0.date <= selectedDay }
        }
    }

    private func getActivityData() -> TimeframeData {
        let calendar = Calendar.current
        let isSteps = selectedGraphTab == 0

        switch selectedTimeframe {
        case .day:
            let startOfDay = calendar.startOfDay(for: selectedDay)
            let endOfDay = isViewingToday ? Date() : calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)

            let typeId = isSteps ? "HKQuantityTypeIdentifierStepCount" : "HKQuantityTypeIdentifierActiveEnergyBurned"
            let samples = LocalPersistenceManager.shared.fetchSamples(typeIdentifier: typeId, from: startOfDay, to: endOfDay)

            var hourlySum = [Double](repeating: 0.0, count: 24)
            for sample in samples {
                let hour = calendar.component(.hour, from: sample.startDate)
                if hour >= 0 && hour < 24 {
                    hourlySum[hour] += sample.value
                }
            }

            let segmentHours = [0, 3, 6, 9, 12, 15, 18, 21]
            let labels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]

            var cumulativePoints: [Double] = []
            var runningTotal = 0.0
            for (idx, hour) in segmentHours.enumerated() {
                let startHour = idx == 0 ? 0 : segmentHours[idx - 1] + 1
                for h in startHour...hour {
                    runningTotal += hourlySum[h]
                }
                cumulativePoints.append(runningTotal)
            }

            // Live HealthKit total (deduplicated across sources — authoritative)
            let liveTotal = isSteps ? Double(displaySteps) : displayCalories
            let cacheTotal = cumulativePoints.last ?? 0.0

            if liveTotal == 0 && cacheTotal == 0 {
                return TimeframeData(points: [], labels: labels, average: 0)
            }

            var finalPoints: [Double]
            if cacheTotal > 0 {
                // Normalize cached hourly shape to the live HealthKit total
                let scale = liveTotal > 0 ? liveTotal / cacheTotal : 1.0
                finalPoints = cumulativePoints.map { $0 * scale }
            } else {
                // No hourly breakdown — flat line at live total for completed hours
                finalPoints = cumulativePoints // all zeros; chart shows empty until data arrives
            }

            return TimeframeData(points: finalPoints, labels: labels, average: liveTotal)

        case .threeDays:
            let relevant = filteredMetrics
            let points = relevant.map { isSteps ? Double($0.steps) : $0.activeCalories }
            let formatter = DateFormatter(); formatter.dateFormat = "E"
            let labels = relevant.map { formatter.string(from: $0.date) }
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)

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
            let labels = ["W1", "W2", "W3", "W4"]
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)

        case .sixMonths:
            let validMetrics6M = filteredMetrics
            var monthlySums6M: [Int: Double] = [:]
            var monthlyCounts6M: [Int: Double] = [:]
            var monthlyDates6M: [Int: Date] = [:]
            for m in validMetrics6M {
                let month = calendar.component(.month, from: m.date)
                let val = isSteps ? Double(m.steps) : m.activeCalories
                monthlySums6M[month, default: 0.0] += val
                monthlyCounts6M[month, default: 0.0] += 1.0
                monthlyDates6M[month] = m.date
            }
            let sortedMonths6M = monthlyDates6M.keys.sorted { monthlyDates6M[$0]! < monthlyDates6M[$1]! }
            let points6M = sortedMonths6M.map { month in
                (monthlySums6M[month] ?? 0.0) / (monthlyCounts6M[month] ?? 1.0)
            }
            let formatter6M = DateFormatter()
            formatter6M.dateFormat = "MMM"
            let labels6M = sortedMonths6M.map { month in
                formatter6M.string(from: monthlyDates6M[month]!)
            }
            let average6M = points6M.isEmpty ? 0.0 : points6M.reduce(0, +) / Double(points6M.count)
            return TimeframeData(points: points6M, labels: labels6M, average: average6M)

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
            AppBackground(accent: Theme.Colors.recoveryHigh)

            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(Theme.Typography.titleSM)
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

                        PeriodNavigationView(timeframe: .day, baseDate: $selectedDay, accentColor: Theme.Colors.recoveryHigh)

                        // Hero Value Card
                        HStack(spacing: 18) {
                            ZStack {
                                Circle()
                                    .stroke(statusColor.opacity(0.08), lineWidth: 6)
                                    .frame(width: 64, height: 64)

                                let currentVal = selectedGraphTab == 0 ? Double(displaySteps) : displayCalories
                                Circle()
                                    .trim(from: 0.0, to: CGFloat(min(1.0, currentVal / goalValue)))
                                    .stroke(
                                        statusColor,
                                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                    )
                                    .frame(width: 64, height: 64)
                                    .rotationEffect(.degrees(-90))
                                    .shadow(color: statusColor.opacity(0.3), radius: 4)
                                
                                Image(systemName: selectedGraphTab == 0 ? "shoeprints.fill" : "flame.fill")
                                    .foregroundColor(.white)
                                    .font(Theme.Typography.titleSM)
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
                                visibleCount: selectedTimeframe == .day && isViewingToday
                                ? (Calendar.current.component(.hour, from: Date()) / 3 + 1) : nil
                            )
                            .frame(height: 150)
                            .padding(.vertical, 8)
                            
                            HStack {
                                Text({
                                    let prefix = selectedTimeframe == .day ? "Total: " : "Average: "
                                    if selectedGraphTab == 0 {
                                        let formatter = NumberFormatter()
                                        formatter.numberStyle = .decimal
                                        let val = (formatter.string(from: NSNumber(value: Int(graphData.average))) ?? "0") + " steps"
                                        return prefix + val
                                    } else {
                                        return prefix + String(format: "%.0f kcal", graphData.average)
                                    }
                                }())
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

                        MetricInsightCard(metric: .activity, hkManager: hkManager)
                            .padding(.horizontal)
                    }
                    .containerRelativeFrame(.horizontal)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
    }
}
