import Combine
import Foundation

@MainActor
final class ActivationFeedback: ObservableObject {
    @Published private(set) var burst = 0
    @Published var burstStartedAt: Date?
    @Published var messageStartedAt: Date?
    private let model: SwitcherModel
    private var awaitingActivation = false
    private var observation: AnyCancellable?

    init(model: SwitcherModel) {
        self.model = model
        observation = model.$activationSequence.dropFirst().sink { [weak self] _ in
            guard let self, self.awaitingActivation else { return }
            self.awaitingActivation = false
            self.burst += 1
        }
    }

    func toggle() {
        if model.fnEnabled || model.needsKeyboardAccess {
            awaitingActivation = false
            clearVisualFeedback()
            model.fnEnabled = false
        } else {
            awaitingActivation = true
            model.fnEnabled = true
            if !model.fnEnabled && !model.needsKeyboardAccess { awaitingActivation = false }
        }
    }

    func clearVisualFeedback() {
        burstStartedAt = nil
        messageStartedAt = nil
    }

}
