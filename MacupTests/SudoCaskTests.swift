import XCTest

@testable import Macup

/// Homebrew casks whose upgrade runs part of itself through sudo, such as Docker Desktop. sudo only asks
/// for a password in a terminal and MacUp has none, so running one here fails halfway through: they are
/// handed to Terminal instead, and left out of anything that runs without someone choosing them.
@MainActor
final class SudoCaskTests: StubScriptCase {
    private func sudoCask(_ name: String = "docker-desktop") -> OutdatedPackage {
        var cask = pkg(name, manager: .brew, kind: "cask")
        cask.extra = "admin"
        return cask
    }

    func testACaskThatNeedsSudoIsHandedToTerminalInsteadOfRun() async {
        let store = store()
        let cask = sudoCask()
        store.loadFixture(reports: [], packages: [cask], log: "")

        XCTAssertTrue(store.updatesInTerminal(cask))
        XCTAssertTrue(store.needsAdmin(cask))
        await store.upgrade(cask)

        XCTAssertTrue(store.log.contains("── Homebrew: docker-desktop ── in Terminal"), store.log)
        XCTAssertTrue(store.log.contains("$ upgrading cask:docker-desktop"), "the script's own command: \(store.log)")
        XCTAssertFalse(store.log.contains("✓ done"), "nothing was run here")
        XCTAssertEqual(store.history.records, [], "and nothing recorded as updated")
    }

    func testUpdateAllLeavesCasksThatNeedSudo() async {
        // Unattended runs go through the same batch, so this is also what keeps them from failing.
        let store = store()
        store.loadFixture(reports: [], packages: [sudoCask(), pkg("jq", manager: .brew, kind: "formula")], log: "")

        XCTAssertEqual(store.eligible.count, 2, "it is still offered to the user")
        XCTAssertEqual(store.updatableCount, 1, "but Update All only counts what it will run")
        await store.upgradeAllEligible()

        XCTAssertEqual(store.history.records.map(\.package), ["jq"])
        XCTAssertFalse(store.log.contains("docker-desktop"), store.log)
    }

    func testAnUpgradeThatFailsForWantOfAPasswordIsSentToTerminalNextTime() async throws {
        // The scan cannot know about every cask. When sudo is refused for lack of a terminal, the row says
        // so plainly, and the next attempt goes to Terminal rather than failing the same way.
        try script(
            "macup-upgrade",
            """
            print "$ brew upgrade --cask -- ${2#cask:}"
            print "sudo: a terminal is required to read the password; either use the -S option" >&2
            print "Error: ${2#cask:}: Failure while executing; /usr/bin/sudo -E -- /bin/rm exited with 1." >&2
            exit 1
            """)
        // Homebrew put the old version back, so the rescan still reports it. System-owned only so the
        // registry is not asked for a date.
        try script(
            "macup-scan",
            #"""
            for m in "$@"; do printf 'M\t%s\tok\t\n' "$m"; done
            printf 'P\tbrew\tsurprise\t1.0.0\t2.0.0\tsystem-cask\t\t0\n'
            """#)
        let store = store()
        let cask = pkg("surprise", manager: .brew, kind: "cask")
        store.loadFixture(reports: [], packages: [cask], log: "")
        XCTAssertFalse(store.updatesInTerminal(cask))

        await store.upgrade(cask)
        let failed = try XCTUnwrap(store.packages.first { $0.id == cask.id }, "still outdated after the rescan")

        XCTAssertEqual(store.failure(for: failed), UpdateStore.needsTerminalFailure)
        XCTAssertTrue(store.updatesInTerminal(failed), "learned from the failure")
    }

    func testTheTerminalScriptShowsTheCommandRunsItAndCleansUp() {
        let script = Support.terminalScript("brew upgrade --cask -- 'it'\\''s'", title: "Updating it's")
        XCTAssertTrue(script.hasPrefix("#!/bin/zsh\n"))
        XCTAssertTrue(script.contains("rm -f -- \"$0\""), "the file removes itself")
        XCTAssertTrue(script.hasSuffix("\nbrew upgrade --cask -- 'it'\\''s'\n"), "the command is run as given")
        XCTAssertTrue(script.contains("print -r -- '$ brew upgrade"), "and shown first, quoted so it is only shown")
    }
}
