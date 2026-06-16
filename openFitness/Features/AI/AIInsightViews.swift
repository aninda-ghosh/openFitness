import SwiftUI

// MARK: - Markdown rendering

/// The on-device model emits inline markdown (**bold**, *italic*). This renders it
/// while keeping line breaks, falling back to plain text if parsing fails.
/// Parsing is cached: SwiftUI re-evaluates chat bubbles on every keystroke and
/// streaming tick, and re-parsing every message each time lags the keyboard.
struct MarkdownText: View {
    let text: String
    var font: Font = Theme.Typography.body
    var color: Color = .white.opacity(0.9)

    @MainActor
    private static var cache: [String: AttributedString] = [:]

    var body: some View {
        Text(Self.attributed(text))
            .font(font)
            .foregroundColor(color)
            .lineSpacing(3)
    }

    @MainActor
    private static func attributed(_ text: String) -> AttributedString {
        if let cached = cache[text] { return cached }
        let parsed = (try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
        // Streaming inserts a new partial string every tick; keep the cache bounded
        if cache.count > 200 { cache.removeAll() }
        cache[text] = parsed
        return parsed
    }
}

// MARK: - Daily Pulse bubble (dashboard)

/// AI-generated daily nudge. Renders nothing when Apple Intelligence is unavailable.
struct DailyPulseCard: View {
    @ObservedObject var hkManager: HealthKitManager
    @State private var pulse: DailyPulse?
    @State private var failed = false
    @State private var showingCoach = false

    var body: some View {
        Group {
            if let pulse {
                Button(action: { showingCoach = true }) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.Colors.recoveryHigh)
                            Text(pulse.headline.uppercased())
                                .font(Theme.Typography.cardTitle)
                                .foregroundColor(.white.opacity(0.85))
                            Spacer()
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.25))
                        }
                        Text(pulse.message)
                            .font(Theme.Typography.callout)
                            .foregroundColor(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    .glassCard(cornerRadius: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.Colors.recoveryHigh.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(TactileButtonStyle())
                .sheet(isPresented: $showingCoach) {
                    AskCoachView()
                }
            } else if AIInsightEngine.isAvailable && !failed && hasData {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.recoveryHigh.opacity(0.6))
                    Text("Reading your day…")
                        .font(Theme.Typography.labelSM)
                        .foregroundColor(.white.opacity(0.35))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .task(id: hasData) {
            guard AIInsightEngine.isAvailable, pulse == nil, hasData else { return }
            do {
                pulse = try await AIInsightEngine.shared.dailyPulse()
                // The user has seen today's pulse; don't notify about it later
                MorningPulseNotifier.markSeenToday()
            } catch {
                failed = true
            }
        }
    }

    // Wait until the first metrics load lands so the nudge isn't written from zeros
    private var hasData: Bool {
        hkManager.todaySteps > 0 || hkManager.todayRecovery > 0 || hkManager.todayStrain > 0
    }
}

// MARK: - Floating coach bubble

/// Persistent glass bubble that floats above all screens and opens Ask Coach.
/// Hidden entirely on devices without Apple Intelligence.
struct AskCoachFloatingButton: View {
    @State private var showingCoach = false

    var body: some View {
        if AIInsightEngine.isAvailable {
            Button(action: { showingCoach = true }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.Colors.recoveryHigh)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(TactileButtonStyle())
            .glassEffect(.regular.interactive(), in: .circle)
            .shadow(color: Theme.Colors.recoveryHigh.opacity(0.25), radius: 14, x: 0, y: 4)
            .padding(.trailing, 20)
            .padding(.bottom, 28)
            .sheet(isPresented: $showingCoach) {
                AskCoachView()
            }
        }
    }
}

// MARK: - Metric insight card (deep-dive views)

/// "What happened and how to improve" for one metric. Renders nothing when
/// Apple Intelligence is unavailable.
struct MetricInsightCard: View {
    let metric: InsightMetric
    @ObservedObject var hkManager: HealthKitManager
    @State private var insight: MetricInsight?
    @State private var failed = false
    @State private var showingCoach = false

    var body: some View {
        if AIInsightEngine.isAvailable && !failed {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.recoveryHigh)
                    Text("AI INSIGHTS")
                        .font(Theme.Typography.cardTitle)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("ON-DEVICE")
                        .font(Theme.Typography.tick)
                        .foregroundColor(.white.opacity(0.25))
                }

                if let insight {
                    MarkdownText(
                        text: insight.summary,
                        font: Theme.Typography.body,
                        color: .white.opacity(0.85)
                    )
                    .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(insight.suggestions.enumerated()), id: \.offset) { _, suggestion in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "arrow.up.right.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.Colors.recoveryHigh.opacity(0.8))
                                    .padding(.top, 2)
                                MarkdownText(
                                    text: suggestion,
                                    font: Theme.Typography.callout,
                                    color: .white.opacity(0.65)
                                )
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 11))
                        Text("Ask Coach about this")
                            .font(Theme.Typography.labelSM)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Theme.Colors.recoveryHigh.opacity(0.8))
                    .padding(.top, 2)
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(Theme.Colors.recoveryHigh)
                            .scaleEffect(0.8)
                        Text("Analyzing your \(metric.displayName.lowercased()) data…")
                            .font(Theme.Typography.callout)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.vertical, 4)
                }
            }
            .glassCard()
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onTapGesture {
                if insight != nil { showingCoach = true }
            }
            .sheet(isPresented: $showingCoach) {
                AskCoachView(focus: metric)
            }
            .task {
                guard insight == nil else { return }
                do {
                    insight = try await AIInsightEngine.shared.metricInsight(for: metric, hkManager: hkManager)
                } catch {
                    failed = true
                }
            }
        }
    }
}
