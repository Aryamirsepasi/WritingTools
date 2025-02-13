import SwiftUI

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var geminiProvider: GeminiProvider
    @Published var openAIProvider: OpenAIProvider
    @Published var mistralProvider: MistralProvider
    @Published var localLLMProvider: LocalLLMProvider
    
    @Published var customInstruction: String = ""
    @Published var selectedText: String = ""
    @Published var isPopupVisible: Bool = false
    @Published var isProcessing: Bool = false
    @Published var previousApplication: NSRunningApplication?
    @Published var selectedImages: [Data] = []  // Store selected image data
    @Published var selectedVideos: [Data] = []  // NEW: Store selected video data
    
    @Published private(set) var currentProvider: String
    
    var activeProvider: any AIProvider {
        if currentProvider == "local" {
            return localLLMProvider
        } else if currentProvider == "openai" {
            return openAIProvider
        } else if currentProvider == "gemini" {
            return geminiProvider
        } else {
            return mistralProvider
        }
    }
    
    private init() {
        let asettings = AppSettings.shared
        self.currentProvider = asettings.currentProvider
        
        let geminiConfig = GeminiConfig(apiKey: asettings.geminiApiKey,
                                        modelName: asettings.geminiModel.rawValue)
        self.geminiProvider = GeminiProvider(config: geminiConfig)
        
        let openAIConfig = OpenAIConfig(apiKey: asettings.openAIApiKey,
                                        baseURL: asettings.openAIBaseURL,
                                        organization: asettings.openAIOrganization,
                                        project: asettings.openAIProject,
                                        model: asettings.openAIModel)
        self.openAIProvider = OpenAIProvider(config: openAIConfig)
        
        let mistralConfig = MistralConfig(apiKey: asettings.mistralApiKey,
                                          baseURL: asettings.mistralBaseURL,
                                          model: asettings.mistralModel)
        self.mistralProvider = MistralProvider(config: mistralConfig)
        
        self.localLLMProvider = LocalLLMProvider()
        
        if asettings.openAIApiKey.isEmpty && asettings.geminiApiKey.isEmpty && asettings.mistralApiKey.isEmpty {
            print("Warning: No API keys configured.")
        }
    }
    
    func saveGeminiConfig(apiKey: String, model: GeminiModel) {
        AppSettings.shared.geminiApiKey = apiKey
        AppSettings.shared.geminiModel = model
        
        let config = GeminiConfig(apiKey: apiKey, modelName: model.rawValue)
        geminiProvider = GeminiProvider(config: config)
    }
    
    func saveOpenAIConfig(apiKey: String, baseURL: String, organization: String?, project: String?, model: String) {
        let asettings = AppSettings.shared
        asettings.openAIApiKey = apiKey
        asettings.openAIBaseURL = baseURL
        asettings.openAIOrganization = organization
        asettings.openAIProject = project
        asettings.openAIModel = model
        
        let config = OpenAIConfig(apiKey: apiKey, baseURL: baseURL,
                                  organization: organization, project: project,
                                  model: model)
        openAIProvider = OpenAIProvider(config: config)
    }
    
    func saveMistralConfig(apiKey: String, baseURL: String, model: String) {
        let asettings = AppSettings.shared
        asettings.mistralApiKey = apiKey
        asettings.mistralBaseURL = baseURL
        asettings.mistralModel = model
        
        let config = MistralConfig(apiKey: apiKey, baseURL: baseURL, model: model)
        mistralProvider = MistralProvider(config: config)
    }
    
    func setCurrentProvider(_ provider: String) {
        currentProvider = provider
        AppSettings.shared.currentProvider = provider
        objectWillChange.send()
    }
    
    // NEW: Process a URL from the clipboard
    func processURLFromClipboard() {
        let pasteboard = NSPasteboard.general
        guard let clipboardString = pasteboard.string(forType: .string),
              let url = URL(string: clipboardString),
              (url.scheme == "http" || url.scheme == "https") else {
            print("No valid URL found in clipboard")
            return
        }
        
        isProcessing = true
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let extractedText = self.extractTextFromHTML(data: data)
                DispatchQueue.main.async {
                    self.selectedText = extractedText
                    self.isProcessing = false
                    print("Extracted text updated from clipboard URL")
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                print("Error processing URL: \(error.localizedDescription)")
            }
        }
    }
    
    func extractTextFromHTML(data: Data) -> String {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attrString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attrString.string
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    func handlePDFData(_ pdfData: Data) {
        let text = PDFHandler.extractText(from: pdfData)
        selectedText = text
    }
}
