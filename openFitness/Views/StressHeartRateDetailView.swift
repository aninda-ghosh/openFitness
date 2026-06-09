import SwiftUI

struct StressHeartRateDetailView: View {
    @ObservedObject var hkManager: HealthKitManager
    
    @State private var selectedTimeframe: Timeframe = .day // Default to D (Daily)
    @State private var selectedGraphTab: Int = 1 // 0: Stress Index, 1: Resting HR
    @State private var showAlgorithmDetails = false
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())

    private var cal: Calendar { Calendar.current }
    private var isViewingToday: Bool { cal.isDateInToday(selectedDay) }
    private var dayMetrics: DailyMetrics? {
        guard !isViewingToday else { return nil }
        return historicalMetrics.first { cal.isDate($0.date, inSameDayAs: selectedDay) }
    }

    private var historicalMetrics: [DailyMetrics] {
        hkManager.historicalMetrics
    }
    
    // 1. Recalculated dynamic stress average based on timeframe
    private var displayStress: Int {
        if selectedTimeframe != .day {
            let data = getStressData()
            return Int(data.average)
        }
        if isViewingToday { return hkManager.todayStressAverage }
        guard let dm = dayMetrics, dm.hrv > 0 else { return 0 }
        return max(5, min(95, Int(100.0 - dm.hrv * 0.95)))
    }
    
    private var stressClassification: String {
        let avg = displayStress
        if avg >= 75 { return "HIGH STRESS" }
        if avg >= 50 { return "ELEVATED" }
        if avg >= 30 { return "STABLE" }
        return "RESTORATIVE"
    }
    
    private var stressColor: Color {
        let avg = displayStress
        if avg >= 70 { return Theme.Colors.recoveryLow }
        if avg >= 40 { return Theme.Colors.recoveryMid }
        return Theme.Colors.recoveryHigh
    }
    
    private var stressExplanation: String {
        let avg = displayStress
        if avg >= 75 {
            return "Sympathetic dominance detected. Prioritize down-regulation and recovery."
        } else if avg >= 50 {
            return "Elevated autonomic tension. Autonomic nervous system is moderately stressed."
        } else if avg >= 30 {
            return "Balanced autonomic tension. Your system is in a stable, steady state."
        } else {
            return "Deep restorative state. Parasympathetic nervous system is active."
        }
    }

    
    // 2. Dynamic stress range based on timeframe
    private var displayStressRange: (lowest: Int, highest: Int) {
        if selectedTimeframe == .day {
            if isViewingToday { return (hkManager.todayStressLowest, hkManager.todayStressHighest) }
            guard let dm = dayMetrics, dm.hrv > 0 else { return (0, 0) }
            let stress = max(5.0, min(95.0, 100.0 - dm.hrv * 0.95))
            return (max(5, Int(stress - 12)), min(98, Int(stress + 15)))
        }
        let hrvs = filteredMetrics.map { $0.hrv }.filter { $0 > 0 }
        if hrvs.isEmpty { return (0, 0) }
        let stresses = hrvs.map { hrv -> Double in max(5.0, min(95.0, 100.0 - hrv * 0.95)) }
        let avgStress = stresses.reduce(0.0, +) / Double(stresses.count)
        return (max(5, Int(avgStress - 12)), min(98, Int(avgStress + 15)))
    }
    
    private var rangeLabel: String {
        let range = displayStressRange
        switch selectedTimeframe {
        case .day:
            return "Today's range: \(range.lowest)% - \(range.highest)%"
        case .threeDays:
            return "3-day average range: \(range.lowest)% - \(range.highest)%"
        case .week:
            return "Weekly average range: \(range.lowest)% - \(range.highest)%"
        case .month:
            return "Monthly average range: \(range.lowest)% - \(range.highest)%"
        case .sixMonths:
            return "6-month average range: \(range.lowest)% - \(range.highest)%"
        case .year:
            return "Annual average range: \(range.lowest)% - \(range.highest)%"
        }
    }
    
    // 3. Recalculated ANS balance based on selected timeframe's stress average
    private var ansBalance: (sympathetic: Int, parasympathetic: Int) {
        let sympathetic = displayStress
        let parasympathetic = 100 - sympathetic
        return (sympathetic, parasympathetic)
    }
    
    // 4. Recalculated Resting HR average based on timeframe
    private var displayRHR: Int {
        if selectedTimeframe == .day {
            if isViewingToday { return hkManager.todayRHR > 0 ? Int(hkManager.todayRHR) : 0 }
            guard let dm = dayMetrics, dm.rhr > 0 else { return 0 }
            return Int(dm.rhr)
        }
        let rhrs = filteredMetrics.map { $0.rhr }.filter { $0 > 0 }
        return rhrs.isEmpty ? 0 : Int(rhrs.reduce(0.0, +) / Double(rhrs.count))
    }

    // 5. Recalculated Average HR based on timeframe
    private var displayAverageHR: Int {
        if selectedTimeframe == .day {
            if isViewingToday { return hkManager.todayAverageHR > 0 ? Int(hkManager.todayAverageHR) : 0 }
            let start = cal.startOfDay(for: selectedDay)
            let end = cal.date(byAdding: .day, value: 1, to: start)!
            let samples = LocalPersistenceManager.shared.fetchSamples(typeIdentifier: "HKQuantityTypeIdentifierHeartRate", from: start, to: end)
            guard !samples.isEmpty else { return 0 }
            let sum = samples.reduce(0.0) { $0 + $1.value }
            return Int(sum / Double(samples.count))
        }
        let avgs = filteredMetrics.map { $0.averageHR }.filter { $0 > 0 }
        return avgs.isEmpty ? 0 : Int(avgs.reduce(0.0, +) / Double(avgs.count))
    }

    // 6. Recalculated Max HR based on timeframe
    private var displayMaxHR: Int {
        if selectedTimeframe == .day {
            if isViewingToday { return hkManager.todayMaxHR > 0 ? Int(hkManager.todayMaxHR) : 0 }
            let start = cal.startOfDay(for: selectedDay)
            let end = cal.date(byAdding: .day, value: 1, to: start)!
            let samples = LocalPersistenceManager.shared.fetchSamples(typeIdentifier: "HKQuantityTypeIdentifierHeartRate", from: start, to: end)
            guard !samples.isEmpty else { return 0 }
            return Int(samples.map { $0.value }.max() ?? 0)
        }
        let maxes = filteredMetrics.map { $0.maxHR }.filter { $0 > 0 }
        return maxes.isEmpty ? 0 : Int(maxes.reduce(0.0, +) / Double(maxes.count))
    }
    
    private var filteredMetrics: [DailyMetrics] {
        switch selectedTimeframe {
        case .day:
            // Filter historical metrics to get just the entry matching selectedDay
            return historicalMetrics.filter { cal.isDate($0.date, inSameDayAs: selectedDay) }
            
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
    
    private func getStressData() -> TimeframeData {
        let calendar = Calendar.current
        let fMetrics = filteredMetrics
        
        // Explicitly typed helper closure using DailyMetrics
        let calculateStress: (DailyMetrics) -> Double = { m in
            if m.hrv > 0 {
                return max(5.0, min(95.0, 100.0 - (m.hrv * 0.95)))
            } else {
                let hrDiff = 20.0
                let baseStress = 15.0 + hrDiff * 1.8
                return max(10.0, min(80.0, baseStress))
            }
        }

        if selectedTimeframe == .day {
            let labels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]
            
            let todaysStress: Double
            // Now fMetrics won't be empty! It will find today's data.
            if let latestMetric = fMetrics.last {
                todaysStress = calculateStress(latestMetric)
            } else {
                todaysStress = Double(displayStress)
            }
            
            guard todaysStress > 0 else { return TimeframeData(points: [], labels: labels, average: 0) }
            return TimeframeData(points: Array(repeating: todaysStress, count: 8), labels: labels, average: todaysStress)
        }
        
        let points = fMetrics.map { calculateStress($0) }
        let formatter = DateFormatter()
        let labels: [String]
        
        switch selectedTimeframe {
        case .day:
            labels = []
        case .threeDays, .week:
            formatter.dateFormat = "E"
            labels = fMetrics.map { formatter.string(from: $0.date) }
        case .month:
            labels = ["W1", "W2", "W3", "W4"]
        case .sixMonths:
            formatter.dateFormat = "MMM"
            var monthlySums6M: [Int: Double] = [:]
            var monthlyCounts6M: [Int: Double] = [:]
            var monthlyDates6M: [Int: Date] = [:]
            
            for m in fMetrics {
                let month = calendar.component(.month, from: m.date)
                let val = calculateStress(m)
                
                monthlySums6M[month, default: 0.0] += val
                monthlyCounts6M[month, default: 0.0] += 1.0
                monthlyDates6M[month] = m.date
            }
            
            let sortedMonths6M = monthlyDates6M.keys.sorted { monthlyDates6M[$0]! < monthlyDates6M[$1]! }
            let points6M = sortedMonths6M.map { month in
                (monthlySums6M[month] ?? 0.0) / (monthlyCounts6M[month] ?? 1.0)
            }
            let labels6M = sortedMonths6M.map { month in
                formatter.string(from: monthlyDates6M[month]!)
            }
            let average6M = points6M.isEmpty ? 0.0 : points6M.reduce(0, +) / Double(points6M.count)
            return TimeframeData(points: points6M, labels: labels6M, average: average6M)
            
        case .year:
            formatter.dateFormat = "MMM"
            var monthlySums: [Int: Double] = [:]
            var monthlyCounts: [Int: Double] = [:]
            var monthlyDates: [Int: Date] = [:]
            
            for m in fMetrics {
                let month = calendar.component(.month, from: m.date)
                let val = calculateStress(m)
                
                monthlySums[month, default: 0.0] += val
                monthlyCounts[month, default: 0.0] += 1.0
                monthlyDates[month] = m.date
            }
            
            let sortedMonths = monthlyDates.keys.sorted { monthlyDates[$1]! > monthlyDates[$0]! }
            let pointsYear = sortedMonths.map { month in
                (monthlySums[month] ?? 0.0) / (monthlyCounts[month] ?? 1.0)
            }
            let labelsYear = sortedMonths.map { month in
                formatter.string(from: monthlyDates[month]!)
            }
            let averageYear = pointsYear.isEmpty ? 0.0 : pointsYear.reduce(0, +) / Double(pointsYear.count)
            return TimeframeData(points: pointsYear, labels: labelsYear, average: averageYear)
        }

        let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
        return TimeframeData(points: points, labels: labels, average: average)
    }

    private func getHRData() -> TimeframeData {
        if selectedTimeframe == .day {
            let startOfSelectedDay = cal.startOfDay(for: selectedDay)
            let endOfSelectedDay = isViewingToday ? Date() : cal.date(byAdding: .day, value: 1, to: startOfSelectedDay)!
            let labels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]
            let segmentHours = [0, 3, 6, 9, 12, 15, 18, 21]

            let hrSamples = LocalPersistenceManager.shared.fetchSamples(
                typeIdentifier: "HKQuantityTypeIdentifierHeartRate",
                from: startOfSelectedDay,
                to: endOfSelectedDay
            )
            guard !hrSamples.isEmpty else { return TimeframeData(points: [], labels: labels, average: 0) }

            var segmentSums = [Double](repeating: 0.0, count: 8)
            var segmentCounts = [Int](repeating: 0, count: 8)
            for sample in hrSamples {
                let hour = cal.component(.hour, from: sample.startDate)
                var segIdx = 7
                for (i, h) in segmentHours.enumerated() {
                    if hour <= h { segIdx = i; break }
                }
                segmentSums[segIdx] += sample.value
                segmentCounts[segIdx] += 1
            }

            let points = (0..<8).map { i -> Double in
                segmentCounts[i] > 0 ? segmentSums[i] / Double(segmentCounts[i]) : 0.0
            }
            let nonZero = points.filter { $0 > 0 }
            let average = nonZero.isEmpty ? 0.0 : nonZero.reduce(0, +) / Double(nonZero.count)
            return TimeframeData(points: points, labels: labels, average: average)
        }

        let calendar = Calendar.current
        let fMetrics = filteredMetrics

        let points = fMetrics.map { $0.rhr > 0 ? $0.rhr : 0.0 }

        let formatter = DateFormatter()
        let labels: [String]
        switch selectedTimeframe {
        case .day:
            labels = [] // Handled in the guard block above
        case .threeDays:
            formatter.dateFormat = "E"
            labels = fMetrics.map { formatter.string(from: $0.date) }
        case .week:
            formatter.dateFormat = "E"
            labels = fMetrics.map { formatter.string(from: $0.date) }
        case .month:
            labels = ["W1", "W2", "W3", "W4"]
        case .sixMonths:
            formatter.dateFormat = "MMM"
            var monthlySums6M: [Int: Double] = [:]
            var monthlyCounts6M: [Int: Double] = [:]
            var monthlyDates6M: [Int: Date] = [:]
            for m in fMetrics {
                let month = calendar.component(.month, from: m.date)
                let val = m.rhr > 0 ? m.rhr : 0.0
                monthlySums6M[month, default: 0.0] += val
                monthlyCounts6M[month, default: 0.0] += 1.0
                monthlyDates6M[month] = m.date
            }
            let sortedMonths6M = monthlyDates6M.keys.sorted { monthlyDates6M[$0]! < monthlyDates6M[$1]! }
            let points6M = sortedMonths6M.map { month in
                (monthlySums6M[month] ?? 0.0) / (monthlyCounts6M[month] ?? 1.0)
            }
            let labels6M = sortedMonths6M.map { month in
                formatter.string(from: monthlyDates6M[month]!)
            }
            let average6M = points6M.isEmpty ? 0.0 : points6M.reduce(0, +) / Double(points6M.count)
            return TimeframeData(points: points6M, labels: labels6M, average: average6M)
        case .year:
            formatter.dateFormat = "MMM"
            var monthlySums: [Int: Double] = [:]
            var monthlyCounts: [Int: Double] = [:]
            var monthlyDates: [Int: Date] = [:]
            for m in fMetrics {
                let month = calendar.component(.month, from: m.date)
                let val = m.rhr > 0 ? m.rhr : 0.0
                monthlySums[month, default: 0.0] += val
                monthlyCounts[month, default: 0.0] += 1.0
                monthlyDates[month] = m.date
            }
            let sortedMonths = monthlyDates.keys.sorted { m1, m2 in
                monthlyDates[m1]! < monthlyDates[m2]!
            }
            let pointsYear = sortedMonths.map { month in
                (monthlySums[month] ?? 0.0) / (monthlyCounts[month] ?? 1.0)
            }
            let labelsYear = sortedMonths.map { month in
                formatter.string(from: monthlyDates[month]!)
            }
            let averageYear = pointsYear.isEmpty ? 0.0 : pointsYear.reduce(0, +) / Double(pointsYear.count)
            return TimeframeData(points: pointsYear, labels: labelsYear, average: averageYear)
        }

        let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
        return TimeframeData(points: points, labels: labels, average: average)
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    CustomSegmentedPicker(selection: $selectedTimeframe)
                        .padding(.top, 10)

                    PeriodNavigationView(timeframe: .day, baseDate: $selectedDay, accentColor: Theme.Colors.recoveryMid)

                    // Compact Score Card
                    HStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .stroke(stressColor.opacity(0.08), lineWidth: 6)
                                .frame(width: 64, height: 64)
                            
                            Circle()
                                .trim(from: 0.0, to: CGFloat(Double(displayStress) / 100.0))
                                .stroke(
                                    LinearGradient(colors: [stressColor, stressColor.opacity(0.6)], startPoint: .top, endPoint: .bottom),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .frame(width: 64, height: 64)
                                .rotationEffect(.degrees(-90))
                                .shadow(color: stressColor.opacity(0.3), radius: 4)
                            
                            Text("\(displayStress)%")
                                .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 64, height: 64)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stressClassification)
                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                .foregroundColor(stressColor)
                            
                            Text(stressExplanation)
                                .font(Theme.Typography.roundedFont(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(3)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80, alignment: .leading)
                    .glassCard()
                    .padding(.horizontal)
                    
                    // Autonomic Tension Details Card
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AUTONOMIC BALANCE")
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundColor(.white.opacity(0.5))
                                Text("Stress Range & Autonomic Balance")
                                    .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "bolt.heart.fill")
                                .font(.title3)
                                .foregroundColor(stressColor)
                        }
                        
                        // Recalculating Range Slider
                        VStack(alignment: .leading, spacing: 6) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 6)
                                    
                                    let range = displayStressRange
                                    let lowPct = CGFloat(range.lowest) / 100.0
                                    let highPct = CGFloat(range.highest) / 100.0
                                    
                                    Capsule()
                                        .fill(stressColor.opacity(0.25))
                                        .frame(width: max(10, geo.size.width * (highPct - lowPct)), height: 6)
                                        .offset(x: geo.size.width * lowPct)
                                    
                                    Circle()
                                        .fill(stressColor)
                                        .frame(width: 12, height: 12)
                                        .offset(x: min(geo.size.width - 12, max(0, geo.size.width * CGFloat(displayStress) / 100.0 - 6)), y: -3)
                                }
                            }
                            .frame(height: 12)
                            
                            Text(rangeLabel)
                                .font(Theme.Typography.roundedFont(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        
                        Divider().background(Color.white.opacity(0.08))
                        
                        // Recalculating ANS Balance gauge
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Sympathetic (Alert)")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                    .foregroundColor(Theme.Colors.strainHigh)
                                Spacer()
                                Text("Parasympathetic (Rest)")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                    .foregroundColor(Theme.Colors.recoveryHigh)
                            }
                            
                            let balance = ansBalance
                            GeometryReader { geo in
                                HStack(spacing: 0) {
                                    Capsule()
                                        .fill(Theme.Colors.strainHigh)
                                        .frame(width: max(4, geo.size.width * CGFloat(balance.sympathetic) / 100.0), height: 8)
                                    
                                    Capsule()
                                        .fill(Theme.Colors.recoveryHigh)
                                        .frame(width: max(4, geo.size.width * CGFloat(balance.parasympathetic) / 100.0), height: 8)
                                }
                            }
                            .frame(height: 8)
                            .cornerRadius(4)
                            
                            HStack {
                                Text("\(balance.sympathetic)%")
                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                    .foregroundColor(Theme.Colors.strainHigh)
                                Spacer()
                                Text("\(balance.parasympathetic)%")
                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                    .foregroundColor(Theme.Colors.recoveryHigh)
                            }
                        }
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // COHERENT CARD 2: Heart Rate Biomarkers (Recalculating Averages)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CARDIAC LOAD")
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundColor(.white.opacity(0.5))
                                Text(selectedTimeframe == .day ? "Today's Heart Rate Biomarkers" : "Heart Rate Averages")
                                    .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "waveform.path.ecg")
                                .font(.title3)
                                .foregroundColor(Theme.Colors.sleepREM)
                        }
                        .padding(.bottom, 4)
                        
                        HStack(spacing: 12) {
                            // RHR Card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("RESTING")
                                    .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.4))
                                Text("\(displayRHR) bpm")
                                    .font(Theme.Typography.roundedFont(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
                            
                            // AVG Card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AVERAGE")
                                    .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.4))
                                Text("\(displayAverageHR) bpm")
                                    .font(Theme.Typography.roundedFont(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
                            
                            // MAX Card
                            VStack(alignment: .leading, spacing: 4) {
                                Text("MAXIMUM")
                                    .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.4))
                                Text("\(displayMaxHR) bpm")
                                    .font(Theme.Typography.roundedFont(size: 18, weight: .bold))
                                    .foregroundColor(Theme.Colors.strainHigh)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // COHERENT CARD 3: Tabbed Autonomic Trends (Stress vs HR)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedGraphTab = 1
                                }
                            }) {
                                Text("Resting HR")
                                    .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                    .foregroundColor(selectedGraphTab == 1 ? .white : .white.opacity(0.4))
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedGraphTab == 1 ? Color.white.opacity(0.08) : Color.clear)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedGraphTab = 0
                                }
                            }) {
                                Text("Stress Index")
                                    .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                    .foregroundColor(selectedGraphTab == 0 ? .white : .white.opacity(0.4))
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedGraphTab == 0 ? Color.white.opacity(0.08) : Color.clear)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                        .padding(.bottom, 4)
                        
                        if selectedGraphTab == 0 {
                            let stressTrend = getStressData()
                            VStack(alignment: .leading, spacing: 12) {
                                CustomLineGraph(
                                    points: stressTrend.points,
                                    labels: stressTrend.labels,
                                    lineColor: Theme.Colors.recoveryMid,
                                    gradientColors: [Theme.Colors.recoveryMid.opacity(0.2), .clear]
                                )
                                .frame(height: 140)
                                .transition(.opacity)
                                
                                HStack {
                                    Text(selectedTimeframe == .day ? String(format: "Current Stress: %.0f%%", stressTrend.average) : String(format: "Average Stress: %.0f%%", stressTrend.average))
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text("Status: \(stressClassification)")
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                        .foregroundColor(stressColor)
                                }
                                .padding(.top, 4)
                            }
                        } else {
                            let hrTrend = getHRData()
                            VStack(alignment: .leading, spacing: 12) {
                                CustomLineGraph(
                                    points: hrTrend.points,
                                    labels: hrTrend.labels,
                                    lineColor: Theme.Colors.sleepREM,
                                    gradientColors: [Theme.Colors.sleepREM.opacity(0.2), .clear]
                                )
                                .frame(height: 140)
                                .transition(.opacity)
                                
                                HStack {
                                    Text(selectedTimeframe == .day ? String(format: "Average HR: %.0f bpm", hrTrend.average) : String(format: "Average RHR: %.0f bpm", hrTrend.average))
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text(selectedTimeframe == .day ? "Min: \(Int(hrTrend.points.min() ?? 0.0)) • Max: \(Int(hrTrend.points.max() ?? 0.0))" : "Min RHR: \(Int(hrTrend.points.min() ?? 0.0)) • Max RHR: \(Int(hrTrend.points.max() ?? 0.0))")
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                        .foregroundColor(Theme.Colors.sleepREM)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // Scientific Accordion
                    VStack(alignment: .leading, spacing: 14) {
                        Button(action: {
                            withAnimation(.spring()) {
                                showAlgorithmDetails.toggle()
                            }
                        }) {
                            HStack {
                                Text("Autonomic Balance & Science")
                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: showAlgorithmDetails ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        if showAlgorithmDetails {
                            Divider().background(Color.white.opacity(0.08))
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("ESTIMATING STRESS FROM BEAT VARIABILITY")
                                    .font(Theme.Typography.roundedFont(size: 11, weight: .bold))
                                    .foregroundColor(Theme.Colors.recoveryMid)
                                
                                Text("Autonomic Nervous System:")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("• Sympathetic (Fight or Flight): Dominates during exertion, high stress, or fatigue. It accelerates heart rate and makes inter-beat intervals highly uniform.\n• Parasympathetic (Rest & Digest): Dominates during rest, meditation, or recovery. It slows heart rate and increases time variation between beats.")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineSpacing(4)
                                
                                Text("Math Model:")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Stress % = Max(5.0, Min(95.0, 100.0 - (SDNN * 0.95)))")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(8)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(6)
                                
                                Text("Standard Deviation of Normal-to-Normal heartbeats (SDNN) measures the variance. If SDNN is low (e.g. 20ms), your stress scales high (81%). If SDNN is high (e.g. 90ms), your stress maps low (14%), reflecting strong parasympathetic recovery.")
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
        .navigationTitle("Stress & Heart Rate")
        .navigationBarTitleDisplayMode(.inline)
    }
}
