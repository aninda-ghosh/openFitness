import SwiftUI

struct StrainDetailView: View {
    @ObservedObject var hkManager: HealthKitManager
    let strain: Double
    let targetLow: Double
    let targetHigh: Double
    let calories: Double
    let avgHR: Double
    let workouts: [WorkoutItem]
    
    @State private var selectedTimeframe: Timeframe = .day
    @State private var showAlgorithmDetails = false
    
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
                strainScore: strain,
                sleepScore: hkManager.todaySleepScore,
                hrv: hkManager.todayHRV,
                rhr: hkManager.todayRHR,
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
    
    private var displayStrain: Double {
        if selectedTimeframe == .day {
            return strain
        }
        let metrics = filteredMetrics
        let scores = metrics.map { $0.strainScore }
        if scores.isEmpty {
            return strain
        }
        return scores.reduce(0.0, +) / Double(scores.count)
    }
    
    // 1. Dynamic average zone durations based on average strain
    private var averageDailyZoneDurations: (z5: Int, z4: Int, z3: Int, z2: Int, z1: Int) {
        let load = displayStrain
        return (
            z5: max(0, Int(load * 0.2)),
            z4: max(1, Int(load * 1.1)),
            z3: max(2, Int(load * 2.2)),
            z2: max(5, Int(load * 3.8)),
            z1: max(3, Int(load * 1.6))
        )
    }
    
    // Predicted minutes to reach target strain (always for today)
    private var predictedWorkoutMinutes: (zone2: Int, zone4: Int, status: String) {
        let currentStrain = strain
        let targetMid = (targetLow + targetHigh) / 2.0
        
        if currentStrain >= targetMid {
            return (0, 0, "Optimal strain target has been achieved for today.")
        }
        
        let currentTRIMP = currentStrain < 20.9 ? -log(1.0 - (currentStrain / 21.0)) / 0.0035 : 999.0
        let targetTRIMP = targetMid < 20.9 ? -log(1.0 - (targetMid / 21.0)) / 0.0035 : 999.0
        
        let remainingTRIMP = max(0.0, targetTRIMP - currentTRIMP)
        
        if remainingTRIMP <= 0 {
            return (0, 0, "Optimal strain target has been achieved for today.")
        }
        
        let minZone2 = Int(ceil(remainingTRIMP / 2.0))
        let minZone4 = Int(ceil(remainingTRIMP / 4.0))
        
        return (minZone2, minZone4, "Predictive estimate to hit optimal daily strain (\(String(format: "%.1f", targetMid))):")
    }
    
    private var cardioStatusBreakdown: [(status: String, days: Int, percentage: Int, color: Color)] {
        let metrics = selectedTimeframe == .day ? [DailyMetrics(
            date: Date(),
            recoveryScore: hkManager.todayRecovery,
            strainScore: strain,
            sleepScore: hkManager.todaySleepScore,
            hrv: hkManager.todayHRV,
            rhr: hkManager.todayRHR,
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
        )] : filteredMetrics
        
        var detraining = 0
        var maintaining = 0
        var productive = 0
        var fatigued = 0
        var overtraining = 0
        
        for m in metrics {
            let score = m.strainScore
            if score >= 15.0 {
                overtraining += 1
            } else if score >= 11.0 {
                fatigued += 1
            } else if score >= 7.0 {
                productive += 1
            } else if score >= 3.0 {
                maintaining += 1
            } else {
                detraining += 1
            }
        }
        
        let total = metrics.count
        guard total > 0 else {
            return [
                ("Detraining", 0, 0, Color.blue),
                ("Maintaining", 0, 0, Theme.Colors.sleepLight),
                ("Productive", 0, 0, Color.green),
                ("Fatigued", 0, 0, Color.orange),
                ("Overtraining", 0, 0, Color.red)
            ]
        }
        
        return [
            ("Detraining", detraining, detraining * 100 / total, Color.blue),
            ("Maintaining", maintaining, maintaining * 100 / total, Theme.Colors.sleepLight),
            ("Productive", productive, productive * 100 / total, Color.green),
            ("Fatigued", fatigued, fatigued * 100 / total, Color.orange),
            ("Overtraining", overtraining, overtraining * 100 / total, Color.red)
        ]
    }
    
