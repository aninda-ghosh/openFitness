import SwiftUI

struct SleepDetailView: View {
    @ObservedObject var hkManager: HealthKitManager
    let score: Int
    let duration: Double
    let needed: Double
    let deep: Double
    let rem: Double
    
    @State private var selectedTimeframe: Timeframe = .day
    @State private var selectedGraphTab: Int
    @State private var showAlgorithmDetails = false
    
    init(hkManager: HealthKitManager, score: Int, duration: Double, needed: Double, deep: Double, rem: Double, initialTab: Int = 0) {
        self.hkManager = hkManager
        self.score = score
        self.duration = duration
        self.needed = needed
        self.deep = deep
        self.rem = rem
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
                recoveryScore: hkManager.todayRecovery,
                strainScore: hkManager.todayStrain,
                sleepScore: score,
                hrv: hkManager.todayHRV,
                rhr: hkManager.todayRHR,
                sleepDuration: duration,
                sleepNeeded: needed,
                deepMinutes: deep,
                remMinutes: rem,
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
        let scores = metrics.map { $0.sleepScore }.filter { $0 > 0 }
        if scores.isEmpty {
            return score
        }
        return Int(scores.reduce(0, +) / scores.count)
    }
    
    private var displayDuration: Double {
        if selectedTimeframe == .day {
            return duration
        }
        let metrics = filteredMetrics
        let durations = metrics.map { $0.sleepDuration }.filter { $0 > 0.0 }
        if durations.isEmpty {
            return duration
        }
        return durations.reduce(0.0, +) / Double(durations.count)
    }
    
    // Predictive Sleep Need tonight based on today's Strain & current Sleep Debt (Today specific)
    private var predictedSleepNeeded: (totalHours: Double, strainAdditionMins: Int, debtAdditionMins: Int) {
        let baseNeeded = needed > 0 ? needed : 8.0
        
        // Strain-based extension: 3.5 minutes per Strain point today
        let strainExtensionMins = Int(hkManager.todayStrain * 3.5)
        
        // Sleep Debt contribution: last 7 days debt (including today)
        var last7 = Array(historicalMetrics.suffix(7))
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        if !last7.contains(where: { calendar.isDate($0.date, inSameDayAs: todayStart) }) {
            let todayMetric = DailyMetrics(
                date: todayStart,
                recoveryScore: hkManager.todayRecovery,
                strainScore: hkManager.todayStrain,
                sleepScore: score,
                hrv: hkManager.todayHRV,
                rhr: hkManager.todayRHR,
                sleepDuration: duration,
                sleepNeeded: needed,
                deepMinutes: deep,
                remMinutes: rem,
                activeCalories: hkManager.todayActiveCalories,
                averageHR: hkManager.todayAverageHR > 0 ? hkManager.todayAverageHR : (hkManager.todayRHR > 0 ? hkManager.todayRHR + 20.0 : 80.0),
                maxHR: hkManager.todayMaxHR > 0 ? hkManager.todayMaxHR : (hkManager.todayRHR > 0 ? hkManager.todayRHR + 65.0 : 140.0),
                steps: hkManager.todaySteps,
                respiratoryRate: hkManager.todayRespiratoryRate,
                oxygenSaturation: hkManager.todayOxygenSaturation,
                bodyTemperature: hkManager.todayBodyTemperature
            )
            last7.append(todayMetric)
            if last7.count > 7 { last7.removeFirst() }
        }
        
        let validLast7 = last7.filter { $0.sleepDuration > 0 }
        let totalDebt = validLast7.reduce(0.0) { sum, m in
            sum + max(0.0, m.sleepNeeded - m.sleepDuration)
        }
        let dailyDebtContribution = validLast7.isEmpty ? 0.0 : totalDebt / Double(validLast7.count)
        
        // Cap debt extension at 2 hours (120 minutes)
        let debtExtensionMins = Int(min(120.0, dailyDebtContribution * 60.0))
        
        let totalExtensionHours = Double(strainExtensionMins + debtExtensionMins) / 60.0
        let totalHours = baseNeeded + totalExtensionHours
        
        return (totalHours, strainExtensionMins, debtExtensionMins)
    }
    
