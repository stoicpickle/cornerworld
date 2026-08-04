import XCTest
@testable import DesktopHostCore

final class DesktopLaunchOptionsTests: XCTestCase {
    func testDefaultsLaunchOverlandAtNormalSpeed() throws {
        let options = try DesktopLaunchOptions(arguments: [])

        XCTAssertEqual(options.world, .overland)
        XCTAssertNil(options.seed)
        XCTAssertEqual(options.farmPlan.rawValue, "wheat")
        XCTAssertFalse(options.fast)
        XCTAssertEqual(options.command, .run)
    }

    func testFarmLaunchParsesCaseInsensitiveWorldPlanAndHexSeed() throws {
        let options = try DesktopLaunchOptions(arguments: [
            "--world", "FARM", "--seed", "0x738", "--plan", "BEANS", "--fast",
        ])

        XCTAssertEqual(options.world, .farm)
        XCTAssertEqual(options.seed, 1_848)
        XCTAssertEqual(options.farmPlan.rawValue, "beans")
        XCTAssertTrue(options.fast)
        XCTAssertEqual(options.command, .run)
    }

    func testFarmMayBeSelectedAfterItsPlan() throws {
        let options = try DesktopLaunchOptions(arguments: [
            "--plan", "fallow", "--world", "farm",
        ])

        XCTAssertEqual(options.world, .farm)
        XCTAssertEqual(options.farmPlan.rawValue, "fallow")
    }

    func testCanopyWorldParsesWithASeedAndFastClock() throws {
        let options = try DesktopLaunchOptions(arguments: [
            "--world", "CANOPY", "--seed", "1993", "--fast",
        ])

        XCTAssertEqual(options.world, .canopy)
        XCTAssertEqual(options.seed, 1_993)
        XCTAssertTrue(options.fast)
    }

    func testHelpAndVersionCommandsDoNotLaunchAWorld() throws {
        XCTAssertEqual(
            try DesktopLaunchOptions(arguments: ["--help", "--unknown"]).command,
            .help
        )
        XCTAssertEqual(
            try DesktopLaunchOptions(arguments: ["--version", "--unknown"]).command,
            .version
        )
    }

    func testFixtureCaptureParsesItsDirectory() throws {
        let options = try DesktopLaunchOptions(arguments: [
            "--capture-farm-fixtures", ".build/proof",
        ])

        XCTAssertEqual(options.command, .captureFarmFixtures(directory: ".build/proof"))
    }

    func testMenuBarFixtureCaptureParsesItsDirectory() throws {
        let options = try DesktopLaunchOptions(arguments: [
            "--capture-menu-bar-fixtures", ".build/menu-proof",
        ])

        XCTAssertEqual(
            options.command,
            .captureMenuBarFixtures(directory: ".build/menu-proof")
        )
    }

    func testCanopyFixtureCaptureParsesItsDirectory() throws {
        let options = try DesktopLaunchOptions(arguments: [
            "--capture-canopy-fixtures", ".build/canopy-proof",
        ])
        XCTAssertEqual(
            options.command,
            .captureCanopyFixtures(directory: ".build/canopy-proof")
        )
    }

    func testFixtureCaptureRejectsIgnoredWorldRunOptionsInEitherOrder() {
        assertError(
            ["--world", "farm", "--capture-farm-fixtures", ".build/proof"],
            equals: .fixtureCaptureMustBeStandalone
        )
        assertError(
            ["--capture-farm-fixtures", ".build/proof", "--seed", "1848"],
            equals: .fixtureCaptureMustBeStandalone
        )
        assertError(
            [
                "--capture-farm-fixtures", ".build/farm-proof",
                "--capture-menu-bar-fixtures", ".build/menu-proof",
            ],
            equals: .fixtureCaptureMustBeStandalone
        )
    }

    func testFarmPlanRequiresFarmWorld() {
        assertError(["--plan", "wheat"], equals: .planRequiresFarm)
        assertError(
            ["--world", "overland", "--plan", "beans"],
            equals: .planRequiresFarm
        )
    }

    func testMissingOptionValuesHaveSpecificErrors() {
        assertError(["--world"], equals: .missingWorld)
        assertError(["--seed"], equals: .missingSeed)
        assertError(["--plan"], equals: .missingPlan)
        assertError(["--capture-farm-fixtures"], equals: .missingFixtureDirectory)
        assertError(
            ["--capture-canopy-fixtures"],
            equals: .missingCanopyFixtureDirectory
        )
        assertError(
            ["--capture-farm-fixtures", "--fast"],
            equals: .missingFixtureDirectory
        )
        assertError(
            ["--capture-menu-bar-fixtures"],
            equals: .missingMenuBarFixtureDirectory
        )
        assertError(
            ["--capture-menu-bar-fixtures", ""],
            equals: .missingMenuBarFixtureDirectory
        )
    }

    func testInvalidWorldSeedAndPlanHaveSpecificErrors() {
        assertError(["--world", "lighthouse"], equals: .invalidWorld("lighthouse"))
        assertError(["--seed", "not-a-seed"], equals: .invalidSeed("not-a-seed"))
        assertError(
            ["--world", "farm", "--plan", "corn"],
            equals: .invalidPlan("corn")
        )
    }

    func testUnknownOptionsAreRejected() {
        assertError(["--farm"], equals: .unknownOption("--farm"))
    }

    func testInvalidValueDescriptionsNameTheRejectedInput() {
        XCTAssertEqual(
            DesktopLaunchError.invalidWorld("lighthouse").description,
            "--world requires overland, farm, or canopy, not 'lighthouse'"
        )
        XCTAssertEqual(
            DesktopLaunchError.invalidSeed("bad-seed").description,
            "--seed requires a decimal or 0x-prefixed hexadecimal value, not 'bad-seed'"
        )
        XCTAssertEqual(
            DesktopLaunchError.invalidPlan("corn").description,
            "--plan requires wheat, beans, or fallow, not 'corn'"
        )
    }

    private func assertError(
        _ arguments: [String],
        equals expected: DesktopLaunchError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try DesktopLaunchOptions(arguments: arguments),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(error as? DesktopLaunchError, expected, file: file, line: line)
        }
    }
}
