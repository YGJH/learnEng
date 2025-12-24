import SwiftUI
import FoundationModels

struct WritingView: View {
    @State private var topic: String = ""
    @State private var generatedEssay: String = ""
    @State private var isGenerating = false
    @State private var showTranslation = false
    @State private var translatedSentences: [TranslatedSentence] = []
    @State private var isTranslating = false
    
    // Separate sessions for writing and translation to manage context window
    @State private var writingSession = LanguageModelSession()
    @State private var translationSession = LanguageModelSession()
    
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI Writing Assistant")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            
            ScrollView {
                VStack(spacing: 20) {
                    // Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Topic")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        TextField("Enter a topic (e.g., 'The benefits of reading')", text: $topic)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(12)
                        
                        Button {
                            generateEssay()
                        } label: {
                            if isGenerating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Label("Generate Essay", systemImage: "pencil.and.outline")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(topic.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(topic.isEmpty || isGenerating)
                    }
                    .padding()
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                    
                    // Essay Display Section
                    if !generatedEssay.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Generated Essay")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                Button {
                                    translateEssay()
                                } label: {
                                    if isTranslating {
                                        ProgressView()
                                    } else {
                                        Label("Translate", systemImage: "translate")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(isTranslating || showTranslation)
                            }
                            
                            if showTranslation {
                                // Translated View (Sentence by Sentence)
                                LazyVStack(alignment: .leading, spacing: 16) {
                                    ForEach(translatedSentences) { item in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(item.original)
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.primary)
                                                .lineSpacing(4)
                                            
                                            Text(item.translation)
                                                .font(.body)
                                                .foregroundStyle(.secondary)
                                                .padding(10)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.blue.opacity(0.05))
                                                .cornerRadius(8)
                                        }
                                        .padding(.bottom, 8)
                                        Divider()
                                    }
                                }
                            } else {
                                // Plain Text View
                                Text(generatedEssay)
                                    .font(.body)
                                    .lineSpacing(6)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    func generateEssay() {
        guard !topic.isEmpty else { return }
        
        isGenerating = true
        showTranslation = false
        generatedEssay = ""
        translatedSentences = []
        
        // Reset writing session to clear previous context if needed, 
        // or keep it if you want a conversational flow. 
        // For a fresh essay, resetting is usually better.
        writingSession = LanguageModelSession()
        
        Task {
            do {
                let prompt = """
                Write a well-structured English essay about: "\(topic)".
                The essay should have an introduction, body paragraphs, and a conclusion.
                Keep the language clear and suitable for an English learner.
                Do not include any introductory text like "Here is an essay...", just start with the title or the essay itself.
                """
                
                // Use Streaming Response
                for try await chunk in streamResponse(prompt: prompt, session: writingSession) {
                    await MainActor.run {
                        self.generatedEssay += chunk
                    }
                }
                
                await MainActor.run {
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to generate essay: \(error.localizedDescription)"
                    self.showError = true
                    self.isGenerating = false
                }
            }
        }
    }
    
    func translateEssay() {
        guard !generatedEssay.isEmpty else { return }
        
        isTranslating = true
        translationSession = LanguageModelSession() // New session for translation
        
        Task {
            do {
                // Split essay into sentences (simple splitting by period/newline)
                // A more robust NLP splitter would be better, but this works for basic needs
                let sentences = generatedEssay
                    .components(separatedBy: .newlines)
                    .flatMap { $0.components(separatedBy: ". ") }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { $0.hasSuffix(".") ? $0 : $0 + "." } // Re-add period if lost
                
                var results: [TranslatedSentence] = []
                
                // Translate batch or one by one. 
                // To avoid context window issues with very long essays, we can translate sentence by sentence 
                // or paragraph by paragraph. Here we do it one by one for precision.
                
                for sentence in sentences {
                    let prompt = """
                    Translate the following English sentence into Traditional Chinese (繁體中文).
                    Only provide the translation, no other text.
                    
                    Sentence: "\(sentence)"
                    """
                    
                    let response = try await translationSession.respond(to: prompt)
                    let translation = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    results.append(TranslatedSentence(original: sentence, translation: translation))
                }
                
                await MainActor.run {
                    self.translatedSentences = results
                    self.showTranslation = true
                    self.isTranslating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to translate: \(error.localizedDescription)"
                    self.showError = true
                    self.isTranslating = false
                }
            }
        }
    }
}

struct TranslatedSentence: Identifiable {
    let id = UUID()
    let original: String
    let translation: String
}
