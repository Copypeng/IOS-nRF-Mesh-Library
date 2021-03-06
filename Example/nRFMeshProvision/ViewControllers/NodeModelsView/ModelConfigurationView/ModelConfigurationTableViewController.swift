//
//  ModelConfigurationTableViewController.swift
//  nRFMeshProvision_Example
//
//  Created by Mostafa Berg on 16/04/2018.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit
import nRFMeshProvision

class ModelConfigurationTableViewController: UITableViewController, ProvisionedMeshNodeDelegate, UITextFieldDelegate {

    // MARK: - Outlets & Actions
    @IBOutlet weak var vendorLabel: UILabel!

    // MARK: - Properties
    private var nodeEntry: MeshNodeEntry!
    private var meshstateManager: MeshStateManager!
    private var selectedModelIndexPath: IndexPath!
    private var companyName: String?
    private var companyIdentifier: Data?
    private var targetNode: ProvisionedMeshNode!
    private var originalDelegate: ProvisionedMeshNodeDelegate?

    // MARK: - Implementation
    public func setProxyNode(_ aNode: ProvisionedMeshNode) {
        targetNode = aNode
        originalDelegate = targetNode.delegate
        targetNode.delegate = self
    }

    public func didSelectPublishAddress(_ anAddress: Data) {
        let elementIdx = selectedModelIndexPath.section
        let modelIdx = selectedModelIndexPath.row
        let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
        let unicast = nodeEntry.nodeUnicast!
        let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
        
        targetNode.nodePublicationAddressSet(anAddress,
                                             onElementAddress: elementAddress,
                                             appKeyIndex: Data([0x00,0x00]),
                                             credentialFlag: false,
                                             ttl: Data([0x04]),
                                             period: Data([0x01]),
                                             retransmitCount: Data([0x02]),
                                             retransmitInterval: Data([0x05]),
                                             modelIdentifier: aModel,
                                             onDestinationAddress: nodeEntry.nodeUnicast!)
    }

    public func didSelectAppKeyAtIndex(_ anAppKeyIndex: UInt16) {
        var anIndex = anAppKeyIndex.bigEndian
        let appKeyIndexData = Data(bytes: &anIndex, count: MemoryLayout<UInt16>.size)
        var keyFound = false
        for aBoundAppKeyIndex in nodeEntry.appKeys {
            if aBoundAppKeyIndex == appKeyIndexData {
                keyFound = true
            }
        }
        let appKey = meshstateManager.state().appKeys[Int(anAppKeyIndex)]
        let selectedAppKeyName = appKey.keys.first!
        if !keyFound {
            showAppKeyAlert(withTitle: "AppKey is not available",
                            andMessage: "\"\(selectedAppKeyName)\" has not been added to this node's AppKey list and cannot be bound to this model.")
        } else {
            let elementIdx = selectedModelIndexPath.section
            let modelIdx = selectedModelIndexPath.row
            let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
            let unicast = nodeEntry.nodeUnicast!
            let elementAddress = Data([unicast[0], unicast[1] + UInt8(elementIdx)])
            targetNode.bindAppKey(withIndex: appKeyIndexData,
                                  toModelId: aModel,
                                  onElementAddress: elementAddress,
                                  onDestinationAddress: nodeEntry.nodeUnicast!)
            print("Will now bind appkey \(selectedAppKeyName) onto model \(aModel.hexString())")
        }
        navigationController?.popViewController(animated: true)
    }

    public func showAppKeyAlert(withTitle aTitle: String, andMessage aMessage: String) {
        let alert = UIAlertController(title: aTitle,
                          message: aMessage,
                          preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default) { (_) in
            self.dismiss(animated: true)
        }
        alert.addAction(okAction)
        present(alert, animated: true)
    }

    public func setMeshStateManager(_ aManager: MeshStateManager) {
        meshstateManager = aManager
    }

