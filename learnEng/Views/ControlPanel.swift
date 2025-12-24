import SwiftUI

struct ControlPanel: View {
    @Binding var selectedPage: String
    @Binding var showPanel: Bool
    @Namespace private var animation
    
    private let menuItems: [(id: String, icon: String, title: String)] = [
        ("Chat", "bubble.left.and.bubble.right.fill", "Chat"),
        ("Vocabulrary", "book.closed.fill", "Vocabulary"),
        ("Exam", "graduationcap.fill", "Exam"),
        ("ScanExam", "doc.text.viewfinder", "Scan Exam"),
        ("Writing", "pencil.and.outline", "Writing"),
        ("News", "newspaper.fill", "News"),
        ("Settings", "gearshape.fill", "Settings")
    ]
    
    var body: some View {
        ZStack {
            // Glassmorphism Background
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            
            
            VStack(alignment: .leading, spacing: 0) {
                // Header Section
                VStack(alignment: .leading, spacing: 16) {
                        
                        
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showPanel = false
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.2))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LearnEng")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        // Text("Your AI Tutor")
                        //     .font(.subheadline)
                        //     .fontWeight(.medium)
                        //     .foregroundStyle(.secondary)
                    }
                }
                .overlay {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .frame(height: 30)
                        .opacity(0)

                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 40)
                // .border(.red)
                
                // Menu Items
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(menuItems, id: \.id) { item in
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    selectedPage = item.id
                                    // Optional: Keep panel open on iPad/Desktop, close on mobile
                                    // showPanel = false 
                                }
                            } label: {
                                HStack(spacing: 16) {
                                    ZStack {
                                        if selectedPage == item.id {
                                            Circle()
                                                .fill(.white.opacity(0.2))
                                                .frame(width: 36, height: 36)
                                                .matchedGeometryEffect(id: "icon_bg", in: animation)
                                        }
                                        
                                        Image(systemName: item.icon)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(selectedPage == item.id ? .white : .secondary)
                                    }
                                    .frame(width: 36, height: 36)
                                    
                                    Text(item.title)
                                        .font(.system(size: 16, weight: selectedPage == item.id ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(selectedPage == item.id ? .white : .primary.opacity(0.8))
                                    
                                    Spacer()
                                    
                                    if selectedPage == item.id {
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 6, height: 6)
                                            .shadow(color: .white.opacity(0.5), radius: 4)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    ZStack {
                                        if selectedPage == item.id {
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.blue, Color.purple],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .matchedGeometryEffect(id: "bg", in: animation)
                                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                        } else {
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.clear)
                                        }
                                    }
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(ControlPanelScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
                
                // Footer
                VStack(spacing: 8) {
                    Divider()
                        .background(.white.opacity(0.2))
                    
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.yellow)
                        Text("Pro Version")
                            .font(.caption)
                            .fontWeight(.bold)
                        Spacer()
                        Text("v1.0.0")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .background(.ultraThinMaterial)
            }
            
        }
        .frame(maxHeight: .infinity)
        .ignoresSafeArea()

    }

}

// Helper for button press animation
struct ControlPanelScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
