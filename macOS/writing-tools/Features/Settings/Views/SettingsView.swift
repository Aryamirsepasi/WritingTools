import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var shortcutText = UserDefaults.standard.string(forKey: "shortcut") ?? "⌥ Space"
    @State private var useGradientTheme = UserDefaults.standard.bool(forKey: "use_gradient_theme")
    @State private var selectedTheme = UserDefaults.standard.string(forKey: "theme_style") ?? "gradient"
    @State private var selectedProvider = UserDefaults.standard.string(forKey: "current_provider") ?? "gemini"

    @State private var geminiApiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
    @State private var selectedGeminiModel = GeminiModel(rawValue: UserDefaults.standard.string(forKey: "gemini_model") ?? "gemini-1.5-flash-latest") ?? .oneflash

    @State private var openAIApiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    @State private var openAIBaseURL = UserDefaults.standard.string(forKey: "openai_base_url") ?? OpenAIConfig.defaultBaseURL
    @State private var openAIOrganization = UserDefaults.standard.string(forKey: "openai_organization") ?? ""
    @State private var openAIProject = UserDefaults.standard.string(forKey: "openai_project") ?? ""
    @State private var openAIModelName = UserDefaults.standard.string(forKey: "openai_model") ?? OpenAIConfig.defaultModel

    @State private var mistralApiKey = UserDefaults.standard.string(forKey: "mistral_api_key") ?? ""
    @State private var mistralBaseURL = UserDefaults.standard.string(forKey: "mistral_base_url") ?? MistralConfig.defaultBaseURL
    @State private var mistralModel = UserDefaults.standard.string(forKey: "mistral_model") ?? MistralConfig.defaultModel

    @State private var displayShortcut = ""

    var showOnlyApiSetup: Bool = false

    var body: some View {
        Form {
            if !showOnlyApiSetup {
                Section("General Settings") {
                    Form {
                        KeyboardShortcuts.Recorder("Global Shortcut:", name: .showPopup)
                    }

                    Section("Appearance") {
                        Picker("Theme", selection: $selectedTheme) {
                            Text("Standard").tag("standard")
                            Text("Gradient").tag("gradient")
                            Text("Glass").tag("glass")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedTheme) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "theme_style")
                            useGradientTheme = (newValue != "standard")
                        }
                    }
                }

                Section("AI Provider") {
                    Picker("Provider", selection: $selectedProvider) {
                        Text("Gemini AI").tag("gemini")
                        Text("OpenAI / Local LLM via Host").tag("openai")
                        Text("Mistral AI").tag("mistral")
                        Text("Local LLM (LLama 3.2 3B)").tag("local")
                    }
                }
            }

            if selectedProvider == "local" {
                LocalLLMSettingsView(evaluator: appState.localLLMProvider)
            } else if selectedProvider == "gemini" {
                Section("Gemini AI Settings") {
                    TextField("API Key", text: $geminiApiKey)
                        .textFieldStyle(.roundedBorder)

                    Picker("Model", selection: $selectedGeminiModel) {
                        ForEach(GeminiModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }

                    Button("Get API Key") {
                        NSWorkspace.shared.open(URL(string: "https://aistudio.google.com/app/apikey")!)
                    }
                }
            } else if selectedProvider == "mistral" {
                Section("Mistral AI Settings") {
                    TextField("API Key", text: $mistralApiKey)
                        .textFieldStyle(.roundedBorder)

                    TextField("Base URL", text: $mistralBaseURL)
                        .textFieldStyle(.roundedBorder)

                    Picker("Model", selection: $mistralModel) {
                        ForEach(MistralModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model.rawValue)
                        }
                    }

                    Button("Get Mistral API Key") {
                        NSWorkspace.shared.open(URL(string: "https://console.mistral.ai/api-keys/")!)
                    }
                }
            } else {
                Section("OpenAI / Local LLM Settings") {
                    TextField("API Key", text: $openAIApiKey)
                        .textFieldStyle(.roundedBorder)

                    TextField("Base URL", text: $openAIBaseURL)
                        .textFieldStyle(.roundedBorder)

                    TextField("Model Name", text: $openAIModelName)
                        .textFieldStyle(.roundedBorder)

                    Text("OpenAI models include: gpt-4o, gpt-3.5-turbo, etc.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    LinkText()

                    TextField("Organization ID (Optional)", text: $openAIOrganization)
                        .textFieldStyle(.roundedBorder)

                    TextField("Project ID (Optional)", text: $openAIProject)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Get OpenAI API Key") {
                            NSWorkspace.shared.open(URL(string: "https://platform.openai.com/account/api-keys")!)
                        }

                        Button("Ollama Documentation") {
                            NSWorkspace.shared.open(URL(string: "https://ollama.ai/download")!)
                        }
                    }
                }
            }

            Button(showOnlyApiSetup ? "Complete Setup" : "Save") {
                saveSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 500)
        .windowBackground(useGradient: useGradientTheme)
    }

    private func saveSettings() {
        let oldShortcut = UserDefaults.standard.string(forKey: "shortcut")

        UserDefaults.standard.set(shortcutText, forKey: "shortcut")
        UserDefaults.standard.set(selectedTheme, forKey: "theme_style")
        UserDefaults.standard.set(selectedTheme != "standard", forKey: "use_gradient_theme")

        if selectedProvider == "gemini" {
            appState.saveGeminiConfig(apiKey: geminiApiKey, model: selectedGeminiModel)
        } else if selectedProvider == "mistral" {
            appState.saveMistralConfig(
                apiKey: mistralApiKey,
                baseURL: mistralBaseURL,
                model: mistralModel
            )
        } else {
            appState.saveOpenAIConfig(
                apiKey: openAIApiKey,
                baseURL: openAIBaseURL,
                organization: openAIOrganization,
                project: openAIProject,
                model: openAIModelName
            )
        }

        appState.setCurrentProvider(selectedProvider)

        if oldShortcut != shortcutText {
            NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
        }

        if showOnlyApiSetup {
            UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
        }

        DispatchQueue.main.async {
            if self.showOnlyApiSetup {
                WindowManager.shared.cleanupWindows()
            } else {
                if let window = NSApplication.shared.windows.first(where: { $0.contentView?.subviews.contains(where: { $0 is NSHostingView<SettingsView> }) ?? false }) {
                    window.close()
                }
            }
        }
    }
}
