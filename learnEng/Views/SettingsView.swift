import SwiftUI

struct SettingsView: View {
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("selectedModel") private var selectedModel: String = "local"
    
    let models = [
        "local": "Local Model (On-Device)",
        "gemini-2.5-flash": "Gemini 2.5 Flash",
        "gemini-2.5-flash-lite": "Gemini 2.5 Flash Lite",
        "gemini-3-pro-preview": "Gemini 3 Pro Preview"
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