    struct WorkoutTypeDistribution: Identifiable {
        let id = UUID()
        let name: String
        let duration: Double
        let calories: Double
        let count: Int
        let color: Color
    }
    
    private var workoutDistribution: [WorkoutTypeDistribution] {
        let workoutsList = hkManager.timeframeWorkouts
        var grouped: [String: (duration: Double, calories: Double, count: Int)] = [:]
        for w in workoutsList {
            let current = grouped[w.name, default: (0.0, 0.0, 0)]
            grouped[w.name] = (
                duration: current.duration + w.durationMinutes,
                calories: current.calories + w.activeEnergyBurned,
                count: current.count + 1
            )
        }
        
        return grouped.map { name, stats in
            WorkoutTypeDistribution(
                name: name,
                duration: stats.duration,
                calories: stats.calories,
                count: stats.count,
                color: colorForWorkoutType(name)
            )
        }.sorted { $0.duration > $1.duration }
    }
    
    private func colorForWorkoutType(_ name: String) -> Color {
        let nameLower = name.lowercased()
        if nameLower.contains("run") {
            return Color.red
        } else if nameLower.contains("walk") {
            return Color.green
        } else if nameLower.contains("cycle") || nameLower.contains("bike") {
            return Color.blue
        } else if nameLower.contains("strength") || nameLower.contains("weight") || nameLower.contains("resistance") {
            return Color.orange
        } else if nameLower.contains("swim") || nameLower.contains("pool") || nameLower.contains("water") {
            return Color.teal
        } else if nameLower.contains("yoga") || nameLower.contains("stretch") || nameLower.contains("pilates") {
            return Color.purple
        } else if nameLower.contains("hiit") || nameLower.contains("cardio") || nameLower.contains("crossfit") {
            return Color.pink
        } else {
            return Color.cyan
        }
    }
    
