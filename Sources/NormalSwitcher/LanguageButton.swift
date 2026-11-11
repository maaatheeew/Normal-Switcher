import SwiftUI

struct LanguageButton: View {
    let layout: KeyboardLayout
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                HStack(spacing: 5) {
                    Text(layout.shortName).font(.title2.bold())
                    if selected { Image(systemName: "checkmark.circle.fill").font(.caption) }
                }
                Text(layout.name).font(.caption).lineLimit(1)
            }
            .foregroundStyle(selected ? Color.black : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 66)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(selected ? .regular.tint(Palette.yellow).interactive() : .regular.interactive(), in: .rect(cornerRadius: 18))
        .accessibilityLabel(layout.name)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}
