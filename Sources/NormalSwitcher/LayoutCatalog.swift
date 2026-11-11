import Carbon
import Foundation

@MainActor
final class LayoutCatalog: NSObject {
    var changed: (() -> Void)?

    override init() {
        super.init()
        for name in [kTISNotifySelectedKeyboardInputSourceChanged, kTISNotifyEnabledKeyboardInputSourcesChanged] {
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(receivedChange), name: Notification.Name(name! as String), object: nil)
        }
    }

    @objc private func receivedChange() { changed?() }

    func layouts() -> [KeyboardLayout] {
        var ids = Set<String>()
        return sources().compactMap { source in
            guard let identifier = text(source, kTISPropertyInputSourceID), ids.insert(identifier).inserted else { return nil }
            let title = text(source, kTISPropertyLocalizedName) ?? identifier
            let languages = object(source, kTISPropertyInputSourceLanguages) as? [String] ?? []
            let language = languages.first ?? ""
            let code = language.split(separator: "-").first.map(String.init) ?? language
            return KeyboardLayout(id: identifier, name: title, shortName: code.isEmpty ? String(title.prefix(2)).uppercased() : code.uppercased(), isASCIICapable: object(source, kTISPropertyInputSourceIsASCIICapable) as? Bool ?? false)
        }
    }

    func selectedID() -> String? {
        guard let item = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return text(item, kTISPropertyInputSourceID)
    }

    func destination() -> String? {
        let items = layouts()
        guard items.count > 1 else { return nil }
        let current = items.firstIndex { $0.id == selectedID() }
        return items[current.map { ($0 + 1) % items.count } ?? 0].id
    }

    @discardableResult
    func choose(_ id: String) -> Bool {
        if selectedID() == id { return true }
        guard let source = sources().first(where: { text($0, kTISPropertyInputSourceID) == id }) else { return false }
        let success = TISSelectInputSource(source) == noErr
        changed?()
        return success
    }

    private func sources() -> [TISInputSource] {
        let candidates = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] ?? []
        return candidates.filter {
            text($0, kTISPropertyInputSourceCategory) == (kTISCategoryKeyboardInputSource as String)
                && (object($0, kTISPropertyInputSourceIsEnabled) as? Bool == true)
                && (object($0, kTISPropertyInputSourceIsSelectCapable) as? Bool == true)
        }
    }

    private func object(_ item: TISInputSource, _ key: CFString) -> AnyObject? {
        guard let value = TISGetInputSourceProperty(item, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(value).takeUnretainedValue()
    }

    private func text(_ item: TISInputSource, _ key: CFString) -> String? { object(item, key) as? String }
}
