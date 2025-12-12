import SwiftUI
import SwiftData
import FoundationModels

struct ExamView: View {
    @Query private var items: [Item]
    @State private var questions: [ExamQuestion] = []
    @State private var isGenerating = false
    @State private var userAnswers: [UUID: String] = [:]
    @State private var showResults = false
    @State private var session = LanguageModelSession()
    @State private var evaluations: [UUID: AnswerEvaluation] = [:]
    @State private var isEvaluating = false
    
    @State private var showMissingKeyAlert = false
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("selectedModel") private var selectedModel: String = "local"
    
    var body: some View {
        NavigationStack {
            VStack {
                if isGenerating {
                    ProgressView("Generating Exam...")
                } else if questions.isEmpty {
                    if items.isEmpty {
                        ContentUnavailableView("No Vocabulary", systemImage: "book.closed", description: Text("Add some words to your vocabulary first."))
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "studentdesk")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                            
                            Text("Ready to test your knowledge?")
                                .font(.title2)
                                .bold()
                            
                            Text("We will generate questions based on your vocabulary list.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            Button("Start Exam") {
                                generateQuestions()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                } else {
                    List {
                        ForEach(questions) { question in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(question.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .padding(6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                    
                                    Spacer()
                                }
                                
                                if let passage = question.passage {
                                    Text(passage)
                                        .font(.callout)
                                        .padding()
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(8)
                                }
                                
                                Text(question.question)
                                    .font(.headline)
                                
                                if question.type == .multipleChoice || question.type == .reading {
                                    if let options = question.options {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(options, id: \.self) { option in
                                                Button {
                                                    if !showResults {
                                                        userAnswers[question.id] = option
                                                    }
                                                } label: {
                                                    HStack {
                                                        Image(systemName: userAnswers[question.id] == option ? "circle.inset.filled" : "circle")
                                                            .foregroundStyle(userAnswers[question.id] == option ? .blue : .secondary)
                                                        Text(option)
                                                            .foregroundStyle(.primary)
                                                        Spacer()
                                                        
                                                        if showResults {
                                                            if option == question.answer {
                                                                Image(systemName: "checkmark.circle.fill")
                                                                    .foregroundStyle(.green)
                                                            } else if userAnswers[question.id] == option && option != question.answer {
                                                                Image(systemName: "xmark.circle.fill")
                                                                    .foregroundStyle(.red)
                                                            }
                                                        }
                                                    }
                                                    .padding()
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(userAnswers[question.id] == option ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                } else if question.type == .fillInBlank {
                                    TextField("Your answer", text: Binding(
                                        get: { userAnswers[question.id] ?? "" },
                                        set: { userAnswers[question.id] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(showResults)
                                }
                                
                                if showResults {
                                    if question.type == .fillInBlank {
                                        if let evaluation = evaluations[question.id] {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(evaluation.isCorrect ? "Correct!" : "Incorrect")
                                                    .foregroundStyle(evaluation.isCorrect ? .green : .red)
                                                    .fontWeight(.bold)
                                                
                                                Text(evaluation.feedback)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                
                                                if !evaluation.isCorrect {
                                                    if let corrected = evaluation.corrected_answer {
                                                        Text("Correct Answer: \(corrected)")
                                                            .font(.caption)
                                                            .fontWeight(.semibold)
                                                            .foregroundStyle(.blue)
                                                    } else {
                                                        Text("Correct Answer: \(question.answer)")
                                                            .font(.caption)
                                                            .fontWeight(.semibold)
                                                            .foregroundStyle(.blue)
                                                    }
                                                }
                                            }
                                            .padding(.top, 4)
                                        } else if isEvaluating {
                                            ProgressView()
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical)
                        }
                        
                        Section {
                            if !showResults {
                                Button("Submit") {
                                    submitExam()
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.borderedProminent)
                                .listRowInsets(EdgeInsets())
                                .padding()
                                .disabled(isEvaluating)
                            } else {
                                Button("New Exam") {
                                    withAnimation {
                                        questions = []
                                        showResults = false
                                        userAnswers = [:]
                                        evaluations = [:]
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.bordered)
                                .listRowInsets(EdgeInsets())
                                .padding()
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Exam")
            .alert("Gemini API Key Missing", isPresented: $showMissingKeyAlert) {
                Button("Use Local Model") {
                    selectedModel = "local"
                    // Retry the action that failed? 
                    // For simplicity, we just switch. User can tap button again.
                    if questions.isEmpty {
                        generateQuestions()
                    } else if showResults {
                        submitExam()
                    }
                }
                
                TextField("Enter API Key", text: $geminiApiKey)
                
                Button("Save & Retry") {
                    if !geminiApiKey.isEmpty {
                        // Retry
                        if questions.isEmpty {
                            generateQuestions()
                        } else if showResults {
                            submitExam()
                        }
                    }
                }
                
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enter your Gemini API Key in Settings or here, or switch to the local model.")
            }
        }
    }
    
    func submitExam() {
        withAnimation {
            showResults = true
            isEvaluating = true
        }
        
        Task {
            for question in questions {
                if question.type == .fillInBlank {
                    let userAnswer = userAnswers[question.id] ?? ""
                    do {
                        let evaluation = try await evaluateAnswer(
                            question: question.question,
                            correctAnswer: question.answer,
                            userAnswer: userAnswer,
                            session: session
                        )
                        await MainActor.run {
                            evaluations[question.id] = evaluation
                        }
                    } catch LLMError.missingApiKey {
                        await MainActor.run {
                            self.isEvaluating = false
                            self.showMissingKeyAlert = true
                        }
                        return
                    } catch {
                        print("Error evaluating answer: \(error)")
                    }
                }
            }
            await MainActor.run {
                isEvaluating = false
            }
        }
    }
    
    func generateQuestions() {
        isGenerating = true
        Task {
            // Pick random 5 words
            let shuffled = items.shuffled()
            let count = min(items.count, 5)
            let selected = Array(shuffled.prefix(count)).map { $0.word ?? $0.query }
            
            do {
                let newQuestions = try await generateExam(words: selected, session: session)
                
                await MainActor.run {
                    self.questions = newQuestions
                    self.isGenerating = false
                }
            } catch LLMError.missingApiKey {
                await MainActor.run {
                    self.isGenerating = false
                    self.showMissingKeyAlert = true
                }
            } catch {
                print("Error generating exam: \(error)")
                await MainActor.run {
                    self.isGenerating = false
                }
            }
        }
    }
    
    func isCorrect(_ question: ExamQuestion) -> Bool {
        guard let userAnswer = userAnswers[question.id] else { return false }
        return userAnswer.lowercased().trimmingCharacters(in: .whitespaces) == question.answer.lowercased().trimmingCharacters(in: .whitespaces)
    }
}
