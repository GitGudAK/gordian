// Gordian palette and shared styles — 1:1 port of ui/theme/Color.kt

import SwiftUI

extension Color {
    static let darkBackground = Color(red: 0x08 / 255, green: 0x09 / 255, blue: 0x0B / 255)
    static let darkSurface = Color(red: 0x13 / 255, green: 0x15 / 255, blue: 0x18 / 255)
    static let darkSurfaceVariant = Color(red: 0x1E / 255, green: 0x21 / 255, blue: 0x27 / 255)
    static let goldPrimary = Color(red: 0xD4 / 255, green: 0xAF / 255, blue: 0x37 / 255)
    static let textLight = Color(red: 0xEA / 255, green: 0xEA / 255, blue: 0xEA / 255)
    static let textMuted = Color(red: 0x9A / 255, green: 0x9F / 255, blue: 0xA5 / 255)
    static let redAccent = Color(red: 0xE0 / 255, green: 0x5C / 255, blue: 0x5C / 255)
    static let goldMuted = Color(red: 0x8A / 255, green: 0x6D / 255, blue: 0x3B / 255)
    static let goldAccent = Color(red: 0xF1 / 255, green: 0xE4 / 255, blue: 0xC3 / 255)
}

// The app's recurring "label" typography: small bold caps with tracking
struct SectionLabel: View {
    let text: String
    var color: Color = .goldPrimary
    var size: CGFloat = 11
    var tracking: CGFloat = 1.5

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold))
            .tracking(tracking)
            .foregroundColor(color)
    }
}

struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 24
    var borderColor: Color = Color.white.opacity(0.05)
    var borderWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: cornerRadius).fill(Color.darkSurface))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(borderColor, lineWidth: borderWidth))
    }
}

extension View {
    func gordianCard(cornerRadius: CGFloat = 24, borderColor: Color = Color.white.opacity(0.05), borderWidth: CGFloat = 1) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius, borderColor: borderColor, borderWidth: borderWidth))
    }
}

// Dark-bordered text input styled like the Android OutlinedTextField
struct GordianFieldStyle: ViewModifier {
    var focused: Bool

    func body(content: Content) -> some View {
        content
            .foregroundColor(.white)
            .tint(.goldPrimary)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.darkSurface))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focused ? Color.goldPrimary : Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}
