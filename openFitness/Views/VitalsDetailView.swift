import SwiftUI

enum VitalType: String {
    case respiratoryRate = "Respiratory Rate"
    case oxygenSaturation = "Oxygen Saturation"
    case bodyTemperature = "Skin Temperature"
}

struct VitalsDetailView: View {
    @ObservedObject var hkManager: HealthKitManager
    let type: VitalType
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTimeframe: Timeframe = .day
    @State private var showScientificDetails = false
    
    private var displayValue: String {
        let val = todayValue
        if val <= 0 { return "--" }
        switch type {
        case .respiratoryRate:
            return String(format: "%.1f rpm", val)
        case .oxygenSaturation:
            return String(format: "%.1f%%", val)
        case .bodyTemperature:
            return String(format: "%.1f °C", val)
        }
    }
    
    private var todayValue: Double {
        switch type {
        case .respiratoryRate:
            return hkManager.todayRespiratoryRate
        case .oxygenSaturation:
            return hkManager.todayOxygenSaturation
        case .bodyTemperature:
            return hkManager.todayBodyTemperature
        }
    }
    
    private var displayStatus: String {
        let val = todayValue
        if val <= 0 { return "No Data" }
        switch type {
        case .respiratoryRate:
            return val > 18.0 ? "Higher" : (val < 12.0 ? "Lower" : "Normal")
        case .oxygenSaturation:
            return val < 95.0 ? "Lower" : "Optimal"
        case .bodyTemperature:
            return val > 37.0 ? "Higher" : (val < 35.5 ? "Lower" : "Normal")
        }
    }
    
    private var statusColor: Color {
        let status = displayStatus
        if status == "Normal" || status == "Optimal" {
            return Theme.Colors.recoveryHigh
        } else if status == "Lower" && type == .oxygenSaturation {
            return Theme.Colors.recoveryLow
        } else if status == "Lower" || status == "Higher" {
            return Color.orange
        }
        return .gray
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
    
    private func getVitalsData() -> TimeframeData {
        let calendar = Calendar.current
        
        switch selectedTimeframe {
        case .day:
            let baseVal = todayValue > 0 ? todayValue : (type == .respiratoryRate ? 14.5 : (type == .oxygenSaturation ? 98.5 : 36.4))
            // Diurnal variations (8 segments of 3 hours)
            let points = type == .respiratoryRate
                ? [baseVal - 0.8, baseVal - 0.4, baseVal + 0.2, baseVal + 0.6, baseVal + 0.1, baseVal - 0.2, baseVal + 0.3, baseVal]
                : (type == .oxygenSaturation
                    ? [baseVal - 0.5, baseVal - 0.2, baseVal + 0.1, baseVal + 0.3, baseVal + 0.1, baseVal - 0.1, baseVal + 0.2, baseVal]
                    : [baseVal - 0.2, baseVal - 0.1, baseVal + 0.1, baseVal + 0.3, baseVal + 0.2, baseVal - 0.1, baseVal + 0.1, baseVal])
            let labels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]
            return TimeframeData(points: points, labels: labels, average: baseVal)
            
        case .week:
            let last7 = filteredMetrics.filter { m in
                switch type {
                case .respiratoryRate: return m.respiratoryRate > 0
                case .oxygenSaturation: return m.oxygenSaturation > 0
                case .bodyTemperature: return m.bodyTemperature > 0
                }
            }
            let points = last7.map { m -> Double in
                switch type {
                case .respiratoryRate: return m.respiratoryRate
                case .oxygenSaturation: return m.oxygenSaturation
                case .bodyTemperature: return m.bodyTemperature
                }
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            let labels = last7.map { formatter.string(from: $0.date) }
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)
            
        case .month:
            let last30 = filteredMetrics.filter { m in
                switch type {
                case .respiratoryRate: return m.respiratoryRate > 0
                case .oxygenSaturation: return m.oxygenSaturation > 0
                case .bodyTemperature: return m.bodyTemperature > 0
                }
            }
            let points = last30.map { m -> Double in
                switch type {
                case .respiratoryRate: return m.respiratoryRate
                case .oxygenSaturation: return m.oxygenSaturation
                case .bodyTemperature: return m.bodyTemperature
                }
            }
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
            let validMetrics = filteredMetrics.filter { m in
                switch type {
                case .respiratoryRate: return m.respiratoryRate > 0
                case .oxygenSaturation: return m.oxygenSaturation > 0
                case .bodyTemperature: return m.bodyTemperature > 0
                }
            }
            var monthlySums: [Int: Double] = [:]
            var monthlyCounts: [Int: Double] = [:]
            var monthlyDates: [Int: Date] = [:]
            for m in validMetrics {
                let month = calendar.component(.month, from: m.date)
                let val: Double = {
                    switch type {
                    case .respiratoryRate: return m.respiratoryRate
                    case .oxygenSaturation: return m.oxygenSaturation
                    case .bodyTemperature: return m.bodyTemperature
                    }
                }()
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
    
    private var vitalExplainText: String {
        switch type {
        case .respiratoryRate:
            return "Respiratory rate is the number of breaths you take per minute, typically measured overnight while asleep. It is highly stable and changes by less than 1-2 breaths per minute under normal circumstances. An elevated respiratory rate can be an early indicator of physiological strain, acute infection, or cardiorespiratory stress before you feel symptoms."
        case .oxygenSaturation:
            return "Oxygen Saturation (SpO2) represents the percentage of oxygen-carrying hemoglobin in your blood. Healthy baseline levels typically hover between 95% and 100%. Occasional small drops during deep sleep are common, but sustained low levels could indicate altitude sickness, respiratory conditions, or systemic sleep apnea issues."
        case .bodyTemperature:
            return "Skin wrist temperature variations track your skin surface temperature changes relative to your personal baseline during sleep. Fluctuations can be influenced by changes in your sleeping environment, sleeping patterns, hormonal shifts, or immune system reactions to illness, stress, or recovery demands."
        }
    }
    
    private var scienceFormulaText: String {
        switch type {
        case .respiratoryRate:
            return "MEASUREMENT: Plethysmography\nHealthy Range: 12 - 20 rpm"
        case .oxygenSaturation:
            return "MEASUREMENT: Pulse Oximetry\nHealthy Range: 95% - 100%"
        case .bodyTemperature:
            return "MEASUREMENT: Wrist Thermal Sensors\nHealthy Range: ± 0.5 °C deviation"
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
                        CustomSegmentedPicker(selection: $selectedTimeframe)
                            .padding(.top, 10)
                        
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
                                    .font(.system(size: 18))
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
                                Text(selectedTimeframe == .day ? "Overnight Cycles" : "Daily Trend")
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
                                    case .respiratoryRate: return String(format: "%.1f rpm", graphData.average)
                                    case .oxygenSaturation: return String(format: "%.1f%%", graphData.average)
                                    case .bodyTemperature: return String(format: "%.1f °C", graphData.average)
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
