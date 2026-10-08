import AppKit
import Foundation

/// Where users can report problems, and the details worth attaching.
enum Support {
    static let repository = URL(string: "https://github.com/patriciobcs/macup")!

    static var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }

    static var environment: String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        return "MacUp \(appVersion) · macOS \(os)"
    }

    /// Plain-text details for the clipboard or an issue body. The manager's version is included when
    /// the scan reported one, so nobody has to ask for it.
    static func details(title: String, manager: Manager, raw: String, version: String = "") -> String {
        """
        \(title)

        Manager: \(manager.title) (\(manager.rawValue))\(version.isEmpty ? "" : " \(version)")
        \(environment)

        Output:
        \(raw.isEmpty ? "(none)" : raw.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
        """
    }

    /// A prefilled "new issue" page on GitHub.
    static func issueURL(title: String, body: String) -> URL {
        var c = URLComponents(url: repository.appendingPathComponent("issues/new"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "title", value: title), URLQueryItem(name: "body", value: body)]
        return c.url ?? repository
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// The script that runs a command in a terminal window: it shows the command, runs it, and deletes
    /// itself, so nothing is left behind in the temporary folder.
    static func terminalScript(_ command: String, title: String) -> String {
        let shown = "'" + "$ \(command)".replacingOccurrences(of: "'", with: "'\\''") + "'"
        return "#!/bin/zsh\n# \(title), opened by MacUp.\nrm -f -- \"$0\"\nprint -r -- \(shown)\n\(command)\n"
    }

    /// Runs a command in a new window of whichever terminal opens .command files, Terminal by default.
    /// For steps that need a person at a terminal: sudo asks for the password there, not MacUp.
    static func runInTerminal(_ command: String, title: String) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacUp-\(UUID().uuidString.prefix(8)).command")
        do {
            try terminalScript(command, title: title).write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        } catch { return }
        NSWorkspace.shared.open(url)
    }
}

extension ManagerReport {
    private static let offlineMarkers = [
        "offline", "could not resolve", "network is unreachable", "no route to host",
        "temporary failure in name resolution", "nodename nor servname", "timed out",
        "connection refused", "could not connect", "failed to connect",
    ]

    /// The failure looks like a missing internet connection rather than a bug.
    var isOffline: Bool {
        status == .error && Self.offlineMarkers.contains { message.lowercased().contains($0) }
    }

    /// One sentence a person can act on; the raw output stays available in `message`.
    var friendlyMessage: String {
        switch status {
        case .error:
            return isOffline
                ? "\(manager.title) needs an internet connection to check for updates."
                : "\(manager.title) could not check for updates."
        case .skipped: return message
        case .ok, .missing: return ""
        }
    }
}