    public func setNodeEntry(_ aNode: MeshNodeEntry, withModelPath anIndexPath: IndexPath) {
        nodeEntry = aNode
        selectedModelIndexPath = anIndexPath
        let elementIdx = selectedModelIndexPath.section
        let modelIdx = selectedModelIndexPath.row
        let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
        if aModel.count == 2 {
            let upperInt = UInt16(aModel[0]) << 8
            let lowerInt = UInt16(aModel[1])
            if let modelIdentifier = MeshModelIdentifiers(rawValue: upperInt | lowerInt) {
                let modelString = MeshModelIdentifierStringConverter().stringValueForIdentifier(modelIdentifier)
                title = modelString
            } else {
                title = aModel.hexString()
            }
        } else {
            let vendorCompanyData = Data(aModel[0...1])
            let vendorModelId     = Data(aModel[2...3])
            var vendorModelInt    =  UInt32(0)
            vendorModelInt |= UInt32(aModel[0]) << 24
            vendorModelInt |= UInt32(aModel[1]) << 16
            vendorModelInt |= UInt32(aModel[2]) << 8
            vendorModelInt |= UInt32(aModel[3])

            companyIdentifier = vendorCompanyData
            companyName = CompanyIdentifiers().humanReadableNameFromIdentifier(vendorCompanyData)

            if let vendorModelIdentifier = MeshVendorModelIdentifiers(rawValue: vendorModelInt) {
                let vendorModelString = MeshVendorModelIdentifierStringConverter().stringValueForIdentifier(vendorModelIdentifier)
                title = vendorModelString
            } else {
                let formattedModel = "\(vendorCompanyData.hexString()):\(vendorModelId.hexString())"
                title = formattedModel
            }
        }
    }

    // MARK: - ProvisionedMeshNodeDelegate
    func nodeDidCompleteDiscovery(_ aNode: ProvisionedMeshNode) {
        //noop
    }

    func nodeShouldDisconnect(_ aNode: ProvisionedMeshNode) {
        targetNode.shouldDisconnect()
    }

    func receivedCompositionData(_ compositionData: CompositionStatusMessage) {
        //noop
    }

    func receivedAppKeyStatusData(_ appKeyStatusData: AppKeyStatusMessage) {
        //noop
    }

    func receivedModelAppBindStatus(_ modelAppStatusData: ModelAppBindStatusMessage) {
        if modelAppStatusData.statusCode == .success {
            print("Model bounded!")
            print("AppKeyIndex: \(modelAppStatusData.appkeyIndex.hexString())")
            print("Element Addr: \(modelAppStatusData.elementAddress.hexString())")
            print("ModelIdentifier: \(modelAppStatusData.modelIdentifier.hexString())")
            print("Source addr: \(modelAppStatusData.sourceAddress.hexString())")
            print("Status code: \(modelAppStatusData.statusCode)")
            
            // Update state with configured key
            let elementIdx = selectedModelIndexPath.section
            let modelIdx = selectedModelIndexPath.row
            let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
            let state = meshstateManager.state()
            if let anIndex = state.provisionedNodes.index(where: { $0.nodeId == nodeEntry.nodeId}) {
                let aNodeEntry = state.provisionedNodes[anIndex]
                state.provisionedNodes.remove(at: anIndex)
                aNodeEntry.modelKeyBindings[aModel] = modelAppStatusData.appkeyIndex
                //and update
                state.provisionedNodes.append(aNodeEntry)
                meshstateManager.saveState()
            }
            tableView.reloadData()
        } else {
            switch modelAppStatusData.statusCode {
            case .cannotBind:
                showAppKeyAlert(withTitle: "Cannot Bind", andMessage: "This model cannot be bound to an AppKey")
            case .featureNotSupported:
                showAppKeyAlert(withTitle: "Not supported", andMessage: "This feature not supported")
            case .invalidAdderss:
                showAppKeyAlert(withTitle: "Invalid Address", andMessage: "Node reported invalid address.")
            case .invalidAppKeyIndex:
                showAppKeyAlert(withTitle: "Invalid AppKey Index", andMessage: "Node reported this AppKey index as invalid")
            case .invalidBinding:
                showAppKeyAlert(withTitle: "Invalid binding", andMessage: "Node reported this Binding as invalid")
            case .invalidModel:
                showAppKeyAlert(withTitle: "Invalid model", andMessage: "Node reported this model as invalid")
            case .invalidNetKeyIndex:
                showAppKeyAlert(withTitle: "Invalid NetKey Index", andMessage: "Node reported NetKey as invalid")
            case .unspecifiedError:
                showAppKeyAlert(withTitle: "Unspecified Error", andMessage: "Node has reported an unspecified error")
            default:
                showAppKeyAlert(withTitle: "Error", andMessage: "An error has occured, error code: \(modelAppStatusData.statusCode.rawValue)")
            }
            print("Failed. Status code: \(modelAppStatusData.statusCode)")
        }

//        print("Model AppKey binding completed, restoring proxy node delegate")
//        targetNode.delegate = originalDelegate
//        originalDelegate = nil
    }

