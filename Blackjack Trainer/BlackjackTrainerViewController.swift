//
//  ViewController.swift
//  Blackjack Trainer
//
//  Created by Chris Gray on 3/23/17.
//  Copyright © 2017 Chris Gray. All rights reserved.
//

import UIKit

class BlackjackTrainerViewController: UIViewController {
    
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet private var dealerCardButtons: [UIButton]!
    @IBOutlet private var gamblerCardButtons: [UIButton]!
    @IBOutlet weak var dealButton: UIButton!
    @IBOutlet weak var correctPlayLabel: UILabel!
    @IBOutlet weak var dealerTitleLabel: UILabel!
    @IBOutlet weak var playerTitleLabel: UILabel!
    @IBOutlet weak var statsLabel: UILabel!
    @IBOutlet weak var lastHandLabel: UILabel!
    
    
    private var newCardButtons = [UIButton]()
    private var cardViews = [UIView]()
    private var previousCardButton = UIButton()
    private var topColorGradient = UIColor.clear.cgColor
    private var bottomColorGradient = UIColor.clear.cgColor
    
    private var gradientColors: [CGColor] {
        get {
            return [topColorGradient, bottomColorGradient]
        }
    }
    
    private let hit = "Hit"
    private let stand = "Stand"
    private let double = "Double"
    private let split = "Split"
    private let rightCardSplitDistance: CGFloat = 65
    private let leftCardSplitDistance: CGFloat = 110
    private let labelSplitRightDistance: CGFloat = 85
    private let labelSplitLeftDistance: CGFloat = 110
    private let cardWidth: CGFloat = 100
    private let cardHeight: CGFloat = 150
    private let twentyOne = 21
    private var numberOfEdgeHits = 0
    private var numberOfCardsHitToPlayer = 0
    private var maxCardsToHitBeforeOverlap = 6
    private var previousHandWasSplit = false
    private var handIsOver = false
    private var aces = false
    private var dealerHitsOnSoft17 = false
    
    private let game = BlackjackGame()
    
    private var gamblerHas21OrBusts: Bool {
        return game.gambler.currentHand.total >= 21
    }
    
    @IBOutlet private weak var gamblerTotalLabel: UILabel!
    @IBOutlet weak var dealerTotalLabel: UILabel!
    @IBOutlet var actionButtons: [UIButton]!
    private var splitHandTotalLabel = UILabel()
    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(showOrHideCount), name: NSNotification.Name("showOrHideCount"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeDealerHitsOnSoft17), name: NSNotification.Name("changeDealerHitsOnSoft17"), object: nil)
//        if UserDefaults.standard.bool(forKey: "launched") {
//            print("user has launched app")
        countLabel.isHidden = !UserDefaults.standard.bool(forKey: "showCountState")
        dealerHitsOnSoft17 = UserDefaults.standard.bool(forKey: "dealerHitsState")
//        }
        game.delegate = self as LastHandDelegate
        newGame()
    }
    
    override func viewDidLayoutSubviews() {
        configureUIDesign()
    }
    
