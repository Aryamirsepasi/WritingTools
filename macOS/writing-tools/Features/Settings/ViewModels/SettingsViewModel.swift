import SwiftUI

class SettingsViewModel: ObservableObject {
    @Published var appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }
}
