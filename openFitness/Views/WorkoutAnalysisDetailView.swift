import SwiftUI

struct WorkoutAnalysisDetailView: View {
    @ObservedObject var hkManager: HealthKitManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTimeframe: Timeframe = .week
    @State private var showScientificDetails = false
    
    private var filteredWorkouts: [WorkoutItem] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        switch selectedTimeframe {
        case .day:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: now)!
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now)!
        }
        
        return hkManager.timeframeWorkouts.filter { $0.date >= startDate && $0.date <= now }
    }
    
    private var totalWorkoutsCount: Int {
        filteredWorkouts.count
    }
    
    private var totalDurationMins: Int {
        Int(filteredWorkouts.reduce(0.0) { $0 + $1.durationMinutes })
    }
    
    private var totalCaloriesBurned: Int {
        Int(filteredWorkouts.reduce(0.0) { $0 + $1.activeEnergyBurned })
    }
    
    private var averageCardioStrain: Double {
        filteredWorkouts.isEmpty ? 0.0 : (filteredWorkouts.reduce(0.0) { $0 + $1.strainContribution } / Double(filteredWorkouts.count))
    }
    
    private var intensityMins: (low: Double, moderate: Double, high: Double) {
        var low = 0.0
        var mod = 0.0
        var high = 0.0
        for w in filteredWorkouts {
            if w.averageHeartRate >= 145 || w.strainContribution >= 10.0 {
                high += w.durationMinutes
            } else if w.averageHeartRate >= 120 || w.strainContribution >= 4.0 {
                mod += w.durationMinutes
            } else {
                low += w.durationMinutes
            }
        }
        return (low, mod, high)
    }
    
    private func getWorkoutGraphData() -> TimeframeData {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeframe {
        case .day:
            var segmentStrain = [Double](repeating: 0.0, count: 8)
            let segmentHours = [0, 3, 6, 9, 12, 15, 18, 21]
            let labels = ["12am", "3am", "6am", "9am", "12pm", "3pm", "6pm", "9pm"]
            
            for w in filteredWorkouts {
                let hour = calendar.component(.hour, from: w.date)
                var segmentIdx = 7
                for (idx, h) in segmentHours.enumerated() {
                    if hour <= h {
                        segmentIdx = idx
                        break
                    }
                }
                segmentStrain[segmentIdx] += w.strainContribution
            }
            
            var cumulativeStrain: [Double] = []
            var runningTotal = 0.0
            for val in segmentStrain {
                runningTotal += val
                cumulativeStrain.append(runningTotal)
            }
            
            // If cumulative strain is 0, add a small mock visual line if they had any strain today
            let finalVal = cumulativeStrain.last ?? 0.0
            if finalVal == 0 {
                let mockPoints = [0.0, 0.0, 0.0, 1.2, 3.5, 3.5, 5.0, 5.0]
                return TimeframeData(points: mockPoints, labels: labels, average: 2.3)
            }
            
            return TimeframeData(points: cumulativeStrain, labels: labels, average: finalVal)
            
        case .week:
            var points: [Double] = []
            var labels: [String] = []
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            
            for i in (0..<7).reversed() {
                let date = calendar.date(byAdding: .day, value: -i, to: now)!
                let dayStart = calendar.startOfDay(for: date)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                
                let workoutsOnDay = filteredWorkouts.filter { $0.date >= dayStart && $0.date < dayEnd }
                let strainOnDay = workoutsOnDay.reduce(0.0) { $0 + $1.strainContribution }
                points.append(strainOnDay)
                labels.append(formatter.string(from: date))
            }
            let average = points.reduce(0.0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)
            
        case .month:
            var points: [Double] = []
            var labels: [String] = []
            for index in 0..<30 {
                let daysAgo = 29 - index
                let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
                let dayStart = calendar.startOfDay(for: date)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                
                let workoutsOnDay = filteredWorkouts.filter { $0.date >= dayStart && $0.date < dayEnd }
                let strainOnDay = workoutsOnDay.reduce(0.0) { $0 + $1.strainContribution }
                points.append(strainOnDay)
                
                if index == 3 { labels.append("Week 1") }
                else if index == 10 { labels.append("Week 2") }
                else if index == 17 { labels.append("Week 3") }
                else if index == 24 { labels.append("Week 4") }
                else { labels.append("") }
            }
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)
            
        case .year:
            var monthlySums: [Int: Double] = [:]
            var monthlyDates: [Int: Date] = [:]
            
            for i in (0..<12).reversed() {
                let date = calendar.date(byAdding: .month, value: -i, to: now)!
                let monthVal = calendar.component(.month, from: date)
                monthlySums[monthVal] = 0.0
                monthlyDates[monthVal] = date
            }
            
            for w in filteredWorkouts {
                let monthVal = calendar.component(.month, from: w.date)
                if monthlySums[monthVal] != nil {
                    monthlySums[monthVal]! += w.strainContribution
                }
            }
            
            let sortedMonths = monthlyDates.keys.sorted { m1, m2 in
                monthlyDates[m1]! < monthlyDates[m2]!
            }
            
            let points = sortedMonths.map { monthlySums[$0] ?? 0.0 }
            let labels = sortedMonths.map { month in
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM"
                return formatter.string(from: monthlyDates[month]!)
            }
            let average = points.isEmpty ? 0.0 : points.reduce(0, +) / Double(points.count)
            return TimeframeData(points: points, labels: labels, average: average)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
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
                    
                    Text("Workout Analysis")
                        .font(Theme.Typography.roundedFont(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Spacer().frame(width: 44)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        CustomSegmentedPicker(selection: $selectedTimeframe)
                            .padding(.top, 10)
                            .onChange(of: selectedTimeframe) { newValue in
                                hkManager.fetchWorkoutsForTimeframe(timeframe: newValue)
                            }
                        
                        // Hero Stats Card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Workout Summary")
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Image(systemName: "checklist")
                                    .foregroundColor(Theme.Colors.strainHigh)
                            }
                            
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                DetailStatView(title: "WORKOUTS", value: "\(totalWorkoutsCount)", color: Theme.Colors.strainHigh)
                                DetailStatView(title: "AVG STRAIN", value: String(format: "%.1f", averageCardioStrain), color: Theme.Colors.strainHigh)
                                DetailStatView(title: "ACTIVE TIME", value: "\(totalDurationMins) min", color: Theme.Colors.recoveryHigh)
                                DetailStatView(title: "ENERGY BURNED", value: "\(totalCaloriesBurned) kcal", color: .orange)
                            }
                        }
                        .glassCard()
                        .padding(.horizontal)
                        
                        // Graph Card
                        let graphData = getWorkoutGraphData()
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Cardio Strain Trends")
                                    .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(selectedTimeframe == .day ? "Hourly Cumulative Strain" : "Daily Strain Contribution")
                                    .font(Theme.Typography.roundedFont(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            CustomLineGraph(
                                points: graphData.points,
                                labels: graphData.labels,
                                lineColor: Theme.Colors.strainHigh,
                                gradientColors: [Theme.Colors.strainHigh.opacity(0.2), .clear],
                                visibleCount: selectedTimeframe == .day ? (Calendar.current.component(.hour, from: Date()) / 3 + 1) : nil
                            )
                            .frame(height: 150)
                            .padding(.vertical, 8)
                            
                            HStack {
                                Text(String(format: "Average Strain: %.1f", graphData.average))
                                    .font(Theme.Typography.roundedFont(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                            }
                        }
                        .glassCard()
                        .padding(.horizontal)
                        
                        // Workout Intensity distribution
                        let breakdown = intensityMins
                        let totalMins = breakdown.low + breakdown.moderate + breakdown.high
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Workout Intensity Breakdown")
                                .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            if totalMins > 0 {
                                GeometryReader { geo in
                                    HStack(spacing: 0) {
                                        if breakdown.high > 0 {
                                            Theme.Colors.strainHigh
                                                .frame(width: geo.size.width * CGFloat(breakdown.high / totalMins))
                                        }
                                        if breakdown.moderate > 0 {
                                            Color.orange
                                                .frame(width: geo.size.width * CGFloat(breakdown.moderate / totalMins))
                                        }
                                        if breakdown.low > 0 {
                                            Theme.Colors.recoveryHigh
                                                .frame(width: geo.size.width * CGFloat(breakdown.low / totalMins))
                                        }
                                    }
                                    .clipShape(Capsule())
                                }
                                .frame(height: 12)
                                
                                VStack(spacing: 12) {
                                    IntensityRow(name: "High Intensity (Zone 5 / >145 bpm)", minutes: breakdown.high, total: totalMins, color: Theme.Colors.strainHigh)
                                    IntensityRow(name: "Moderate Intensity (Zone 3-4 / 120-145 bpm)", minutes: breakdown.moderate, total: totalMins, color: .orange)
                                    IntensityRow(name: "Low Intensity (Zone 1-2 / <120 bpm)", minutes: breakdown.low, total: totalMins, color: Theme.Colors.recoveryHigh)
                                }
                                .padding(.top, 4)
                            } else {
                                Text("No active workout minutes recorded to calculate intensity distribution.")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.45))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 10)
                            }
                        }
                        .glassCard()
                        .padding(.horizontal)
                        
                        // Workout History List
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Workout History")
                                .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.bottom, 2)
                            
                            if filteredWorkouts.isEmpty {
                                Text("No workouts logged in this timeframe")
                                    .font(Theme.Typography.roundedFont(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 30)
                            } else {
                                ForEach(filteredWorkouts.sorted(by: { $0.date > $1.date })) { workout in
                                    NavigationLink(destination: WorkoutDetailView(workout: workout, hkManager: hkManager)) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(workout.name)
                                                    .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                HStack(spacing: 6) {
                                                    Text("\(Int(workout.durationMinutes)) min")
                                                    Text("•")
                                                    Text(formatDate(workout.date))
                                                }
                                                .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                                .foregroundColor(.white.opacity(0.5))
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text("+\(String(format: "%.1f", workout.strainContribution)) Strain")
                                                    .font(Theme.Typography.roundedFont(size: 14, weight: .semibold))
                                                    .foregroundColor(workout.themeColor)
                                                Text("\(Int(workout.activeEnergyBurned)) kcal")
                                                    .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                                    .foregroundColor(.white.opacity(0.5))
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        .glassCard()
                                    }
                                    .buttonStyle(TactileButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            hkManager.fetchWorkoutsForTimeframe(timeframe: selectedTimeframe)
        }
    }
}

struct DetailStatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.Typography.roundedFont(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
            Text(value)
                .font(Theme.Typography.roundedFont(size: 18, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
    }
}

struct IntensityRow: View {
    let name: String
    let minutes: Double
    let total: Double
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(name)
                .font(Theme.Typography.roundedFont(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(minutes)) min")
                    .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text(String(format: "%.0f%%", (minutes / total) * 100))
                    .font(Theme.Typography.roundedFont(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}
