import Foundation
import Combine

@MainActor
class BaseViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    @Published var isLoading = false
    @Published var errorMessage: String?

    func handleError(_ error: Error) {
        self.errorMessage = error.localizedDescription
        print("Error: \(error)")
    }

    func clearError() {
        self.errorMessage = nil
    }

    deinit {
        cancellables.removeAll()
    }
}