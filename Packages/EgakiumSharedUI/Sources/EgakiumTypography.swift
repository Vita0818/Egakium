#if canImport(SwiftUI)
import CoreText
import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Cross-platform typography roles shared by the macOS workbench and iOS Chat.
///
/// App views may scale the nominal point size with `@ScaledMetric`, but should
/// keep the role's weight so both platforms retain the same visual voice.
/// Every app-owned Latin glyph uses the exact bundled JetBrains Mono face;
/// glyphs absent from JetBrains Mono retain Core Text's Apple fallback chain,
/// which resolves Chinese text to the appropriate PingFang family.
public enum EgakiumTypographyRole: String, CaseIterable, Hashable, Sendable {
    case brand
    case largeTitle
    case title
    case headline
    case body
    case caption
    case metadata
    case monospaced
    case chat
}

public struct EgakiumTypographySpec: Equatable, Sendable {
    public enum Design: String, Sendable {
        case jetBrainsMono
    }

    public enum Weight: String, Sendable {
        case regular
        case medium
        case semibold
    }

    public let nominalPointSize: CGFloat
    public let weight: Weight
    public let design: Design

    public init(
        nominalPointSize: CGFloat,
        weight: Weight,
        design: Design
    ) {
        self.nominalPointSize = nominalPointSize
        self.weight = weight
        self.design = design
    }
}

public enum EgakiumTypography {
    public static let bundledFontVersion = "2.304"
    public static let primaryFamilyName = "JetBrains Mono"
    public static let chineseFallbackFamilyPrefix = "PingFang"

    public static func spec(for role: EgakiumTypographyRole) -> EgakiumTypographySpec {
        switch role {
        case .brand:
            return EgakiumTypographySpec(
                nominalPointSize: 28,
                weight: .semibold,
                design: .jetBrainsMono)
        case .largeTitle:
            return EgakiumTypographySpec(
                nominalPointSize: 30,
                weight: .semibold,
                design: .jetBrainsMono)
        case .title:
            return EgakiumTypographySpec(
                nominalPointSize: 20,
                weight: .semibold,
                design: .jetBrainsMono)
        case .headline:
            return EgakiumTypographySpec(
                nominalPointSize: 16,
                weight: .semibold,
                design: .jetBrainsMono)
        case .body:
            return EgakiumTypographySpec(
                nominalPointSize: 14,
                weight: .regular,
                design: .jetBrainsMono)
        case .caption:
            return EgakiumTypographySpec(
                nominalPointSize: 12,
                weight: .medium,
                design: .jetBrainsMono)
        case .metadata:
            return EgakiumTypographySpec(
                nominalPointSize: 10,
                weight: .medium,
                design: .jetBrainsMono)
        case .monospaced:
            return EgakiumTypographySpec(
                nominalPointSize: 13,
                weight: .regular,
                design: .jetBrainsMono)
        case .chat:
            return EgakiumTypographySpec(
                nominalPointSize: 15,
                weight: .regular,
                design: .jetBrainsMono)
        }
    }

    /// Eagerly verifies the complete bundled face inventory and the two
    /// required glyph-resolution branches. A missing or substituted asset is
    /// a packaging error; the app never silently changes to another Latin
    /// typeface.
    public static func preflight() {
        _ = bundledGraphicsFonts

        let base = coreTextFont(size: 14, weight: .regular, italic: false)
        let latin = CTFontCreateForString(
            base,
            "Egakium" as CFString,
            CFRange(location: 0, length: 7))
        precondition(
            (CTFontCopyPostScriptName(latin) as String) == Face.regular.postScriptName,
            "JetBrains Mono Latin glyph resolution is unavailable")

        let chinese = CTFontCreateForString(
            base,
            "中文" as CFString,
            CFRange(location: 0, length: 2))
        precondition(
            (CTFontCopyFamilyName(chinese) as String)
                .hasPrefix(chineseFallbackFamilyPrefix),
            "Chinese text no longer resolves through PingFang")
    }

    public static func font(
        for role: EgakiumTypographyRole,
        size: CGFloat? = nil,
        weight: Font.Weight? = nil
    ) -> Font {
        let spec = spec(for: role)
        return fixed(
            size: size ?? spec.nominalPointSize,
            weight: weight ?? spec.weight.swiftUIWeight)
    }

    /// Exact-size JetBrains Mono font for existing role APIs and deliberately
    /// fixed-size UI. Chinese glyphs continue through the platform cascade.
    public static func fixed(
        size: CGFloat,
        weight: Font.Weight = .regular,
        italic: Bool = false
    ) -> Font {
        Font(platformFont(
            size: size,
            weight: faceWeight(for: weight),
            italic: italic))
    }

