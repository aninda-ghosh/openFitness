import Foundation

/// Shared storage between the main app and the widget extension via iCloud Key-Value Store.
/// Works on free Apple Developer accounts. Changes sync within seconds on the same device.
struct SharedStore {
    private static var kv: NSUbiquitousKeyValueStore { .default }

    // MARK: - Write (called from main app after every metrics load)
    static func save(
        activenessScore: Int,
        recovery: Int,
        strain: Double,
        sleep: Int,
        steps: Int,
        calories: Double,
        hrv: Double,
        rhr: Double,
        energyBank: Int,
        stressAvg: Int
    ) {
        kv.set(Int64(activenessScore), forKey: "activenessScore")
        kv.set(Int64(recovery),        forKey: "recovery")
        kv.set(strain,                 forKey: "strain")
        kv.set(Int64(sleep),           forKey: "sleep")
        kv.set(Int64(steps),           forKey: "steps")
        kv.set(calories,               forKey: "calories")
        kv.set(hrv,                    forKey: "hrv")
        kv.set(rhr,                    forKey: "rhr")
        kv.set(Int64(energyBank),      forKey: "energyBank")
        kv.set(Int64(stressAvg),       forKey: "stressAvg")
        kv.set(Date(),                 forKey: "lastUpdated")
        kv.synchronize()
    }

    // MARK: - Read
    static var activenessScore: Int { Int(kv.longLong(forKey: "activenessScore")) }
    static var recovery: Int        { Int(kv.longLong(forKey: "recovery")) }
    static var strain: Double       { kv.double(forKey: "strain") }
    static var sleep: Int           { Int(kv.longLong(forKey: "sleep")) }
    static var steps: Int           { Int(kv.longLong(forKey: "steps")) }
    static var calories: Double     { kv.double(forKey: "calories") }
    static var hrv: Double          { kv.double(forKey: "hrv") }
    static var rhr: Double          { kv.double(forKey: "rhr") }
    static var energyBank: Int      { Int(kv.longLong(forKey: "energyBank")) }
    static var stressAvg: Int       { Int(kv.longLong(forKey: "stressAvg")) }
    static var lastUpdated: Date?   { kv.object(forKey: "lastUpdated") as? Date }

    // MARK: - Classification helpers (duplicated here so widget doesn't need main app)
    static func classificationLabel(for score: Int) -> String {
        if score >= 80 { return "Peak Form" }
        if score >= 60 { return "Well Balanced" }
        if score >= 40 { return "Moderate" }
        return "Rest Needed"
    }

    static func strainLabel(for strain: Double) -> String {
        if strain >= 14 { return "High" }
        if strain >= 8  { return "Moderate" }
        if strain > 0   { return "Light" }
        return "Rest"
    }
}
