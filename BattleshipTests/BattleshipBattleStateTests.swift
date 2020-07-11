import UIKit
import XCTest

class BattleshipBattleStateTests: XCTestCase {
    let playerId1 = Battle.PlayerId.player1
    let playerId2 = Battle.PlayerId.player2
    var b: Battle!
    var bp1: Battle.BattleOperation!
    var bp2: Battle.BattleOperation!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        b = Battle()
        bp1 = BattleshipBattleStateTests.addShips(b: b, playerId: playerId1)
        bp2 = BattleshipBattleStateTests.addShips(b: bp1.battle, playerId: playerId2)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    static func addShips(b: Battle, playerId: Battle.PlayerId) -> Battle.BattleOperation {
        var bp = b.addShip(Battle.Ship.carrier, playerId: playerId, y: 0, x: 0)
        bp = bp.battle.addShip(Battle.Ship.battleship, playerId: playerId, y: 1, x: 0)
        bp = bp.battle.addShip(Battle.Ship.submarine, playerId: playerId, y: 2, x: 0)
        bp = bp.battle.addShip(Battle.Ship.cruiser, playerId: playerId, y: 3, x: 0)
        bp = bp.battle.addShip(Battle.Ship.patrol, playerId: playerId, y: 4, x: 0)
        return bp
    }
    
    func testStatusAtStart() {
        XCTAssertTrue(b.battleState == Battle.BattleState.setup, "setup status at start \(bp1.battle.battleState)")
    }
    
    func testStatusAfterShipsPlacedForPlayer1() {
        XCTAssertTrue(bp1.battle.battleState == Battle.BattleState.setup, "status after one ship placed \(bp1.battle.battleState)")
    }
    
    func testStatusAfterAllShipsPlaced() {
        XCTAssertTrue(bp2.battle.battleState == Battle.BattleState.setupComplete, "status after both placed \(bp2.battle.battleState)")
    }
    
    func testCantShootWithOneShip() {
        var bp = b.addShip(Battle.Ship.battleship, playerId: playerId1, y: 1, x: 0)
        bp = bp.battle.shootAtPlayerId(playerId1, y: 0, x: 0)
        XCTAssertTrue(bp.battle.battleState == Battle.BattleState.setup, "all ships must be placed \(bp.battle.battleState)")
    }
    
    func testCantShootWithOnePlayer() {
        let bp = bp1.battle.shootAtPlayerId(playerId1, y: 0, x: 0)
        XCTAssertTrue(bp.battle.battleState == Battle.BattleState.setup, "all ships must be placed \(bp.battle.battleState)")
    }

    func testCanShootTwiceAfterAllShipsPlaced() {
        var bp = bp2.battle.shootAtPlayerId(playerId1, y: 0, x: 0)
        bp = bp.battle.shootAtPlayerId(playerId1, y: 0, x: 0)
        XCTAssertTrue(bp.message == Battle.Message.notThisPlayersTurn, "player has to take turns message:\(bp.message)")
    }
    
    func testCanShootAfterAllShipsPlaced() {
        let bp = bp2.battle.shootAtPlayerId(playerId1, y: 0, x: 0)
        XCTAssertTrue(bp.battle.battleState == Battle.BattleState.playing, "after first shoot we're playing \(bp.battle.battleState)")
    }
    
    func testPlayer1Win() {
        var bp = bp2!
        for y in 0 ..< 4 {
           for x in 0 ..< 5 {
                bp = bp.battle.shootAtPlayerId(playerId2, y: y, x: x)
                bp = bp.battle.shootAtPlayerId(playerId1, y: y, x: x)
           }
        }
        bp = bp.battle.shootAtPlayerId(playerId2, y: 4, x: 0)
        bp.battle.printBattle()
        
        XCTAssertTrue(bp.battle.battleState == Battle.BattleState.gameOver && bp.battle.whoWon() == playerId1, "player 1 should win \(bp.battle.battleState)")
    }
    
}
