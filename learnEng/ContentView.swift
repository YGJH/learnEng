//
//  ContentView.swift
//  learnEng
//
//  Created by user20 on 2025/12/12.
//

import SwiftUI
import SwiftData
import FoundationModels
//import MarkdownUI

struct ContentView: View {
    @State var user_input = ""
    let model = SystemLanguageModel.default
    @State private var model_session = LanguageModelSession(tools: [DictionaryTool()])
    @State private var chattingSession: [ChatMessage] = []
    @State private var currentTask: Task<Void, Never>?
    @State var state_img: Image = Image(systemName: "paperplane.fill")
    @State var waiting_model_reply = false


    @State var show_panel: Bool = false
    @State var selectedPage: String = "Chat"
    
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var showOnboarding = false
    
    @State private var showMissingKeyAlert = false
    @State private var showQuotaAlert = false
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("selectedModel") private var selectedModel: String = "local"
    
    func sendMessage() {
        if waiting_model_reply {
            currentTask?.cancel()
            waiting_model_reply = false
            state_img = Image(systemName: "paperplane.fill")
            if let lastIndex = chattingSession.indices.last, chattingSession[lastIndex].reply.isEmpty {
                chattingSession[lastIndex].reply = "Cancelled"
            }
            return
        }

        if !user_input.isEmpty {
            let query = user_input
            user_input = ""
            waiting_model_reply = true
            state_img = Image(systemName: "stop.fill")
            
            // Reset session for each new message to avoid context window issues
            model_session = LanguageModelSession(tools: [DictionaryTool()])
            
            let newMessage = ChatMessage(query: query, reply: "")
            chattingSession.append(newMessage)
            
            currentTask = Task {
                do {
                    let (reply, card) = try await give_reply(input: query, session: model_session)
                    if !Task.isCancelled {
                        await MainActor.run {
                            if let index = chattingSession.firstIndex(where: { $0.id == newMessage.id }) {
                                chattingSession[index].reply = reply
                                chattingSession[index].card = card
                            }
                            state_img = Image(systemName: "paperplane.fill")
                            waiting_model_reply = false
                        }
                    }
                } catch LLMError.missingApiKey {
                    await MainActor.run {
                        waiting_model_reply = false
                        state_img = Image(systemName: "paperplane.fill")
                        showMissingKeyAlert = true
                        // Restore input
                        user_input = query
                        // Remove the failed message bubble
                        if let index = chattingSession.firstIndex(where: { $0.id == newMessage.id }) {
                            chattingSession.remove(at: index)
                        }
                    }
                } catch LLMError.quotaExceeded {
                    await MainActor.run {
                        waiting_model_reply = false
                        state_img = Image(systemName: "paperplane.fill")
                        showQuotaAlert = true
                        // Restore input
                        user_input = query
                        // Remove the failed message bubble
                        if let index = chattingSession.firstIndex(where: { $0.id == newMessage.id }) {
                            chattingSession.remove(at: index)
                        }
                    }
                } catch {
                    await MainActor.run {
                        if let index = chattingSession.firstIndex(where: { $0.id == newMessage.id }) {
                            chattingSession[index].reply = "Error: \(error.localizedDescription)"
                        }
                        state_img = Image(systemName: "paperplane.fill")
                        waiting_model_reply = false
                    }
                }
            }
        }
    }
 
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                // Main Content
                ZStack {
                    if !show_panel {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                show_panel.toggle()
                            }
                        } label: {
                            Image(systemName: "list.dash")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(Color(.systemBackground).opacity(0.8))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .zIndex(1)
                        .padding()
                    }

                    if selectedPage == "Chat" {
                        Color.clear.frame(height: 60)
                        ChatView(
                            userInput: $user_input,
                            chattingSession: $chattingSession,
                            waitingModelReply: $waiting_model_reply,
                            stateImg: $state_img,
                            modelSession: $model_session,
                            model: model,
                            onSendMessage: sendMessage
                        )
                    } else if selectedPage == "Vocabulrary" {
                        Color.clear.frame(height: 60)
                        VocabulraryView()
                    } else if selectedPage == "Exam" {
                        Color.clear.frame(height: 60)
                        ExamView()
                    } else if selectedPage == "ScanExam" {
                        Color.clear.frame(height: 60)
                        ScanExamView()
                    } else if selectedPage == "News" {
                        Color.clear.frame(height: 60)
                        NewsView()
                    } else if selectedPage == "Settings" {
                        Color.clear.frame(height: 60)
                        SettingsView()
                    } else if selectedPage == "Writing" {
                        Color.clear.frame(height: 60)
                        WritingView()
                    } else {
                        Color.clear.frame(height: 60)
                        Text(selectedPage)
                            .font(.largeTitle)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    Button {
                        showOnboarding = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemBackground).opacity(0.8))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .zIndex(1)
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(x: show_panel ? 280 : 0)
                
                // Sidebar Control Panel
                if show_panel {
                    ControlPanel(selectedPage: $selectedPage, showPanel: $show_panel)
                        .frame(width: 280)
                        .frame(maxHeight: .infinity)
                        .transition(.move(edge: .leading))
                        .ignoresSafeArea()
                        .zIndex(2)
                }
            }
        }
        .background(Color(.secondarySystemBackground).ignoresSafeArea())
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(showOnboarding: $showOnboarding)
        }
        .onAppear {
            if !hasSeenOnboarding {
                showOnboarding = true
                hasSeenOnboarding = true
            }
        }
        .alert("Gemini API Key Missing", isPresented: $showMissingKeyAlert) {
            Button("Use Local Model") {
                selectedModel = "local"
            }
            TextField("API Key", text: $geminiApiKey)
            Button("Save & Retry", action: sendMessage)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enter your Gemini API Key or switch to the local model.")
        }
        .alert("API Quota Exceeded", isPresented: $showQuotaAlert) {
            Button("Use Local Model") {
                selectedModel = "local"
                sendMessage()
            }
            Button("Open Billing Page") {
                if let url = URL(string: "https://aistudio.google.com/apikey") {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("You exceeded your current quota, please check your plan and billing details at Google AI Studio.")
        }
    }
    
    

}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

