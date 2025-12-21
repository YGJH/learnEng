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
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading) {
                    // Placeholder for the button space if needed, or just padding
                    // Since the button is now floating, we might need to add top padding to the content
                    // so it doesn't get hidden behind the button.
                    // However, for "Chat", the button was part of the flow.
                    // Let's add a spacer or padding.
                    
                    if selectedPage == "Chat" {
                        // Add padding for the floating button
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
                        // Add padding for the floating button
                        Color.clear.frame(height: 60)
                        VocabulraryView()
                    } else if selectedPage == "Exam" {
                        // Add padding for the floating button
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
                        // Add padding for the floating button
                        Color.clear.frame(height: 60)
                        Text(selectedPage)
                            .font(.largeTitle)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .disabled(show_panel)
//                .padding()
                
                // Floating Menu Button
                Button {
                    withAnimation {
                        show_panel.toggle()
                    }
                } label: {
                    Image(systemName: "list.dash")
                        .font(.system(size: 30))
                }
                .padding()
                .zIndex(3) // Ensure it's above everything
                
                if show_panel {
                    Color.black.opacity(0.3)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            withAnimation {
                                show_panel = false
                            }
                        }
                        .transition(.opacity)
                        .zIndex(1)
                }
                
                ControlPanel(selectedPage: $selectedPage, showPanel: $show_panel)
//                    .frame(width: proxy.size.width * 0.4, height: proxy.size.height, alignment: .topLeading)
                    .frame(width: show_panel ? 0.4 * proxy.size.width : 0, height: proxy.size.height, alignment: .topLeading)
                    .cornerRadius(20)
                    .zIndex(2)
                
                // Help Button (Top Right)
                Button {
                    showOnboarding = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .padding()
                        .background(Color(uiColor: .systemBackground).opacity(0.8))
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Color(.secondarySystemBackground))
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

