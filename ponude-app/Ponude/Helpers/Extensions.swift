import SwiftUI
import Foundation

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
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

// MARK: - Design Tokens

enum DesignTokens {
    static let gold = Color(hex: "#C5A55A")
    static let dark = Color(hex: "#1A1A1A")
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let lineColor = Color(nsColor: .separatorColor)
    /// Elevated card surface – adapts to light/dark mode
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    /// Page/canvas backdrop behind the A4 preview
    static let pageBackground = Color(nsColor: .underPageBackgroundColor)
    
    // Status colors (Ponude)
    static let statusDraft = Color(hex: "#94A3B8")
    static let statusSent = Color(hex: "#3B82F6")
    static let statusAccepted = Color(hex: "#22C55E")
    static let statusRejected = Color(hex: "#EF4444")
    
    // Status colors (Računi)
    static let statusIssued = Color(hex: "#8B5CF6")
    static let statusPaid = Color(hex: "#22C55E")
    static let statusCancelled = Color(hex: "#EF4444")
}

// MARK: - Brand Accent Environment Key

private struct BrandAccentKey: EnvironmentKey {
    static let defaultValue: Color = DesignTokens.gold
}

extension EnvironmentValues {
    var brandAccent: Color {
        get { self[BrandAccentKey.self] }
        set { self[BrandAccentKey.self] = newValue }
    }
}

// MARK: - Number Formatting

extension Decimal {
    /// Formats as Croatian currency: 30.000,00
    var hrFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "hr_HR")
        return formatter.string(from: self as NSDecimalNumber) ?? "0,00"
    }
}

extension String {
    /// Converts a Croatian-formatted number string to Decimal
    var toDecimal: Decimal {
        let cleaned = self
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned) ?? 0
    }
}

// MARK: - Date Formatting

extension Date {
    /// Formats as Croatian date: 09.04.2026.
    var hrFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy."
        formatter.locale = Locale(identifier: "hr_HR")
        return formatter.string(from: self)
    }
}

// MARK: - View Helpers

struct GoldDivider: View {
    var body: some View {
        Rectangle()
            .fill(DesignTokens.gold)
            .frame(height: 1)
    }
}

struct ThinDivider: View {
    var body: some View {
        Rectangle()
            .fill(DesignTokens.lineColor)
            .frame(height: 0.5)
    }
}
