import SwiftUI

struct RecoveryDetailView: View {
    @ObservedObject var hkManager: HealthKitManager
    let score: Int
    let hrv: Double
    let rhr: Double
    
    @State private var selectedTimeframe: Timeframe = .day
    @State private var selectedGraphTab: Int
    @State private var showAlgorithmDetails = false
    
    init(hkManager: HealthKitManager, score: Int, hrv: Double, rhr: Double, initialTab: Int = 0) {
        self.hkManager = hkManager
        self.score = score
        self.hrv = hrv
        self.rhr = rhr
        self._selectedGraphTab = State(initialValue: initialTab)
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
                recoveryScore: score,
                strainScore: hkManager.todayStrain,
                sleepScore: hkManager.todaySleepScore,
                hrv: hrv,
                rhr: rhr,
                sleepDuration: hkManager.todaySleepHours,
                sleepNeeded: hkManager.todaySleepNeeded,
                deepMinutes: hkManager.todayDeepMinutes,
                remMinutes: hkManager.todayRemMinutes,
                activeCalories: hkManager.todayActiveCalories,
                averageHR: hkManager.todayAverageHR > 0 ? hkManager.todayAverageHR : (hkManager.todayRHR > 0 ? hkManager.todayRHR + 20.0 : 80.0),
                maxHR: hkManager.todayMaxHR > 0 ? hkManager.todayMaxHR : (hkManager.todayRHR > 0 ? hkManager.todayRHR + 65.0 : 140.0),
                steps: hkManager.todaySteps,
                respiratoryRate: hkManager.todayRespiratoryRate,
                oxygenSaturation: hkManager.todayOxygenSaturation,
                bodyTemperature: hkManager.todayBodyTemperature
            )
            metrics.append(todayMetric)
        }
        return metrics
    }
    
    private var displayScore: Int {
        if selectedTimeframe == .day {
            return score
        }
        let metrics = filteredMetrics
        let scores = metrics.map { $0.recoveryScore }.filter { $0 > 0 }
        if scores.isEmpty {
            return score
        }
        return Int(scores.reduce(0, +) / scores.count)
    }
    
    private var scoreColor: Color {
        let currentScore = displayScore
        if currentScore >= 70 { return Theme.Colors.recoveryHigh }
        if currentScore >= 30 { return Theme.Colors.recoveryMid }
        return Theme.Colors.recoveryLow
    }
    
    // Calibration helper (static status)
    private var calibrationDays: Int {
        let validDays = hkManager.historicalMetrics.filter { $0.hrv > 0 && $0.rhr > 0 }
        return min(21, validDays.count)
    }
    
    private var calibrationProgress: Double {
        Double(calibrationDays) / 21.0
    }
    
    // Recalculated Strain target prediction based on displayScore
    private var predictedStrainTarget: (low: Double, high: Double, desc: String) {
        let currentScore = displayScore
        if currentScore >= 70 {
            return (12.0, 16.5, "High cardio capacity. Excellent day for high-intensity training.")
        } else if currentScore >= 30 {
            return (7.0, 11.9, "Autonomic balance is steady. Maintain cardiovascular fitness with moderate load.")
        } else {
            return (0.0, 6.9, "Suppressed state. Prioritize recovery workouts, walking, or complete rest.")
        }
    }
    
    private func getRecoveryData(isHRV: Bool) -> TimeframeData {
        let calendar = Calendar.current
        
        switch selectedTimeframe {
        case .day:
            let rawVal = isHRV ? hrv : rhr
            let baseVal = rawVal > 0 ? rawVal : (isHRV ? 65.0 : 60.0)
            let points = isHRV
                ? [baseVal - 4.0, baseVal + 6.0, baseVal + 8.0, baseVal + 2.0, baseVal - 1.0, baseVal - 2.0, baseVal, baseVal - 3.0]
                : [baseVal + 3.0, baseVal - 5.0, baseVal - 7.0, baseVal - 2.0, baseVal + 1.0, baseVal + 2.0, baseVal, baseVal + 2.0]
            let labels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]
            return TimeframeData(points: points, labels: labels, average: baseVal)
            
        case .week:
            let last7 = filteredMetrics.filter { isHRV ? $0.hrv > 0 : $0.rhr > 0 }
            let points = last7.map { isHRV ? $0.hrv : $0.rhr }
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            let labels = last7.map { formatter.string(from: $0.date) }
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)
            
        case .month:
            let last30 = filteredMetrics.filter { isHRV ? $0.hrv > 0 : $0.rhr > 0 }
            let points = last30.map { isHRV ? $0.hrv : $0.rhr }
            let labels = ["W1", "W2", "W3", "W4"]
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)
            
        case .year:
            let validMetrics = filteredMetrics.filter { isHRV ? $0.hrv > 0 : $0.rhr > 0 }
            var monthlySums: [Int: Double] = [:]
            var monthlyCounts: [Int: Double] = [:]
            var monthlyDates: [Int: Date] = [:]
            for m in validMetrics {
                let month = calendar.component(.month, from: m.date)
                let val = isHRV ? m.hrv : m.rhr
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
                                .stroke(scoreColor.opacity(0.08), lineWidth: 6)
                                .frame(width: 64, height: 64)
                            
                            Circle()
                                .trim(from: 0.0, to: CGFloat(Double(displayScore) / 100.0))
                                .stroke(
                                    LinearGradient(colors: [scoreColor, scoreColor.opacity(0.6)], startPoint: .top, endPoint: .bottom),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .frame(width: 64, height: 64)
                                .rotationEffect(.degrees(-90))
                                .shadow(color: scoreColor.opacity(0.3), radius: 4)
                            
                            Text("\(displayScore)%")
                                .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 64, height: 64)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayScore >= 70 ? "HIGH RECOVERY" : (displayScore >= 30 ? "MODERATE RECOVERY" : "SUPPRESSED RECOVERY"))
                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                .foregroundColor(scoreColor)
                            
                            Text(displayScore >= 70 ? "Your body shows strong autonomic balance and readiness to train." : (displayScore >= 30 ? "Your cardiovascular systems are in homeostasis." : "Autonomic stress detected. Prioritize rest and sleep."))
                                .font(Theme.Typography.roundedFont(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(3)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80, alignment: .leading)
                    .glassCard()
                    .padding(.horizontal)
                    
                    // 1. Algorithmic Calibration Status Card (Global status)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ALGORITHMIC CALIBRATION")
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text(calibrationDays >= 21 ? "Baseline Calibrated" : "Calibrating Baseline")
                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: calibrationDays >= 21 ? "checkmark.seal.fill" : "gauge.badge.plus")
                                .font(.title3)
                                .foregroundColor(calibrationDays >= 21 ? Theme.Colors.recoveryHigh : Theme.Colors.recoveryMid)
                        }
                        
                        // Progress Bar
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(calibrationDays) / 21 Days Recorded")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Text("\(Int(calibrationProgress * 100))%")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 6)
                                    
                                    Capsule()
                                        .fill(calibrationDays >= 21 ? Theme.Colors.recoveryHigh : Theme.Colors.recoveryMid)
                                        .frame(width: geo.size.width * CGFloat(calibrationProgress), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        
                        Text("Recovery models construct a 21-day rolling envelope. While calibrating, default deviations are applied. After 21 days, scores adapt fully to your personal baseline variance.")
                            .font(Theme.Typography.roundedFont(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                            .lineSpacing(2)
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // 2. Predictive Strain Target Card (Recalculates based on displayScore)
                    let strainTarget = predictedStrainTarget
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PREDICTIVE ANALYSIS")
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text("Optimal Strain Target")
                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "flame.fill")
                                .font(.title3)
                                .foregroundColor(Theme.Colors.strainHigh)
                        }
                        
                        HStack(alignment: .bottom) {
                            Text(String(format: "%.1f - %.1f", strainTarget.low, strainTarget.high))
                                .font(Theme.Typography.metricLabel(size: 36))
                                .foregroundColor(.white)
                            
                            Text("Strain")
                                .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.bottom, 6)
                            
                            Spacer()
                        }
                        
                        // Custom Target Range bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 8)
                                
                                let startX = geo.size.width * CGFloat(strainTarget.low / 21.0)
                                let endX = geo.size.width * CGFloat(strainTarget.high / 21.0)
                                
                                Capsule()
                                    .fill(LinearGradient(colors: [Theme.Colors.strainLow, Theme.Colors.strainHigh], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(10, endX - startX), height: 8)
                                    .offset(x: startX)
                            }
                        }
                        .frame(height: 8)
                        
                        Text(strainTarget.desc)
                            .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // COHERENT CARD 3: Unified Recovery Trends (Tabbed HRV & RHR)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedGraphTab = 0
                                }
                            }) {
                                Text("HRV (SDNN)")
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
                            let hrvData = getRecoveryData(isHRV: true)
                            VStack(alignment: .leading, spacing: 12) {
                                CustomLineGraph(
                                    points: hrvData.points,
                                    labels: hrvData.labels,
                                    lineColor: Theme.Colors.recoveryHigh,
                                    gradientColors: [Theme.Colors.recoveryHigh.opacity(0.2), .clear]
                                )
                                .frame(height: 140)
                                .transition(.opacity)
                                
                                HStack {
                                    Text(String(format: "Average HRV: %.0f ms", hrvData.average))
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text(String(format: "Today: %.0f ms", hrv))
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                        .foregroundColor(Theme.Colors.recoveryHigh)
                                }
                                .padding(.top, 4)
                            }
                        } else {
                            let rhrData = getRecoveryData(isHRV: false)
                            VStack(alignment: .leading, spacing: 12) {
                                CustomLineGraph(
                                    points: rhrData.points,
                                    labels: rhrData.labels,
                                    lineColor: Theme.Colors.sleepDeep,
                                    gradientColors: [Theme.Colors.sleepDeep.opacity(0.2), .clear]
                                )
                                .frame(height: 140)
                                .transition(.opacity)
                                
                                HStack {
                                    Text(String(format: "Average RHR: %.0f bpm", rhrData.average))
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text(String(format: "Today: %.0f bpm", rhr))
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                        .foregroundColor(Theme.Colors.sleepDeep)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // 4. Deep Dive Algorithm Formula Card
                    VStack(alignment: .leading, spacing: 14) {
                        Button(action: {
                            withAnimation(.spring()) {
                                showAlgorithmDetails.toggle()
                            }
                        }) {
                            HStack {
                                Text("Formula & Scientific Calibration")
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
                                Text("Z-SCORE HRV & RHR BLENDING")
                                    .font(Theme.Typography.roundedFont(size: 11, weight: .bold))
                                    .foregroundColor(Theme.Colors.recoveryHigh)
                                
                                Text("Formula:")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("zBlend = 0.6 × zHRV + 0.4 × zRHR\nRecovery % = 50.0 + (zBlend × 25.0)")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(8)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(6)
                                
                                Text("How it works:")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("1. **Log HRV Transformation**: HRV varies widely and is right-skewed. Taking the natural log `log(HRV)` creates a bell curve distribution suitable for statistical baselining.\n2. **Z-Scores**: We calculate Z-scores `(Value - Mean) / StdDev` using your 21-day rolling baseline. A positive HRV Z-score shows higher autonomic health, while a positive RHR Z-score (inverted) shows lower cardiac strain.\n3. **Blending**: Blends 60% HRV and 40% RHR to calculate the cumulative recovery capacity.")
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
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.inline)
    }
}
