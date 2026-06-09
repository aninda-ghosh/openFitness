import SwiftUI

struct Theme {
    // MARK: - Color Palette
    struct Colors {
        // Backgrounds
        static let background    = Color(red: 0.02,  green: 0.02,  blue: 0.02)   // #050505 near-black
        static let cardBackground = Color(red: 0.055, green: 0.055, blue: 0.055)  // #0E0E0E lifted black
        static let border        = Color.white.opacity(0.05)

        // Recovery
        static let recoveryHigh  = Color(red: 0.063, green: 1.0,   blue: 0.667)  // #10FFAA Electric Mint
        static let recoveryMid   = Color(red: 1.0,   green: 0.839, blue: 0.039)  // #FFD60A Pure Gold
        static let recoveryLow   = Color(red: 1.0,   green: 0.216, blue: 0.373)  // #FF375F Apple Health Red

        // Strain
        static let strainHigh    = Color(red: 1.0,   green: 0.420, blue: 0.0)    // #FF6B00 Deep Orange
        static let strainLow     = Color(red: 1.0,   green: 0.576, blue: 0.251)  // #FF9340 Muted Orange

        // Sleep
        static let sleepDeep     = Color(red: 0.482, green: 0.380, blue: 1.0)    // #7B61FF Personal Purple
        static let sleepREM      = Color(red: 0.749, green: 0.353, blue: 0.949)  // #BF5AF2 Vivid Violet
        static let sleepLight    = Color(red: 0.039, green: 0.518, blue: 1.0)    // #0A84FF Apple Blue
        static let sleepAwake    = Color(red: 1.0,   green: 0.624, blue: 0.039)  // #FF9F0A Warm Amber
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

// MARK: - View Modifiers for Flat Solid Cards
struct GlassmorphicModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 1.0)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
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
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(GlassmorphicModifier(cornerRadius: cornerRadius))
    }
}
