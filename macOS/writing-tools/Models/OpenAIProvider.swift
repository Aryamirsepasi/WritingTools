import Foundation
import Vision
import AppKit

struct OpenAIConfig: Codable {
    var apiKey: String
    var baseURL: String
    var organization: String?
    var project: String?
    var model: String
    
    static let defaultBaseURL = "https://api.openai.com/v1"
    static let defaultModel = "gpt-4o"
}

enum OpenAIModel: String, CaseIterable {
    case gpt4 = "gpt-4"
    case gpt35Turbo = "gpt-3.5-turbo"
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    
    var displayName: String {
        switch self {
        case .gpt4: return "GPT-4 (Most Capable)"
        case .gpt35Turbo: return "GPT-3.5 Turbo (Faster)"
        case .gpt4o: return "GPT-4o (Optimized)"
        case .gpt4oMini: return "GPT-4o Mini (Lightweight)"
        }
    }
}
@MainActor
class OpenAIProvider: ObservableObject, AIProvider {
    @Published var isProcessing = false
    private var config: OpenAIConfig
    
    init(config: OpenAIConfig) {
        self.config = config
    }
    
    
    func processText(systemPrompt: String? = "You are a helpful writing assistant.",
                     userPrompt: String,
                     images: [Data],
                     streaming: Bool = false) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        // Run OCR on any attached images.
        var ocrExtractedText = ""
        for image in images {
            do {
                let recognized = try await OCRManager.shared.performOCR(on: image)
                if !recognized.isEmpty {
                    ocrExtractedText += recognized + "\n"
                }
            } catch {
                print("OCR error (OpenAI): \(error.localizedDescription)")
            }
        }
        let combinedUserPrompt = ocrExtractedText.isEmpty ? userPrompt : "\(userPrompt)\n\nOCR Extracted Text:\n\(ocrExtractedText)"
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt ?? "You are a helpful writing assistant."],
            ["role": "user", "content": combinedUserPrompt]
        ]
        
        var requestBody: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "temperature": 0.5
        ]
        if streaming {
            requestBody["stream"] = true
        }
        
        let baseURL = config.baseURL.isEmpty ? OpenAIConfig.defaultBaseURL : config.baseURL
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw NSError(domain: "OpenAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL."])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        if let organization = config.organization, !organization.isEmpty {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        if streaming {
            // Use streaming bytes API:
            let (stream, response) = try await URLSession.shared.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "OpenAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server returned an error."])
            }
            var finalResult = ""
            for try await line in stream.lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                if trimmed.contains("[DONE]") { break }
                if let data = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let delta = choices.first?["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    finalResult += content
                    // (You could also call a streaming callback here to update UI continuously.)
                }
            }
            return finalResult
        } else {
            // Non-streaming call
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "OpenAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server returned an error."])
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw NSError(domain: "OpenAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response."])
            }
            return content
        }
    }
    
    func cancel() {
        isProcessing = false
    }
}
