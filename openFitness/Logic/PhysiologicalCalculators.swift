import Foundation

struct CalibratedBaseline {
    let hrvMean: Double
    let hrvStdDev: Double
    let rhrMean: Double
    let rhrStdDev: Double
}

struct EnergyBankDetails {
    let currentEnergy: Int
    let totalCharged: Int
    let totalDrained: Int
    let lastChargedValue: Int
    let lastChargedTime: Date
    let wakeEnergy: Int
    let sleepCharge: Int
}

struct PhysiologicalCalculators {
    
    // MARK: - Calibration Helper Storage
    static func saveCalibration(hrvMean: Double, hrvStdDev: Double, rhrMean: Double, rhrStdDev: Double, count: Int) {
        let prevCount = UserDefaults.standard.integer(forKey: "calibrationSampleCount")
        if count >= prevCount {
            UserDefaults.standard.set(hrvMean, forKey: "calibratedHRVMean")
            UserDefaults.standard.set(hrvStdDev, forKey: "calibratedHRVStdDev")
            UserDefaults.standard.set(rhrMean, forKey: "calibratedRHRMean")
            UserDefaults.standard.set(rhrStdDev, forKey: "calibratedRHRStdDev")
            UserDefaults.standard.set(true, forKey: "hasCalibrated")
            UserDefaults.standard.set(count, forKey: "calibrationSampleCount")
        }
    }
    
    static func getStoredBaseline() -> CalibratedBaseline? {
        guard UserDefaults.standard.bool(forKey: "hasCalibrated") else { return nil }
        return CalibratedBaseline(
            hrvMean: UserDefaults.standard.double(forKey: "calibratedHRVMean"),
            hrvStdDev: UserDefaults.standard.double(forKey: "calibratedHRVStdDev"),
            rhrMean: UserDefaults.standard.double(forKey: "calibratedRHRMean"),
            rhrStdDev: UserDefaults.standard.double(forKey: "calibratedRHRStdDev")
        )
    }
    
    // MARK: - Recovery Score (0% - 100%)
    /// Calculates the daily Recovery Score based on log-transformed HRV Z-scores and RHR Z-scores.
    /// Supports persistent calibration fallback for sparse historical data.
    static func calculateRecovery(
        profile: UserProfile,
        todayHRV: Double,
        todayRHR: Double,
        historyHRV: [Double],
        historyRHR: [Double],
        storedBaseline: CalibratedBaseline? = nil
    ) -> Int {
        let hrvCount = historyHRV.count
        let rhrCount = historyRHR.count
        
        var hrvMean = 0.0
        var hrvStdDev = 1.0
        var rhrMean = 0.0
        var rhrStdDev = 1.0
        
        // Age and Sex adjusted fallbacks instead of hardcoded 55.0 / 60.0
        let defaultHRV = max(30.0, min(90.0, 100.0 - Double(profile.age)))
        let defaultRHR = profile.biologicalSex == "Female" ? 65.0 : 60.0
        
        let safeHRV = todayHRV > 0 ? todayHRV : defaultHRV
        let safeRHR = todayRHR > 0 ? todayRHR : defaultRHR
        let logTodayHRV = log(safeHRV)
        
        if hrvCount >= 3 && rhrCount >= 3 {
            // 1. Natural log HRV values to obtain normal distribution
            let logHistoryHRV = historyHRV.filter { $0 > 0 }.map { log($0) }
            
            if !logHistoryHRV.isEmpty {
                hrvMean = logHistoryHRV.reduce(0, +) / Double(logHistoryHRV.count)
                let hrvVariance = logHistoryHRV.map { pow($0 - hrvMean, 2) }.reduce(0, +) / Double(logHistoryHRV.count)
                hrvStdDev = max(sqrt(hrvVariance), 0.12) // Minimum SD to avoid extreme inflation on flat data
            } else {
                hrvMean = log(defaultHRV)
                hrvStdDev = 0.15
            }
            
            // 3. RHR Statistics
            let validHistoryRHR = historyRHR.filter { $0 > 0 }
            if !validHistoryRHR.isEmpty {
                rhrMean = validHistoryRHR.reduce(0, +) / Double(validHistoryRHR.count)
                let rhrVariance = validHistoryRHR.map { pow($0 - rhrMean, 2) }.reduce(0, +) / Double(validHistoryRHR.count)
                rhrStdDev = max(sqrt(rhrVariance), 3.0) // Minimum SD of 3 bpm to prevent near-zero division issues
            } else {
                rhrMean = defaultRHR
                rhrStdDev = 5.0
            }
            
            // Save calibration to UserDefaults for future baseline fallback
            saveCalibration(hrvMean: hrvMean, hrvStdDev: hrvStdDev, rhrMean: rhrMean, rhrStdDev: rhrStdDev, count: max(hrvCount, rhrCount))
        } else if let baseline = storedBaseline {
            // Use stored calibration
            hrvMean = baseline.hrvMean
            hrvStdDev = baseline.hrvStdDev
            rhrMean = baseline.rhrMean
            rhrStdDev = baseline.rhrStdDev
        } else {
            // Default baseline values so we still calculate a dynamic score
            hrvMean = log(defaultHRV)
            hrvStdDev = 0.15
            rhrMean = defaultRHR
            rhrStdDev = 5.0
        }
        
        // Z-score calculations
        let rawZHRV = (logTodayHRV - hrvMean) / hrvStdDev
        let zHRV = max(-2.2, min(2.2, rawZHRV)) // Clamp individual Z-scores to normal envelope
        
        // Inverted because lower resting heart rate is better
        let rawZRHR = (rhrMean - safeRHR) / rhrStdDev
        let zRHR = max(-2.2, min(2.2, rawZRHR))
        
        // Blend Z-scores (60% weight on HRV, 40% on RHR)
        let zBlend = (0.6 * zHRV) + (0.4 * zRHR)
        
        // Map Z-score to 0 - 100% (with factor 22.7 mapping [-2.2, 2.2] range to ~[-50, 50] range)
        let recoveryScore = 50.0 + (zBlend * 22.7)
        
        return max(0, min(100, Int(round(recoveryScore))))
    }
    
