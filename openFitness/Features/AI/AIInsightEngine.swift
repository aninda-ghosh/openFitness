import Foundation
import FoundationModels

// MARK: - Generated content shapes

@Generable
struct DailyPulse: Codable, Equatable {
    @Guide(description: "Catchy headline of 3 to 5 words about the user's day, like 'Rest day, well earned' or 'Great sleep, now move'. Never the app name or the word pulse")
    var headline: String

    @Guide(description: "One or two sentences, 35 words maximum: cite one or two of the user's numbers and give exactly one piece of advice. No filler, no repeated phrases")
    var message: String
}

@Generable
struct MetricInsight: Codable, Equatable {
    @Guide(description: "Two or three plain sentences restating the most important facts, using only the numbers given. No invented numbers, no speculation")
    var summary: String

    @Guide(description: "Three short, specific, actionable suggestions for the next 24 hours, each grounded in the given facts", .count(3))
    var suggestions: [String]
}

// MARK: - Metrics that support deep-dive insights

enum InsightMetric: String {
    case recovery
    case sleep
    case strain
    case stress
    case activity
    case energy
    case vitals
    case activeness
    case workouts

    var displayName: String {
        switch self {
        case .recovery: return "Recovery"
        case .sleep: return "Sleep"
        case .strain: return "Cardio Strain"
        case .stress: return "Stress"
        case .activity: return "Activity"
        case .energy: return "Energy"
        case .vitals: return "Vitals"
        case .activeness: return "Activeness"
        case .workouts: return "Workout Patterns"
        }
    }
}

// MARK: - Engine

/// The ~3B-parameter on-device model invents numbers and causality when asked to
/// analyze raw data, so all analysis here is computed deterministically in code
/// (deltas vs 7-day baselines, stance decisions) and the model only puts the
/// pre-verified facts into words, sampled greedily.
@MainActor
final class AIInsightEngine {
    static let shared = AIInsightEngine()

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    private var metricCache: [String: MetricInsight] = [:]

    private struct CachedPulse: Codable {
        let day: String
        let bucket: Int
        let pulse: DailyPulse
    }

    private static let pulseCacheKey = "ai.dailyPulse.cache.v3"

    private static let factualOptions = GenerationOptions(sampling: .greedy)

    // MARK: Daily pulse

    /// Short encouraging summary for the dashboard and the morning notification.
    /// Regenerated every ~4 hours so the nudge tracks the user's day without burning
    /// the model on every appearance. Background callers pass the manager they just
    /// refreshed, since the dashboard's registered instance may be stale there.
    func dailyPulse(using hkOverride: HealthKitManager? = nil) async throws -> DailyPulse {
        let day = Self.dayString(Date())
        let bucket = Calendar.current.component(.hour, from: Date()) / 4

        if let data = UserDefaults.standard.data(forKey: Self.pulseCacheKey),
           let cached = try? JSONDecoder().decode(CachedPulse.self, from: data),
           cached.day == day, cached.bucket == bucket {
            return cached.pulse
        }

        let timeOfDay: String
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<12: timeOfDay = "morning"
        case ..<17: timeOfDay = "afternoon"
        default: timeOfDay = "evening"
        }

        // Decide the stance in code so the model cannot give conflicting advice
        let hk = hkOverride ?? AIDataSource.manager
        let stance: String
        if hk.todayRecovery < 50 || hk.energyBank < 30 {
            stance = "Their recovery or energy is low today: encourage rest or gentle movement only. Do not suggest workouts."
        } else if hk.todaySteps < 6000 {
            stance = "They have not moved much yet: encourage them to get active."
        } else {
            stance = "They are having a good day: celebrate it briefly and encourage them to keep it up."
        }

        let context = """
            Recovery \(hk.todayRecovery)%, strain \(AIToolFormat.num(hk.todayStrain)) of 21, \
            sleep \(AIToolFormat.num(hk.todaySleepHours))h (score \(hk.todaySleepScore)%), \
            \(hk.todaySteps) steps, \(Int(hk.todayActiveCalories)) active kcal, \
            energy bank \(hk.energyBank)%, stress \(hk.todayStressAverage) of 100
            """

