import SwiftUI
import SwiftData
import FoundationModels

struct ExamView: View {
    @Query private var items: [Item]
    @State private var questions: [ExamQuestion] = []
    @State private var isGenerating = false
    @State private var generationProgress: Double = 0.0
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
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                contentView
            }
            .navigationTitle("Exam")
            .navigationBarTitleDisplayMode(.inline)
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
            loadingView
        } else if questions.isEmpty {
            emptyStateView
        } else {
            examListView
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.1), lineWidth: 12)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: generationProgress)
                    .stroke(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: generationProgress)
                    .shadow(color: .blue.opacity(0.3), radius: 10)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            
            VStack(spacing: 12) {
                Text("Generating Exam...")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("\(Int(generationProgress * 100))%")
                    .font(.title3)
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            
            Text("Crafting questions from your vocabulary...")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        if items.isEmpty {
            ContentUnavailableView("No Vocabulary", systemImage: "book.closed", description: Text("Add some words to your vocabulary first."))
        } else {
            VStack(spacing: 40) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)
                    
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 10)
                }
                
                VStack(spacing: 16) {
                    Text("Ready to Test?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text("We'll generate a personalized exam based on your vocabulary list.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 40)
                        .lineSpacing(4)
                }
                
                VStack(spacing: 16) {
                    Button {
                        generateQuestions()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Exam")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button {
                        showFlashCards = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.stack.fill")
                            Text("Review Flash Cards")
                        }
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 30)
                
                Spacer()
            }
        }
    }
    
    private var examListView: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("English Exam")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("\(questions.count) Questions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    if showResults {
                        Text("Finished")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.1))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Questions
                ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                    QuestionCard(
                        index: index,
                        question: question,
                        userAnswer: Binding(
                            get: { userAnswers[question.id] },
                            set: { userAnswers[question.id] = $0 }
                        ),
                        showResults: showResults,
                        evaluation: evaluations[question.id]
                    )
                    .transition(.scale.combined(with: .opacity))
                }
                
                if showResults {
                    scoreSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                actionButtonSection
                    .padding(.bottom, 40)
            }
            .padding()
        }
        .scrollIndicators(.hidden)
    }
    
    @ViewBuilder
    private var scoreSection: some View {
        VStack(spacing: 20) {
            if isEvaluating {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Grading your exam...")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(20)
            } else {
                VStack(spacing: 20) {
                    Text("Exam Results")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    let score = calculateScore()
                    let percentage = questions.isEmpty ? 0 : Int((Double(score) / Double(questions.count)) * 100)
                    
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                            .frame(width: 150, height: 150)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(percentage) / 100)
                            .stroke(
                                percentage >= 80 ? Color.green :
                                percentage >= 60 ? Color.orange : Color.red,
                                style: StrokeStyle(lineWidth: 15, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 150, height: 150)
                        
                        VStack {
                            Text("\(score)/\(questions.count)")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("Score")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text(getGrade(percentage: percentage))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            percentage >= 80 ? .green :
                            percentage >= 60 ? .orange : .red
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(30)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            }
        }
    }
    
    @ViewBuilder
    private var actionButtonSection: some View {
        if !showResults {
            Button {
                submitExam()
            } label: {
                Text("Submit Exam")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isEvaluating)
        } else {
            Button {
                withAnimation {
                    questions = []
                    showResults = false
                    userAnswers = [:]
                    evaluations = [:]
                }
            } label: {
                Text("Start New Exam")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(ScaleButtonStyle())
        }
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
        generationProgress = 0.0
        
        // Simulate progress
        Task {
            for _ in 0..<90 {
                if !isGenerating { break }
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                await MainActor.run {
                    if generationProgress < 0.9 {
                        generationProgress += 0.01
                    }
                }
            }
        }
        
        Task {
            // Pick random 5 words
            // Prioritize favorite items
            let favoriteItems = items.filter { $0.isFavorite }
            let normalItems = items.filter { !$0.isFavorite }
            
            var selectedItems: [Item] = []
            
            // Try to include at least 2 favorites if available
            if !favoriteItems.isEmpty {
                let favoritesCount = min(favoriteItems.count, 2)
                selectedItems.append(contentsOf: favoriteItems.shuffled().prefix(favoritesCount))
            }
            
            // Fill the rest with normal items
            let remainingCount = 5 - selectedItems.count
            if remainingCount > 0 && !normalItems.isEmpty {
                selectedItems.append(contentsOf: normalItems.shuffled().prefix(remainingCount))
            }
            
            // If we still don't have 5, add more favorites if possible
            if selectedItems.count < 5 && favoriteItems.count > 2 {
                let usedFavorites = Set(selectedItems.compactMap { $0.word ?? $0.query })
                let unusedFavorites = favoriteItems.filter { !usedFavorites.contains($0.word ?? $0.query) }
                let needed = 5 - selectedItems.count
                selectedItems.append(contentsOf: unusedFavorites.shuffled().prefix(needed))
            }
            
            let selected = selectedItems.map { $0.word ?? $0.query }.shuffled()
            
            do {
                let newQuestions = try await generateExam(words: selected, session: session)
                
                await MainActor.run {
                    self.generationProgress = 1.0
                }
                try? await Task.sleep(nanoseconds: 300_000_000) // Wait for 100% animation
                
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

struct QuestionCard: View {
    let index: Int
    let question: ExamQuestion
    @Binding var userAnswer: String?
    let showResults: Bool
    let evaluation: AnswerEvaluation?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Q\(index + 1)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
                
                Text(question.type.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
                
                Spacer()
                
                if showResults {
                    resultIcon
                }
            }
            
            // Passage
            if let passage = question.passage {
                Text(passage)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(6)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            
            // Question
            Text(question.question)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Divider()
            
            // Options or Input
            if question.questionType == .multipleChoice || question.questionType == .reading {
                optionsView
            } else {
                inputView
            }
            
            // Feedback
            if showResults {
                feedbackView
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private var optionsView: some View {
        VStack(spacing: 12) {
            if let options = question.options {
                ForEach(options, id: \.self) { option in
                    Button {
                        if !showResults {
                            userAnswer = option
                        }
                    } label: {
                        HStack {
                            Image(systemName: userAnswer == option ? "circle.inset.filled" : "circle")
                                .foregroundStyle(userAnswer == option ? .blue : .secondary)
                            
                            Text(option)
                                .font(.body)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            if showResults {
                                if option == question.correctAnswerText {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if userAnswer == option && option != question.correctAnswerText {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    showResults && option == question.correctAnswerText ? Color.green.opacity(0.1) :
                                    userAnswer == option ? Color.blue.opacity(0.05) : Color(.systemGray6)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    showResults && option == question.correctAnswerText ? Color.green :
                                    userAnswer == option ? Color.blue : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(showResults)
                }
            }
        }
    }
    
    private var inputView: some View {
        VStack(alignment: .leading) {
            Text("Your Answer:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextField("Type here...", text: Binding(
                get: { userAnswer ?? "" },
                set: { userAnswer = $0 }
            ))
            .textFieldStyle(.plain)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .disabled(showResults)
        }
    }
    
    @ViewBuilder
    private var resultIcon: some View {
        if question.questionType == .multipleChoice || question.questionType == .reading {
            if userAnswer == question.correctAnswerText {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.title2)
            }
        } else {
            if let eval = evaluation {
                Image(systemName: eval.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(eval.isCorrect ? .green : .red)
                    .font(.title2)
            }
        }
    }
    
    @ViewBuilder
    private var feedbackView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if question.questionType == .fillInBlank {
                if let eval = evaluation {
                    Text(eval.isCorrect ? "Correct!" : "Incorrect")
                        .font(.headline)
                        .foregroundStyle(eval.isCorrect ? .green : .red)
                    
                    Text(eval.feedback)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if !eval.isCorrect {
                        Text("Correct Answer: \(eval.corrected_answer ?? question.correctAnswerText)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                    }
                }
            } else {
                if userAnswer != question.correctAnswerText {
                    Text("Correct Answer: \(question.correctAnswerText)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }
            
            if let explanation = question.explanation, !explanation.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                Text("Explanation")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
