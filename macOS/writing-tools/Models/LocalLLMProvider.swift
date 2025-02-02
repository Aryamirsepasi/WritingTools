import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import SwiftUI

@MainActor
class LocalLLMProvider: ObservableObject, AIProvider {
    @Published var isProcessing = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var downloadTask: Task<ModelContainer, Error>?
    @Published var output = ""
    @Published var modelInfo = ""
    @Published var stat = ""
    @Published var lastError: String?
    @Published var retryCount: Int = 0
    
    var running = false
    private var isCancelled = false
    private let modelDirectory: URL
    private let maxRetries = 3
    
    
    // Using Llama3.2 4-bit quantized model as default for better device compatibility
    let modelConfiguration = ModelRegistry.llama3_2_3B_4bit
    let generateParameters = GenerateParameters(temperature: 0.6)
    let maxTokens = 4096
    let displayEveryNTokens = 4
    
    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }
    
    var loadState = LoadState.idle
    
    init() {
        // Get the Documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not find Documents directory")
            modelDirectory = FileManager.default.temporaryDirectory // Fallback
            return
        }
        
        // Set the correct model directory path
        modelDirectory = documentsPath
            .appendingPathComponent("huggingface/models/mlx-community/Phi-3.5-mini-instruct-4bit")
        
        
        // Limit the buffer cache to 20MB
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
        
        // Check if model already exists
        checkModelStatus()
    }
    
    private func checkModelStatus() {
        if FileManager.default.fileExists(atPath: modelDirectory.path) {
            let modelFiles = try? FileManager.default.contentsOfDirectory(atPath: modelDirectory.path)
            if modelFiles?.isEmpty == false {
                loadState = .idle // Will load on demand
                modelInfo = "Model available"
            } else {
                loadState = .idle
                modelInfo = "Model needs to be downloaded"
            }
        } else {
            loadState = .idle
            modelInfo = "Model needs to be downloaded"
        }
    }
    
    func startDownload() {
        guard downloadTask == nil else { return }
        isCancelled = false
        retryCount = 0
        
        downloadTask = Task {
            return try await load()
        }
    }
    
    func cancelDownload() {
        isCancelled = true
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0
        modelInfo = "Download cancelled"
        lastError = nil
    }
    
    func retryDownload() {
        guard retryCount < maxRetries else {
            lastError = "Maximum retry attempts reached"
            return
        }
        retryCount += 1
        startDownload()
    }
    
    func deleteModel() throws {
        // First ensure we're not currently downloading or using the model
        guard !isDownloading && !running else {
            throw NSError(domain: "LocalLLM",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot delete while model is in use"])
        }
        
        // Get the Documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "LocalLLM",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not find Documents directory"])
        }
        
        // Construct the path to the model
        let modelPath = documentsPath
            .appendingPathComponent("huggingface/models/mlx-community/Phi-3.5-mini-instruct-4bit")
        
        do {
            // Check if directory exists
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: modelPath.path, isDirectory: &isDirectory)
            
            guard exists && isDirectory.boolValue else {
                throw NSError(domain: "LocalLLM",
                              code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Model directory not found"])
            }
            
            // Delete the directory
            try FileManager.default.removeItem(at: modelPath)
            
            // Reset state
            loadState = .idle
            modelInfo = "Model deleted"
            lastError = nil
            
            print("Model directory deleted: \(modelPath.path)")
        } catch {
            print("Failed to delete model: \(error)")
            throw error
        }
    }
    
    func load() async throws -> ModelContainer {
        guard !isCancelled else {
            throw CancellationError()
        }
        
        switch loadState {
        case .idle:
            isDownloading = true
            downloadProgress = 0
            lastError = nil
            
            do {
                let modelContainer = try await LLMModelFactory.shared.loadContainer(
                    configuration: modelConfiguration
                ) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self = self, !self.isCancelled else { return }
                        self.downloadProgress = progress.fractionCompleted
                        self.modelInfo = "Downloading \(self.modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                    }
                }
                
                let numParams = await modelContainer.perform { context in
                    context.model.numParameters()
                }
                
                isDownloading = false
                downloadProgress = 1.0
                modelInfo = "Loaded \(modelConfiguration.id). Weights: \(numParams / (1024*1024))M"
                loadState = .loaded(modelContainer)
                downloadTask = nil
                
                return modelContainer
                
            } catch let error as NSError {
                isDownloading = false
                downloadProgress = 0
                
                if error.domain == NSURLErrorDomain {
                    lastError = "Network error: \(error.localizedDescription)"
                } else {
                    lastError = "Error: \(error.localizedDescription)"
                }
                
                modelInfo = lastError ?? "Unknown error occurred"
                downloadTask = nil
                throw error
            }
            
        case .loaded(let modelContainer):
            return modelContainer
        }
    }
    
    // MARK: - Updated processText with OCR support
    func processText(systemPrompt: String?, userPrompt: String, images: [Data], streaming: Bool = false) async throws -> String {
        guard !running else {
            throw NSError(domain: "LocalLLM", code: -1, userInfo: [NSLocalizedDescriptionKey: "Generation already in progress"])
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
        
        // Run OCR on attached images
        var ocrExtractedText = ""
        for image in images {
            do {
                let recognized = try await OCRManager.shared.performOCR(on: image)
                if !recognized.isEmpty {
                    ocrExtractedText += recognized + "\n"
                }
            } catch {
                print("OCR error (LocalLLM): \(error.localizedDescription)")
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
                    // Update continuously
                    Task { @MainActor [weak self] in
                        self?.output = text
                    }
                } else {
                    // Accumulate without intermediate updates
                    accumulatedText = text
                }
                if tokens.count >= (self?.maxTokens ?? 240) {
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
    
    
    func cancel() {
        Task { @MainActor in
            running = false
            isProcessing = false
        }
    }
}
