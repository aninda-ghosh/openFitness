import SwiftUI
import SwiftData
import BackgroundTasks
import WidgetKit
import HealthKit

@main
struct openFitnessApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .modelContainer(LocalPersistenceManager.shared.container)
                // Propagates to every ScrollView: screens whose content fits stay
                // fixed instead of rubber-banding when dragged
                .scrollBounceBehavior(.basedOnSize, axes: [.vertical, .horizontal])
        }
    }
}

// MARK: - AppDelegate
final class AppDelegate: NSObject, UIApplicationDelegate {
    private let healthStore = HKHealthStore()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        registerBGTasks()
        enableHealthKitBackgroundDelivery()
        return true
    }

    // MARK: - BGTask Registration
    private func registerBGTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "openFitness.bg.refresh",
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleNextRefresh()

        task.expirationHandler = { task.setTaskCompleted(success: false) }

        Task { @MainActor in
            let hkManager = HealthKitManager.shared
            // loadMetricsFromLocalStore already writes to SharedStore at end
            hkManager.loadMetricsFromLocalStore()
            WidgetCenter.shared.reloadAllTimelines()
            await MorningPulseNotifier.deliverIfDue(using: hkManager)
            task.setTaskCompleted(success: true)
        }
    }

    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "openFitness.bg.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - HealthKit Background Delivery
    // Wakes the app whenever new HRV, steps, or active energy data arrives.
    private func enableHealthKitBackgroundDelivery() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let typesToObserve: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .stepCount,
            .activeEnergyBurned,
        ]

        for identifier in typesToObserve {
            guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { continue }

            let query = HKObserverQuery(sampleType: quantityType, predicate: nil) { [weak self] _, completionHandler, error in
                guard error == nil else { completionHandler(); return }
                self?.handleHealthKitUpdate(completionHandler: completionHandler)
            }
            healthStore.execute(query)

            healthStore.enableBackgroundDelivery(for: quantityType, frequency: .immediate) { _, _ in }
        }
    }

    private func handleHealthKitUpdate(completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            let hkManager = HealthKitManager.shared
            hkManager.loadMetricsFromLocalStore() // writes SharedStore internally
            WidgetCenter.shared.reloadAllTimelines()
            await MorningPulseNotifier.deliverIfDue(using: hkManager)
            completionHandler()
        }
    }
}
