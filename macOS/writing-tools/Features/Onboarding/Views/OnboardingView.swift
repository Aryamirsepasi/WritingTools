import SwiftUI
import KeyboardShortcuts

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @State private var currentStep = 0
    @State private var useGradientTheme = true
    @State private var selectedTheme = UserDefaults.standard.string(forKey: "theme_style") ?? "gradient"
    @State private var selectedProvider = UserDefaults.standard.string(forKey: "current_provider") ?? "gemini"

    @State private var geminiApiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
    @State private var selectedGeminiModel = GeminiModel(rawValue: UserDefaults.standard.string(forKey: "gemini_model") ?? "gemini-2.0-flash") ?? .twoflash
    @State private var openAIApiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    @State private var openAIBaseURL = UserDefaults.standard.string(forKey: "openai_base_url") ?? OpenAIConfig.defaultBaseURL
    @State private var openAIOrganization = UserDefaults.standard.string(forKey: "openai_organization") ?? ""
    @State private var openAIProject = UserDefaults.standard.string(forKey: "openai_project") ?? ""
    @State private var openAIModelName = UserDefaults.standard.string(forKey: "openai_model") ?? OpenAIConfig.defaultModel
    @State private var mistralApiKey = UserDefaults.standard.string(forKey: "mistral_api_key") ?? ""
    @State private var mistralBaseURL = UserDefaults.standard.string(forKey: "mistral_base_url") ?? MistralConfig.defaultBaseURL
    @State private var mistralModel = UserDefaults.standard.string(forKey: "mistral_model") ?? MistralConfig.defaultModel

    private let steps = [
        OnboardingStep(
            title: "Welcome to WritingTools!",
            description: "Your AI-powered writing assistant",
            isPermissionStep: false
        ),
        OnboardingStep(
            title: "Key Features",
            description: "Discover what WritingTools can do for you",
            isPermissionStep: false
        ),
        OnboardingStep(
            title: "Enable Accessibility",
            description: "WritingTools needs accessibility access to enhance your writing experience",
            isPermissionStep: true
        ),
        OnboardingStep(
            title: "Choose Your AI Provider",
            description: "Select and configure your preferred AI model",
            isPermissionStep: false
        ),
        OnboardingStep(
            title: "Customize Experience",
            description: "Set up your shortcuts and theme",
            isPermissionStep: false
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    switch currentStep {
                    case 0:
                        welcomeStep
                    case 1:
                        featuresStep
                    case 2:
                        accessibilityStep
                    case 3:
                        aiProviderStep
                    case 4:
                        customizationStep
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .frame(maxWidth: .infinity)
            }

            navigationArea
        }
        .frame(width: 600, height: 550)
    }

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.accentColor)

            Text(steps[0].title)
                .font(.largeTitle)
                .bold()

            Text("Transform your writing experience with AI-powered assistance")
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding(.bottom)

            VStack(spacing: 16) {
                FeatureRow(icon: "wand.and.stars", title: "Smart Writing Enhancement", description: "Improve your writing with AI-powered suggestions")
                FeatureRow(icon: "keyboard", title: "System-wide Access", description: "Use anywhere with a simple keyboard shortcut")
                FeatureRow(icon: "gear", title: "Customizable", description: "Create custom commands for your specific needs")
                FeatureRow(icon: "lock.shield", title: "Privacy-Focused", description: "Your data stays on your device with local AI options")
            }
        }
    }

    private var featuresStep: some View {
        VStack(spacing: 24) {
            Text("Writing Tools at Your Fingertips")
                .font(.title)
                .bold()

            VStack(spacing: 20) {
                FeatureSection(title: "Quick Actions", items: [
                    "Proofread and correct grammar",
                    "Rewrite for clarity and impact",
                    "Adjust tone (professional/friendly)",
                    "Summarize long text"
                ])

                FeatureSection(title: "Advanced Features", items: [
                    "Create custom AI commands",
                    "Extract key points",
                    "Generate structured content",
                    "Multi-language support"
                ])

                FeatureSection(title: "Workflow Integration", items: [
                    "Works in any application",
                    "Customizable keyboard shortcuts",
                    "Response windows for longer content",
                    "Copy and paste automation"
                ])
            }
        }
    }

    private var accessibilityStep: some View {
        VStack(spacing: 20) {
            Text(steps[2].title)
                .font(.title)
                .bold()

            Text(steps[2].description)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 15) {
                Text("Why we need accessibility access:")
                    .font(.headline)
                    .padding(.bottom, 5)

                AccessibilityReason(number: "1", text: "To detect text selection across applications")
                AccessibilityReason(number: "2", text: "To provide instant writing suggestions")
                AccessibilityReason(number: "3", text: "To automate text replacement")
                AccessibilityReason(number: "4", text: "To support system-wide keyboard shortcuts")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.controlBackgroundColor)))

            VStack(spacing: 12) {
                Text("How to enable:")
                    .font(.headline)

                Button("Open System Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top)
        }
    }

    private var aiProviderStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose Your AI Provider")
                .font(.title)
                .bold()

            Text("Select your preferred AI service and configure its settings:")
                .font(.headline)

            Picker("Provider", selection: $selectedProvider) {
                Text("Gemini AI").tag("gemini")
                Text("OpenAI / Local LLM").tag("openai")
                Text("Mistral AI").tag("mistral")
                Text("Local LLM (Phi-3.5)").tag("local")
            }
            .pickerStyle(.segmented)

            if selectedProvider == "local" {
                LocalLLMSettingsView(evaluator: appState.localLLMProvider)
            } else if selectedProvider == "gemini" {
                providerSettingsGemini
            } else if selectedProvider == "mistral" {
                providerSettingsMistral
            } else {
                providerSettingsOpenAI
            }
        }
    }

    private var navigationArea: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(currentStep >= index ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button(currentStep == steps.count - 1 ? "Get Started" : "Next") {
                    if currentStep == steps.count - 1 {
                        saveSettingsAndFinish()
                    } else {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }

    private var customizationStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Customize Your Experience")
                .font(.title)
                .bold()

            VStack(alignment: .leading, spacing: 15) {
                Text("Global Shortcut")
                    .font(.headline)
                KeyboardShortcuts.Recorder("Activation Shortcut:", name: .showPopup)
                    .padding(.bottom)

                Text("Visual Theme")
                    .font(.headline)
                Picker("Theme", selection: $selectedTheme) {
                    Text("Standard").tag("standard")
                    Text("Gradient").tag("gradient")
                    Text("Glass").tag("glass")
                }
                .pickerStyle(.segmented)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.controlBackgroundColor)))
        }
    }

    private var providerSettingsGemini: some View {
        VStack(alignment: .leading, spacing: 10) {
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
    }

    private var providerSettingsMistral: some View {
        VStack(alignment: .leading, spacing: 10) {
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
    }

    private var providerSettingsOpenAI: some View {
        VStack(alignment: .leading, spacing: 10) {
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

    private func saveSettingsAndFinish() {
        UserDefaults.standard.set(selectedTheme, forKey: "theme_style")
        UserDefaults.standard.set(selectedTheme != "standard", forKey: "use_gradient_theme")

        switch selectedProvider {
        case "gemini":
            appState.saveGeminiConfig(apiKey: geminiApiKey, model: selectedGeminiModel)
        case "mistral":
            appState.saveMistralConfig(
                apiKey: mistralApiKey,
                baseURL: mistralBaseURL,
                model: mistralModel
            )
        case "local":
            break
        default:
            appState.saveOpenAIConfig(
                apiKey: openAIApiKey,
                baseURL: openAIBaseURL,
                organization: openAIOrganization,
                project: openAIProject,
                model: openAIModelName
            )
        }

        appState.setCurrentProvider(selectedProvider)

        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")

        WindowManager.shared.cleanupWindows()
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let isPermissionStep: Bool
}
