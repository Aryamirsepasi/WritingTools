import Foundation
import SwiftUI
import MLXLLM
import MLXLMCommon

/// A generic manager for one local LLM model based on its configuration.
/// It “wraps” the download, load, and delete functions so that they work
/// for any model in the registry.
@MainActor
class LocalLLMModelManager: ObservableObject, Identifiable {
    let id = UUID()
    let configuration: ModelConfiguration

    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0
    @Published var downloadTask: Task<ModelContainer, Error>?
    @Published var loadState: LoadState = .idle
    @Published var lastError: String?
    
    // When download completes the container is stored here.
    var downloadedModel: ModelContainer?

    enum LoadState {
        case idle           // not downloaded yet
        case downloaded     // downloaded and waiting for user “load”
        case loaded(ModelContainer)  // model is active
    }
    
    private var isCancelled = false
    private var retryCount: Int = 0
    private let maxRetries = 3

    /// Compute a safe “modelPath” from the configuration id.
    /// For example, if the id is "mlx-community/Llama-3.2-3B-Instruct-4bit",
    /// we replace the "/" with "_" and then store it under a folder (here “LocalLLMModels”).
    private var modelPathComponent: String {
        "LocalLLMModels/\(configuration.id)"
    }
    
    /// The full URL for the download directory.
    private var modelDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(modelPathComponent)
    }
    
    init(configuration: ModelConfiguration) {
        self.configuration = configuration
        checkModelStatus()
    }
    
    /// Check whether there are already files downloaded for this model.
    private func checkModelStatus() {
        if FileManager.default.fileExists(atPath: modelDirectory.path) {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: modelDirectory.path),
               !files.isEmpty {
                loadState = .downloaded
            } else {
                loadState = .idle
            }
        } else {
            loadState = .idle
        }
    }
    
    /// Start downloading (and “loading”) the model.
    func startDownload() {
        guard downloadTask == nil else { return }
        isCancelled = false
        retryCount = 0
        isDownloading = true
        downloadProgress = 0
        lastError = nil
        
        downloadTask = Task {
            do {
                // Call the (unchangeable) LLMModelFactory to download the model.
                let modelContainer = try await LLMModelFactory.shared.loadContainer(
                    configuration: configuration
                ) { [weak self] progress in
                    Task { @MainActor in
                        guard let self = self, !self.isCancelled else { return }
                        self.downloadProgress = progress.fractionCompleted
                    }
                }
                await MainActor.run {
                    self.isDownloading = false
                    self.downloadProgress = 1.0
                    self.downloadedModel = modelContainer
                    self.loadState = .downloaded
                }
                return modelContainer
            } catch {
                await MainActor.run {
                    self.isDownloading = false
                    self.downloadProgress = 0
                    self.lastError = error.localizedDescription
                    self.downloadTask = nil
                }
                throw error
            }
        }
    }
    
    /// Cancel an in‐progress download.
    func cancelDownload() {
        isCancelled = true
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0
        lastError = "Download cancelled"
    }
    
    /// Retry download (up to a maximum number of attempts).
    func retryDownload() {
        guard retryCount < maxRetries else {
            lastError = "Maximum retry attempts reached"
            return
        }
        retryCount += 1
        startDownload()
    }
    
    /// “Load” the model – for example, set it as the active LLM in your project.
    /// (Here we simply update the state; you should integrate the model container
    /// into your project’s active LLM instance.)
    func loadModel() async throws {
        guard case .downloaded = loadState, let container = downloadedModel else {
            throw NSError(domain: "LocalLLM", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Model not downloaded"])
        }
        // Additional initialization could go here.
        loadState = .loaded(container)
        // TODO: Integrate `container` into your active LLM instance.
    }
    
    /// Delete the downloaded model.
    func deleteModel() throws {
        guard !isDownloading else {
            throw NSError(domain: "LocalLLM", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot delete while downloading"])
        }
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: modelDirectory.path) {
            try fileManager.removeItem(at: modelDirectory)
            loadState = .idle
            downloadedModel = nil
        } else {
            throw NSError(domain: "LocalLLM", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Model directory not found"])
        }
    }
}
