import Foundation
import Combine

@MainActor
final class MediaImportCoordinator: ObservableObject {
    static let shared = MediaImportCoordinator()

    @Published var pendingText: String?

    private init() {}

    func consumePendingText() -> String? {
        guard let raw = pendingText else { return nil }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingText = nil
        guard !text.isEmpty else { return nil }
        return text
    }
}
