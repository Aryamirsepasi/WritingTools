import SwiftUI

struct ModelCardView: View {
    @ObservedObject var modelManager: LocalLLMModelManager
    @State private var isLoadingModel: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    var modelIcon: (symbol: String, color: Color) {
        let id = String(describing: modelManager.configuration.id).lowercased()
        switch true {
        case id.contains("llama"):
            return ("cpu", .blue)
        case id.contains("mistral"):
            return ("cpu", .orange)
        case id.contains("phi"):
            return ("cpu", .green)
        case id.contains("qwen"):
            return ("cpu", .yellow)
        default:
            return ("cpu", .gray)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: modelIcon.symbol)
                    .font(.system(size: 24))
                    .foregroundColor(modelIcon.color)
                    .frame(width: 32, height: 32)
                
                let idString = String(describing: modelManager.configuration.id)
                let replacements = [
                    "id(": "",
                    "mlx-community/": "",
                    ")": ""
                ]

                let processedId = replacements.reduce(idString) { (result, replacement) in
                    result.replacingOccurrences(of: replacement.key, with: replacement.value)
                }

                Text(processedId)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if case .loaded = modelManager.loadState {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Toggle("", isOn: .constant(false))
                        .labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Size: \(modelManager.configuration.displaySize)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let error = modelManager.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            if modelManager.isDownloading {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: modelManager.downloadProgress) {
                        Text("\(Int(modelManager.downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .progressViewStyle(.linear)

                    Button("Cancel") {
                        modelManager.cancelDownload()
                    }
                    .foregroundColor(.red)
                }
            } else {
                switch modelManager.loadState {
                case .idle:
                    Button("Download") {
                        modelManager.startDownload()
                    }
                    .buttonStyle(.borderedProminent)
                case .downloaded:
                    HStack {
                        Button("Load") {
                            Task {
                                await loadModel()
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Delete") {
                            deleteModel()
                        }
                        .foregroundColor(.red)
                    }
                case .loaded:
                    HStack {
                        Text("Model Loaded")
                            .foregroundColor(.green)
                        Spacer()
                        Button("Delete") {
                            deleteModel()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
        .cornerRadius(12)
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func loadModel() async {
        do {
            isLoadingModel = true
            try await modelManager.loadModel()
            isLoadingModel = false
        } catch {
            isLoadingModel = false
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func deleteModel() {
        do {
            try modelManager.deleteModel()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
