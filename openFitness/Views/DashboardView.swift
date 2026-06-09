import SwiftUI

private func formatStaleDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
}

struct DashboardView: View {
    @StateObject private var hkManager = HealthKitManager()
    @State private var selectedECG: ECGPoint?
    @State private var showingECGSheet = false
    @State private var showingNoECGAlert = false
    @State private var activeECGPoints: [ECGPoint] = []
    @State private var showingFAQ = false
    
    private var energyBankMessage: String {
        let bank = hkManager.energyBank
        if bank >= 80 {
            return "Your energy is fully charged. Excellent time for a high-intensity workout!"
        } else if bank >= 50 {
            return "Your battery is steady. You can handle moderate training today."
        } else if bank >= 30 {
            return "Energy is depleted. Consider light active recovery or early sleep."
        } else {
            return "Critical exhaustion. Focus entirely on rest and sleep."
        }
    }
    
    private var stressClassification: String {
        let avg = hkManager.todayStressAverage
        if avg == 0 { return "No Data" }
        if avg < 25 { return "Low" }
        if avg < 50 { return "Moderate" }
        if avg < 75 { return "High" }
        return "Extreme"
    }
    
    private var stressColor: Color {
        let avg = hkManager.todayStressAverage
        if avg < 25 { return Theme.Colors.recoveryHigh }
        if avg < 50 { return Theme.Colors.recoveryMid }
        if avg < 75 { return Color.orange }
        return Theme.Colors.recoveryLow
    }
    private var dailySummaryText: String {
        let rec = hkManager.todayRecovery
        let sleep = hkManager.todaySleepScore
        let strain = hkManager.todayStrain
        
        let recStatus = rec >= 80 ? "Fully recovered" : (rec >= 50 ? "Moderately recovered" : "Rest recommended")
        let sleepStatus = sleep >= 80 ? "restful sleep" : (sleep >= 50 ? "decent sleep" : "poor sleep")
        let strainStatus = strain >= 12.0 ? "high activity" : (strain >= 4.0 ? "moderate activity" : "light activity")
        
        return "\(recStatus) after \(sleepStatus) with \(strainStatus) today."
    }
    
    private var energyBankStatusText: String {
        let trend = hkManager.energyBankSleepCharge > 0 ? "Charged +\(hkManager.energyBankSleepCharge)% from sleep." : "No sleep charge logged."
        return "\(trend) Stress average: \(hkManager.todayStressAverage)% • Active burn: \(Int(hkManager.todayActiveCalories)) kcal"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Gradient
                Theme.Colors.background
                    .ignoresSafeArea()
                
                // Subtle fluid color blob behind dashboard
                RadialGradient(
                    colors: [Theme.Colors.sleepDeep.opacity(0.12), .clear],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 400
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("openFitness")
                                .font(Theme.Typography.metricLabel(size: 28))
                                .foregroundColor(.white)

                            Spacer()

                            if hkManager.isSyncing {
                                HStack(spacing: 5) {
                                    ProgressView()
                                        .tint(Theme.Colors.sleepDeep)
                                        .scaleEffect(0.6)
                                        .frame(width: 12, height: 12)
                                    Text("SYNCING...")
                                        .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                        .foregroundColor(Theme.Colors.sleepDeep)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.Colors.sleepDeep.opacity(0.12))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.Colors.sleepDeep.opacity(0.3), lineWidth: 1)
                                )
                            } else {
                                // LIVE / OFFLINE badge
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(hkManager.isAuthorized ? Color.green : Color.red)
                                        .frame(width: 6, height: 6)
                                    Text(hkManager.isAuthorized ? "LIVE" : "OFFLINE")
                                        .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                        .foregroundColor(hkManager.isAuthorized ? Color.green : Color.red)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(hkManager.isAuthorized ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(hkManager.isAuthorized ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                                )
                            }

                            // FAQ button
                            Button(action: { showingFAQ = true }) {
                                Image(systemName: "questionmark.circle")
                                    .font(Theme.Typography.titleSM)
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.leading, 8)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Hero Card: Activeness Score (calibrated) or Stay Active (uncalibrated)
                        if hkManager.isCalibrated {
                            ActivenessScoreCard(hkManager: hkManager)
                            .padding(.horizontal)
                        } else {
                            // Stay Active greeting hero card (Dribbble neon yellow-green style)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "bolt.fill")
                                        .foregroundColor(.black)
                                        .padding(8)
                                        .background(Color.white.opacity(0.35))
                                        .clipShape(Circle())
                                    
                                    Spacer()
                                    
                                    Text("Stay Active")
                                        .font(Theme.Typography.roundedFont(size: 11, weight: .bold))
                                        .foregroundColor(.black.opacity(0.6))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.08))
                                        .cornerRadius(12)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Stay Active")
                                        .font(Theme.Typography.roundedFont(size: 22, weight: .bold))
                                        .foregroundColor(.black)
                                    
