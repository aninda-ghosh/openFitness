import Foundation
import SwiftData

@MainActor
final class LocalPersistenceManager {
    static let shared = LocalPersistenceManager()
    
    let container: ModelContainer
    let context: ModelContext
    
    private init() {
        do {
            let schema = Schema([
                SampleEntity.self,
                SyncAnchorEntity.self,
                DailyMetricEntity.self
            ])
            
            // Configure file protection level natively on SQLite
            let config = ModelConfiguration(
                schema: schema,
                url: URL.documentsDirectory.appending(path: "openfitness.store"),
                allowsSave: true
            )
            
            self.container = try ModelContainer(for: schema, configurations: [config])
            self.context = ModelContext(container)
            self.context.autosaveEnabled = false
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Raw Sample Operations
    
    func saveSamples(_ samples: [SampleEntity]) {
        guard !samples.isEmpty else { return }
        
        let start = samples.map { $0.startDate }.min() ?? Date()
        let end = samples.map { $0.endDate }.max() ?? Date()
        let typeId = samples.first?.typeIdentifier ?? ""
        
        let descriptor = FetchDescriptor<SampleEntity>(
            predicate: #Predicate<SampleEntity> {
                $0.typeIdentifier == typeId &&
                $0.startDate >= start &&
                $0.startDate <= end
            }
        )
        
        let existingSamples = (try? context.fetch(descriptor)) ?? []
        let existingUUIDs = Set(existingSamples.map { $0.uuid })
        
        for sample in samples {
            if existingUUIDs.contains(sample.uuid) {
                continue
            }
            context.insert(sample)
        }
        
        do {
            try context.save()
        } catch {
            print("Error saving samples to database: \(error.localizedDescription)")
        }
    }
    
    func deleteSamples(withUUIDs uuids: [String]) {
        guard !uuids.isEmpty else { return }
        
        for uuidStr in uuids {
            let descriptor = FetchDescriptor<SampleEntity>(
                predicate: #Predicate<SampleEntity> { $0.uuid == uuidStr }
            )
            if let existing = try? context.fetch(descriptor) {
                for item in existing {
                    context.delete(item)
                }
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Error deleting samples: \(error.localizedDescription)")
        }
    }
    
    func fetchSamples(typeIdentifier: String, from startDate: Date, to endDate: Date) -> [SampleEntity] {
        let descriptor = FetchDescriptor<SampleEntity>(
            predicate: #Predicate<SampleEntity> {
                $0.typeIdentifier == typeIdentifier &&
                $0.startDate >= startDate &&
                $0.startDate <= endDate
            },
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    // MARK: - Daily Metric Operations
    
    func saveDailyMetric(_ metric: DailyMetricEntity) {
        let dateStr = metric.dateString
        let descriptor = FetchDescriptor<DailyMetricEntity>(
            predicate: #Predicate<DailyMetricEntity> { $0.dateString == dateStr }
        )
        
        if let existing = try? context.fetch(descriptor), let first = existing.first {
            first.recovery = metric.recovery
            first.strain = metric.strain
            first.sleepScore = metric.sleepScore
            first.stressAvg = metric.stressAvg
            first.steps = metric.steps
            first.activeCalories = metric.activeCalories
            first.date = metric.date
            first.hrv = metric.hrv
            first.rhr = metric.rhr
            first.sleepDuration = metric.sleepDuration
            first.respiratoryRate = metric.respiratoryRate
            first.oxygenSaturation = metric.oxygenSaturation
            first.bodyTemperature = metric.bodyTemperature
        } else {
            context.insert(metric)
        }
        
        do {
            try context.save()
        } catch {
            print("Error saving daily metric: \(error.localizedDescription)")
        }
    }
    
    func fetchDailyMetrics(from startDate: Date, to endDate: Date) -> [DailyMetricEntity] {
        let descriptor = FetchDescriptor<DailyMetricEntity>(
            predicate: #Predicate<DailyMetricEntity> {
                $0.date >= startDate &&
                $0.date <= endDate
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func clearDailyMetricsCache() {
        let descriptor = FetchDescriptor<DailyMetricEntity>()
        if let allMetrics = try? context.fetch(descriptor) {
            for metric in allMetrics {
                context.delete(metric)
            }
        }
        do {
            try context.save()
            print("LocalPersistenceManager: Successfully cleared daily metrics cache.")
        } catch {
            print("LocalPersistenceManager: Error clearing daily metrics cache: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sync Anchor Operations
    
    func saveAnchor(typeIdentifier: String, anchorData: Data) {
        let descriptor = FetchDescriptor<SyncAnchorEntity>(
            predicate: #Predicate<SyncAnchorEntity> { $0.typeIdentifier == typeIdentifier }
        )
        
        if let existing = try? context.fetch(descriptor), let first = existing.first {
            first.anchorData = anchorData
            first.updatedAt = Date()
        } else {
            context.insert(SyncAnchorEntity(typeIdentifier: typeIdentifier, anchorData: anchorData))
        }
        
        do {
            try context.save()
        } catch {
            print("Error saving sync anchor: \(error.localizedDescription)")
        }
    }
    
    func getAnchorData(typeIdentifier: String) -> Data? {
        let descriptor = FetchDescriptor<SyncAnchorEntity>(
            predicate: #Predicate<SyncAnchorEntity> { $0.typeIdentifier == typeIdentifier }
        )
        return (try? context.fetch(descriptor))?.first?.anchorData
    }
    
    // MARK: - Retention Purge
    
    /// Deletes raw samples and daily metrics older than 365 days to respect the 1-year data retention policy.
    func purgeOldData() {
        let calendar = Calendar.current
        let now = Date()
        guard let oneYearAgo = calendar.date(byAdding: .day, value: -365, to: now) else { return }
        
        // Fetch and delete SampleEntity samples older than 365 days
        let sampleDescriptor = FetchDescriptor<SampleEntity>(
            predicate: #Predicate<SampleEntity> { $0.startDate < oneYearAgo }
        )
        if let oldSamples = try? context.fetch(sampleDescriptor) {
            for sample in oldSamples {
                context.delete(sample)
            }
        }
        
        // Fetch and delete DailyMetricEntity metrics older than 365 days
        let metricDescriptor = FetchDescriptor<DailyMetricEntity>(
            predicate: #Predicate<DailyMetricEntity> { $0.date < oneYearAgo }
        )
        if let oldMetrics = try? context.fetch(metricDescriptor) {
            for metric in oldMetrics {
                context.delete(metric)
            }
        }
        
        do {
            try context.save()
            print("LocalPersistenceManager: Successfully purged records older than 1 year.")
        } catch {
            print("Lo80calPersistenceManager: Error saving context after retention purge: \(error.localizedDescription)")
        }
    }
}
