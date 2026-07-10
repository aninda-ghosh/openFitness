import SwiftUI
import HealthKit

struct EnergyDetailView: View {
    @ObservedObject var hkManager: HealthKitManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTimeframe: Timeframe = .day
    @State private var showInfoSheet = false
    @State private var baseDate: Date = Calendar.current.startOfDay(for: Date())
    
    private var displayEnergy: Int {
        if selectedTimeframe == .day {
            return hkManager.energyBank
        }
        let data = getHistoricalEnergyData()
        if data.points.isEmpty {
            return hkManager.energyBank
        }
        return Int(round(data.average))
    }
    
    var body: some View {
        ZStack {
            AppBackground(accent: Theme.Colors.sleepDeep)

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
                    
                    Text("Energy Bank")
                        .font(Theme.Typography.roundedFont(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        showInfoSheet.toggle()
                    }) {
                        Image(systemName: "info.circle")
                            .font(Theme.Typography.titleSM)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.04))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Hero Battery Section
                        VStack(spacing: 12) {
                            HStack(alignment: .center, spacing: 16) {
                                HStack(spacing: 8) {
                                    Image(systemName: "battery.100.bolt")
                                        .font(Theme.Typography.titleLG)
                                        .foregroundColor(Theme.Colors.sleepDeep)
                                    
                                    Text("\(displayEnergy)%")
                                        .font(Theme.Typography.metricLabel(size: 36))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(selectedTimeframe == .day ? "Current Battery" : "Average Battery")
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                    
                                    if selectedTimeframe == .day && !hkManager.energyBankLastChargedString.isEmpty {
                                        Text(hkManager.energyBankLastChargedString)
                                            .font(Theme.Typography.roundedFont(size: 11, weight: .medium))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 8)
                                    
                                    Capsule()
                                        .fill(Theme.Colors.sleepDeep)
                                        .frame(width: geo.size.width * CGFloat(displayEnergy) / 100.0, height: 8)
                                }
                            }
                            .frame(height: 8)
                            .padding(.vertical, 4)
                            
                            // Three-pill row: Had / Charged / Drained
                            HStack(spacing: 6) {
                                // Had Pill
                                HStack(spacing: 4) {
                                    Image(systemName: "battery.50")
                                        .foregroundColor(.white.opacity(0.6))
                                        .font(Theme.Typography.caption)
                                    Text(selectedTimeframe == .day ? "Had: \(hkManager.energyBankStart)%" : "Had")
                                        .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                                )
                                
                                // Total Charged Pill
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundColor(Theme.Colors.sleepDeep)
                                        .font(Theme.Typography.caption)
                                    Text(selectedTimeframe == .day ? "Charged: +\(hkManager.energyBankCharged)%" : "Charged")
                                        .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                                )
                                
                                // Total Drained Pill
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(Color(red: 0.96, green: 0.45, blue: 0.41))
                                        .font(Theme.Typography.caption)
                                    Text(selectedTimeframe == .day ? "Drained: -\(hkManager.energyBankDrained)%" : "Drained")
                                        .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                                )
                            }
                        }
                        .padding()
                        .glassCard()
                        .padding(.horizontal)
                        
                        // Custom Timeframe Picker
                        CustomSegmentedPicker(selection: $selectedTimeframe, options: [.day, .week, .month, .sixMonths, .year])
                            .padding(.horizontal)
                            .onChange(of: selectedTimeframe) { _, _ in
                                baseDate = Calendar.current.startOfDay(for: Date())
                            }

                        if selectedTimeframe != .day {
                            PeriodNavigationView(
                                timeframe: selectedTimeframe,
                                baseDate: $baseDate,
                                accentColor: Theme.Colors.sleepDeep
                            )
                        }
                        
                        // Chart Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(selectedTimeframe == .day ? "TODAY'S ENERGY CURVE" : "ENERGY BANK TREND")
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                if selectedTimeframe == .day {
                                    Text("Hourly")
                                        .font(Theme.Typography.roundedFont(size: 11, weight: .bold))
                                        .foregroundColor(Theme.Colors.sleepDeep)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Theme.Colors.sleepDeep.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            
                            let graphData = getHistoricalEnergyData()
                            if graphData.points.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("No chart data available")
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.3))
                                        .padding(.vertical, 40)
                                    Spacer()
                                }
                            } else {
                                CustomLineGraph(
                                    points: graphData.points,
                                    labels: graphData.labels,
                                    lineColor: Theme.Colors.sleepDeep,
                                    gradientColors: [Theme.Colors.sleepDeep.opacity(0.24), Theme.Colors.sleepDeep.opacity(0.0)]
                                )
                                .frame(height: 180)
                            }
                        }
                        .padding()
                        .glassCard()
                        .padding(.horizontal)
                        
                        // Dynamic Description card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ENERGY BANK INSIGHT")
                                .font(Theme.Typography.cardTitle)
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(Theme.Colors.sleepDeep)
                                    .font(Theme.Typography.bodyLG)
                                    .padding(.top, 2)
                                
                                Text(hkManager.energyBankDescription.isEmpty ? 
                                     "Your energy level is dynamically calculated based on your sleep, recovery, stress, and active calories. Keep your stress low to recharge." : 
                                     hkManager.energyBankDescription)
                                    .font(Theme.Typography.roundedFont(size: 13, weight: .regular))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineSpacing(4)
                            }
                        }
                        .padding()
                        .glassCard()
                        .padding(.horizontal)
                        
                        // Energy Charging / Draining Factors
                        VStack(alignment: .leading, spacing: 16) {
                            Text("CONTRIBUTIONS TODAY")
                                .font(Theme.Typography.cardTitle)
                                .foregroundColor(.white.opacity(0.6))
                            
                            // Sleep (Charge)
                            HStack(spacing: 12) {
                                Image(systemName: "bed.double.fill")
                                    .font(Theme.Typography.titleSM)
                                    .foregroundColor(Theme.Colors.sleepDeep)
                                    .frame(width: 38, height: 38)
                                    .background(Theme.Colors.sleepDeep.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sleep Ingestion")
                                        .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("\(String(format: "%.1f", hkManager.todaySleepHours)) hrs slept (Score: \(hkManager.todaySleepScore)%)")
                                        .font(Theme.Typography.roundedFont(size: 11, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                Spacer()
                                Text("+\(hkManager.energyBankSleepCharge)%")
                                    .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                                    .foregroundColor(Theme.Colors.sleepDeep)
                            }
                            
                            Divider().background(Color.white.opacity(0.06))
                            
                            // Stress (Drain)
                            HStack(spacing: 12) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(Theme.Typography.titleSM)
                                    .foregroundColor(.orange)
                                    .frame(width: 38, height: 38)
                                    .background(Color.orange.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Autonomic Stress")
                                        .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Average Stress: \(hkManager.todayStressAverage)%")
                                        .font(Theme.Typography.roundedFont(size: 11, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                Spacer()
                                let stressDr = max(0, hkManager.energyBankDrained - Int(hkManager.todayActiveCalories * 0.05))
                                Text("-\(stressDr)%")
                                    .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            
                            Divider().background(Color.white.opacity(0.06))
                            
                            // Active Calories (Drain)
                            HStack(spacing: 12) {
                                Image(systemName: "flame.fill")
                                    .font(Theme.Typography.titleSM)
                                    .foregroundColor(Color(red: 0.96, green: 0.45, blue: 0.41))
                                    .frame(width: 38, height: 38)
                                    .background(Color(red: 0.96, green: 0.45, blue: 0.41).opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Active Calorie Burn")
                                        .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("\(Int(hkManager.todayActiveCalories)) kcal burned")
                                        .font(Theme.Typography.roundedFont(size: 11, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                Spacer()
                                let calDr = Int(hkManager.todayActiveCalories * 0.05)
                                Text("-\(calDr)%")
                                    .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                                    .foregroundColor(Color(red: 0.96, green: 0.45, blue: 0.41))
                        }
                    }
                    .padding()
                        .glassCard()
                        .padding(.horizontal)

                        MetricInsightCard(metric: .energy, hkManager: hkManager)
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                    }
                    .containerRelativeFrame(.horizontal)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showInfoSheet) {
            EnergyBankInfoSheet()
        }
    }
    
    // Dynamic hourly energy graph simulator
    private func getHourlyEnergyData() -> TimeframeData {
        let calendar = Calendar.current
        let now = Date()
        
        var wakeUpTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? now
        if !hkManager.isSleepDataStale,
           let latestSleepStage = hkManager.todaySleepStages.sorted(by: { $0.endDate < $1.endDate }).last {
            wakeUpTime = latestSleepStage.endDate
        }
        
        let adjustedWakeUpTime: Date
        if now < wakeUpTime {
            adjustedWakeUpTime = calendar.date(byAdding: .day, value: -1, to: wakeUpTime) ?? wakeUpTime
        } else {
            adjustedWakeUpTime = wakeUpTime
        }
        
        let wakeHour = calendar.component(.hour, from: adjustedWakeUpTime)
        
        // Fetch raw samples to run simulation hour-by-hour starting 2 hours before wake
        let queryStartDate = calendar.date(byAdding: .hour, value: -2, to: adjustedWakeUpTime) ?? adjustedWakeUpTime
        
        let hrvSamples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue,
            from: calendar.startOfDay(for: queryStartDate),
            to: now
        )
        
        var hourlyStress: [Date: Int] = [:]
        let hrvByHour = Dictionary(grouping: hrvSamples) { sample -> Date in
            let hour = calendar.component(.hour, from: sample.startDate)
            let startOfSampleDay = calendar.startOfDay(for: sample.startDate)
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startOfSampleDay) ?? startOfSampleDay
        }
        for (hourDate, samples) in hrvByHour {
            let avgVal = samples.reduce(0.0) { $0 + $1.value } / Double(samples.count)
            let stress = max(5, min(95, Int(100.0 - (avgVal * 0.95))))
            hourlyStress[hourDate] = stress
        }
        
        let calSamples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
            from: calendar.startOfDay(for: queryStartDate),
            to: now
        )
        
        var hourlyCalories: [Date: Double] = [:]
        let calsByHour = Dictionary(grouping: calSamples) { sample -> Date in
            let hour = calendar.component(.hour, from: sample.startDate)
            let startOfSampleDay = calendar.startOfDay(for: sample.startDate)
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startOfSampleDay) ?? startOfSampleDay
        }
        for (hourDate, samples) in calsByHour {
            let totalCals = samples.reduce(0.0) { $0 + $1.value }
            hourlyCalories[hourDate] = totalCals
        }
        
        let simulationStartIsYesterday = now < wakeUpTime
        let recoveryToUse = simulationStartIsYesterday ? hkManager.yesterdayRecovery : hkManager.todayRecovery
        let sleepScoreToUse = simulationStartIsYesterday ? hkManager.yesterdaySleepScore : hkManager.todaySleepScore
        
        let recoveryFactor = Double(recoveryToUse) / 100.0
        let yesterdayEnding = 15.0 + (recoveryFactor * 15.0)
        let rawSleepCharge = Double(sleepScoreToUse) * 0.95
        let sleepCharge = min(rawSleepCharge, 98.0 - yesterdayEnding)
        let wakeEnergy = yesterdayEnding + sleepCharge
        
        var energyAtHour = [Double](repeating: yesterdayEnding, count: 24)
        var currentEnergy = wakeEnergy
        
        // Hours before wake
        for h in 0..<wakeHour {
            let progress = wakeHour > 0 ? Double(h) / Double(wakeHour) : 1.0
            energyAtHour[h] = yesterdayEnding + progress * sleepCharge
        }
        
        // Hours after wake
        if wakeHour >= 0 && wakeHour < 24 {
            energyAtHour[wakeHour] = wakeEnergy
        }
        
        for h in (wakeHour + 1)...23 {
            guard h < 24 else { break }
            let hourDate = calendar.date(bySettingHour: h, minute: 0, second: 0, of: adjustedWakeUpTime) ?? adjustedWakeUpTime
            let stress = hourlyStress[hourDate] ?? 30
            let calories = hourlyCalories[hourDate] ?? 0.0
            
            let stressDrain = max(0.0, (Double(stress) - 30.0) / 70.0 * 4.5)
            let calDrain = calories * 0.06
            let baselineDrain = 1.2
            let hourlyDrain = stressDrain + calDrain + baselineDrain
            
            var hourlyCharge = 0.0
            if stress < 25 && calories < 15.0 {
                hourlyCharge = max(0.0, (25.0 - Double(stress)) / 25.0 * 2.5)
            }
            
            currentEnergy = max(5.0, min(100.0, currentEnergy + hourlyCharge - hourlyDrain))
            energyAtHour[h] = currentEnergy
        }
        
        // Sample at 8 segments
        let segmentHours = [0, 3, 6, 9, 12, 15, 18, 21]
        let labels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]
        var points: [Double] = []
        for hour in segmentHours {
            points.append(energyAtHour[hour])
        }
        
        let average = points.reduce(0.0, +) / Double(points.count)
        return TimeframeData(points: points, labels: labels, average: average)
    }
    
    // Historical picker data selector
    private func getHistoricalEnergyData() -> TimeframeData {
        let calendar = Calendar.current
        guard selectedTimeframe != .day else { return getHourlyEnergyData() }

        let metrics: [DailyMetrics]
        switch selectedTimeframe {
        case .day:
            return getHourlyEnergyData()
        case .threeDays:
            let start = calendar.date(byAdding: .day, value: -2, to: baseDate)!
            metrics = hkManager.historicalMetrics.filter { $0.date >= start && $0.date <= baseDate }
        case .week:
            let start = calendar.date(byAdding: .day, value: -6, to: baseDate)!
            metrics = hkManager.historicalMetrics.filter { $0.date >= start && $0.date <= baseDate }
        case .month:
            let start = calendar.date(byAdding: .day, value: -29, to: baseDate)!
            metrics = hkManager.historicalMetrics.filter { $0.date >= start && $0.date <= baseDate }
        case .sixMonths:
            let start = calendar.date(byAdding: .day, value: -179, to: baseDate)!
            metrics = hkManager.historicalMetrics.filter { $0.date >= start && $0.date <= baseDate }
        case .year:
            let start = calendar.date(byAdding: .day, value: -364, to: baseDate)!
            metrics = hkManager.historicalMetrics.filter { $0.date >= start && $0.date <= baseDate }
        }

        if metrics.isEmpty {
            return TimeframeData(points: [], labels: [], average: 0)
        }

        let formatter = DateFormatter()
        switch selectedTimeframe {
        case .week:
            let points = metrics.map { m -> Double in
                let base = Double(m.recoveryScore + m.sleepScore) / 2.0
                return max(5.0, min(98.0, base - m.strainScore * 2.2))
            }
            formatter.dateFormat = "E"
            let labels = metrics.map { formatter.string(from: $0.date) }
            let average = points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)

        case .month:
            let points = metrics.map { m -> Double in
                let base = Double(m.recoveryScore + m.sleepScore) / 2.0
                return max(5.0, min(98.0, base - m.strainScore * 2.2))
            }
            let average = points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: ["W1","W2","W3","W4"], average: average)

        default: // .year
            formatter.dateFormat = "MMM"
            var monthlySums: [Int: Double] = [:]
            var monthlyCounts: [Int: Double] = [:]
            var monthlyDates: [Int: Date] = [:]
            for m in metrics {
                let month = calendar.component(.month, from: m.date)
                let base = Double(m.recoveryScore + m.sleepScore) / 2.0
                let val = max(5.0, min(98.0, base - m.strainScore * 2.2))
                monthlySums[month, default: 0] += val
                monthlyCounts[month, default: 0] += 1
                monthlyDates[month] = m.date
            }
            let sorted = monthlyDates.keys.sorted { monthlyDates[$0]! < monthlyDates[$1]! }
            let pts = sorted.map { (monthlySums[$0] ?? 0) / (monthlyCounts[$0] ?? 1) }
            let lbls = sorted.map { formatter.string(from: monthlyDates[$0]!) }
            let avg = pts.isEmpty ? 0 : pts.reduce(0, +) / Double(pts.count)
            return TimeframeData(points: pts, labels: lbls, average: avg)
        }
    }
}

