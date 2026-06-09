import SwiftUI

struct ActivenessDetailView: View {
    @ObservedObject var hkManager: HealthKitManager
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedTimeframe: Timeframe = .week
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())

    private var cal: Calendar { Calendar.current }
    private var isViewingToday: Bool { cal.isDateInToday(selectedDay) }
    private var historicalMetrics: [DailyMetrics] { hkManager.historicalMetrics }

    @State private var showThresholdSettings = false

    // Compute a comparable activeness score from historical DailyMetrics
    private func computeScore(for m: DailyMetrics) -> Int {
        let t = PhysiologicalCalculators.getActivityThresholds()
        let sRecovery = Double(m.recoveryScore) / 100.0
        let sStrain = exp(-0.5 * pow((m.strainScore - t.optimalStrain) / 4.0, 2))
        let sSleep = Double(m.sleepScore) / 100.0
        let stepsNorm = min(1.0, Double(m.steps) / Double(t.dailyStepsGoal))
        let calorieTarget = t.dailyCalorieGoal > 0 ? t.dailyCalorieGoal : 600.0
        let calsNorm = min(1.0, m.activeCalories / calorieTarget)
        let sActivity = 0.6 * stepsNorm + 0.4 * calsNorm
        // Sigmoid centered at 50ms HRV — higher HRV = better
        let sHRV = m.hrv > 0 ? (1.0 / (1.0 + exp(-0.05 * (m.hrv - 50.0)))) : 0.5
        let weighted = 0.25*sRecovery + 0.20*sStrain + 0.20*sSleep + 0.15*sActivity + 0.10*sHRV + 0.10*0.5
        return max(0, min(100, Int(round(weighted * 100.0))))
    }

    private var displayedScore: Int {
        if selectedTimeframe == .day {
            if isViewingToday { return hkManager.activenessScore }
            guard let m = historicalMetrics.first(where: { cal.isDate($0.date, inSameDayAs: selectedDay) }) else { return 0 }
            return computeScore(for: m)
        }
        // For trend views, show the period average so the gauge updates with each timeframe
        let data = getHistoricalData()
        return data.points.isEmpty ? hkManager.activenessScore : max(1, Int(round(data.average)))
    }

    private var classification: (label: String, color: Color) {
        let s = displayedScore
        if s >= 80 { return ("Peak Form", Theme.Colors.recoveryHigh) }
        if s >= 60 { return ("Well Balanced", Theme.Colors.sleepDeep) }
        if s >= 40 { return ("Moderate", Theme.Colors.strainHigh) }
        return ("Recovery Needed", Theme.Colors.recoveryLow)
    }

    // Historical chart data
    private func getHistoricalData() -> TimeframeData {
        let fmt = DateFormatter(); fmt.dateFormat = "E"
        let fmtMMM = DateFormatter(); fmtMMM.dateFormat = "MMM"
        let endDate = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!

        func monthlyAggregate(from startDate: Date) -> TimeframeData {
            let relevant = historicalMetrics.filter { $0.date >= startDate && $0.date <= endDate }
            var sums: [Int: Double] = [:]; var counts: [Int: Double] = [:]; var dates: [Int: Date] = [:]
            for m in relevant {
                let comps = cal.dateComponents([.year, .month], from: m.date)
                let key = (comps.year ?? 0) * 100 + (comps.month ?? 0)
                sums[key, default: 0] += Double(computeScore(for: m))
                counts[key, default: 0] += 1
                dates[key] = m.date
            }
            let sorted = dates.keys.sorted { dates[$0]! < dates[$1]! }
            let pts = sorted.map { (sums[$0] ?? 0) / (counts[$0] ?? 1) }
            let labels = sorted.map { fmtMMM.string(from: dates[$0]!) }
            let avg = pts.isEmpty ? 0 : pts.reduce(0, +) / Double(pts.count)
            return TimeframeData(points: pts, labels: labels, average: avg)
        }

        switch selectedTimeframe {
        case .day:
            return TimeframeData(points: [], labels: [], average: Double(displayedScore))
        case .threeDays:
            let start = cal.date(byAdding: .day, value: -2, to: cal.startOfDay(for: Date()))!
            let relevant = historicalMetrics.filter { $0.date >= start && $0.date <= endDate }.sorted { $0.date < $1.date }
            let pts = relevant.map { Double(computeScore(for: $0)) }
            return TimeframeData(points: pts, labels: relevant.map { fmt.string(from: $0.date) },
                                 average: pts.isEmpty ? 0 : pts.reduce(0, +) / Double(pts.count))
        case .week:
            let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date()))!
            let relevant = historicalMetrics.filter { $0.date >= start && $0.date <= endDate }.sorted { $0.date < $1.date }
            let pts = relevant.map { Double(computeScore(for: $0)) }
            return TimeframeData(points: pts, labels: relevant.map { fmt.string(from: $0.date) },
                                 average: pts.isEmpty ? 0 : pts.reduce(0, +) / Double(pts.count))
        case .month:
            let start = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: Date()))!
            let relevant = historicalMetrics.filter { $0.date >= start && $0.date <= endDate }.sorted { $0.date < $1.date }
            let pts = relevant.map { Double(computeScore(for: $0)) }
            let dateFmt = DateFormatter(); dateFmt.dateFormat = "d MMM"
            let step = max(1, relevant.count / 6)
            let thinLabels = relevant.enumerated().map { (i, m) -> String in
                (i % step == 0 || i == relevant.count - 1) ? dateFmt.string(from: m.date) : ""
            }
            return TimeframeData(points: pts, labels: thinLabels,
                                 average: pts.isEmpty ? 0 : pts.reduce(0, +) / Double(pts.count))
        case .sixMonths:
            return monthlyAggregate(from: cal.date(byAdding: .month, value: -6, to: cal.startOfDay(for: Date()))!)
        case .year:
            return monthlyAggregate(from: cal.date(byAdding: .year, value: -1, to: cal.startOfDay(for: Date()))!)
        }
    }

    // Sub-score breakdown — single day for .day, period averages for all other timeframes
    private var subScores: [(label: String, icon: String, value: Int, color: Color)] {
        let t = PhysiologicalCalculators.getActivityThresholds()

        func makeScores(recovery: Int, strain: Double, sleep: Int, steps: Int, calories: Double, hrv: Double)
            -> [(label: String, icon: String, value: Int, color: Color)] {
            let calTarget = t.dailyCalorieGoal > 0 ? t.dailyCalorieGoal : 600.0
            let sStrain   = Int(round(exp(-0.5 * pow((strain - t.optimalStrain) / 4.0, 2)) * 100.0))
            let sActivity = Int(round((0.6 * min(1.0, Double(steps) / Double(t.dailyStepsGoal))
                                     + 0.4 * min(1.0, calories / calTarget)) * 100.0))
            let sHRV      = hrv > 0 ? Int(round((1.0 / (1.0 + exp(-0.05 * (hrv - 50.0)))) * 100.0)) : 50
            return [
                ("Recovery", "heart.fill",          recovery, Theme.Colors.recoveryHigh),
                ("Strain",   "flame.fill",           sStrain,  Theme.Colors.strainHigh),
                ("Sleep",    "moon.fill",            sleep,    Theme.Colors.sleepDeep),
                ("Activity", "figure.run",           sActivity,Theme.Colors.recoveryHigh),
                ("HRV",      "waveform.path.ecg",   sHRV,     Theme.Colors.sleepDeep)
            ]
        }

        // Single day
        if selectedTimeframe == .day {
            let m: DailyMetrics? = isViewingToday ? nil
                : historicalMetrics.first(where: { cal.isDate($0.date, inSameDayAs: selectedDay) })
            return makeScores(
                recovery: m.map { $0.recoveryScore } ?? hkManager.todayRecovery,
                strain:   m.map { $0.strainScore }   ?? hkManager.todayStrain,
                sleep:    m.map { $0.sleepScore }     ?? hkManager.todaySleepScore,
                steps:    m.map { $0.steps }           ?? hkManager.todaySteps,
                calories: m.map { $0.activeCalories } ?? hkManager.todayActiveCalories,
                hrv:      m.map { $0.hrv }             ?? hkManager.todayHRV
            )
        }

        // Multi-day: compute period averages from historicalMetrics
        let endDate = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        let startDate: Date = {
            switch selectedTimeframe {
            case .threeDays: return cal.date(byAdding: .day,   value: -2,  to: cal.startOfDay(for: Date()))!
            case .week:      return cal.date(byAdding: .day,   value: -6,  to: cal.startOfDay(for: Date()))!
            case .month:     return cal.date(byAdding: .day,   value: -29, to: cal.startOfDay(for: Date()))!
            case .sixMonths: return cal.date(byAdding: .month, value: -6,  to: cal.startOfDay(for: Date()))!
            default:         return cal.date(byAdding: .year,  value: -1,  to: cal.startOfDay(for: Date()))!
            }
        }()

        let filtered = historicalMetrics.filter { $0.date >= startDate && $0.date <= endDate }
        guard !filtered.isEmpty else {
            return makeScores(recovery: hkManager.todayRecovery, strain: hkManager.todayStrain,
                              sleep: hkManager.todaySleepScore, steps: hkManager.todaySteps,
                              calories: hkManager.todayActiveCalories, hrv: hkManager.todayHRV)
        }

        let n = Double(filtered.count)
        let avgRecovery  = Int(round(filtered.map { Double($0.recoveryScore) }.reduce(0, +) / n))
        let avgStrain    = filtered.map { $0.strainScore }.reduce(0, +) / n
        let avgSleep     = Int(round(filtered.map { Double($0.sleepScore) }.reduce(0, +) / n))
        let avgSteps     = Int(round(filtered.map { Double($0.steps) }.reduce(0, +) / n))
        let avgCalories  = filtered.map { $0.activeCalories }.reduce(0, +) / n
        let hrvsWithData = filtered.filter { $0.hrv > 0 }.map { $0.hrv }
        let avgHRV       = hrvsWithData.isEmpty ? 0.0 : hrvsWithData.reduce(0, +) / Double(hrvsWithData.count)

        return makeScores(recovery: avgRecovery, strain: avgStrain, sleep: avgSleep,
                          steps: avgSteps, calories: avgCalories, hrv: avgHRV)
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { presentationMode.wrappedValue.dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(Theme.Typography.titleSM)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.04))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Activeness Score")
                        .font(Theme.Typography.roundedFont(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button { showThresholdSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        CustomSegmentedPicker(selection: $selectedTimeframe)
                            .padding(.top, 10)

                        if selectedTimeframe == .day {
                            PeriodNavigationView(timeframe: .day, baseDate: $selectedDay, accentColor: Theme.Colors.strainHigh)
                        }

                        // Hero Gauge
                        HStack(alignment: .center, spacing: 20) {
                            ZStack {
                                ArcShape(startAngle: -210, endAngle: 30, lineWidth: 10)
                                    .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                    .frame(width: 110, height: 110)

                                ArcShape(startAngle: -210, endAngle: -210 + (240.0 * Double(min(displayedScore, 100)) / 100.0), lineWidth: 10)
                                    .stroke(
                                        AngularGradient(
                                            colors: [Theme.Colors.sleepDeep, Theme.Colors.recoveryHigh, Theme.Colors.strainHigh],
                                            center: .center,
                                            startAngle: .degrees(-210),
                                            endAngle: .degrees(30)
                                        ),
                                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                    )
                                    .frame(width: 110, height: 110)
                                    .shadow(color: classification.color.opacity(0.5), radius: 6)

                                VStack(spacing: 2) {
                                    Text("\(displayedScore)")
                                        .font(Theme.Typography.metricLabel(size: 36))
                                        .foregroundColor(.white)
                                    Text(classification.label)
                                        .font(Theme.Typography.tick)
                                        .foregroundColor(classification.color)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                            }
                            .frame(width: 110, height: 110)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("ACTIVENESS")
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundColor(.white.opacity(0.5))

                                Text(classification.label)
                                    .font(Theme.Typography.roundedFont(size: 22, weight: .bold))
                                    .foregroundColor(.white)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white.opacity(0.08))
                                            .frame(height: 6)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(LinearGradient(
                                                colors: [Theme.Colors.sleepDeep, Theme.Colors.recoveryHigh],
                                                startPoint: .leading, endPoint: .trailing))
                                            .frame(width: geo.size.width * CGFloat(displayedScore) / 100.0, height: 6)
                                    }
                                }
                                .frame(height: 6)

                                HStack {
                                    Text("0")
                                        .font(Theme.Typography.tick)
                                        .foregroundColor(.white.opacity(0.3))
                                    Spacer()
                                    Text("100")
                                        .font(Theme.Typography.tick)
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                        .padding(.horizontal)

                        // Trend Chart (non-day timeframes)
                        if selectedTimeframe != .day {
                            let data = getHistoricalData()
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Score Trend")
                                        .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(data.points.isEmpty ? "No Data" : String(format: "Avg  %.0f", data.average))
                                        .font(Theme.Typography.roundedFont(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }

                                if data.points.isEmpty {
                                    Text("No historical data available for this period.")
                                        .font(Theme.Typography.roundedFont(size: 13, weight: .regular))
                                        .foregroundColor(.white.opacity(0.4))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .frame(height: 120)
                                } else {
                                    CustomLineGraph(
                                        points: data.points,
                                        labels: data.labels,
                                        lineColor: Theme.Colors.recoveryHigh,
                                        gradientColors: [Theme.Colors.recoveryHigh.opacity(0.25), .clear]
                                    )
                                    .frame(height: 150)
                                    .padding(.vertical, 8)
                                }
                            }
                            .glassCard()
                            .padding(.horizontal)
                        }

                        // Component Breakdown
                        VStack(alignment: .leading, spacing: 14) {
                            Text("COMPONENT BREAKDOWN")
                                .font(Theme.Typography.cardTitle)
                                .foregroundColor(.white.opacity(0.5))

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(subScores, id: \.label) { sub in
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .stroke(sub.color.opacity(0.15), lineWidth: 3)
                                                .frame(width: 52, height: 52)
                                            Circle()
                                                .trim(from: 0, to: min(1.0, CGFloat(sub.value) / 100.0))
                                                .stroke(sub.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                                .frame(width: 52, height: 52)
                                                .rotationEffect(.degrees(-90))
                                            Image(systemName: sub.icon)
                                                .font(.system(size: 14))
                                                .foregroundColor(sub.color)
                                        }
                                        Text(sub.value > 0 ? "\(sub.value)%" : "--")
                                            .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(sub.label)
                                            .font(Theme.Typography.tick)
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.04))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .glassCard()
                        .padding(.horizontal)

                        // How it's calculated
                        VStack(alignment: .leading, spacing: 10) {
                            Text("HOW IT'S CALCULATED")
                                .font(Theme.Typography.cardTitle)
                                .foregroundColor(.white.opacity(0.5))

                            Text("Activeness Score blends five pillars of daily health into a single readiness number: Recovery (25%), Strain Balance (20%), Sleep Quality (20%), Physical Activity (15%), HRV Trend (10%), and Stress Inverse (10%). A score above 80 means peak readiness — below 40 signals your body needs rest.")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .regular))
                                .foregroundColor(.white.opacity(0.75))
                                .lineSpacing(4)
                        }
                        .glassCard()
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showThresholdSettings) {
            ActivityThresholdSettingsSheet()
        }
    }
}

