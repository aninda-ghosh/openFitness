import Foundation

struct CalibratedBaseline {
    let hrvMean: Double
    let hrvStdDev: Double
    let rhrMean: Double
    let rhrStdDev: Double
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
        
        let logTodayHRV = log(todayHRV)
        
        if hrvCount >= 3 && rhrCount >= 3 {
            // 1. Natural log HRV values to obtain normal distribution
            let logHistoryHRV = historyHRV.map { log($0) }
            
            // 2. HRV Statistics
            hrvMean = logHistoryHRV.reduce(0, +) / Double(logHistoryHRV.count)
            let hrvVariance = logHistoryHRV.map { pow($0 - hrvMean, 2) }.reduce(0, +) / Double(logHistoryHRV.count)
            hrvStdDev = max(sqrt(hrvVariance), 0.05) // Prevent division by zero
            
            // 3. RHR Statistics
            rhrMean = historyRHR.reduce(0, +) / Double(historyRHR.count)
            let rhrVariance = historyRHR.map { pow($0 - rhrMean, 2) }.reduce(0, +) / Double(historyRHR.count)
            rhrStdDev = max(sqrt(rhrVariance), 1.0)
            
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
            hrvMean = log(55.0)
            hrvStdDev = 0.15
            rhrMean = 60.0
            rhrStdDev = 5.0
        }
        
        // Z-score calculations
        let zHRV = (logTodayHRV - hrvMean) / hrvStdDev
        
        // Inverted because lower resting heart rate is better
        let zRHR = (rhrMean - todayRHR) / rhrStdDev
        
        // Blend Z-scores (60% weight on HRV, 40% on RHR)
        let zBlend = (0.6 * zHRV) + (0.4 * zRHR)
        
        // Map Z-score to 0 - 100%
        let recoveryScore = 50.0 + (zBlend * 25.0)
        
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
    ///   - duration: Total hours slept.
    ///   - needed: Target sleep needed in hours.
    ///   - deepMinutes: Minutes spent in deep sleep.
    ///   - remMinutes: Minutes spent in REM sleep.
    ///   - dayAverageHR: Daytime active heart rate average (bpm).
    ///   - sleepAverageHR: Nighttime sleeping heart rate average (bpm).
    /// - Returns: A percentage value from 0 to 100.
    static func calculateSleepScore(
        duration: Double,
        needed: Double,
        deepMinutes: Double,
        remMinutes: Double,
        dayAverageHR: Double,
        sleepAverageHR: Double
    ) -> Int {
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
    /// - Parameters:
    ///   - recovery: Today's Recovery Score (0–100)
    ///   - strain: Today's Strain Score (0.0–21.0)
    ///   - sleepScore: Today's Sleep Score (0–100)
    ///   - steps: Today's step count
    ///   - activeCalories: Today's active energy burned (kcal)
    ///   - todayHRV: Today's HRV value (ms)
    ///   - baselineHRVMean: Calibrated log-HRV mean
    ///   - baselineHRVStdDev: Calibrated log-HRV standard deviation
    ///   - stressAverage: Today's average stress level (0–100)
    /// - Returns: A percentage value from 0 to 100.
    static func calculateActivenessScore(
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
        let calsNorm = min(1.0, activeCalories / 600.0)
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
}
