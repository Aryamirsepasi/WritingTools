import SwiftUI

struct LocalLLMSettingsView: View {
    @ObservedObject private var llmEvaluator: LocalLLMProvider
    @State private var showingDeleteAlert = false
    @State private var showingErrorAlert = false

    init(evaluator: LocalLLMProvider) {
        self.llmEvaluator = evaluator
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !llmEvaluator.modelInfo.isEmpty {
                Text(llmEvaluator.modelInfo)
                    .textFieldStyle(.roundedBorder)
            }

            Button("Open Model Store") {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.showLocalLLMStoreManually()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert("Delete Model", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                do {
                    try llmEvaluator.deleteModel()
                } catch {
                    llmEvaluator.lastError = "Failed to delete model: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        } message: {
            Text("Are you sure you want to delete the downloaded model? You'll need to download it again to use local processing.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = llmEvaluator.lastError {
                Text(error)
            }
        }
    }
}