        let session = LanguageModelSession(instructions: """
            You write one short nudge for the dashboard of a fitness tracking app. \
            At most two sentences and 35 words in total. Warm and specific: cite one or \
            two numbers from the data, give exactly one piece of advice, and never \
            contradict the guidance you are given. Plain text only - no markdown, no \
            emoji, no medical advice.
            """)

        let prompt = """
            It is \(timeOfDay). The user's metrics today: \(context).
            Guidance: \(stance)
            Write the nudge.
            """

        let pulse = try await session.respond(
            to: prompt,
            generating: DailyPulse.self,
            options: Self.factualOptions
        ).content

        if let data = try? JSONEncoder().encode(CachedPulse(day: day, bucket: bucket, pulse: pulse)) {
            UserDefaults.standard.set(data, forKey: Self.pulseCacheKey)
        }
        return pulse
    }

    // MARK: Metric deep-dive insight

    /// "What happened and how to improve" for one metric, cached per metric per day.
    func metricInsight(for metric: InsightMetric, hkManager: HealthKitManager) async throws -> MetricInsight {
        let cacheKey = "\(metric.rawValue)-\(Self.dayString(Date()))"
        if let cached = metricCache[cacheKey] {
            return cached
        }

        let session = LanguageModelSession(instructions: """
            You turn verified facts about one of the user's fitness metrics into a short \
            readable insight. Use only the numbers that appear in the facts - never \
            invent, estimate or recalculate a number. The summary restates the most \
            important facts in plain language. The suggestions are concrete actions for \
            the next 24 hours that follow from those facts. You may use **bold** for key \
            numbers. No medical advice - for health concerns, suggest a professional.
            """)

        let prompt = """
            Metric: \(metric.displayName)

            Verified facts:
            \(facts(for: metric, hk: hkManager))

            Write the summary and three suggestions using these facts only.
            """

        let insight = try await session.respond(
            to: prompt,
            generating: MetricInsight.self,
            options: Self.factualOptions
        ).content
        metricCache[cacheKey] = insight
        return insight
    }

    /// Fact block used to seed a focused Ask Coach session opened from a metric screen.
    func chatContext(for metric: InsightMetric) -> String {
        facts(for: metric, hk: AIDataSource.manager)
    }

    // MARK: - Deterministic fact building

    /// Today's values compared against 7-day baselines, computed in code so the
    /// model has nothing to "figure out".
    private func facts(for metric: InsightMetric, hk: HealthKitManager) -> String {
        let baseline = Baseline()
        var lines: [String] = []

        switch metric {
        case .recovery:
            lines.append(compare(Double(hk.todayRecovery), baseline.avg(\.recovery), "Recovery score", unit: "%", decimals: 0))
            lines.append(compare(hk.todayHRV, baseline.avgOptional(\.hrv), "HRV", unit: "ms"))
            lines.append(compare(hk.todayRHR, baseline.avgOptional(\.rhr), "Resting heart rate", unit: "bpm", decimals: 0))
            lines.append("Higher HRV and lower resting heart rate mean better recovery.")
            lines.append("Last night's sleep: \(AIToolFormat.num(hk.todaySleepHours))h of \(AIToolFormat.num(hk.todaySleepNeeded))h needed, sleep score \(hk.todaySleepScore)%.")
        case .sleep:
            let deficit = hk.todaySleepNeeded - hk.todaySleepHours
            lines.append("Slept \(AIToolFormat.num(hk.todaySleepHours))h of \(AIToolFormat.num(hk.todaySleepNeeded))h needed" +
                         (deficit > 0.25 ? " - a deficit of \(AIToolFormat.num(deficit))h." : " - need was met."))
            lines.append(compare(Double(hk.todaySleepScore), baseline.avg(\.sleepScore), "Sleep score", unit: "%", decimals: 0))
            lines.append("Deep sleep \(Int(hk.todayDeepMinutes))min, REM sleep \(Int(hk.todayRemMinutes))min.")
            if let avgSleep = baseline.avgOptional(\.sleepDuration) {
                lines.append("7-day average sleep duration: \(AIToolFormat.num(avgSleep))h.")
            }
            lines.append("Previous night: \(AIToolFormat.num(hk.yesterdaySleepHours))h, score \(hk.yesterdaySleepScore)%.")
        case .strain:
            lines.append(compare(hk.todayStrain, baseline.avg(\.strain), "Strain (0-21 scale)", unit: ""))
            lines.append(compare(Double(hk.todaySteps), baseline.avgDouble { Double($0.steps) }, "Steps", unit: "", decimals: 0))
            lines.append(compare(hk.todayActiveCalories, baseline.avg(\.activeCalories), "Active calories", unit: " kcal", decimals: 0))
            lines.append("Recovery today is \(hk.todayRecovery)%." +
                         (hk.todayRecovery >= 66 && hk.todayStrain < 8 ? " Recovery is high and strain is low, so there is room for more training today."
                          : hk.todayRecovery < 50 && hk.todayStrain > 12 ? " Strain is high while recovery is low, which works against recovery."
                          : ""))
        case .stress:
            lines.append(compare(Double(hk.todayStressAverage), baseline.avg(\.stressAvg), "Average stress (0-100, lower is calmer)", unit: "", decimals: 0))
            lines.append("Today's stress ranged from \(hk.todayStressLowest) to \(hk.todayStressHighest).")
            lines.append(compare(hk.todayHRV, baseline.avgOptional(\.hrv), "HRV", unit: "ms"))
            lines.append("Lower HRV usually accompanies higher stress.")
            lines.append("Last night's sleep: \(AIToolFormat.num(hk.todaySleepHours))h, score \(hk.todaySleepScore)%.")
        case .activity:
            lines.append(compare(Double(hk.todaySteps), baseline.avgDouble { Double($0.steps) }, "Steps", unit: "", decimals: 0))
            lines.append(compare(hk.todayActiveCalories, baseline.avg(\.activeCalories), "Active calories", unit: " kcal", decimals: 0))
            lines.append("Strain today: \(AIToolFormat.num(hk.todayStrain)) of 21. Energy bank: \(hk.energyBank)%.")
        case .energy:
            lines.append("Energy bank is at \(hk.energyBank)%; the day started at \(hk.energyBankStart)%.")
            lines.append("Charged \(hk.energyBankCharged)% so far today (\(hk.energyBankSleepCharge)% of it from sleep) and drained \(hk.energyBankDrained)%.")
            lines.append("Recovery \(hk.todayRecovery)%, strain \(AIToolFormat.num(hk.todayStrain)) of 21, sleep \(AIToolFormat.num(hk.todaySleepHours))h.")
        case .vitals:
            lines.append(compare(hk.todayRespiratoryRate, baseline.avgOptional(\.respiratoryRate), "Respiratory rate", unit: " breaths/min"))
            lines.append(compare(hk.todayOxygenSaturation, baseline.avgOptional(\.oxygenSaturation), "Blood oxygen", unit: "%"))
            lines.append(compare(hk.todayBodyTemperature, baseline.avgOptional(\.bodyTemperature), "Skin temperature", unit: "°"))
            if hk.todayVO2Max > 0 { lines.append("VO2 max: \(AIToolFormat.num(hk.todayVO2Max)).") }
            if hk.todayBodyFatPercentage > 0 { lines.append("Body fat: \(AIToolFormat.num(hk.todayBodyFatPercentage))%.") }
            if hk.todayWeight > 0 { lines.append("Weight \(AIToolFormat.num(hk.todayWeight)) lb, BMI \(AIToolFormat.num(hk.todayBMI)).") }
            lines.append("Vitals staying near the 7-day baseline is a good sign; deviations can reflect strain, illness or poor sleep.")
        case .activeness:
            lines.append("Activeness score today: \(hk.activenessScore) of 100." +
                         (hk.isCalibrated ? "" : " The score is still calibrating and may be unstable."))
            lines.append(compare(Double(hk.todayRecovery), baseline.avg(\.recovery), "Recovery", unit: "%", decimals: 0))
            lines.append(compare(Double(hk.todaySleepScore), baseline.avg(\.sleepScore), "Sleep score", unit: "%", decimals: 0))
            lines.append(compare(Double(hk.todaySteps), baseline.avgDouble { Double($0.steps) }, "Steps", unit: "", decimals: 0))
            lines.append(compare(Double(hk.todayStressAverage), baseline.avg(\.stressAvg), "Stress (lower is calmer)", unit: "", decimals: 0))
            lines.append("Strain today: \(AIToolFormat.num(hk.todayStrain)) of 21.")
        case .workouts:
            let calendar = Calendar.current
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let recent = hk.recentWorkouts
            if recent.isEmpty {
                lines.append("No workouts recorded recently.")
            } else {
                lines.append("Workouts in the last 7 days: \(recent.filter { $0.date >= weekAgo }.count).")
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "EEE MMM d"
                for w in recent.prefix(5) {
                    var parts = ["\(Int(w.durationMinutes))min", "\(Int(w.activeEnergyBurned)) kcal"]
                    if w.averageHeartRate > 0 { parts.append("avg HR \(Int(w.averageHeartRate))bpm") }
                    lines.append("\(dayFormatter.string(from: w.date)): \(w.name) - " + parts.joined(separator: ", "))
                }
            }
            lines.append("Recovery today \(hk.todayRecovery)%, strain \(AIToolFormat.num(hk.todayStrain)) of 21.")
        }

        return lines.filter { !$0.isEmpty }.map { "- " + $0 }.joined(separator: "\n")
    }

    /// "X today: 42, 12% below the 7-day average of 48" - or just today's value
    /// when there is no baseline. Returns "" when there is no data at all.
    private func compare(_ today: Double, _ baseline: Double?, _ label: String, unit: String, decimals: Int = 1) -> String {
        guard today > 0 else { return "" }
        let todayStr = "\(label) today: \(AIToolFormat.num(today, decimals))\(unit)"
        guard let baseline, baseline > 0 else { return todayStr + "." }
        let pct = (today - baseline) / baseline * 100
        if abs(pct) < 3 {
            return todayStr + ", in line with the 7-day average."
        }
        let direction = pct > 0 ? "above" : "below"
        return todayStr + ", \(Int(abs(pct)))% \(direction) the 7-day average of \(AIToolFormat.num(baseline, decimals))\(unit)."
    }

    /// 7-day baselines from the local store (today excluded), ignoring empty values.
    private struct Baseline {
        private let history: [DailyMetricEntity]

        init() {
            let calendar = Calendar.current
            let end = calendar.startOfDay(for: Date())
            let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
            history = LocalPersistenceManager.shared.fetchDailyMetrics(from: start, to: end)
        }

        func avg(_ keyPath: KeyPath<DailyMetricEntity, Int>) -> Double? {
            average(history.map { Double($0[keyPath: keyPath]) })
        }

        func avg(_ keyPath: KeyPath<DailyMetricEntity, Double>) -> Double? {
            average(history.map { $0[keyPath: keyPath] })
        }

        func avgOptional(_ keyPath: KeyPath<DailyMetricEntity, Double?>) -> Double? {
            average(history.compactMap { $0[keyPath: keyPath] })
        }

        func avgDouble(_ transform: (DailyMetricEntity) -> Double) -> Double? {
            average(history.map(transform))
        }

        private func average(_ values: [Double]) -> Double? {
            let nonZero = values.filter { $0 > 0 }
            guard !nonZero.isEmpty else { return nil }
            return nonZero.reduce(0, +) / Double(nonZero.count)
        }
    }

    private static func dayString(_ date: Date) -> String {
        AIToolFormat.makeDayFormatter().string(from: date)
    }
}
