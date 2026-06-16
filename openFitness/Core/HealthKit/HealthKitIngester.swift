import Foundation
import HealthKit

public final class HealthKitIngester: Sendable {
    public static let shared = HealthKitIngester()
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    public func isHealthDataAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    public func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!,
            HKObjectType.workoutType(),
            HKObjectType.electrocardiogramType(),
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .vo2Max)!,
            HKObjectType.quantityType(forIdentifier: .bodyMassIndex)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead, completion: completion)
    }
    
    public func registerObserverQueries(onUpdate: @escaping (HKSampleType, @escaping () -> Void) -> Void) {
        let typesToObserve: [HKSampleType] = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]
        
        for sampleType in typesToObserve {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
                if let error = error {
                    print("HealthKitIngester: Observer query error for \(sampleType.identifier): \(error.localizedDescription)")
                    completionHandler()
                    return
                }
                onUpdate(sampleType, completionHandler)
            }
            healthStore.execute(query)
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { success, error in
                if !success {
                    print("HealthKitIngester: Failed to enable background delivery for \(sampleType.identifier): \(error?.localizedDescription ?? "")")
                }
            }
        }
    }
    
    public func syncSampleType(
        _ sampleType: HKSampleType,
        anchor: HKQueryAnchor?,
        completion: @escaping ([RawSample], [String], HKQueryAnchor?, Error?) -> Void
    ) {
        let typeId = sampleType.identifier
        var predicate: NSPredicate? = nil
        
        if anchor == nil {
            let calendar = Calendar.current
            let now = Date()
            
            let daysToSync: Int
            switch typeId {
            case HKQuantityTypeIdentifier.heartRate.rawValue,
                 HKQuantityTypeIdentifier.respiratoryRate.rawValue,
                 HKQuantityTypeIdentifier.oxygenSaturation.rawValue,
                 HKQuantityTypeIdentifier.bodyTemperature.rawValue,
                 HKQuantityTypeIdentifier.appleSleepingWristTemperature.rawValue:
                daysToSync = -7
            case HKQuantityTypeIdentifier.restingHeartRate.rawValue,
                 HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue,
                 HKCategoryTypeIdentifier.sleepAnalysis.rawValue,
                 HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
                 HKQuantityTypeIdentifier.stepCount.rawValue:
                daysToSync = -30
            case HKQuantityTypeIdentifier.bodyMass.rawValue,
                 HKQuantityTypeIdentifier.bodyFatPercentage.rawValue,
                 HKQuantityTypeIdentifier.bodyMassIndex.rawValue,
                 HKQuantityTypeIdentifier.vo2Max.rawValue:
                // Body composition readings are sparse (smart scale / manual entries),
                // so fetch the full retention window to populate historic charts
                daysToSync = -365
            default:
                daysToSync = -7
            }
            
            if let startDate = calendar.date(byAdding: .day, value: daysToSync, to: now) {
                predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
            }
        }
        
        let query = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: predicate,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { _, samples, deletedObjects, newAnchor, error in
            if let error = error {
                completion([], [], nil, error)
                return
            }
            
            let samplesToProcess = samples ?? []
            let deletedUUIDs = (deletedObjects ?? []).map { $0.uuid.uuidString }
            
            var rawSamples: [RawSample] = []
            for s in samplesToProcess {
                let uuid = s.uuid
                let start = s.startDate
                let end = s.endDate
                
                var value = 0.0
                var unitStr = ""
                
                if let quantitySample = s as? HKQuantitySample {
                    let unit = HealthKitIngester.defaultUnit(for: quantitySample.quantityType)
                    value = quantitySample.quantity.doubleValue(for: unit)
                    unitStr = unit.unitString
                } else if let categorySample = s as? HKCategorySample {
                    value = Double(categorySample.value)
                }
                
                let metadata = s.metadata
                let sourceName = s.sourceRevision.source.name
                let sourceBundleId = s.sourceRevision.source.bundleIdentifier
                rawSamples.append(RawSample(
                    id: uuid,
                    typeIdentifier: typeId,
                    startDate: start,
                    endDate: end,
                    value: value,
                    unitString: unitStr,
                    metadata: metadata,
                    sourceName: sourceName,
                    sourceBundleId: sourceBundleId
                ))
            }
            
            completion(rawSamples, deletedUUIDs, newAnchor, nil)
        }
        healthStore.execute(query)
    }
    
    public func fetchRawSamples(
        typeIdentifier: String,
        from startDate: Date,
        to endDate: Date,
        completion: @escaping ([RawSample]) -> Void
    ) {
        guard let sampleType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: typeIdentifier)) else {
            completion([])
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let quantitySamples = samples as? [HKQuantitySample] else {
                completion([])
                return
            }
            
            let unit = HealthKitIngester.defaultUnit(for: quantitySamples.first?.quantityType ?? sampleType)
            let mapped = quantitySamples.map { s in
                RawSample(
                    id: s.uuid,
                    typeIdentifier: typeIdentifier,
                    startDate: s.startDate,
                    endDate: s.endDate,
                    value: s.quantity.doubleValue(for: unit),
                    unitString: unit.unitString,
                    metadata: s.metadata,
                    sourceName: s.sourceRevision.source.name,
                    sourceBundleId: s.sourceRevision.source.bundleIdentifier
                )
            }
            completion(mapped)
        }
        healthStore.execute(query)
    }
    
    public func fetchStatisticsSum(
        typeIdentifier: String,
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Double) -> Void
    ) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: typeIdentifier)) else {
            completion(0.0)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let sum = result?.sumQuantity() {
                let unit = HealthKitIngester.defaultUnit(for: quantityType)
                completion(sum.doubleValue(for: unit))
            } else {
                completion(0.0)
            }
        }
        healthStore.execute(query)
    }
    
    public func fetchRawWorkouts(limit: Int, completion: @escaping ([RawWorkout]) -> Void) {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: nil, limit: limit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let workoutSamples = samples as? [HKWorkout] else {
                completion([])
                return
            }
            
            var workoutsList: [RawWorkout] = []
            for sample in workoutSamples {
                let duration = sample.duration / 60.0
                let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
                let calories = sample.statistics(for: activeEnergyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
                let avgHR = sample.statistics(for: heartRateType)?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0.0
                
                var distanceValue: Double? = nil
                var paceString: String? = nil
                if let distanceQty = sample.totalDistance {
                    let isSwimming = sample.workoutActivityType == .swimming
                    let unit = isSwimming ? HKUnit.yard() : HKUnit.mile()
                    distanceValue = distanceQty.doubleValue(for: unit)
                    
                    if let dist = distanceValue, dist > 0.01 {
                        let paceDecimal = duration / dist
                        let minutes = Int(paceDecimal)
                        let seconds = Int((paceDecimal - Double(minutes)) * 60)
                        let suffix = isSwimming ? "/yd" : "/mi"
                        paceString = String(format: "%d'%02d\" %@", minutes, seconds, suffix)
                    }
                }
                
                workoutsList.append(RawWorkout(
                    id: sample.uuid,
                    startDate: sample.startDate,
                    endDate: sample.endDate,
                    durationMinutes: duration,
                    activeCaloriesBurned: calories,
                    averageHeartRate: avgHR,
                    workoutActivityType: sample.workoutActivityType.rawValue,
                    name: sample.workoutActivityType.name,
                    distance: distanceValue,
                    paceString: paceString
                ))
            }
            completion(workoutsList)
        }
        healthStore.execute(query)
    }
    
    public func fetchRawECGSamples(completion: @escaping ([RawECG]) -> Void) {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: HKObjectType.electrocardiogramType(), predicate: nil, limit: 5, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let ecgSamples = samples as? [HKElectrocardiogram] else {
                completion([])
                return
            }
            
            let mapped = ecgSamples.map { s in
                RawECG(
                    id: s.uuid,
                    date: s.startDate,
                    averageHeartRate: s.averageHeartRate?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                    symptomsStatus: s.symptomsStatus.rawValue,
                    classification: s.classification.rawValue
                )
            }
            completion(mapped)
        }
        healthStore.execute(query)
    }
    
    public func fetchRawECGVoltageSamples(for ecgId: UUID, completion: @escaping ([Float]) -> Void) {
        // Query the HKElectrocardiogram sample matching the ID
        let predicate = HKQuery.predicateForObject(with: ecgId)
        let query = HKSampleQuery(sampleType: HKObjectType.electrocardiogramType(), predicate: predicate, limit: 1, sortDescriptors: nil) { [weak self] _, samples, _ in
            guard let self = self, let ecg = samples?.first as? HKElectrocardiogram else {
                completion([])
                return
            }
            
            var voltageValues: [Float] = []
            let ecgQuery = HKElectrocardiogramQuery(ecg) { _, result in
                switch result {
                case .measurement(let measurement):
                    if let voltage = measurement.quantity(for: .appleWatchSimilarToLeadI) {
                        let microvolts = voltage.doubleValue(for: HKUnit.voltUnit(with: .micro))
                        voltageValues.append(Float(microvolts))
                    }
                case .done:
                    completion(voltageValues)
                case .error(let error):
                    print("Error query ECG voltage: \(error.localizedDescription)")
                    completion([])
                @unknown default:
                    break
                }
            }
            self.healthStore.execute(ecgQuery)
        }
        healthStore.execute(query)
    }
    
    public func fetchBiologicalCharacteristics() -> (age: Int, biologicalSex: String) {
        var userAge = 30
        var userSex = "Unknown"
        
        if let dobComponents = try? healthStore.dateOfBirthComponents() {
            let calendar = Calendar.current
            let now = Date()
            if let dob = dobComponents.date,
               let ageComponents = calendar.dateComponents([.year], from: dob, to: now).year {
                userAge = ageComponents
            }
        }
        
        if let sexObject = try? healthStore.biologicalSex() {
            switch sexObject.biologicalSex {
            case .female:
                userSex = "Female"
            case .male:
                userSex = "Male"
            case .other:
                userSex = "Other"
            default:
                userSex = "Unknown"
            }
        }
        
        return (userAge, userSex)
    }
    
    // MARK: - Historical Query Fetchers
    
    public func fetchHistoricalActiveCalories(startDate: Date, completion: @escaping ([Date: Double]) -> Void) {
        guard let activeCalType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion([:])
            return
        }
        
        let calendar = Calendar.current
        var interval = DateComponents()
        interval.day = 1
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(
            quantityType: activeCalType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: calendar.startOfDay(for: startDate),
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, error in
            var dailySums: [Date: Double] = [:]
            guard let statsCollection = results else {
                completion([:])
                return
            }
            
            statsCollection.enumerateStatistics(from: startDate, to: Date()) { statistics, _ in
                let date = calendar.startOfDay(for: statistics.startDate)
                if let sum = statistics.sumQuantity() {
                    dailySums[date] = sum.doubleValue(for: .kilocalorie())
                }
            }
            completion(dailySums)
        }
        healthStore.execute(query)
    }
    
    public func fetchHistoricalRHR(startDate: Date, completion: @escaping ([Date: Double]) -> Void) {
        guard let rhrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            completion([:])
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: rhrType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            var dailyRHR: [Date: Double] = [:]
            guard let rhrSamples = samples as? [HKQuantitySample] else {
                completion([:])
                return
            }
            
            let calendar = Calendar.current
            let unit = HKUnit.count().unitDivided(by: .minute())
            for sample in rhrSamples {
                let date = calendar.startOfDay(for: sample.startDate)
                dailyRHR[date] = sample.quantity.doubleValue(for: unit)
            }
            completion(dailyRHR)
        }
        healthStore.execute(query)
    }
    
    public func fetchHistoricalHRV(startDate: Date, completion: @escaping ([Date: Double]) -> Void) {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion([:])
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            var dailyHRVs: [Date: [Double]] = [:]
            guard let hrvSamples = samples as? [HKQuantitySample] else {
                completion([:])
                return
            }
            
            let calendar = Calendar.current
            let unit = HKUnit.secondUnit(with: .milli)
            for sample in hrvSamples {
                let date = calendar.startOfDay(for: sample.startDate)
                let val = sample.quantity.doubleValue(for: unit)
                dailyHRVs[date, default: []].append(val)
            }
            
            var dailyHRV: [Date: Double] = [:]
            for (date, vals) in dailyHRVs {
                dailyHRV[date] = vals.reduce(0, +) / Double(vals.count)
            }
            completion(dailyHRV)
        }
        healthStore.execute(query)
    }
    
    public func fetchHistoricalSleep(startDate: Date, completion: @escaping ([Date: (duration: Double, deep: Double, rem: Double)]) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([:])
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            var dailySleepData: [Date: (duration: Double, deep: Double, rem: Double)] = [:]
            guard let sleepSamples = samples as? [HKCategorySample] else {
                completion([:])
                return
            }
            
            let calendar = Calendar.current
            var sleepDurations: [Date: TimeInterval] = [:]
            var deepDurations: [Date: TimeInterval] = [:]
            var remDurations: [Date: TimeInterval] = [:]
            
            for sample in sleepSamples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                let date = calendar.startOfDay(for: sample.endDate)
                
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    sleepDurations[date, default: 0] += duration
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    sleepDurations[date, default: 0] += duration
                    deepDurations[date, default: 0] += duration
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    sleepDurations[date, default: 0] += duration
                    remDurations[date, default: 0] += duration
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    sleepDurations[date, default: 0] += duration
                default:
                    break
                }
            }
            
            for date in sleepDurations.keys {
                let dur = sleepDurations[date] ?? 0
                let deep = deepDurations[date] ?? 0
                let rem = remDurations[date] ?? 0
                dailySleepData[date] = (dur / 3600.0, deep / 60.0, rem / 60.0)
            }
            completion(dailySleepData)
        }
        healthStore.execute(query)
    }
    
    public func fetchHistoricalWorkouts(startDate: Date, completion: @escaping ([Date: Double]) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            var dailyStrainTRIMP: [Date: Double] = [:]
            guard let workoutSamples = samples as? [HKWorkout] else {
                completion([:])
                return
            }
            
            let calendar = Calendar.current
            for sample in workoutSamples {
                let date = calendar.startOfDay(for: sample.startDate)
                let duration = sample.duration / 60.0
                let trimp = duration * 3.0
                dailyStrainTRIMP[date, default: 0.0] += trimp
            }
            completion(dailyStrainTRIMP)
        }
        healthStore.execute(query)
    }
    
    public func fetchHistoricalHeartRateStats(startDate: Date, completion: @escaping ([Date: (average: Double, max: Double)]) -> Void) {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion([:])
            return
        }
        
        let calendar = Calendar.current
        var interval = DateComponents()
        interval.day = 1
        
        let anchorDate = calendar.startOfDay(for: startDate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: hrType,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage, .discreteMax],
            anchorDate: anchorDate,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, error in
            var stats: [Date: (average: Double, max: Double)] = [:]
            guard let results = results else {
                completion([:])
                return
            }
            
            let endDate = Date()
            results.enumerateStatistics(from: anchorDate, to: endDate) { statistics, _ in
                let date = calendar.startOfDay(for: statistics.startDate)
                let avgUnit = HKUnit.count().unitDivided(by: .minute())
                
                var avgVal = 0.0
                var maxVal = 0.0
                
                if let avgQuantity = statistics.averageQuantity() {
                    avgVal = avgQuantity.doubleValue(for: avgUnit)
                }
                if let maxQuantity = statistics.maximumQuantity() {
                    maxVal = maxQuantity.doubleValue(for: avgUnit)
                }
                
                if avgVal > 0 || maxVal > 0 {
                    stats[date] = (average: avgVal, max: maxVal)
                }
            }
            completion(stats)
        }
        healthStore.execute(query)
    }
    
    public func fetchHistoricalAverage(
        typeIdentifier: String,
        startDate: Date,
        completion: @escaping ([Date: Double]) -> Void
    ) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: typeIdentifier)) else {
            completion([:])
            return
        }
        
        let calendar = Calendar.current
        var interval = DateComponents()
        interval.day = 1
        
        let anchorDate = calendar.startOfDay(for: startDate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: anchorDate,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, error in
            var dailyAverages: [Date: Double] = [:]
            guard let results = results else {
                completion([:])
                return
            }
            
            let unit = HealthKitIngester.defaultUnit(for: quantityType)
            results.enumerateStatistics(from: startDate, to: Date()) { statistics, _ in
                let date = calendar.startOfDay(for: statistics.startDate)
                if let avg = statistics.averageQuantity() {
                    let val = avg.doubleValue(for: unit)
                    if typeIdentifier == HKQuantityTypeIdentifier.oxygenSaturation.rawValue {
                        dailyAverages[date] = val * 100.0
                    } else {
                        dailyAverages[date] = val
                    }
                }
            }
            completion(dailyAverages)
        }
        healthStore.execute(query)
    }
    
    public func fetchHistoricalSum(
        typeIdentifier: String,
        startDate: Date,
        completion: @escaping ([Date: Double]) -> Void
    ) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: typeIdentifier)) else {
            completion([:])
            return
        }
        
        let calendar = Calendar.current
        var interval = DateComponents()
        interval.day = 1
        
        let anchorDate = calendar.startOfDay(for: startDate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: anchorDate,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, error in
            var dailySums: [Date: Double] = [:]
            guard let statsCollection = results else {
                completion([:])
                return
            }
            
            let unit = HealthKitIngester.defaultUnit(for: quantityType)
            statsCollection.enumerateStatistics(from: startDate, to: Date()) { statistics, _ in
                let date = calendar.startOfDay(for: statistics.startDate)
                if let sum = statistics.sumQuantity() {
                    dailySums[date] = sum.doubleValue(for: unit)
                }
            }
            completion(dailySums)
        }
        healthStore.execute(query)
    }
    
    public func fetchRawWorkouts(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping ([RawWorkout]) -> Void
    ) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let workoutSamples = samples as? [HKWorkout] else {
                completion([])
                return
            }
            
            var workoutsList: [RawWorkout] = []
            for sample in workoutSamples {
                let duration = sample.duration / 60.0
                let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
                let calories = sample.statistics(for: activeEnergyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
                let avgHR = sample.statistics(for: heartRateType)?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0.0
                
                var distanceValue: Double? = nil
                var paceString: String? = nil
                if let distanceQty = sample.totalDistance {
                    let isSwimming = sample.workoutActivityType == .swimming
                    let unit = isSwimming ? HKUnit.yard() : HKUnit.mile()
                    distanceValue = distanceQty.doubleValue(for: unit)
                    
                    if let dist = distanceValue, dist > 0.01 {
                        let paceDecimal = duration / dist
                        let minutes = Int(paceDecimal)
                        let seconds = Int((paceDecimal - Double(minutes)) * 60)
                        let suffix = isSwimming ? "/yd" : "/mi"
                        paceString = String(format: "%d'%02d\" %@", minutes, seconds, suffix)
                    }
                }
                
                workoutsList.append(RawWorkout(
                    id: sample.uuid,
                    startDate: sample.startDate,
                    endDate: sample.endDate,
                    durationMinutes: duration,
                    activeCaloriesBurned: calories,
                    averageHeartRate: avgHR,
                    workoutActivityType: sample.workoutActivityType.rawValue,
                    name: sample.workoutActivityType.name,
                    distance: distanceValue,
                    paceString: paceString
                ))
            }
            completion(workoutsList)
        }
        healthStore.execute(query)
    }
    
    // MARK: - Static Helpers
    
    private static func defaultUnit(for quantityType: HKQuantityType) -> HKUnit {
        switch quantityType.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            return HKUnit.count().unitDivided(by: .minute())
        case HKQuantityTypeIdentifier.restingHeartRate.rawValue:
            return HKUnit.count().unitDivided(by: .minute())
        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
            return HKUnit.secondUnit(with: .milli)
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            return HKUnit.kilocalorie()
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return HKUnit.count()
        case HKQuantityTypeIdentifier.respiratoryRate.rawValue:
            return HKUnit.count().unitDivided(by: .minute())
        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            return HKUnit.percent()
        case HKQuantityTypeIdentifier.bodyTemperature.rawValue, HKQuantityTypeIdentifier.appleSleepingWristTemperature.rawValue:
            return HKUnit.degreeCelsius()
        case HKQuantityTypeIdentifier.height.rawValue:
            return HKUnit.meterUnit(with: .centi)
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            return HKUnit.gramUnit(with: .kilo)
        case HKQuantityTypeIdentifier.bodyFatPercentage.rawValue:
            return HKUnit.percent()
        case HKQuantityTypeIdentifier.vo2Max.rawValue:
            return HKUnit(from: "ml/kg·min")
        case HKQuantityTypeIdentifier.bodyMassIndex.rawValue:
            return HKUnit.count()
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            return HKUnit.gramUnit(with: .kilo)
        default:
            return HKUnit.count()
        }
    }
}

