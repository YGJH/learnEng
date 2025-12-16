import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    
    let pages = [
        OnboardingPage(
            title: "Welcome to LearnEng",
            description: "Your personal AI English tutor. Learn vocabulary, practice conversation, and take exams.",
            imageName: "graduationcap.fill",
            color: .blue
        ),
        OnboardingPage(
            title: "AI Chat & Vocabulary",
            description: "Chat with AI to learn new words. Save them to your vocabulary list with a single tap.",
            imageName: "bubble.left.and.bubble.right.fill",
            color: .purple
        ),
        OnboardingPage(
            title: "Scan & Generate Exams",
            description: "Take a photo of any English text or exam paper. AI will generate a digital test for you.",
            imageName: "doc.text.viewfinder",
            color: .orange
        ),
        OnboardingPage(
            title: "Writing Assistant",
            description: "Practice writing essays with AI guidance and get sentence-by-sentence translations.",
            imageName: "pencil.and.outline",
            color: .green
        )
    ]
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation {
                            showOnboarding = false
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                }
                
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack(spacing: 20) {
                            Image(systemName: pages[index].imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .foregroundColor(pages[index].color)
                                .padding(.bottom, 30)
                            
                            Text(pages[index].title)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(pages[index].description)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 32)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        withAnimation {
                            showOnboarding = false
                        }
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
}
