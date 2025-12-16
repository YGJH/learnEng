import SwiftUI
import Vision
import VisionKit
import FoundationModels

struct ScanExamView: View {
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var selectedImage: UIImage?
    @State private var recognizedText: String = ""
    @State private var isProcessing = false
    @State private var processingStep = ""
    @State private var questions: [ExamQuestion] = []
    @State private var showExam = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    // Reuse the session logic
    @State private var session = LanguageModelSession(tools: [DictionaryTool()])
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding()
                    
                    if isProcessing {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text(processingStep)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            processImage()
                        } label: {
                            Label("Generate Exam", systemImage: "wand.and.stars")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        Button("Retake Photo") {
                            selectedImage = nil
                            recognizedText = ""
                        }
                        .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 30) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue)
                        
                        Text("Scan Exam Paper")
                            .font(.title2)
                            .bold()
                        
                        Text("Take a photo of an English exam paper or worksheet. AI will extract the questions and create a digital test for you.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        HStack(spacing: 20) {
                            Button {
                                showCamera = true
                            } label: {
                                VStack {
                                    Image(systemName: "camera.fill")
                                        .font(.largeTitle)
                                    Text("Camera")
                                        .font(.headline)
                                }
                                .frame(width: 120, height: 120)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(20)
                            }
                            
                            Button {
                                showPhotoLibrary = true
                            } label: {
                                VStack {
                                    Image(systemName: "photo.fill")
                                        .font(.largeTitle)
                                    Text("Photos")
                                        .font(.headline)
                                }
                                .frame(width: 120, height: 120)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(20)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scan Exam")
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
            }
            .fullScreenCover(isPresented: $showPhotoLibrary) {
                ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage)
            }
            .navigationDestination(isPresented: $showExam) {
                ExamStudyView(questions: questions)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    func processImage() {
        guard let image = selectedImage else { return }
        
        isProcessing = true
        processingStep = "Scanning text..."
        
        // 1. OCR
        recognizeText(from: image) { text in
            guard let text = text, !text.isEmpty else {
                self.errorMessage = "Could not recognize any text in the image."
                self.showError = true
                self.isProcessing = false
                return
            }
            
            self.recognizedText = text
            self.processingStep = "AI is analyzing questions..."
            
            // 2. LLM Generation
            Task {
                do {
                    let questions = try await generateExamFromText(text, session: session)
                    await MainActor.run {
                        self.questions = questions
                        self.isProcessing = false
                        self.showExam = true
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to generate exam: \(error.localizedDescription)"
                        self.showError = true
                        self.isProcessing = false
                    }
                }
            }
        }
    }
    
    func recognizeText(from image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                completion(nil)
                return
            }
            
            let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            completion(text)
        }
        
        request.recognitionLevel = .accurate
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// A simplified version of ExamView that takes questions directly
struct GeneratedExamView: View {
    let questions: [ExamQuestion]
    @State private var userAnswers: [UUID: String] = [:]
    @State private var showResults = false
    @State private var evaluations: [UUID: AnswerEvaluation] = [:]
    @State private var isEvaluating = false
    @State private var session = LanguageModelSession(tools: [DictionaryTool()])
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scanned Exam")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                                )
                            Text("\(questions.count) Questions")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        Spacer()
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
                    
                    if !showResults {
                        Button {
                            submitExam()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Submit Exam")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                        .disabled(isEvaluating)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Reuse logic from ExamView (simplified)
    func submitExam() {
        withAnimation {
            showResults = true
            isEvaluating = true
        }
        
        Task {
            for question in questions {
                if question.questionType == .fillInBlank {
                    let userAnswer = userAnswers[question.id] ?? ""
                    // Reuse evaluateAnswer from LLMService
                    if let evaluation = try? await evaluateAnswer(
                        question: question.question,
                        correctAnswer: question.correctAnswerText,
                        userAnswer: userAnswer,
                        session: session
                    ) {
                        await MainActor.run {
                            evaluations[question.id] = evaluation
                        }
                    }
                }
            }
            await MainActor.run {
                isEvaluating = false
            }
        }
    }
    
    func calculateScore() -> Int {
        var score = 0
        for question in questions {
            if question.questionType == .multipleChoice || question.questionType == .reading {
                if userAnswers[question.id] == question.correctAnswerText {
                    score += 1
                }
            } else if question.questionType == .fillInBlank {
                if let evaluation = evaluations[question.id], evaluation.isCorrect {
                    score += 1
                }
            }
        }
        return score
    }
    
    @ViewBuilder
    private var scoreSection: some View {
        VStack(spacing: 20) {
            if isEvaluating {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.blue)
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
                            .stroke(Color.gray.opacity(0.1), lineWidth: 20)
                            .frame(width: 160, height: 160)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(percentage) / 100)
                            .stroke(
                                LinearGradient(
                                    colors: percentage >= 80 ? [.green, .mint] :
                                            percentage >= 60 ? [.orange, .yellow] : [.red, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 160, height: 160)
                            .shadow(color: (percentage >= 80 ? Color.green : percentage >= 60 ? Color.orange : Color.red).opacity(0.3), radius: 10)
                        
                        VStack(spacing: 4) {
                            Text("\(score)/\(questions.count)")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                            Text("Score")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                    }
                    .padding(.vertical, 10)
                    
                    Text(getGrade(percentage: percentage))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            percentage >= 80 ? .green :
                            percentage >= 60 ? .orange : .red
                        )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            (percentage >= 80 ? Color.green : percentage >= 60 ? Color.orange : Color.red).opacity(0.1)
                        )
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(30)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
                .padding(.horizontal)
            }
        }
    }
    
    func getGrade(percentage: Int) -> String {
        switch percentage {
        case 90...100: return "Excellent! 🌟"
        case 80..<90: return "Great! 👍"
        case 70..<80: return "Good 👌"
        case 60..<70: return "Pass ✓"
        default: return "Keep Trying 💪"
        }
    }
}
