import SwiftUI
import FoundationModels
import NaturalLanguage

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
                                            
                                            if let translation = item.translation {
                                                Text(translation)
                                                    .font(.body)
                                                    .foregroundStyle(.secondary)
                                                    .padding(10)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(Color.blue.opacity(0.05))
                                                    .cornerRadius(8)
                                            } else {
                                                HStack {
                                                    ProgressView()
                                                        .scaleEffect(0.8)
                                                    Text("Translating...")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                .padding(10)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.gray.opacity(0.1))
                                                .cornerRadius(8)
                                            }
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
                // 1. Robust Sentence Splitting using NaturalLanguage
                let tokenizer = NLTokenizer(unit: .sentence)
                tokenizer.string = generatedEssay
                let sentences = tokenizer.tokens(for: generatedEssay.startIndex..<generatedEssay.endIndex).map { String(generatedEssay[$0]) }
                
                // 2. Initialize UI with placeholders (nil translation)
                await MainActor.run {
                    self.translatedSentences = sentences.map { TranslatedSentence(original: $0, translation: nil) }
                    self.showTranslation = true
                }
                
                // 3. Batch Processing
                let batchSize = 5
                let batches = sentences.chunked(into: batchSize)
                var currentIndex = 0
                
                for batch in batches {
                    // Construct prompt for the batch
                    // We ask for a JSON array to ensure we can parse multiple translations back correctly.
                    let batchText = batch.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                    let prompt = """
                    Translate the following numbered English sentences into Traditional Chinese (繁體中文).
                    Return the translations as a JSON array of strings, maintaining the order.
                    Example output: ["翻譯1", "翻譯2"]
                    
                    Sentences:
                    \(batchText)
                    """
                    
                    let response = try await translationSession.respond(to: prompt)
                    
                    // Parse Response
                    // Try to find JSON array in the response
                    var translatedBatch: [String] = []
                    
                    if let data = response.content.data(using: .utf8) {
                        // Try to parse directly first
                        if let jsonArray = try? JSONDecoder().decode([String].self, from: data) {
                            translatedBatch = jsonArray
                        } else {
                            // Fallback: Try to extract JSON from markdown code blocks if present
                            let pattern = "```json\\s*(\\[.*?\\])\\s*```"
                            if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
                               let match = regex.firstMatch(in: response.content, range: NSRange(response.content.startIndex..., in: response.content)),
                               let range = Range(match.range(at: 1), in: response.content),
                               let jsonData = String(response.content[range]).data(using: .utf8),
                               let jsonArray = try? JSONDecoder().decode([String].self, from: jsonData) {
                                translatedBatch = jsonArray
                            } else {
                                // Fallback 2: If JSON fails, try to split by newlines if it looks like a list
                                // This is a last resort and might be less accurate
                                translatedBatch = response.content.components(separatedBy: .newlines)
                                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                                    // Remove numbering if present (e.g. "1. 翻譯")
                                    .map { $0.replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression) }
                            }
                        }
                    }
                    
                    // Update UI with results
                    await MainActor.run {
                        for (offset, translation) in translatedBatch.enumerated() {
                            let globalIndex = currentIndex + offset
                            if globalIndex < self.translatedSentences.count {
                                self.translatedSentences[globalIndex].translation = translation
                            }
                        }
                    }
                    
                    currentIndex += batch.count
                }
                
                await MainActor.run {
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
    var translation: String?
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
