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

    // Period navigation: end date of the currently viewed range
    @State private var baseDate: Date = Calendar.current.startOfDay(for: Date())

    // Day-level navigation (used when selectedTimeframe == .day)
    @State private var selectedDayDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var historicalDaySleepStages: [SleepStageSample] = []

    init(hkManager: HealthKitManager, score: Int, duration: Double, needed: Double, deep: Double, rem: Double, initialTab: Int = 0) {
        self.hkManager = hkManager
        self.score = score
        self.duration = duration
        self.needed = needed
        self.deep = deep
        self.rem = rem
        self._selectedGraphTab = State(initialValue: initialTab)
    }

    private var calendar: Calendar { Calendar.current }
    private var isViewingToday: Bool { calendar.isDateInToday(selectedDayDate) }

    // MARK: - Day-view resolved values (today or historical)
    private var displayedScore: Int {
        if selectedTimeframe == .day && !isViewingToday {
            return historicalMetrics.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDayDate) })?.sleepScore ?? 0
        }
        return score
    }
    private var displayedDuration: Double {
        if selectedTimeframe == .day && !isViewingToday {
            return historicalMetrics.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDayDate) })?.sleepDuration ?? 0
        }
        return duration
    }
    private var displayedDeep: Double {
        if selectedTimeframe == .day && !isViewingToday {
            return historicalMetrics.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDayDate) })?.deepMinutes ?? 0
        }
        return deep
    }
    private var displayedRem: Double {
        if selectedTimeframe == .day && !isViewingToday {
            return historicalMetrics.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDayDate) })?.remMinutes ?? 0
        }
        return rem
    }
    private var displayedSleepStages: [SleepStageSample] {
        if selectedTimeframe == .day && !isViewingToday {
            return historicalDaySleepStages
        }
        return hkManager.todaySleepStages
    }
    private var isStaleLabelActive: Bool {
        isViewingToday && hkManager.isSleepDataStale
    }

    // MARK: - Historical data
    private var historicalMetrics: [DailyMetrics] { hkManager.historicalMetrics }

    private var filteredMetrics: [DailyMetrics] {
        switch selectedTimeframe {
        case .day:
            return []
        case .threeDays:
            let start = calendar.date(byAdding: .day, value: -2, to: baseDate)!
            return historicalMetrics.filter { $0.date >= start && $0.date <= baseDate }
        case .week:
            let start = calendar.date(byAdding: .day, value: -6, to: baseDate)!
            return historicalMetrics.filter { $0.date >= start && $0.date <= baseDate }
        case .month:
            let start = calendar.date(byAdding: .day, value: -29, to: baseDate)!
            return historicalMetrics.filter { $0.date >= start && $0.date <= baseDate }
        case .sixMonths:
            let start = calendar.date(byAdding: .day, value: -179, to: baseDate)!
            return historicalMetrics.filter { $0.date >= start && $0.date <= baseDate }
        case .year:
            let start = calendar.date(byAdding: .day, value: -364, to: baseDate)!
            return historicalMetrics.filter { $0.date >= start && $0.date <= baseDate }
        }
    }

    private var displayScore: Int {
        if selectedTimeframe == .day { return displayedScore }
        let scores = filteredMetrics.map { $0.sleepScore }.filter { $0 > 0 }
        return scores.isEmpty ? displayedScore : Int(scores.reduce(0, +) / scores.count)
    }

    private var displayDuration: Double {
        if selectedTimeframe == .day { return displayedDuration }
        let durations = filteredMetrics.map { $0.sleepDuration }.filter { $0 > 0 }
        return durations.isEmpty ? displayedDuration : durations.reduce(0, +) / Double(durations.count)
    }

    // MARK: - Tonight's sleep need (always based on today)
    private var predictedSleepNeeded: (totalHours: Double, strainAdditionMins: Int, debtAdditionMins: Int) {
        let baseNeeded = needed > 0 ? needed : 8.0
        let strainExtensionMins = Int(hkManager.todayStrain * 3.5)

        var last7 = Array(historicalMetrics.suffix(7))
        let todayStart = calendar.startOfDay(for: Date())
        if !last7.contains(where: { calendar.isDate($0.date, inSameDayAs: todayStart) }) {
            let todayMetric = DailyMetrics(
                date: todayStart, recoveryScore: hkManager.todayRecovery, strainScore: hkManager.todayStrain,
                sleepScore: score, hrv: hkManager.todayHRV, rhr: hkManager.todayRHR, sleepDuration: duration,
                sleepNeeded: needed, deepMinutes: deep, remMinutes: rem, activeCalories: hkManager.todayActiveCalories,
                averageHR: hkManager.todayAverageHR > 0 ? hkManager.todayAverageHR : 80,
                maxHR: hkManager.todayMaxHR > 0 ? hkManager.todayMaxHR : 140,
                steps: hkManager.todaySteps, respiratoryRate: hkManager.todayRespiratoryRate,
                oxygenSaturation: hkManager.todayOxygenSaturation, bodyTemperature: hkManager.todayBodyTemperature
            )
            last7.append(todayMetric)
            if last7.count > 7 { last7.removeFirst() }
        }
        let validLast7 = last7.filter { $0.sleepDuration > 0 }
        let totalDebt = validLast7.reduce(0.0) { $0 + max(0, $1.sleepNeeded - $1.sleepDuration) }
        let dailyDebt = validLast7.isEmpty ? 0.0 : totalDebt / Double(validLast7.count)
        let debtMins = Int(min(120, dailyDebt * 60))
        return (baseNeeded + Double(strainExtensionMins + debtMins) / 60.0, strainExtensionMins, debtMins)
    }

    // Historical sleep analysis for a past day (for past day outlook card)
    private var historicalSleepAnalysis: (recommendedHours: Double, actualHours: Double, surplus: Double)? {
        guard !isViewingToday && selectedTimeframe == .day else { return nil }
        guard let dayData = historicalMetrics.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDayDate) }) else { return nil }
        // Prior day's strain drives sleep need
        let priorDay = calendar.date(byAdding: .day, value: -1, to: selectedDayDate)!
        let priorStrain = historicalMetrics.first(where: { calendar.isDate($0.date, inSameDayAs: priorDay) })?.strainScore ?? 0
        let recommendedHours = 8.0 + (priorStrain * 3.5 / 60.0)
        let actualHours = dayData.sleepDuration
        let surplus = actualHours - recommendedHours
        return (recommendedHours, actualHours, surplus)
    }

    // MARK: - Chart data
    private func getSleepData(isScore: Bool) -> TimeframeData {
        switch selectedTimeframe {
        case .day:
            let base = isScore ? Double(displayedScore) : displayedDuration
            guard base > 0 else { return TimeframeData(points: [], labels: [], average: 0) }
            let pts = isScore
                ? [base*0.1, base*0.5, base*0.85, base, base, base, base, base]
                : [base*0.125, base*0.5, base*0.875, base, base, base, base, base]
            return TimeframeData(points: pts, labels: ["12am","3am","6am","9am","12pm","3pm","6pm","9pm"], average: base)

        case .threeDays:
            let valid = filteredMetrics.filter { isScore ? $0.sleepScore > 0 : $0.sleepDuration > 0 }
            let pts = valid.map { isScore ? Double($0.sleepScore) : $0.sleepDuration }
            let fmt = DateFormatter(); fmt.dateFormat = "E"
            let labels = valid.map { fmt.string(from: $0.date) }
            let avg = pts.isEmpty ? 0 : pts.reduce(0,+) / Double(pts.count)
            return TimeframeData(points: pts, labels: labels, average: avg)

        case .week:
            let valid = filteredMetrics.filter { isScore ? $0.sleepScore > 0 : $0.sleepDuration > 0 }
            let pts = valid.map { isScore ? Double($0.sleepScore) : $0.sleepDuration }
            let fmt = DateFormatter(); fmt.dateFormat = "E"
            let labels = valid.map { fmt.string(from: $0.date) }
            let avg = pts.isEmpty ? 0 : pts.reduce(0,+) / Double(pts.count)
            return TimeframeData(points: pts, labels: labels, average: avg)

        case .month:
            let valid = filteredMetrics.filter { isScore ? $0.sleepScore > 0 : $0.sleepDuration > 0 }
            let pts = valid.map { isScore ? Double($0.sleepScore) : $0.sleepDuration }
            let avg = pts.isEmpty ? 0 : pts.reduce(0,+) / Double(pts.count)
            return TimeframeData(points: pts, labels: ["W1","W2","W3","W4"], average: avg)

        case .sixMonths:
            let valid6M = filteredMetrics.filter { isScore ? $0.sleepScore > 0 : $0.sleepDuration > 0 }
            var sums6M: [Int: Double] = [:]; var counts6M: [Int: Double] = [:]; var dates6M: [Int: Date] = [:]
            for m in valid6M {
                let mo = calendar.component(.month, from: m.date)
                sums6M[mo, default: 0] += isScore ? Double(m.sleepScore) : m.sleepDuration
                counts6M[mo, default: 0] += 1
                dates6M[mo] = m.date
            }
            let sorted6M = dates6M.keys.sorted { dates6M[$0]! < dates6M[$1]! }
            let pts6M = sorted6M.map { (sums6M[$0] ?? 0) / (counts6M[$0] ?? 1) }
            let fmt6M = DateFormatter(); fmt6M.dateFormat = "MMM"
            let labels6M = sorted6M.map { fmt6M.string(from: dates6M[$0]!) }
            let avg6M = pts6M.isEmpty ? 0 : pts6M.reduce(0,+) / Double(pts6M.count)
            return TimeframeData(points: pts6M, labels: labels6M, average: avg6M)

        case .year:
            let valid = filteredMetrics.filter { isScore ? $0.sleepScore > 0 : $0.sleepDuration > 0 }
            var sums: [Int: Double] = [:]; var counts: [Int: Double] = [:]; var dates: [Int: Date] = [:]
            for m in valid {
                let mo = calendar.component(.month, from: m.date)
                sums[mo, default: 0] += isScore ? Double(m.sleepScore) : m.sleepDuration
                counts[mo, default: 0] += 1
                dates[mo] = m.date
            }
            let sorted = dates.keys.sorted { dates[$0]! < dates[$1]! }
            let pts = sorted.map { (sums[$0] ?? 0) / (counts[$0] ?? 1) }
            let fmt = DateFormatter(); fmt.dateFormat = "MMM"
            let labels = sorted.map { fmt.string(from: dates[$0]!) }
            let avg = pts.isEmpty ? 0 : pts.reduce(0,+) / Double(pts.count)
            return TimeframeData(points: pts, labels: labels, average: avg)
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            AppBackground(accent: Theme.Colors.sleepDeep)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    CustomSegmentedPicker(selection: $selectedTimeframe)
                        .padding(.top, 10)
                        .onChange(of: selectedTimeframe) { _, _ in
                            baseDate = calendar.startOfDay(for: Date())
                            selectedDayDate = calendar.startOfDay(for: Date())
                            historicalDaySleepStages = []
                        }

                    // Period / day navigation bar
                    PeriodNavigationView(
                        timeframe: selectedTimeframe,
                        baseDate: selectedTimeframe == .day ? $selectedDayDate : $baseDate,
                        accentColor: Theme.Colors.sleepDeep
                    )

                    MetricInsightCard(metric: .sleep, hkManager: hkManager)
                        .padding(.horizontal)
                    .onChange(of: selectedDayDate) { _, newDate in
                        if selectedTimeframe == .day && !calendar.isDateInToday(newDate) {
                            historicalDaySleepStages = hkManager.loadSleepStages(for: newDate)
                        } else {
                            historicalDaySleepStages = []
                        }
                    }

                    // Compact Score Card
                    HStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .stroke(Theme.Colors.sleepLight.opacity(0.08), lineWidth: 6)
                                .frame(width: 64, height: 64)
                            Circle()
                                .trim(from: 0, to: CGFloat(Double(displayScore) / 100.0))
                                .stroke(
                                    LinearGradient(colors: [Theme.Colors.sleepLight, Theme.Colors.sleepLight.opacity(0.6)], startPoint: .top, endPoint: .bottom),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .frame(width: 64, height: 64)
                                .rotationEffect(.degrees(-90))
                                .shadow(color: Theme.Colors.sleepLight.opacity(0.3), radius: 4)
                            Text(displayScore > 0 ? "\(displayScore)%" : "--")
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

                    // Sleep Need Outlook
                    if selectedTimeframe == .day && isViewingToday {
                        let sleepNeed = predictedSleepNeeded
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(isStaleLabelActive ? "LATEST SLEEP OUTLOOK (\(formatDate(hkManager.sleepDataDate)))" : "TONIGHT'S OUTLOOK")
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
                                let mins = Int((sleepNeed.totalHours - Double(hours)) * 60)
                                Text("\(hours)h \(mins)m")
                                    .font(Theme.Typography.metricLabel(size: 36))
                                    .foregroundColor(.white)
                                Text("Needed Tonight")
                                    .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.bottom, 6)
                            }

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
                    } else if selectedTimeframe == .day && !isViewingToday {
                        // Historical day outlook card
                        if let analysis = historicalSleepAnalysis {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("SLEEP ANALYSIS FOR \(formatDate(selectedDayDate).uppercased())")
                                            .font(Theme.Typography.cardTitle)
                                            .foregroundColor(.white.opacity(0.5))
                                        Text("Sleep Duration & Need")
                                            .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    Image(systemName: "moon.stars.fill")
                                        .font(.title3)
                                        .foregroundColor(Theme.Colors.sleepLight)
                                }

                                HStack(alignment: .bottom, spacing: 2) {
                                    Text(analysis.actualHours > 0 ? formatSleepHours(analysis.actualHours) : "--")
                                        .font(Theme.Typography.metricLabel(size: 36))
                                        .foregroundColor(.white)
                                    Text("Actual Sleep")
                                        .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                        .padding(.bottom, 6)
                                }

                                VStack(spacing: 8) {
                                    HStack {
                                        Text("Recommended sleep:")
                                            .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                            .foregroundColor(.white.opacity(0.5))
                                        Spacer()
                                        Text(String(format: "%.1f hrs", analysis.recommendedHours))
                                            .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    HStack {
                                        Text("Sleep surplus / deficit:")
                                            .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                            .foregroundColor(.white.opacity(0.5))
                                        Spacer()
                                        let surplusText = analysis.surplus >= 0 ? String(format: "+%.1f hrs", analysis.surplus) : String(format: "%.1f hrs", analysis.surplus)
                                        Text(surplusText)
                                            .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                            .foregroundColor(analysis.surplus >= 0 ? Theme.Colors.recoveryHigh : Theme.Colors.recoveryLow)
                                    }
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.02))
                                .cornerRadius(8)
                            }
                            .glassCard()
                            .padding(.horizontal)
                        }
                    }

                    // Sleep Quality & Duration Trends (Tabbed)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedGraphTab = 0 } }) {
                                Text("Quality Score")
                                    .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                    .foregroundColor(selectedGraphTab == 0 ? .white : .white.opacity(0.4))
                                    .padding(.vertical, 6).padding(.horizontal, 12)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(selectedGraphTab == 0 ? Color.white.opacity(0.08) : Color.clear))
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedGraphTab = 1 } }) {
                                Text("Duration (Hrs)")
                                    .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                    .foregroundColor(selectedGraphTab == 1 ? .white : .white.opacity(0.4))
                                    .padding(.vertical, 6).padding(.horizontal, 12)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(selectedGraphTab == 1 ? Color.white.opacity(0.08) : Color.clear))
                            }
                            .buttonStyle(PlainButtonStyle())
                            Spacer()
                        }
                        .padding(.bottom, 4)

                        if selectedGraphTab == 0 {
                            let trendData = getSleepData(isScore: true)
                            VStack(alignment: .leading, spacing: 12) {
                                if trendData.points.isEmpty {
                                    noDataPlaceholder
                                } else {
                                    CustomLineGraph(points: trendData.points, labels: trendData.labels,
                                                    lineColor: Theme.Colors.sleepLight,
                                                    gradientColors: [Theme.Colors.sleepLight.opacity(0.2), .clear])
                                        .frame(height: 140).transition(.opacity)
                                }
                                HStack {
                                    Text(trendData.points.isEmpty ? "No data" : String(format: "Average Score: %.0f%%", trendData.average))
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text(displayScore > 0 ? "\(displayScore)%" : "--")
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                        .foregroundColor(Theme.Colors.sleepLight)
                                }
                                .padding(.top, 4)
                            }
                        } else {
                            let trendData = getSleepData(isScore: false)
                            VStack(alignment: .leading, spacing: 12) {
                                if trendData.points.isEmpty {
                                    noDataPlaceholder
                                } else {
                                    CustomLineGraph(points: trendData.points, labels: trendData.labels,
                                                    lineColor: Theme.Colors.sleepREM,
                                                    gradientColors: [Theme.Colors.sleepREM.opacity(0.2), .clear])
                                        .frame(height: 140).transition(.opacity)
                                }
                                HStack {
                                    Text(trendData.points.isEmpty ? "No data" : String(format: "Average Sleep: %.1f hrs", trendData.average))
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text(displayedDuration > 0 ? formatSleepHours(displayedDuration) : "--")
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                        .foregroundColor(Theme.Colors.sleepREM)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .glassCard()
                    .padding(.horizontal)

                    // Hypnogram (day + week view)
                    if selectedTimeframe == .day || selectedTimeframe == .week || selectedTimeframe == .threeDays {
                        SleepHypnogramChart(samples: displayedSleepStages)
                            .padding(.horizontal)
                    }

                    // Sleep Architecture
                    VStack(alignment: .leading, spacing: 16) {
                        let archTitle: String = {
                            if selectedTimeframe == .day {
                                if !isViewingToday {
                                    return "Sleep Architecture (\(formatDate(selectedDayDate)))"
                                }
                                return isStaleLabelActive ? "Sleep Architecture (\(formatDate(hkManager.sleepDataDate)))" : "Tonight's Sleep Architecture"
                            }
                            switch selectedTimeframe {
                            case .threeDays: return "3-Day Average Architecture"
                            case .week: return "Weekly Average Architecture"
                            case .month: return "Monthly Average Architecture"
                            case .sixMonths: return "6-Month Average Architecture"
                            default: return "Annual Average Architecture"
                            }
                        }()
                        Text(archTitle)
                            .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        let archMetrics: [DailyMetrics] = {
                            switch selectedTimeframe {
                            case .day: return []
                            case .threeDays: return filteredMetrics.filter { $0.sleepDuration > 0 }
                            case .week: return filteredMetrics.filter { $0.sleepDuration > 0 }
                            case .month: return filteredMetrics.filter { $0.sleepDuration > 0 }
                            case .sixMonths: return filteredMetrics.filter { $0.sleepDuration > 0 }
                            case .year: return filteredMetrics.filter { $0.sleepDuration > 0 }
                            }
                        }()

                        let avgDuration = archMetrics.isEmpty ? displayedDuration : archMetrics.map { $0.sleepDuration }.reduce(0,+) / Double(archMetrics.count)
                        let avgDeep = archMetrics.isEmpty ? displayedDeep : archMetrics.map { $0.deepMinutes }.reduce(0,+) / Double(archMetrics.count)
                        let avgRem = archMetrics.isEmpty ? displayedRem : archMetrics.map { $0.remMinutes }.reduce(0,+) / Double(archMetrics.count)

                        let awakeMins: Double = {
                            if selectedTimeframe == .day {
                                let awakeSamples = displayedSleepStages.filter { $0.stage == 0 }
                                let totalSecs = awakeSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                                return totalSecs > 0 ? totalSecs / 60.0 : (displayedDuration > 0 ? 24.0 : 0.0)
                            }
                            return avgDuration > 0 ? 24.0 : 0.0
                        }()

                        let lightMins = max(0.0, (avgDuration * 60.0) - avgDeep - avgRem)
                        let total = awakeMins + lightMins + avgRem + avgDeep

                        if total > 0 {
                            let awakeR = awakeMins / total
                            let lightR  = lightMins / total
                            let remR    = avgRem / total
                            let deepR   = avgDeep / total

                            GeometryReader { geo in
                                HStack(spacing: 0) {
                                    Color.orange.opacity(0.8).frame(width: geo.size.width * CGFloat(awakeR))
                                    Theme.Colors.sleepLight.frame(width: geo.size.width * CGFloat(lightR))
                                    Theme.Colors.sleepREM.frame(width: geo.size.width * CGFloat(remR))
                                    Theme.Colors.sleepDeep.frame(width: geo.size.width * CGFloat(deepR))
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .frame(height: 24)

                            let deepPct  = Int(round(deepR  * 100))
                            let remPct   = Int(round(remR   * 100))
                            let lightPct = Int(round(lightR * 100))
                            let awakePct = max(0, 100 - deepPct - remPct - lightPct)

                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                SleepStageCard(stageName: "Awake",      minutes: awakeMins, percentage: awakePct, color: .orange,                  icon: "sun.max.fill")
                                SleepStageCard(stageName: "Light Sleep", minutes: lightMins, percentage: lightPct, color: Theme.Colors.sleepLight,  icon: "moon.fill")
                                SleepStageCard(stageName: "REM Sleep",   minutes: avgRem,    percentage: remPct,   color: Theme.Colors.sleepREM,    icon: "sparkles")
                                SleepStageCard(stageName: "Deep Sleep",  minutes: avgDeep,   percentage: deepPct,  color: Theme.Colors.sleepDeep,   icon: "moon.stars.fill")
                            }
                            .padding(.top, 8)
                        } else {
                            noDataPlaceholder
                        }
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
                            Image(systemName: "hourglass.badge.plus").foregroundColor(.orange)
                        }

                        let debt = max(0.0, needed - displayDuration)
                        HStack(alignment: .bottom) {
                            Text(displayDuration > 0 ? String(format: "%.1f hrs", debt) : "--")
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

                    // Algorithm Details
                    VStack(alignment: .leading, spacing: 14) {
                        Button(action: { withAnimation(.spring()) { showAlgorithmDetails.toggle() } }) {
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
                                Text("Dip % = ((DayAvgHR - NightAvgHR) / DayAvgHR) * 100")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(8)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(6)
                                Text("A healthy cardiovascular system shows an autonomic shift during sleep. Heart rate should dip by **10% to 20%** compared to your daytime average.")
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

    // MARK: - Helpers
    private var noDataPlaceholder: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "moon.zzz")
                    .font(Theme.Typography.roundedFont(size: 24, weight: .regular))
                    .foregroundColor(.white.opacity(0.2))
                Text("No sleep data for this period")
                    .font(Theme.Typography.roundedFont(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.vertical, 30)
            Spacer()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func formatSleepHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
