import Foundation

struct AnalysisSleepStageSample: Identifiable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let stage: Int // 0: Awake, 1: Light/Core, 2: REM, 3: Deep

    init(id: UUID = UUID(), startDate: Date, endDate: Date, stage: Int) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.stage = stage
    }
}

struct CalculatedMetricsState: Sendable {
    let todayRecovery: Int
    let todayStrain: Double
    let todaySleepScore: Int
    let todayStressAverage: Int
    let todayStressHighest: Int
    let todayStressLowest: Int
    let todayHRV: Double
    let todayRHR: Double
    let todayActiveCalories: Double
    let todaySteps: Int
    let todaySleepHours: Double
    let todayDeepMinutes: Double
    let todayRemMinutes: Double
    let todaySleepStages: [AnalysisSleepStageSample]
    
    // Vitals
    let vitalsRespiratoryRate: Double
    let vitalsOxygenSaturation: Double
    let vitalsBodyTemperature: Double
    let vitalsWristTemperature: Double
    
    // Energy Bank
    let energyBankLevel: Int
    let energyBankStart: Int
    let energyBankCharged: Int
    let energyBankDrained: Int
    let energyBankLastChargedTime: Date
    let energyBankLastChargedValue: Int
    let energyBankSleepCharge: Int
    let energyBankDescription: String
    
    // Historical baselines
    let historicalHRV: [Double]
    let historicalRHR: [Double]
    
    // Yesterday's metrics (for early-morning wake cycle calculations)
    let yesterdayRecovery: Int
    let yesterdaySleepScore: Int
    let yesterdaySleepHours: Double
}

final class AnalysisEngine: Sendable {
    static let shared = AnalysisEngine()
    
    private init() {}
    
    func calculateTodayMetrics(
        profile: UserProfile,
        now: Date,
        sleepSamples: [SampleEntity],
        hrvSamples: [SampleEntity],
        rhrSamples: [SampleEntity],
        calorieSamples: [SampleEntity],
        stepSamples: [SampleEntity],
        vitalsSamples: [SampleEntity],
        workouts: [RawWorkout],
        storedBaseline: CalibratedBaseline?
    ) -> CalculatedMetricsState {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let todayStartStr = formatDateString(now)
        
        // 1. Process Sleep Samples (Filtering by wake-up day to match the date)
        let todaySleepSamples = sleepSamples.filter { sample in
            let hour = calendar.component(.hour, from: sample.endDate)
            let sleepDay = hour < 12 ? sample.endDate : (calendar.date(byAdding: .day, value: 1, to: sample.endDate) ?? sample.endDate)
            return calendar.isDate(sleepDay, inSameDayAs: now)
        }
        
        var totalAsleepTime: TimeInterval = 0
        var deepTime: TimeInterval = 0
        var remTime: TimeInterval = 0
        var stageSamples: [AnalysisSleepStageSample] = []
        
        for sample in todaySleepSamples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            let val = Int(sample.value)
            
            switch val {
            case 1, 3: // asleepUnspecified, asleepCore
                totalAsleepTime += duration
                stageSamples.append(AnalysisSleepStageSample(startDate: sample.startDate, endDate: sample.endDate, stage: 1))
            case 4: // asleepDeep
                totalAsleepTime += duration
                deepTime += duration
                stageSamples.append(AnalysisSleepStageSample(startDate: sample.startDate, endDate: sample.endDate, stage: 3))
            case 5: // asleepREM
                totalAsleepTime += duration
                remTime += duration
                stageSamples.append(AnalysisSleepStageSample(startDate: sample.startDate, endDate: sample.endDate, stage: 2))
            case 2: // awake
                stageSamples.append(AnalysisSleepStageSample(startDate: sample.startDate, endDate: sample.endDate, stage: 0))
            default: // e.g. 0 (inBed)
                break
            }
        }
        
        let todaySleepHours = totalAsleepTime / 3600.0
        let todayDeepMinutes = deepTime / 60.0
        let todayRemMinutes = remTime / 60.0
        let todaySleepStages = stageSamples.sorted(by: { $0.startDate < $1.startDate })
        
