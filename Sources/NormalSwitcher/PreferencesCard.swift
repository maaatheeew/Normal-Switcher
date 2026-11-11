import SwiftUI

struct PreferencesCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var model: SwitcherModel

    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $model.fnEnabled) {
                Text("Switch normally with Fn")
            }
            .padding(.vertical, 10)
            Divider()
            Toggle(isOn: $model.launchAtLogin) {
                Text("Launch at login")
            }
            .padding(.vertical, 10)
            .onChange(of: model.launchAtLogin) { _, _ in model.updateLoginItem() }
        }
        .toggleStyle(.switch)
        .tint(colorScheme == .dark ? .white : .black)
        .font(.body)
    }
}