    func receivedModelPublicationStatus(_ modelPublicationStatusData: ModelPublicationStatusMessage) {
        if modelPublicationStatusData.statusCode == .success {
            print("Publication address set!")
            print("AppKeyIndex: \(modelPublicationStatusData.appKeyIndex.hexString())")
            print("Element Addr: \(modelPublicationStatusData.elementAddress.hexString())")
            print("ModelIdentifier: \(modelPublicationStatusData.modelIdentifier.hexString())")
            print("Source addr: \(modelPublicationStatusData.sourceAddress.hexString())")
            print("Status code: \(modelPublicationStatusData.statusCode)")
            
            // Update state with configured key
            let elementIdx = selectedModelIndexPath.section
            let modelIdx = selectedModelIndexPath.row
            let aModel = nodeEntry.elements![elementIdx].allSigAndVendorModels()[modelIdx]
            let state = meshstateManager.state()
            if let anIndex = state.provisionedNodes.index(where: { $0.nodeId == nodeEntry.nodeId}) {
                let aNodeEntry = state.provisionedNodes[anIndex]
                state.provisionedNodes.remove(at: anIndex)
                aNodeEntry.modelPublishAddresses[aModel] = modelPublicationStatusData.publishAddress
                //and update
                state.provisionedNodes.append(aNodeEntry)
                meshstateManager.saveState()
            }
            tableView.reloadData()
        } else {
            switch modelPublicationStatusData.statusCode {
            case .cannotBind:
                showAppKeyAlert(withTitle: "Cannot Bind", andMessage: "This model cannot be bound to an AppKey")
            case .featureNotSupported:
                showAppKeyAlert(withTitle: "Not supported", andMessage: "This feature not supported")
            case .invalidAdderss:
                showAppKeyAlert(withTitle: "Invalid Address", andMessage: "Node reported invalid address.")
            case .invalidAppKeyIndex:
                showAppKeyAlert(withTitle: "Invalid AppKey Index", andMessage: "Node reported this AppKey index as invalid")
            case .invalidBinding:
                showAppKeyAlert(withTitle: "Invalid binding", andMessage: "Node reported this Binding as invalid")
            case .invalidModel:
                showAppKeyAlert(withTitle: "Invalid model", andMessage: "Node reported this model as invalid")
            case .invalidNetKeyIndex:
                showAppKeyAlert(withTitle: "Invalid NetKey Index", andMessage: "Node reported NetKey as invalid")
            case .unspecifiedError:
                showAppKeyAlert(withTitle: "Unspecified Error", andMessage: "Node has reported an unspecified error")
            default:
                showAppKeyAlert(withTitle: "Error", andMessage: "An error has occured, error code: \(modelPublicationStatusData.statusCode.rawValue)")
            }
            print("Failed. Status code: \(modelPublicationStatusData.statusCode)")
        }
    }