    private func formatDuration(_ mins: Double) -> String {
        let hours = Int(mins) / 60
        let minutes = Int(mins) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func getStrainData() -> TimeframeData {
        let calendar = Calendar.current
        
        switch selectedTimeframe {
        case .day:
            let startOfDay = calendar.startOfDay(for: Date())
            let now = Date()
            
            let energySamples = LocalPersistenceManager.shared.fetchSamples(
                typeIdentifier: "HKQuantityTypeIdentifierActiveEnergyBurned",
                from: startOfDay,
                to: now
            )
            
            var hourlyLoad = [Double](repeating: 0.0, count: 24)
            for sample in energySamples {
                let hour = calendar.component(.hour, from: sample.startDate)
                if hour >= 0 && hour < 24 {
                    hourlyLoad[hour] += sample.value
                }
            }
            
            let todayWorkouts = hkManager.timeframeWorkouts.filter { calendar.isDate($0.date, inSameDayAs: now) }
            for w in todayWorkouts {
                let hour = calendar.component(.hour, from: w.date)
                if hour >= 0 && hour < 24 {
                    let maxHR = 190.0
                    let hrRatio = w.averageHeartRate / maxHR
                    let zoneMultiplier: Double
                    if hrRatio >= 0.9 { zoneMultiplier = 5.0 }
                    else if hrRatio >= 0.8 { zoneMultiplier = 4.0 }
                    else if hrRatio >= 0.7 { zoneMultiplier = 3.0 }
                    else if hrRatio >= 0.6 { zoneMultiplier = 2.0 }
                    else { zoneMultiplier = 1.0 }
                    
                    let workoutTRIMP = w.durationMinutes * zoneMultiplier
                    hourlyLoad[hour] += workoutTRIMP * 10.0
                }
            }
            
            var cumulativeLoad = [Double](repeating: 0.0, count: 24)
            var currentLoad = 0.0
            for hour in 0...23 {
                currentLoad += hourlyLoad[hour]
                cumulativeLoad[hour] = currentLoad
            }
            
            let totalLoad = cumulativeLoad[23]
            let targetStrain = strain
            var targetTRIMP = 0.0
            if targetStrain > 0 {
                let clampedStrain = min(20.9, targetStrain)
                targetTRIMP = -log(1.0 - (clampedStrain / 21.0)) / 0.0035
            }
            
            var strainAtHour = [Double](repeating: 0.0, count: 24)
            for hour in 0...23 {
                if totalLoad > 0 {
                    let ratio = cumulativeLoad[hour] / totalLoad
                    let hourlyTRIMP = ratio * targetTRIMP
                    strainAtHour[hour] = PhysiologicalCalculators.calculateStrain(eTRIMP: hourlyTRIMP)
                } else {
                    if hour < 7 {
                        strainAtHour[hour] = 0.0
                    } else if hour > 22 {
                        strainAtHour[hour] = targetStrain
                    } else {
                        let awakeProgress = Double(hour - 7) / 15.0
                        let hourlyTRIMP = awakeProgress * targetTRIMP
                        strainAtHour[hour] = PhysiologicalCalculators.calculateStrain(eTRIMP: hourlyTRIMP)
                    }
                }
            }
            
            let segmentHours = [0, 3, 6, 9, 12, 15, 18, 21]
            let labels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]
            var points: [Double] = []
            for hour in segmentHours {
                points.append(strainAtHour[hour])
            }
            
            return TimeframeData(points: points, labels: labels, average: targetStrain)
            
        case .week:
            let last7 = filteredMetrics
            let points = last7.map { $0.strainScore }
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            let labels = last7.map { formatter.string(from: $0.date) }
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)
            
        case .month:
            let last30 = filteredMetrics
            let points = last30.map { $0.strainScore }
            let labels = ["W1", "W2", "W3", "W4"]
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)
            