    private func getSleepData(isScore: Bool) -> TimeframeData {
        let calendar = Calendar.current
        
        switch selectedTimeframe {
        case .day:
            let base = isScore ? Double(score) : duration
            let rawBase = base > 0 ? base : (isScore ? 80.0 : 8.0)
            let points = isScore
                ? [rawBase * 0.1, rawBase * 0.5, rawBase * 0.85, rawBase, rawBase, rawBase, rawBase, rawBase]
                : [rawBase * 0.125, rawBase * 0.5, rawBase * 0.875, rawBase, rawBase, rawBase, rawBase, rawBase]
            let labels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]
            return TimeframeData(points: points, labels: labels, average: rawBase)
            
        case .week:
            let last7 = filteredMetrics.filter { isScore ? $0.sleepScore > 0 : $0.sleepDuration > 0 }
            let points = last7.map { isScore ? Double($0.sleepScore) : $0.sleepDuration }
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            let labels = last7.map { formatter.string(from: $0.date) }
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)
            
        case .month:
            let last30 = filteredMetrics.filter { isScore ? $0.sleepScore > 0 : $0.sleepDuration > 0 }
            let points = last30.map { isScore ? Double($0.sleepScore) : $0.sleepDuration }
            let labels = ["W1", "W2", "W3", "W4"]
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)
            
        case .year:
            let validMetrics = filteredMetrics.filter { isScore ? $0.sleepScore > 0 : $0.sleepDuration > 0 }
            var monthlySums: [Int: Double] = [:]
            var monthlyCounts: [Int: Double] = [:]
            var monthlyDates: [Int: Date] = [:]
            for m in validMetrics {
                let month = calendar.component(.month, from: m.date)
                let val = isScore ? Double(m.sleepScore) : m.sleepDuration
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
                                .stroke(Theme.Colors.sleepLight.opacity(0.08), lineWidth: 6)
                                .frame(width: 64, height: 64)
                            
                            Circle()
                                .trim(from: 0.0, to: CGFloat(Double(displayScore) / 100.0))
                                .stroke(
                                    LinearGradient(colors: [Theme.Colors.sleepLight, Theme.Colors.sleepLight.opacity(0.6)], startPoint: .top, endPoint: .bottom),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .frame(width: 64, height: 64)
                                .rotationEffect(.degrees(-90))
                                .shadow(color: Theme.Colors.sleepLight.opacity(0.3), radius: 4)
                            
                            Text("\(displayScore)%")
                                .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 64, height: 64)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SLEEP QUALITY SCORE")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                .foregroundColor(Theme.Colors.sleepLight)
                            
                            Text(String(format: "Typical duration needed: %.1f hrs", needed))
                                .font(Theme.Typography.roundedFont(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(3)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80, alignment: .leading)
                    .glassCard()
                    .padding(.horizontal)
                    
                    // 1. Predictive Sleep Requirements Card (Today planning)
                    let sleepNeed = predictedSleepNeeded
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TONIGHT'S OUTLOOK")
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text("Sleep Need Recommendation")
                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "moon.stars.fill")
                                .font(.title3)
                                .foregroundColor(Theme.Colors.sleepLight)
                        }
                        
                        HStack(alignment: .bottom, spacing: 2) {
                            let hours = Int(sleepNeed.totalHours)
                            let mins = Int((sleepNeed.totalHours - Double(hours)) * 60.0)
                            Text("\(hours)h \(mins)m")
                                .font(Theme.Typography.metricLabel(size: 36))
                                .foregroundColor(.white)
                            
                            Text("Needed Tonight")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.bottom, 6)
                        }
                        
                        // Extension breakdown list
                        VStack(spacing: 8) {
                            HStack {
                                Text("Baseline sleep requirement:")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                                Text(String(format: "%.1f hrs", needed))
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            if sleepNeed.strainAdditionMins > 0 {
                                  HStack {
                                      Text("Cardio Strain extra repair time:")
                                          .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                          .foregroundColor(.white.opacity(0.5))
                                      Spacer()
                                      Text("+\(sleepNeed.strainAdditionMins) mins")
                                          .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                          .foregroundColor(Theme.Colors.strainHigh)
                                  }
                            }
                            
                            if sleepNeed.debtAdditionMins > 0 {
                                  HStack {
                                      Text("Accumulated sleep debt recovery:")
                                          .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                          .foregroundColor(.white.opacity(0.5))
                                      Spacer()
                                      Text("+\(sleepNeed.debtAdditionMins) mins")
                                          .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                          .foregroundColor(Color.orange)
                                  }
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(8)
                        
                        Text("Predicted sleep duration adapts to daily physical strain levels and outstanding sleep debt to facilitate optimal cognitive and physical recovery.")
                            .font(Theme.Typography.roundedFont(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // COHERENT CARD 2: Unified Sleep Quality & Duration Trends (Tabbed)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedGraphTab = 0
                                }
                            }) {
                                Text("Quality Score")
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
                                Text("Duration (Hrs)")
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
                            let trendData = getSleepData(isScore: true)
                            VStack(alignment: .leading, spacing: 12) {
                                CustomLineGraph(
                                    points: trendData.points,
                                    labels: trendData.labels,
                                    lineColor: Theme.Colors.sleepLight,
                                    gradientColors: [Theme.Colors.sleepLight.opacity(0.2), .clear]
                                )
                                .frame(height: 140)
                                .transition(.opacity)
                                
                                HStack {
                                    Text(String(format: "Average Score: %.0f%%", trendData.average))
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text("Today's Score: \(score)%")
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                        .foregroundColor(Theme.Colors.sleepLight)
                                }
                                .padding(.top, 4)
                            }
                        } else {
                            let trendData = getSleepData(isScore: false)
                            VStack(alignment: .leading, spacing: 12) {
                                CustomLineGraph(
                                    points: trendData.points,
                                    labels: trendData.labels,
                                    lineColor: Theme.Colors.sleepREM,
                                    gradientColors: [Theme.Colors.sleepREM.opacity(0.2), .clear]
                                )
                                .frame(height: 140)
                                .transition(.opacity)
                                
                                HStack {
                                    Text(String(format: "Average Sleep: %.1f hrs", trendData.average))
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text(String(format: "Today: %.1f hrs", duration))
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                        .foregroundColor(Theme.Colors.sleepREM)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // Tonight's Hypnogram (Only visible in Week/Today context)
                    if selectedTimeframe == .day || selectedTimeframe == .week {
                        SleepHypnogramChart(samples: hkManager.todaySleepStages)
                            .padding(.horizontal)
                    }
                    
                    // COHERENT CARD 3: Recalculating Sleep Architecture (ALWAYS SHOWN)
                    VStack(alignment: .leading, spacing: 16) {
                        Text(selectedTimeframe == .day ? "Tonight's Sleep Architecture" : (selectedTimeframe == .week ? "Weekly Average Architecture" : (selectedTimeframe == .month ? "Monthly Average Architecture" : "Annual Average Architecture")))
                            .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        let filteredMetrics: [DailyMetrics] = {
                            switch selectedTimeframe {
                            case .day:
                                return []
                            case .week:
                                return Array(historicalMetrics.suffix(7)).filter { $0.sleepDuration > 0 }
                            case .month:
                                return Array(historicalMetrics.suffix(30)).filter { $0.sleepDuration > 0 }
                            case .year:
                                return historicalMetrics.filter { $0.sleepDuration > 0 }
                            }
                        }()
                        
                        let avgDuration = filteredMetrics.isEmpty ? duration : (filteredMetrics.map { $0.sleepDuration }.reduce(0.0, +) / Double(filteredMetrics.count))
                        let avgDeep = filteredMetrics.isEmpty ? deep : (filteredMetrics.map { $0.deepMinutes }.reduce(0.0, +) / Double(filteredMetrics.count))
                        let avgRem = filteredMetrics.isEmpty ? rem : (filteredMetrics.map { $0.remMinutes }.reduce(0.0, +) / Double(filteredMetrics.count))
                        
                        let awakeMins: Double = {
                            if selectedTimeframe == .day {
                                let awakeSamples = hkManager.todaySleepStages.filter { $0.stage == 0 }
                                let totalAwakeSecs = awakeSamples.reduce(0.0) { sum, sample in
                                    sum + sample.endDate.timeIntervalSince(sample.startDate)
                                }
                                return totalAwakeSecs > 0 ? totalAwakeSecs / 60.0 : (duration > 0 ? 24.0 : 0.0)
                            } else {
                                return avgDuration > 0 ? 24.0 : 0.0
                            }
                        }()
                        
                        let deepMins = avgDeep
                        let remMins = avgRem
                        let lightMins = max(0.0, (avgDuration * 60.0) - deepMins - remMins)
                        
                        let totalSessionMinutes = awakeMins + lightMins + remMins + deepMins
                        
                        let awakeRatio = totalSessionMinutes > 0 ? awakeMins / totalSessionMinutes : 0.05
                        let lightRatio = totalSessionMinutes > 0 ? lightMins / totalSessionMinutes : 0.60
                        let remRatio = totalSessionMinutes > 0 ? remMins / totalSessionMinutes : 0.20
                        let deepRatio = totalSessionMinutes > 0 ? deepMins / totalSessionMinutes : 0.15
                        
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                Color.orange.opacity(0.8)
                                    .frame(width: geo.size.width * CGFloat(awakeRatio))
                                Theme.Colors.sleepLight
                                    .frame(width: geo.size.width * CGFloat(lightRatio))
                                Theme.Colors.sleepREM
                                    .frame(width: geo.size.width * CGFloat(remRatio))
                                Theme.Colors.sleepDeep
                                    .frame(width: geo.size.width * CGFloat(deepRatio))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .frame(height: 24)
                        
                        let deepPct = totalSessionMinutes > 0 ? Int(round((deepMins / totalSessionMinutes) * 100)) : 0
                        let remPct = totalSessionMinutes > 0 ? Int(round((remMins / totalSessionMinutes) * 100)) : 0
                        let lightPct = totalSessionMinutes > 0 ? Int(round((lightMins / totalSessionMinutes) * 100)) : 0
                        let awakePct = totalSessionMinutes > 0 ? max(0, 100 - deepPct - remPct - lightPct) : 0
                        
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            SleepStageCard(stageName: "Awake", minutes: awakeMins, percentage: awakePct, color: Color.orange, icon: "sun.max.fill")
                            SleepStageCard(stageName: "Light Sleep", minutes: lightMins, percentage: lightPct, color: Theme.Colors.sleepLight, icon: "moon.fill")
                            SleepStageCard(stageName: "REM Sleep", minutes: remMins, percentage: remPct, color: Theme.Colors.sleepREM, icon: "sparkles")
                            SleepStageCard(stageName: "Deep Sleep", minutes: deepMins, percentage: deepPct, color: Theme.Colors.sleepDeep, icon: "moon.stars.fill")
                        }
                        .padding(.top, 8)
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // Sleep Debt Status
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Sleep Debt Status")
                                .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "hourglass.badge.plus")
                                .foregroundColor(.orange)
                        }
                        
                        let debt = max(0.0, needed - displayDuration)
                        HStack(alignment: .bottom) {
                            Text(String(format: "%.1f hrs", debt))
                                .font(Theme.Typography.metricLabel(size: 32))
                                .foregroundColor(debt > 1.0 ? .orange : .green)
                            Spacer()
                            Text("Needed: \(String(format: "%.1f hrs", needed))")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Text(debt > 1.0 ? "Your sleep debt is accumulating. Aim to go to bed earlier tonight." : "Your sleep debt is healthy. Continue your regular schedule.")
                            .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // Nocturnal Heart Rate Dipping & Sleep Scoring formula card
                    VStack(alignment: .leading, spacing: 14) {
                        Button(action: {
                            withAnimation(.spring()) {
                                showAlgorithmDetails.toggle()
                            }
                        }) {
                            HStack {
                                Text("Sleep Scoring & HR Dipping")
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
                                Text("100-POINT QUALITY ALGORITHM")
                                    .font(Theme.Typography.roundedFont(size: 11, weight: .bold))
                                    .foregroundColor(Theme.Colors.sleepLight)
                                
                                Text("Point Composition:")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("- **Duration (40 pts)**: Ratio of sleep duration vs baseline needed.\n- **Deep Sleep (30 pts)**: Ratio of actual deep sleep minutes vs 90-minute target.\n- **REM Sleep (20 pts)**: Ratio of actual REM minutes vs 90-minute target.\n- **Heart Rate Dipping (10 pts)**: Presence of nocturnal heart rate dipping.")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineSpacing(4)
                                
                                Text("Nocturnal Heart Rate Dipping:")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Formula:")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Dip % = ((DayAvgHR - NightAvgHR) / DayAvgHR) * 100")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(8)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(6)
                                
                                Text("A healthy cardiovascular system shows an autonomic shift during sleep. Heart rate should dip by **10% to 20%** compared to your daytime average. Dipping less than 10% (non-dipper) correlates with increased sympathetic tone and incomplete physical recovery.")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineSpacing(4)
                            }
                        }
                    }
                    .glassCard()
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Sleep Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }
}
