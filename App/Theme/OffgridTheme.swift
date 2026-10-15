import SwiftUI

public enum OffgridTheme {
    // Colors
    public static let background = Color("background", hex: "#0B0C0E")
    public static let surface = Color("surface", hex: "#141518")
    public static let surfaceRaised = Color("surfaceRaised", hex: "#222328")
    public static let hairline = Color("hairline", hex: "#222328")
    public static let textPrimary = Color("textPrimary", hex: "#F4F4F5")
    public static let textSecondary = Color("textSecondary", hex: "#A1A1AA")
    public static let solar = Color("solar", hex: "#F5B945")
    public static let battery = Color("battery", hex: "#34D399")
    public static let grid = Color("grid", hex: "#93C5FD")
    public static let warning = Color("warning", hex: "#FF9F43")
    public static let alarm = Color("alarm", hex: "#FF5C5C")

    // Radii
    public static let heroRadius: CGFloat = 24
    public static let tileRadius: CGFloat = 20
    public static let tabRadius: CGFloat = 16
    public static let buttonRadius: CGFloat = 14

    // Spacing
    public static let screenPadding: CGFloat = 20
    public static let tileGap: CGFloat = 12
    public static let sectionGap: CGFloat = 16
    public static let touchTargetSize: CGFloat = 44

    // Font helper
    public static func numberFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded).monospacedDigit()
    }
}

// Extension to create Color from hex
private extension Color {
    init(_ name: String, hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
