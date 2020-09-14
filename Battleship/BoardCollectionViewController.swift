import UIKit
import QuartzCore

//let reuseIdentifier = "BoardCell"

// the player and enemy boards are controlled from the same class
// the enemy board controls the shooting (you indicate where to shoot, by touching the enemy board)
// the player board controls the rest of the logic
class BoardCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    var viewModel: BattleViewModel!
    var imThePlayer: Bool = false
    
    func afterInitModel(viewModel: BattleViewModel, imThePlayer: Bool) {
        self.viewModel = viewModel
        self.imThePlayer = imThePlayer
        if imThePlayer {
            viewModel.restart() // setup first time
        }
        // listen and react to changes on the seascape array
        viewModel.addUpdateListener(imThePlayer: imThePlayer) {[weak self] changedIndices in
            
            print("update " + (imThePlayer ? "player" : "enemy") + " indices:\(changedIndices)")
            let playerOrEnemyStr = imThePlayer ? "player" : "enemy"
            let changedPaths = changedIndices.map { IndexPath(item: $0, section: 0) }
            //self?.collectionView.reloadData()
            self?.collectionView?.reloadItems(at: changedPaths)
            if let msg = viewModel.gameOverString() {
                self?.newGameDialog(msg: msg)
            }
        }
    }

    /// display a dialog that lets the user reset the ship boards, effectively restarting the game. If the game hasn't started (i.e. a string isn't passed to this method) you don't need to reset the enemy board
    func newGameDialog(msg: String? = nil, hasACancelButton: Bool = false) {
        let defaultDialogMsg = "Change the layout of your ships by touching in your green ship area. Start the game by touching in the enemy blue area"
        let theMsg = msg ?? defaultDialogMsg
        let alertController = UIAlertController(title: "Battleship Layout", message: theMsg, preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "Ok", style: .default) { (action) in
            if msg != nil {
                self.viewModel.restart()
            }
            self.viewModel.randomShipsForPlayer()
        }
        alertController.addAction(okAction)
        
        if hasACancelButton {
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(cancelAction)
        }
        self.present(alertController, animated: true) { }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if imThePlayer && viewModel.gameStatus == .notStarted {
            newGameDialog()
        }
    }

    // MARK: UICollectionViewDataSource
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    // its just easier to deal with a 1D array here, rater than a board matrix
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.viewModel.xDim * self.viewModel.yDim
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: BoardCollectionViewCell.identifier, for: indexPath) as? BoardCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        cell.layer.borderWidth = 0.3
        cell.layer.borderColor = UIColor.lightGray.cgColor
        var vText = viewModel.boardDescriptionForIndex(indexPath.item, imThePlayer: imThePlayer)
        var vXLabel = ""
        switch vText {
        case "_":  // dont show this, its ugly
            vText = " "
        case "a", "b", "s", "c", "p": // these ships are sunk
            cell.alpha = CGFloat(0.8)
            vText = vText.uppercased()
            vXLabel = "X"
        case "A", "B", "S", "C", "P":
            if !imThePlayer { // hide enemy ships
                vText = " "
            }
        default: break
        }
        if imThePlayer { // the player gets a nice garish color
            cell.backgroundColor = UIColor.green
        }
        cell.update(textLabelText: vText, xLabelText: vXLabel)
        return cell
    }
    
    // base the grid cell size on the width of the collection view. We really dont want these to flow onto the next row
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width
            let height = collectionView.bounds.height
            let horizontalCount = self.viewModel.xDim
            let verticalCount = self.viewModel.xDim // size the cells as squares
        
            //this should be a class var/constant which you can feed into the minimumLineSpacingForSectionAtIndex delegate
            let gap = 0.0
            let kwidth = width - CGFloat(gap)
            let kheight = height - CGFloat(gap)
            let keywidth = kwidth / CGFloat(horizontalCount)
            let keyheight = kheight / CGFloat(verticalCount)
            
            return CGSize(width:keywidth, height:keyheight < keywidth ? keyheight: keywidth)
    }
    
    // MARK: UICollectionViewDelegate

    // an item has been touched, show a dialog or shoot
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if imThePlayer && viewModel.gameStatus == .notStarted {
            newGameDialog()
        } else if imThePlayer {
            newGameDialog(msg: "Do you want to start again", hasACancelButton: true)
        } else {
            viewModel.shootIndex(indexPath.item) // this is the enemy board, so shoot at it
        }
        return false
    }
}
