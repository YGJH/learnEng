import SwiftUI

struct ControlPanel: View {
    @Binding var selectedPage: String
    @Binding var showPanel: Bool
    @Namespace private var animation
    
    private let menuItems: [(id: String, icon: String, title: String)] = [
        ("Chat", "bubble.left.and.bubble.right.fill", "Chat"),
        ("Vocabulrary", "book.closed.fill", "Vocabulary"),
        ("Exam", "graduationcap.fill", "Exam"),
        ("News", "newspaper.fill", "News"),
        ("Settings", "gearshape.fill", "Settings")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Color.clear
                        .frame(width: 52, height: 52)
                        
                    Spacer()
                    
                    Button {
                        withAnimation(.spring()) {
                            showPanel = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("LearnEng")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your AI Tutor")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 40)
            
            // Menu Items
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(menuItems, id: \.id) { item in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPage = item.id
                                showPanel = false
                            }
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    if selectedPage == item.id {
                                        Image(systemName: item.icon)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .transition(.scale)
                                    } else {
                                        Image(systemName: item.icon)
                                            .font(.headline)
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .frame(width: 32, height: 32)
                                
                                Text(item.title)
                                    .font(.headline)
                                    .fontWeight(selectedPage == item.id ? .bold : .medium)
                                    .foregroundStyle(selectedPage == item.id ? .white : .primary)
                                
                                Spacer()
                                
                                if selectedPage == item.id {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                ZStack {
                                    if selectedPage == item.id {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.blue)
                                            .matchedGeometryEffect(id: "activeTab", in: animation)
                                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                    } else {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.clear)
                                    }
                                }
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
            
            Spacer()
            
            // Footer / User Profile
            VStack {
                Divider()
                    .padding(.bottom, 16)
                
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundStyle(.gray)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("User Profile")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Settings & Account")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color(UIColor.systemBackground))
        .ignoresSafeArea()
        .allowsHitTesting(showPanel)
    }
}
