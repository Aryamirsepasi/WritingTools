import SwiftUI
import MLXLLM
import MLXLMCommon

@MainActor
class LocalLLMStoreViewModel: ObservableObject {
    @Published var models: [LocalLLMModelManager] = []

    init() {
        loadModels()
    }

    private func loadModels() {
        let configs: [ModelConfiguration] = [
            ModelRegistry.llama3_2_3B_4bit,
            ModelRegistry.mistral7B4bit,
            ModelRegistry.phi3_5_4bit,
            ModelRegistry.llama3_1_8B_4bit,
            ModelRegistry.gemma_2_9b_it_4bit,
            ModelRegistry.qwen2_5_3B_4bit,
            ModelRegistry.qwen2_5_7B_4bit,
            ModelRegistry.qwen2_5_14B_4bit,
            ModelRegistry.mistral_small_24B_4bit
        ]
        self.models = configs.map { LocalLLMModelManager(configuration: $0) }
    }
}

extension ModelConfiguration {
    
    // TODO
    var displaySize: String {
        let identifier = String(describing: id).lowercased()
        if identifier.contains("llama") {
            return "~1.8GB"
        } else if identifier.contains("mistral") {
            return "~2GB"
        } else if identifier.contains("phi") {
            return "~1GB"
        } else if identifier.contains("code") {
            return "~3GB"
        } else {
            return "Unknown"
        }
    }
    
}

extension ModelRegistry{
    
    static public let qwen2_5_7B_4bit = ModelConfiguration(
        id: "mlx-community/Qwen2.5-7B-Instruct-4bit",
        defaultPrompt: "You are a helpful writing and coding assistant"
    )
    
    static public let qwen2_5_3B_4bit = ModelConfiguration(
        id: "mlx-community/Qwen2.5-3B-Instruct-4bit",
        defaultPrompt: "You are a helpful writing and coding assistant"
    )
    
    static public let qwen2_5_14B_4bit = ModelConfiguration(
        id: "mlx-community/Qwen2.5-14B-Instruct-4bit",
        defaultPrompt: "You are a helpful writing and coding assistant"
    )
    
    static public let mistral_small_24B_4bit = ModelConfiguration(
        id: "mlx-community/Mistral-Small-24B-Instruct-2501-4bit",
        defaultPrompt: "You are a helpful writing and coding assistant"
    )
}
