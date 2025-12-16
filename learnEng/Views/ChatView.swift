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
        VStack(spacing: 0) {
            if model.availability == .available {
                // Chat messages
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(chattingSession) { message in
                            VStack(alignment: .leading, spacing: 12) {
                                // User message bubble
                                VStack(alignment: .trailing, spacing: 6) {
                                    HStack {
                                        Spacer()
                                        Text(message.query)
                                            .font(.body)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color.accentColor)
                                            .foregroundColor(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                    }
                                    
                                    // Action buttons
                                    HStack(spacing: 12) {
                                        Button {
                                            resendMessage(message.query)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.clockwise")
                                                    .font(.caption)
                                                Text("Resend")
                                                    .font(.caption)
                                            }
                                            .foregroundColor(.secondary)
                                        }
                                        .disabled(waitingModelReply)
                                        
                                        Button {
                                            editMessage(message.query)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "pencil")
                                                    .font(.caption)
                                                Text("Edit")
                                                    .font(.caption)
                                            }
                                            .foregroundColor(.secondary)
                                        }
                                        .disabled(waitingModelReply)
                                    }
                                    .padding(.trailing, 4)
                                }
                                
                                // AI message bubble
                                HStack(alignment: .top, spacing: 10) {
                                    // AI avatar
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Image(systemName: "brain.head.profile")
                                                .font(.system(size: 18))
                                                .foregroundColor(.accentColor)
                                        )
                                    
                                    if let card = message.card {
                                        WordCardView(card: card, query: message.query)
                                    } else if message.reply.isEmpty {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                            Text("Thinking...")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color(.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                    } else {
                                        Text(message.formattedReply)
                                            .font(.body)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color(.secondarySystemBackground))
                                            .foregroundColor(.accentColor)
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                Divider()
                
                // Input area
                HStack(spacing: 12) {
                    TextField("Type a word to look up...", text: $userInput, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemBackground))
                        .foregroundStyle(Color(.label))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .onSubmit {
                            onSendMessage()
                        }
                    
                    Button {
                        onSendMessage()
                    } label: {
                        stateImg
                            .font(.system(size: 20))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Circle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            } else {
                // Model unavailable message
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Language Model Unavailable")
                        .font(.headline)
                    Text("Please enable Language model in settings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
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
