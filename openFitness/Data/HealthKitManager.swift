import Foundation
import HealthKit
import Combine
import SwiftUI
import SwiftData

// MARK: - Daily Metrics Struct
struct DailyMetrics: Identifiable {
    let id = UUID()
    let date: Date
    let recoveryScore: Int
    let strainScore: Double
    let sleepScore: Int
    let hrv: Double
    let rhr: Double
    let sleepDuration: Double
    let sleepNeeded: Double
    let deepMinutes: Double
    let remMinutes: Double
    let activeCalories: Double
    let averageHR: Double
    let maxHR: Double
    let steps: Int
    let respiratoryRate: Double
    let oxygenSaturation: Double
    let bodyTemperature: Double
}

// MARK: - ECG Waveform Point Struct
struct ECGPoint: Identifiable {
    let id = UUID()
    let timeOffset: Double // in seconds from start
    let voltage: Double    // in millivolts (mV)
}

struct SleepStageSample: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let stage: Int // 0: Awake, 1: Light/Core, 2: REM, 3: Deep
}

struct WorkoutItem: Identifiable {
    let id = UUID()
    let name: String
    let durationMinutes: Double
    let averageHeartRate: Double
    let activeEnergyBurned: Double // kCal
    let strainContribution: Double
    let date: Date
    let distanceMiles: Double?
    let averagePace: String?
}

struct WorkoutHRZone: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let percentage: Double // 0.0 to 1.0
    let color: Color
    let bpmRange: String
}

struct WorkoutDetailInfo {
    let minHeartRate: Double
    let maxHeartRate: Double
    let averageHeartRate: Double
    let heartRateSamples: [Double]
    let recoveryHeartRateSamples: [Double]
    let hrr1Min: Double
    let hrr2Min: Double
    let hrZones: [WorkoutHRZone]
    let distanceMiles: Double?
    let averagePace: String?
    let startTimeString: String
    let endTimeString: String
}

@MainActor
class HealthKitManager: ObservableObject {

    // Singleton used by background tasks and AppDelegate
    static let shared = HealthKitManager()

    // MARK: - Published Properties for SwiftUI Views
    @Published var isAuthorized = false
    
    // Core Metrics
    @Published var todayRecovery: Int = 0
    @Published var todayStrain: Double = 0.0
    @Published var todaySleepScore: Int = 0
    
    @Published var todayHRV: Double = 0.0
    @Published var todayRHR: Double = 0.0
    @Published var todaySleepHours: Double = 0.0
    @Published var todaySleepNeeded: Double = 8.0
    @Published var todayDeepMinutes: Double = 0.0
    @Published var todayRemMinutes: Double = 0.0
    @Published var todayActiveCalories: Double = 0.0
    @Published var todaySteps: Int = 0
    @Published var todayAverageHR: Double = 0.0
    @Published var todayMaxHR: Double = 0.0
    
    // Vitals Monitor Biomarkers
    @Published var todayRespiratoryRate: Double = 0.0
    @Published var todayOxygenSaturation: Double = 0.0
    @Published var todayBodyTemperature: Double = 0.0

    // Body Composition & Fitness
    @Published var todayBodyFatPercentage: Double = 0.0
    @Published var todayVO2Max: Double = 0.0
    @Published var todayBMI: Double = 0.0
    @Published var todayWeight: Double = 0.0
    
    // Stress & Energy
    @Published var todayStressAverage: Int = 0
    @Published var todayStressHighest: Int = 0
    @Published var todayStressLowest: Int = 0
    @Published var energyBank: Int = 0
    @Published var energyBankStart: Int = 0
    @Published var energyBankCharged: Int = 0
    @Published var energyBankDrained: Int = 0
    @Published var energyBankSleepCharge: Int = 0
    @Published var energyBankLastChargedValue: Int = 0
    @Published var yesterdayRecovery: Int = 0
    @Published var yesterdaySleepScore: Int = 0
    @Published var yesterdaySleepHours: Double = 0.0
    @Published var timeframeWorkouts: [WorkoutItem] = []
    @Published var energyBankLastChargedString: String = ""
    @Published var energyBankDescription: String = ""
    @Published var activenessScore: Int = 0
    @Published var isCalibrated: Bool = false
    @Published var isSyncing: Bool = false
    
    @Published var todaySleepStages: [SleepStageSample] = []
    @Published var sleepDataDate: Date = Date()
    @Published var isSleepDataStale: Bool = false
    
    @Published var recentWorkouts: [WorkoutItem] = []
    @Published var recentECGSamples: [RawECG] = []
    
    // Historical metrics array (past 365 days) for charts
    @Published var historicalMetrics: [DailyMetrics] = []
    
    // Historical arrays (last 21 days) for today's baseline calculations
    private var historicalHRV: [Double] = []
    private var historicalRHR: [Double] = []
    
    private var hasRegisteredObservers = false
    private var calculationTask: Task<Void, Never>?
    
    @Published var userAge: Int = 30
    @Published var userBiologicalSex: String = "Unknown"
    @Published var userHeightCm: Double = 175.0
    @Published var userWeightKg: Double = 70.0
    
    init() {
        if HealthKitIngester.shared.isHealthDataAvailable() {
            requestAuthorization()
        }
    }
    
    // MARK: - Authorization
    func requestAuthorization() {
        HealthKitIngester.shared.requestAuthorization { [weak self] (success, _) in
            DispatchQueue.main.async {
                if success {
                    self?.isAuthorized = true
                    self?.registerObserverQueries()
                    self?.fetchUserProfile()
                    self?.fetchAllMetrics()
                } else {
                    self?.isAuthorized = false
                }
            }
        }
    }
    
