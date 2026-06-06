import SwiftUI

struct Theme {
    // MARK: - Color Palette
    struct Colors {
        // Backgrounds
        static let background = Color(red: 0.08, green: 0.08, blue: 0.08) // Warm Charcoal
        static let cardBackground = Color(red: 0.13, green: 0.13, blue: 0.13) // Solid dark gray
        static let border = Color.white.opacity(0.03) // Deep gray stroke
        
        // Recovery (Neon Yellow-Green / Teal / Neon Orange)
        static let recoveryHigh = Color(red: 0.78, green: 0.96, blue: 0.15)    // Neon Lime Green (#C8F525)
        static let recoveryMid = Color(red: 0.23, green: 0.79, blue: 0.74)     // Bright Teal
        static let recoveryLow = Color(red: 0.96, green: 0.53, blue: 0.09)     // Neon Orange
        
        // Strain
        static let strainHigh = Color(red: 0.96, green: 0.53, blue: 0.09)      // Neon Orange
        static let strainLow = Color(red: 0.96, green: 0.53, blue: 0.09).opacity(0.6)
        
        // Sleep
        static let sleepDeep = Color(red: 0.23, green: 0.79, blue: 0.74)       // Bright Teal
        static let sleepREM = Color(red: 0.23, green: 0.79, blue: 0.74).opacity(0.7)
        static let sleepLight = Color(red: 0.78, green: 0.96, blue: 0.15)      // Neon Lime Green
        static let sleepAwake = Color(red: 0.96, green: 0.53, blue: 0.09)      // Neon Orange
    }
    
    // MARK: - Typography (Rounded Sans-Serif)
    struct Typography {
        static func roundedFont(size: CGFloat, weight: Font.Weight) -> Font {
            return .system(size: size, weight: weight, design: .rounded)
        }
        
        static func metricLabel(size: CGFloat = 48) -> Font {
            return roundedFont(size: size, weight: .bold)
        }
        
        static var cardTitle: Font {
            return roundedFont(size: 14, weight: .semibold)
        }
        
        static var bodyText: Font {
            return roundedFont(size: 16, weight: .regular)
        }
        
        static var valueLabel: Font {
            return roundedFont(size: 20, weight: .bold)
        }
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
            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3) // Flat shadow lift
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