                                    Text("Your Daily Boost of Energy")
                                        .font(Theme.Typography.roundedFont(size: 13, weight: .medium))
                                        .foregroundColor(.black.opacity(0.75))
                                }
                                .padding(.top, 4)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Theme.Colors.recoveryHigh,
                                                Theme.Colors.recoveryHigh.opacity(0.8)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .padding(.horizontal)
                        }
                        
                        // Daily Summary Card (Compact)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("DAILY SUMMARY")
                                        .font(Theme.Typography.cardTitle)
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(dailySummaryText)
                                        .font(Theme.Typography.roundedFont(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.4))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "circle.grid.3x3.fill")
                                    .foregroundColor(Theme.Colors.recoveryHigh)
                            }
                            
                            HStack(spacing: 0) {
                                // Ring 1: Recovery
                                NavigationLink(destination: RecoveryDetailView(
                                    hkManager: hkManager,
                                    score: hkManager.todayRecovery,
                                    hrv: hkManager.todayHRV,
                                    rhr: hkManager.todayRHR
                                )) {
                                    CircularGaugeView(
                                        title: "Recovery",
                                        value: "\(hkManager.todayRecovery)%",
                                        progress: Double(hkManager.todayRecovery) / 100.0,
                                        color: Theme.Colors.recoveryHigh
                                    )
                                }
                                .buttonStyle(TactileButtonStyle())
                                
                                Spacer()
                                
                                // Ring 2: Strain
                                NavigationLink(destination: StrainDetailView(
                                    hkManager: hkManager,
                                    strain: hkManager.todayStrain,
                                    targetLow: 7.2,
                                    targetHigh: 12.8,
                                    calories: hkManager.todayActiveCalories,
                                    avgHR: hkManager.todayAverageHR,
                                    workouts: hkManager.recentWorkouts
                                )) {
                                    CircularGaugeView(
                                        title: "Strain",
                                        value: String(format: "%.1f", hkManager.todayStrain),
                                        progress: hkManager.todayStrain / 21.0,
                                        color: Theme.Colors.strainHigh
                                    )
                                }
                                .buttonStyle(TactileButtonStyle())
                                
                                Spacer()
                                
                                // Ring 3: Sleep
                                NavigationLink(destination: SleepDetailView(
                                    hkManager: hkManager,
                                    score: hkManager.todaySleepScore,
                                    duration: hkManager.todaySleepHours,
                                    needed: hkManager.todaySleepNeeded,
                                    deep: hkManager.todayDeepMinutes,
                                    rem: hkManager.todayRemMinutes
                                )) {
                                    CircularGaugeView(
                                        title: "Sleep",
                                        value: "\(hkManager.todaySleepScore)",
                                        progress: Double(hkManager.todaySleepScore) / 100.0,
                                        color: Theme.Colors.sleepDeep,
                                        subtitle: hkManager.isSleepDataStale ? formatStaleDate(hkManager.sleepDataDate) : nil
                                    )
                                }
                                .buttonStyle(TactileButtonStyle())
                            }
                            .padding(.top, 4)
                        }
                        .glassCard()
                        .padding(.horizontal)
                        
                        // Today's Activity Card (Steps & Active Energy)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("TODAY'S ACTIVITY")
                                        .font(Theme.Typography.cardTitle)
                                        .foregroundColor(.white.opacity(0.6))
                                    Text("Tap steps or calories to view trends")
                                        .font(Theme.Typography.roundedFont(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                                Spacer()
                                Image(systemName: "figure.run")
                                    .foregroundColor(Theme.Colors.strainHigh)
                            }
                            
                            HStack(spacing: 20) {
                                // Steps
                                NavigationLink(destination: ActivityDetailView(hkManager: hkManager, initialTab: 0)) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Image(systemName: "shoeprints.fill")
                                                .font(.footnote)
                                                .foregroundColor(Theme.Colors.recoveryHigh)
                                            Text("STEPS")
                                                .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                        
                                        Text("\(hkManager.todaySteps)")
                                            .font(Theme.Typography.roundedFont(size: 22, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        // Progress bar
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.white.opacity(0.06))
                                                
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Theme.Colors.recoveryHigh)
                                                    .frame(width: geo.size.width * CGFloat(min(1.0, Double(hkManager.todaySteps) / 10000.0)))
                                                    .shadow(color: Theme.Colors.recoveryHigh.opacity(0.4), radius: 3, x: 0, y: 1)
                                            }
                                        }
                                        .frame(height: 6)
                                        
                                        Text("Goal: 10,000")
                                            .font(Theme.Typography.tick)
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Active Energy
                                NavigationLink(destination: ActivityDetailView(hkManager: hkManager, initialTab: 1)) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Image(systemName: "flame.fill")
                                                .font(.footnote)
                                                .foregroundColor(Theme.Colors.strainHigh)
                                            Text("ACTIVE ENERGY")
                                                .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                        
                                        Text("\(Int(hkManager.todayActiveCalories)) kcal")
                                            .font(Theme.Typography.roundedFont(size: 22, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        // Progress bar
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.white.opacity(0.06))
                                                
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Theme.Colors.strainHigh)
                                                    .frame(width: geo.size.width * CGFloat(min(1.0, hkManager.todayActiveCalories / 600.0)))
                                                    .shadow(color: Theme.Colors.strainHigh.opacity(0.4), radius: 3, x: 0, y: 1)
                                            }
                                        }
                                        .frame(height: 6)
                                        
                                        Text("Goal: 600 kcal")
                                            .font(Theme.Typography.tick)
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .glassCard()
                        .padding(.horizontal)

                        
                        // Energy Bank Card
                        // Energy Bank Card
                        NavigationLink(destination: EnergyDetailView(hkManager: hkManager)) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("ENERGY BANK")
                                            .font(Theme.Typography.cardTitle)
                                            .foregroundColor(.white.opacity(0.6))
                                        Text(energyBankStatusText)
                                            .font(Theme.Typography.roundedFont(size: 10, weight: .medium))
                                            .foregroundColor(.white.opacity(0.4))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    Text("\(hkManager.energyBank)%")
                                        .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                                        .foregroundColor(Theme.Colors.sleepDeep)
                                }
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.white.opacity(0.06))
                                            .frame(height: 8)
                                        
                                        Capsule()
                                            .fill(LinearGradient(colors: [Theme.Colors.sleepDeep, Theme.Colors.recoveryHigh], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: geo.size.width * CGFloat(hkManager.energyBank) / 100.0, height: 8)
                                    }
                                }
                                .frame(height: 8)
                                
                                let chargeStr = "+\(hkManager.energyBankCharged)%"
                                let drainStr = "-\(hkManager.energyBankDrained)%"
                                let lastTime = hkManager.energyBankLastChargedString.replacingOccurrences(of: "Last charged to ", with: "")
                                let subtext = lastTime.isEmpty ? "\(chargeStr) Charged  •  \(drainStr) Drained" : "\(chargeStr) Charged  •  \(drainStr) Drained  •  \(lastTime)"
                                
                                Text(subtext)
                                    .font(Theme.Typography.roundedFont(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                    .multilineTextAlignment(.leading)
                            }
                            .glassCard()
                            .padding(.horizontal)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Stress & Heart Rate Card
                        NavigationLink(destination: StressHeartRateDetailView(hkManager: hkManager)) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("STRESS & HEART RATE")
                                            .font(Theme.Typography.cardTitle)
                                            .foregroundColor(.white.opacity(0.6))
                                        Text("Tap to view autonomic stress & ECG")
                                            .font(Theme.Typography.roundedFont(size: 10, weight: .medium))
                                            .foregroundColor(.white.opacity(0.35))
                                    }
                                    Spacer()
                                    Image(systemName: "heart.text.square.fill")
                                        .foregroundColor(Theme.Colors.strainHigh)
                                }
                                
                                HStack(alignment: .top, spacing: 16) {
                                    // Stress Gauge Section
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Stress Level")
                                            .font(Theme.Typography.roundedFont(size: 12, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.5))
                                        
                                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                                            Text("\(hkManager.todayStressAverage)%")
                                                .font(Theme.Typography.metricLabel(size: 26))
                                                .foregroundColor(stressColor)
                                            Text(stressClassification)
                                                .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                                                .foregroundColor(stressColor)
                                        }
                                        
                                        // Range Slider
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(Color.white.opacity(0.06))
                                                    .frame(height: 6)
                                                
                                                // Typical range band
                                                let lowPct = CGFloat(hkManager.todayStressLowest) / 100.0
                                                let highPct = CGFloat(hkManager.todayStressHighest) / 100.0
                                                Capsule()
                                                    .fill(stressColor.opacity(0.25))
                                                    .frame(width: max(10, geo.size.width * (highPct - lowPct)), height: 6)
                                                    .offset(x: geo.size.width * lowPct)
                                                
                                                // Current average dot
                                                Circle()
                                                    .fill(stressColor)
                                                    .frame(width: 12, height: 12)
                                                    .offset(x: min(geo.size.width - 12, max(0, geo.size.width * CGFloat(hkManager.todayStressAverage) / 100.0 - 6)), y: -3)
                                            }
                                        }
                                        .frame(height: 12)
                                        
                                        Text("Today's range: \(hkManager.todayStressLowest)% - \(hkManager.todayStressHighest)%")
                                            .font(Theme.Typography.roundedFont(size: 11, weight: .regular))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Divider().background(Color.white.opacity(0.08))
                                    
                                    // Heart Rate details section
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Heart Rate")
                                            .font(Theme.Typography.roundedFont(size: 12, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.5))
                                            .padding(.bottom, 2)
                                        
                                        HStack {
                                            Text("Resting:")
                                                .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                                .foregroundColor(.white.opacity(0.5))
                                            Spacer()
                                            Text(hkManager.todayRHR > 0 ? "\(Int(hkManager.todayRHR)) bpm" : "-- bpm")
                                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        
                                        HStack {
                                            Text("Average:")
                                                .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                                .foregroundColor(.white.opacity(0.5))
                                            Spacer()
                                            Text(hkManager.todayAverageHR > 0 ? "\(Int(hkManager.todayAverageHR)) bpm" : "-- bpm")
                                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        
                                        HStack {
                                            Text("Maximum:")
                                                .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                                .foregroundColor(.white.opacity(0.5))
                                            Spacer()
                                            Text(hkManager.todayMaxHR > 0 ? "\(Int(hkManager.todayMaxHR)) bpm" : "-- bpm")
                                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                                .foregroundColor(Theme.Colors.strainHigh)
                                        }
                                    }
                                    .frame(width: 125)
                                }
                            }
                            .glassCard()
                            .padding(.horizontal)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Vitals Monitor (Biomarkers Grid)
                        VitalsMonitorView(
                            hkManager: hkManager,
                            rhr: hkManager.todayRHR,
                            hrv: hkManager.todayHRV,
                            rr: hkManager.todayRespiratoryRate,
                            spo2: hkManager.todayOxygenSaturation,
                            temp: hkManager.todayBodyTemperature,
                            sleepHours: hkManager.todaySleepHours
                        )

                        // Body Composition & Fitness
                        BodyCompositionView(hkManager: hkManager)

                        // Weekly Workout Patterns Card
                        WorkoutPatternCard(workouts: hkManager.recentWorkouts, hkManager: hkManager)
                        
                        // 4. ECG Samples Card
                        ECGCardView(ecgCount: hkManager.recentECGSamples.count) {
                            if let sample = hkManager.recentECGSamples.first {
                                hkManager.fetchECGVoltageSamples(for: sample) { points in
                                    if points.isEmpty {
                                        self.showingNoECGAlert = true
                                    } else {
                                        self.activeECGPoints = points
                                        self.showingECGSheet = true
                                    }
                                }
                            } else {
                                self.showingNoECGAlert = true
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
                .refreshable {
                    await hkManager.fetchAllMetricsAsync()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingECGSheet) {
                ECGDetailSheet(waveformPoints: activeECGPoints)
            }
            .sheet(isPresented: $showingFAQ) {
                FAQView()
            }
            .alert(isPresented: $showingNoECGAlert) {
                Alert(
                    title: Text("No ECG Data Found"),
                    message: Text("We couldn't find any ECG recordings on your Apple Watch. Take a recording using the ECG app on your Watch and sync it to Apple Health to view it here."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                hkManager.requestAuthorization()
            }
        }
    }
}



// MARK: - ECG Card View
struct ECGCardView: View {
    let ecgCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("ECG / SENSOR WAVEFORMS")
                        .font(Theme.Typography.cardTitle)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(Theme.Colors.recoveryLow)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ecgCount > 0 ? "Recorded Electrocardiogram" : "No ECG Recording Found")
                            .font(Theme.Typography.roundedFont(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(ecgCount > 0 ? "Tap to render recorded voltage wave" : "Take a recording in the Watch ECG app")
                            .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .glassCard()
            .padding(.horizontal)
        }
        .buttonStyle(TactileButtonStyle())
    }
}

