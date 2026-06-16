import Foundation
import FoundationModels

// MARK: - Live data source

/// The dashboard owns the live HealthKitManager instance (it is not the `.shared`
/// singleton, which only background tasks use). It registers itself here so the
/// AI tools and insight engine read the same data the UI shows.
@MainActor
enum AIDataSource {
    static weak var hkManager: HealthKitManager?

    static var manager: HealthKitManager {
        hkManager ?? HealthKitManager.shared
    }

    static func todaySummary() -> String {
        let hk = manager
        var lines: [String] = []
        lines.append("Recovery: \(hk.todayRecovery)% (yesterday \(hk.yesterdayRecovery)%)")
        lines.append("Strain: \(AIToolFormat.num(hk.todayStrain)) of 21")
        // Pre-compute the surplus/deficit: the model cannot do arithmetic reliably
        let sleepDelta = hk.todaySleepHours - hk.todaySleepNeeded
        let sleepDeltaStr = abs(sleepDelta) < 0.05
            ? "need met exactly"
            : sleepDelta > 0
                ? "\(AIToolFormat.num(sleepDelta))h more than needed"
                : "\(AIToolFormat.num(-sleepDelta))h less than needed"
        lines.append("Sleep: \(AIToolFormat.num(hk.todaySleepHours))h of \(AIToolFormat.num(hk.todaySleepNeeded))h needed (\(sleepDeltaStr)), score \(hk.todaySleepScore)% (yesterday \(hk.yesterdaySleepScore)%, \(AIToolFormat.num(hk.yesterdaySleepHours))h)")
        lines.append("Sleep stages: deep \(Int(hk.todayDeepMinutes))min, REM \(Int(hk.todayRemMinutes))min")
        lines.append("Stress: avg \(hk.todayStressAverage), range \(hk.todayStressLowest)-\(hk.todayStressHighest) (0-100 scale)")
        lines.append("Energy bank: \(hk.energyBank)% (started day at \(hk.energyBankStart)%, charged \(hk.energyBankCharged)%, drained \(hk.energyBankDrained)%)")
        lines.append("Activity: \(hk.todaySteps) steps, \(Int(hk.todayActiveCalories)) active kcal")
        lines.append("Heart: HRV \(AIToolFormat.num(hk.todayHRV))ms, resting HR \(AIToolFormat.num(hk.todayRHR, 0))bpm, avg HR \(AIToolFormat.num(hk.todayAverageHR, 0))bpm, max HR \(AIToolFormat.num(hk.todayMaxHR, 0))bpm")
        if hk.todayRespiratoryRate > 0 {
            lines.append("Respiratory rate: \(AIToolFormat.num(hk.todayRespiratoryRate)) breaths/min")
        }
        if hk.todayOxygenSaturation > 0 {
            lines.append("Blood oxygen: \(AIToolFormat.num(hk.todayOxygenSaturation))%")
        }
        if hk.todayVO2Max > 0 {
            lines.append("VO2 max: \(AIToolFormat.num(hk.todayVO2Max))")
        }
        if hk.todayWeight > 0 {
            lines.append("Weight: \(AIToolFormat.num(hk.todayWeight)) lb, BMI \(AIToolFormat.num(hk.todayBMI))")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Shared formatting helpers

// Used from both MainActor views and nonisolated tool calls, so each member is
// nonisolated and the (non-Sendable) formatter is created per call
enum AIToolFormat {
    nonisolated static func makeDayFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    nonisolated static func parseDay(_ string: String) -> Date? {
        makeDayFormatter().date(from: string)
    }

    nonisolated static func num(_ value: Double, _ decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", value)
    }
}

// MARK: - Today Snapshot

/// Current-day metrics straight from HealthKitManager's published state.
struct TodaySnapshotTool: Tool {
    let name = "getTodaySnapshot"
    let description = """
        Get the user's metrics for today (right now): recovery, strain, sleep, stress, \
        energy bank, steps, calories, HRV, resting heart rate and vitals. \
        Also includes yesterday's recovery and sleep for comparison.
        """

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            AIDataSource.todaySummary()
        }
    }
}

// MARK: - Daily History

/// Per-day metric history from the local SwiftData store.
struct DailyHistoryTool: Tool {
    let name = "getDailyHistory"
    let description = """
        Get per-day historical metrics (recovery, strain, sleep, stress, steps, calories, \
        HRV, resting heart rate) for a date range. Use for trends, comparisons and questions \
        about past days or weeks. Maximum range is 35 days per call.
        """

    @Generable
    struct Arguments {
        @Guide(description: "First day of the range, formatted yyyy-MM-dd")
        var startDate: String

        @Guide(description: "Last day of the range (inclusive), formatted yyyy-MM-dd")
        var endDate: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let start = AIToolFormat.parseDay(arguments.startDate),
              let end = AIToolFormat.parseDay(arguments.endDate) else {
            return "Invalid dates. Use yyyy-MM-dd format, e.g. 2026-06-03."
        }

