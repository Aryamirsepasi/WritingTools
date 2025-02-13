import SwiftUI

class HomeViewModel: ObservableObject {
    @Published var appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }
}
