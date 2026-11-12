import AppKit

@main
@MainActor
struct Launcher {
    static func main() {
        if ProcessInfo.processInfo.arguments.contains("--verify-login-item") {
            do { try LoginItemManager().verifyRoundTrip() }
            catch { fputs("Login item verification: \(error.localizedDescription)\n", stderr); exit(1) }
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--verify-quit") {
            QuitVerification.run()
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--check-access") {
            print("AX trusted: \(AXIsProcessTrusted())")
            return
        }
        let app = NSApplication.shared
        let delegate = MenuBarController()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