        // Process Yesterday's Sleep Samples (for early morning fallback calculations)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let yesterdaySleepSamples = sleepSamples.filter { sample in
            let hour = calendar.component(.hour, from: sample.endDate)
            let sleepDay = hour < 12 ? sample.endDate : (calendar.date(byAdding: .day, value: 1, to: sample.endDate) ?? sample.endDate)
            return calendar.isDate(sleepDay, inSameDayAs: yesterday)
        }
        
        var yesterdayTotalAsleep: TimeInterval = 0
        var yesterdayDeep: TimeInterval = 0
        var yesterdayRem: TimeInterval = 0
        
        for sample in yesterdaySleepSamples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            let val = Int(sample.value)
            switch val {
            case 1, 3:
                yesterdayTotalAsleep += duration
            case 4:
                yesterdayTotalAsleep += duration
                yesterdayDeep += duration
            case 5:
                yesterdayTotalAsleep += duration
                yesterdayRem += duration
            default:
                break
            }
        }
        
        let yesterdaySleepHours = yesterdayTotalAsleep / 3600.0
        let yesterdayDeepMinutes = yesterdayDeep / 60.0
        let yesterdayRemMinutes = yesterdayRem / 60.0
        
        // 2. Process Sleep Windows and HRV Baseline
        let sleepSamplesByWakeUp = Dictionary(grouping: sleepSamples) { sample -> String in
            let hour = calendar.component(.hour, from: sample.endDate)
            let sleepDay = hour < 12 ? sample.endDate : (calendar.date(byAdding: .day, value: 1, to: sample.endDate) ?? sample.endDate)
            return formatDateString(sleepDay)
        }
        
        var baselineSleepWindows: [String: (start: Date, end: Date)] = [:]
        for (dateStr, samples) in sleepSamplesByWakeUp {
            let asleep = samples.filter { $0.value > 0 } // Stage > 0 (Core/REM/Deep)
            guard !asleep.isEmpty else { continue }
            let sStart = asleep.map { $0.startDate }.min()
            let sEnd = asleep.map { $0.endDate }.max()
            if let start = sStart, let end = sEnd {
                baselineSleepWindows[dateStr] = (start: start, end: end)
            }
        }
        
        // Group HRV by day
        let hrvByDay = Dictionary(grouping: hrvSamples) { sample -> String in
            formatDateString(sample.startDate)
        }
        
        var dailyHRVMap: [String: Double] = [:]
        for (dateStr, samples) in hrvByDay {
            if dateStr == todayStartStr { continue }
            
            if let window = baselineSleepWindows[dateStr] {
                let sleepHRVSamples = samples.filter { $0.startDate >= window.start && $0.startDate <= window.end }
                if !sleepHRVSamples.isEmpty {
                    let avg = sleepHRVSamples.reduce(0.0) { $0 + $1.value } / Double(sleepHRVSamples.count)
                    dailyHRVMap[dateStr] = avg
                    continue
                }
            }
            let avg = samples.reduce(0.0) { $0 + $1.value } / Double(samples.count)
            dailyHRVMap[dateStr] = avg
        }
        let sortedHRVDays = dailyHRVMap.keys.sorted()
        var historicalHRV = sortedHRVDays.map { dailyHRVMap[$0]! }
        
        // Today's HRV calculation
        let hrvSamplesToday = hrvSamples.filter { formatDateString($0.startDate) == todayStartStr }
        var todaySleepStart: Date? = nil
        var todaySleepEnd: Date? = nil
        if let firstStage = todaySleepStages.first {
            todaySleepStart = firstStage.startDate
        }
        if let lastStage = todaySleepStages.last {
            todaySleepEnd = lastStage.endDate
        }
        
        let todaySleepHRV: [SampleEntity]
        if let start = todaySleepStart, let end = todaySleepEnd {
            todaySleepHRV = hrvSamplesToday.filter { $0.startDate >= start && $0.startDate <= end }
        } else {
            todaySleepHRV = []
        }
        
        let todayHRV: Double
        if !todaySleepHRV.isEmpty {
            todayHRV = todaySleepHRV.reduce(0.0) { $0 + $1.value } / Double(todaySleepHRV.count)
        } else if !hrvSamplesToday.isEmpty {
            todayHRV = hrvSamplesToday.reduce(0.0) { $0 + $1.value } / Double(hrvSamplesToday.count)
        } else {
            let defaultHRV = max(30.0, min(90.0, 100.0 - Double(profile.age)))
            todayHRV = historicalHRV.last ?? defaultHRV
        }
        historicalHRV.append(todayHRV)
        
        // 3. Process RHR Baseline
        let rhrByDay = Dictionary(grouping: rhrSamples) { sample -> String in
            formatDateString(sample.startDate)
        }
        
        var dailyRHRMap: [String: Double] = [:]
        for (dateStr, samples) in rhrByDay {
            if dateStr == todayStartStr { continue }
            let avg = samples.reduce(0.0) { $0 + $1.value } / Double(samples.count)
            dailyRHRMap[dateStr] = avg
        }
        let sortedRHRDays = dailyRHRMap.keys.sorted()
        var historicalRHR = sortedRHRDays.map { dailyRHRMap[$0]! }
        
        let todayRhrSamples = rhrSamples.filter { formatDateString($0.startDate) == todayStartStr }
        let todayRHR: Double
        if !todayRhrSamples.isEmpty {
            todayRHR = todayRhrSamples.reduce(0.0) { $0 + $1.value } / Double(todayRhrSamples.count)
        } else {
            let defaultRHR = profile.biologicalSex == "Female" ? 65.0 : 60.0
            todayRHR = historicalRHR.last ?? defaultRHR
        }
        historicalRHR.append(todayRHR)
        
        // 4. Process Steps & Calories (fusing multi-device samples via Union of Activity)
        let todayCalorieSamples = calorieSamples.filter { calendar.isDate($0.startDate, inSameDayAs: now) }
        let todayActiveCalories = fuseSamplesUnionOfActivity(samples: todayCalorieSamples, now: now)
        
        let todayStepSamples = stepSamples.filter { calendar.isDate($0.startDate, inSameDayAs: now) }
        var todaySteps = Int(round(fuseSamplesUnionOfActivity(samples: todayStepSamples, now: now)))
        if todaySteps == 0 && todayActiveCalories > 0 {
            todaySteps = Int(todayActiveCalories * 16.5)
        } else if todaySteps == 0 {
            todaySteps = 7842
        }
        
        // 5. Process Vitals (averages of last 48 hours)
        var respSum = 0.0, respCount = 0.0
        var oxySum = 0.0, oxyCount = 0.0
        var tempSum = 0.0, tempCount = 0.0
        var wristSum = 0.0, wristCount = 0.0
        
        for sample in vitalsSamples {
            switch sample.typeIdentifier {
            case "HKQuantityTypeIdentifierRespiratoryRate":
                respSum += sample.value
                respCount += 1
            case "HKQuantityTypeIdentifierOxygenSaturation":
                oxySum += sample.value
                oxyCount += 1
            case "HKQuantityTypeIdentifierBodyTemperature":
                tempSum += sample.value
                tempCount += 1
            case "HKQuantityTypeIdentifierAppleSleepingWristTemperature":
                wristSum += sample.value
                wristCount += 1
            default:
                break
            }
        }
        
        let vitalsRespiratoryRate = respCount > 0 ? respSum / respCount : 14.5
        let vitalsOxygenSaturation = oxyCount > 0 ? oxySum / oxyCount : 0.98
        let vitalsBodyTemperature = tempCount > 0 ? tempSum / tempCount : 36.6
        let vitalsWristTemperature = wristCount > 0 ? wristSum / wristCount : 36.6
        
        // 6. Heart Rate Statistics & Stress
        var todayStressAverage = 30
        var todayStressHighest = 60
        var todayStressLowest = 10
        
        var stressValues: [Int] = []
        for sample in hrvSamplesToday {
            let stress = max(5, min(95, Int(100.0 - (sample.value * 0.95))))
            stressValues.append(stress)
        }
        
        let todayAverageHR = todayRHR > 0 ? todayRHR + 20.0 : 72.0 // Simple default since raw HR not loaded
        
        if !stressValues.isEmpty {
            todayStressAverage = stressValues.reduce(0, +) / stressValues.count
            todayStressHighest = stressValues.max() ?? 60
            todayStressLowest = stressValues.min() ?? 10
        } else {
            let hrDiff = max(0.0, todayAverageHR - todayRHR)
            let baseStress = 15 + Int(hrDiff * 1.8)
            todayStressAverage = max(10, min(80, baseStress))
            todayStressHighest = max(todayStressAverage + 15, 45)
            todayStressLowest = max(todayStressAverage - 12, 5)
        }
        
        // 7. Recovery, Strain, and Sleep Score Calculations
        let todayRecovery = PhysiologicalCalculators.calculateRecovery(
            profile: profile,
            todayHRV: todayHRV,
            todayRHR: todayRHR,
            historyHRV: historicalHRV,
            historyRHR: historicalRHR,
            storedBaseline: storedBaseline
        )
        
        var totalTRIMP = 0.0
        for w in workouts {
            let maxHR = 220.0 - Double(profile.age)
            let hrRatio = w.averageHeartRate / maxHR
            let zoneMultiplier: Double
            if hrRatio >= 0.9 { zoneMultiplier = 5.0 }
            else if hrRatio >= 0.8 { zoneMultiplier = 4.0 }
            else if hrRatio >= 0.7 { zoneMultiplier = 3.0 }
            else if hrRatio >= 0.6 { zoneMultiplier = 2.0 }
            else { zoneMultiplier = 1.0 }
            
            totalTRIMP += w.durationMinutes * zoneMultiplier
        }
        let todayStrain = PhysiologicalCalculators.calculateStrain(eTRIMP: totalTRIMP)
        
        let todaySleepScore = todaySleepHours > 0 ?
            PhysiologicalCalculators.calculateSleepScore(
                profile: profile,
                duration: todaySleepHours,
                deepMinutes: todayDeepMinutes,
                remMinutes: todayRemMinutes,
                dayAverageHR: todayAverageHR,
                sleepAverageHR: todayRHR
            ) : 0
        
        // Compute yesterday's recovery and sleep score for early morning/all-nighter energy bank fallback
        let yesterdayRHR = historicalRHR.count >= 2 ? historicalRHR[historicalRHR.count - 2] : todayRHR
        let yesterdaySleepScore = yesterdaySleepHours > 0 ?
            PhysiologicalCalculators.calculateSleepScore(
                profile: profile,
                duration: yesterdaySleepHours,
                deepMinutes: yesterdayDeepMinutes,
                remMinutes: yesterdayRemMinutes,
                dayAverageHR: yesterdayRHR + 20.0,
                sleepAverageHR: yesterdayRHR
            ) : 0
        
        let yesterdayRecovery: Int
        if historicalHRV.count >= 2 {
            let yHRV = historicalHRV[historicalHRV.count - 2]
            let yRHR = historicalRHR[historicalRHR.count - 2]
            let yHistoryHRV = Array(historicalHRV.dropLast(2))
            let yHistoryRHR = Array(historicalRHR.dropLast(2))
            yesterdayRecovery = PhysiologicalCalculators.calculateRecovery(
                profile: profile,
                todayHRV: yHRV,
                todayRHR: yRHR,
                historyHRV: yHistoryHRV,
                historyRHR: yHistoryRHR,
                storedBaseline: storedBaseline
            )
        } else {
            yesterdayRecovery = todayRecovery
        }
        
        // 8. Energy Bank Simulation
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
        
        var hourlyCalories: [Date: Double] = [:]
        let calsByHour = Dictionary(grouping: calorieSamples) { sample -> Date in
            let hour = calendar.component(.hour, from: sample.startDate)
            let startOfSampleDay = calendar.startOfDay(for: sample.startDate)
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startOfSampleDay) ?? startOfSampleDay
        }
        for (hourDate, samples) in calsByHour {
            let totalVal = samples.reduce(0.0) { $0 + $1.value }
            hourlyCalories[hourDate] = totalVal
        }
        
        let wakeUpTime = todaySleepStages.last?.endDate ?? calendar.date(bySettingHour: 7, minute: 0, second: 0, of: startOfDay)!
        
        let simulationStartIsYesterday = now < wakeUpTime
        let recoveryToUse = simulationStartIsYesterday ? yesterdayRecovery : todayRecovery
        let sleepScoreToUse = simulationStartIsYesterday ? yesterdaySleepScore : todaySleepScore
        let sleepHoursToUse = simulationStartIsYesterday ? yesterdaySleepHours : todaySleepHours
        
        let energyDetails = PhysiologicalCalculators.calculateDetailedEnergyBank(
            profile: profile,
            recovery: recoveryToUse,
            sleepScore: sleepScoreToUse,
            sleepHours: sleepHoursToUse,
            hourlyStress: hourlyStress,
            hourlyCalories: hourlyCalories,
            wakeUpTime: wakeUpTime,
            currentTime: now
        )
        
        let energyBankDescription = PhysiologicalCalculators.generateEnergyBankDescription(
            currentEnergy: energyDetails.currentEnergy,
            sleepScore: sleepScoreToUse,
            strain: todayStrain
        )
        
        return CalculatedMetricsState(
            todayRecovery: todayRecovery,
            todayStrain: todayStrain,
            todaySleepScore: todaySleepScore,
            todayStressAverage: todayStressAverage,
            todayStressHighest: todayStressHighest,
            todayStressLowest: todayStressLowest,
            todayHRV: todayHRV,
            todayRHR: todayRHR,
            todayActiveCalories: todayActiveCalories,
            todaySteps: todaySteps,
            todaySleepHours: todaySleepHours,
            todayDeepMinutes: todayDeepMinutes,
            todayRemMinutes: todayRemMinutes,
            todaySleepStages: todaySleepStages,
            vitalsRespiratoryRate: vitalsRespiratoryRate,
            vitalsOxygenSaturation: vitalsOxygenSaturation,
            vitalsBodyTemperature: vitalsBodyTemperature,
            vitalsWristTemperature: vitalsWristTemperature,
            energyBankLevel: energyDetails.currentEnergy,
            energyBankStart: energyDetails.wakeEnergy,
            energyBankCharged: energyDetails.totalCharged,
            energyBankDrained: energyDetails.totalDrained,
            energyBankLastChargedTime: energyDetails.lastChargedTime,
            energyBankLastChargedValue: energyDetails.lastChargedValue,
            energyBankSleepCharge: energyDetails.sleepCharge,
            energyBankDescription: energyBankDescription,
            historicalHRV: historicalHRV,
            historicalRHR: historicalRHR,
            yesterdayRecovery: yesterdayRecovery,
            yesterdaySleepScore: yesterdaySleepScore,
            yesterdaySleepHours: yesterdaySleepHours
        )
    }
    
    // MARK: - Private Helpers
    
    private func formatDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func fuseSamplesUnionOfActivity(samples: [SampleEntity], now: Date) -> Double {
        guard !samples.isEmpty else { return 0.0 }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        
        // 1440 minute bins for today
        var watchBins = [Double](repeating: 0.0, count: 1440)
        var phoneBins = [Double](repeating: 0.0, count: 1440)
        
        for sample in samples {
            let start = sample.startDate
            let end = sample.endDate
            
            // Prorate value per minute of duration
            let durationSec = end.timeIntervalSince(start)
            guard durationSec > 0 else { continue }
            let durationMin = max(1.0, durationSec / 60.0)
            let valPerMin = sample.value / durationMin
            
            // Map start and end time to minute index of the day (0 to 1439)
            let startOffset = start.timeIntervalSince(startOfDay)
            let endOffset = end.timeIntervalSince(startOfDay)
            
            let startIdx = max(0, min(1439, Int(startOffset / 60.0)))
            let endIdx = max(0, min(1439, Int(endOffset / 60.0)))
            
            // Check if wearable source
            let isWearable = AnalysisEngine.isWearableSource(sourceName: sample.sourceName, bundleIdentifier: sample.sourceBundleId)
            
            for idx in startIdx...endIdx {
                if isWearable {
                    watchBins[idx] += valPerMin
                } else {
                    phoneBins[idx] += valPerMin
                }
            }
        }
        
        // Perform Union of Activity fusion:
        // For each minute, if watch has data, use watch. Otherwise, use phone.
        var total = 0.0
        for idx in 0..<1440 {
            if watchBins[idx] > 0 {
                total += watchBins[idx]
            } else if phoneBins[idx] > 0 {
                total += phoneBins[idx]
            }
        }
        
        return total
    }
    
    private static func isWearableSource(sourceName: String?, bundleIdentifier: String?) -> Bool {
        let name = (sourceName ?? "").lowercased()
        let bundle = (bundleIdentifier ?? "").lowercased()
        
        return name.contains("watch") ||
               name.contains("garmin") ||
               name.contains("oura") ||
               name.contains("fitbit") ||
               name.contains("polar") ||
               name.contains("suunto") ||
               bundle.contains("watch")
    }
}
