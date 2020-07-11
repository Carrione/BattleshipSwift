
import UIKit

// The view model is passed to the two embedded collection view controllers. 
/// The collection view controllers react and interact with the view model
class BattleViewController: UIViewController {

    lazy var viewModel: BattleViewModel = BattleViewModel()

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? BoardCollectionViewController {
            switch segue.identifier {
            case .some("playerSegue"):
                vc.afterInitModel(viewModel: viewModel, imThePlayer: true)
            case .some("enemyPlayerSegue"):
                vc.afterInitModel(viewModel: viewModel, imThePlayer: false)
            default:
                print("correct type, but cant identify segue")
            }
        } else {
            print("cant identify segue")
        }
    }
}