    // MARK: - Main Query Orchestrator
    func fetchAllMetrics(completion: (() -> Void)? = nil) {
        guard isAuthorized else {
            completion?()
            return
        }
        guard !isSyncing else {
            completion?()
            return
        }
        
        // 1. Sync granular samples from HealthKit to SwiftData store
        syncAllDataFromHealthKit { [weak self] in
            guard let self = self else {
                completion?()
                return
            }
            
            // 2. Fetch session/document types (workouts, ECGs) directly
            let dispatchGroup = DispatchGroup()
            
            dispatchGroup.enter()
            self.fetchActiveEnergyAndWorkouts { dispatchGroup.leave() }
            
            dispatchGroup.enter()
            self.fetchECGSamples { dispatchGroup.leave() }
            
            dispatchGroup.notify(queue: .main) {
                // 3. Load from database and calculate scores
                self.loadMetricsFromLocalStore()
                
                // 4. Load 365-day trend history
                self.fetchHistoricalData {
                    // Check calibration
                    let validDays = self.historicalMetrics.filter { $0.hrv > 0 && $0.rhr > 0 }.count
                    let hasStoredBaseline = UserDefaults.standard.bool(forKey: "hasCalibrated")
                    self.isCalibrated = validDays >= 21 && hasStoredBaseline
                    
                    let profile = UserProfile(
                        age: self.userAge,
                        biologicalSex: self.userBiologicalSex,
                        heightCm: self.userHeightCm,
                        weightKg: self.userWeightKg,
                        sleepNeedHours: self.todaySleepNeeded
                    )
                    
                    if self.isCalibrated, let baseline = PhysiologicalCalculators.getStoredBaseline() {
                        self.activenessScore = PhysiologicalCalculators.calculateActivenessScore(
                            profile: profile,
                            recovery: self.todayRecovery,
                            strain: self.todayStrain,
                            sleepScore: self.todaySleepScore,
                            steps: self.todaySteps,
                            activeCalories: self.todayActiveCalories,
                            todayHRV: self.todayHRV,
                            baselineHRVMean: baseline.hrvMean,
                            baselineHRVStdDev: baseline.hrvStdDev,
                            stressAverage: self.todayStressAverage
                        )
                    }
                    
                    // 5. Cache today's metric in SwiftData DailyMetricEntity
                    let todayStr = self.formatDateString(Date())
                    let todayMetric = DailyMetricEntity(
                        dateString: todayStr,
                        date: Calendar.current.startOfDay(for: Date()),
                        recovery: self.todayRecovery,
                        strain: self.todayStrain,
                        sleepScore: self.todaySleepScore,
                        stressAvg: self.todayStressAverage,
                        steps: self.todaySteps,
                        activeCalories: self.todayActiveCalories,
                        hrv: self.todayHRV,
                        rhr: self.todayRHR,
                        sleepDuration: self.todaySleepHours,
                        respiratoryRate: self.todayRespiratoryRate,
                        oxygenSaturation: self.todayOxygenSaturation,
                        bodyTemperature: self.todayBodyTemperature
                    )
                    LocalPersistenceManager.shared.saveDailyMetric(todayMetric)
                    
                    completion?()
                }
            }
        }
    }
    
    // MARK: - Query Workouts
    private func fetchActiveEnergyAndWorkouts(completion: @escaping () -> Void) {
        HealthKitIngester.shared.fetchRawWorkouts(limit: 5) { [weak self] rawWorkouts in
            guard let self = self else {
                completion()
                return
            }
            
            let workoutsList = rawWorkouts.map { rw in
                WorkoutItem(
                    name: rw.name,
                    durationMinutes: rw.durationMinutes,
                    averageHeartRate: rw.averageHeartRate,
                    activeEnergyBurned: rw.activeCaloriesBurned,
                    strainContribution: rw.durationMinutes * (rw.averageHeartRate > 130 ? 0.3 : 0.1),
                    date: rw.startDate,
                    distanceMiles: rw.distance,
                    averagePace: rw.paceString
                )
            }
            
            DispatchQueue.main.async {
                self.recentWorkouts = workoutsList
                completion()
            }
        }
    }
    
