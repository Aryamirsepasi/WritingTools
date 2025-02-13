import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import SwiftUI

@MainActor
class LocalLLMProvider: ObservableObject, AIProvider {
    // MARK: - Published Properties for UI Feedback
    @Published var isProcessing = false
    @Published var output = ""
    @Published var modelInfo = ""
    @Published var stat = ""
    @Published var lastError: String?
    
    // MARK: - Generation Settings
    let generateParameters = GenerateParameters(temperature: 0.6)
    let maxTokens = 120000
    let displayEveryNTokens = 4
    
    // A flag to ensure we don’t start multiple generations concurrently.
    var running = false

    // Instead of keeping a fixed configuration, we use a manager that encapsulates
    // the model’s configuration, download, load, and deletion logic.
    @Published var modelManager: LocalLLMModelManager

    // MARK: - Initialization
    /// Initialize with a default model configuration (e.g. Llama 3.2 3B 4-bit).
    /// In practice you could update this later when the user selects a different model.
    init(configuration: ModelConfiguration = ModelRegistry.llama3_2_3B_4bit) {
        self.modelManager = LocalLLMModelManager(configuration: configuration)
        
        // Set an initial model information message.
        switch modelManager.loadState {
        case .idle:
            self.modelInfo = "Model needs to be downloaded"
        case .downloaded:
            self.modelInfo = "Model downloaded and ready to load"
        case .loaded:
            self.modelInfo = "Model loaded"
        }
    }
    
    // MARK: - Delegated Download / Load / Delete Operations
    
    /// Starts the download for the currently selected model.
    func startDownload() {
        modelManager.startDownload()
    }
    
    /// Cancels an in-progress download.
    func cancelDownload() {
        modelManager.cancelDownload()
    }
    
    /// Retries the download if it previously failed.
    func retryDownload() {
        modelManager.retryDownload()
    }
    
    /// Deletes the downloaded model.
    func deleteModel() throws {
        try modelManager.deleteModel()
    }
    
    /// Asynchronously loads the model.
    /// If the model is already loaded, it returns the container immediately.
    /// If the model has been downloaded but not “activated”, this calls the manager’s loadModel()
    /// to complete the loading process.
    func load() async throws -> ModelContainer {
        switch modelManager.loadState {
        case .loaded(let container):
            return container
        case .downloaded:
            try await modelManager.loadModel()
            if case .loaded(let container) = modelManager.loadState {
                return container
            }
        case .idle:
            break
        }
        throw NSError(domain: "LocalLLM", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model not available"])
    }
    
    // MARK: - Processing Text (Generation)
    func processText(systemPrompt: String? = "You are a helpful writing assistant.",
                     userPrompt: String,
                     images: [Data],
                     videos: [Data]? = nil,
                     streaming: Bool = false) async throws -> String {
        guard !running else {
            throw NSError(domain: "LocalLLM", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Generation already in progress"])
        }
        
        running = true
        isProcessing = true
        output = ""
        
        defer {
            Task { @MainActor in
                self.running = false
                self.isProcessing = false
            }
        }
        
        // Run OCR on attached images.
        var ocrExtractedText = ""
        for imageData in images {
            do {
                let recognized = try await OCRManager.shared.performOCR(on: imageData)
                if !recognized.isEmpty {
                    ocrExtractedText += recognized + "\n"
                }
            } catch {
                print("OCR error: \(error.localizedDescription)")
            }
        }
        
        let combinedUserPrompt = ocrExtractedText.isEmpty ? userPrompt : "\(userPrompt)\n\nOCR Extracted Text:\n\(ocrExtractedText)"
        let finalPrompt = systemPrompt.map { "\($0)\n\n\(combinedUserPrompt)" } ?? combinedUserPrompt
        
        let modelContainer = try await load()
        MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))
        
        let result = try await modelContainer.perform { [weak self] context in
            let input = try await context.processor.prepare(input: .init(prompt: finalPrompt))
            var accumulatedText = ""
            return try MLXLMCommon.generate(
                input: input,
                parameters: self?.generateParameters ?? GenerateParameters(temperature: 0.6),
                context: context
            ) { [weak self] tokens in
                let text = context.tokenizer.decode(tokens: tokens)
                if streaming {
                    Task { @MainActor [weak self] in
                        self?.output = text
                    }
                } else {
                    accumulatedText = text
                }
                if tokens.count >= (self?.maxTokens ?? 120000) {
                    return .stop
                } else {
                    return .more
                }
            }
        }
        
        if !streaming {
            DispatchQueue.main.async {
                self.output = result.output
            }
        }
        await MainActor.run { [weak self] in
            self?.stat = " Tokens/second: \(String(format: "%.3f", result.tokensPerSecond))"
        }
        return result.output
    }
    
    // MARK: - Cancel Ongoing Generation
    func cancel() {
        Task { @MainActor in
            running = false
            isProcessing = false
        }
    }
}
