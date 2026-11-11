import SwiftUI

struct LanguagePicker: View {
    @ObservedObject var model: SwitcherModel

    var body: some View {
        VStack(spacing: 10) {
            if model.layouts.isEmpty {
                Text("Add a keyboard language in System Settings.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    ForEach(model.layouts.prefix(4)) { layout in
                        LanguageButton(layout: layout, selected: model.selectedID == layout.id) { model.select(layout) }
                    }
                }
                if model.layouts.count > 4 {
                    Menu("More languages") {
                        ForEach(model.layouts.dropFirst(4)) { layout in
                            Button(layout.name) { model.select(layout) }
                        }
                    }
                }
            }
            Label(model.fnEnabled ? "Tap fn to switch languages." : "Fn switching is paused.", systemImage: model.fnEnabled ? "keyboard" : "pause.circle")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
