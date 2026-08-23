#if canImport(SwiftUI)
import CoreText
import XCTest
@testable import EgakiumSharedUI

final class EgakiumTypographyTests: XCTestCase {
    func testSharedTypographyRolesKeepTheCrossPlatformDesignContract() {
        let expected: [EgakiumTypographyRole: EgakiumTypographySpec] = [
            .brand: EgakiumTypographySpec(
                nominalPointSize: 28,
                weight: .semibold,
                design: .jetBrainsMono),
            .largeTitle: EgakiumTypographySpec(
                nominalPointSize: 30,
                weight: .semibold,
                design: .jetBrainsMono),
            .title: EgakiumTypographySpec(
                nominalPointSize: 20,
                weight: .semibold,
                design: .jetBrainsMono),
            .headline: EgakiumTypographySpec(
                nominalPointSize: 16,
                weight: .semibold,
                design: .jetBrainsMono),
            .body: EgakiumTypographySpec(
                nominalPointSize: 14,
                weight: .regular,
                design: .jetBrainsMono),
            .caption: EgakiumTypographySpec(
                nominalPointSize: 12,
                weight: .medium,
                design: .jetBrainsMono),
            .metadata: EgakiumTypographySpec(
                nominalPointSize: 10,
                weight: .medium,
                design: .jetBrainsMono),
            .monospaced: EgakiumTypographySpec(
                nominalPointSize: 13,
                weight: .regular,
                design: .jetBrainsMono),
            .chat: EgakiumTypographySpec(
                nominalPointSize: 15,
                weight: .regular,
                design: .jetBrainsMono),
        ]

        XCTAssertEqual(Set(expected.keys), Set(EgakiumTypographyRole.allCases))
        for role in EgakiumTypographyRole.allCases {
            XCTAssertEqual(EgakiumTypography.spec(for: role), expected[role])
        }
    }

    #if canImport(AppKit)
    func testBundledJetBrainsMonoKeepsTheAppleChineseFallback() {
        EgakiumTypography.preflight()

        let regular = EgakiumTypography.platformFont(
            size: 14,
            weight: .regular)
        XCTAssertEqual(regular.fontName, "JetBrainsMono-Regular")

        let coreTextFont = regular as CTFont
        let latin = CTFontCreateForString(
            coreTextFont,
            "Egakium" as CFString,
            CFRange(location: 0, length: 7))
        XCTAssertEqual(
            CTFontCopyPostScriptName(latin) as String,
            "JetBrainsMono-Regular")

        let chinese = CTFontCreateForString(
            coreTextFont,
            "中文" as CFString,
            CFRange(location: 0, length: 2))
        XCTAssertTrue(
            (CTFontCopyFamilyName(chinese) as String).hasPrefix("PingFang"))
    }

    func testBundledWeightAndItalicFacesResolveWithoutSynthesis() {
        let expected: [(EgakiumFontFaceWeight, Bool, String)] = [
            (.light, false, "JetBrainsMono-Light"),
            (.light, true, "JetBrainsMono-LightItalic"),
            (.regular, false, "JetBrainsMono-Regular"),
            (.regular, true, "JetBrainsMono-Italic"),
            (.medium, false, "JetBrainsMono-Medium"),
            (.medium, true, "JetBrainsMono-MediumItalic"),
            (.semibold, false, "JetBrainsMono-SemiBold"),
            (.semibold, true, "JetBrainsMono-SemiBoldItalic"),
            (.bold, false, "JetBrainsMono-Bold"),
            (.bold, true, "JetBrainsMono-BoldItalic"),
        ]

        for (weight, italic, postScriptName) in expected {
            XCTAssertEqual(
                EgakiumTypography.platformFont(
                    size: 14,
                    weight: weight,
                    italic: italic).fontName,
                postScriptName)
        }
    }
    #endif
}
#endif
