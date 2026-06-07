import Foundation
import SwiftData

@Model
final class SampleEntity {
    @Attribute(.unique) var uuid: String
    var typeIdentifier: String
    var startDate: Date
    var endDate: Date
    var value: Double
    var unitString: String
    var metadataJson: String?
    var sourceName: String?
    var sourceBundleId: String?
    
    init(
        uuid: String,
        typeIdentifier: String,
        startDate: Date,
        endDate: Date,
        value: Double,
        unitString: String,
        metadataJson: String? = nil,
        sourceName: String? = nil,
        sourceBundleId: String? = nil
    ) {
        self.uuid = uuid
        self.typeIdentifier = typeIdentifier
        self.startDate = startDate
        self.endDate = endDate
        self.value = value
        self.unitString = unitString
        self.metadataJson = metadataJson
        self.sourceName = sourceName
        self.sourceBundleId = sourceBundleId
    }
}

@Model
final class SyncAnchorEntity {
    @Attribute(.unique) var typeIdentifier: String
    var anchorData: Data
    var updatedAt: Date
    
    init(typeIdentifier: String, anchorData: Data, updatedAt: Date = Date()) {
        self.typeIdentifier = typeIdentifier
        self.anchorData = anchorData
        self.updatedAt = updatedAt
    }
}

@Model
final class DailyMetricEntity {
    @Attribute(.unique) var dateString: String // format "yyyy-MM-dd"
    var date: Date
    var recovery: Int
    var strain: Double
    var sleepScore: Int
    var stressAvg: Int
    var steps: Int
    var activeCalories: Double
    var hrv: Double?
    var rhr: Double?
    var sleepDuration: Double?
    var respiratoryRate: Double?
    var oxygenSaturation: Double?
    var bodyTemperature: Double?
    
    init(
        dateString: String,
        date: Date,
        recovery: Int,
        strain: Double,
        sleepScore: Int,
        stressAvg: Int,
        steps: Int,
        activeCalories: Double,
        hrv: Double? = nil,
        rhr: Double? = nil,
        sleepDuration: Double? = nil,
        respiratoryRate: Double? = nil,
        oxygenSaturation: Double? = nil,
        bodyTemperature: Double? = nil
    ) {
        self.dateString = dateString
        self.date = date
        self.recovery = recovery
        self.strain = strain
        self.sleepScore = sleepScore
        self.stressAvg = stressAvg
        self.steps = steps
        self.activeCalories = activeCalories
        self.hrv = hrv
        self.rhr = rhr
        self.sleepDuration = sleepDuration
        self.respiratoryRate = respiratoryRate
        self.oxygenSaturation = oxygenSaturation
        self.bodyTemperature = bodyTemperature
    }
}