        // Keep tool output small enough for the on-device context window
        let calendar = Calendar.current
        let clampedStart = max(start, calendar.date(byAdding: .day, value: -34, to: end) ?? start)
        let endOfRange = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end

        return await MainActor.run {
            let metrics = LocalPersistenceManager.shared.fetchDailyMetrics(from: clampedStart, to: endOfRange)
            guard !metrics.isEmpty else {
                return "No data recorded between \(arguments.startDate) and \(arguments.endDate)."
            }

            var lines: [String] = []
            for m in metrics {
                var parts: [String] = []
                parts.append("recovery \(m.recovery)%")
                parts.append("strain \(AIToolFormat.num(m.strain))")
                if let sleep = m.sleepDuration, sleep > 0 {
                    parts.append("sleep \(AIToolFormat.num(sleep))h (score \(m.sleepScore)%)")
                }
                parts.append("stress \(m.stressAvg)")
                parts.append("\(m.steps) steps")
                parts.append("\(Int(m.activeCalories)) kcal")
                if let hrv = m.hrv, hrv > 0 { parts.append("HRV \(AIToolFormat.num(hrv))ms") }
                if let rhr = m.rhr, rhr > 0 { parts.append("RHR \(AIToolFormat.num(rhr, 0))bpm") }
                lines.append("\(m.dateString): " + parts.joined(separator: ", "))
            }

            // Pre-computed averages so the model never aggregates numbers itself
            func avg(_ values: [Double]) -> Double? {
                let v = values.filter { $0 > 0 }
                return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
            }
            var avgParts: [String] = []
            if let v = avg(metrics.map { Double($0.recovery) }) { avgParts.append("recovery \(Int(v))%") }
            if let v = avg(metrics.map(\.strain)) { avgParts.append("strain \(AIToolFormat.num(v))") }
            if let v = avg(metrics.compactMap(\.sleepDuration)) { avgParts.append("sleep \(AIToolFormat.num(v))h") }
            if let v = avg(metrics.map { Double($0.sleepScore) }) { avgParts.append("sleep score \(Int(v))%") }
            if let v = avg(metrics.map { Double($0.steps) }) { avgParts.append("\(Int(v)) steps") }
            if let v = avg(metrics.map(\.activeCalories)) { avgParts.append("\(Int(v)) kcal") }
            if !avgParts.isEmpty {
                lines.append("Averages for this range: " + avgParts.joined(separator: ", ") + ".")
            }

            return lines.joined(separator: "\n")
        }
    }
}

// MARK: - Workouts

/// Workout sessions pulled from HealthKit for a date range.
struct WorkoutsTool: Tool {
    let name = "getWorkouts"
    let description = """
        Get the user's workouts in a date range: type, date, duration, calories, \
        average heart rate, and distance/pace where available. Use for questions about \
        training, exercise sessions, runs, rides, or workout frequency.
        """

    @Generable
    struct Arguments {
        @Guide(description: "First day of the range, formatted yyyy-MM-dd")
        var startDate: String

        @Guide(description: "Last day of the range (inclusive), formatted yyyy-MM-dd")
        var endDate: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let start = AIToolFormat.parseDay(arguments.startDate),
              let end = AIToolFormat.parseDay(arguments.endDate) else {
            return "Invalid dates. Use yyyy-MM-dd format, e.g. 2026-06-03."
        }
        let calendar = Calendar.current
        let endOfRange = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end

        let workouts = await withCheckedContinuation { continuation in
            HealthKitIngester.shared.fetchRawWorkouts(from: start, to: endOfRange) { result in
                continuation.resume(returning: result)
            }
        }

        guard !workouts.isEmpty else {
            return "No workouts recorded between \(arguments.startDate) and \(arguments.endDate)."
        }

        let dayFormatter = AIToolFormat.makeDayFormatter()
        // Newest first from the query; cap output to protect the context window
        let lines = workouts.prefix(20).map { w -> String in
            var parts: [String] = []
            parts.append("\(Int(w.durationMinutes))min")
            if w.activeCaloriesBurned > 0 { parts.append("\(Int(w.activeCaloriesBurned)) kcal") }
            if w.averageHeartRate > 0 { parts.append("avg HR \(Int(w.averageHeartRate))bpm") }
            if let distance = w.distance, distance > 0.01 {
                parts.append("\(AIToolFormat.num(distance, 2)) mi")
            }
            if let pace = w.paceString { parts.append(pace) }
            return "\(dayFormatter.string(from: w.startDate)) \(w.name): " + parts.joined(separator: ", ")
        }

        var result = lines.joined(separator: "\n")
        if workouts.count > 20 {
            result += "\n(\(workouts.count - 20) more workouts omitted)"
        }
        return result
    }
}
