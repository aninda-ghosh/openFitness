import SwiftUI

struct Theme {
    // MARK: - Color Palette
    struct Colors {
        // Backgrounds
        static let background    = Color(red: 0.02,  green: 0.02,  blue: 0.02)   // #050505 near-black
        static let cardBackground = Color(red: 0.055, green: 0.055, blue: 0.055)  // #0E0E0E lifted black
        static let border        = Color.white.opacity(0.05)

        // Recovery (desaturated ~12% from the original neons to sit on gradients)
        static let recoveryHigh  = Color(red: 0.22,  green: 0.95,  blue: 0.69)   // Soft Mint
        static let recoveryMid   = Color(red: 0.98,  green: 0.84,  blue: 0.18)   // Warm Gold
        static let recoveryLow   = Color(red: 0.98,  green: 0.28,  blue: 0.41)   // Health Red

        // Strain
        static let strainHigh    = Color(red: 1.0,   green: 0.50,  blue: 0.18)   // Deep Orange
        static let strainLow     = Color(red: 1.0,   green: 0.62,  blue: 0.33)   // Muted Orange

        // Sleep
        static let sleepDeep     = Color(red: 0.53,  green: 0.45,  blue: 0.98)   // Personal Purple
        static let sleepREM      = Color(red: 0.76,  green: 0.42,  blue: 0.93)   // Vivid Violet
        static let sleepLight    = Color(red: 0.18,  green: 0.55,  blue: 0.98)   // Apple Blue
        static let sleepAwake    = Color(red: 0.98,  green: 0.65,  blue: 0.16)   // Warm Amber
    }
    
    // MARK: - Typography (SF Pro Rounded)
    struct Typography {
        static func roundedFont(size: CGFloat, weight: Font.Weight) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }

        // MARK: Display — hero numbers on rings and stat screens
        static var displayXL: Font  { roundedFont(size: 56, weight: .black) }   // Primary score ring
        static var display: Font    { roundedFont(size: 44, weight: .bold) }    // Main stat hero
        static var displaySM: Font  { roundedFont(size: 34, weight: .bold) }    // Secondary stat hero

        // MARK: Titles — section and card headings
        static var titleLG: Font    { roundedFont(size: 28, weight: .bold) }    // Card headline number
        static var title: Font      { roundedFont(size: 22, weight: .semibold) } // Supporting values
        static var titleSM: Font    { roundedFont(size: 20, weight: .semibold) } // Card section heading

        // MARK: Body — readable prose and callouts
        static var bodyLG: Font     { roundedFont(size: 17, weight: .regular) } // Primary descriptive text
        static var body: Font       { roundedFont(size: 15, weight: .regular) } // Standard body
        static var callout: Font    { roundedFont(size: 13, weight: .medium) }  // Secondary stats, callouts

        // MARK: Labels — UI chrome and card titles
        static var label: Font      { roundedFont(size: 13, weight: .semibold) } // Card titles, segment tabs
        static var labelSM: Font    { roundedFont(size: 12, weight: .medium) }   // Secondary labels

        // MARK: Captions — chart elements, tags, ticks
        static var caption: Font    { roundedFont(size: 11, weight: .semibold) } // Chart labels, pill tags
        static var tick: Font       { roundedFont(size: 10, weight: .semibold) } // Axis ticks — minimum readable size

        // MARK: Backward-compatible helpers
        static func metricLabel(size: CGFloat = 44) -> Font { roundedFont(size: size, weight: .bold) }
        static var cardTitle: Font  { label }
        static var bodyText: Font   { bodyLG }
        static var valueLabel: Font { title }
    }
}

// MARK: - Atmospheric Background

/// Mesh-gradient backdrop: deep charcoal-navy with a wash of the screen's accent
/// bleeding in from the top corner. Replaces the flat near-black background so
/// glass chrome has something to refract and cards need less of their own chrome.
struct AppBackground: View {
    var accent: Color = Theme.Colors.recoveryHigh

    var body: some View {
        Color.black
            .ignoresSafeArea()
    }
}

// MARK: - Open Section Header

/// Sentence-case header for content that sits directly on the background
/// instead of inside a card.
struct SectionHeaderView: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.Typography.titleSM)
                .foregroundColor(.white.opacity(0.92))
            if let subtitle {
                Text(subtitle)
                    .font(Theme.Typography.labelSM)
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - View Modifiers for Soft Translucent Cards
struct GlassmorphicModifier: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1.0)
            )
    }
}

// VisualEffectView enables UIKit system blurs in SwiftUI
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}

struct TactileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24) -> some View {
        self.modifier(GlassmorphicModifier(cornerRadius: cornerRadius))
    }
}