    // MARK: - Daily Strain Score (0.0 - 21.0)
    /// Converts a raw cardiovascular training impulse (eTRIMP) into a logarithmic strain score between 0 and 21.
    /// - Parameter eTRIMP: The accumulated Edwards TRIMP load (Minutes * Zone weights).
    /// - Returns: A Double value between 0.0 and 21.0.
    static func calculateStrain(eTRIMP: Double) -> Double {
        guard eTRIMP > 0 else { return 0.0 }
        
        // k controls how fast the curve tapers off. 
        // A value of 0.0035 means:
        // - eTRIMP of 100 = 6.3 Strain (Light)
        // - eTRIMP of 250 = 12.2 Strain (Moderate)
        // - eTRIMP of 500 = 17.3 Strain (High)
        // - eTRIMP of 900 = 20.1 Strain (Extreme / All-Out)
        let k = 0.0035
        let strain = 21.0 * (1.0 - exp(-k * eTRIMP))
        
        // Format to one decimal place
        return Double(round(10 * strain) / 10)
    }
    
    // MARK: - Sleep Score (0% - 100%)
    /// Computes sleep quality based on duration, sleep stage distributions, and nocturnal heart rate dipping.
    /// - Parameters:
    ///   - profile: User biological configuration.
    ///   - duration: Total hours slept.
    ///   - deepMinutes: Minutes spent in deep sleep.
    ///   - remMinutes: Minutes spent in REM sleep.
    ///   - dayAverageHR: Daytime active heart rate average (bpm).
    ///   - sleepAverageHR: Nighttime sleeping heart rate average (bpm).
    /// - Returns: A percentage value from 0 to 100.
    static func calculateSleepScore(
        profile: UserProfile,
        duration: Double,
        deepMinutes: Double,
        remMinutes: Double,
        dayAverageHR: Double,
        sleepAverageHR: Double
    ) -> Int {
        let needed = profile.sleepNeedHours
        
        // 1. Duration Score (40 points max)
        let durationRatio = min(1.0, duration / max(needed, 4.0))
        let durationPoints = durationRatio * 40.0
        
        // 2. Deep Sleep Score (30 points max - target 90 minutes)
        let deepRatio = min(1.0, deepMinutes / 90.0)
        let deepPoints = deepRatio * 30.0
        
        // 3. REM Sleep Score (20 points max - target 90 minutes)
        let remRatio = min(1.0, remMinutes / 90.0)
        let remPoints = remRatio * 20.0
        
        // 4. Heart Rate Dip Score (10 points max - target 10% - 20% dip)
        var dipPoints = 0.0
        if dayAverageHR > 0 {
            let dipPercent = ((dayAverageHR - sleepAverageHR) / dayAverageHR) * 100.0
            if dipPercent >= 10.0 && dipPercent <= 20.0 {
                dipPoints = 10.0
            } else if dipPercent > 0 {
                // Partial credit for any dip
                let ratio = min(1.0, dipPercent / 10.0)
                dipPoints = ratio * 10.0
            }
        } else {
            dipPoints = 7.0 // Default baseline credit if daytime heart rate is missing
        }
        
        let totalScore = durationPoints + deepPoints + remPoints + dipPoints
        return max(0, min(100, Int(round(totalScore))))
    }
    
