import XCTest

@testable import Macup

final class ErrorSummaryTests: XCTestCase {
    func testPrefersErrorLines() {
        let out =
            "$ brew upgrade -- x\n==> Upgrading x\nError: x: It seems the App source '/Applications/X.app' is not there.\n"
        XCTAssertEqual(
            UpdateStore.errorSummary(out, status: 1),
            "Error: x: It seems the App source '/Applications/X.app' is not there.")
    }
    func testSudoWithNoTerminalSaysWhatToDoRatherThanQuotingSudo() {
        let out = """
            $ brew upgrade --cask -- docker-desktop
            ==> Removing launchctl service com.docker.socket
            sudo: a terminal is required to read the password; either use the -S option to read from standard input
            sudo: a password is required
            Error: docker-desktop: Failure while executing; /usr/bin/sudo -E -- /usr/bin/xargs -0 -- /bin/rm -r -f -- exited with 1.
            """
        XCTAssertEqual(UpdateStore.errorSummary(out, status: 1), UpdateStore.needsTerminalFailure)
    }
    func testFallsBackToTail() {
        XCTAssertEqual(UpdateStore.errorSummary("$ cmd\na\nb\nc\nd\n", status: 2), "b\nc\nd")
        XCTAssertEqual(UpdateStore.errorSummary("", status: 3), "Exited with status 3")
    }
}
