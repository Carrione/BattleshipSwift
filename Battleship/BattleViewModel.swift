import Foundation

// The ally and enemy controllers each register a listener and receives notification of board updates
// The ally can start a new game
// or request new ship placements, if the game hasn't started
// or fire on the enemy. The enemy immediately shoots back
class BattleViewModel {

    enum GameStatus {
    case notStarted, started
    }
    
    var gameStatus: GameStatus = .notStarted
    let xDim = 10 // dimensions of the board
    let yDim = 10
    private let allyPlayerId = Battle.PlayerId.player1
    private let enemyPlayerId = Battle.PlayerId.player2
    private var bondAlly: BondPlayer // contains listeners, to inform controllers of changes
    private var bondEnemy: BondPlayer
    private var randomIndexes: [Int] = []
    private var enemyBattleStart: Battle // Battle that just has the enemy ship. Ally ships not yet deployed
    private var battle: Battle

    init() {
        battle = Battle(yDim: yDim, xDim: xDim)
        enemyBattleStart = battle
        bondAlly = BondPlayer(battle: battle, playerId: allyPlayerId)
        bondEnemy = BondPlayer(battle: battle, playerId: enemyPlayerId)
    }
    
    /// Create a brand new battle with random ships for the enemy. The players ships will be created later
    func restart() {
        gameStatus = .notStarted
        enemyBattleStart = Battle(yDim: yDim, xDim: xDim).randomBoardForPlayerId(enemyPlayerId).battle
        bondEnemy.updateBondArray(battle: enemyBattleStart)
        battle = enemyBattleStart // listeners will be informed on calling update ships
    }
    
    /// Allow the UI to react to changes on the array representing their ships. An array of changed indices will be returned
    func addUpdateListener(imThePlayer: Bool, updateListener: @escaping ([Int]) -> Void) {
        let player = imThePlayer ? bondAlly : bondEnemy
        player.listener = updateListener
    }
    
    /// the enemy allready has their ships setup, just create/recreate the players
    func randomShipsForPlayer() {
        let battleOperation = enemyBattleStart.randomBoardForPlayerId(allyPlayerId)
        battle = battleOperation.battle
        bondAlly.updateBondArray(battle: battle)
    }
    
    /// the string representing the current cell on the board
    func boardDescriptionForIndex(_ index: Int, imThePlayer: Bool) -> String {
        let player = imThePlayer ? bondAlly : bondEnemy
        return player.board1D[index].description
    }
    
    /// gets called once for each set of array changes
    func gameOverString() -> String? {
        switch battle.whoWon() {
        case .none:
            return nil
        case .some(.player1):
            return "Game Over and You Won! Play again?"
        case .some(.player2):
            return "Sorry you have been beaten! Do you want to try one more time?"
        }
    }
    
    /// change the UI's one dimention representation of a board to a two dimentional one and shoot
    private func shootAtPlayerId(_ playerId: Battle.PlayerId, index: Int) -> Battle.BattleOperation {
        let y = index / xDim
        let x = index % xDim
        let battleOperation = battle.shootAtPlayerId(playerId, y: y, x: x)
        print("\(playerId) \(battleOperation.message)")
        return battleOperation
    }
    
    /// always the player that shoots first
    func shootIndex(_ index: Int) {
        gameStatus = .started
        battle = shootAtPlayerId(enemyPlayerId, index: index).battle
        bondEnemy.updateBondArray(battle: battle)
        
        // shoot back, but not with much smarts
        if randomIndexes.count < 1 {
            randomIndexes = randomIndexes.sorted(by: { _, _ -> Bool in
                // random sort from the lowest or highest
                Bool.random()
            })
        }
        let randomIndex = randomIndexes.last ?? 0
        print("RANDCount: \(randomIndexes.count)")
        randomIndexes.removeLast()
        let battleOperation = shootAtPlayerId(allyPlayerId, index: randomIndex)
        battle = battleOperation.battle
        bondAlly.updateBondArray(battle: battle)
        if battleOperation.message == .hit {
            randomIndexes = nearbyWaterForHit(hitIndex: randomIndex,
                                              randomIndexes: randomIndexes,
                                              board1D: bondAlly.board1D)
        }

    }

    /// if a hit, look for all nearby positions
    private func nearbyWaterForHit(hitIndex: Int, randomIndexes: [Int], board1D: [Battle.SeaScape]) -> [Int] {
        
        var indexes: [Int] = []
        for i in [hitIndex+1, hitIndex-1, hitIndex+xDim, hitIndex-xDim] {
            if i < 0 || i >= self.xDim * self.yDim {
                continue
            }
            let seaDescription = board1D[i].description
            switch seaDescription {
            case "_", "A", "B", "S", "C", "P":
                indexes.append(i)
            default:
                break
            }
        }

        let randomIndexesWithout = randomIndexes.filter {
            return indexes.contains($0)
        }
        let newRandomIndexes = randomIndexesWithout + indexes
        return newRandomIndexes
    }


    /// store a one dimentional dynamic array representing the board. This is a lot easier to handle than multiple dimensions. The view controller can listen for changes on the dynamic arrays and react to changes
    private class BondPlayer {
        let playerId: Battle.PlayerId
        private(set) var board1D: [Battle.SeaScape]
        var listener: (([Int]) -> Void)?

        init (battle: Battle, playerId: Battle.PlayerId) {
            self.playerId = playerId

            // get the starting state
            let board = battle.boardForPlayerId(playerId)
            board1D = board.reduce([], +)
        }
        
        func updateBondArray(battle: Battle) {
            let board = battle.boardForPlayerId(playerId)
            let array = board.reduce([], +)
            var indexes: [Int] = []
            for (index, element) in array.enumerated() {
                if (element != board1D[index]) {
                    board1D[index] = element
                    indexes.append(index)
                }
            }
            if let callback = listener {
                callback(indexes)
            }
        }
    }

}