// Information Sheet for Energy Bank
struct EnergyBankInfoSheet: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            AppBackground(accent: Theme.Colors.sleepDeep)

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("About Energy Bank")
                        .font(Theme.Typography.roundedFont(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(Theme.Typography.roundedFont(size: 24, weight: .bold))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(.bottom, 10)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("The Energy Bank is a dynamic calculation of your body's energy reservoir throughout the day. It functions similar to Garmin's Body Battery or Bevel's Energy Bank.")
                            .font(Theme.Typography.roundedFont(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. OVERNIGHT RECHARGE")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                .foregroundColor(Theme.Colors.sleepDeep)
                            Text("Your battery charges overnight during sleep. The charge amount (+%) is derived directly from your Sleep Score and baseline physical readiness.")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("2. STRESS DEPLETION")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                .foregroundColor(.orange)
                            Text("High stress levels (HRV suppression) cause your battery to drain faster. Stress levels above 30% trigger continuous depleting factors.")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("3. CALORIC DEPLETION")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                .foregroundColor(Color(red: 0.96, green: 0.45, blue: 0.41))
                            Text("Physical exercise and active energy expenditure burn battery energy, proportional to workout duration and cardiovascular intensity.")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("4. RESTING CHARGE")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                .foregroundColor(Theme.Colors.recoveryHigh)
                            Text("Taking breaks in a low-stress state (stress under 25, active energy under 15 kcal/hr) allows your battery to charge slightly during the day.")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("5. NO-SLEEP FALLBACK")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                .foregroundColor(.gray)
                            Text("If no sleep is logged for the day, the Energy Bank defaults to starting at yesterday's recovery baseline (typically 15% - 30%) at 7:00 AM.")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
            .padding()
        }
    }
}
