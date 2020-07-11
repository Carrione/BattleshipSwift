import Foundation

// This class represets a point in time of a battle. 
// Its immutable. To progress, a new Battle is created.
// There are two players each with a 2D board, on which ships can be placed and fired at.
class Battle {

    typealias BoardType = [[SeaScape]] // 2D board with ships, water and misses on it (Hits are on Ships!)
    
    /// all the various items you can have on the sea
    enum SeaScape {
        case water, miss
        case shipSectionNominal(Ship)
        case shipSectionDamaged(Ship)
        case shipSectionSunk(Ship)
        
        var description: String {
            switch self {
            case .water: return "_"
            case .miss: return "~"
            case .shipSectionNominal(let ship): return ship.description
            case .shipSectionDamaged(_): return "X"
            case .shipSectionSunk(let ship): return ship.description.lowercased()
            }
        }
        
        /// the ship section is undamaged
        var isNominal: Bool {
            switch self {
            case .shipSectionNominal(_): return true
            default: return false
            }
        }
        
        var isShip: Bool {
            switch self {
            case .shipSectionNominal(_), .shipSectionDamaged(_), .shipSectionSunk(_): return true
            default: return false
            }
        }
    }

    /// types of ship that can go on the sea
    enum Ship: String  {
        case carrier = "A", battleship = "B", submarine = "S", cruiser = "C", patrol = "P"
        
        var description : String {
            return self.rawValue
        }
        
        var length: Int {
            switch self {
            case .carrier: return 5
            case .battleship: return 4
            case .submarine: return 3
            case .cruiser: return 2
            case .patrol: return 1
            }
        }
        
        static var allShips: [Ship] {
            return [.carrier, .battleship, .submarine, .cruiser, .patrol]
        }
        
        static var numberOfShips: Int {
            return allShips.count
        }
    }

    /// battleState to go in one direction only ->
    enum BattleState: String  {
        case setup = "Setup", setupComplete = "SetupComplete", playing = "Playing", gameOver = "GameOver"
        
        var description : String {
            return self.rawValue
        }
    }
    
    /// messages to allow api users to get a little information about what went right or wrong
    enum Message: String {
        case hit = "Hit", miss = "Miss"
        case hitSameSpot = "HitSameSpot", missSameSpot = "MissSameSpot", shotOutOfBounds = "ShotOutOfBounds"
        case shipNotAllowedHere = "ShipNotAllowedHere", shipAlreadyPlaced = "ShipAlreadyPlaced"
        case shipPlaced = "ShipPlaced", allShipsPlaced = "AllShipsPlaced"
        case gameStarted = "GameHasStarted", gameNotInPlay = "GameNotInPlay", notThisPlayersTurn = "NotThisPlayersTurn"
        
        var description : String {
            return self.rawValue
        }
    }
    
    /// communicate the result of an operation on the battle, along with an updated battle object
    struct BattleOperation {
        let message: Message
        let battle: Battle
        let justSunk: Ship?
        
        init(message: Message, battle: Battle, justSunk: Ship? = nil) {
            self.message = message
            self.battle = battle
            self.justSunk = justSunk
        }
    }
    
    /// alowed players
    enum PlayerId: String {
        case player1 = "Player1", player2 = "Player2"
        
        var description : String {
            return self.rawValue
        }
    }
    
    // these are the three obects that will change, each time a new battle object is generated
    private let battleStore: BattleStore
    private let lastShooterId: PlayerId?
    let battleState: BattleState
    
    // next point of a battle
    private init(battleStore: BattleStore, battleState: BattleState, lastShooterId: PlayerId?) {
        self.battleStore = battleStore
        self.lastShooterId = lastShooterId
        self.battleState = battleState
    }
    
    /// yup you can create a different sized board, but 10 * 10 is good
    convenience init(yDim: Int = 10, xDim: Int = 10) {
        self.init(battleStore: BattleStore(yDim: yDim, xDim: xDim), battleState: BattleState.setup, lastShooterId: .none)
    }

