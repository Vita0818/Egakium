import XCTest
@testable import EgakiumSharedUI

final class MessageRendererModeTests: XCTestCase {
    func testDefaultsToMicrosoftWhenNoPreferenceExistsAfterCutover() {
        XCTAssertEqual(
            EgakiumMessageRendererMode.resolve(
                persistedRawValue: nil,
                arguments: ["Egakium"]),
            .microsoft)
    }

    func testPersistedPlainSafeModeIsPreserved() {
        XCTAssertEqual(
            EgakiumMessageRendererMode.resolve(
                persistedRawValue: EgakiumMessageRendererMode.plainSafe.rawValue,
                arguments: ["Egakium"]),
            .plainSafe)
    }

    func testLaunchArgumentsOverridePersistedPreference() {
        XCTAssertEqual(
            EgakiumMessageRendererMode.resolve(
                persistedRawValue: EgakiumMessageRendererMode.microsoft.rawValue,
                arguments: ["Egakium", EgakiumMessageRendererMode.plainSafeLaunchArgument]),
            .plainSafe)
        XCTAssertEqual(
            EgakiumMessageRendererMode.resolve(
                persistedRawValue: EgakiumMessageRendererMode.plainSafe.rawValue,
                arguments: ["Egakium", EgakiumMessageRendererMode.microsoftLaunchArgument]),
            .microsoft)
    }

    func testPlainSafeWinsContradictoryLaunchArguments() {
        XCTAssertEqual(
            EgakiumMessageRendererMode.resolve(
                persistedRawValue: nil,
                arguments: [
                    "Egakium",
                    EgakiumMessageRendererMode.microsoftLaunchArgument,
                    EgakiumMessageRendererMode.plainSafeLaunchArgument,
                ]),
            .plainSafe)
    }

    func testUnknownPersistedValueFailsToPlainSafe() {
        XCTAssertEqual(
            EgakiumMessageRendererMode.resolve(
                persistedRawValue: "future-value",
                arguments: ["Egakium"]),
            .plainSafe)
    }

    func testLegacyRichPreferenceAndLaunchArgumentMigrateToMicrosoft() {
        XCTAssertEqual(
            EgakiumMessageRendererMode.resolve(
                persistedRawValue: "rich",
                arguments: ["Egakium"]),
            .microsoft)
        XCTAssertEqual(
            EgakiumMessageRendererMode.resolve(
                persistedRawValue: EgakiumMessageRendererMode.plainSafe.rawValue,
                arguments: ["Egakium", EgakiumMessageRendererMode.legacyRichLaunchArgument]),
            .microsoft)
    }

    func testPlainSafeRenderPlanPreservesRawTextAndLineEndings() {
        let raw = "  **first**\r\n| a | b |\r`$code$`\n公式 $x_i$ 与 \\$29.99  "
        let plan = EgakiumMessageRenderPlan.resolve(
            rawText: raw,
            isComplete: true,
            policyIsRich: true,
            rendererMode: .plainSafe)

        XCTAssertEqual(plan.displayText, raw)
        XCTAssertEqual(Data(plan.displayText.utf8), Data(raw.utf8))
        XCTAssertFalse(plan.usesRichRenderer)
    }

    func testEmptyStreamingRenderPlanUsesPlaceholderWithoutRichWork() {
        let plan = EgakiumMessageRenderPlan.resolve(
            rawText: "",
            isComplete: false,
            policyIsRich: true,
            rendererMode: .plainSafe)

        XCTAssertEqual(plan.displayText, "…")
        XCTAssertFalse(plan.usesRichRenderer)
    }

    func testCompletedEmptyMessageRemainsByteExactEmptyText() {
        let plan = EgakiumMessageRenderPlan.resolve(
            rawText: "",
            isComplete: true,
            policyIsRich: true,
            rendererMode: .plainSafe)

        XCTAssertEqual(plan.displayText, "")
        XCTAssertFalse(plan.usesRichRenderer)
    }

    func testRichModeRoutesEligibleMessagesToRichRenderer() {
        let plan = EgakiumMessageRenderPlan.resolve(
            rawText: "**assistant source**",
            isComplete: true,
            policyIsRich: true,
            rendererMode: .microsoft)

        XCTAssertEqual(plan.displayText, "**assistant source**")
        XCTAssertTrue(plan.usesRichRenderer)
        XCTAssertTrue(plan.acceptsRichDocument(rawText: "**assistant source**"))
        XCTAssertFalse(plan.acceptsRichDocument(rawText: "**older snapshot**"))
    }

    func testRolePolicyCanAlwaysForcePlainRendering() {
        let plan = EgakiumMessageRenderPlan.resolve(
            rawText: "**user source**",
            isComplete: true,
            policyIsRich: false,
            rendererMode: .microsoft)

        XCTAssertEqual(plan.displayText, "**user source**")
        XCTAssertFalse(plan.usesRichRenderer)
    }
}
