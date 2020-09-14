import UIKit

class BoardCollectionViewCell: UICollectionViewCell {
    
    static var identifier: String {
        //Self.description()
        "BoardCollectionViewCell"
    }
    
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var xLabel: UILabel!
    
    func update(textLabelText: String, xLabelText: String) {
        textLabel.text = textLabelText
        // xLabel represents a sunk ship
        xLabel.text = xLabelText
    }
}