    /// battle state is changing, so create a new battle for this point in time
    private func newBattle(playerId: PlayerId, board: BoardType, firedOnByPlayerId: PlayerId?, didLose: Bool = false) -> Battle {
        
        var newBattleStore = battleStore // this makes the "new" structure mutable
        newBattleStore.setBoard(board: board, forPlayerId: playerId) // update the board
        
        let newBattleState: BattleState
        switch battleState {
        case .setup where newBattleStore.setupComplete():
            newBattleState = .setupComplete
        case .setupComplete where firedOnByPlayerId != nil:
            newBattleState = .playing
        case .playing where didLose:
            newBattleState = .gameOver
        default:
            newBattleState = battleState
        }
        
        return Battle(battleStore: newBattleStore, battleState: newBattleState, lastShooterId: firedOnByPlayerId ?? lastShooterId)
    }

    /// add a ship, but only for the setup stage and only if its not already added, is not on another ship or off the board
    func addShip(_ ship: Ship, playerId: PlayerId, y: Int, x: Int, isVertical: Bool = false) -> BattleOperation {
        
        let board = battleStore.boardForPlayerId(playerId)
        switch battleStore.stateForPlayerId(playerId) {
        case .boardSetupComplete:
            return BattleOperation(message:.allShipsPlaced, battle: self)
        case .boardSetup where BattleStore.isShip(ship: ship, onBoard: board):
            return BattleOperation(message:.shipAlreadyPlaced, battle: self)
        default: break
        }
        
        if let pairs = BattleStore.pairsOverWaterForBoard(board,
                                                          isVertical: isVertical,
                                                          y: y,
                                                          x: x,
                                                          len: ship.length) {
            var vBoard = board
            for (y, x) in pairs {
                vBoard[y][x] = SeaScape.shipSectionNominal(ship)
            }
        
            return BattleOperation(message:.shipPlaced, battle: newBattle(playerId: playerId,
                                                                          board: vBoard,
                                                                          firedOnByPlayerId: nil))
        } else {
            return BattleOperation(message:.shipNotAllowedHere, battle: self)
        }
    }
    
    // After all Ships are placed, the first shot will start the game. When the opponent has no Ships left on the board, the game will complete
    
    func shootAtPlayerId(_ targetPlayerId: PlayerId, y: Int, x: Int) -> BattleOperation {
        
        let firingPlayerId: PlayerId = targetPlayerId == .player1 ? .player2 : .player1
        switch battleState {
        case .playing, .setupComplete:
            // https://stackoverflow.com/questions/26941529/swift-testing-against-optional-value-in-switch-case
            switch lastShooterId {
            case .some(firingPlayerId):
                return BattleOperation(message:.notThisPlayersTurn, battle: self)
            default: break
            }
        default:
            return BattleOperation(message:.gameNotInPlay, battle: self)
        }
        
        var targetPlayerBoard = battleStore.boardForPlayerId(targetPlayerId)
        var didLose = false
        var justSunk: Ship?
        let message: Message
        switch targetPlayerBoard[y][x] {
        case .shipSectionNominal(let ship):
            message = .hit
            targetPlayerBoard[y][x] = .shipSectionDamaged(ship)
            if !BattleStore.isNominalShip(ship, onBoard: targetPlayerBoard) { // check if its sunk
                targetPlayerBoard = BattleStore.sinkShip(ship, onBoard: targetPlayerBoard)
                didLose = BattleStore.nrOfNominalShipsOnBoard(targetPlayerBoard) == 0
                justSunk = ship
            }
        case .shipSectionDamaged(_), .shipSectionSunk(_):
            message = .hitSameSpot
        case .water:
            message = .miss
            targetPlayerBoard[y][x] = .miss
        case .miss:
            message = .missSameSpot
        }
        
        return BattleOperation(message: message,
                               battle: newBattle(playerId: targetPlayerId,
                                                 board: targetPlayerBoard,
                                                 firedOnByPlayerId: firingPlayerId,
                                                 didLose: didLose),
                              justSunk: justSunk)
    }
    