    func configurationSucceeded() {
        //noop
    }

    // MARK: - UIViewController
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if companyName != nil {
            vendorLabel.text = "Vendor: \(companyName!) (\(companyIdentifier!.hexString()))"
        } else {
            vendorLabel.text = "SIG Model"
        }
    }
//
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return 1
        case 2:
            return 1
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "AppKey Binding"
        } else if section == 1 {
            return "Publish Address"
        } else if section == 2 {
            return "Subscription Addresses"
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let aCell = tableView.dequeueReusableCell(withIdentifier: "ModelConfigurationCell", for: indexPath)

        if indexPath.section == 0 {
            if let element = nodeEntry.elements?[selectedModelIndexPath.section] {
                let targetModel = element.allSigAndVendorModels()[selectedModelIndexPath.row]
                if let key = nodeEntry.modelKeyBindings[targetModel] {
                    aCell.textLabel?.text = key.hexString()
                } else {
                    aCell.textLabel?.text = "No AppKey Bound"
                }
            }
            return aCell
        }
        
        if indexPath.section == 1 {
            if let element = nodeEntry.elements?[selectedModelIndexPath.section] {
                let targetModel = element.allSigAndVendorModels()[selectedModelIndexPath.row]
                if let address = nodeEntry.modelPublishAddresses[targetModel] {
                    aCell.textLabel?.text = address.hexString()
                } else {
                    aCell.textLabel?.text = "No Publication Address set"
                }
            }
            return aCell
        }
        
        if indexPath.section == 2 {
            aCell.textLabel?.text = "Not implemented yet"
            return aCell
        }

        return aCell
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        //Only last section (Subscription groups) is not implemented yet
        return indexPath.section != 2
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            self.performSegue(withIdentifier: "ShowAppKeyBindingView", sender: indexPath.row)
        case 1:
            //self.performSegue(withIdentifier: "ShowPublishGroupsView", sender: indexPath.row)
            self.presentInputAlert { (anAddressString) in
                guard  anAddressString != nil else {
                    return
                }
                self.didSelectPublishAddress(Data(hexString: anAddressString!)!)
            }
        case 2:
            break
            //self.performSegue(withIdentifier: "ShowSubscribeGroupsView", sender: indexPath.row)
        default:
            break
        }
    }

    // MARK: - Input Alert
    func presentInputAlert(withCompletion aCompletionHandler : @escaping (String?) -> Void) {
        let inputAlertView = UIAlertController(title: "Enter an address",
                                               message: nil,
                                               preferredStyle: .alert)
        inputAlertView.addTextField { (aTextField) in
            aTextField.keyboardType = UIKeyboardType.alphabet
            aTextField.returnKeyType = .done
            aTextField.delegate = self
            aTextField.clearButtonMode = UITextFieldViewMode.whileEditing
            //Give a placeholder that shows this upcoming key index
            aTextField.placeholder = "0xBEEF"
        }
        
        let createAction = UIAlertAction(title: "Add", style: .default) { (_) in
            DispatchQueue.main.async {
                if let text = inputAlertView.textFields![0].text {
                    if text.count > 0 {
                        aCompletionHandler(text)
                    } else {
                        aCompletionHandler(nil)
                    }
                } else {
                    aCompletionHandler(nil)
                }
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in
            DispatchQueue.main.async {
                aCompletionHandler(nil)
            }
        }
        
        inputAlertView.addAction(createAction)
        inputAlertView.addAction(cancelAction)
        present(inputAlertView, animated: true, completion: nil)
    }

    // MARK: - Navigation
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return ["ShowAppKeyBindingView",
                "ShowPublishGroupsView",
                "ShowSubscribeGroupsView"].contains(identifier)
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowAppKeyBindingView" {
            if let destination = segue.destination as? ModelAppKeyBindingConfigurationTableViewController {
                destination.setSelectionDelegate(self)
                destination.setStateManager(meshstateManager)
            }
        }
    }
}
