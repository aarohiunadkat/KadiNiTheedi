import SwiftUI

struct ContentView: View {
    @State private var game = GameController()

    var body: some View {
        Group {
            switch game.screen {
            case .setup: SetupView(game: game)
            case .table: TableView(game: game)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        #if DEBUG
        .onAppear {
            // `-autostart N` launches straight into an N-player game (screenshots/testing).
            let args = CommandLine.arguments
            if let i = args.firstIndex(of: "-autostart"), args.indices.contains(i + 1), let n = Int(args[i + 1]),
               GameConfig.supportedPlayerCounts.contains(n), game.screen == .setup {
                game.debugAutoHuman = args.contains("-autohuman"); game.fastMode = args.contains("-fast")
                game.playerCount = n
                game.startGame()
            }
        }
        #endif
    }
}

#Preview(traits: .landscapeLeft) { ContentView() }
