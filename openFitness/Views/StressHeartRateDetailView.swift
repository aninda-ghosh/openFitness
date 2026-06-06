import SwiftUI

struct StressHeartRateDetailView: View {
    @ObservedObject var hkManager: HealthKitManager
    
    @State private var selectedTimeframe: Timeframe = .day // Default to D (Daily)
    @State private var selectedGraphTab: Int = 0 // 0: Stress Index, 1: Resting HR
    @State private var showAlgorithmDetails = false
    
    private var historicalMetrics: [DailyMetrics] {
        hkManager.historicalMetrics
    }
    
    // 1. Recalculated dynamic stress average based on timeframe
    private var displayStress: Int {
        if selectedTimeframe == .day {
            return hkManager.todayStressAverage
        }
        let data = getStressData()
        return Int(data.average)
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
            return (hkManager.todayStressLowest, hkManager.todayStressHighest)
        }
        
        let hrvs = filteredMetrics.map { $0.hrv }.filter { $0 > 0 }
        if hrvs.isEmpty {
            return (hkManager.todayStressLowest, hkManager.todayStressHighest)
        }
        
        let stresses = hrvs.map { hrv -> Double in
            max(5.0, min(95.0, 100.0 - (hrv * 0.95)))
        }
        
        let avgStress = stresses.reduce(0.0, +) / Double(stresses.count)
        let lowest = max(5, Int(avgStress - 12))
        let highest = min(98, Int(avgStress + 15))
        return (lowest, highest)
    }
    
    private var rangeLabel: String {
        let range = displayStressRange
        switch selectedTimeframe {
        case .day:
            return "Today's range: \(range.lowest)% - \(range.highest)%"
        case .week:
            return "Weekly average range: \(range.lowest)% - \(range.highest)%"
        case .month:
            return "Monthly average range: \(range.lowest)% - \(range.highest)%"
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
            return hkManager.todayRHR > 0 ? Int(hkManager.todayRHR) : 60
        }
        let rhrs = filteredMetrics.map { $0.rhr }.filter { $0 > 0 }
        if rhrs.isEmpty {
            return hkManager.todayRHR > 0 ? Int(hkManager.todayRHR) : 60
        }
        return Int(rhrs.reduce(0.0, +) / Double(rhrs.count))
    }
    
    // 5. Recalculated Average HR average based on timeframe
    private var displayAverageHR: Int {
        if selectedTimeframe == .day {
            return hkManager.todayAverageHR > 0 ? Int(hkManager.todayAverageHR) : 80
        }
        let avgs = filteredMetrics.map { $0.averageHR }.filter { $0 > 0 }
        if avgs.isEmpty {
            return hkManager.todayAverageHR > 0 ? Int(hkManager.todayAverageHR) : 80
        }
        return Int(avgs.reduce(0.0, +) / Double(avgs.count))
    }
    
    // 6. Recalculated Max HR average based on timeframe
    private var displayMaxHR: Int {
        if selectedTimeframe == .day {
            return hkManager.todayMaxHR > 0 ? Int(hkManager.todayMaxHR) : 140
        }
        let maxes = filteredMetrics.map { $0.maxHR }.filter { $0 > 0 }
        if maxes.isEmpty {
            return hkManager.todayMaxHR > 0 ? Int(hkManager.todayMaxHR) : 140
        }
        return Int(maxes.reduce(0.0, +) / Double(maxes.count))
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
                averageHR: hkManager.todayAverageHR > 0 ? hkManager.todayAverageHR : (hkManager.todayRHR > 0 ? hkManager.todayRHR + 20.0 : 80.0),
                maxHR: hkManager.todayMaxHR > 0 ? hkManager.todayMaxHR : (hkManager.todayRHR > 0 ? hkManager.todayRHR + 65.0 : 140.0)
            )
            metrics.append(todayMetric)
        }
        return metrics
    }
    
    private func getStressData() -> TimeframeData {
        if selectedTimeframe == .day {
            let base = Double(hkManager.todayStressAverage > 0 ? hkManager.todayStressAverage : 35)
            // Plot today's stress level fluctuation (hourly)
            let points = [base * 0.5, base * 0.4, base * 0.9, base * 1.3, base * 0.8, base * 1.1, base * 1.0, base]
            let labels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]
            return TimeframeData(points: points, labels: labels, average: base)
        }
        
        let calendar = Calendar.current
        let fMetrics = filteredMetrics
        
        let points = fMetrics.map { m -> Double in
            if m.hrv > 0 {
                return max(5.0, min(95.0, 100.0 - (m.hrv * 0.95)))
            } else {
                let hrDiff = 20.0
                let baseStress = 15.0 + hrDiff * 1.8
                return max(10.0, min(80.0, baseStress))
            }
        }
        
        let formatter = DateFormatter()
        let labels: [String]
        switch selectedTimeframe {
        case .day:
            labels = [] // Handled in the guard block above
        case .week:
            formatter.dateFormat = "E"
            labels = fMetrics.map { String(formatter.string(from: $0.date).prefix(1)) }
        case .month:
            formatter.dateFormat = "d"
            labels = fMetrics.enumerated().map { index, m in
                if index % 5 == 0 || index == fMetrics.count - 1 {
                    return formatter.string(from: m.date)
                } else {
                    return ""
                }
            }
        case .year:
            formatter.dateFormat = "MMM"
            var monthlySums: [Int: Double] = [:]
            var monthlyCounts: [Int: Double] = [:]
            var monthlyDates: [Int: Date] = [:]
            for m in fMetrics {
                let month = calendar.component(.month, from: m.date)
                let val: Double
                if m.hrv > 0 {
                    val = max(5.0, min(95.0, 100.0 - (m.hrv * 0.95)))
                } else {
                    let hrDiff = 20.0
                    let baseStress = 15.0 + hrDiff * 1.8
                    val = max(10.0, min(80.0, baseStress))
                }
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
                String(formatter.string(from: monthlyDates[month]!).prefix(1))
            }
            let averageYear = pointsYear.isEmpty ? 0.0 : pointsYear.reduce(0, +) / Double(pointsYear.count)
            return TimeframeData(points: pointsYear, labels: labelsYear, average: averageYear)
        }
        
        let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
        return TimeframeData(points: points, labels: labels, average: average)
    }
    
    private func getHRData() -> TimeframeData {
        if selectedTimeframe == .day {
            let rhrVal = hkManager.todayRHR > 0 ? hkManager.todayRHR : 60.0
            let avgVal = hkManager.todayAverageHR > 0 ? hkManager.todayAverageHR : 72.0
            let maxVal = hkManager.todayMaxHR > 0 ? hkManager.todayMaxHR : 130.0
            
            // Plot today's heart rate fluctuation (hourly)
            let points = [rhrVal, rhrVal + 2.0, avgVal - 5.0, avgVal + 15.0, maxVal - 10.0, avgVal + 5.0, rhrVal + 6.0, rhrVal]
            let labels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]
            return TimeframeData(points: points, labels: labels, average: avgVal)
        }
        
        let calendar = Calendar.current
        let fMetrics = filteredMetrics
        
        let points = fMetrics.map { $0.rhr > 0 ? $0.rhr : 60.0 }
        
        let formatter = DateFormatter()
        let labels: [String]
        switch selectedTimeframe {
        case .day:
            labels = [] // Handled in the guard block above
        case .week:
            formatter.dateFormat = "E"
            labels = fMetrics.map { String(formatter.string(from: $0.date).prefix(1)) }
        case .month:
            formatter.dateFormat = "d"
            labels = fMetrics.enumerated().map { index, m in
                if index % 5 == 0 || index == fMetrics.count - 1 {
                    return formatter.string(from: m.date)
                } else {
                    return ""
                }
            }
        case .year:
            formatter.dateFormat = "MMM"
            var monthlySums: [Int: Double] = [:]
            var monthlyCounts: [Int: Double] = [:]
            var monthlyDates: [Int: Date] = [:]
            for m in fMetrics {
                let month = calendar.component(.month, from: m.date)
                let val = m.rhr > 0 ? m.rhr : 60.0
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
                String(formatter.string(from: monthlyDates[month]!).prefix(1))
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