    /// randomly set the ships, has the potential to fail, if the board is too small to fit all the ships
    func randomBoardForPlayerId(_ playerId: PlayerId, ships: [Ship] = Ship.allShips) -> BattleOperation {
        
        if ships.count == 0 {
            return BattleOperation(message: .allShipsPlaced, battle: self)
        }
        let board = battleStore.boardForPlayerId(playerId)
        let ship = ships[0]
        let restOfShips = Array(ships.dropFirst())
        
        let potentialPositions = BattleStore.pairsForBoard(board) // all y,x pairs for the board
        let pairs: [(y: Int, x: Int)]
        let isVertical = Bool.random()
        pairs = potentialPositions.filter {
            let overWaterPairs = BattleStore.pairsOverWaterForBoard(board,
                                                                    isVertical: isVertical,
                                                                    y: $0.y,
                                                                    x: $0.x,
                                                                    len: ship.length)
            return overWaterPairs != nil
        }
  
        let randomSortedPairs = pairs.sorted { _,_ in Bool.random() }
        for pair in randomSortedPairs {
            let battleOperation = addShip(ship, playerId: playerId, y: pair.y, x: pair.x, isVertical: isVertical)
            if battleOperation.message == .shipNotAllowedHere {
                NSLog("all the pairs should be ok: pair generation error")
            }
            switch battleOperation.battle.randomBoardForPlayerId(playerId, ships: restOfShips) {
            case let battleOperation where battleOperation.message == .allShipsPlaced:
                return battleOperation
            default:
                break
            }
        }
        return BattleOperation(message: .shipNotAllowedHere, battle: self)
    }
    
    /// accessor to a board for api
    func boardForPlayerId(_ playerId: PlayerId) -> BoardType {
        return battleStore.boardForPlayerId(playerId)
    }
    
    /// just in case they want to know
    func whoWon() -> PlayerId? {
        switch battleState {
        case .gameOver:
            return lastShooterId
        default:
            return nil
        }
    }
    
    /// store for player's boards and operations on boards
    private struct BattleStore {
        enum BoardState  {
            case boardSetup, boardSetupComplete
        }
        
        /// players' boards
        private var boards: [PlayerId: BoardType] = [:]
        
        init(yDim: Int = 10, xDim: Int = 10) {
            let emptyRow = [SeaScape](repeating: .water, count: xDim)
            let board = BoardType(repeating: emptyRow, count: yDim) // setting up multi dimentional arrays
            boards[.player1] = board
            boards[.player2] = board
        }
        
        /// update the board for one player. It's a value object, so this isn't going to trample on anyone
        mutating func setBoard(board: BoardType, forPlayerId: PlayerId) {
            boards[forPlayerId] = board
        }
        
        func boardForPlayerId(_ playerId: PlayerId) -> BoardType {
            guard let board = boards[playerId] else {
                // TODO: handle error
                print("Board for player id \(playerId) doesn't exists")
                return BoardType()
            }
            return board
        }
        
        /// have all the ships been placed for all players
        func setupComplete() -> Bool {
            return stateForPlayerId(.player1) == .boardSetupComplete &&
                stateForPlayerId(.player2) == .boardSetupComplete
        }
        
        /// has all the ships been placed for this player
        func stateForPlayerId(_ playerId: PlayerId) -> BoardState {
            return BattleStore.numberOfShipsOnBoard(boardForPlayerId(playerId)) == Ship.numberOfShips ? .boardSetupComplete : .boardSetup
        }
        
        // helper functions. These are static to help indicate they are just pure functions
        
        static func isNominalShip(_ ship: Ship, onBoard: BoardType) -> Bool {
            // using description as contains doesnt want to play with enums, easily
            // swift has no flatmap, so use reduce
            let shipSections = onBoard.reduce([], +).filter {
                $0.isNominal && $0.description == ship.description
            }
            return shipSections.count > 0
        }
        
        static func isShip(ship: Ship, onBoard: BoardType) -> Bool {
            let shipSections = onBoard.reduce([], +).filter {
                $0.isShip && $0.description.uppercased() == ship.description
            }
            return shipSections.count > 0
        }
        
