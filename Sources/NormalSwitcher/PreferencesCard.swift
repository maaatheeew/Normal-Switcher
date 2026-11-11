import SwiftUI

struct PreferencesCard: View {
    @ObservedObject var model: SwitcherModel

    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $model.fnEnabled) {
                Label("Switch with Fn", systemImage: "globe")
            }
            .padding(.vertical, 13)
            Divider()
            Toggle(isOn: $model.launchAtLogin) {
                Label("Launch at login", systemImage: "sunrise")
            }
            .padding(.vertical, 13)
            .onChange(of: model.launchAtLogin) { _, _ in model.updateLoginItem() }
        }
        .toggleStyle(.switch)
        .tint(Palette.yellow)
        .font(.body)
        .padding(.horizontal, 16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}
