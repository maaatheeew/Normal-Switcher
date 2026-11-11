import SwiftUI

struct LanguageButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let layout: KeyboardLayout
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                HStack(spacing: 5) {
                    Text(layout.shortName).font(.title3.bold())
                    if selected { Image(systemName: "checkmark.circle.fill").font(.caption) }
                }
                Text(layout.name).font(.caption).lineLimit(1)
            }
            .foregroundStyle(selected ? (colorScheme == .dark ? Color.black : Color.white) : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(selected ? Color.primary : Color.clear, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(selected ? 0 : 0.18), lineWidth: 1))
        .accessibilityLabel(layout.name)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}
