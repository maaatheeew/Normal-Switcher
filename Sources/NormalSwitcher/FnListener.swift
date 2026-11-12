import AppKit

@MainActor
protocol FnListening: AnyObject {
    func start() -> Bool
    func stop()
}

@MainActor
final class FnListener: FnListening {
    var enabled = true { didSet { tap.cancel() } }
    private var tap = FnTap()
    private var outside: Any?
    private var inside: Any?
    private let catalog: LayoutCatalog

    init(catalog: LayoutCatalog) { self.catalog = catalog }

    func start() -> Bool {
        guard outside == nil else { return inside != nil }
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .systemDefined]
        outside = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.consume(event) }
        }
        guard outside != nil else { return false }
        inside = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.consume(event) }
            return event
        }
        guard inside != nil else { stop(); return false }
        return true
    }

    func stop() {
        if let outside { NSEvent.removeMonitor(outside) }
        if let inside { NSEvent.removeMonitor(inside) }
        outside = nil
        inside = nil
        tap.cancel()
    }

    private func consume(_ event: NSEvent) {
        guard enabled else { return }
        if event.type == .systemDefined && event.subtype.rawValue != 8 { return }
        guard event.type == .flagsChanged && event.keyCode == 63 else {
            tap.usedInChord()
            return
        }
        if event.modifierFlags.contains(.function) {
            let modifiers = event.modifierFlags.intersection([.shift, .control, .option, .command])
            tap.down(destination: catalog.destination(), withModifiers: !modifiers.isEmpty)
        } else if let id = tap.up() { catalog.choose(id) }
    }
}