        static func numberOfShipsOnBoard(_ board: BoardType) -> Int {
            let shipSections = board.reduce([], +).filter {
                $0.isShip
            }.map {
                $0.description.uppercased()
            }
            return Set(shipSections).count
        }
        
        static func nrOfNominalShipsOnBoard(_ board: BoardType) -> Int {
            let shipSections = board.reduce([], +).filter {
                $0.isNominal
            }.map {
                $0.description.uppercased()
            }
            return Set(shipSections).count
        }
        
        static let dimYx = { (board: BoardType) -> (yDim :Int, xDim: Int) in
            (yDim: board.count, xDim: board.count > 0 ? board[0].count : 0)
        }
        
        /// get all the pairs for the whole board
        static func pairsForBoard(_ board: BoardType) -> [(y: Int, x: Int)] {
            let dim = dimYx(board)
            return (0 ..< dim.yDim).map { y in
                (0 ..< dim.xDim).map {
                    (y: y, x: $0)
                }
            }.reduce([], +)
        }
        
        /// get the pairs that represent a particular ship
        static func pairsForShip(_ ship: Ship, onBoard: BoardType) -> [(y: Int, x: Int)] {
            let pairs = BattleStore.pairsForBoard(onBoard)
            return pairs.filter {y, x in
                switch onBoard[y][x] {
                case .shipSectionNominal(ship), .shipSectionDamaged(ship), .shipSectionSunk(ship):
                    return true
                default:
                    return false
                }
            }
        }
        
        /// sink every section of a ship
        static func sinkShip(_ ship: Ship, onBoard: BoardType) -> BoardType {
            var board = onBoard
            for pair in BattleStore.pairsForShip(ship, onBoard: onBoard) {
                board[pair.y][pair.x] = .shipSectionSunk(ship)
            }
            return board
        }
        
        /// checks that the generated pairs are over water
        private static func pairsOverWaterForBoard(_ board: BoardType, pairs: [(y:Int, x:Int)]) -> [(y:Int, x:Int)]? {
            let dim = dimYx(board)
            for (y, x) in pairs {
                if x < 0 || y < 0 || x >= dim.xDim || y >= dim.yDim {
                    return nil
                }
                switch board[y][x] {
                case .water:
                    continue
                default:
                    return nil
                }
            }
            return pairs
        }
        
        /// generate pairs for a ship and check all the ship is over water
        static func pairsOverWaterForBoard(_ board: BoardType, isVertical: Bool, y: Int, x: Int, len: Int) -> [(y:Int, x:Int)]? {
            if isVertical {
                return BattleStore.pairsOverWaterForBoard(board, pairs: (y ..< y + len).map { (y: $0, x: x) })
            } else {
                return BattleStore.pairsOverWaterForBoard(board, pairs: (x ..< x + len).map { (y: y, x: $0) })
            }
        }
    }
    
    // Mark: - just for testing/debugging
    
    func printBattle() {
        print("\nBattle State \(battleState)\n")
        printBoard(playerId: .player1)
        print("\n")
        printBoard(playerId: .player2)
    }
    
    func printBoard(playerId: PlayerId) {
        let board = battleStore.boardForPlayerId(playerId)
        
        func printBoard(_ board: BoardType) {
            var number = 0
            for boardRow in board {
                number += 1
                print(boardRow.reduce("\(number) ", {"\($0) \($1)"}))
            }
        }
        
        let xDim = BattleStore.dimYx(board).xDim
        
        let array = (1 ... xDim).map { $0.description }
        let header = "   " + " " + array.joined()
        print("\(header) \(playerId.description)")
        printBoard(board)
    }
    
}

// need these because the enum has an associated type

func !=(a:Battle.SeaScape, b:Battle.SeaScape) -> Bool {
    return !(==)(a, b)
}

func ==(a:Battle.SeaScape, b:Battle.SeaScape) -> Bool {
    switch(a, b) {
    case (.water, .water), (.miss, .miss):
        return true
    case let (s1, s2):
        return s1.description == s2.description
    }
}