    // MARK: - Activeness Score (0% - 100%)
    /// Computes a composite daily Activeness Score from six physiological and activity sub-scores.
    /// Only meaningful once calibration is complete (21+ days of HRV/RHR baseline data).
    static func calculateActivenessScore(
        profile: UserProfile,
        recovery: Int,
        strain: Double,
        sleepScore: Int,
        steps: Int,
        activeCalories: Double,
        todayHRV: Double,
        baselineHRVMean: Double,
        baselineHRVStdDev: Double,
        stressAverage: Int
    ) -> Int {
        // 1. Recovery sub-score (25% weight) — direct mapping
        let sRecovery = Double(recovery) / 100.0
        
        // 2. Strain Balance sub-score (20% weight) — bell curve centered at optimal ~11
        // Rewards moderate training, penalizes both under-training and overtraining
        let strainOptimal = 11.0
        let strainSpread = 4.0
        let sStrain = exp(-0.5 * pow((strain - strainOptimal) / strainSpread, 2))
        
        // 3. Sleep Quality sub-score (20% weight) — direct mapping
        let sSleep = Double(sleepScore) / 100.0
        
        // 4. Activity sub-score (15% weight) — blend of steps and calories
        let stepsNorm = min(1.0, Double(steps) / 10000.0)
        
        // Calorie target normalized dynamically based on weight instead of flat 600
        let calorieTarget = max(300.0, profile.weightKg * 8.5)
        let calsNorm = min(1.0, activeCalories / calorieTarget)
        
        let sActivity = 0.6 * stepsNorm + 0.4 * calsNorm
        
        // 5. HRV Trend sub-score (10% weight) — sigmoid-mapped z-score
        // Higher HRV relative to personal baseline = better
        let logHRV = todayHRV > 0 ? log(todayHRV) : baselineHRVMean
        let stdDev = max(baselineHRVStdDev, 0.05)
        let zHRV = (logHRV - baselineHRVMean) / stdDev
        let sHRV = 1.0 / (1.0 + exp(-1.5 * zHRV)) // Sigmoid: maps z-score to 0–1
        
        // 6. Stress inverse sub-score (10% weight) — lower stress = higher score
        let sStress = 1.0 - (Double(stressAverage) / 100.0)
        
        // Weighted sum
        let weighted = (0.25 * sRecovery) +
                       (0.20 * sStrain) +
                       (0.20 * sSleep) +
                       (0.15 * sActivity) +
                       (0.10 * sHRV) +
                       (0.10 * sStress)
        
        let score = weighted * 100.0
        return max(0, min(100, Int(round(score))))
    }
    
    // MARK: - Dynamic Energy Bank Score (0% - 100%)
    /// Replicates a cumulative reservoir model for the Energy Bank based on recovery/sleep start charge,
    /// hourly active energy depletion, and stress levels (Garmin/Body Battery style).
    static func calculateDynamicEnergyBank(
        profile: UserProfile,
        recovery: Int,
        sleepScore: Int,
        hourlyStress: [Date: Int],
        hourlyCalories: [Date: Double],
        wakeUpTime: Date,
        currentTime: Date
    ) -> Int {
        let details = calculateDetailedEnergyBank(
            profile: profile,
            recovery: recovery,
            sleepScore: sleepScore,
            sleepHours: profile.sleepNeedHours,
            hourlyStress: hourlyStress,
            hourlyCalories: hourlyCalories,
            wakeUpTime: wakeUpTime,
            currentTime: currentTime
        )
        return details.currentEnergy
    }
    
