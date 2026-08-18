#if canImport(SwiftUI)
import XCTest
@testable import EgakiumSharedUI

final class EgakiumTypographyTests: XCTestCase {
    func testSharedTypographyRolesKeepTheCrossPlatformDesignContract() {
        let expected: [EgakiumTypographyRole: EgakiumTypographySpec] = [
            .brand: EgakiumTypographySpec(
                nominalPointSize: 28,
                weight: .semibold,
                design: .serif),
            .largeTitle: EgakiumTypographySpec(
                nominalPointSize: 30,
                weight: .semibold,
                design: .serif),
            .title: EgakiumTypographySpec(
                nominalPointSize: 20,
                weight: .semibold,
                design: .serif),
            .headline: EgakiumTypographySpec(
                nominalPointSize: 16,
                weight: .semibold,
                design: .sansSerif),
            .body: EgakiumTypographySpec(
                nominalPointSize: 14,
                weight: .regular,
                design: .sansSerif),
            .caption: EgakiumTypographySpec(
                nominalPointSize: 12,
                weight: .medium,
                design: .sansSerif),
            .metadata: EgakiumTypographySpec(
                nominalPointSize: 10,
                weight: .medium,
                design: .sansSerif),
            .monospaced: EgakiumTypographySpec(
                nominalPointSize: 13,
                weight: .regular,
                design: .monospaced),
            .chat: EgakiumTypographySpec(
                nominalPointSize: 15,
                weight: .regular,
                design: .sansSerif),
        ]

        XCTAssertEqual(Set(expected.keys), Set(EgakiumTypographyRole.allCases))
        for role in EgakiumTypographyRole.allCases {
            XCTAssertEqual(EgakiumTypography.spec(for: role), expected[role])
        }
    }
}
#endif