    func fetchWorkoutsForTimeframe(timeframe: Timeframe) {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        switch timeframe {
        case .day:
            startDate = calendar.startOfDay(for: now)
        case .threeDays:
            startDate = calendar.date(byAdding: .day, value: -3, to: now)!
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: now)!
        case .sixMonths:
            startDate = calendar.date(byAdding: .day, value: -180, to: now)!
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now)!
        }
        
        HealthKitIngester.shared.fetchRawWorkouts(from: startDate, to: now) { [weak self] rawWorkouts in
            guard let self = self else { return }
            let mapped = rawWorkouts.map { rw in
                WorkoutItem(
                    name: rw.name,
                    durationMinutes: rw.durationMinutes,
                    averageHeartRate: rw.averageHeartRate,
                    activeEnergyBurned: rw.activeCaloriesBurned,
                    strainContribution: rw.durationMinutes * (rw.averageHeartRate > 130 ? 0.3 : 0.1),
                    date: rw.startDate,
                    distanceMiles: rw.distance,
                    averagePace: rw.paceString
                )
            }
            DispatchQueue.main.async {
                self.timeframeWorkouts = mapped
            }
        }
    }
    
    // MARK: - Query ECGs
    private func fetchECGSamples(completion: @escaping () -> Void) {
        HealthKitIngester.shared.fetchRawECGSamples { [weak self] samples in
            DispatchQueue.main.async {
                self?.recentECGSamples = samples
                completion()
            }
        }
    }
    
    // MARK: - Query ECG Voltage Waveform Points
    func fetchECGVoltageSamples(
        for ecgSample: RawECG,
        completion: @escaping ([ECGPoint]) -> Void
    ) {
        HealthKitIngester.shared.fetchRawECGVoltageSamples(for: ecgSample.id) { voltages in
            // Map raw voltage floats (microvolts) to ECGPoints in millivolts
            let points = voltages.enumerated().map { index, val in
                ECGPoint(timeOffset: Double(index) / 512.0, voltage: Double(val) / 1000.0)
            }
            DispatchQueue.main.async {
                completion(points)
            }
        }
    }
    
    // MARK: - 365-Day Historical Data Engine (Cached via SwiftData)
    func fetchHistoricalData(completion: (() -> Void)? = nil) {
        guard isAuthorized else {
            completion?()
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -365, to: now) else {
            completion?()
            return
        }
        
        // 1. Try loading cached daily metrics from local SwiftData
        let cachedEntities = LocalPersistenceManager.shared.fetchDailyMetrics(from: startDate, to: now)
        let hasStaleEntities = cachedEntities.contains(where: {
            $0.respiratoryRate == nil || $0.oxygenSaturation == nil || $0.bodyTemperature == nil
        })
        
        let yesterdayStr = formatDateString(calendar.date(byAdding: .day, value: -1, to: now)!)
        let hasYesterday = cachedEntities.contains { $0.dateString == yesterdayStr }
        
        if hasStaleEntities {
            LocalPersistenceManager.shared.clearDailyMetricsCache()
        } else if cachedEntities.count >= 21 && hasYesterday {
            var metrics: [DailyMetrics] = []
            for entity in cachedEntities {
                metrics.append(DailyMetrics(
                    date: entity.date,
                    recoveryScore: entity.recovery,
                    strainScore: entity.strain,
                    sleepScore: entity.sleepScore,
                    hrv: entity.hrv ?? 0.0,
                    rhr: entity.rhr ?? 0.0,
                    sleepDuration: entity.sleepDuration ?? 0.0,
                    sleepNeeded: 8.0,
                    deepMinutes: entity.sleepDuration != nil ? 0.0 : 0.0,
                    remMinutes: entity.sleepDuration != nil ? 0.0 : 0.0,
                    activeCalories: entity.activeCalories,
                    averageHR: 0.0,
                    maxHR: 0.0,
                    steps: entity.steps,
                    respiratoryRate: entity.respiratoryRate ?? 0.0,
                    oxygenSaturation: entity.oxygenSaturation ?? 0.0,
                    bodyTemperature: entity.bodyTemperature ?? 0.0
                ))
            }
            self.historicalMetrics = metrics
            completion?()
            return
        }
        
        // 2. Local DB cache is empty: backfill via HealthKit
        let dispatchGroup = DispatchGroup()
        
        var activeCals: [Date: Double] = [:]
        var rhrs: [Date: Double] = [:]
        var hrvs: [Date: Double] = [:]
        var sleep: [Date: (duration: Double, deep: Double, rem: Double)] = [:]
        var workouts: [Date: Double] = [:]
        var hrStats: [Date: (average: Double, max: Double)] = [:]
        var steps: [Date: Double] = [:]
        var respRates: [Date: Double] = [:]
        var oxygenSats: [Date: Double] = [:]
        var bodyTemps: [Date: Double] = [:]
        
        dispatchGroup.enter()
        HealthKitIngester.shared.fetchHistoricalActiveCalories(startDate: startDate) { res in
            activeCals = res
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        HealthKitIngester.shared.fetchHistoricalRHR(startDate: startDate) { res in
            rhrs = res
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        HealthKitIngester.shared.fetchHistoricalHRV(startDate: startDate) { res in
            hrvs = res
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        HealthKitIngester.shared.fetchHistoricalSleep(startDate: startDate) { res in
            sleep = res
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        HealthKitIngester.shared.fetchHistoricalWorkouts(startDate: startDate) { res in
            workouts = res
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        HealthKitIngester.shared.fetchHistoricalHeartRateStats(startDate: startDate) { res in
            hrStats = res
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        HealthKitIngester.shared.fetchHistoricalSum(typeIdentifier: HKQuantityTypeIdentifier.stepCount.rawValue, startDate: startDate) { res in
            steps = res
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        HealthKitIngester.shared.fetchHistoricalAverage(typeIdentifier: HKQuantityTypeIdentifier.respiratoryRate.rawValue, startDate: startDate) { res in
            respRates = res
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        HealthKitIngester.shared.fetchHistoricalAverage(typeIdentifier: HKQuantityTypeIdentifier.oxygenSaturation.rawValue, startDate: startDate) { res in
            oxygenSats = res
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        HealthKitIngester.shared.fetchHistoricalAverage(typeIdentifier: HKQuantityTypeIdentifier.appleSleepingWristTemperature.rawValue, startDate: startDate) { wristRes in
            bodyTemps = wristRes
            HealthKitIngester.shared.fetchHistoricalAverage(typeIdentifier: HKQuantityTypeIdentifier.bodyTemperature.rawValue, startDate: startDate) { bodyRes in
                for (date, val) in bodyRes {
                    if bodyTemps[date] == nil {
                        bodyTemps[date] = val
                    }
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            var metrics: [DailyMetrics] = []
            
            let calendar = Calendar.current
            var sortedDates: [Date] = []
            var curr = calendar.startOfDay(for: startDate)
            let todayStart = calendar.startOfDay(for: now)
            while curr <= todayStart {
                sortedDates.append(curr)
                if let next = calendar.date(byAdding: .day, value: 1, to: curr) {
                    curr = next
                } else {
                    break
                }
            }
            
            var hrvHistory: [Double] = []
            var rhrHistory: [Double] = []
            
            for date in sortedDates {
                let hrvVal = hrvs[date] ?? (hrvHistory.last ?? 0.0)
                let rhrVal = rhrs[date] ?? (rhrHistory.last ?? 0.0)
                let stepsVal = Int(steps[date] ?? 8000.0)
                let rrVal = respRates[date] ?? 16.0
                let spo2Val = oxygenSats[date] ?? 98.0
                let tempVal = bodyTemps[date] ?? 36.5
                
                if hrvVal > 0 { hrvHistory.append(hrvVal) }
                if rhrVal > 0 { rhrHistory.append(rhrVal) }
                
                if hrvHistory.count > 21 { hrvHistory.removeFirst() }
                if rhrHistory.count > 21 { rhrHistory.removeFirst() }
                
                let profile = UserProfile(
                    age: self.userAge,
                    biologicalSex: self.userBiologicalSex,
                    heightCm: self.userHeightCm,
                    weightKg: self.userWeightKg,
                    sleepNeedHours: self.todaySleepNeeded
                )
                
                let recScore = (hrvVal > 0 && rhrVal > 0) ?
                    PhysiologicalCalculators.calculateRecovery(
                        profile: profile,
                        todayHRV: hrvVal,
                        todayRHR: rhrVal,
                        historyHRV: hrvHistory,
                        historyRHR: rhrHistory,
                        storedBaseline: PhysiologicalCalculators.getStoredBaseline()
                    ) : 55
                
                let trimp = workouts[date] ?? 0.0
                let strainScore = PhysiologicalCalculators.calculateStrain(eTRIMP: trimp)
                
                let sleepData = sleep[date] ?? (0.0, 0.0, 0.0)
                
                let hrStat = hrStats[date]
                var avgHRVal = hrStat?.average ?? 0.0
                var maxHRVal = hrStat?.max ?? 0.0
                if avgHRVal <= 0 {
                    avgHRVal = rhrVal > 0 ? rhrVal + 20.0 : 0.0
                }
                if maxHRVal <= 0 {
                    maxHRVal = rhrVal > 0 ? rhrVal + 65.0 : 0.0
                }
                
                let sleepScore = sleepData.duration > 0 ?
                    PhysiologicalCalculators.calculateSleepScore(
                        profile: profile,
                        duration: sleepData.duration,
                        deepMinutes: sleepData.deep,
                        remMinutes: sleepData.rem,
                        dayAverageHR: avgHRVal,
                        sleepAverageHR: rhrVal
                    ) : 0
                
                metrics.append(DailyMetrics(
                    date: date,
                    recoveryScore: recScore,
                    strainScore: strainScore,
                    sleepScore: sleepScore,
                    hrv: hrvVal,
                    rhr: rhrVal,
                    sleepDuration: sleepData.duration,
                    sleepNeeded: 8.0,
                    deepMinutes: sleepData.deep,
                    remMinutes: sleepData.rem,
                    activeCalories: activeCals[date] ?? 0.0,
                    averageHR: avgHRVal,
                    maxHR: maxHRVal,
                    steps: stepsVal,
                    respiratoryRate: rrVal,
                    oxygenSaturation: spo2Val,
                    bodyTemperature: tempVal
                ))
                
                // Cache locally in SwiftData
                let dateStr = self.formatDateString(date)
                let entity = DailyMetricEntity(
                    dateString: dateStr,
                    date: calendar.startOfDay(for: date),
                    recovery: recScore,
                    strain: strainScore,
                    sleepScore: sleepScore,
                    stressAvg: 35,
                    steps: stepsVal,
                    activeCalories: activeCals[date] ?? 0.0,
                    hrv: hrvVal > 0 ? hrvVal : 55.0,
                    rhr: rhrVal > 0 ? rhrVal : 60.0,
                    sleepDuration: sleepData.duration,
                    respiratoryRate: rrVal,
                    oxygenSaturation: spo2Val,
                    bodyTemperature: tempVal
                )
                LocalPersistenceManager.shared.saveDailyMetric(entity)
            }
            
            self.historicalMetrics = metrics
            completion?()
        }
    }
    
    // MARK: - Async fetch wrapper for refreshable
    func fetchAllMetricsAsync() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            fetchAllMetrics {
                continuation.resume()
            }
        }
    }
    
    // MARK: - Workout Details Query
    func fetchWorkoutDetails(for workout: WorkoutItem, completion: @escaping (WorkoutDetailInfo) -> Void) {
        let startDate = workout.date
        let durationSec = workout.durationMinutes * 60.0
        let endDate = startDate.addingTimeInterval(durationSec)
        let queryEndDate = endDate.addingTimeInterval(300) // Query 5 mins post-workout for recovery
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let startTimeStr = timeFormatter.string(from: startDate)
        let endTimeStr = timeFormatter.string(from: endDate)
        
        let maxEstimatedHR = Double(220 - self.userAge)
        
        // 1. Try to load heart rate samples from local SwiftData cache
        let localHRs = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: HKQuantityTypeIdentifier.heartRate.rawValue,
            from: startDate,
            to: queryEndDate
        )
        
        if !localHRs.isEmpty {
            let workoutHRs = localHRs.filter { $0.startDate <= endDate }
            let recoveryHRs = localHRs.filter { $0.startDate > endDate }
            
            let workoutValues = workoutHRs.map { $0.value }
            let recoveryValues = recoveryHRs.map { $0.value }
            
            let avgHR = workoutValues.isEmpty ? workout.averageHeartRate : (workoutValues.reduce(0, +) / Double(workoutValues.count))
            let minHR = workoutValues.isEmpty ? (workout.averageHeartRate > 0 ? workout.averageHeartRate - 10 : 60) : (workoutValues.min() ?? 60.0)
            let maxHR = workoutValues.isEmpty ? (workout.averageHeartRate > 0 ? workout.averageHeartRate + 25 : 150) : (workoutValues.max() ?? 150.0)
            
            let downsampledWorkout = HealthKitManager.downsample(workoutValues.isEmpty ? (workout.averageHeartRate > 0 ? [workout.averageHeartRate] : [120.0]) : workoutValues, to: 30)
            let zones = HealthKitManager.calculateZones(hrValues: workoutValues, maxEstimatedHR: maxEstimatedHR)
            
            let peakHR = maxHR
            var hrr1: Double? = nil
            var hrr2: Double? = nil
            
            if !recoveryHRs.isEmpty {
                let rec1Time = endDate.addingTimeInterval(60)
                let rec2Time = endDate.addingTimeInterval(120)
                
                if let closest1Min = recoveryHRs.min(by: { abs($0.startDate.timeIntervalSince(rec1Time)) < abs($1.startDate.timeIntervalSince(rec1Time)) }) {
                    if abs(closest1Min.startDate.timeIntervalSince(rec1Time)) < 45 {
                        hrr1 = peakHR - closest1Min.value
                    }
                }
                
                if let closest2Min = recoveryHRs.min(by: { abs($0.startDate.timeIntervalSince(rec2Time)) < abs($1.startDate.timeIntervalSince(rec2Time)) }) {
                    if abs(closest2Min.startDate.timeIntervalSince(rec2Time)) < 45 {
                        hrr2 = peakHR - closest2Min.value
                    }
                }
            }
            
            if hrr1 == nil || hrr1! < 0 {
                let baseDrop = 15.0 + (workout.strainContribution * 1.5)
                hrr1 = min(60, max(10, baseDrop + Double.random(in: -3...3)))
            }
            if hrr2 == nil || hrr2! < 0 {
                let baseDrop = 28.0 + (workout.strainContribution * 2.5)
                hrr2 = min(90, max(20, baseDrop + Double.random(in: -4...4)))
            }
            
            var downsampledRecovery: [Double] = []
            if recoveryValues.isEmpty {
                let startVal = workoutValues.last ?? (workout.averageHeartRate > 0 ? workout.averageHeartRate : 130.0)
                let targetVal = minHR > 40 ? minHR : 65.0
                for i in 1...10 {
                    let t = Double(i) / 10.0
                    let val = targetVal + (startVal - targetVal) * exp(-2.2 * t)
                    downsampledRecovery.append(val)
                }
            } else {
                downsampledRecovery = HealthKitManager.downsample(recoveryValues, to: 10)
            }
            
            let detail = WorkoutDetailInfo(
                minHeartRate: minHR,
                maxHeartRate: maxHR,
                averageHeartRate: avgHR,
                heartRateSamples: downsampledWorkout,
                recoveryHeartRateSamples: downsampledRecovery,
                hrr1Min: hrr1 ?? 20.0,
                hrr2Min: hrr2 ?? 35.0,
                hrZones: zones,
                distanceMiles: workout.distanceMiles,
                averagePace: workout.averagePace,
                startTimeString: startTimeStr,
                endTimeString: endTimeStr
            )
            completion(detail)
            return
        }
        
        // 2. Fall back to HealthKit query if local cache is not populated
        HealthKitIngester.shared.fetchRawSamples(
            typeIdentifier: HKQuantityTypeIdentifier.heartRate.rawValue,
            from: startDate,
            to: queryEndDate
        ) { [weak self] rawSamples in
            guard let self = self else { return }
            guard !rawSamples.isEmpty else {
                let detail = self.createDefaultDetailInfo(workout: workout, maxEstimatedHR: maxEstimatedHR, startTimeStr: startTimeStr, endTimeStr: endTimeStr)
                DispatchQueue.main.async { completion(detail) }
                return
            }
            
            let workoutSamples = rawSamples.filter { $0.startDate <= endDate }
            let recoverySamples = rawSamples.filter { $0.startDate > endDate }
            
            let workoutValues = workoutSamples.map { $0.value }
            let recoveryValues = recoverySamples.map { $0.value }
            
            let avgHR = workoutValues.isEmpty ? workout.averageHeartRate : (workoutValues.reduce(0, +) / Double(workoutValues.count))
            let minHR = workoutValues.isEmpty ? (workout.averageHeartRate > 0 ? workout.averageHeartRate - 10 : 60) : (workoutValues.min() ?? 60.0)
            let maxHR = workoutValues.isEmpty ? (workout.averageHeartRate > 0 ? workout.averageHeartRate + 25 : 150) : (workoutValues.max() ?? 150.0)
            
            let downsampledWorkout = HealthKitManager.downsample(workoutValues.isEmpty ? (workout.averageHeartRate > 0 ? [workout.averageHeartRate] : [120.0]) : workoutValues, to: 30)
            let zones = HealthKitManager.calculateZones(hrValues: workoutValues, maxEstimatedHR: maxEstimatedHR)
            
            let peakHR = maxHR
            var hrr1: Double? = nil
            var hrr2: Double? = nil
            
            if !recoverySamples.isEmpty {
                let rec1Time = endDate.addingTimeInterval(60)
                let rec2Time = endDate.addingTimeInterval(120)
                
                if let closest1Min = recoverySamples.min(by: { abs($0.startDate.timeIntervalSince(rec1Time)) < abs($1.startDate.timeIntervalSince(rec1Time)) }) {
                    if abs(closest1Min.startDate.timeIntervalSince(rec1Time)) < 45 {
                        hrr1 = peakHR - closest1Min.value
                    }
                }
                
                if let closest2Min = recoverySamples.min(by: { abs($0.startDate.timeIntervalSince(rec2Time)) < abs($1.startDate.timeIntervalSince(rec2Time)) }) {
                    if abs(closest2Min.startDate.timeIntervalSince(rec2Time)) < 45 {
                        hrr2 = peakHR - closest2Min.value
                    }
                }
            }
            
            if hrr1 == nil || hrr1! < 0 {
                let baseDrop = 15.0 + (workout.strainContribution * 1.5)
                hrr1 = min(60, max(10, baseDrop + Double.random(in: -3...3)))
            }
            if hrr2 == nil || hrr2! < 0 {
                let baseDrop = 28.0 + (workout.strainContribution * 2.5)
                hrr2 = min(90, max(20, baseDrop + Double.random(in: -4...4)))
            }
            
            var downsampledRecovery: [Double] = []
            if recoveryValues.isEmpty {
                let startVal = workoutValues.last ?? (workout.averageHeartRate > 0 ? workout.averageHeartRate : 130.0)
                let targetVal = minHR > 40 ? minHR : 65.0
                for i in 1...10 {
                    let t = Double(i) / 10.0
                    let val = targetVal + (startVal - targetVal) * exp(-2.2 * t)
                    downsampledRecovery.append(val)
                }
            } else {
                downsampledRecovery = HealthKitManager.downsample(recoveryValues, to: 10)
            }
            
            let detail = WorkoutDetailInfo(
                minHeartRate: minHR,
                maxHeartRate: maxHR,
                averageHeartRate: avgHR,
                heartRateSamples: downsampledWorkout,
                recoveryHeartRateSamples: downsampledRecovery,
                hrr1Min: hrr1 ?? 20.0,
                hrr2Min: hrr2 ?? 35.0,
                hrZones: zones,
                distanceMiles: workout.distanceMiles,
                averagePace: workout.averagePace,
                startTimeString: startTimeStr,
                endTimeString: endTimeStr
            )
            
            DispatchQueue.main.async {
                completion(detail)
            }
        }
    }
    
    private func createDefaultDetailInfo(workout: WorkoutItem, maxEstimatedHR: Double, startTimeStr: String, endTimeStr: String) -> WorkoutDetailInfo {
        let zones = HealthKitManager.calculateZones(hrValues: [], maxEstimatedHR: maxEstimatedHR)
        let startVal = workout.averageHeartRate > 0 ? workout.averageHeartRate : 130.0
        let targetVal = 65.0
        var mockRecovery: [Double] = []
        for i in 1...10 {
            let t = Double(i) / 10.0
            let val = targetVal + (startVal - targetVal) * exp(-2.2 * t)
            mockRecovery.append(val)
        }
        
        let base1 = 15.0 + (workout.strainContribution * 1.5)
        let base2 = 28.0 + (workout.strainContribution * 2.5)
        
        return WorkoutDetailInfo(
            minHeartRate: workout.averageHeartRate > 0 ? workout.averageHeartRate - 10 : 60,
            maxHeartRate: workout.averageHeartRate > 0 ? workout.averageHeartRate + 25 : 150,
            averageHeartRate: workout.averageHeartRate > 0 ? workout.averageHeartRate : 120,
            heartRateSamples: workout.averageHeartRate > 0 ? [workout.averageHeartRate-5, workout.averageHeartRate+15, workout.averageHeartRate+5] : [],
            recoveryHeartRateSamples: mockRecovery,
            hrr1Min: min(60, max(10, base1)),
            hrr2Min: min(90, max(20, base2)),
            hrZones: zones,
            distanceMiles: workout.distanceMiles,
            averagePace: workout.averagePace,
            startTimeString: startTimeStr,
            endTimeString: endTimeStr
        )
    }
    
    nonisolated static func downsample(_ values: [Double], to maxPoints: Int) -> [Double] {
        guard values.count > maxPoints else { return values }
        var result: [Double] = []
        let strideValue = Double(values.count) / Double(maxPoints)
        for i in 0..<maxPoints {
            let index = Int(Double(i) * strideValue)
            if index < values.count {
                result.append(values[index])
            }
        }
        return result
    }
    
    @MainActor static func calculateZones(hrValues: [Double], maxEstimatedHR: Double) -> [WorkoutHRZone] {
        let z1Range = (maxEstimatedHR * 0.5)...(maxEstimatedHR * 0.6)
        let z2Range = (maxEstimatedHR * 0.6)...(maxEstimatedHR * 0.7)
        let z3Range = (maxEstimatedHR * 0.7)...(maxEstimatedHR * 0.8)
        let z4Range = (maxEstimatedHR * 0.8)...(maxEstimatedHR * 0.9)
        let z5Range = (maxEstimatedHR * 0.9)...(maxEstimatedHR * 1.1)
        
        let bpmFormatter: (ClosedRange<Double>) -> String = { range in
            "\(Int(range.lowerBound))-\(Int(range.upperBound)) bpm"
        }
        
        guard !hrValues.isEmpty else {
            return [
                WorkoutHRZone(name: "Zone 5: Red Line", percentage: 0.0, color: Theme.Colors.strainHigh, bpmRange: bpmFormatter(z5Range)),
                WorkoutHRZone(name: "Zone 4: Anaerobic", percentage: 0.0, color: Theme.Colors.strainHigh.opacity(0.85), bpmRange: bpmFormatter(z4Range)),
                WorkoutHRZone(name: "Zone 3: Aerobic", percentage: 0.0, color: Theme.Colors.recoveryHigh, bpmRange: bpmFormatter(z3Range)),
                WorkoutHRZone(name: "Zone 2: Temperate", percentage: 0.0, color: Theme.Colors.sleepDeep.opacity(0.85), bpmRange: bpmFormatter(z2Range)),
                WorkoutHRZone(name: "Zone 1: Warm Up", percentage: 0.0, color: Theme.Colors.sleepDeep, bpmRange: bpmFormatter(z1Range))
            ]
        }
        
        var counts = [0.0, 0.0, 0.0, 0.0, 0.0]
        for hr in hrValues {
            if z5Range.contains(hr) {
                counts[4] += 1
            } else if z4Range.contains(hr) {
                counts[3] += 1
            } else if z3Range.contains(hr) {
                counts[2] += 1
            } else if z2Range.contains(hr) {
                counts[1] += 1
            } else if z1Range.contains(hr) {
                counts[0] += 1
            }
        }
        
        let totalSamples = Double(hrValues.count)
        let percentages = counts.map { $0 / totalSamples }
        
        return [
            WorkoutHRZone(name: "Zone 5: Red Line", percentage: percentages[4], color: Theme.Colors.strainHigh, bpmRange: bpmFormatter(z5Range)),
            WorkoutHRZone(name: "Zone 4: Anaerobic", percentage: percentages[3], color: Theme.Colors.strainHigh.opacity(0.85), bpmRange: bpmFormatter(z4Range)),
            WorkoutHRZone(name: "Zone 3: Aerobic", percentage: percentages[2], color: Theme.Colors.recoveryHigh, bpmRange: bpmFormatter(z3Range)),
            WorkoutHRZone(name: "Zone 2: Temperate", percentage: percentages[1], color: Theme.Colors.sleepDeep.opacity(0.85), bpmRange: bpmFormatter(z2Range)),
            WorkoutHRZone(name: "Zone 1: Warm Up", percentage: percentages[0], color: Theme.Colors.sleepDeep, bpmRange: bpmFormatter(z1Range))
        ]
    }
    
    // MARK: - Local Database Sync & Load Layer
    
    private func formatDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func serializeMetadata(_ metadata: [String: Any]) -> [String: Any] {
        var serialized: [String: Any] = [:]
        for (key, val) in metadata {
            if let str = val as? String {
                serialized[key] = str
            } else if let num = val as? NSNumber {
                serialized[key] = num
            } else if let date = val as? Date {
                serialized[key] = ISO8601DateFormatter().string(from: date)
            } else if let quantity = val as? HKQuantity {
                serialized[key] = quantity.description
            } else {
                serialized[key] = String(describing: val)
            }
        }
        return serialized
    }
    
    func syncAllDataFromHealthKit(completion: @escaping () -> Void) {
        guard isAuthorized else {
            completion()
            return
        }
        guard !isSyncing else {
            completion()
            return
        }
        
        self.isSyncing = true
        
        let typesToSync: [String] = [
            "HKCategoryTypeIdentifierSleepAnalysis",
            "HKQuantityTypeIdentifierHeartRate",
            "HKQuantityTypeIdentifierRestingHeartRate",
            "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
            "HKQuantityTypeIdentifierActiveEnergyBurned",
            "HKQuantityTypeIdentifierStepCount",
            "HKQuantityTypeIdentifierRespiratoryRate",
            "HKQuantityTypeIdentifierOxygenSaturation",
            "HKQuantityTypeIdentifierBodyTemperature",
            "HKQuantityTypeIdentifierAppleSleepingWristTemperature",
            "HKQuantityTypeIdentifierBodyFatPercentage",
            "HKQuantityTypeIdentifierVO2Max",
            "HKQuantityTypeIdentifierBodyMassIndex",
            "HKQuantityTypeIdentifierBodyMass"
        ]
        
        let group = DispatchGroup()
        
        for typeId in typesToSync {
            group.enter()
            
            var anchor: HKQueryAnchor? = nil
            if let anchorData = LocalPersistenceManager.shared.getAnchorData(typeIdentifier: typeId) {
                anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: anchorData)
            }
            
            guard let sampleType = getSampleType(for: typeId) else {
                group.leave()
                continue
            }
            
            HealthKitIngester.shared.syncSampleType(sampleType, anchor: anchor) { rawSamples, deletedUUIDs, newAnchor, error in
                if let error = error {
                    print("Error syncing \(typeId): \(error.localizedDescription)")
                } else {
                    let entities = rawSamples.map { rs in
                        var metadataJson: String? = nil
                        if let meta = rs.metadata {
                            if let jsonData = try? JSONSerialization.data(withJSONObject: self.serializeMetadata(meta), options: []),
                               let jsonStr = String(data: jsonData, encoding: .utf8) {
                                metadataJson = jsonStr
                            }
                        }
                        return SampleEntity(
                            uuid: rs.id.uuidString,
                            typeIdentifier: rs.typeIdentifier,
                            startDate: rs.startDate,
                            endDate: rs.endDate,
                            value: rs.value,
                            unitString: rs.unitString,
                            metadataJson: metadataJson,
                            sourceName: rs.sourceName,
                            sourceBundleId: rs.sourceBundleId
                        )
                    }
                    
                    DispatchQueue.main.async {
                        LocalPersistenceManager.shared.saveSamples(entities)
                        LocalPersistenceManager.shared.deleteSamples(withUUIDs: deletedUUIDs)
                        
                        if let newAnchor = newAnchor {
                            if let anchorData = try? NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true) {
                                LocalPersistenceManager.shared.saveAnchor(typeIdentifier: typeId, anchorData: anchorData)
                            }
                        }
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            LocalPersistenceManager.shared.purgeOldData()
            self?.isSyncing = false
            completion()
        }
    }
    
    private func getSampleType(for identifier: String) -> HKSampleType? {
        if let quantityType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: identifier)) {
            return quantityType
        }
        if let categoryType = HKCategoryType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: identifier)) {
            return categoryType
        }
        return nil
    }
    
    private func syncSampleType(_ sampleType: HKSampleType, completion: @escaping () -> Void) {
        let typeId = sampleType.identifier
        
        var anchor: HKQueryAnchor? = nil
        if let anchorData = LocalPersistenceManager.shared.getAnchorData(typeIdentifier: typeId) {
            anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: anchorData)
        }
        
        HealthKitIngester.shared.syncSampleType(sampleType, anchor: anchor) { rawSamples, deletedUUIDs, newAnchor, error in
            if let error = error {
                print("Error syncing observer data for \(typeId): \(error.localizedDescription)")
            } else {
                let entities = rawSamples.map { rs in
                    var metadataJson: String? = nil
                    if let meta = rs.metadata {
                        if let jsonData = try? JSONSerialization.data(withJSONObject: self.serializeMetadata(meta), options: []),
                           let jsonStr = String(data: jsonData, encoding: .utf8) {
                            metadataJson = jsonStr
                        }
                    }
                    return SampleEntity(
                        uuid: rs.id.uuidString,
                        typeIdentifier: rs.typeIdentifier,
                        startDate: rs.startDate,
                        endDate: rs.endDate,
                        value: rs.value,
                        unitString: rs.unitString,
                        metadataJson: metadataJson,
                        sourceName: rs.sourceName,
                        sourceBundleId: rs.sourceBundleId
                    )
                }
                
                DispatchQueue.main.async {
                    LocalPersistenceManager.shared.saveSamples(entities)
                    LocalPersistenceManager.shared.deleteSamples(withUUIDs: deletedUUIDs)
                    
                    if let newAnchor = newAnchor {
                        if let anchorData = try? NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true) {
                            LocalPersistenceManager.shared.saveAnchor(typeIdentifier: typeId, anchorData: anchorData)
                        }
                    }
                }
            }
            completion()
        }
    }
    
    func registerObserverQueries() {
        guard isAuthorized else { return }
        guard !hasRegisteredObservers else { return }
        hasRegisteredObservers = true
        
        HealthKitIngester.shared.registerObserverQueries { [weak self] sampleType, completionHandler in
            guard let self = self else {
                completionHandler()
                return
            }
            
            Task { @MainActor in
                self.syncSampleType(sampleType) {
                    self.scheduleMetricsCalculation()
                    completionHandler()
                }
            }
        }
    }
    
    // MARK: - Debounced Calculations
    func scheduleMetricsCalculation() {
        calculationTask?.cancel()
        calculationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self.loadMetricsFromLocalStore()
        }
    }
    
    // MARK: - User Profile Retrieval
    func fetchUserProfile() {
        guard isAuthorized else { return }
        
        let characteristics = HealthKitIngester.shared.fetchBiologicalCharacteristics()
        self.userAge = characteristics.age
        self.userBiologicalSex = characteristics.biologicalSex
        
        let now = Date()
        let calendar = Calendar.current
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
        
        HealthKitIngester.shared.fetchRawSamples(
            typeIdentifier: HKQuantityTypeIdentifier.height.rawValue,
            from: oneYearAgo,
            to: now
        ) { [weak self] samples in
            if let lastSample = samples.last {
                DispatchQueue.main.async {
                    self?.userHeightCm = lastSample.value
                }
            }
        }
        
        HealthKitIngester.shared.fetchRawSamples(
            typeIdentifier: HKQuantityTypeIdentifier.bodyMass.rawValue,
            from: oneYearAgo,
            to: now
        ) { [weak self] samples in
            if let lastSample = samples.last {
                DispatchQueue.main.async {
                    self?.userWeightKg = lastSample.value
                }
            }
        }
    }
    
    func loadSleepStages(for date: Date) -> [SleepStageSample] {
        let calendar = Calendar.current
        let dayStart = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date))!
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
        let raw = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: HKCategoryTypeIdentifier.sleepAnalysis.rawValue,
            from: dayStart,
            to: dayEnd
        )
        return raw.compactMap { sample in
            let hour = calendar.component(.hour, from: sample.endDate)
            let sleepDay = hour < 12 ? sample.endDate : (calendar.date(byAdding: .day, value: 1, to: sample.endDate) ?? sample.endDate)
            guard calendar.isDate(sleepDay, inSameDayAs: date) else { return nil }
            let val = Int(sample.value)
            let stage: Int
            switch val {
            case 1, 3: stage = 1
            case 4:    stage = 3
            case 5:    stage = 2
            case 2:    stage = 0
            default:   return nil
            }
            return SleepStageSample(startDate: sample.startDate, endDate: sample.endDate, stage: stage)
        }.sorted { $0.startDate < $1.startDate }
    }

    func loadMetricsFromLocalStore() {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        // 1. Today's Sleep (from 7 days ago to now)
        let sleepStart = calendar.date(byAdding: .day, value: -7, to: now)!
        let sleepSamples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: HKCategoryTypeIdentifier.sleepAnalysis.rawValue,
            from: sleepStart,
            to: now
        )
        
        // 2. Today's HRV & RHR (past 21 days for baseline)
        let baselineStart = calendar.date(byAdding: .day, value: -21, to: now)!
        
        let hrvSamples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue,
            from: baselineStart,
            to: now
        )
        
        let rhrSamples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: HKQuantityTypeIdentifier.restingHeartRate.rawValue,
            from: baselineStart,
            to: now
        )
        
        // 3. Today's Active Calories & Steps (querying from yesterday's start of day to cover early-morning wake cycles)
        let calStart = calendar.date(byAdding: .day, value: -1, to: startOfDay)!
        let calSamples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
            from: calStart,
            to: now
        )
        
        let stepSamples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: HKQuantityTypeIdentifier.stepCount.rawValue,
            from: calStart,
            to: now
        )
        
        // 4. Respiratory Rate, Oxygen Saturation, Body Temperature (last 48 hours)
        let vitalsStart = calendar.date(byAdding: .day, value: -2, to: now)!
        
        let rrSamples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: HKQuantityTypeIdentifier.respiratoryRate.rawValue,
            from: vitalsStart,
            to: now
        )
        
        let spo2Samples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: HKQuantityTypeIdentifier.oxygenSaturation.rawValue,
            from: vitalsStart,
            to: now
        )
        
        let wristTempSamples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: HKQuantityTypeIdentifier.appleSleepingWristTemperature.rawValue,
            from: vitalsStart,
            to: now
        )
        let bodyTempSamples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: HKQuantityTypeIdentifier.bodyTemperature.rawValue,
            from: vitalsStart,
            to: now
        )
        let vitalsSamples = rrSamples + spo2Samples + wristTempSamples + bodyTempSamples

        // 5. Body composition & VO2 max — sporadic, look back 90 days for most recent reading
        let bodyCompStart = calendar.date(byAdding: .day, value: -90, to: now)!

        let bodyFatSamples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: "HKQuantityTypeIdentifierBodyFatPercentage",
            from: bodyCompStart, to: now
        )
        self.todayBodyFatPercentage = (bodyFatSamples.last?.value ?? 0.0) * 100.0

        let vo2Samples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: "HKQuantityTypeIdentifierVO2Max",
            from: bodyCompStart, to: now
        )
        self.todayVO2Max = vo2Samples.last?.value ?? 0.0

        let bmiSamples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: "HKQuantityTypeIdentifierBodyMassIndex",
            from: bodyCompStart, to: now
        )
        self.todayBMI = bmiSamples.last?.value ?? 0.0

        let weightSamples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: "HKQuantityTypeIdentifierBodyMass",
            from: bodyCompStart, to: now
        )
        self.todayWeight = weightSamples.last?.value ?? 0.0

        // 6. Today's Heart Rates (Average & Max)
        let hrSamples = LocalPersistenceManager.shared.fetchSamples(
            typeIdentifier: HKQuantityTypeIdentifier.heartRate.rawValue,
            from: startOfDay,
            to: now
        )
        let hrValues = hrSamples.map { $0.value }
        
        // Only today's workouts contribute to today's strain calculation
        let rawWorkouts = self.recentWorkouts
            .filter { $0.date >= startOfDay }
            .map { w in
                RawWorkout(
                    id: w.id,
                    startDate: w.date,
                    endDate: w.date.addingTimeInterval(w.durationMinutes * 60),
                    durationMinutes: w.durationMinutes,
                    activeCaloriesBurned: w.activeEnergyBurned,
                    averageHeartRate: w.averageHeartRate,
                    workoutActivityType: 0,
                    name: w.name
                )
            }
        
        let profile = UserProfile(
            age: self.userAge,
            biologicalSex: self.userBiologicalSex,
            heightCm: self.userHeightCm,
            weightKg: self.userWeightKg,
            sleepNeedHours: self.todaySleepNeeded
        )
        
        let state = AnalysisEngine.shared.calculateTodayMetrics(
            profile: profile,
            now: now,
            sleepSamples: sleepSamples,
            hrvSamples: hrvSamples,
            rhrSamples: rhrSamples,
            calorieSamples: calSamples,
            stepSamples: stepSamples,
            vitalsSamples: vitalsSamples,
            workouts: rawWorkouts,
            storedBaseline: PhysiologicalCalculators.getStoredBaseline()
        )
        
        // Populate Published variables
        self.todayRecovery = state.todayRecovery
        self.todayStrain = state.todayStrain
        self.todaySleepScore = state.todaySleepScore
        self.todayHRV = state.todayHRV
        self.todayRHR = state.todayRHR
        self.todaySleepHours = state.todaySleepHours
        self.todayDeepMinutes = state.todayDeepMinutes
        self.todayRemMinutes = state.todayRemMinutes
        self.todayActiveCalories = state.todayActiveCalories
        self.todaySteps = state.todaySteps
        self.todayRespiratoryRate = state.vitalsRespiratoryRate
        self.todayOxygenSaturation = state.vitalsOxygenSaturation * 100.0
        self.todayBodyTemperature = state.vitalsWristTemperature > 0 ? state.vitalsWristTemperature : state.vitalsBodyTemperature
        self.sleepDataDate = state.sleepDataDate
        self.isSleepDataStale = state.isSleepDataStale
        
        self.todayStressAverage = state.todayStressAverage
        self.todayStressHighest = state.todayStressHighest
        self.todayStressLowest = state.todayStressLowest
        self.energyBank = state.energyBankLevel
        self.energyBankStart = state.energyBankStart
        self.energyBankCharged = state.energyBankCharged
        self.energyBankDrained = state.energyBankDrained
        self.energyBankSleepCharge = state.energyBankSleepCharge
        self.energyBankLastChargedValue = state.energyBankLastChargedValue
        self.energyBankDescription = state.energyBankDescription
        self.yesterdayRecovery = state.yesterdayRecovery
        self.yesterdaySleepScore = state.yesterdaySleepScore
        self.yesterdaySleepHours = state.yesterdaySleepHours
        
        self.todaySleepStages = state.todaySleepStages.map { ss in
            SleepStageSample(startDate: ss.startDate, endDate: ss.endDate, stage: ss.stage)
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let timeStr = formatter.string(from: state.energyBankLastChargedTime)
        self.energyBankLastChargedString = "Last charged to \(state.energyBankLastChargedValue)% at \(timeStr)"
        
        if !hrValues.isEmpty {
            self.todayAverageHR = hrValues.reduce(0.0, +) / Double(hrValues.count)
            self.todayMaxHR = hrValues.max() ?? 0.0
        } else {
            self.todayAverageHR = self.todayRHR > 0 ? self.todayRHR + 20.0 : 72.0
            self.todayMaxHR = self.todayAverageHR > 0 ? self.todayAverageHR + 45.0 : 135.0
        }

        // Write to App Group so the widget always has fresh data
        SharedStore.save(
            activenessScore: self.activenessScore,
            recovery:        self.todayRecovery,
            strain:          self.todayStrain,
            sleep:           self.todaySleepScore,
            steps:           self.todaySteps,
            calories:        self.todayActiveCalories,
            hrv:             self.todayHRV,
            rhr:             self.todayRHR,
            energyBank:      self.energyBank,
            stressAvg:       self.todayStressAverage
        )
    }
}



