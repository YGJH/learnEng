import SwiftUI

struct SettingsView: View {
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("selectedModel") private var selectedModel: String = "local"
    @AppStorage("translationLanguage") private var translationLanguage: String = "zh-TW"
    
    let models = [
        "local": "Local Model (On-Device)",
        "gemini-2.5-flash": "Gemini 2.5 Flash",
        "gemini-2.5-flash-lite": "Gemini 2.5 Flash Lite",
        "gemini-3-pro-preview": "Gemini 3 Pro Preview"
    ]
    
    let languages = [
        "zh-TW": "繁體中文 (Traditional Chinese)",
        "zh-CN": "简体中文 (Simplified Chinese)",
        "ja": "日本語 (Japanese)",
        "ko": "한국어 (Korean)",
        "es": "Español (Spanish)",
        "fr": "Français (French)",
        "de": "Deutsch (German)",
        "it": "Italiano (Italian)",
        "pt": "Português (Portuguese)",
        "ru": "Русский (Russian)",
        "ar": "العربية (Arabic)",
        "hi": "हिन्दी (Hindi)",
        "vi": "Tiếng Việt (Vietnamese)",
        "th": "ไทย (Thai)",
        "id": "Bahasa Indonesia (Indonesian)"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Model Selection")) {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(models.keys.sorted(), id: \.self) { key in
                            Text(models[key] ?? key).tag(key)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section(header: Text("Translation Language"), footer: Text("Choose the language for vocabulary translations.")) {
                    Picker("Language", selection: $translationLanguage) {
                        ForEach(languages.keys.sorted(by: { languages[$0]! < languages[$1]! }), id: \.self) { key in
                            Text(languages[key] ?? key).tag(key)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                if selectedModel.contains("gemini") {
                    Section(header: Text("Gemini Configuration"), footer: Text("Enter your Google Gemini API Key.")) {
                        SecureField("API Key", text: $geminiApiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                
                Section(header: Text("About")) {
                    Text("LearnEng v1.0")
                    Text("Using \(models[selectedModel] ?? selectedModel)")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                // Migration for old model IDs or user manual errors
                if selectedModel.hasPrefix("models/") {
                    selectedModel = String(selectedModel.dropFirst(7))
                }
                
                // Migration for old model IDs
                if selectedModel == "gemini-1.5-flash" {
                    selectedModel = "gemini-1.5-flash-latest"
                } else if selectedModel == "gemini-1.5-pro" {
                    selectedModel = "gemini-1.5-pro-latest"
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
