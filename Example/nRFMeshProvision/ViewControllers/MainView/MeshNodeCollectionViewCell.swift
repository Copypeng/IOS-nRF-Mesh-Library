//
//  MeshNodeCollectionViewCell.swift
//  nRFMeshProvision_Example
//
//  Created by Mostafa Berg on 12/04/2018.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit
import nRFMeshProvision

class MeshNodeCollectionViewCell: UICollectionViewCell {
    // MARK: - Outlets and actions
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var manufacturerLabel: UILabel!
    @IBOutlet weak var elementCountLabel: UILabel!
    @IBOutlet weak var modelCountLabel: UILabel!
    @IBAction func infoButtonTapped(_ sender: Any) {
        handleInfoButtonTapped()
    }

    // MARK: - Properties
    private weak var networkView: MainNetworkViewController?
    private var indexPath: IndexPath!

    // MARK: - Initialization
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        layer.cornerRadius  = 5
        layer.masksToBounds = true
    }

    // MARK: - Implementation
    func handleInfoButtonTapped() {
        networkView?.presentInformationForNodeAtIndex(indexPath.row)
    }
    public func setupCellWithNodeEntry(_ aNodeEntry: MeshNodeEntry,
                                       atIndexPath anIndexPath: IndexPath,
                                       andNetworkView aNetworkView: MainNetworkViewController) {
        indexPath = anIndexPath
        networkView = aNetworkView
        nameLabel.text = aNodeEntry.nodeName
        let companyIdentifier = aNodeEntry.companyIdentifier
        var companyFieldString: String
        if companyIdentifier != nil {
            if let companyName = CompanyIdentifiers().humanReadableNameFromIdentifier(aNodeEntry.companyIdentifier!) {
                companyFieldString = "Company Identifier: \(companyIdentifier!.hexString()) (\(companyName))"
            } else {
                companyFieldString = "Company Identifier: \(companyIdentifier!.hexString())"
            }
        } else {
            companyFieldString = "Company Identifier: N/A"
        }
        manufacturerLabel.text = companyFieldString
        if aNodeEntry.elements != nil {
            elementCountLabel.text = "Elements: \(aNodeEntry.elements!.count)"
            var modelCounter = 0
            for anElement in aNodeEntry.elements! {
                modelCounter += anElement.totalModelCount()
            }
            modelCountLabel.text = "Models: \(modelCounter)"
        } else {
            elementCountLabel.text = "Elements: N/A"
            modelCountLabel.text = "Models: N/A"
        }

        
    }
}
