import DeckOfPlayingCards

var deck = Deck.standard52CardDeck()
deck.shuffle()
for _ in 0...4 {
    guard let card = deck.deal() else {
        print("No more cards!")
        break
    }
    print(card)
}
