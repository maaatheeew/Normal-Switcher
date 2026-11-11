import SwiftUI

struct SwitcherView: View {
    @ObservedObject var model: SwitcherModel

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 20) {
                LanguagePicker(model: model)
                PreferencesCard(model: model)
                if model.needsKeyboardAccess {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Allow keyboard access once to switch languages with Fn.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            Button("Allow access", systemImage: "keyboard", action: model.requestKeyboardAccess)
                                .buttonStyle(.glass)
                            Button("Not now", action: model.cancelAccessRequest).buttonStyle(.plain)
                        }
                    }
                }
                if let notice = model.notice {
                    Text(notice).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Menu {
                        Text("Normal Switcher 1.0")
                        Text("By Matthew Avgul")
                        Divider()
                        Picker("Appearance", selection: $model.appearance) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        Button("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right", action: model.openSource)
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 24, height: 18)
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                    .accessibilityLabel("About Normal Switcher")
                    Spacer()
                    Button("Quit", systemImage: "power", action: model.quit)
                        .buttonStyle(.glass).controlSize(.small)
                }
                .foregroundStyle(.secondary)
            }
            .padding(Palette.padding)
        }
        .frame(width: Palette.width)
    }
}
