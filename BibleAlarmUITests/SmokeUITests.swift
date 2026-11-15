import XCTest

/// Walks through the main screens in the simulator. This is the closest thing to a device test
/// that can run without Ryder's iPhone: it catches crashes and broken flows, and saves screenshots.
/// It cannot prove that real alarms ring; that still needs a phone.
final class SmokeUITests: XCTestCase {
    @MainActor
    func testA_EnglishWalkthrough() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Onboarding
        tap(app.buttons["Continue"])
        shot("01-onboarding-alarm")
        tap(app.buttons["Allow alarms"])
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 6) {
            allow.tap()
            print("UITEST: alarm permission prompt appeared and was allowed")
        } else {
            print("UITEST: no alarm permission prompt appeared in the simulator")
        }
        XCTAssertTrue(app.staticTexts["Choose your Bible"].waitForExistence(timeout: 15))
        shot("02-onboarding-bible")
        tap(app.buttons["Get started"])

        // Home and today's verse
        XCTAssertTrue(app.buttons["Read today's verse"].waitForExistence(timeout: 10))
        shot("03-home")
        app.buttons["Read today's verse"].tap()
        XCTAssertTrue(app.buttons["choice-0"].waitForExistence(timeout: 20), "The verse challenge did not appear")
        print("UITEST: challenge verse = \(app.staticTexts["verse-text"].label)")
        shot("04-challenge")
        solveChallenge(in: app, until: app.buttons["Amen"])
        shot("05-success")
        app.buttons["Amen"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        shot("06-reflection")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Today's verse is done"].waitForExistence(timeout: 10))

        // Journey
        app.tabBars.buttons["Journey"].tap()
        XCTAssertTrue(app.staticTexts["Day streak"].waitForExistence(timeout: 5))
        shot("07-journey")

        // Settings: unlock Premium (test builds only) and look at the Premium screens
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Bible version"].waitForExistence(timeout: 5))
        shot("08-settings")
        let unlock = app.switches["Unlock Premium for testing"]
        for _ in 0..<4 where !unlock.exists {
            app.swipeUp()
        }
        XCTAssertTrue(unlock.exists, "The test unlock switch is missing")
        unlock.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        for _ in 0..<4 where !app.staticTexts["Answer style"].exists {
            app.swipeDown()
        }
        XCTAssertTrue(app.staticTexts["Answer style"].waitForExistence(timeout: 5), "Premium did not unlock")
        tap(app.buttons["Premium is active"])
        XCTAssertTrue(app.staticTexts["Bible Alarm Premium"].waitForExistence(timeout: 5))
        shot("09-paywall")
        tap(app.buttons["Close"])

        // Alarms: add one
        app.tabBars.buttons["Alarms"].tap()
        tap(app.buttons["Add alarm"])
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 5))
        shot("10-alarm-editor")
        let soundRow = app.staticTexts["Sound"]
        for _ in 0..<3 where !soundRow.isHittable {
            app.swipeUp()
        }
        soundRow.tap()
        XCTAssertTrue(app.staticTexts["Add your own sound"].waitForExistence(timeout: 5))
        shot("11-sound-picker")
        tap(app.buttons["Chimes"])
        app.navigationBars.buttons.firstMatch.tap()
        tap(app.buttons["Save"])
        let okButton = app.alerts.buttons["OK"]
        if okButton.waitForExistence(timeout: 6) {
            let message = app.alerts.staticTexts.allElementsBoundByIndex.map { $0.label }.joined(separator: " | ")
            print("UITEST: saving the alarm showed an alert: \(message)")
            okButton.tap()
        } else {
            print("UITEST: alarm saved without an error alert")
        }
        XCTAssertTrue(app.buttons["Add alarm"].waitForExistence(timeout: 10))
        shot("12-home-with-alarm")

        // Memorize mode (Premium)
        app.tabBars.buttons["Journey"].tap()
        tap(app.buttons["Memorize mode"])
        XCTAssertTrue(app.buttons["choice-0"].waitForExistence(timeout: 20), "Memorize mode did not start")
        shot("13-memorize")
        solveChallenge(in: app, until: app.staticTexts["Well done"])
        tap(app.buttons["Done"])
    }

    @MainActor
    func testB_ChineseWalkthrough() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_TW",
            "-hasOnboarded", "YES", "-bibleVersionID", "cuv",
        ]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["鬧鐘"].waitForExistence(timeout: 15), "The Chinese translation is not being used")
        shot("20-zh-home")
        let again = app.buttons["再讀一次"]
        let first = app.buttons["讀今天的經文"]
        if again.waitForExistence(timeout: 5) {
            again.tap()
        } else {
            tap(first)
        }
        XCTAssertTrue(app.buttons["choice-0"].waitForExistence(timeout: 20), "The Chinese verse challenge did not appear")
        print("UITEST: Chinese challenge verse = \(app.staticTexts["verse-text"].label)")
        let choices = (0..<4).map { app.buttons["choice-\($0)"] }.filter { $0.exists }.map { $0.label }
        print("UITEST: Chinese choices = \(choices.joined(separator: " / "))")
        shot("21-zh-challenge")
        solveChallenge(in: app, until: app.buttons["阿們"])
        shot("22-zh-success")
        app.buttons["阿們"].tap()
        tap(app.buttons["完成"])

        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["聖經譯本"].waitForExistence(timeout: 5))
        shot("23-zh-settings")
    }

    // MARK: - Helpers

    @MainActor
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing: \(element)", file: file, line: line)
        element.tap()
    }

    /// Taps the choices in turn until the challenge is finished. Wrong taps only shake the verse.
    @MainActor
    private func solveChallenge(in app: XCUIApplication, until finished: XCUIElement) {
        for _ in 0..<60 {
            if finished.exists { return }
            for index in 0..<4 {
                if finished.exists { return }
                let choice = app.buttons["choice-\(index)"]
                if choice.exists, choice.isHittable {
                    choice.tap()
                }
            }
        }
        XCTAssertTrue(finished.waitForExistence(timeout: 5), "The challenge never finished")
    }

    @MainActor
    private func shot(_ name: String) {
        guard let folder = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !folder.isEmpty else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: directory.appendingPathComponent(name + ".png"))
    }
}
