import SwiftUI

struct ExamStudyView: View {
    let questions: [ExamQuestion]
    @State private var startExam = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Study Guide")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Review the questions and explanations before taking the test.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Questions List
                ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                    StudyCard(index: index, question: question)
                }
                
                // Start Exam Button
                Button {
                    startExam = true
                } label: {
                    Text("Start Exam")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .padding(.vertical)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationDestination(isPresented: $startExam) {
            GeneratedExamView(questions: questions)
        }
    }
}

struct StudyCard: View {
    let index: Int
    let question: ExamQuestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question Header
            HStack(alignment: .top) {
                Text("Q\(index + 1)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Circle().fill(Color.blue))
                
                Text(question.question)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            // Options or Answer
            if question.questionType == .multipleChoice || question.questionType == .reading {
                if let options = question.options {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(options.enumerated()), id: \.offset) { idx, option in
                            HStack {
                                Image(systemName: (idx + 1 == question.answer) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor((idx + 1 == question.answer) ? .green : .secondary)
                                Text(option)
                                    .font(.body)
                                    .foregroundColor((idx + 1 == question.answer) ? .primary : .secondary)
                            }
                        }
                    }
                }
            } else {
                HStack {
                    Text("Answer:")
                        .font(.headline)
                    Text(question.correctAnswerText)
                        .font(.body)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }
            
            // Explanation
            if let explanation = question.explanation, !explanation.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Explanation", systemImage: "lightbulb.fill")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Text(explanation)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}
