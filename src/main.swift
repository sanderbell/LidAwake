import AppKit
import Foundation
import LocalAuthentication

enum NoSleepState {
    case on
    case off
    case unknown(String)

    var isKnown: Bool {
        switch self {
        case .on, .off:
            return true
        case .unknown:
            return false
        }
    }

    var statusTitle: String {
        switch self {
        case .on:
            return "Keeping awake"
        case .off:
            return "Normal sleep"
        case .unknown(let message):
            return "Status unavailable: \(message)"
        }
    }

    var toggleTitle: String {
        switch self {
        case .on:
            return "Allow Sleep"
        case .off:
            return "Keep Awake"
        case .unknown:
            return "Refresh"
        }
    }

    var symbolName: String {
        switch self {
        case .on:
            return "sun.max.fill"
        case .off:
            return "moon.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }

    var tooltip: String {
        switch self {
        case .on:
            return "Lid Awake is on."
        case .off:
            return "Normal lid sleep."
        case .unknown:
            return "Status unknown."
        }
    }
}

struct CommandResult {
    let output: String
    let exitCode: Int32
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let statusMenuItem = NSMenuItem(title: "Checking...", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: "Keep Awake", action: #selector(toggleNoSleep), keyEquivalent: "")
    private let refreshMenuItem = NSMenuItem(title: "Refresh", action: #selector(refreshFromMenu), keyEquivalent: "r")
    private let setupMenuItem = NSMenuItem(title: "Set Up Helper...", action: #selector(runSetup), keyEquivalent: "")
    private let quitMenuItem = NSMenuItem(title: "Quit Lid Awake", action: #selector(quit), keyEquivalent: "q")

    private var state: NoSleepState = .unknown("Checking")
    private var isBusy = false
    private var lastMessage = "Starting up"
    private var lastOutput = "none"
    private var refreshTimer: Timer?
    private let scriptPath: String?

    override init() {
        scriptPath = Self.findScriptPath()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureMenu()
        refreshStatus()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshStatus(silent: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.imagePosition = .imageLeading
        button.toolTip = "Lid Awake"
        button.target = self
        statusItem.menu = menu
        updateStatusIcon()
    }

    private func configureMenu() {
        menu.autoenablesItems = false

        statusMenuItem.isEnabled = false

        toggleMenuItem.target = self
        refreshMenuItem.target = self
        setupMenuItem.target = self
        quitMenuItem.target = self

        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(toggleMenuItem)
        menu.addItem(refreshMenuItem)
        menu.addItem(setupMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitMenuItem)

        updateMenu()
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else {
            return
        }

        let symbol = isBusy ? "arrow.triangle.2.circlepath" : state.symbolName
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: state.tooltip) {
            image.isTemplate = true
            button.image = image
            button.title = statusTitle()
        } else {
            button.image = nil
            button.title = statusTitle()
        }

        button.toolTip = isBusy ? "Lid Awake is updating." : state.tooltip
    }

    private func statusTitle() -> String {
        switch state {
        case .on:
            return " Awake"
        case .off:
            return " Sleep"
        case .unknown:
            return " ?"
        }
    }

    private func updateMenu() {
        statusMenuItem.title = isBusy ? "Updating..." : state.statusTitle
        toggleMenuItem.title = isBusy ? "Working..." : state.toggleTitle

        let hasScript = scriptPath != nil
        toggleMenuItem.isEnabled = !isBusy
        refreshMenuItem.isEnabled = !isBusy
        setupMenuItem.isEnabled = hasScript && !isBusy
    }

    private func setBusy(_ busy: Bool, message: String? = nil) {
        isBusy = busy
        if let message {
            lastMessage = message
        }
        updateStatusIcon()
        updateMenu()
    }

    @objc private func toggleNoSleep() {
        switch state {
        case .on:
            setNoSleep(enabled: false)
        case .off:
            setNoSleep(enabled: true)
        case .unknown:
            refreshStatus()
        }
    }

    @objc private func refreshFromMenu() {
        refreshStatus()
    }

    @objc private func runSetup() {
        let alert = NSAlert()
        alert.messageText = "Set up Lid Awake helper?"
        alert.informativeText = "This allows Touch ID toggles. Permission is limited to lid sleep on/off."
        alert.addButton(withTitle: "Set Up")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        setBusy(true, message: "Running setup")
        runScript(arguments: ["setup"], asAdmin: true) { [weak self] result in
            guard let self else {
                return
            }

            if result.exitCode == 0 {
                self.lastMessage = "Setup complete"
            } else {
                self.lastMessage = "Setup failed: \(Self.oneLine(result.output))"
            }

            self.setBusy(false)
            self.refreshStatus(silent: true)
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func refreshStatus(silent: Bool = false) {
        if !silent {
            setBusy(true, message: "Refreshing")
        }

        runPmsetStatus { [weak self] result in
            guard let self else {
                return
            }

            self.lastOutput = Self.oneLine(result.output)
            Self.appendLog("status exit=\(result.exitCode) output=\(Self.oneLine(result.output))")

            if result.exitCode == 0 {
                self.state = Self.parseStatus(result.output)
                if !silent {
                    self.lastMessage = "Refreshed \(Self.shortTimeString())"
                }
            } else {
                self.state = .unknown(Self.oneLine(result.output))
                self.lastMessage = "Status failed"
            }

            self.setBusy(false)
        }
    }

    private func setNoSleep(enabled: Bool) {
        let label = enabled ? "Turning on" : "Turning off"
        setBusy(true, message: label)

        authenticateWithTouchID(enabled: enabled) { [weak self] authenticated, authMessage in
            guard let self else {
                return
            }

            if authenticated {
                self.lastMessage = "Touch ID approved"
                self.setNoSleepWithPasswordlessSudo(enabled: enabled) { [weak self] result in
                    guard let self else {
                        return
                    }

                    self.lastOutput = Self.oneLine(result.output)
                    Self.appendLog("touchid sudo pmset \(enabled ? "on" : "off") exit=\(result.exitCode) output=\(Self.oneLine(result.output))")

                    if result.exitCode == 0 {
                        self.lastMessage = enabled ? "Turned on with Touch ID" : "Turned off with Touch ID"
                        self.refreshStatus(silent: true)
                    } else {
                        self.lastMessage = "Touch ID ok, sudo rule failed"
                        self.setNoSleepWithAdminFallback(enabled: enabled)
                    }
                }
                return
            }

            self.lastMessage = authMessage
            Self.appendLog("touchid auth failed output=\(authMessage)")

            if authMessage == "Touch ID cancelled" {
                self.setBusy(false)
                return
            }

            self.setNoSleepWithAdminFallback(enabled: enabled)
        }
    }

    private func setNoSleepWithAdminFallback(enabled: Bool) {
        self.lastMessage = "Needs admin approval"
        self.updateMenu()

        self.setNoSleepWithAdminPrivileges(enabled: enabled) { [weak self] adminResult in
            guard let self else {
                return
            }

            self.lastOutput = Self.oneLine(adminResult.output)
            Self.appendLog("admin pmset \(enabled ? "on" : "off") exit=\(adminResult.exitCode) output=\(Self.oneLine(adminResult.output))")

            if adminResult.exitCode == 0 {
                self.lastMessage = enabled ? "Turned on" : "Turned off"
            } else {
                self.lastMessage = "Failed: \(Self.oneLine(adminResult.output))"
            }

            self.refreshStatus(silent: true)
        }
    }

    private func runPmsetStatus(completion: @escaping (CommandResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["-g"]
            let result = Self.run(process)

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private func runScript(arguments: [String], asAdmin: Bool, completion: @escaping (CommandResult) -> Void) {
        guard let scriptPath else {
            completion(CommandResult(output: "nosleep.sh not found", exitCode: 127))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = asAdmin
                ? Self.runWithAdministratorPrivileges(scriptPath: scriptPath, arguments: arguments)
                : Self.runDirectly(scriptPath: scriptPath, arguments: arguments)

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private func setNoSleepWithAdminPrivileges(enabled: Bool, completion: @escaping (CommandResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let value = enabled ? "1" : "0"
            let result = Self.runCommandWithAdministratorPrivileges(
                executablePath: "/usr/bin/pmset",
                arguments: ["-a", "disablesleep", value]
            )

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private func setNoSleepWithPasswordlessSudo(enabled: Bool, completion: @escaping (CommandResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let value = enabled ? "1" : "0"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            process.arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", value]
            let result = Self.run(process)

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private func authenticateWithTouchID(enabled: Bool, completion: @escaping (Bool, String) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error),
              context.biometryType == .touchID else {
            completion(false, Self.touchIDUnavailableMessage(error))
            return
        }

        let action = enabled ? "keep the lid awake" : "allow lid sleep"
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Use Touch ID to \(action)."
        ) { success, authError in
            DispatchQueue.main.async {
                if success {
                    completion(true, "Touch ID approved")
                } else {
                    completion(false, Self.touchIDUnavailableMessage(authError as NSError?))
                }
            }
        }
    }

    private static func runDirectly(scriptPath: String, arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath] + arguments
        return run(process)
    }

    private static func runWithAdministratorPrivileges(scriptPath: String, arguments: [String]) -> CommandResult {
        runCommandWithAdministratorPrivileges(executablePath: "/bin/bash", arguments: [scriptPath] + arguments)
    }

    private static func runCommandWithAdministratorPrivileges(executablePath: String, arguments: [String]) -> CommandResult {
        let commandParts = [executablePath] + arguments
        let command = commandParts.map(shellQuote).joined(separator: " ")
        let appleScript = "do shell script \(appleScriptString(command)) with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        return run(process)
    }

    private static func run(_ process: Process) -> CommandResult {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CommandResult(output: error.localizedDescription, exitCode: 126)
        }

        var data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        data.append(errorPipe.fileHandleForReading.readDataToEndOfFile())

        let output = String(data: data, encoding: .utf8) ?? ""
        return CommandResult(output: output, exitCode: process.terminationStatus)
    }

    private static func parseStatus(_ output: String) -> NoSleepState {
        for line in output.components(separatedBy: .newlines) {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 2 else {
                continue
            }

            let key = parts[0].lowercased()
            let value = String(parts[1])

            if key == "sleepdisabled" || key == "disablesleep" {
                if value == "1" {
                    return .on
                }

                if value == "0" {
                    return .off
                }
            }
        }

        let normalized = output.lowercased()
        if normalized.contains("sleepdisabled\t\t1")
            || normalized.contains("sleepdisabled 1")
            || normalized.contains("disablesleep 1")
            || normalized.contains("sleep is disabled")
            || normalized.contains("nosleep is on") {
            return .on
        }

        if normalized.contains("sleepdisabled\t\t0")
            || normalized.contains("sleepdisabled 0")
            || normalized.contains("disablesleep 0")
            || normalized.contains("sleep is enabled")
            || normalized.contains("nosleep is off") {
            return .off
        }

        return .unknown(oneLine(output))
    }

    private static func touchIDAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            && context.biometryType == .touchID
    }

    private static func touchIDUnavailableMessage(_ error: NSError?) -> String {
        guard let error else {
            return "Touch ID unavailable"
        }

        if error.domain == LAError.errorDomain,
           let code = LAError.Code(rawValue: error.code) {
            switch code {
            case .userCancel, .appCancel, .systemCancel:
                return "Touch ID cancelled"
            case .biometryNotAvailable:
                return "Touch ID unavailable"
            case .biometryNotEnrolled:
                return "Touch ID not enrolled"
            case .biometryLockout:
                return "Touch ID locked"
            default:
                break
            }
        }

        return error.localizedDescription
    }

    private static func appendLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        let logURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("lid-awake.log")

        guard let data = line.data(using: .utf8) else {
            return
        }

        if FileManager.default.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: logURL)
        }
    }

    private static func findScriptPath() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/Terminal/scripts/nosleep.sh",
            "\(home)/Terminal/Scripts/nosleep.sh",
            "/Users/sanderbell/Terminal/scripts/nosleep.sh",
            "/Users/sanderbell/Terminal/Scripts/nosleep.sh"
        ]

        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func oneLine(_ value: String) -> String {
        let collapsed = value
            .split(whereSeparator: { $0.isNewline })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if collapsed.isEmpty {
            return "No output"
        }

        if collapsed.count <= 72 {
            return collapsed
        }

        return "\(collapsed.prefix(69))..."
    }

    private static func shortTimeString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: Date())
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
