import XCTest
@testable import KadiEngine

func c(_ rank: Rank, _ suit: Suit, deck: Int = 1) -> Card { Card(deck: deck, rank: rank, suit: suit) }

/// State with hand-picked hands; auction taken by the player after the dealer, everyone else passes.
func makePlayingState(
    playerCount: Int, dealer: Int, hands: [[Card]], trump: Suit, calls: [PartnerCall]
) throws -> GameState {
    var state = GameState(config: GameConfig(playerCount: playerCount), hands: hands, removed: [], dealer: dealer)
    let opener = (dealer + 1) % playerCount
    try state.placeBid(player: opener, amount: state.auction.openingBid)
    while state.phase == .bidding { try state.pass(player: state.auction.current) }
    try state.chooseTrump(trump, by: opener)
    try state.choosePartnerCalls(calls, by: opener)
    return state
}

func plays(_ entries: [(Int, Card)]) -> [PlayedCard] {
    entries.map { PlayedCard(card: $0.1, player: $0.0) }
}

func syntheticTrick(number: Int, winner: Int, card: Card) -> Trick {
    var t = Trick(number: number, leader: winner, playerCount: 4)
    t.plays = [PlayedCard(card: card, player: winner)]
    t.winner = winner
    return t
}
