import Foundation
import FoundationModels
import Observation

@MainActor
@Observable
final class AskCoachModel {

    struct Message: Identifiable, Equatable {
        enum Role {
            case user
            case assistant
        }

        let id = UUID()
        let role: Role
        var text: String
        var isError = false
    }

    enum Availability {
        case available
        case appleIntelligenceNotEnabled
        case modelNotReady
        case deviceNotEligible
        case unavailable
    }

    private(set) var messages: [Message] = []
    private(set) var isResponding = false

    /// When set, the session is seeded with this metric's verified facts and the
    /// coach treats it as the entry point of a holistic conversation.
    let focus: InsightMetric?

    private var session: LanguageModelSession?

    init(focus: InsightMetric? = nil) {
        self.focus = focus
    }

    var availability: Availability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable:
            return .unavailable
        }
    }

    func reset() {
        messages.removeAll()
        session = nil
    }

    func send(_ text: String) async {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isResponding else { return }

        messages.append(Message(role: .user, text: prompt))
        messages.append(Message(role: .assistant, text: ""))
        isResponding = true
        defer { isResponding = false }

        let session = self.session ?? makeSession()
        self.session = session

        do {
            // Applying every token re-renders the whole conversation (markdown parse +
            // scroll layout per bubble) and can hang the main thread on long answers,
            // so coalesce snapshots to ~10 UI updates per second
            var latest = ""
            var lastRender = Date.distantPast
            // Greedy sampling keeps the small model factual, same as the insight cards
            let stream = session.streamResponse(
                to: prompt,
                options: GenerationOptions(sampling: .greedy)
            )
            for try await snapshot in stream {
                latest = snapshot.content
                let now = Date()
                if now.timeIntervalSince(lastRender) > 0.1 {
                    lastRender = now
                    updateLastMessage(latest)
                }
            }
            updateLastMessage(latest)
        } catch let error as LanguageModelSession.GenerationError {
            handleGenerationError(error)
        } catch {
            updateLastMessage("Something went wrong: \(error.localizedDescription)", isError: true)
        }
    }

    private func handleGenerationError(_ error: LanguageModelSession.GenerationError) {
        switch error {
        case .exceededContextWindowSize:
            // The on-device model has a small context window; start over rather than fail repeatedly
            session = nil
            updateLastMessage(
                "This conversation got too long for the on-device model, so I've started a fresh one. Please ask that again.",
                isError: true
            )
        case .guardrailViolation:
            updateLastMessage(
                "Apple's on-device model declined to answer that one. Try rephrasing, or ask about your metrics directly.",
                isError: true
            )
        case .rateLimited:
            updateLastMessage("The on-device model is busy. Give it a moment and try again.", isError: true)
        default:
            updateLastMessage("Something went wrong: \(error.localizedDescription)", isError: true)
        }
    }

    private func updateLastMessage(_ text: String, isError: Bool = false) {
        guard let index = messages.indices.last, messages[index].role == .assistant else { return }
        messages[index].text = text
        messages[index].isError = isError
    }

    private func makeSession() -> LanguageModelSession {
        let today = Date()
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let weekday = today.formatted(.dateTime.weekday(.wide))

        var instructions = """
            You are the in-app coach for openFitness, a personal fitness tracking app. \
            You answer questions about the user's own health and fitness data: recovery, \
            strain, sleep, stress, energy, steps, heart metrics, vitals and workouts.

            Today is \(weekday), \(dayFormatter.string(from: today)).

            Rules:
            - Always fetch real data with the tools before answering; never invent numbers.
            - Use getTodaySnapshot for today, getDailyHistory for past days and trends, \
            getWorkouts for exercise sessions.
            - Recovery, sleep score and energy are percentages (0-100). Strain is 0-21. \
            Stress is 0-100 where lower is calmer.
            - Be concise and conversational: a short answer with the key numbers, then one \
            practical takeaway. No markdown tables or headers.
            - The app does not set goals or targets. Never invent a goal, recommended \
            range or target the tools did not report.
            - Quote numbers exactly as the tools report them. Avoid doing your own \
            arithmetic beyond simple comparisons like higher or lower.
            - You are not a doctor. If asked for medical advice, suggest talking to a \
            healthcare professional instead.
            """

        if let focus {
            instructions += """


            The user opened this chat from the \(focus.displayName) screen, so start \
            from their \(focus.displayName.lowercased()) but think about their health \
            holistically: connect it to sleep, recovery, strain, stress and activity \
            where relevant, and use the tools to pull any additional data you need.

            Verified \(focus.displayName) data right now:
            \(AIInsightEngine.shared.chatContext(for: focus))
            """
        }

        return LanguageModelSession(
            tools: [TodaySnapshotTool(), DailyHistoryTool(), WorkoutsTool()],
            instructions: instructions
        )
    }
}