// MARK: - Workouts List View
struct WorkoutsListView: View {
    let workouts: [WorkoutItem]
    let hkManager: HealthKitManager
    
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
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT WORKOUTS")
                .font(Theme.Typography.cardTitle)
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal)
            
            if workouts.isEmpty {
                Text("No workouts logged recently")
                    .font(Theme.Typography.roundedFont(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .glassCard()
                    .padding(.horizontal)
            } else {
                ForEach(workouts) { workout in
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
                        .padding(.horizontal)
                    }
                    .buttonStyle(TactileButtonStyle())
                }
            }
        }
    }
}



// MARK: - Vitals Monitor Grid
struct VitalsMonitorView: View {
    @ObservedObject var hkManager: HealthKitManager
    let rhr: Double
    let hrv: Double
    let rr: Double
    let spo2: Double
    let temp: Double
    let sleepHours: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("VITALS MONITOR")
                    .font(Theme.Typography.cardTitle)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(Theme.Colors.recoveryHigh)
            }
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                NavigationLink(destination: RecoveryDetailView(hkManager: hkManager, score: hkManager.todayRecovery, hrv: hkManager.todayHRV, rhr: hkManager.todayRHR, initialTab: 0)) {
                    VitalTileView(
                        title: "Heart Rate Variability",
                        shortTitle: "HRV",
                        value: hrv > 0 ? String(format: "%.0f ms", hrv) : "-- ms",
                        status: hrv == 0 ? "No Data" : (hrv < 40 ? "Low" : (hrv > 75 ? "High" : "Normal")),
                        color: hrv == 0 ? .gray : (hrv < 40 ? Theme.Colors.recoveryLow : (hrv > 75 ? Theme.Colors.recoveryHigh : Theme.Colors.recoveryHigh)),
                        ratio: hrv == 0 ? 0.5 : min(1.0, max(0.0, (hrv - 20) / 80.0)),
                        iconName: "waveform.path.ecg"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: RecoveryDetailView(hkManager: hkManager, score: hkManager.todayRecovery, hrv: hkManager.todayHRV, rhr: hkManager.todayRHR, initialTab: 1)) {
                    VitalTileView(
                        title: "Resting Heart Rate",
                        shortTitle: "RHR",
                        value: rhr > 0 ? String(format: "%.0f bpm", rhr) : "-- bpm",
                        status: rhr == 0 ? "No Data" : (rhr > 75 ? "Elevated" : (rhr < 50 ? "Low" : "Normal")),
                        color: rhr == 0 ? .gray : (rhr > 75 ? Theme.Colors.recoveryLow : (rhr < 50 ? Theme.Colors.recoveryMid : Theme.Colors.recoveryHigh)),
                        ratio: rhr == 0 ? 0.5 : min(1.0, max(0.0, (rhr - 40) / 50.0)),
                        iconName: "heart.fill"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: VitalsDetailView(hkManager: hkManager, type: .respiratoryRate)) {
                    VitalTileView(
                        title: "Respiratory Rate",
                        shortTitle: "RR",
                        value: rr > 0 ? String(format: "%.1f rpm", rr) : "-- rpm",
                        status: rr == 0 ? "No Data" : (rr > 18.0 ? "Higher" : (rr < 12.0 ? "Lower" : "Normal")),
                        color: rr == 0 ? .gray : (rr > 18.0 ? Color.orange : (rr < 12.0 ? Color.blue : Theme.Colors.recoveryHigh)),
                        ratio: rr == 0 ? 0.5 : min(1.0, max(0.0, (rr - 10.0) / 12.0)),
                        iconName: "wind"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: VitalsDetailView(hkManager: hkManager, type: .oxygenSaturation)) {
                    VitalTileView(
                        title: "Oxygen Saturation",
                        shortTitle: "SpO2",
                        value: spo2 > 0 ? String(format: "%.1f%%", spo2) : "--%",
                        status: spo2 == 0 ? "No Data" : (spo2 < 95.0 ? "Lower" : "Optimal"),
                        color: spo2 == 0 ? .gray : (spo2 < 95.0 ? Theme.Colors.recoveryLow : Theme.Colors.recoveryHigh),
                        ratio: spo2 == 0 ? 0.5 : min(1.0, max(0.0, (spo2 - 90.0) / 10.0)),
                        iconName: "lungs.fill"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: VitalsDetailView(hkManager: hkManager, type: .bodyTemperature)) {
                    VitalTileView(
                        title: "Skin Temperature",
                        shortTitle: "Temp",
                        value: temp > 0 ? String(format: "%.1f °C", temp) : "-- °C",
                        status: temp == 0 ? "No Data" : (temp > 37.0 ? "Higher" : (temp < 35.5 ? "Lower" : "Normal")),
                        color: temp == 0 ? .gray : (temp > 37.0 ? Color.orange : (temp < 35.5 ? Color.blue : Theme.Colors.recoveryHigh)),
                        ratio: temp == 0 ? 0.5 : min(1.0, max(0.0, (temp - 35.0) / 3.0)),
                        iconName: "thermometer.medium"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: SleepDetailView(
                    hkManager: hkManager,
                    score: hkManager.todaySleepScore,
                    duration: hkManager.todaySleepHours,
                    needed: hkManager.todaySleepNeeded,
                    deep: hkManager.todayDeepMinutes,
                    rem: hkManager.todayRemMinutes,
                    initialTab: 1
                )) {
                    VitalTileView(
                        title: "Sleep Duration",
                        shortTitle: "Sleep",
                        value: sleepHours > 0 ? formatSleepHours(sleepHours) : "--",
                        status: hkManager.isSleepDataStale ? formatStaleDate(hkManager.sleepDataDate) : (sleepHours == 0 ? "No Data" : (sleepHours < 6.5 ? "Short" : "Normal")),
                        color: sleepHours == 0 ? .gray : (sleepHours < 6.5 ? Theme.Colors.recoveryMid : Theme.Colors.recoveryHigh),
                        ratio: sleepHours == 0 ? 0.5 : min(1.0, max(0.0, (sleepHours - 4.0) / 6.0)),
                        iconName: "bed.double.fill"
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .glassCard()
        .padding(.horizontal)
    }
    
    private func formatSleepHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m)m"
        }
    }
}

// MARK: - Body Composition & Fitness Section
struct BodyCompositionView: View {
    @ObservedObject var hkManager: HealthKitManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("BODY COMPOSITION & FITNESS")
                    .font(Theme.Typography.cardTitle)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Image(systemName: "figure.arms.open")
                    .foregroundColor(Theme.Colors.strainHigh)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                NavigationLink(destination: VitalsDetailView(hkManager: hkManager, type: .bodyFatPercentage)) {
                    let fat = hkManager.todayBodyFatPercentage
                    VitalTileView(
                        title: "Body Fat",
                        shortTitle: "Fat%",
                        value: fat > 0 ? String(format: "%.1f%%", fat) : "--%",
                        status: fat == 0 ? "No Data" : (fat > 32 ? "High" : (fat > 20 ? "Average" : "Fit")),
                        color: fat == 0 ? .gray : (fat > 32 ? Theme.Colors.recoveryLow : (fat > 20 ? Color.orange : Theme.Colors.recoveryHigh)),
                        ratio: fat == 0 ? 0.5 : min(1.0, max(0.0, 1.0 - (fat - 5.0) / 35.0)),
                        iconName: "figure.arms.open"
                    )
                }
                .buttonStyle(PlainButtonStyle())

                NavigationLink(destination: VitalsDetailView(hkManager: hkManager, type: .vo2Max)) {
                    let vo2 = hkManager.todayVO2Max
                    VitalTileView(
                        title: "VO2 Max",
                        shortTitle: "VO2",
                        value: vo2 > 0 ? String(format: "%.1f", vo2) : "--",
                        status: vo2 == 0 ? "No Data" : (vo2 >= 52 ? "Excellent" : (vo2 >= 42 ? "Good" : (vo2 >= 34 ? "Fair" : "Low"))),
                        color: vo2 == 0 ? .gray : (vo2 >= 42 ? Theme.Colors.recoveryHigh : (vo2 >= 34 ? Color.orange : Theme.Colors.recoveryLow)),
                        ratio: vo2 == 0 ? 0.5 : min(1.0, max(0.0, (vo2 - 20.0) / 50.0)),
                        iconName: "lungs.fill"
                    )
                }
                .buttonStyle(PlainButtonStyle())

                NavigationLink(destination: VitalsDetailView(hkManager: hkManager, type: .bmi)) {
                    let bmi = hkManager.todayBMI
                    VitalTileView(
                        title: "BMI",
                        shortTitle: "BMI",
                        value: bmi > 0 ? String(format: "%.1f", bmi) : "--",
                        status: bmi == 0 ? "No Data" : (bmi >= 30 ? "Obese" : (bmi >= 25 ? "Overweight" : (bmi >= 18.5 ? "Normal" : "Underweight"))),
                        color: bmi == 0 ? .gray : (bmi >= 18.5 && bmi < 25 ? Theme.Colors.recoveryHigh : (bmi < 30 ? Color.orange : Theme.Colors.recoveryLow)),
                        ratio: bmi == 0 ? 0.5 : min(1.0, max(0.0, (bmi - 15.0) / 25.0)),
                        iconName: "scalemass.fill"
                    )
                }
                .buttonStyle(PlainButtonStyle())

                NavigationLink(destination: VitalsDetailView(hkManager: hkManager, type: .weight)) {
                    let wt = hkManager.todayWeight
                    VitalTileView(
                        title: "Weight",
                        shortTitle: "kg",
                        value: wt > 0 ? String(format: "%.1f kg", wt) : "-- kg",
                        status: wt == 0 ? "No Data" : "Tracked",
                        color: wt == 0 ? .gray : Theme.Colors.recoveryHigh,
                        ratio: wt == 0 ? 0.5 : min(1.0, max(0.0, (wt - 40.0) / 80.0)),
                        iconName: "scalemass"
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .glassCard()
        .padding(.horizontal)
    }
}

struct VitalTileView: View {
    let title: String
    let shortTitle: String
    let value: String
    let status: String
    let color: Color
    let ratio: CGFloat
    let iconName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(Theme.Typography.labelSM)
                        .foregroundColor(color)
                    
                    Text(shortTitle)
                        .font(Theme.Typography.roundedFont(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                
                Text(status)
                    .font(Theme.Typography.roundedFont(size: 10, weight: .semibold))
                    .foregroundColor(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.12))
                    .cornerRadius(4)
            }
            
            Text(value)
                .font(Theme.Typography.roundedFont(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            // Custom premium indicator slider
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 4)
                    
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: geo.size.width * 0.5, height: 4)
                        .offset(x: geo.size.width * 0.25)
                    
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .shadow(color: color.opacity(0.5), radius: 3)
                        .offset(x: max(0, min(geo.size.width - 8, ratio * geo.size.width - 4)), y: -2)
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .background(Color.white.opacity(0.02))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Circular Gauge View
struct CircularGaugeView: View {
    let title: String
    let value: String
    let progress: Double
    let color: Color
    var subtitle: String? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Soft 3D radial backglow
                Circle()
                    .fill(color.opacity(0.08))
                    .frame(width: 76, height: 76)
                    .blur(radius: 6)
                
                // Base ring shadow
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 8)
                    .frame(width: 76, height: 76)
                    .shadow(color: Color.black.opacity(0.35), radius: 2, x: 1, y: 1)
                
                // Trimmed progress ring with pop shadow
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, max(0.0, progress))))
                    .stroke(
                        AngularGradient(colors: [color.opacity(0.7), color], center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.35), radius: 3, x: 0, y: 2)
                
                Text(value)
                    .font(Theme.Typography.roundedFont(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 2) {
                Text(title.uppercased())
                    .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.tick)
                        .foregroundColor(.white.opacity(0.35))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SheetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationBackground(.ultraThinMaterial)
        } else {
            content.background(Color.black.opacity(0.85))
        }
    }
}

