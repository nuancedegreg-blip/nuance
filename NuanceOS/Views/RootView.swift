import SwiftUI

struct RootView: View {
    @State private var showAR = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ContentView()

            Button {
                showAR = true
            } label: {
                Image(systemName: "arkit")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.indigo, in: Circle())
                    .shadow(radius: 10, y: 5)
            }
            .padding(.trailing, 18)
            .padding(.bottom, 82)
            .accessibilityLabel("Ouvrir Nuance AR")
        }
        .fullScreenCover(isPresented: $showAR) {
            ARStudioView()
        }
    }
}