    static func platformFont(
        size: CGFloat,
        weight: EgakiumFontFaceWeight,
        italic: Bool = false
    ) -> EgakiumPlatformFont {
        let face = Face(weight: weight, italic: italic)
        let cacheKey = "\(face.resourceName):\(Double(size).bitPattern)" as NSString
        if let cached = platformFontCache.object(forKey: cacheKey) {
            return cached
        }
        let font = coreTextFont(size: size, weight: weight, italic: italic)
        #if canImport(AppKit)
        let platformFont = font as NSFont
        #elseif canImport(UIKit)
        let platformFont = font as UIFont
        #endif
        platformFontCache.setObject(platformFont, forKey: cacheKey)
        return platformFont
    }

    static func dynamicTypeScale(for size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall:
            return 14.0 / 17.0
        case .small:
            return 15.0 / 17.0
        case .medium:
            return 16.0 / 17.0
        case .large:
            return 1
        case .xLarge:
            return 19.0 / 17.0
        case .xxLarge:
            return 21.0 / 17.0
        case .xxxLarge:
            return 23.0 / 17.0
        case .accessibility1:
            return 28.0 / 17.0
        case .accessibility2:
            return 33.0 / 17.0
        case .accessibility3:
            return 40.0 / 17.0
        case .accessibility4:
            return 47.0 / 17.0
        case .accessibility5:
            return 53.0 / 17.0
        @unknown default:
            return 1
        }
    }

    static func semanticPointSize(
        for style: Font.TextStyle,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        let baseSize = semanticBasePointSize(for: style)
        #if canImport(UIKit)
        return UIFontMetrics(forTextStyle: uiKitTextStyle(for: style))
            .scaledValue(
                for: baseSize,
                compatibleWith: UITraitCollection(
                    preferredContentSizeCategory:
                        uiKitContentSizeCategory(for: dynamicTypeSize)))
        #else
        return baseSize * dynamicTypeScale(for: dynamicTypeSize)
        #endif
    }

    private static func semanticBasePointSize(for style: Font.TextStyle) -> CGFloat {
        #if canImport(AppKit)
        if style == .largeTitle { return 26 }
        if style == .title { return 22 }
        if style == .title2 { return 17 }
        if style == .title3 { return 15 }
        if style == .headline { return 13 }
        if style == .subheadline { return 11 }
        if style == .body { return 13 }
        if style == .callout { return 12 }
        if style == .footnote { return 10 }
        if style == .caption { return 10 }
        if style == .caption2 { return 10 }
        #elseif canImport(UIKit)
        if style == .largeTitle { return 34 }
        if style == .title { return 28 }
        if style == .title2 { return 22 }
        if style == .title3 { return 20 }
        if style == .headline { return 17 }
        if style == .subheadline { return 15 }
        if style == .body { return 17 }
        if style == .callout { return 16 }
        if style == .footnote { return 13 }
        if style == .caption { return 12 }
        if style == .caption2 { return 11 }
        #endif
        return 13
    }

    #if canImport(UIKit)
    private static func uiKitTextStyle(for style: Font.TextStyle) -> UIFont.TextStyle {
        if style == .largeTitle { return .largeTitle }
        if style == .title { return .title1 }
        if style == .title2 { return .title2 }
        if style == .title3 { return .title3 }
        if style == .headline { return .headline }
        if style == .subheadline { return .subheadline }
        if style == .body { return .body }
        if style == .callout { return .callout }
        if style == .footnote { return .footnote }
        if style == .caption { return .caption1 }
        if style == .caption2 { return .caption2 }
        return .body
    }

    private static func uiKitContentSizeCategory(
        for size: DynamicTypeSize
    ) -> UIContentSizeCategory {
        switch size {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
    #endif

    static func semanticDefaultWeight(for style: Font.TextStyle) -> Font.Weight {
        style == .headline ? .semibold : .regular
    }

    public static func brand(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .brand, size: size, weight: weight)
    }

    public static func largeTitle(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .largeTitle, size: size, weight: weight)
    }

    public static func title(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .title, size: size, weight: weight)
    }

    public static func headline(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .headline, size: size, weight: weight)
    }

    public static func body(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .body, size: size, weight: weight)
    }

    public static func caption(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .caption, size: size, weight: weight)
    }

    public static func metadata(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .metadata, size: size, weight: weight)
    }

    public static func mono(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .monospaced, size: size, weight: weight)
    }

    public static func chat(
        _ size: CGFloat? = nil,
        _ weight: Font.Weight? = nil
    ) -> Font {
        font(for: .chat, size: size, weight: weight)
    }

    private static func coreTextFont(
        size: CGFloat,
        weight: EgakiumFontFaceWeight,
        italic: Bool
    ) -> CTFont {
        let face = Face(weight: weight, italic: italic)
        guard let graphicsFont = bundledGraphicsFonts[face] else {
            preconditionFailure("Missing bundled JetBrains Mono face: \(face.resourceName)")
        }
        return CTFontCreateWithGraphicsFont(graphicsFont, size, nil, nil)
    }

    private static func faceWeight(for weight: Font.Weight) -> EgakiumFontFaceWeight {
        if weight == .ultraLight || weight == .thin || weight == .light {
            return .light
        }
        if weight == .medium {
            return .medium
        }
        if weight == .semibold {
            return .semibold
        }
        if weight == .bold || weight == .heavy || weight == .black {
            return .bold
        }
        return .regular
    }

    private static let bundledGraphicsFonts: [Face: CGFont] = {
        var result: [Face: CGFont] = [:]
        for face in Face.allCases {
            guard let url = Bundle.module.url(
                forResource: face.resourceName,
                withExtension: "ttf",
                subdirectory: "Fonts"),
                  let provider = CGDataProvider(url: url as CFURL),
                  let graphicsFont = CGFont(provider),
                  (graphicsFont.postScriptName as String?) == face.postScriptName else {
                preconditionFailure(
                    "Missing or invalid bundled JetBrains Mono asset: \(face.resourceName).ttf")
            }
            result[face] = graphicsFont
        }
        return result
    }()

    private static let platformFontCache: NSCache<NSString, EgakiumPlatformFont> = {
        let cache = NSCache<NSString, EgakiumPlatformFont>()
        cache.countLimit = 256
        return cache
    }()
}

