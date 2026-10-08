import Foundation

/// Homebrew casks whose upgrade runs part of itself through sudo: an installer package, a system launch
/// service or a file in /Library to remove. sudo only asks for a password in a terminal and MacUp has
/// none, nor does it ask for the password on Homebrew's behalf, so these are updated in Terminal, where
/// sudo asks for it itself.
extension UpdateStore {
    /// What sudo says when Homebrew asks it for a password and there is no terminal to ask in.
    nonisolated static let sudoWithoutTerminal = "a terminal is required to read the password"
    /// The failure shown for it. Homebrew's own error names the sudo command, which says nothing useful.
    nonisolated static let needsTerminalFailure =
        "Needs your administrator password, which Homebrew can only ask for in Terminal."

    /// Updating this package asks for an administrator password: its whole manager does (MacPorts,
    /// system Ruby gems), or it is a cask that runs part of its upgrade through sudo.
    func needsAdmin(_ pkg: OutdatedPackage) -> Bool { needsAdmin(pkg.manager) || updatesInTerminal(pkg) }

    /// A cask that is updated in Terminal. Known from the scan, or learned from an upgrade that failed
    /// for exactly that reason.
    func updatesInTerminal(_ pkg: OutdatedPackage) -> Bool {
        pkg.manager == .brew && (pkg.needsAdmin || failure(for: pkg) == Self.needsTerminalFailure)
    }

    /// Opens the update in Terminal, where sudo asks for the password itself and MacUp never sees it.
    func updateInTerminal(_ pkg: OutdatedPackage) async {
        guard let command = await updateCommand(pkg) else { return }
        appendLog("\n\(Self.logMarker(manager: pkg.manager, names: [pkg.name])) in Terminal\n$ \(command)\n")
        // Nobody is at a test run to type the password, and a window opening there would be a surprise.
        guard !AutomatedRun.isActive else { return }
        Support.runInTerminal(command, title: "Updating \(pkg.name)")
    }

    /// The same command, for someone who would rather run it themselves.
    func copyUpdateCommand(_ pkg: OutdatedPackage) async {
        if let command = await updateCommand(pkg) { Support.copy(command) }
    }

    /// The command the upgrade script would have run, the user's own replacement included.
    private func updateCommand(_ pkg: OutdatedPackage) async -> String? {
        await ScriptRunner.upgradeCommand(
            manager: pkg.manager, argument: pkg.upgradeArgument, brewGreedy: settings.brewGreedy)
    }
}
