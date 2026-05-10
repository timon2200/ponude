import SwiftUI

/// Defines the visual template style used for quote PDF rendering.
/// Each company gets a distinct look — colors, fonts, layout structure.
///
/// Design references:
///   • Lotus RC      — Cinematic dark navy, bold outlined sans-serif, modern & bold
///   • Studio Varaždin — Black/gold ornamental, premium serif typography, framed borders
///   • Lovements     — Wedding elegance: soft blush, rose-gold, delicate serif
///   • Domy Media    — Cinematic broadcast: deep charcoal, electric violet, sharp editorial
enum QuoteTemplateStyle {
    case lotusRC          // Cinematic: dark navy, bold sans-serif, modern edge
    case studioVarazdin   // Premium gold: black + ornamental gold borders, serif
    case lovements        // Wedding: blush, rose-gold, delicate & romantic
    case domyMedia        // Broadcast: charcoal + violet, clean & contemporary
    
    /// Determine the template style from a BusinessProfile's shortName.
    static func style(for profile: BusinessProfile) -> QuoteTemplateStyle {
        switch profile.shortName.lowercased() {
        case let name where name.contains("lotus"):
            return .lotusRC
        case let name where name.contains("studio") || name.contains("varaždin"):
            return .studioVarazdin
        case let name where name.contains("lovements"):
            return .lovements
        case let name where name.contains("domy"):
            return .domyMedia
        default:
            return .lotusRC
        }
    }
    
    // MARK: - Brand Color
    
    var brandColor: Color {
        switch self {
        case .lotusRC:         return Color(hex: "#3B82F6")  // Cinematic blue
        case .studioVarazdin:  return Color(hex: "#C5A55A")  // Ornamental gold
        case .lovements:       return Color(hex: "#D4A0A0")  // Rose gold
        case .domyMedia:       return Color(hex: "#7B2FF7")  // Electric violet
        }
    }
    
    var brandColorHex: String {
        switch self {
        case .lotusRC:         return "#3B82F6"
        case .studioVarazdin:  return "#C5A55A"
        case .lovements:       return "#D4A0A0"
        case .domyMedia:       return "#7B2FF7"
        }
    }
    
    // MARK: - Header
    
    var headerBackground: Color {
        switch self {
        case .lotusRC:         return Color(hex: "#0B1929")  // Deep navy
        case .studioVarazdin:  return Color(hex: "#0D0D0D")  // Rich black
        case .lovements:       return Color(hex: "#FFF5F5")  // Soft blush white
        case .domyMedia:       return Color(hex: "#1A1A2E")  // Deep charcoal
        }
    }
    
    var headerBackgroundHex: String {
        switch self {
        case .lotusRC:         return "#0B1929"
        case .studioVarazdin:  return "#0D0D0D"
        case .lovements:       return "#FFF5F5"
        case .domyMedia:       return "#1A1A2E"
        }
    }
    
    var headerTextColor: Color {
        switch self {
        case .lotusRC:         return .white
        case .studioVarazdin:  return Color(hex: "#C5A55A")
        case .lovements:       return Color(hex: "#8B6F6F")
        case .domyMedia:       return .white
        }
    }
    
    var headerTextColorHex: String {
        switch self {
        case .lotusRC:         return "#FFFFFF"
        case .studioVarazdin:  return "#C5A55A"
        case .lovements:       return "#8B6F6F"
        case .domyMedia:       return "#FFFFFF"
        }
    }
    
    // MARK: - Footer
    
    var footerBackground: Color {
        switch self {
        case .lotusRC:         return Color(hex: "#0B1929")
        case .studioVarazdin:  return Color(hex: "#0D0D0D")
        case .lovements:       return Color(hex: "#FFF5F5")
        case .domyMedia:       return Color(hex: "#1A1A2E")
        }
    }
    
    var footerBackgroundHex: String {
        switch self {
        case .lotusRC:         return "#0B1929"
        case .studioVarazdin:  return "#0D0D0D"
        case .lovements:       return "#FFF5F5"
        case .domyMedia:       return "#1A1A2E"
        }
    }
    
    var footerTextColor: Color {
        switch self {
        case .lotusRC:         return .white.opacity(0.7)
        case .studioVarazdin:  return Color(hex: "#C5A55A").opacity(0.7)
        case .lovements:       return Color(hex: "#B08E8E")
        case .domyMedia:       return Color(hex: "#7B2FF7").opacity(0.7)
        }
    }
    
    var footerTextColorHex: String {
        switch self {
        case .lotusRC:         return "rgba(255,255,255,0.7)"
        case .studioVarazdin:  return "rgba(197,165,90,0.7)"
        case .lovements:       return "#B08E8E"
        case .domyMedia:       return "rgba(123,47,247,0.7)"
        }
    }
    
    // MARK: - Body Text
    
    var textColor: Color {
        switch self {
        case .lotusRC:         return Color(hex: "#E2E8F0")  // Light slate for dark bodies
        case .studioVarazdin:  return Color(hex: "#333333")
        case .lovements:       return Color(hex: "#5D4647")
        case .domyMedia:       return Color(hex: "#1E1E2E")
        }
    }
    
    var textColorHex: String {
        switch self {
        case .lotusRC:         return "#1E293B"  // For PDF white-bg body
        case .studioVarazdin:  return "#333333"
        case .lovements:       return "#5D4647"
        case .domyMedia:       return "#1E1E2E"
        }
    }
    
    var lightTextColor: Color {
        switch self {
        case .lotusRC:         return Color(hex: "#64748B")
        case .studioVarazdin:  return Color(hex: "#777777")
        case .lovements:       return Color(hex: "#B08E8E")
        case .domyMedia:       return Color(hex: "#6B7280")
        }
    }
    
    var lightTextColorHex: String {
        switch self {
        case .lotusRC:         return "#64748B"
        case .studioVarazdin:  return "#777777"
        case .lovements:       return "#B08E8E"
        case .domyMedia:       return "#6B7280"
        }
    }
    
    // MARK: - Rules & Borders
    
    var ruleColor: Color {
        switch self {
        case .lotusRC:         return Color(hex: "#334155")
        case .studioVarazdin:  return Color(hex: "#C5A55A").opacity(0.3)
        case .lovements:       return Color(hex: "#F0D4D4")
        case .domyMedia:       return Color(hex: "#E5E7EB")
        }
    }
    
    var ruleColorHex: String {
        switch self {
        case .lotusRC:         return "#CBD5E1"
        case .studioVarazdin:  return "rgba(197,165,90,0.3)"
        case .lovements:       return "#F0D4D4"
        case .domyMedia:       return "#E5E7EB"
        }
    }
    
    var tableHeaderBackground: Color {
        switch self {
        case .lotusRC:         return Color(hex: "#F1F5F9")
        case .studioVarazdin:  return .clear
        case .lovements:       return Color(hex: "#FFF5F5")
        case .domyMedia:       return Color(hex: "#F3F0FF")
        }
    }
    
    var tableHeaderBackgroundHex: String {
        switch self {
        case .lotusRC:         return "#F1F5F9"
        case .studioVarazdin:  return "transparent"
        case .lovements:       return "#FFF5F5"
        case .domyMedia:       return "#F3F0FF"
        }
    }
    
    // MARK: - Page Background (for PDF body)
    
    var pageBackgroundHex: String {
        switch self {
        case .lotusRC:         return "#FFFFFF"
        case .studioVarazdin:  return "#FAFAF8"
        case .lovements:       return "#FFFAFA"
        case .domyMedia:       return "#FFFFFF"
        }
    }
}