enum EgakiumFontFaceWeight: Sendable {
    case light
    case regular
    case medium
    case semibold
    case bold
}

private enum Face: CaseIterable, Hashable {
    case light
    case lightItalic
    case regular
    case italic
    case medium
    case mediumItalic
    case semibold
    case semiboldItalic
    case bold
    case boldItalic

    init(weight: EgakiumFontFaceWeight, italic: Bool) {
        switch (weight, italic) {
        case (.light, false): self = .light
        case (.light, true): self = .lightItalic
        case (.regular, false): self = .regular
        case (.regular, true): self = .italic
        case (.medium, false): self = .medium
        case (.medium, true): self = .mediumItalic
        case (.semibold, false): self = .semibold
        case (.semibold, true): self = .semiboldItalic
        case (.bold, false): self = .bold
        case (.bold, true): self = .boldItalic
        }
    }

    var resourceName: String {
        switch self {
        case .light: return "JetBrainsMono-Light"
        case .lightItalic: return "JetBrainsMono-LightItalic"
        case .regular: return "JetBrainsMono-Regular"
        case .italic: return "JetBrainsMono-Italic"
        case .medium: return "JetBrainsMono-Medium"
        case .mediumItalic: return "JetBrainsMono-MediumItalic"
        case .semibold: return "JetBrainsMono-SemiBold"
        case .semiboldItalic: return "JetBrainsMono-SemiBoldItalic"
        case .bold: return "JetBrainsMono-Bold"
        case .boldItalic: return "JetBrainsMono-BoldItalic"
        }
    }

    var postScriptName: String {
        resourceName
    }
}

private extension EgakiumTypographySpec.Weight {
    var swiftUIWeight: Font.Weight {
        switch self {
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        }
    }
}

#if canImport(AppKit)
typealias EgakiumPlatformFont = NSFont
#elseif canImport(UIKit)
typealias EgakiumPlatformFont = UIFont
#endif

private struct EgakiumSemanticFontModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let style: Font.TextStyle
    let weight: Font.Weight?
    let italic: Bool

    func body(content: Content) -> some View {
        content.font(EgakiumTypography.fixed(
            size: EgakiumTypography.semanticPointSize(
                for: style,
                dynamicTypeSize: dynamicTypeSize),
            weight: weight ?? EgakiumTypography.semanticDefaultWeight(for: style),
            italic: italic))
    }
}

public extension View {
    /// Dynamic-Type-aware semantic JetBrains Mono font for app-owned UI.
    func egakiumFont(
        _ style: Font.TextStyle,
        weight: Font.Weight? = nil,
        italic: Bool = false
    ) -> some View {
        modifier(EgakiumSemanticFontModifier(
            style: style,
            weight: weight,
            italic: italic))
    }

    /// Exact-size JetBrains Mono font for intentionally fixed-size UI.
    func egakiumFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        italic: Bool = false
    ) -> some View {
        font(EgakiumTypography.fixed(
            size: size,
            weight: weight,
            italic: italic))
    }

    /// Sets the app-owned default font while allowing role-specific children
    /// to override size and weight through the same JetBrains Mono family.
    func egakiumInterfaceTypography() -> some View {
        egakiumFont(.body)
    }
}
#endif