extension HKWorkoutActivityType {
    public var name: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .pilates: return "Pilates"
        case .highIntensityIntervalTraining: return "HIIT"
        case .climbing: return "Climbing"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .dance: return "Dance"
        case .traditionalStrengthTraining: return "Traditional Strength"
        case .coreTraining: return "Core Training"
        case .crossTraining: return "Cross Training"
        case .tennis: return "Tennis"
        case .soccer: return "Soccer"
        case .basketball: return "Basketball"
        case .boxing: return "Boxing"
        case .golf: return "Golf"
        case .stairClimbing: return "Stair Climbing"
        case .snowboarding: return "Snowboarding"
        case .downhillSkiing: return "Downhill Skiing"
        case .crossCountrySkiing: return "Cross Country Skiing"
        case .martialArts: return "Martial Arts"
        case .kickboxing: return "Kickboxing"
        case .cooldown: return "Cooldown"
        case .mixedCardio: return "Mixed Cardio"
        case .barre: return "Barre"
        case .pickleball: return "Pickleball"
        case .badminton: return "Badminton"
        case .squash: return "Squash"
        case .tableTennis: return "Table Tennis"
        case .volleyball: return "Volleyball"
        case .bowling: return "Bowling"
        case .sailing: return "Sailing"
        case .skatingSports: return "Skating"
        case .fitnessGaming: return "Fitness Gaming"
        case .gymnastics: return "Gymnastics"
        case .handball: return "Handball"
        default: return "Workout"
        }
    }
}
