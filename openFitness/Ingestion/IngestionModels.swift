import Foundation

public struct RawSample: Sendable, Identifiable {
    public let id: UUID
    public let typeIdentifier: String
    public let startDate: Date
    public let endDate: Date
    public let value: Double
    public let unitString: String
    public let metadata: [String: Any]?
    public let sourceName: String?
    public let sourceBundleId: String?

    public init(
        id: UUID = UUID(),
        typeIdentifier: String,
        startDate: Date,
        endDate: Date,
        value: Double,
        unitString: String,
        metadata: [String: Any]? = nil,
        sourceName: String? = nil,
        sourceBundleId: String? = nil
    ) {
        self.id = id
        self.typeIdentifier = typeIdentifier
        self.startDate = startDate
        self.endDate = endDate
        self.value = value
        self.unitString = unitString
        self.metadata = metadata
        self.sourceName = sourceName
        self.sourceBundleId = sourceBundleId
    }
}

public struct RawWorkout: Sendable, Identifiable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date
    public let durationMinutes: Double
    public let activeCaloriesBurned: Double
    public let averageHeartRate: Double
    public let workoutActivityType: UInt
    public let name: String
    public let distance: Double?
    public let paceString: String?

    public init(id: UUID = UUID(), startDate: Date, endDate: Date, durationMinutes: Double, activeCaloriesBurned: Double, averageHeartRate: Double, workoutActivityType: UInt, name: String, distance: Double? = nil, paceString: String? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.durationMinutes = durationMinutes
        self.activeCaloriesBurned = activeCaloriesBurned
        self.averageHeartRate = averageHeartRate
        self.workoutActivityType = workoutActivityType
        self.name = name
        self.distance = distance
        self.paceString = paceString
    }
}

public struct RawECG: Sendable, Identifiable {
    public let id: UUID
    public let date: Date
    public let averageHeartRate: Double?
    public let symptomsStatus: Int
    public let classification: Int

    public init(id: UUID = UUID(), date: Date, averageHeartRate: Double?, symptomsStatus: Int, classification: Int) {
        self.id = id
        self.date = date
        self.averageHeartRate = averageHeartRate
        self.symptomsStatus = symptomsStatus
        self.classification = classification
    }
}
