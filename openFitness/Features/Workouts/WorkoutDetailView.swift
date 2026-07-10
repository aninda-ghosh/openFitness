import SwiftUI

struct WorkoutDetailView: View {
    let workout: WorkoutItem
    let hkManager: HealthKitManager
    
    @State private var isLoading = true
    @State private var details: WorkoutDetailInfo? = nil
    @State private var showAlgorithmDetails = false
    
    private var formattedDateString: String {
        let calendar = Calendar.current
        let date = workout.date
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
            AppBackground(accent: workout.themeColor)

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: workout.themeColor))
                        .scaleEffect(1.5)
                    Text("Loading workout data...")
                        .font(Theme.Typography.roundedFont(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            } else if let details = details {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header Banner Card
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(workout.themeColor.opacity(0.12))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Circle()
                                            .stroke(workout.themeColor.opacity(0.3), lineWidth: 1)
                                    )
                                Image(systemName: workout.iconName)
                                    .font(.title3)
                                    .foregroundColor(workout.themeColor)
                                    .shadow(color: workout.themeColor.opacity(0.5), radius: 4, x: 0, y: 2)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.name)
                                    .font(Theme.Typography.roundedFont(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("\(formattedDateString) • \(details.startTimeString) - \(details.endTimeString)")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Details Grid - Flat-with-3D Tactile Cards
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                WorkoutDetailTile(title: "DURATION", value: "\(Int(workout.durationMinutes)) min", icon: "clock.fill", color: Theme.Colors.recoveryHigh)
                                WorkoutDetailTile(title: "CARDIO LOAD (STRAIN)", value: String(format: "+%.1f", workout.strainContribution), icon: "flame.fill", color: workout.themeColor)
                            }
                            
                            HStack(spacing: 12) {
                                WorkoutDetailTile(title: "ENERGY BURNED", value: "\(Int(workout.activeEnergyBurned)) kcal", icon: "bolt.fill", color: Theme.Colors.strainHigh)
                                WorkoutDetailTile(title: "AVG HEART RATE", value: details.averageHeartRate > 0 ? "\(Int(details.averageHeartRate)) bpm" : (workout.averageHeartRate > 0 ? "\(Int(workout.averageHeartRate)) bpm" : "-- bpm"), icon: "waveform.path.ecg", color: Theme.Colors.strainHigh)
                            }
                            
                            if let dist = details.distanceMiles, dist > 0.01 {
                                HStack(spacing: 12) {
                                    WorkoutDetailTile(title: "DISTANCE", value: String(format: "%.2f %@", dist, workout.name == "Swimming" ? "yd" : "mi"), icon: "figure.walk", color: Theme.Colors.sleepDeep)
                                    if let pace = details.averagePace {
                                        WorkoutDetailTile(title: "AVG PACE", value: pace, icon: "speedometer", color: Theme.Colors.sleepDeep)
                                    } else {
                                        WorkoutDetailTile(title: "PEAK HEART RATE", value: details.maxHeartRate > 0 ? "\(Int(details.maxHeartRate)) bpm" : "-- bpm", icon: "arrow.up.heart.fill", color: Theme.Colors.strainHigh)
                                    }
                                }
                            } else if details.maxHeartRate > 0 {
                                HStack(spacing: 12) {
                                    WorkoutDetailTile(title: "PEAK HEART RATE", value: "\(Int(details.maxHeartRate)) bpm", icon: "arrow.up.heart.fill", color: Theme.Colors.strainHigh)
                                    WorkoutDetailTile(title: "MIN HEART RATE", value: details.minHeartRate > 0 ? "\(Int(details.minHeartRate)) bpm" : "-- bpm", icon: "arrow.down.heart.fill", color: Theme.Colors.sleepDeep)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Heart Rate Timeline
                        if !details.heartRateSamples.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("HEART RATE TIMELINE")
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                WorkoutHeartRateGraph(
                                    workoutPoints: details.heartRateSamples,
                                    recoveryPoints: details.recoveryHeartRateSamples,
                                    averageHR: details.averageHeartRate > 0 ? details.averageHeartRate : workout.averageHeartRate,
                                    maxHR: details.maxHeartRate,
                                    minHR: details.minHeartRate,
                                    themeColor: workout.themeColor
                                )
                                .frame(height: 140)
                                .padding(.top, 10)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.4), radius: 6, x: 2, y: 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .padding(.horizontal)
                        }
                        
                        // Heart Rate Recovery Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("HEART RATE RECOVERY (HRR)")
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                                Image(systemName: "heart.text.square.fill")
                                    .foregroundColor(Theme.Colors.recoveryHigh)
                            }
                            
                            Text("Measures how fast your heart rate drops after stopping exertion. A faster recovery indicates high cardiovascular fitness.")
                                .font(Theme.Typography.roundedFont(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .lineSpacing(3)
                            
                            HStack(spacing: 12) {
                                // 1 Min recovery drop
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("1-MIN DROP")
                                        .font(Theme.Typography.tick)
                                        .foregroundColor(.white.opacity(0.4))
                                    
                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        Text(String(format: "-%.0f", details.hrr1Min))
                                            .font(Theme.Typography.roundedFont(size: 24, weight: .bold))
                                            .foregroundColor(Theme.Colors.recoveryHigh)
                                        Text("bpm")
                                            .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    
                                    // Rating pill
                                    Text(details.hrr1Min >= 30 ? "Outstanding" : (details.hrr1Min >= 20 ? "Good" : (details.hrr1Min >= 12 ? "Normal" : "Low")))
                                        .font(Theme.Typography.tick)
                                        .foregroundColor(details.hrr1Min >= 12 ? Theme.Colors.recoveryHigh : Theme.Colors.recoveryLow)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background((details.hrr1Min >= 12 ? Theme.Colors.recoveryHigh : Theme.Colors.recoveryLow).opacity(0.12))
                                        .cornerRadius(4)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.02))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 1))
                                
                                // 2 Min recovery drop
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("2-MIN DROP")
                                        .font(Theme.Typography.tick)
                                        .foregroundColor(.white.opacity(0.4))
                                    
                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        Text(String(format: "-%.0f", details.hrr2Min))
                                            .font(Theme.Typography.roundedFont(size: 24, weight: .bold))
                                            .foregroundColor(Theme.Colors.sleepDeep)
                                        Text("bpm")
                                            .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    
                                    Text(details.hrr2Min >= 45 ? "Outstanding" : (details.hrr2Min >= 30 ? "Good" : (details.hrr2Min >= 22 ? "Normal" : "Low")))
                                        .font(Theme.Typography.tick)
                                        .foregroundColor(details.hrr2Min >= 22 ? Theme.Colors.sleepDeep : Theme.Colors.recoveryLow)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background((details.hrr2Min >= 22 ? Theme.Colors.sleepDeep : Theme.Colors.recoveryLow).opacity(0.12))
                                        .cornerRadius(4)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.02))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.04), lineWidth: 1))
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 2, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .padding(.horizontal)
                        
                        // Heart Rate Zones Breakdown
                        VStack(alignment: .leading, spacing: 14) {
                            Text("HEART RATE ZONES")
                                .font(Theme.Typography.cardTitle)
                                .foregroundColor(.white.opacity(0.5))
                            
                            VStack(spacing: 4) {
                                ForEach(details.hrZones) { zone in
                                    let zoneIdx = details.hrZones.firstIndex(of: zone) ?? 0
                                    WorkoutHRZoneRowView(
                                        zone: 5 - zoneIdx,
                                        name: String(zone.name.dropFirst(8)), // "Zone 5: Red Line" -> "Red Line"
                                        range: zone.bpmRange,
                                        percentage: zone.percentage,
                                        color: zone.color
                                    )
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 2, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .padding(.horizontal)
                        
                        // Scientific Deep Dive Card
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
                                    Text("EDWARDS TRAINING IMPULSE (TRIMP)")
                                        .font(Theme.Typography.roundedFont(size: 11, weight: .bold))
                                        .foregroundColor(workout.themeColor)
                                    
                                    Text("Formula:")
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("TRIMP = Sum(Duration in Zone × Zone Multiplier)\nZone weights: Z1 = 1x, Z2 = 2x, Z3 = 3x, Z4 = 4x, Z5 = 5x\nStrain = 21.0 × (1.0 - e^(-0.0035 × TRIMP))")
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.9))
                                        .padding(8)
                                        .background(Color.black.opacity(0.2))
                                        .cornerRadius(6)
                                    
                                    Text("How it works:")
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("1. **Heart Rate Zones**: Your workout heart rate samples are grouped into five zones based on your maximum heart rate. Higher heart rate zones place higher stress on your cardiovascular system.\n2. **Duration Multiplier**: The time spent in each zone is multiplied by its coefficient (e.g. 1 minute in Zone 5 redline counts as 5 TRIMP points, whereas 1 minute in Zone 1 counts as 1 TRIMP point).\n3. **Daily Cardio Strain**: Daily Cardio Strain uses a logarithmic scale to map cumulative TRIMP load from 0.0 to 21.0. This prevents overtraining by tapering off marginal strain increases during extremely heavy training days.")
                                        .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineSpacing(4)
                                }
                            }
                        }
                        .glassCard()
                        .padding(.horizontal)
                    }
                    .containerRelativeFrame(.horizontal)
                    .padding(.bottom, 30)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Text("Could not load details")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .onAppear {
            hkManager.fetchWorkoutDetails(for: workout) { info in
                self.details = info
                self.isLoading = false
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Workout Components

struct WorkoutDetailTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.footnote)
                Text(title)
                    .font(Theme.Typography.tick)
                    .foregroundColor(.white.opacity(0.4))
            }
            Text(value)
                .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.4), radius: 4, x: 2, y: 3)
        .shadow(color: Color.white.opacity(0.04), radius: 0, x: -1, y: -1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct WorkoutHRZoneRowView: View {
    let zone: Int
    let name: String
    let range: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Text("Z\(zone)")
                .font(Theme.Typography.roundedFont(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 20)
                .background(color.opacity(0.25))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color.opacity(0.4), lineWidth: 0.5)
                )
                .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Theme.Typography.roundedFont(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(range)
                    .font(Theme.Typography.roundedFont(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(percentage))
                        .shadow(color: color.opacity(0.4), radius: 2, x: 0, y: 1)
                }
            }
            .frame(width: 80, height: 6)
            .padding(.trailing, 4)
            
            Text(String(format: "%.0f%%", percentage * 100))
                .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

struct WorkoutHeartRateGraph: View {
    let workoutPoints: [Double]
    let recoveryPoints: [Double]
    let averageHR: Double
    let maxHR: Double
    let minHR: Double
    let themeColor: Color
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let recoveryColor = Color(red: 0.35, green: 0.78, blue: 0.68) // Soothing mint recovery color
                
                let allPoints = workoutPoints + recoveryPoints
                let rawMin = min(minHR, allPoints.min() ?? 80.0)
                let rawMax = max(maxHR, allPoints.max() ?? 180.0)
                let padding = (rawMax - rawMin) * 0.15
                let minVal = max(40, rawMin - padding)
                let maxVal = min(220, rawMax + padding)
                let range = maxVal - minVal > 0 ? maxVal - minVal : 1.0
                
                let yForVal: (Double) -> CGFloat = { val in
                    let pct = CGFloat((val - minVal) / range)
                    return height * (1.0 - pct)
                }
                
                let workoutWidth = width * 0.75
                let recoveryWidth = width * 0.25
                
                let xForWorkoutIdx: (Int) -> CGFloat = { idx in
                    guard workoutPoints.count > 1 else { return 0.0 }
                    return CGFloat(idx) / CGFloat(workoutPoints.count - 1) * workoutWidth
                }
                
                let xForRecoveryIdx: (Int) -> CGFloat = { idx in
                    guard !recoveryPoints.isEmpty else { return workoutWidth }
                    return workoutWidth + (CGFloat(idx + 1) / CGFloat(recoveryPoints.count)) * recoveryWidth
                }
                
                let workoutPath = Path { path in
                    guard workoutPoints.count > 1 else { return }
                    path.move(to: CGPoint(x: xForWorkoutIdx(0), y: yForVal(workoutPoints[0])))
                    for i in 0..<workoutPoints.count - 1 {
                        let p0 = CGPoint(x: xForWorkoutIdx(i), y: yForVal(workoutPoints[i]))
                        let p1 = CGPoint(x: xForWorkoutIdx(i+1), y: yForVal(workoutPoints[i+1]))
                        let cp1 = CGPoint(x: p0.x + (p1.x - p0.x) / 3.0, y: p0.y)
                        let cp2 = CGPoint(x: p0.x + 2.0 * (p1.x - p0.x) / 3.0, y: p1.y)
                        path.addCurve(to: p1, control1: cp1, control2: cp2)
                    }
                }
                
                let workoutFillPath = Path { path in
                    guard workoutPoints.count > 1 else { return }
                    path.move(to: CGPoint(x: xForWorkoutIdx(0), y: height))
                    path.addLine(to: CGPoint(x: xForWorkoutIdx(0), y: yForVal(workoutPoints[0])))
                    for i in 0..<workoutPoints.count - 1 {
                        let p0 = CGPoint(x: xForWorkoutIdx(i), y: yForVal(workoutPoints[i]))
                        let p1 = CGPoint(x: xForWorkoutIdx(i+1), y: yForVal(workoutPoints[i+1]))
                        let cp1 = CGPoint(x: p0.x + (p1.x - p0.x) / 3.0, y: p0.y)
                        let cp2 = CGPoint(x: p0.x + 2.0 * (p1.x - p0.x) / 3.0, y: p1.y)
                        path.addCurve(to: p1, control1: cp1, control2: cp2)
                    }
                    path.addLine(to: CGPoint(x: workoutWidth, y: height))
                    path.closeSubpath()
                }
                
                let recoveryPath = Path { path in
                    guard !recoveryPoints.isEmpty else { return }
                    let startPoint = CGPoint(x: workoutWidth, y: yForVal(workoutPoints.last ?? 120.0))
                    path.move(to: startPoint)
                    var prev = startPoint
                    for j in 0..<recoveryPoints.count {
                        let p = CGPoint(x: xForRecoveryIdx(j), y: yForVal(recoveryPoints[j]))
                        let cp1 = CGPoint(x: prev.x + (p.x - prev.x) / 3.0, y: prev.y)
                        let cp2 = CGPoint(x: prev.x + 2.0 * (p.x - prev.x) / 3.0, y: p.y)
                        path.addCurve(to: p, control1: cp1, control2: cp2)
                        prev = p
                    }
                }
                
                let recoveryFillPath = Path { path in
                    guard !recoveryPoints.isEmpty else { return }
                    path.move(to: CGPoint(x: workoutWidth, y: height))
                    path.addLine(to: CGPoint(x: workoutWidth, y: yForVal(workoutPoints.last ?? 120.0)))
                    var prev = CGPoint(x: workoutWidth, y: yForVal(workoutPoints.last ?? 120.0))
                    for j in 0..<recoveryPoints.count {
                        let p = CGPoint(x: xForRecoveryIdx(j), y: yForVal(recoveryPoints[j]))
                        let cp1 = CGPoint(x: prev.x + (p.x - prev.x) / 3.0, y: prev.y)
                        let cp2 = CGPoint(x: prev.x + 2.0 * (p.x - prev.x) / 3.0, y: p.y)
                        path.addCurve(to: p, control1: cp1, control2: cp2)
                        prev = p
                    }
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                
                ZStack(alignment: .topLeading) {
                    // Grid divisions
                    Path { p in
                        let divisions = 3
                        for i in 1..<divisions {
                            let y = CGFloat(i) / CGFloat(divisions) * height
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: width, y: y))
                        }
                    }
                    .stroke(Color.white.opacity(0.04), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    
                    // Vertical transition divider line
                    Path { p in
                        p.move(to: CGPoint(x: workoutWidth, y: 0))
                        p.addLine(to: CGPoint(x: workoutWidth, y: height))
                    }
                    .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    
                    // Workout area fills
                    workoutFillPath
                        .fill(LinearGradient(
                            colors: [themeColor.opacity(0.2), themeColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                    
                    // Recovery area fills (cooling down to mint/blue)
                    recoveryFillPath
                        .fill(LinearGradient(
                            colors: [recoveryColor.opacity(0.15), recoveryColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                    
                    // Workout line
                    workoutPath
                        .stroke(themeColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .shadow(color: themeColor.opacity(0.3), radius: 3, x: 0, y: 2)
                    
                    // Recovery line
                    recoveryPath
                        .stroke(recoveryColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [1, 0]))
                        .shadow(color: recoveryColor.opacity(0.3), radius: 3, x: 0, y: 2)
                    
                    if averageHR > 0 {
                        let yAvg = yForVal(averageHR)
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: yAvg))
                            p.addLine(to: CGPoint(x: workoutWidth, y: yAvg))
                        }
                        .stroke(themeColor.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                        
                        Text("AVG \(Int(averageHR)) BPM")
                            .font(Theme.Typography.tick)
                            .foregroundColor(themeColor.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(themeColor.opacity(0.2), lineWidth: 0.5))
                            .position(x: 50, y: yAvg - 10)
                    }
                    
                    // Recovery Phase Label at the top right of division
                    Text("RECOVERY")
                        .font(Theme.Typography.tick)
                        .foregroundColor(recoveryColor.opacity(0.7))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(3)
                        .position(x: workoutWidth + 30, y: 12)
                    
                    if let maxIdx = workoutPoints.firstIndex(of: maxHR), workoutPoints.count > 1 {
                        let x = xForWorkoutIdx(maxIdx)
                        let y = yForVal(maxHR)
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(themeColor, lineWidth: 2))
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                            .position(x: x, y: y)
                        
                        Text("MAX \(Int(maxHR))")
                            .font(Theme.Typography.tick)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(themeColor)
                            .cornerRadius(4)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 2)
                            .position(x: x, y: y - 14)
                    }
                    
                    // Check if recovery ends lower
                    if let finalRecovery = recoveryPoints.last, !recoveryPoints.isEmpty {
                        let x = width - 4
                        let y = yForVal(finalRecovery)
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(recoveryColor, lineWidth: 2))
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                            .position(x: x, y: y)
                        
                        Text("REST \(Int(finalRecovery))")
                            .font(Theme.Typography.tick)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(recoveryColor)
                            .cornerRadius(4)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 2)
                            .position(x: x - 10, y: y + 14)
                    }
                }
            }
        }
    }
}
