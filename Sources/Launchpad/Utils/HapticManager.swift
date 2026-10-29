import AppKit

@MainActor
public final class HapticManager {
    public static let shared = HapticManager()

    private init() {}

    public func playClick() {
        guard AppSettings.shared.enableHapticFeedback else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }

    public func playAction() {
        guard AppSettings.shared.enableHapticFeedback else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }

    public func playPage() {
        guard AppSettings.shared.enableHapticFeedback else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }
}
