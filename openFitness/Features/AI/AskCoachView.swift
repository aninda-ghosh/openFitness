import SwiftUI

struct AskCoachView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: AskCoachModel
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    private let focus: InsightMetric?

    init(focus: InsightMetric? = nil) {
        self.focus = focus
        _model = State(initialValue: AskCoachModel(focus: focus))
    }

    private var starterQuestions: [String] {
        switch focus {
        case .recovery:
            return ["Why is my recovery where it is?", "What's hurting my recovery most?", "How do I recover faster?"]
        case .sleep:
            return ["What's holding my sleep score back?", "How do I get more deep sleep?", "Is my sleep schedule consistent?"]
        case .strain:
            return ["Is my strain right for my recovery?", "Should I push harder or rest?", "How does this week's strain compare?"]
        case .stress:
            return ["Why is my stress elevated?", "What helps my stress the most?", "How does stress affect my sleep?"]
        case .activity:
            return ["Am I moving enough?", "How are my steps trending?", "What would lift my activity most?"]
        case .energy:
            return ["Why is my energy where it is?", "How do I keep my energy up today?", "What drains my energy most?"]
        case .vitals:
            return ["Are my vitals normal for me?", "What does my skin temperature mean?", "How is my VO2 max trending?"]
        case .activeness:
            return ["What's dragging my score down?", "Which area should I fix first?", "How do I raise my activeness score?"]
        case .workouts:
            return ["Am I training consistently?", "What should my next workout be?", "Is my training balanced?"]
        case nil:
            return ["Why is my recovery low today?", "How did I sleep this week?", "Am I training enough?", "Compare this week to last week"]
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(accent: Theme.Colors.recoveryHigh)

                switch model.availability {
                case .available:
                    chatContent
                default:
                    unavailableContent
                }
            }
            .navigationTitle("Ask Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !model.messages.isEmpty {
                        Button(action: { model.reset() }) {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.recoveryHigh)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Chat

    private var chatContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if model.messages.isEmpty {
                            emptyState
                        }
                        ForEach(model.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.messages.last?.text) {
                    if let lastId = model.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }

            inputBar
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundColor(Theme.Colors.recoveryHigh)
                Text(focus.map { "Ask about your \($0.displayName.lowercased())" } ?? "Ask about your data")
                    .font(Theme.Typography.titleSM)
                    .foregroundColor(.white)
                Text("Answers are generated on this iPhone by Apple Intelligence. Your health data never leaves the device.")
                    .font(Theme.Typography.callout)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(starterQuestions, id: \.self) { question in
                    Button {
                        Task { await model.send(question) }
                    } label: {
                        Text(question)
                            .font(Theme.Typography.callout)
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(TactileButtonStyle())
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func messageBubble(_ message: AskCoachModel.Message) -> some View {
        if message.role == .user {
            Text(message.text)
                .font(Theme.Typography.body)
                .foregroundColor(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.Colors.recoveryHigh)
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else if message.text.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(Theme.Colors.recoveryHigh)
                Text("Checking your data…")
                    .font(Theme.Typography.callout)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 6)
        } else {
            MarkdownText(
                text: message.text,
                font: Theme.Typography.body,
                color: message.isError ? .white.opacity(0.6) : .white.opacity(0.9)
            )
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about your fitness…", text: $inputText, axis: .vertical)
                .font(Theme.Typography.body)
                .foregroundColor(.white)
                .lineLimit(1...4)
                .submitLabel(.send)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
                .onSubmit(sendCurrentInput)

            Button(action: sendCurrentInput) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(canSend ? Theme.Colors.recoveryHigh : .white.opacity(0.2))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isResponding
    }

    private func sendCurrentInput() {
        guard canSend else { return }
        let text = inputText
        inputText = ""
        Task { await model.send(text) }
    }

    // MARK: - Unavailable

    private var unavailableContent: some View {
        VStack(spacing: 14) {
            Image(systemName: unavailableIcon)
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))

            Text(unavailableTitle)
                .font(Theme.Typography.titleSM)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(unavailableMessage)
                .font(Theme.Typography.body)
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .glassCard()
        .padding(.horizontal, 24)
    }

    private var unavailableIcon: String {
        switch model.availability {
        case .modelNotReady: return "arrow.down.circle.dotted"
        case .deviceNotEligible: return "iphone.slash"
        default: return "sparkles"
        }
    }

    private var unavailableTitle: String {
        switch model.availability {
        case .appleIntelligenceNotEnabled: return "Turn On Apple Intelligence"
        case .modelNotReady: return "Model Downloading"
        case .deviceNotEligible: return "Device Not Supported"
        default: return "Not Available"
        }
    }

    private var unavailableMessage: String {
        switch model.availability {
        case .appleIntelligenceNotEnabled:
            return "Ask Coach runs entirely on your iPhone using Apple Intelligence — your health data never leaves the device.\n\nEnable it in Settings → Apple Intelligence & Siri, then come back here."
        case .modelNotReady:
            return "Apple Intelligence is still downloading its on-device model. This happens automatically — check back in a few minutes."
        case .deviceNotEligible:
            return "Ask Coach needs an iPhone that supports Apple Intelligence (iPhone 15 Pro or later)."
        default:
            return "The on-device model isn't available right now."
        }
    }
}

#Preview {
    AskCoachView()
}
