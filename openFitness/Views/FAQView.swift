import SwiftUI

struct FAQView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var expandedIndex: Int? = nil

    private struct FAQItem {
        let question: String
        let answer: String
        let icon: String
        let color: Color
    }

    private struct FAQSection {
        let title: String
        let items: [FAQItem]
    }

    private let sections: [FAQSection] = [
        FAQSection(title: "Getting Started", items: [
            FAQItem(
                question: "What data does openFitness use?",
                answer: "openFitness reads heart rate, resting heart rate, HRV, sleep analysis, active energy, steps, respiratory rate, SpO₂, body temperature, workouts, and ECG from Apple Health. The app is read-only — it never writes to Health.",
                icon: "heart.text.square.fill",
                color: Theme.Colors.recoveryHigh
            ),
            FAQItem(
                question: "Do I need an Apple Watch?",
                answer: "Strongly recommended. HRV, resting heart rate, sleep stages, wrist temperature, and ECG are only recorded by Apple Watch. Without it, Recovery and Sleep scores will be limited and the Activeness Score won't calibrate.",
                icon: "applewatch",
                color: Theme.Colors.sleepDeep
            ),
            FAQItem(
                question: "Why does the app show no data?",
                answer: "Go to Settings → Privacy & Security → Health → openFitness and confirm all categories are enabled. If you denied permission at first launch, delete and reinstall to get the prompt again.",
                icon: "lock.shield",
                color: Theme.Colors.strainHigh
            )
        ]),
        FAQSection(title: "Scores", items: [
            FAQItem(
                question: "How is Recovery calculated?",
                answer: "HRV and resting heart rate are each scored as Z-scores against your rolling 21-day personal baseline (60% HRV, 40% RHR). Higher HRV and lower RHR relative to your norm produces a higher score.",
                icon: "heart.fill",
                color: Theme.Colors.recoveryHigh
            ),
            FAQItem(
                question: "What does the Strain Score mean?",
                answer: "Strain (0–21) is cardiovascular training load via the Edwards TRIMP method — workout duration × heart-rate zone multiplier, mapped logarithmically. 0–7 is light, 8–13 moderate, 14–17 high, 18+ extreme.",
                icon: "flame.fill",
                color: Theme.Colors.strainHigh
            ),
            FAQItem(
                question: "How is Sleep Score calculated?",
                answer: "Duration vs. need (40 pts) + deep sleep vs. 90 min target (30 pts) + REM vs. 90 min target (20 pts) + nocturnal HR dip of 10–20% (10 pts). Wear your Watch to bed for stage data.",
                icon: "moon.fill",
                color: Theme.Colors.sleepDeep
            ),
            FAQItem(
                question: "What is the Activeness Score?",
                answer: "A weighted composite: Recovery 25%, Strain Balance 20%, Sleep 20%, Activity 15%, HRV Trend 10%, Stress 10%. Unlocks after 21 days of HRV + RHR data. Tap ⓘ on the card for the full formula.",
                icon: "bolt.fill",
                color: Theme.Colors.recoveryHigh
            ),
            FAQItem(
                question: "Why is strain ~11 the ideal, not higher?",
                answer: "Chronic overtraining is as harmful as under-training. The bell-curve (Gaussian centred at 11, spread 4) rewards sustainable moderate effort and penalises both sedentary days and excessive overload.",
                icon: "chart.xyaxis.line",
                color: Theme.Colors.strainHigh
            )
        ]),
        FAQSection(title: "Vitals & ECG", items: [
            FAQItem(
                question: "What is HRV and why does it matter?",
                answer: "HRV measures variation between heartbeats (ms). Higher HRV indicates better autonomic nervous system function and recovery capacity. openFitness uses SDNN — the metric Apple Watch records.",
                icon: "waveform.path.ecg",
                color: Theme.Colors.sleepDeep
            ),
            FAQItem(
                question: "How do I view an ECG recording?",
                answer: "Take an ECG on your Watch, confirm it synced in the Health app, then tap the ECG card on the Dashboard. The waveform renders on a clinical grid. Use the amplitude slider if the trace looks flat.",
                icon: "waveform",
                color: Theme.Colors.recoveryLow
            ),
            FAQItem(
                question: "Why are Respiratory Rate, SpO₂, or Temperature missing?",
                answer: "These are passively recorded during sleep by Apple Watch Series 8+ or Ultra. Wear your Watch to bed and ensure background measurements are on in the Health app. The app looks back 48 hours for each vital.",
                icon: "lungs.fill",
                color: Theme.Colors.recoveryMid
            )
        ]),
        FAQSection(title: "Privacy & Data", items: [
            FAQItem(
                question: "Does openFitness send data anywhere?",
                answer: "No. Everything runs on-device. There are no servers, analytics, or SDKs of any kind. Your health data never leaves your iPhone.",
                icon: "lock.fill",
                color: Theme.Colors.recoveryHigh
            ),
            FAQItem(
                question: "Where is calibration data stored?",
                answer: "HRV/RHR mean and standard deviation are saved in UserDefaults on your device. They update automatically whenever 3+ days of history exist and the new sample count exceeds the previous save.",
                icon: "internaldrive",
                color: Theme.Colors.sleepDeep
            )
        ])
    ]

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    // ── Header ───────────────────────────────────────────
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Help & FAQ")
                                .font(Theme.Typography.metricLabel(size: 22))
                                .foregroundColor(.white)
                            Text("How openFitness works")
                                .font(Theme.Typography.roundedFont(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        Spacer()
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }

                    // ── Sections ─────────────────────────────────────────
                    ForEach(Array(sections.enumerated()), id: \.element.title) { sIdx, section in
                        VStack(alignment: .leading, spacing: 10) {

                            // Section label — sits above its card
                            Text(section.title.uppercased())
                                .font(Theme.Typography.roundedFont(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.35))
                                .tracking(0.8)
                                .padding(.leading, 4)

                            // Items card
                            VStack(spacing: 0) {
                                ForEach(Array(section.items.enumerated()), id: \.element.question) { iIdx, item in
                                    let globalIndex = sIdx * 100 + iIdx
                                    let isExpanded = expandedIndex == globalIndex

                                    VStack(spacing: 0) {
                                        // Row tap target
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                expandedIndex = isExpanded ? nil : globalIndex
                                            }
                                        }) {
                                            HStack(alignment: .center, spacing: 12) {
                                                // Icon bubble
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .fill(item.color.opacity(0.14))
                                                        .frame(width: 34, height: 34)
                                                    Image(systemName: item.icon)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(item.color)
                                                }

                                                Text(item.question)
                                                    .font(Theme.Typography.roundedFont(size: 14, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .multilineTextAlignment(.leading)
                                                    .frame(maxWidth: .infinity, alignment: .leading)

                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(.white.opacity(0.25))
                                                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 13)
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                        // Expanded answer
                                        if isExpanded {
                                            Text(item.answer)
                                                .font(Theme.Typography.roundedFont(size: 13, weight: .regular))
                                                .foregroundColor(.white.opacity(0.55))
                                                .fixedSize(horizontal: false, vertical: true)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.top, 2)
                                                .padding(.horizontal, 14)
                                                .padding(.bottom, 14)
                                                .background(Color.white.opacity(0.02))
                                        }

                                        // Divider (not between last item and card edge)
                                        if iIdx < section.items.count - 1 {
                                            Rectangle()
                                                .fill(Color.white.opacity(0.06))
                                                .frame(height: 0.5)
                                                .padding(.leading, 60)
                                        }
                                    }
                                }
                            }
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                            )
                        }
                    }

                    // ── About ────────────────────────────────────────────
                    VStack(spacing: 20) {
                        // App icon + name
                        VStack(spacing: 10) {
                            Image("OpenFitness-App-Logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .cornerRadius(14)
                                .shadow(color: Theme.Colors.recoveryHigh.opacity(0.25), radius: 10, x: 0, y: 4)

                            VStack(spacing: 3) {
                                Text("openFitness")
                                    .font(Theme.Typography.roundedFont(size: 18, weight: .bold))
                                    .foregroundColor(.white)

                                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                                    .font(Theme.Typography.roundedFont(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Divider().background(Color.white.opacity(0.06))

                        // Author row
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AUTHOR")
                                    .font(Theme.Typography.roundedFont(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.3))
                                    .tracking(0.6)
                                Text("Aninda Ghosh")
                                    .font(Theme.Typography.roundedFont(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.recoveryHigh.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Text("AG")
                                    .font(Theme.Typography.roundedFont(size: 13, weight: .bold))
                                    .foregroundColor(Theme.Colors.recoveryHigh)
                            }
                        }

                        Divider().background(Color.white.opacity(0.06))

                        // Privacy note
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.recoveryHigh)
                            Text("All calculations run on-device. No data ever leaves your iPhone.")
                                .font(Theme.Typography.roundedFont(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
                }
                .padding()
            }
        }
        .modifier(SheetBackgroundModifier())
    }
}
