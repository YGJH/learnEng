import SwiftUI

struct ControlPanel: View {
    @Binding var selectedPage: String
    @Binding var showPanel: Bool
    
    let pages = [
        "Chat",
        "Vocabulrary",
        "Exam",
        "News",
        "Settings"
    ]
    
    var body : some View {
        ScrollView {
            Button {
            } label: {
                Image(systemName: "list.dash")
                    .font(.system(size: 30))
            }
            .padding()
            .opacity(0)


            ForEach(pages, id: \.self) { choice in
                Button {
                    selectedPage = choice
                    withAnimation {
                        showPanel = false
                    }
                } label: {
                    Text(choice)
                        .font(.system(size: 30))
                        .padding()
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(selectedPage == choice ? .blue : .orange)
                        .background(selectedPage == choice ? Color.blue.opacity(0.1) : Color.clear)
                }
            }
//            Spacer()
        }
        .padding(.top, 20)
        .background(Color(UIColor.systemBackground))
//        .edgesIgnoringSafeArea(.all)
    }
}
