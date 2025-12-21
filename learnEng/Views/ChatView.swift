//
//  ChatView.swift
//  learnEng
//
//  Created by user20 on 2025/12/16.
//

import SwiftUI
import FoundationModels

struct ChatView: View {
    @Binding var userInput: String
    @Binding var chattingSession: [ChatMessage]
    @Binding var waitingModelReply: Bool
    @Binding var stateImg: Image
    @Binding var modelSession: LanguageModelSession
    
    let model: SystemLanguageModel
    let onSendMessage: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            if model.availability == .available {
                if chattingSession.isEmpty {
                    EmptyChatStateView()
                        .padding(.bottom, 80)
                }
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(chattingSession) { message in
                                MessageView(
                                    message: message,
                                    waitingModelReply: waitingModelReply,
                                    onResend: { resendMessage($0) },
                                    onEdit: { editMessage($0) }
                                )
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                                    removal: .opacity
                                ))
                            }
                            
                            // Invisible spacer for scrolling to bottom
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 100) // Space for input bar
                    }
                    .onChange(of: chattingSession.count) { _ in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                
                // Input Area
                VStack(spacing: 0) {
                    Divider()
                        .opacity(0)
                    
                    HStack(spacing: 12) {
                        TextField("Type a word to look up...", text: $userInput, axis: .vertical)
                            .lineLimit(1...4)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .onSubmit {
                                onSendMessage()
                            }
                        
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                onSendMessage()
                            }
                        } label: {
                            stateImg
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.accentColor, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .shadow(color: .accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .disabled(userInput.isEmpty && !waitingModelReply)
                        .opacity(userInput.isEmpty && !waitingModelReply ? 0.6 : 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
            } else {
                UnavailableView()
            }
        }
    }
    
    // Helper functions
    private func resendMessage(_ query: String) {
        userInput = query
        onSendMessage()
    }
    
    private func editMessage(_ query: String) {
        userInput = query
    }
}

struct MessageView: View {
    let message: ChatMessage
    let waitingModelReply: Bool
    let onResend: (String) -> Void
    let onEdit: (String) -> Void
    
    @State private var showActions = false
    
    var body: some View {
        VStack(spacing: 8) {
            // User Message
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.query)
                        .font(.body)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.accentColor, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.accentColor.opacity(0.2), radius: 5, x: 0, y: 3)
                        .onTapGesture {
                            withAnimation(.spring()) { showActions.toggle() }
                        }
                    
                    if showActions {
                        HStack(spacing: 16) {
                            Button { onResend(message.query) } label: {
                                Label("Resend", systemImage: "arrow.clockwise")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .disabled(waitingModelReply)
                            
                            Button { onEdit(message.query) } label: {
                                Label("Edit", systemImage: "pencil")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .disabled(waitingModelReply)
                        }
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            
            // AI Message
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 36, height: 36)
                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading) {
                    if let card = message.card {
                        WordCardView(card: card, query: message.query)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    } else if message.reply.isEmpty {
                        TypingIndicator()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(message.formattedReply)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.secondarySystemBackground))
                                .foregroundColor(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            
                            Button {
                                SpeechSynthesizer.shared.speak(String(message.formattedReply.characters))
                            } label: {
                                Image(systemName: "speaker.wave.2.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue.opacity(0.8))
                            }
                            .padding(.leading, 4)
                        }
                    }
                }
                Spacer()
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct UnavailableView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .shadow(color: .orange.opacity(0.3), radius: 10)
            
            VStack(spacing: 8) {
                Text("Language Model Unavailable")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("Please enable the Language model in settings to start chatting.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct EmptyChatStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
            }
            .padding(.bottom, 8)
            
            VStack(spacing: 12) {
                Text("Start a Conversation")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Type a word or phrase below to\nstart learning English.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
