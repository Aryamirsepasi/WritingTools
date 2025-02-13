import SwiftUI

class OnboardingViewModel: ObservableObject {
    @Published var appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }
}
