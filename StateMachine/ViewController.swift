//
//  ViewController.swift
//  StateMachine
//
//  Created by Dmitrii Ivanov on 12/12/2018.
//  Copyright © 2018 DI. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet fileprivate var statusValue: UILabel!
    private var fwUpdateManager: FWUpdateManager?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func startProcess() {
        fwUpdateManager = FWUpdateManager(
            apiClient: APIClient(),
            dataStore: DataStore(),
            remoteDeviceManager: RemoteDeviceManager(),
            fwValidator: FWValidator(),
            uiDelegate: self
        )
        fwUpdateManager!.startTheProcess()
    }

    @IBAction func initiateError() {
        fwUpdateManager?.initiateError()
    }
}


extension ViewController: UpdateManagerUIDelegate {

    func stateChanged(state: State) {
        statusValue.text = state.stringRepresentation()
    }
}
