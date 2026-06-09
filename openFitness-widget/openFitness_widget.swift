import WidgetKit
import SwiftUI
import Foundation

// MARK: - Shared Store (read-only — main app writes, widget reads via iCloud KV Store)
private struct SharedStore {
    private static var kv: NSUbiquitousKeyValueStore { .default }

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

// MARK: - Colours (mirrored from Theme.swift — no main-app import in extensions)
private enum WColor {
    static let background   = Color(red: 0.02,  green: 0.02,  blue: 0.02)
    static let card         = Color(red: 0.055, green: 0.055, blue: 0.055)
    static let mint         = Color(red: 0.063, green: 1.0,   blue: 0.667)
    static let purple       = Color(red: 0.482, green: 0.380, blue: 1.0)
    static let orange       = Color(red: 1.0,   green: 0.420, blue: 0.0)
    static let red          = Color(red: 1.0,   green: 0.216, blue: 0.373)

    static func scoreColor(for score: Int) -> Color {
        if score >= 80 { return mint }
        if score >= 60 { return purple }
        if score >= 40 { return orange }
        return red
    }
}

// MARK: - Timeline Entry
struct FitnessEntry: TimelineEntry {
    let date: Date
    let activenessScore: Int
    let recovery: Int
    let strain: Double
    let sleep: Int
    let steps: Int
    let calories: Double
    let hrv: Double
    let energyBank: Int
    let lastUpdated: Date?

    static var placeholder: FitnessEntry {
        FitnessEntry(date: Date(), activenessScore: 72, recovery: 68, strain: 5.5,
                     sleep: 81, steps: 7500, calories: 580, hrv: 45, energyBank: 76, lastUpdated: nil)
    }

    static var empty: FitnessEntry {
        FitnessEntry(date: Date(), activenessScore: 0, recovery: 0, strain: 0,
                     sleep: 0, steps: 0, calories: 0, hrv: 0, energyBank: 0, lastUpdated: nil)
    }
}

// MARK: - Provider
struct FitnessProvider: TimelineProvider {
    func placeholder(in context: Context) -> FitnessEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (FitnessEntry) -> Void) {
        completion(context.isPreview ? .placeholder : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FitnessEntry>) -> Void) {
        let entry = currentEntry()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func currentEntry() -> FitnessEntry {
        FitnessEntry(
            date: Date(),
            activenessScore: SharedStore.activenessScore,
            recovery:        SharedStore.recovery,
            strain:          SharedStore.strain,
            sleep:           SharedStore.sleep,
            steps:           SharedStore.steps,
            calories:        SharedStore.calories,
            hrv:             SharedStore.hrv,
            energyBank:      SharedStore.energyBank,
            lastUpdated:     SharedStore.lastUpdated
        )
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let entry: FitnessEntry

    private var score: Int { entry.activenessScore }
    private var scoreColor: Color { WColor.scoreColor(for: score) }
    private var label: String { SharedStore.classificationLabel(for: score) }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: score block
            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVENESS")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                Text("\(score)")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(scoreColor)
                    .lineLimit(1)
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                // Steps + calories
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk").font(.system(size: 10)).foregroundColor(WColor.mint)
                        Text(entry.steps == 0 ? "0 steps" : "\(entry.steps.formatted()) steps")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "flame").font(.system(size: 10)).foregroundColor(WColor.orange)
                        Text(entry.calories == 0 ? "0 cal" : "\(Int(entry.calories)) cal")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .frame(maxWidth: 130, maxHeight: .infinity, alignment: .leading)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.horizontal, 14)

            // Right: metric rows
            VStack(alignment: .leading, spacing: 0) {
                metricRow(icon: "heart.fill", label: "Recovery", value: "\(entry.recovery)%",                  color: WColor.mint)
                Divider().background(Color.white.opacity(0.06))
                metricRow(icon: "moon.fill",  label: "Sleep",    value: "\(entry.sleep)%",                     color: WColor.purple)
                Divider().background(Color.white.opacity(0.06))
                metricRow(icon: "flame.fill", label: "Strain",   value: String(format: "%.1f", entry.strain),  color: WColor.orange)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func metricRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Entry View Router
struct openFitness_widgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FitnessEntry

    var body: some View {
        MediumWidgetView(entry: entry)
            .containerBackground(WColor.background, for: .widget)
    }
}

// MARK: - Widget Definition
struct openFitness_widget: Widget {
    let kind: String = "openFitness_widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FitnessProvider()) { entry in
            openFitness_widgetEntryView(entry: entry)
        }
        .configurationDisplayName("openFitness")
        .description("Your daily activeness score, recovery, strain, and sleep at a glance.")
        .supportedFamilies([.systemMedium])
    }
}