//    private enum GamblerAction {
//        case hit, stand, double, split
//    }
    
    func showOrHideCount() {
        countLabel.isHidden = !countLabel.isHidden
    }
    
    func changeDealerHitsOnSoft17() { //fix implementation?
        dealerHitsOnSoft17 = !dealerHitsOnSoft17
    }
    
    
    @IBAction func chooseAction(_ action: UIButton) {
        let chosenAction = action.currentTitle!
        let correctAction = game.getCorrectPlay()
        
        if chosenAction == correctAction {
            correctPlayLabel.text = "Correct"
        } else {
            correctPlayLabel.text = "Incorrect, correct play is \(correctAction)"
        }
        switch chosenAction {
        case hit:
            gamblerHits()
        case stand:
            gamblerStands()
        case double:
            gamblerDoubles()
        case split:
            gamblerSplits()
        default:
            break
        }
        updateLabelsAfterAction()
    }
    
    private func gamblerHits() {
        changeButtonState(button: actionButtons[2], enabled: false)
        changeButtonState(button: actionButtons[3], enabled: false)
        hitToPlayer()
        if !game.gambler.lastHand && gamblerHas21OrBusts {
            splitHandStandsOrBusts()
        } else if gamblerHas21OrBusts {
            switchPlayToDealer()
        }
    }
    
    private func gamblerStands() {
        if game.gambler.lastHand {
            switchPlayToDealer()
        } else {
            splitHandStandsOrBusts()
        }
    }
    
    private func gamblerDoubles() {
        hitToPlayer()
        if game.gambler.lastHand {
            switchPlayToDealer()
        } else {
            splitHandStandsOrBusts()
        }
    }
    
    private func gamblerSplits() {
        previousHandWasSplit = true
        if game.gambler.currentHand.cards.first!.rank == "ace" && game.gambler.currentHand.cards.last!.rank == "ace" {
            aces = true
        }
        splitCardsOnTable()
        updateUIAfterSplit()
        game.splitHand()
        hitToPlayer()
        if aces || gamblerHas21OrBusts {
            splitHandStandsOrBusts()
        }
    }
    
    private func splitHandStandsOrBusts() {
        if !actionButtons[2].isEnabled {
            changeButtonState(button: actionButtons[2], enabled: true)
        }
        gamblerTotalLabel.isHidden = false
        numberOfCardsHitToPlayer = 0
        previousCardButton = gamblerCardButtons.first!
        game.splitHandStandsOrBusts()
        hitToPlayer()
        if aces || gamblerHas21OrBusts {
            switchPlayToDealer()
        }
    }
    
    private func updateUIAfterSplit() {
        splitHandTotalLabel.frame = gamblerTotalLabel.frame
        splitHandTotalLabel.center.x += labelSplitRightDistance
        splitHandTotalLabel.textColor = UIColor.white
        splitHandTotalLabel.font = UIFont(name: splitHandTotalLabel.font.fontName, size: 26)
        splitHandTotalLabel.textAlignment = .center
        self.view.addSubview(splitHandTotalLabel)
        gamblerTotalLabel.center.x -= labelSplitLeftDistance
        gamblerTotalLabel.isHidden = true
    }
    
    private func updateLabelsAfterAction() {
        if game.count > 0 {
            countLabel.text = "Count: +\(game.count)"
        } else {
            countLabel.text = "Count: \(game.count)"
        }
        
        gamblerTotalLabel.text = String(game.gambler.hands.first!.total)
        if game.gambler.alreadySplit {
            splitHandTotalLabel.text = String(game.gambler.hands.last!.total)
        }
        
        if game.currentPlayer === game.dealer { //updateTotal was already called on dealer's hand
            dealerTotalLabel.text = String(game.dealer.currentHand.total)
        }
    }
    
    private func updateStatsLabel() {
        //this should be called after switchPlayToDealer possibly
        if handIsOver {
            let round = game.countHandsWon()
            var winOrLose = String()
            if round > 0 {
                winOrLose = "You win!"
            } else if round == 0 {
                winOrLose = "Push."
            } else {
                winOrLose = "Dealer wins."
            }
            statsLabel.text = "\(winOrLose)    Hands played: \(game.handsPlayed)   Hands won: \(game.handsGamblerWon)"
        } else {
            statsLabel.text = "Hands played: \(game.handsPlayed)   Hands won: \(game.handsGamblerWon)"
        }
    }
    
    private func hitToPlayer() {
        
        let newCardFrame = getCorrectFrameForNewCard()
        game.dealTopCard(to: game.currentPlayer.currentHand, faceUp: true)
        let newCard = game.currentPlayer.currentHand.cards.last!
        putNewCardOnTable(card: newCard, cardFrame: newCardFrame)
    }
    
    private func getCorrectFrameForNewCard() -> CGRect {
        let previousXLocation = previousCardButton.frame.minX
        let previousYLocation = previousCardButton.frame.minY
        
        var newCardFrame = CGRect()
        newCardFrame = CGRect(x: previousXLocation + 20, y: previousYLocation, width: cardWidth, height: cardHeight)
        
        if game.currentPlayer === game.gambler {
            if !game.gambler.lastHand {
                maxCardsToHitBeforeOverlap = 4
            }
            if numberOfCardsHitToPlayer % maxCardsToHitBeforeOverlap == 0 && numberOfCardsHitToPlayer > 0 {
                var cardToOverlap = UIButton()
                if game.gambler.lastHand {
                    cardToOverlap = gamblerCardButtons.first!
                } else {
                    cardToOverlap = gamblerCardButtons.last!
                }
                newCardFrame = CGRect(x: cardToOverlap.frame.minX, y: previousYLocation, width: cardWidth, height: cardHeight)
            }
            numberOfCardsHitToPlayer += 1
        }
        return newCardFrame
    }
    
    private func putNewCardOnTable(card: Card, cardFrame: CGRect) {
        let cardButton = UIButton()
        updateCardButtonImage(cardButton: cardButton, card: card)
        newCardButtons.append(cardButton)
        previousCardButton = cardButton
        
        let newCardView = UIView()
        cardViews.append(newCardView)
        
        newCardView.addSubview(cardButton)
        cardButton.frame = cardFrame
        self.view.addSubview(newCardView)
    }
    
    private func splitCardsOnTable() {
        let firstCardButton = gamblerCardButtons.first!
        let secondCardButton = gamblerCardButtons.last!
        let firstCardXLocation = firstCardButton.frame.minX
        let secondCardXLocation = secondCardButton.frame.minX
        
        firstCardButton.frame = CGRect(x: firstCardXLocation - leftCardSplitDistance, y: firstCardButton.frame.minY, width: cardWidth, height: cardHeight)
        secondCardButton.frame = CGRect(x: secondCardXLocation + rightCardSplitDistance, y: secondCardButton.frame.minY, width: cardWidth, height: cardHeight)
        
        changeButtonState(button: actionButtons.last!, enabled: false) //player not able to re-split
    }
    
    private func switchPlayToDealer() {
        for actionButton in actionButtons {
            changeButtonState(button: actionButton, enabled: false)
        }
        previousCardButton = dealerCardButtons.last!
        game.currentPlayer = game.dealer
        newCardButtons.removeAll()
        game.flipDealerCard()
        updateCardButtonImage(cardButton: dealerCardButtons.last!, card: game.dealer.currentHand.cards.last!)
        if game.dealerNeedsToHit() {
            while game.dealer.currentHand.total <= 17 {
                if game.dealer.currentHand.total == 17 && game.dealer.currentHand.soft && dealerHitsOnSoft17 {
                    hitToPlayer()
                } else if game.dealer.currentHand.total == 17 {
                    break
                } else {
                    hitToPlayer()
                }
            }
        }
        endOfGameUpdates()
    }
    
    private func cleanUpTableUI() {
        if !cardViews.isEmpty {
            for cardView in cardViews {
                cardView.removeFromSuperview()
            }
        }
        if previousHandWasSplit {
            gamblerCardButtons.first!.center.x += leftCardSplitDistance
            gamblerCardButtons.last!.center.x -= rightCardSplitDistance
            gamblerTotalLabel.center.x += labelSplitLeftDistance
            splitHandTotalLabel.removeFromSuperview()
            previousHandWasSplit = false
        }
        newCardButtons.removeAll()
        correctPlayLabel.text = ""
        dealerTotalLabel.text = ""
        lastHandLabel.text = ""
        updateStatsLabel()
    }
    
    private func dealNewGameCards() {
        game.dealTopCard(to: game.gambler.currentHand, faceUp: true)
        game.dealTopCard(to: game.dealer.currentHand, faceUp: true)
        game.dealTopCard(to: game.gambler.currentHand, faceUp: true)
        game.dealTopCard(to: game.dealer.currentHand, faceUp: false)
        
        updateCardButtonImage(cardButton: gamblerCardButtons.first!, card: game.gambler.currentHand.cards.first!)
        updateCardButtonImage(cardButton: dealerCardButtons.first!, card: game.dealer.currentHand.cards.first!)
        updateCardButtonImage(cardButton: gamblerCardButtons.last!, card: game.gambler.currentHand.cards.last!)
        dealerCardButtons.last!.setBackgroundImage(UIImage(named: "cardback"), for: .normal)
    }
    
    private func updateCardButtonImage(cardButton: UIButton, card: Card) {
        let cardName = "\(card.rank)_of_\(card.suit)"
        let cardImage = UIImage(named: cardName)
        cardButton.setBackgroundImage(cardImage, for: .normal)
    }
    
    private func changeButtonState(button: UIButton, enabled: Bool) {
        switch enabled {
        case true:
            button.isEnabled = true
            button.alpha = 1
        case false:
            button.isEnabled = false
            button.alpha = 0.5
        }        
    }
    
    private func configureUIDesign() {
        setColorsForGradients(topRed: 65/255, topGreen: 67/255, topBlue: 68/255, topAlpha: 1, bottomRed: 35/255, bottomGreen: 37/255, bottomBlue: 39/255, bottomAlpha: 1)
        
        for actionButton in actionButtons {
            actionButton.layer.cornerRadius = 5
            createGradient(button: actionButton, colors: gradientColors, radius: 5)
        }
        setColorsForGradients(topRed: 255/255, topGreen: 0, topBlue: 132/255, topAlpha: 1, bottomRed: 51/255, bottomGreen: 0, bottomBlue: 27/255, bottomAlpha: 1)
        createGradient(button: dealButton, colors: gradientColors, radius: 5)
        
//        setColorsForGradients(topRed: 255/255, topGreen: 237/255, topBlue: 188/255, topAlpha: 1, bottomRed: 237/255, bottomGreen: 66/255, bottomBlue: 100/255, bottomAlpha: 1)
        
        createGradient(label: dealerTitleLabel, colors: gradientColors, radius: 5)
        createGradient(label: playerTitleLabel, colors: gradientColors, radius: 5)
    }
    
    private func setColorsForGradients(topRed: CGFloat, topGreen: CGFloat, topBlue: CGFloat, topAlpha: CGFloat, bottomRed: CGFloat, bottomGreen: CGFloat, bottomBlue: CGFloat, bottomAlpha: CGFloat) {
        topColorGradient = UIColor(red: topRed, green: topGreen, blue: topBlue, alpha: topAlpha).cgColor
        bottomColorGradient = UIColor(red: bottomRed, green: bottomGreen, blue: bottomBlue, alpha: bottomAlpha).cgColor
    }
    
    func createGradient(button: UIButton, colors: [CGColor], radius: CGFloat) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = button.bounds
        gradientLayer.colors = colors
        gradientLayer.cornerRadius = radius
        button.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    func createGradient(label: UILabel, colors: [CGColor], radius: CGFloat) {
        
        let gradientView = UIView()
        gradientView.frame = label.frame
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = gradientView.bounds
        gradientLayer.colors = colors
        gradientLayer.cornerRadius = radius
        
        gradientView.layer.addSublayer(gradientLayer)
        self.view.insertSubview(gradientView, at: 0)
    }
    
    
    @IBAction func dealNewGame(_ sender: UIButton) {
        newGame()
    }
    
    func endOfGameUpdates() {
        handIsOver = true
        updateStatsLabel()
        aces = false
        numberOfCardsHitToPlayer = 0
        maxCardsToHitBeforeOverlap = 6
        changeButtonState(button: dealButton, enabled: true)
    }
    
    func newGame() {
        handIsOver = false
        cleanUpTableUI()
        game.newGameUpdates()
//        changeButtonState(button: dealButton, enabled: false)
        
        
        
        for actionButton in actionButtons { //is there a better way to do this?
            changeButtonState(button: actionButton, enabled: true)
        }
        
        dealNewGameCards()
        if !game.gamblerCanSplit() {
            changeButtonState(button: actionButtons.last!, enabled: false)
        }
        previousCardButton = gamblerCardButtons.last!
        if game.checkForBlackjack() {
            switchPlayToDealer()
        }
        updateLabelsAfterAction()
    }
}


extension BlackjackTrainerViewController: LastHandDelegate {
    func didReceiveHandUpdate() {
        lastHandLabel.text = "Last hand!"
    }
}










