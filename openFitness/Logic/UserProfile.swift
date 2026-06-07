import Foundation

public struct UserProfile: Sendable {
    public let age: Int
    public let biologicalSex: String
    public let heightCm: Double
    public let weightKg: Double
    public let sleepNeedHours: Double

    public init(age: Int, biologicalSex: String, heightCm: Double, weightKg: Double, sleepNeedHours: Double = 8.0) {
        self.age = age
        self.biologicalSex = biologicalSex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.sleepNeedHours = sleepNeedHours
    }
    
    /// Returns default profile settings for fallback purposes
    public static var `default`: UserProfile {
        UserProfile(
            age: 30,
            biologicalSex: "Unknown",
            heightCm: 175.0,
            weightKg: 70.0,
            sleepNeedHours: 8.0
        )
    }
}
