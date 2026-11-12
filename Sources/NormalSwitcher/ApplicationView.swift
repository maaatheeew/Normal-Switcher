import SwiftUI

struct ApplicationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var model: SwitcherModel
    @StateObject private var feedback: ActivationFeedback

    init(model: SwitcherModel) {
        self.model = model
        _feedback = StateObject(wrappedValue: ActivationFeedback(model: model))
    }

    var body: some View {
        VStack(spacing: 32) {
            LargeFnSwitch(isOn: $model.fnEnabled, toggle: feedback.toggle)
                .fixedSize()
                .scaleEffect(3)
                .frame(width: 180, height: 90)

            Toggle("Launch at login", isOn: $model.launchAtLogin)
                .toggleStyle(.checkbox)
                .fixedSize()
                .onChange(of: model.launchAtLogin) { model.updateLoginItem() }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 56)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if let startedAt = feedback.burstStartedAt, !reduceMotion {
                ConfettiBurst()
                    .id(startedAt)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottom) {
            if feedback.messageStartedAt != nil {
                Text("Your keyboard. Finally yours.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 22)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: feedback.burst) {
            feedback.messageStartedAt = .now
            if !reduceMotion { feedback.burstStartedAt = .now }
        }
        .onChange(of: model.fnEnabled) {
            if !model.fnEnabled { feedback.clearVisualFeedback() }
        }
        .onChange(of: reduceMotion) {
            if reduceMotion { feedback.burstStartedAt = nil }
        }
        .task(id: feedback.burstStartedAt) {
            guard feedback.burstStartedAt != nil else { return }
            do { try await Task.sleep(for: ConfettiBurst.duration) } catch { return }
            feedback.burstStartedAt = nil
        }
        .task(id: feedback.messageStartedAt) {
            guard feedback.messageStartedAt != nil else { return }
            do { try await Task.sleep(for: .milliseconds(2400)) } catch { return }
            feedback.messageStartedAt = nil
        }
        .onDisappear { feedback.clearVisualFeedback() }
    }
}
