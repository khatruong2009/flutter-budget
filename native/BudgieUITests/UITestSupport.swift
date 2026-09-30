import XCTest

// Typing and tapping that survive the software keyboard coming back.
//
// XCTest types through a virtual hardware keyboard that it attaches for each
// `typeText` and detaches afterwards. While it is attached UIKit minimises the
// software keyboard; about a second after it detaches (longer under load)
// UIKit shows the software keyboard again, and every sheet footer and centred
// dialog above it moves up by the keyboard's height. A plain `tap()` resolves
// its point from a snapshot and delivers the touch later, so a tap resolved
// while the keyboard was minimised and delivered after it came back landed on
// the keyboard (the form's Add became a space after "coffee", or a "9" in the
// amount) or, under a dialog, on its scrim. So every typing step here waits for
// the keyboard to come back and settle, and `tapSettled` waits for the keyboard
// and for its element to be hittable and still.

@MainActor
extension XCUIElement {
    /// Taps this field once it has settled, then types `text` into it.
    func enterText(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        tapSettled(file: file, line: line)
        typeSettled(text)
    }

    /// Types `text` into this (focused) field, then waits for the software
    /// keyboard to come back and settle.
    func typeSettled(_ text: String) {
        typeText(text)
        waitForKeyboardToSettle()
    }

    /// Taps once the keyboard has settled and this element exists, is
    /// hittable and has stopped moving (a sheet or dialog entrance, or the
    /// keyboard, moves it).
    func tapSettled(timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(exists || waitForExistence(timeout: timeout), "\(self) exists", file: file, line: line)
        waitForKeyboardToSettle()
        let deadline = Date().addingTimeInterval(timeout)
        var last = CGRect.null
        while Date() < deadline {
            let current = frame
            if isHittable && current == last { break }
            last = current
            Thread.sleep(forTimeInterval: 0.2)
        }
        tap()
    }
}

/// Waits until there is no software keyboard, or it is on screen and has
/// stopped moving. A keyboard that exists below the screen is minimised for
/// XCTest's virtual hardware keyboard and about to come back; after
/// `timeout` (a keyboard that stays minimised) the caller goes on.
@MainActor
private func waitForKeyboardToSettle(timeout: TimeInterval = 5) {
    let app = XCUIApplication()
    let keyboard = app.keyboards.firstMatch
    let deadline = Date().addingTimeInterval(timeout)
    var last = CGRect.null
    while Date() < deadline {
        guard keyboard.exists else { return }
        let frame = keyboard.frame
        if frame.minY < app.frame.maxY && frame == last { return }
        last = frame
        Thread.sleep(forTimeInterval: 0.2)
    }
}
