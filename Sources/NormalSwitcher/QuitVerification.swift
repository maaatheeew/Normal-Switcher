import AppKit

@MainActor
final class QuitVerification: NSObject, NSApplicationDelegate {
    private let model = SwitcherModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in model.quit() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        FileHandle.standardOutput.write(Data("PASS: production Quit action terminates NSApplication\n".utf8))
    }

    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let delegate = QuitVerification()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