extension WorkoutItem {
    var iconName: String {
        switch name {
        case "Running": return "figure.run"
        case "Cycling": return "figure.outdoor.cycle"
        case "Swimming": return "figure.pool.swim"
        case "Walking": return "figure.walk"
        case "Strength Training", "Traditional Strength": return "figure.strengthtraining.traditional"
        case "HIIT": return "figure.highintensity.intervaltraining"
        case "Yoga": return "figure.yoga"
        case "Pilates": return "figure.pilates"
        case "Hiking": return "figure.hiking"
        case "Core Training": return "figure.core.training"
        case "Cross Training": return "figure.cross.training"
        case "Elliptical": return "figure.elliptical"
        case "Rowing": return "figure.rower"
        case "Stair Climbing": return "figure.stair.stepper"
        case "Climbing": return "figure.climbing"
        case "Dance": return "figure.dance"
        case "Tennis": return "figure.tennis"
        case "Soccer": return "figure.soccer"
        case "Basketball": return "figure.basketball"
        case "Boxing", "Kickboxing": return "figure.boxing"
        case "Golf": return "figure.golf"
        case "Snowboarding": return "figure.snowboarding"
        case "Skiing": return "figure.skiing.downhill"
        case "Surfing": return "figure.surfing"
        case "Stretching": return "figure.flexibility"
        case "Martial Arts": return "figure.martial.arts"
        case "Cooldown": return "figure.cooldown"
        case "Mixed Cardio": return "figure.mixed.cardio"
        case "Barre": return "figure.barre"
        case "Pickleball", "Badminton", "Squash", "Table Tennis": return "figure.racket"
        case "Volleyball": return "figure.volleyball"
        case "Bowling": return "figure.bowling"
        case "Sailing": return "figure.sailing"
        case "Skating": return "figure.skating"
        case "Fitness Gaming": return "gamecontroller"
        case "Gymnastics": return "figure.gymnastics"
        case "Handball": return "figure.handball"
        default:
            return "figure.cross.training"
        }
    }
    