// MARK: - Threshold Settings Sheet
struct ActivityThresholdSettingsSheet: View {
    @Environment(\.presentationMode) var presentationMode

    @State private var stepsGoal: Double
    @State private var calorieGoal: Double
    @State private var optimalStrain: Double
    @State private var showSaveConfirm = false

    init() {
        let t = PhysiologicalCalculators.getActivityThresholds()
        _stepsGoal = State(initialValue: Double(t.dailyStepsGoal))
        _calorieGoal = State(initialValue: t.dailyCalorieGoal > 0 ? t.dailyCalorieGoal : 500.0)
        _optimalStrain = State(initialValue: t.optimalStrain)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Warning banner
                        HStack(spacing: 10) {
                            Image(systemName: "clock.arrow.2.circlepath")
                                .foregroundColor(.orange)
                                .font(.system(size: 16))
                            Text("Changing thresholds starts a 7-day recalibration window. Your Activeness Score badge will show \"RECALIBRATING\" until the new baselines settle.")
                                .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.75))
                                .lineSpacing(3)
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                        .padding(.horizontal)
                        .padding(.top, 20)

                        // Steps Goal
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "figure.walk")
                                    .foregroundColor(Theme.Colors.recoveryHigh)
                                Text("Daily Steps Goal")
                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(stepsGoal).formatted())")
                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                    .foregroundColor(Theme.Colors.recoveryHigh)
                            }
                            Slider(value: $stepsGoal, in: 3000...20000, step: 500)
                                .accentColor(Theme.Colors.recoveryHigh)
                            HStack {
                                Text("3,000").font(Theme.Typography.tick).foregroundColor(.white.opacity(0.4))
                                Spacer()
                                Text("20,000").font(Theme.Typography.tick).foregroundColor(.white.opacity(0.4))
                            }
                            Text("Activity sub-score reaches 100% when you hit this goal. Default: 10,000.")
                                .font(Theme.Typography.tick)
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .glassCard()
                        .padding(.horizontal)

                        // Calorie Goal
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(Theme.Colors.strainHigh)
                                Text("Active Calorie Goal")
                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(calorieGoal)) kcal")
                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                    .foregroundColor(Theme.Colors.strainHigh)
                            }
                            Slider(value: $calorieGoal, in: 200...1200, step: 25)
                                .accentColor(Theme.Colors.strainHigh)
                            HStack {
                                Text("200").font(Theme.Typography.tick).foregroundColor(.white.opacity(0.4))
                                Spacer()
                                Text("1,200").font(Theme.Typography.tick).foregroundColor(.white.opacity(0.4))
                            }
                            Text("Calorie component of activity score. Auto-calculated from your weight if unset.")
                                .font(Theme.Typography.tick)
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .glassCard()
                        .padding(.horizontal)

                        // Optimal Strain
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "waveform.path.ecg.rectangle")
                                    .foregroundColor(Theme.Colors.sleepDeep)
                                Text("Optimal Strain Target")
                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(String(format: "%.1f", optimalStrain))
                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                    .foregroundColor(Theme.Colors.sleepDeep)
                            }
                            Slider(value: $optimalStrain, in: 5...20, step: 0.5)
                                .accentColor(Theme.Colors.sleepDeep)
                            HStack {
                                Text("5.0 (Light)").font(Theme.Typography.tick).foregroundColor(.white.opacity(0.4))
                                Spacer()
                                Text("20.0 (High)").font(Theme.Typography.tick).foregroundColor(.white.opacity(0.4))
                            }
                            Text("Strain score peaks when your daily training load hits this target. Default: 11.0.")
                                .font(Theme.Typography.tick)
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .glassCard()
                        .padding(.horizontal)

                        // Save Button
                        Button {
                            PhysiologicalCalculators.saveActivityThresholds(
                                PhysiologicalCalculators.ActivityThresholds(
                                    dailyStepsGoal: Int(stepsGoal),
                                    dailyCalorieGoal: calorieGoal,
                                    optimalStrain: optimalStrain
                                )
                            )
                            showSaveConfirm = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                presentationMode.wrappedValue.dismiss()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if showSaveConfirm {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.Colors.recoveryHigh)
                                    Text("Saved — 7-day recalibration started")
                                        .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                                        .foregroundColor(Theme.Colors.recoveryHigh)
                                } else {
                                    Text("Save Thresholds")
                                        .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .background(showSaveConfirm ? Theme.Colors.recoveryHigh.opacity(0.15) : Theme.Colors.sleepDeep.opacity(0.8))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .animation(.easeInOut(duration: 0.2), value: showSaveConfirm)

                        Spacer().frame(height: 30)
                    }
                }
            }
            .navigationTitle("Score Thresholds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }
}