    // MARK: - Detailed Energy Bank Calculator
    /// Performs a cumulative hourly reservoir simulation to track current energy level, total charged,
    /// total drained, and peak charging statistics.
    static func calculateDetailedEnergyBank(
        profile: UserProfile,
        recovery: Int,
        sleepScore: Int,
        sleepHours: Double,
        hourlyStress: [Date: Int],
        hourlyCalories: [Date: Double],
        wakeUpTime: Date,
        currentTime: Date
    ) -> EnergyBankDetails {
        let calendar = Calendar.current
        
        // 1. Starting baseline energy (yesterday's ending energy).
        // Let's base this on Recovery score: higher recovery implies yesterday ended more rested.
        let recoveryFactor = Double(recovery) / 100.0
        let yesterdayEnding = 15.0 + (recoveryFactor * 15.0) // 15% to 30% range
        
        // 2. Sleep charge: sleep score determines how much energy is added.
        // A sleep score of 76% adds around +72% charge. Capped at 98% maximum charge.
        let rawSleepCharge = Double(sleepScore) * 0.95
        let sleepCharge = min(rawSleepCharge, 98.0 - yesterdayEnding)
        
        let wakeEnergy = yesterdayEnding + sleepCharge
        
        var currentEnergy = wakeEnergy
        var totalCharged = 0.0
        var totalDrained = 0.0
        
        // If current time is before the wake-up time of today, we should simulate starting from yesterday's wake-up time.
        let adjustedWakeUpTime: Date
        if currentTime < wakeUpTime {
            adjustedWakeUpTime = calendar.date(byAdding: .day, value: -1, to: wakeUpTime) ?? wakeUpTime
        } else {
            adjustedWakeUpTime = wakeUpTime
        }
        
        var lastChargedValue = Int(round(wakeEnergy))
        var lastChargedTime = adjustedWakeUpTime
        
        let elapsedHours = calendar.dateComponents([.hour], from: adjustedWakeUpTime, to: currentTime).hour ?? 0
        
        if elapsedHours >= 0 {
            for h in 0...elapsedHours {
                guard let hourDate = calendar.date(byAdding: .hour, value: h, to: adjustedWakeUpTime) else { continue }
                if hourDate > currentTime { break }
                
                let stress = hourlyStress[hourDate] ?? 30
                let calories = hourlyCalories[hourDate] ?? 0.0
                
                // Stress drain: stress levels above 30 drain the battery
                let stressDrain = max(0.0, (Double(stress) - 30.0) / 70.0 * 4.5)
                
                // Activity drain: energy expenditure drains the battery
                let calDrain = calories * 0.06
                
                // Baseline awake metabolic/cognitive drain (1.2% per hour just for being awake)
                let baselineDrain = 1.2
                
                let hourlyDrain = baselineDrain + stressDrain + calDrain
                
                // Resting charge: low stress (under 25) and low activity charges the battery
                var hourlyCharge = 0.0
                if stress < 25 && calories < 15.0 {
                    hourlyCharge = max(0.0, (25.0 - Double(stress)) / 25.0 * 2.5)
                }
                
                let newEnergy = currentEnergy + hourlyCharge - hourlyDrain
                let clippedEnergy = max(5.0, min(100.0, newEnergy))
                
                let actualChange = clippedEnergy - currentEnergy
                if actualChange > 0 {
                    totalCharged += actualChange
                } else {
                    totalDrained += abs(actualChange)
                }
                
                currentEnergy = clippedEnergy
                
                if hourlyCharge > 0 && currentEnergy > Double(lastChargedValue) {
                    lastChargedValue = Int(round(currentEnergy))
                    lastChargedTime = hourDate
                }
            }
        }
        
        return EnergyBankDetails(
            currentEnergy: max(5, min(100, Int(round(currentEnergy)))),
            totalCharged: max(0, min(100, Int(round(totalCharged)))),
            totalDrained: max(0, min(100, Int(round(totalDrained)))),
            lastChargedValue: max(5, min(100, lastChargedValue)),
            lastChargedTime: lastChargedTime,
            wakeEnergy: max(5, min(100, Int(round(wakeEnergy)))),
            sleepCharge: max(0, min(100, Int(round(sleepCharge))))
        )
    }
    
    // MARK: - Dynamic Text Generator
    /// Builds a rich contextual summary describing sleep quality, daily strain, and current energy reserves.
    static func generateEnergyBankDescription(
        currentEnergy: Int,
        sleepScore: Int,
        strain: Double
    ) -> String {
        let status: String
        if currentEnergy >= 85 {
            status = "Topped off and ready: "
        } else if currentEnergy >= 65 {
            status = "Steady and balanced: "
        } else if currentEnergy >= 40 {
            status = "Charging down: "
        } else {
            status = "Running on empty: "
        }
        
        let usual = 36 // Match Bevel's usual baseline of 36%
        let diff = currentEnergy - usual
        let levelComparison: String
        if diff > 15 {
            levelComparison = "Your Energy Bank is sitting pretty at \(currentEnergy)% right now, which is way above your usual \(usual)% for this time of day. "
        } else if diff < -15 {
            levelComparison = "Your Energy Bank is low at \(currentEnergy)% right now, which is significantly below your usual \(usual)% for this time of day. "
        } else {
            levelComparison = "Your Energy Bank is at \(currentEnergy)% right now, which is right around your usual \(usual)% for this time of day. "
        }
        
        let sleepComment: String
        if sleepScore >= 80 {
            sleepComment = "That solid sleep really paid off, "
        } else if sleepScore >= 60 {
            sleepComment = "Your sleep was decent but could be deeper, "
        } else {
            sleepComment = "Poor sleep has left you starting at a disadvantage, "
        }
        
        let strainComment: String
        if strain < 2.0 {
            strainComment = "and since you haven't put any Strain on the system yet, you're in a perfect spot to tackle that high-intensity training today."
        } else if strain < 8.0 {
            strainComment = "and with only light activity so far, you still have plenty of reserve to tackle workouts later."
        } else if strain < 14.0 {
            strainComment = "and since you've already accumulated moderate strain, keep an eye on your exertion levels."
        } else {
            strainComment = "and after that intense workout, you should focus on recovery and letting your battery recharge."
        }
        
        return status + levelComparison + sleepComment + strainComment
    }
}