// MARK: - Activeness Score Hero Card
// MARK: - Activeness Score Hero Card
struct ActivenessScoreCard: View {
    @ObservedObject var hkManager: HealthKitManager
    
    private var score: Int { hkManager.activenessScore }
    private var recovery: Int { hkManager.todayRecovery }
    private var strain: Double { hkManager.todayStrain }
    private var sleepScore: Int { hkManager.todaySleepScore }
    private var steps: Int { hkManager.todaySteps }
    private var activeCalories: Double { hkManager.todayActiveCalories }
    private var stressAverage: Int { hkManager.todayStressAverage }
    
    private var classification: (label: String, color: Color) {
        if score >= 80 { return ("Peak Form", Theme.Colors.recoveryHigh) }
        if score >= 60 { return ("Well Balanced", Theme.Colors.sleepDeep) }
        if score >= 40 { return ("Moderate", Theme.Colors.strainHigh) }
        return ("Recovery Needed", Theme.Colors.recoveryLow)
    }
    
    private var sleepPillLabel: String {
        guard hkManager.isSleepDataStale else { return "Sleep" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return "Sleep (\(formatter.string(from: hkManager.sleepDataDate)))"
    }

    // Sub-scores for the pill breakdown (normalized 0–100)
    private var subScores: [(label: String, icon: String, value: Int, color: Color)] {
        let sRecovery = recovery
        let sStrain = Int(round(exp(-0.5 * pow((strain - 11.0) / 4.0, 2)) * 100.0))
        let sSleep = sleepScore
        let sActivity = Int(round((0.6 * min(1.0, Double(steps) / 10000.0) + 0.4 * min(1.0, activeCalories / 600.0)) * 100.0))
        let sStress = max(0, 100 - stressAverage)

        return [
            ("Recovery", "heart.fill", sRecovery, Theme.Colors.recoveryHigh),
            ("Strain", "flame.fill", sStrain, Theme.Colors.strainHigh),
            (sleepPillLabel, "moon.fill", sSleep, Theme.Colors.sleepDeep),
            ("Activity", "figure.run", sActivity, Theme.Colors.recoveryHigh),
            ("Stress", "brain.head.profile", sStress, Theme.Colors.sleepDeep)
        ]
    }
    
    @State private var showingInfo = false

    @ViewBuilder
    private func destinationView(for label: String) -> some View {
        switch label {
        case "Recovery":
            RecoveryDetailView(
                hkManager: hkManager,
                score: hkManager.todayRecovery,
                hrv: hkManager.todayHRV,
                rhr: hkManager.todayRHR
            )
        case "Strain":
            StrainDetailView(
                hkManager: hkManager,
                strain: hkManager.todayStrain,
                targetLow: 7.2,
                targetHigh: 12.8,
                calories: hkManager.todayActiveCalories,
                avgHR: hkManager.todayAverageHR,
                workouts: hkManager.recentWorkouts
            )
        case "Activity":
            ActivityDetailView(hkManager: hkManager, initialTab: 0)
        case "Stress":
            StressHeartRateDetailView(hkManager: hkManager)
        default: // Sleep or Sleep (M/d) when stale
            SleepDetailView(
                hkManager: hkManager,
                score: hkManager.todaySleepScore,
                duration: hkManager.todaySleepHours,
                needed: hkManager.todaySleepNeeded,
                deep: hkManager.todayDeepMinutes,
                rem: hkManager.todayRemMinutes
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Row 1: title + badge + info ──────────────────────────────────
            HStack(spacing: 6) {
                Text("ACTIVENESS SCORE")
                    .font(Theme.Typography.cardTitle)
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize()

                Button(action: { showingInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                if PhysiologicalCalculators.isRecalibrating {
                    HStack(spacing: 3) {
                        Circle().fill(Color.orange).frame(width: 4, height: 4)
                        Text("RECALIBRATING \(PhysiologicalCalculators.recalibrationDaysRemaining)D")
                            .font(Theme.Typography.tick)
                            .foregroundColor(Color.orange.opacity(0.9))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(6)
                } else {
                    HStack(spacing: 3) {
                        Circle().fill(Theme.Colors.recoveryHigh).frame(width: 4, height: 4)
                        Text("CALIBRATED")
                            .font(Theme.Typography.tick)
                            .foregroundColor(Theme.Colors.recoveryHigh.opacity(0.85))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.recoveryHigh.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // ── Row 2: score hero ─────────────────────────────────────────────
            HStack(alignment: .center, spacing: 16) {
                // Large score + label on the left
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(score)")
                        .font(Theme.Typography.metricLabel(size: 52))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(classification.label.uppercased())
                        .font(Theme.Typography.roundedFont(size: 11, weight: .bold))
                        .foregroundColor(classification.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(classification.color.opacity(0.12))
                        .cornerRadius(6)
                }

                Spacer()

                // Arc gauge on the right — decorative accent
                ZStack {
                    ArcShape(startAngle: -210, endAngle: 30, lineWidth: 8)
                        .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 84, height: 84)

                    ArcShape(startAngle: -210, endAngle: -210 + (240 * Double(min(score, 100)) / 100.0), lineWidth: 8)
                        .stroke(
                            AngularGradient(
                                colors: [Theme.Colors.sleepDeep, Theme.Colors.recoveryHigh, Theme.Colors.strainHigh],
                                center: .center,
                                startAngle: .degrees(-210),
                                endAngle: .degrees(30)
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 84, height: 84)
                        .shadow(color: classification.color.opacity(0.4), radius: 5)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(classification.color)
                }
                .frame(width: 84, height: 84)
            }
            .padding(.horizontal, 14)

            // Description
            Text(scoreDescription)
                .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.45))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 14)

            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 14)

            // ── Row 3: sub-score pills ────────────────────────────────────────
            HStack(spacing: 5) {
                ForEach(subScores, id: \.label) { sub in
                    NavigationLink(destination: destinationView(for: sub.label)) {
                        VStack(spacing: 3) {
                            Image(systemName: sub.icon)
                                .font(.system(size: 11))
                                .foregroundColor(sub.color)
                            Text("\(sub.value)%")
                                .font(Theme.Typography.caption)
                                .foregroundColor(.white)
                            Text(sub.label)
                                .font(Theme.Typography.tick)
                                .foregroundColor(.white.opacity(0.45))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            // ── Row 4: History & Trends ───────────────────────────────────────
            NavigationLink(destination: ActivenessDetailView(hkManager: hkManager)) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.recoveryHigh)
                    Text("History & Trends")
                        .font(Theme.Typography.roundedFont(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.recoveryHigh)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.Colors.recoveryHigh.opacity(0.07))
                .cornerRadius(9)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .glassCard()
        .sheet(isPresented: $showingInfo) {
            ActivenessScoreInfoSheet()
        }
    }

    private var scoreDescription: String {
        if score >= 80 {
            return "Your body and activity metrics are firing on all cylinders. Ideal day for peak performance."
        } else if score >= 60 {
            return "Good balance across recovery, training, and sleep. Stay consistent."
        } else if score >= 40 {
            return "Some areas need attention. Check your sub-scores for insights."
        } else {
            return "Your body is signaling for rest. Prioritize sleep and light recovery."
        }
    }
}

// MARK: - Activeness Score Info Sheet
struct ActivenessScoreInfoSheet: View {
    @Environment(\.presentationMode) var presentationMode

    private struct Component {
        let icon: String
        let color: Color
        let label: String
        let weight: Double   // 0–1
        let weightLabel: String
        let detail: String
    }

    private let components: [Component] = [
        Component(icon: "heart.fill",         color: Theme.Colors.recoveryHigh, label: "Recovery",       weight: 0.25, weightLabel: "25%", detail: "HRV and resting heart rate scored against your personal 21-day baseline."),
        Component(icon: "flame.fill",          color: Theme.Colors.strainHigh,   label: "Strain Balance", weight: 0.20, weightLabel: "20%", detail: "Bell-curve centred at strain ~11. Under-training and overtraining both reduce this."),
        Component(icon: "moon.fill",           color: Theme.Colors.sleepDeep,    label: "Sleep Quality",  weight: 0.20, weightLabel: "20%", detail: "Duration, deep sleep, REM, and nocturnal heart-rate dip combined."),
        Component(icon: "figure.run",          color: Theme.Colors.recoveryHigh, label: "Activity",       weight: 0.15, weightLabel: "15%", detail: "Steps to 10k (60%) and active calories to 600 kcal (40%)."),
        Component(icon: "waveform.path.ecg",   color: Theme.Colors.sleepDeep,    label: "HRV Trend",      weight: 0.10, weightLabel: "10%", detail: "Today's HRV vs. your calibrated mean via a sigmoid mapping."),
        Component(icon: "brain.head.profile",  color: Theme.Colors.recoveryMid,  label: "Stress",         weight: 0.10, weightLabel: "10%", detail: "Inverse stress — lower average stress yields a higher sub-score.")
    ]

    private let zones: [(label: String, range: String, color: Color)] = [
        ("Recovery\nNeeded", "<40",   Theme.Colors.recoveryLow),
        ("Moderate",         "40–59", Theme.Colors.strainHigh),
        ("Well\nBalanced",   "60–79", Theme.Colors.sleepDeep),
        ("Peak\nForm",       "≥80",   Theme.Colors.recoveryHigh)
    ]

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Header ──────────────────────────────────────────
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Activeness Score")
                                .font(Theme.Typography.metricLabel(size: 22))
                                .foregroundColor(.white)
                            Text("Weighted blend of six physiological sub-scores")
                                .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        Spacer()
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(Theme.Typography.roundedFont(size: 22, weight: .regular))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }

                    // ── Score zones ──────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SCORE ZONES")
                            .font(Theme.Typography.cardTitle)
                            .foregroundColor(.white.opacity(0.4))

                        // Gradient bar
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(
                                colors: [Theme.Colors.recoveryLow, Theme.Colors.strainHigh,
                                         Theme.Colors.sleepDeep, Theme.Colors.recoveryHigh],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(height: 10)

                        // Zone labels
                        HStack(spacing: 0) {
                            ForEach(zones, id: \.label) { z in
                                VStack(spacing: 3) {
                                    Text(z.label)
                                        .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                        .foregroundColor(z.color)
                                        .multilineTextAlignment(.center)
                                    Text(z.range)
                                        .font(Theme.Typography.tick)
                                        .foregroundColor(.white.opacity(0.35))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))

                    // ── Weight distribution bar ───────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("WEIGHT DISTRIBUTION")
                            .font(Theme.Typography.cardTitle)
                            .foregroundColor(.white.opacity(0.4))

                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                ForEach(components, id: \.label) { c in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(c.color)
                                        .frame(width: max(0, geo.size.width * CGFloat(c.weight) - 2), height: 28)
                                        .overlay(
                                            Text(c.weightLabel)
                                                .font(Theme.Typography.tick)
                                                .foregroundColor(.black.opacity(0.6))
                                        )
                                }
                            }
                        }
                        .frame(height: 28)

                        // Legend dots
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(components, id: \.label) { c in
                                HStack(spacing: 5) {
                                    Circle().fill(c.color).frame(width: 7, height: 7)
                                    Text(c.label)
                                        .font(Theme.Typography.roundedFont(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))

                    // ── Sub-score table ──────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {
                        Text("SUB-SCORES")
                            .font(Theme.Typography.cardTitle)
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.bottom, 10)

                        ForEach(Array(components.enumerated()), id: \.element.label) { idx, c in
                            VStack(spacing: 0) {
                                HStack(alignment: .center, spacing: 12) {
                                    // Icon
                                    ZStack {
                                        Circle()
                                            .fill(c.color.opacity(0.12))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: c.icon)
                                            .font(Theme.Typography.roundedFont(size: 14, weight: .semibold))
                                            .foregroundColor(c.color)
                                    }

                                    // Label + description
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.label)
                                            .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(c.detail)
                                            .font(Theme.Typography.roundedFont(size: 11, weight: .regular))
                                            .foregroundColor(.white.opacity(0.45))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()

                                    // Weight with mini bar
                                    VStack(spacing: 4) {
                                        Text(c.weightLabel)
                                            .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                            .foregroundColor(c.color)
                                        GeometryReader { g in
                                            ZStack(alignment: .leading) {
                                                Capsule().fill(Color.white.opacity(0.06)).frame(height: 3)
                                                Capsule().fill(c.color)
                                                    .frame(width: g.size.width * CGFloat(c.weight / 0.25), height: 3)
                                            }
                                        }
                                        .frame(width: 36, height: 3)
                                    }
                                }
                                .padding(.vertical, 12)

                                if idx < components.count - 1 {
                                    Divider().background(Color.white.opacity(0.05))
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))

                    // ── Calibration note ─────────────────────────────────
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(Theme.Typography.titleSM)
                            .foregroundColor(Theme.Colors.recoveryHigh)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("21-day calibration required")
                                .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text("HRV and resting heart rate need 21+ days to form a statistically meaningful personal baseline before the score unlocks.")
                                .font(Theme.Typography.roundedFont(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .background(Theme.Colors.recoveryHigh.opacity(0.07))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.recoveryHigh.opacity(0.18), lineWidth: 1))
                }
                .padding()
            }
        }
        .modifier(SheetBackgroundModifier())
    }
}

// MARK: - Arc Shape for Gauge
struct ArcShape: Shape {
    let startAngle: Double
    let endAngle: Double
    let lineWidth: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2.0 - lineWidth / 2.0
        path.addArc(center: center,
                    radius: radius,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(endAngle),
                    clockwise: false)
        return path
    }
}

// MARK: - Workout Pattern Card Component
struct WorkoutPatternCard: View {
    let workouts: [WorkoutItem]
    let hkManager: HealthKitManager
    
    private var last7DaysWorkouts: [WorkoutItem] {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return workouts.filter { $0.date >= sevenDaysAgo }
    }
    
    private var totalWorkoutsCount: Int {
        last7DaysWorkouts.count
    }
    
    private var totalDurationMins: Int {
        Int(last7DaysWorkouts.reduce(0.0) { $0 + $1.durationMinutes })
    }
    
    private var totalCaloriesBurned: Int {
        Int(last7DaysWorkouts.reduce(0.0) { $0 + $1.activeEnergyBurned })
    }
    
    private var avgStrain: Double {
        last7DaysWorkouts.isEmpty ? 0.0 : (last7DaysWorkouts.reduce(0.0) { $0 + $1.strainContribution } / Double(last7DaysWorkouts.count))
    }
    
    private var intensityMins: (low: Double, moderate: Double, high: Double) {
        var low = 0.0
        var mod = 0.0
        var high = 0.0
        for w in last7DaysWorkouts {
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
    
    var body: some View {
        NavigationLink(destination: WorkoutAnalysisDetailView(hkManager: hkManager)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WEEKLY WORKOUT PATTERNS")
                            .font(Theme.Typography.cardTitle)
                            .foregroundColor(.white.opacity(0.6))
                        Text(totalWorkoutsCount > 0 
                             ? "\(totalWorkoutsCount) workouts logged • \(totalDurationMins) mins total"
                             : "No workouts logged in the last 7 days")
                            .font(Theme.Typography.roundedFont(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    Spacer()
                    Image(systemName: "figure.run.circle.fill")
                        .foregroundColor(Theme.Colors.strainHigh)
                        .font(.title3)
                }
                
                if totalWorkoutsCount > 0 {
                    // Stat boxes
                    HStack(spacing: 12) {
                        WorkoutMiniStat(title: "AVG STRAIN", value: String(format: "%.1f", avgStrain), color: Theme.Colors.strainHigh)
                        WorkoutMiniStat(title: "CALORIES", value: "\(totalCaloriesBurned) kcal", color: .orange)
                        WorkoutMiniStat(title: "DURATION", value: "\(totalDurationMins)m", color: Theme.Colors.recoveryHigh)
                    }
                    
                    // Intensity distribution
                    let breakdown = intensityMins
                    let totalMins = breakdown.low + breakdown.moderate + breakdown.high
                    if totalMins > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("INTENSITY DISTRIBUTION")
                                .font(Theme.Typography.tick)
                                .foregroundColor(.white.opacity(0.45))
                            
                            GeometryReader { geo in
                                HStack(spacing: 0) {
                                    if breakdown.high > 0 {
                                        Theme.Colors.strainHigh
                                            .frame(width: geo.size.width * CGFloat(breakdown.high / totalMins))
                                    }
                                    if breakdown.moderate > 0 {
                                        Theme.Colors.recoveryHigh
                                            .frame(width: geo.size.width * CGFloat(breakdown.moderate / totalMins))
                                    }
                                    if breakdown.low > 0 {
                                        Theme.Colors.sleepDeep
                                            .frame(width: geo.size.width * CGFloat(breakdown.low / totalMins))
                                    }
                                }
                                .clipShape(Capsule())
                            }
                            .frame(height: 8)
                            
                            HStack(spacing: 12) {
                                if breakdown.high > 0 {
                                    WorkoutIntensityLegend(name: "High", color: Theme.Colors.strainHigh)
                                }
                                if breakdown.moderate > 0 {
                                    WorkoutIntensityLegend(name: "Mod", color: Theme.Colors.recoveryHigh)
                                }
                                if breakdown.low > 0 {
                                    WorkoutIntensityLegend(name: "Low", color: Theme.Colors.sleepDeep)
                                }
                            }
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white.opacity(0.3))
                        Text("Log workouts with Apple Watch to analyze intensity patterns.")
                            .font(Theme.Typography.roundedFont(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .padding(.vertical, 4)
                }
            }
            .glassCard()
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct WorkoutMiniStat: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.Typography.tick)
                .foregroundColor(.white.opacity(0.45))
            Text(value)
                .font(Theme.Typography.roundedFont(size: 14, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
    }
}

struct WorkoutIntensityLegend: View {
    let name: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(name)
                .font(Theme.Typography.tick)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

#Preview {
    DashboardView()
}
