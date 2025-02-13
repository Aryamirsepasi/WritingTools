import SwiftUI

class AboutViewModel: ObservableObject {
    @Published var updateChecker = UpdateChecker.shared
}
