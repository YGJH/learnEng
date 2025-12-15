import SwiftUI
import SwiftData
import FoundationModels

struct ExamView: View {
    @Query private var items: [Item]
    @State private var questions: [ExamQuestion] = []
    @State private var isGenerating = false
    @State private var userAnswers: [UUID: String] = [:]
    @State private var showResults = false
    @State private var session = LanguageModelSession(tools: [DictionaryTool()])
    @State private var evaluations: [UUID: AnswerEvaluation] = [:]
    @State private var isEvaluating = false
    
    @State private var showMissingKeyAlert = false
    @State private var showQuotaAlert = false
    @State private var showSafetyAlert = false
    @State private var errorMessage = ""
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("selectedModel") private var selectedModel: String = "local"
    @State private var showFlashCards = false
    
    var body: some View {
        NavigationStack {
            VStack {
                contentView
            }
            .navigationTitle("Exam")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFlashCards = true
                    } label: {
                        Label("Flash Cards", systemImage: "rectangle.stack.fill")
                    }
                }
            }
            .fullScreenCover(isPresented: $showFlashCards) {
                FlashCardView()
            }
            .alert("Gemini API Key Missing", isPresented: $showMissingKeyAlert) {
                apiKeyAlertButtons
            } message: {
                Text("Please enter your Gemini API Key in Settings or here, or switch to the local model.")
            }
            .alert("API Quota Exceeded", isPresented: $showQuotaAlert) {
                quotaAlertButtons
            } message: {
                Text("You exceeded your current quota, please check your plan and billing details at Google AI Studio.")
            }
            .alert("Question Generation Issue", isPresented: $showSafetyAlert) {
                safetyAlertButtons
            } message: {
                Text(errorMessage.isEmpty ? "Some vocabulary words may have triggered safety filters. The system tried to generate questions with available words." : errorMessage)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isGenerating {
            ProgressView("Generating Exam...")
        } else if questions.isEmpty {
            emptyStateView
        } else {
            examListView
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
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
    }
    
    private var examListView: some View {
        List {
            ForEach(questions) { question in
                questionView(for: question)
            }
            
            if showResults {
                scoreSection
            }
            
            actionButtonSection
        }
        .listStyle(.plain)
    }
    
    @ViewBuilder
    private func questionView(for question: ExamQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(question.type.replacingOccurrences(of: "_", with: " ").capitalized)
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
                    .font(.body)
                    .lineSpacing(4)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
            
            Text(question.question)
                .font(.title3)
                .fontWeight(.semibold)
            
            if question.questionType == .multipleChoice || question.questionType == .reading {
                multipleChoiceOptions(for: question)
            } else if question.questionType == .fillInBlank {
                fillInBlankField(for: question)
            }
            
            if showResults {
                resultFeedback(for: question)
            }
        }
        .padding(.vertical)
    }
    
    @ViewBuilder
    private func multipleChoiceOptions(for question: ExamQuestion) -> some View {
        if let options = question.options {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    optionButton(option: option, question: question)
                }
            }
        }
    }
    
    private func optionButton(option: String, question: ExamQuestion) -> some View {
        Button {
            if !showResults {
                userAnswers[question.id] = option
            }
        } label: {
            HStack {
                Image(systemName: userAnswers[question.id] == option ? "circle.inset.filled" : "circle")
                    .foregroundStyle(userAnswers[question.id] == option ? .blue : .secondary)
                Text(option)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                
                if showResults {
                    if option == question.correctAnswerText {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if userAnswers[question.id] == option && option != question.correctAnswerText {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(showResults && option == question.correctAnswerText ? Color.green.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        showResults && option == question.correctAnswerText ? Color.green :
                        userAnswers[question.id] == option ? Color.blue :
                        Color.gray.opacity(0.3),
                        lineWidth: showResults && option == question.correctAnswerText ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func fillInBlankField(for question: ExamQuestion) -> some View {
        TextField("Your answer", text: Binding(
            get: { userAnswers[question.id] ?? "" },
            set: { userAnswers[question.id] = $0 }
        ))
        .font(.body)
        .textFieldStyle(.roundedBorder)
        .disabled(showResults)
    }
    
    @ViewBuilder
    private func resultFeedback(for question: ExamQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if question.questionType == .multipleChoice || question.questionType == .reading {
                multipleChoiceResult(for: question)
            } else if question.questionType == .fillInBlank {
                fillInBlankResult(for: question)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func multipleChoiceResult(for question: ExamQuestion) -> some View {
        let isCorrect = userAnswers[question.id] == question.correctAnswerText
        
        HStack(spacing: 8) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isCorrect ? .green : .red)
            Text(isCorrect ? "Correct!" : "Incorrect")
                .fontWeight(.bold)
                .foregroundStyle(isCorrect ? .green : .red)
        }
        
        if !isCorrect {
            if let userAnswer = userAnswers[question.id] {
                Text("Your answer: \(userAnswer)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("You didn't answer this question")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text("Correct answer: \(question.correctAnswerText)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.green)
        }
    }
    
    @ViewBuilder
    private func fillInBlankResult(for question: ExamQuestion) -> some View {
        if let evaluation = evaluations[question.id] {
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
                    Text("Correct Answer: \(question.correctAnswerText)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
            }
        } else if isEvaluating {
            ProgressView()
                .padding(.top, 4)
        }
    }
    
    @ViewBuilder
    private var scoreSection: some View {
        Section {
            if isEvaluating {
                evaluatingView
            } else {
                finalScoreView
            }
        }
        .listRowBackground(Color.clear)
    }
    
    private var evaluatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Evaluating your answers...")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            Text("Please wait while AI grades your fill-in-blank answers")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var finalScoreView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("Your Score")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            let score = calculateScore()
            let percentage = Int((Double(score) / Double(questions.count)) * 100)
            
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(score)")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(
                        percentage >= 80 ? .green :
                        percentage >= 60 ? .orange : .red
                    )
                
                Text("/ \(questions.count)")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            
            Text("\(percentage)%")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            Text(getGrade(percentage: percentage))
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            percentage >= 80 ? Color.green.opacity(0.2) :
                            percentage >= 60 ? Color.orange.opacity(0.2) : Color.red.opacity(0.2)
                        )
                )
                .foregroundStyle(
                    percentage >= 80 ? .green :
                    percentage >= 60 ? .orange : .red
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    @ViewBuilder
    private var actionButtonSection: some View {
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
    
    @ViewBuilder
    private var apiKeyAlertButtons: some View {
        Button("Use Local Model") {
            selectedModel = "local"
            if questions.isEmpty {
                generateQuestions()
            } else if showResults {
                submitExam()
            }
        }
        
        TextField("Enter API Key", text: $geminiApiKey)
        
        Button("Save & Retry") {
            if !geminiApiKey.isEmpty {
                if questions.isEmpty {
                    generateQuestions()
                } else if showResults {
                    submitExam()
                }
            }
        }
        
        Button("Cancel", role: .cancel) { }
    }
    
    @ViewBuilder
    private var quotaAlertButtons: some View {
        Button("Use Local Model") {
            selectedModel = "local"
            if questions.isEmpty {
                generateQuestions()
            } else if showResults {
                submitExam()
            }
        }
        
        Button("Open Billing Page") {
            if let url = URL(string: "https://aistudio.google.com/apikey") {
                UIApplication.shared.open(url)
            }
        }
        
        Button("OK", role: .cancel) { }
    }
    
    @ViewBuilder
    private var safetyAlertButtons: some View {
        Button("Retry") {
            generateQuestions()
        }
        
        Button("Try Gemini Model") {
            selectedModel = "gemini-1.5-flash"
            generateQuestions()
        }
        
        Button("Cancel", role: .cancel) { }
    }
    
    func submitExam() {
        withAnimation {
            showResults = true
            isEvaluating = true
        }
        
        Task {
            for question in questions {
                if question.questionType == .fillInBlank {
                    let userAnswer = userAnswers[question.id] ?? ""
                    do {
                        let evaluation = try await evaluateAnswer(
                            question: question.question,
                            correctAnswer: question.correctAnswerText,
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
                    } catch LLMError.quotaExceeded {
                        await MainActor.run {
                            self.isEvaluating = false
                            self.showQuotaAlert = true
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
            } catch LLMError.quotaExceeded {
                await MainActor.run {
                    self.isGenerating = false
                    self.showQuotaAlert = true
                }
            } catch let error as NSError where error.domain == "ExamGenerationError" {
                // Safety guardrails triggered
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                    self.showSafetyAlert = true
                }
            } catch {
                print("Error generating exam: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to generate exam: \(error.localizedDescription)"
                    self.isGenerating = false
                    self.showSafetyAlert = true
                }
            }
        }
    }
    
    func isCorrect(_ question: ExamQuestion) -> Bool {
        guard let userAnswer = userAnswers[question.id] else { return false }
        return userAnswer.lowercased().trimmingCharacters(in: .whitespaces) == question.correctAnswerText.lowercased().trimmingCharacters(in: .whitespaces)
    }
    
    func calculateScore() -> Int {
        var score = 0
        for question in questions {
            if question.questionType == .multipleChoice || question.questionType == .reading {
                // For multiple choice, check if user answer matches correct answer
                if userAnswers[question.id] == question.correctAnswerText {
                    score += 1
                }
            } else if question.questionType == .fillInBlank {
                // For fill in blank, check evaluation result
                if let evaluation = evaluations[question.id], evaluation.isCorrect {
                    score += 1
                }
            }
        }
        return score
    }
    
    func getGrade(percentage: Int) -> String {
        switch percentage {
        case 90...100:
            return "Excellent! 🌟"
        case 80..<90:
            return "Great! 👍"
        case 70..<80:
            return "Good 👌"
        case 60..<70:
            return "Pass ✓"
        default:
            return "Keep Trying 💪"
        }
    }
}
