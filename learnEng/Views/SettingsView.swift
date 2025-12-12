import SwiftUI

struct SettingsView: View {
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("selectedModel") private var selectedModel: String = "local"
    
    let models = [
        "local": "Local Model (On-Device)",
        "gemini-1.5-flash": "Gemini 1.5 Flash",
        "gemini-1.5-pro": "Gemini 1.5 Pro",
        "gemini-2.0-flash-exp": "Gemini 2.0 Flash (Experimental)"
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
        }
    }
}

#Preview {
    SettingsView()
}
