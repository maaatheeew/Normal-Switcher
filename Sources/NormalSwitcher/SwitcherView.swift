import SwiftUI

struct SwitcherView: View {
    @ObservedObject var model: SwitcherModel

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 14) {
                PreferencesCard(model: model)
                if model.needsKeyboardAccess {
                    VStack(alignment: .center, spacing: 10) {
                        Text("Allow keyboard access to switch languages with Fn.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Allow access", systemImage: "keyboard", action: model.requestKeyboardAccess)
                            .buttonStyle(.glass)
                            .buttonBorderShape(.capsule)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                if let notice = model.notice {
                    Text(notice).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Menu {
                        Text("Normal Switcher 1.0.4")
                        Text("By Matthew Avgul")
                        Divider()
                        Button("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right", action: model.openSource)
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 24, height: 18)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .accessibilityLabel("About Normal Switcher")
                    Spacer()
                    Button("Quit", action: model.quit)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .controlSize(.regular)
                }
                .foregroundStyle(.secondary)
            }
            .padding(Palette.padding)
        }
        .frame(width: Palette.width)
    }
}