        case .year:
            var monthlySums: [Int: Double] = [:]
            var monthlyCounts: [Int: Double] = [:]
            var monthlyDates: [Int: Date] = [:]
            for m in filteredMetrics {
                let month = calendar.component(.month, from: m.date)
                monthlySums[month, default: 0.0] += m.strainScore
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
                                .stroke(Theme.Colors.strainHigh.opacity(0.08), lineWidth: 6)
                                .frame(width: 64, height: 64)
                            
                            Circle()
                                .trim(from: 0.0, to: CGFloat(min(1.0, displayStrain / 21.0)))
                                .stroke(
                                    LinearGradient(colors: [Theme.Colors.strainHigh, Theme.Colors.strainHigh.opacity(0.6)], startPoint: .top, endPoint: .bottom),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .frame(width: 64, height: 64)
                                .rotationEffect(.degrees(-90))
                                .shadow(color: Theme.Colors.strainHigh.opacity(0.3), radius: 4)
                            
                            VStack(spacing: 0) {
                                Text(String(format: "%.1f", displayStrain))
                                    .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Text("/ 21")
                                    .font(Theme.Typography.roundedFont(size: 8, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .frame(width: 64, height: 64)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayStrain >= targetHigh ? "HIGH CARDIO STRAIN" : (displayStrain >= targetLow ? "OPTIMAL STRAIN" : "RESTORATIVE STRAIN"))
                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                .foregroundColor(Theme.Colors.strainHigh)
                            
                            Text("Your cardiovascular strain is measured on a logarithmic intensity curve.")
                                .font(Theme.Typography.roundedFont(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(3)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80, alignment: .leading)
                    .glassCard()
                    .padding(.horizontal)
                    
                    // 1. Predictive Strain Planner Card (Today specific)
                    let prediction = predictedWorkoutMinutes
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TODAY'S PLANNER")
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text("Workout Target Predictor")
                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "hourglass.badge.plus")
                                .font(.title3)
                                .foregroundColor(Theme.Colors.strainLow)
                        }
                        
                        Text(prediction.status)
                            .font(Theme.Typography.roundedFont(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 2)
                        
                        if prediction.zone2 > 0 || prediction.zone4 > 0 {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ZONE 2 (AEROBIC)")
                                        .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                        .foregroundColor(Theme.Colors.sleepLight)
                                    
                                    Text("\(prediction.zone2) mins")
                                        .font(Theme.Typography.valueLabel)
                                        .foregroundColor(.white)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.02))
                                .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ZONE 4 (THRESHOLD)")
                                        .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                        .foregroundColor(Theme.Colors.strainHigh)
                                    
                                    Text("\(prediction.zone4) mins")
                                        .font(Theme.Typography.valueLabel)
                                        .foregroundColor(.white)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.02))
                                .cornerRadius(8)
                            }
                        }
                        
                        Text("Edwards TRIMP values multiply active workout time by physiological zone stress weights (e.g. Zone 4 exercises apply 4x strain multiplier compared to Zone 2's 2x).")
                            .font(Theme.Typography.roundedFont(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // 2. Workout Breakdown Card
                    let totalDuration = hkManager.timeframeWorkouts.reduce(0.0) { $0 + $1.durationMinutes }
                    let totalCalories = hkManager.timeframeWorkouts.reduce(0.0) { $0 + $1.activeEnergyBurned }
                    
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("WORKOUT BREAKDOWN")
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundColor(.white.opacity(0.5))
                                Text(selectedTimeframe == .day ? "Today's Workouts" : (selectedTimeframe == .week ? "Weekly Workout Summary" : (selectedTimeframe == .month ? "Monthly Workout Summary" : "Annual Workout Summary")))
                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "figure.run.square.stack")
                                .font(.title3)
                                .foregroundColor(Theme.Colors.strainHigh)
                        }
                        
                        if hkManager.timeframeWorkouts.isEmpty {
                            Text("No workouts recorded in this timeframe.")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.vertical, 8)
                        } else {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("WORKOUTS")
                                        .font(Theme.Typography.roundedFont(size: 9, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                    Text("\(hkManager.timeframeWorkouts.count)")
                                        .font(Theme.Typography.roundedFont(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("TOTAL TIME")
                                        .font(Theme.Typography.roundedFont(size: 9, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                    Text(formatDuration(totalDuration))
                                        .font(Theme.Typography.roundedFont(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("TOTAL CALORIES")
                                        .font(Theme.Typography.roundedFont(size: 9, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                    Text(String(format: "%.0f kcal", totalCalories))
                                        .font(Theme.Typography.roundedFont(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.vertical, 4)
                            
                            GeometryReader { geometry in
                                HStack(spacing: 2) {
                                    let dists = workoutDistribution
                                    ForEach(dists) { dist in
                                        let width = max(4.0, geometry.size.width * CGFloat(dist.duration / totalDuration) - 2.0)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(dist.color)
                                            .frame(width: width)
                                    }
                                }
                            }
                            .frame(height: 12)
                            .cornerRadius(6)
                            .padding(.vertical, 4)
                            
                            VStack(spacing: 10) {
                                ForEach(workoutDistribution) { dist in
                                    HStack {
                                        Circle()
                                            .fill(dist.color)
                                            .frame(width: 8, height: 8)
                                        
                                        Text(dist.name)
                                            .font(Theme.Typography.roundedFont(size: 13, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        Text("\(dist.count) \(dist.count == 1 ? "session" : "sessions")")
                                            .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                            .foregroundColor(.white.opacity(0.4))
                                        
                                        Spacer().frame(width: 12)
                                        
                                        Text(formatDuration(dist.duration))
                                            .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // Historical Trend Chart
                    let trendData = getStrainData()
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Strain History")
                                .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("Daily Cardiological Load")
                                .font(Theme.Typography.roundedFont(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        CustomLineGraph(
                            points: trendData.points,
                            labels: trendData.labels,
                            lineColor: Theme.Colors.strainHigh,
                            gradientColors: [Theme.Colors.strainHigh.opacity(0.2), .clear],
                            visibleCount: selectedTimeframe == .day ? (Calendar.current.component(.hour, from: Date()) / 3 + 1) : nil
                        )
                            .frame(height: 140)
                            .padding(.vertical, 8)
                        
                        HStack {
                            Text(String(format: "Average: %.1f", trendData.average))
                                .font(Theme.Typography.roundedFont(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text(String(format: "Today: %.1f", strain))
                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                .foregroundColor(Theme.Colors.strainHigh)
                        }
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // Cardio Status Breakdown Table
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Cardiovascular Load Status")
                            .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        let breakdown = cardioStatusBreakdown
                        VStack(spacing: 12) {
                            ForEach(breakdown, id: \.status) { item in
                                CardioBreakdownRow(status: item.status, days: item.days, percentage: item.percentage, color: item.color)
                            }
                        }
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // Heart Rate Zones details card (Recalculating Averages)
                    VStack(alignment: .leading, spacing: 16) {
                        Text(selectedTimeframe == .day ? "Today's Cardio Zones" : (selectedTimeframe == .week ? "Weekly Average Cardio Zones" : (selectedTimeframe == .month ? "Monthly Average Cardio Zones" : "Annual Average Cardio Zones")))
                            .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        let zones = averageDailyZoneDurations
                        VStack(spacing: 12) {
                            HRZoneRowView(zone: 5, range: "90% - 100% (Anaerobic / Max)", duration: "\(zones.z5) min", weight: 5, color: Color.red)
                            HRZoneRowView(zone: 4, range: "80% - 90% (Threshold)", duration: "\(zones.z4) min", weight: 4, color: Color.orange)
                            HRZoneRowView(zone: 3, range: "70% - 80% (Aerobic / Tempo)", duration: "\(zones.z3) min", weight: 3, color: Color.yellow)
                            HRZoneRowView(zone: 2, range: "60% - 70% (Fat Burn / Aerobic)", duration: "\(zones.z2) min", weight: 2, color: Color.green)
                            HRZoneRowView(zone: 1, range: "50% - 60% (Warm Up / Recovery)", duration: "\(zones.z1) min", weight: 1, color: Color.blue)
                        }
                    }
                    .glassCard()
                    .padding(.horizontal)
                    
                    // Algorithm deep dive card
                    VStack(alignment: .leading, spacing: 14) {
                        Button(action: {
                            withAnimation(.spring()) {
                                showAlgorithmDetails.toggle()
                            }
                        }) {
                            HStack {
                                Text("Edwards TRIMP & Log Curve")
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
                                Text("LOGARITHMIC CARDIOVASCULAR INTENSITY")
                                    .font(Theme.Typography.roundedFont(size: 11, weight: .bold))
                                    .foregroundColor(Theme.Colors.strainHigh)
                                
                                Text("Formula:")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Strain = 21.0 × (1.0 - e^(-0.0035 × TRIMP))")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(8)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(6)
                                
                                Text("How it works:")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("1. **Edwards TRIMP (Training Impulse)**: Measures cumulative load by multiplying workout duration by heart rate zone coefficients (multiplier 1x to 5x).\n2. **Log Scaling**: Early activities yield rapid strain progression (a quick jog easily raises strain to 6.0). However, as load accumulates, the marginal strain increases decrease asymptotically. Reaching 20+ strain requires extremely taxing, prolonged threshold workouts to prevent overtraining injuries.")
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
        .navigationTitle("Cardio Strain")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hkManager.fetchWorkoutsForTimeframe(timeframe: selectedTimeframe)
        }
        .onChange(of: selectedTimeframe) { newTimeframe in
            hkManager.fetchWorkoutsForTimeframe(timeframe: newTimeframe)
        }
    }
}
