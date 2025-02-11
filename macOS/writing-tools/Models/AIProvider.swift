import Foundation

@MainActor
protocol AIProvider: ObservableObject {
    // Indicates if provider is processing a request
    var isProcessing: Bool { get set }
    
    // Process text with optional system prompt, images and videos
    func processText(systemPrompt: String?, userPrompt: String, images: [Data], videos: [Data]?, streaming: Bool) async throws -> String

    // Cancel ongoing requests
    func cancel()
}
