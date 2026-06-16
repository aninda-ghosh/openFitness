import SwiftUI

enum VitalType: String {
    case respiratoryRate = "Respiratory Rate"
    case oxygenSaturation = "Oxygen Saturation"
    case bodyTemperature = "Skin Temperature"
    case bodyFatPercentage = "Body Fat"
    case vo2Max = "VO2 Max"
    case bmi = "BMI"
    case weight = "Weight"
}

struct VitalsDetailView: View {
    @ObservedObject var hkManager: HealthKitManager
    let type: VitalType
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTimeframe: Timeframe
    @State private var showScientificDetails = false
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())

    init(hkManager: HealthKitManager, type: VitalType) {
        self.hkManager = hkManager
        self.type = type
        _selectedTimeframe = State(initialValue: .day)
    }

    private var cal: Calendar { Calendar.current }
    private var isViewingToday: Bool { cal.isDateInToday(selectedDay) }
    private var dayMetrics: DailyMetrics? {
        guard !isViewingToday else { return nil }
        return historicalMetrics.first { cal.isDate($0.date, inSameDayAs: selectedDay) }
    }

    private var typeIdentifier: String {
        switch type {
        case .respiratoryRate:   return "HKQuantityTypeIdentifierRespiratoryRate"
        case .oxygenSaturation:  return "HKQuantityTypeIdentifierOxygenSaturation"
        case .bodyTemperature:   return "HKQuantityTypeIdentifierAppleSleepingWristTemperature"
        case .bodyFatPercentage: return "HKQuantityTypeIdentifierBodyFatPercentage"
        case .vo2Max:            return "HKQuantityTypeIdentifierVO2Max"
        case .bmi:               return "HKQuantityTypeIdentifierBodyMassIndex"
        case .weight:            return "HKQuantityTypeIdentifierBodyMass"
        }
    }

    private var displayedValue: Double {
        switch type {
        case .respiratoryRate, .oxygenSaturation, .bodyTemperature:
            if isViewingToday { return todayValue }
            guard let m = dayMetrics else { return 0 }
            switch type {
            case .respiratoryRate:  return m.respiratoryRate
            case .oxygenSaturation: return m.oxygenSaturation
            default:                return m.bodyTemperature
            }
        case .bodyFatPercentage, .vo2Max, .bmi, .weight:
            if isViewingToday { return todayValue }
            let start = cal.startOfDay(for: selectedDay)
            let end = cal.date(byAdding: .day, value: 1, to: start)!
            let samples = LocalPersistenceManager.shared.fetchSamples(typeIdentifier: typeIdentifier, from: start, to: end)
            let raw = samples.last?.value ?? 0.0
            return type == .bodyFatPercentage ? raw * 100.0 : raw
        }
    }

    private var displayValue: String {
        let val = displayedValue
        if val <= 0 { return "--" }
        switch type {
        case .respiratoryRate:   return String(format: "%.1f rpm", val)
        case .oxygenSaturation:  return String(format: "%.1f%%", val)
        case .bodyTemperature:   return String(format: "%.1f °C", val)
        case .bodyFatPercentage: return String(format: "%.1f%%", val)
        case .vo2Max:            return String(format: "%.1f ml/kg·min", val)
        case .bmi:               return String(format: "%.1f", val)
        case .weight:      return String(format: "%.1f kg", val)
        }
    }
    
    private var todayValue: Double {
        switch type {
        case .respiratoryRate:   return hkManager.todayRespiratoryRate
        case .oxygenSaturation:  return hkManager.todayOxygenSaturation
        case .bodyTemperature:   return hkManager.todayBodyTemperature
        case .bodyFatPercentage: return hkManager.todayBodyFatPercentage
        case .vo2Max:            return hkManager.todayVO2Max
        case .bmi:               return hkManager.todayBMI
        case .weight:            return hkManager.todayWeight
        }
    }
    
    private var displayStatus: String {
        let val = displayedValue
        if val <= 0 { return "No Data" }
        switch type {
        case .respiratoryRate:
            return val > 18.0 ? "Higher" : (val < 12.0 ? "Lower" : "Normal")
        case .oxygenSaturation:
            return val < 95.0 ? "Lower" : "Optimal"
        case .bodyTemperature:
            return val > 37.0 ? "Higher" : (val < 35.5 ? "Lower" : "Normal")
        case .bodyFatPercentage:
            return val > 32 ? "High" : (val > 20 ? "Average" : (val > 10 ? "Fit" : "Athletic"))
        case .vo2Max:
            return val >= 52 ? "Excellent" : (val >= 42 ? "Good" : (val >= 34 ? "Fair" : "Low"))
        case .bmi:
            return val >= 30 ? "Obese" : (val >= 25 ? "Overweight" : (val >= 18.5 ? "Normal" : "Underweight"))
        case .weight:
            return "Tracked"
        }
    }

    private var statusColor: Color {
        let val = displayedValue
        let status = displayStatus
        if status == "No Data" { return .gray }
        switch type {
        case .respiratoryRate, .bodyTemperature:
            return status == "Normal" ? Theme.Colors.recoveryHigh : Color.orange
        case .oxygenSaturation:
            return status == "Optimal" ? Theme.Colors.recoveryHigh : Theme.Colors.recoveryLow
        case .bodyFatPercentage:
            return status == "High" ? Theme.Colors.recoveryLow : (status == "Average" ? Color.orange : Theme.Colors.recoveryHigh)
        case .vo2Max:
            return (status == "Excellent" || status == "Good") ? Theme.Colors.recoveryHigh : (status == "Fair" ? Color.orange : Theme.Colors.recoveryLow)
        case .bmi:
            return status == "Normal" ? Theme.Colors.recoveryHigh : (status == "Obese" ? Theme.Colors.recoveryLow : Color.orange)
        case .weight:
            return val > 0 ? Theme.Colors.recoveryHigh : .gray
        }
    }
    
    private var isBodyComp: Bool {
        type == .bodyFatPercentage || type == .vo2Max || type == .bmi || type == .weight
    }

    private var historicalMetrics: [DailyMetrics] {
        hkManager.historicalMetrics
    }
    
    private var filteredMetrics: [DailyMetrics] {
        switch selectedTimeframe {
        case .day:
            return []
        case .threeDays, .week:
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

    private func directSamples(from start: Date, to end: Date) -> TimeframeData {
        let raw = LocalPersistenceManager.shared.fetchSamples(typeIdentifier: typeIdentifier, from: start, to: end)
        if raw.isEmpty { return TimeframeData(points: [], labels: [], average: 0) }
        // Count whole calendar days inclusive of the (possibly partial) last day,
        // so a reading from earlier today is not dropped
        let startDay = cal.startOfDay(for: start)
        let dayCount = max(1, (cal.dateComponents([.day], from: startDay, to: end).day ?? 0) + 1)
        // Use date format (d MMM) for body comp — readings are sporadic so day-of-week is meaningless
        let fmt = DateFormatter(); fmt.dateFormat = "d MMM"
        var dailyVals: [(Date, Double)] = []
        for i in 0..<dayCount {
            let dayStart = cal.date(byAdding: .day, value: i, to: cal.startOfDay(for: start))!
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
            let daySamples = raw.filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
            if !daySamples.isEmpty {
                let sum = daySamples.reduce(0.0) { $0 + $1.value }
                let val = type == .bodyFatPercentage ? (sum / Double(daySamples.count)) * 100.0 : sum / Double(daySamples.count)
                dailyVals.append((dayStart, val))
            }
        }
        if dailyVals.isEmpty { return TimeframeData(points: [], labels: [], average: 0) }
        let points = dailyVals.map { $0.1 }
        // Thin x-axis labels for dense charts: cap at ~6 visible labels to prevent overlap
        let step = max(1, Int((Double(points.count) / 5.0).rounded(.up)))
        let labels = dailyVals.enumerated().map { (i, pair) -> String in
            (i % step == 0 || i == dailyVals.count - 1) ? fmt.string(from: pair.0) : ""
        }
        let avg = points.reduce(0, +) / Double(points.count)
        return TimeframeData(points: points, labels: labels, average: avg)
    }

    private func directSamplesMonthly(from start: Date, to end: Date) -> TimeframeData {
        let raw = LocalPersistenceManager.shared.fetchSamples(typeIdentifier: typeIdentifier, from: start, to: end)
        if raw.isEmpty { return TimeframeData(points: [], labels: [], average: 0) }
        let fmt = DateFormatter(); fmt.dateFormat = "MMM ''yy"
        // Key by year*100+month to avoid collisions across years (e.g. Jan 2024 vs Jan 2025)
        var sums: [Int: Double] = [:]; var counts: [Int: Double] = [:]; var dates: [Int: Date] = [:]
        for s in raw {
            let comps = cal.dateComponents([.year, .month], from: s.startDate)
            let key = (comps.year ?? 0) * 100 + (comps.month ?? 0)
            let v = type == .bodyFatPercentage ? s.value * 100.0 : s.value
            sums[key, default: 0] += v; counts[key, default: 0] += 1; dates[key] = s.startDate
        }
        let sorted = dates.keys.sorted { dates[$0]! < dates[$1]! }
        let points = sorted.map { (sums[$0] ?? 0) / (counts[$0] ?? 1) }
        let labels = sorted.map { fmt.string(from: dates[$0]!) }
        let avg = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
        return TimeframeData(points: points, labels: labels, average: avg)
    }

    private func getVitalsData() -> TimeframeData {
        let calendar = Calendar.current

        switch selectedTimeframe {
        case .day:
            let dayStart = cal.startOfDay(for: selectedDay)
            let dayEnd = isViewingToday ? Date() : cal.date(byAdding: .day, value: 1, to: dayStart)!
            let labels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]
            let segmentHours = [0, 3, 6, 9, 12, 15, 18, 21]
            let daySamples = LocalPersistenceManager.shared.fetchSamples(typeIdentifier: typeIdentifier, from: dayStart, to: dayEnd)
            if daySamples.isEmpty { return TimeframeData(points: [], labels: labels, average: 0) }
            var segSums = [Double](repeating: 0, count: 8); var segCounts = [Int](repeating: 0, count: 8)
            for s in daySamples {
                let hour = calendar.component(.hour, from: s.startDate)
                var idx = 7
                for (i, h) in segmentHours.enumerated() { if hour <= h { idx = i; break } }
                let val = type == .bodyFatPercentage ? s.value * 100.0 : s.value
                segSums[idx] += val; segCounts[idx] += 1
            }
            let points = (0..<8).map { i -> Double in segCounts[i] > 0 ? segSums[i] / Double(segCounts[i]) : 0.0 }
            let nonZero = points.filter { $0 > 0 }
            let avg = nonZero.isEmpty ? 0.0 : nonZero.reduce(0, +) / Double(nonZero.count)
            return TimeframeData(points: points, labels: labels, average: avg)
            
        case .threeDays, .week:
            if isBodyComp {
                // True 7-day window — may be empty when no readings fall in the week
                let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: selectedDay))!
                let end = isViewingToday ? Date() : cal.date(byAdding: .day, value: 1, to: selectedDay)!
                return directSamples(from: start, to: end)
            }
            let last7 = filteredMetrics.filter { m in
                type == .respiratoryRate ? m.respiratoryRate > 0 : (type == .oxygenSaturation ? m.oxygenSaturation > 0 : m.bodyTemperature > 0)
            }
            let points = last7.map { m -> Double in
                type == .respiratoryRate ? m.respiratoryRate : (type == .oxygenSaturation ? m.oxygenSaturation : m.bodyTemperature)
            }
            let formatter = DateFormatter(); formatter.dateFormat = "E"
            let labels = last7.map { formatter.string(from: $0.date) }
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)

        case .month:
            if isBodyComp {
                // True 30-day window with daily readings
                let start = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: selectedDay))!
                let end = isViewingToday ? Date() : cal.date(byAdding: .day, value: 1, to: selectedDay)!
                return directSamples(from: start, to: end)
            }
            let last30 = filteredMetrics.filter { m in
                type == .respiratoryRate ? m.respiratoryRate > 0 : (type == .oxygenSaturation ? m.oxygenSaturation > 0 : m.bodyTemperature > 0)
            }
            let pointsM = last30.map { m -> Double in
                type == .respiratoryRate ? m.respiratoryRate : (type == .oxygenSaturation ? m.oxygenSaturation : m.bodyTemperature)
            }
            let labelsM = ["W1", "W2", "W3", "W4"]
            let averageM = pointsM.isEmpty ? 0.0 : pointsM.reduce(0, +) / Double(pointsM.count)
            return TimeframeData(points: pointsM, labels: labelsM, average: averageM)

        case .sixMonths:
            if isBodyComp {
                // True 6-month window (-179 days, app-wide convention), aggregated by month
                let start = cal.date(byAdding: .day, value: -179, to: cal.startOfDay(for: selectedDay))!
                let end = isViewingToday ? Date() : cal.date(byAdding: .day, value: 1, to: selectedDay)!
                return directSamplesMonthly(from: start, to: end)
            }
            let validMetrics6M = filteredMetrics.filter { m in
                type == .respiratoryRate ? m.respiratoryRate > 0 : (type == .oxygenSaturation ? m.oxygenSaturation > 0 : m.bodyTemperature > 0)
            }
            var monthlySums6M: [Int: Double] = [:]
            var monthlyCounts6M: [Int: Double] = [:]
            var monthlyDates6M: [Int: Date] = [:]
            for m in validMetrics6M {
                let month = calendar.component(.month, from: m.date)
                let val = type == .respiratoryRate ? m.respiratoryRate : (type == .oxygenSaturation ? m.oxygenSaturation : m.bodyTemperature)
                monthlySums6M[month, default: 0.0] += val
                monthlyCounts6M[month, default: 0.0] += 1.0
                monthlyDates6M[month] = m.date
            }
            let sortedMonths6M = monthlyDates6M.keys.sorted { monthlyDates6M[$0]! < monthlyDates6M[$1]! }
            let points6M = sortedMonths6M.map { (monthlySums6M[$0] ?? 0.0) / (monthlyCounts6M[$0] ?? 1.0) }
            let formatter6M = DateFormatter(); formatter6M.dateFormat = "MMM"
            let labels6M = sortedMonths6M.map { formatter6M.string(from: monthlyDates6M[$0]!) }
            let average6M = points6M.isEmpty ? 0.0 : points6M.reduce(0, +) / Double(points6M.count)
            return TimeframeData(points: points6M, labels: labels6M, average: average6M)

        case .year:
            if isBodyComp {
                // True 1-year window (-364 days, app-wide convention), aggregated by month
                let start = cal.date(byAdding: .day, value: -364, to: cal.startOfDay(for: selectedDay))!
                let end = isViewingToday ? Date() : cal.date(byAdding: .day, value: 1, to: selectedDay)!
                return directSamplesMonthly(from: start, to: end)
            }
            let validMetrics = filteredMetrics.filter { m in
                type == .respiratoryRate ? m.respiratoryRate > 0 : (type == .oxygenSaturation ? m.oxygenSaturation > 0 : m.bodyTemperature > 0)
            }
            var monthlySums: [Int: Double] = [:]
            var monthlyCounts: [Int: Double] = [:]
            var monthlyDates: [Int: Date] = [:]
            for m in validMetrics {
                let month = calendar.component(.month, from: m.date)
                let val = type == .respiratoryRate ? m.respiratoryRate : (type == .oxygenSaturation ? m.oxygenSaturation : m.bodyTemperature)
                monthlySums[month, default: 0.0] += val
                monthlyCounts[month, default: 0.0] += 1.0
                monthlyDates[month] = m.date
            }
            let sortedMonths = monthlyDates.keys.sorted { monthlyDates[$0]! < monthlyDates[$1]! }
            let pointsY = sortedMonths.map { (monthlySums[$0] ?? 0.0) / (monthlyCounts[$0] ?? 1.0) }
            let formatterY = DateFormatter(); formatterY.dateFormat = "MMM"
            let labelsY = sortedMonths.map { formatterY.string(from: monthlyDates[$0]!) }
            let averageY = pointsY.isEmpty ? 0.0 : pointsY.reduce(0, +) / Double(pointsY.count)
            return TimeframeData(points: pointsY, labels: labelsY, average: averageY)
        }
    }
    
    private var vitalExplainText: String {
        switch type {
        case .respiratoryRate:
            return "Respiratory rate is the number of breaths you take per minute, typically measured overnight while asleep. An elevated respiratory rate can be an early indicator of physiological strain, acute infection, or cardiorespiratory stress before you feel symptoms."
        case .oxygenSaturation:
            return "Oxygen Saturation (SpO2) represents the percentage of oxygen-carrying hemoglobin in your blood. Healthy baseline levels typically hover between 95% and 100%. Sustained low levels could indicate respiratory conditions or sleep apnea."
        case .bodyTemperature:
            return "Skin wrist temperature tracks surface temperature changes relative to your personal baseline during sleep. Fluctuations can reflect sleeping environment changes, hormonal shifts, or immune system reactions to illness or recovery."
        case .bodyFatPercentage:
            return "Body fat percentage is the proportion of fat mass relative to total body weight. It is a key indicator of metabolic health and fitness. Apple Health reads this from compatible smart scales or third-party apps that perform body composition analysis."
        case .vo2Max:
            return "VO2 Max is the maximum rate at which your body can consume oxygen during intense exercise. It is one of the strongest predictors of cardiovascular fitness and longevity. Apple Watch estimates VO2 Max from heart rate and speed during outdoor walks and runs."
        case .bmi:
            return "Body Mass Index (BMI) is a weight-to-height ratio used as a population-level screening tool. While useful at a glance, it does not account for muscle mass, bone density, or fat distribution, so it should be interpreted alongside body fat percentage and lean mass."
        case .weight:
            return "Body weight is your total mass including muscle, fat, bone, organs, and water. Tracking weight over time reveals trends in body composition change. Apple Health reads weight from compatible smart scales or manual entries."
        }
    }

    private var scienceFormulaText: String {
        switch type {
        case .respiratoryRate:   return "MEASUREMENT: Plethysmography\nHealthy Range: 12 - 20 rpm"
        case .oxygenSaturation:  return "MEASUREMENT: Pulse Oximetry\nHealthy Range: 95% - 100%"
        case .bodyTemperature:   return "MEASUREMENT: Wrist Thermal Sensors\nHealthy Range: ± 0.5 °C deviation"
        case .bodyFatPercentage: return "MEASUREMENT: Smart Scale / DEXA\nHealthy Range: 10% - 20% (athletic), 20% - 32% (average)"
        case .vo2Max:            return "MEASUREMENT: Heart Rate + GPS\nHealthy Range: > 42 ml/kg·min (Good), > 52 (Excellent)"
        case .bmi:               return "MEASUREMENT: Weight ÷ Height²\nHealthy Range: 18.5 - 24.9"
        case .weight:            return "MEASUREMENT: Smart Scale / Manual Entry\nUnit: Kilograms"
        }
    }
    
    var body: some View {
        ZStack {
            AppBackground(accent: Theme.Colors.sleepLight)

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
                    
                    Text(type.rawValue)
                        .font(Theme.Typography.roundedFont(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Spacer to balance back button
                    Spacer().frame(width: 44)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        CustomSegmentedPicker(selection: $selectedTimeframe, options: [.day, .week, .month, .sixMonths, .year])
                            .padding(.top, 10)

                        PeriodNavigationView(timeframe: .day, baseDate: $selectedDay, accentColor: Theme.Colors.sleepLight)

                        MetricInsightCard(metric: .vitals, hkManager: hkManager)
                            .padding(.horizontal)

                        // Hero Value Card
                        HStack(spacing: 18) {
                            ZStack {
                                Circle()
                                    .stroke(statusColor.opacity(0.08), lineWidth: 6)
                                    .frame(width: 64, height: 64)
                                
                                Circle()
                                    .trim(from: 0.0, to: 0.8)
                                    .stroke(
                                        LinearGradient(colors: [statusColor, statusColor.opacity(0.6)], startPoint: .top, endPoint: .bottom),
                                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                    )
                                    .frame(width: 64, height: 64)
                                    .rotationEffect(.degrees(-90))
                                    .shadow(color: statusColor.opacity(0.3), radius: 4)
                                
                                Image(systemName: type == .respiratoryRate ? "wind" : (type == .oxygenSaturation ? "lungs.fill" : "thermometer.medium"))
                                    .foregroundColor(.white)
                                    .font(Theme.Typography.titleSM)
                            }
                            .frame(width: 64, height: 64)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayValue)
                                    .font(Theme.Typography.roundedFont(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(displayStatus.uppercased())
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                    .foregroundColor(statusColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(statusColor.opacity(0.12))
                                    .cornerRadius(6)
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
                        .glassCard()
                        .padding(.horizontal)
                        
                        // Graph Card
                        let graphData = getVitalsData()
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Biomarker History")
                                    .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text({
                                    switch selectedTimeframe {
                                    case .day: return isBodyComp ? "Today's Readings" : "Overnight Cycles"
                                    case .sixMonths, .year: return "Monthly Trend"
                                    default: return "Daily Trend"
                                    }
                                }())
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            CustomLineGraph(
                                points: graphData.points,
                                labels: graphData.labels,
                                lineColor: statusColor,
                                gradientColors: [statusColor.opacity(0.2), .clear]
                            )
                            .frame(height: 150)
                            .padding(.vertical, 8)
                            
                            HStack {
                                Text(String(format: "Average: %@", {
                                    switch type {
                                    case .respiratoryRate:   return String(format: "%.1f rpm", graphData.average)
                                    case .oxygenSaturation:  return String(format: "%.1f%%", graphData.average)
                                    case .bodyTemperature:   return String(format: "%.1f °C", graphData.average)
                                    case .bodyFatPercentage: return String(format: "%.1f%%", graphData.average)
                                    case .vo2Max:            return String(format: "%.1f ml/kg·min", graphData.average)
                                    case .bmi:               return String(format: "%.1f", graphData.average)
                                    case .weight:      return String(format: "%.1f kg", graphData.average)
                                    }
                                }()))
                                .font(Theme.Typography.roundedFont(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                
                                Spacer()
                            }
                        }
                        .glassCard()
                        .padding(.horizontal)
                        
                        // Biomarker Information Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("WHY IT MATTERS")
                                .font(Theme.Typography.cardTitle)
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text(vitalExplainText)
                                .font(Theme.Typography.roundedFont(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.75))
                                .lineSpacing(4)
                        }
                        .glassCard()
                        .padding(.horizontal)
                        
                        // Scientific Breakdown Card
                        VStack(alignment: .leading, spacing: 14) {
                            Button(action: {
                                withAnimation(.spring()) {
                                    showScientificDetails.toggle()
                                }
                            }) {
                                HStack {
                                    Text("Scientific References")
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
                                    
                                    Text("Overnight biometric metrics represent autonomic nervous system function and cardiorespiratory health. Normal variations fluctuate slightly based on hydration, body position, sleep quality, and elevation.")
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
