import SwiftUI

struct ContentView: View {
    @ObservedObject var session: TerminalSessionController

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            TerminalView(session: session)
        }
    }
}