    var themeColor: Color {
        switch name {
        case "Running", "HIIT": return Color(red: 0.96, green: 0.66, blue: 0.51) // Coral Orange
        case "Cycling": return Color(red: 0.55, green: 0.83, blue: 0.67) // Mint Green
        case "Swimming": return Color(red: 0.58, green: 0.82, blue: 0.92) // Ice Blue
        case "Walking": return Color(red: 0.62, green: 0.85, blue: 0.82) // Teal
        case "Strength Training", "Traditional Strength": return Color(red: 0.96, green: 0.86, blue: 0.60) // Gold
        case "Yoga", "Pilates": return Color(red: 0.75, green: 0.66, blue: 0.86) // Lavender
        case "Hiking": return Color(red: 0.82, green: 0.72, blue: 0.65) // Soft Brown
        case "Climbing": return Color(red: 0.85, green: 0.55, blue: 0.35) // Clay/Brown
        case "Rowing": return Color(red: 0.38, green: 0.65, blue: 0.85) // Sky Blue
        case "Elliptical": return Color(red: 0.65, green: 0.75, blue: 0.85) // Steel Blue
        case "Dance": return Color(red: 0.95, green: 0.45, blue: 0.65) // Pink
        case "Tennis", "Pickleball", "Badminton", "Squash", "Table Tennis": return Color(red: 0.65, green: 0.95, blue: 0.35) // Neon Yellow/Green
        case "Boxing", "Kickboxing": return Color(red: 0.95, green: 0.35, blue: 0.35) // Red
        case "Golf": return Color(red: 0.35, green: 0.85, blue: 0.35) // Forest Green
        case "Snowboarding", "Skiing": return Color(red: 0.90, green: 0.95, blue: 1.0) // Soft White/Blue
        case "Surfing", "Sailing": return Color(red: 0.23, green: 0.51, blue: 0.96) // Soothing Blue
        default:
            return Color(red: 0.94, green: 0.68, blue: 0.78) // Pink/Default
        }
    }
}
