import Foundation

struct MistralConfig: Codable {
    var apiKey: String
    var baseURL: String
    var model: String
    
    static let defaultBaseURL = "https://api.mistral.ai/v1"
    static let defaultModel = "mistral-small-latest"
}
enum MistralModel: String, CaseIterable {
    case mistralSmall = "mistral-small-latest"
    case mistralMedium = "mistral-medium-latest"
    case mistralLarge = "mistral-large-latest"
    
    var displayName: String {
        switch self {
        case .mistralSmall: return "Mistral Small (Fast)"
        case .mistralMedium: return "Mistral Medium (Balanced)"
        case .mistralLarge: return "Mistral Large (Most Capable)"
        }
    }
}
@MainActor
class MistralProvider: ObservableObject, AIProvider {
    @Published var isProcessing = false
    private var config: MistralConfig
    
    init(config: MistralConfig) {
        self.config = config
    }
    
    
    func processText(systemPrompt: String? = "You are a helpful writing assistant.",
                     userPrompt: String,
                     images: [Data],
                     videos: [Data]? = nil,
                     streaming: Bool = false) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        // Run OCR on any attached images.
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
        
        var messages: [[String: Any]] = []
        if let systemPrompt = systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": combinedUserPrompt])
        
        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": messages
        ]
        
        guard let url = URL(string: "\(config.baseURL)/chat/completions") else {
            throw NSError(domain: "MistralAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL."])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "MistralAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server returned an error."])
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "MistralAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response."])
        }
        return content
    }
    
    func cancel() {
        isProcessing = false
    }
}
