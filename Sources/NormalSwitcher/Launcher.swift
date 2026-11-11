import AppKit

@main
@MainActor
struct Launcher {
    static func main() {
        let app = NSApplication.shared
        let delegate = MenuBarController()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
