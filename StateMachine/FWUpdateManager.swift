//
//  FWUpdateManager.swift
//  StateMachine
//
//  Created by Dmitrii Ivanov on 12/12/2018.
//  Copyright © 2018 DI. All rights reserved.
//

import Foundation


typealias ProgressHandler = (FWUpdateIntermediateResult<Int>) -> ()     // result with percentage
typealias ComplitionHandler = (FWUpdateIntermediateResult<Bool>) -> ()  // result with success


final class FWUpdateManager {

    // MARK: - Properties
    private let uiDelegate: UpdateManagerUIDelegate
    private let apiClient: APIClient
    private let fwValidator: FWValidator
    private let dataStore: DataStore
    private let remoteDeviceManager: RemoteDeviceManager

    private var state = State.none {
        didSet {
            guard state != oldValue else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                print("\(self.state)")
                self.uiDelegate.stateChanged(state: self.state)
            }
        }
    }
    private let stateAccessQueue = DispatchQueue(label: "com.stateMachine.stateChangeQueue")

    // MARK: - Lifecycle
    init(apiClient: APIClient, dataStore: DataStore, remoteDeviceManager: RemoteDeviceManager, fwValidator:FWValidator, uiDelegate: UpdateManagerUIDelegate) {
        self.apiClient = apiClient
        self.dataStore = dataStore
        self.fwValidator = fwValidator
        self.remoteDeviceManager = remoteDeviceManager
        self.uiDelegate = uiDelegate
    }

    // MARK: - Public
    func startTheProcess() {
        changeState(toNewState: .started)
    }

    /*
     An artificial function to emulate errors on all the stages
     */
    func initiateError() {
        switch state {
        case .checkingIfUpdateNeeded:
            apiClient.error = FWUpdateError.apiError
        case .downloadingFromAPI:
            apiClient.error = FWUpdateError.apiError
        case .downloadedFromAPI:
            apiClient.error = FWUpdateError.storingError
        case .uploadingToDevice:
            remoteDeviceManager.error = FWUpdateError.deviceUploadingError
        case .waitingForDeviceRestart:
            remoteDeviceManager.error = FWUpdateError.deviceInstallingError
        default:
            break
        }
    }

    // MARK: - Private
    private func changeState(toNewState newState: State) {
        stateAccessQueue.async { [weak self] in
            guard let self = self else { return }
            self.state = newState
            self.processCurrentState()
        }
    }

    private func processCurrentState() {
        switch state {
        case .started:
            switch checkPrerequisites() {
            case .success(let currentVersion):
                checkIfUpdateIsNeeded(currentVersion: currentVersion)
            case .failure(let error):
                changeState(toNewState: .error(error: error))
            }
        case .downloadedFromAPI(let newVersion, let path):
            storeNewVersion(version: newVersion, path: path)
        case .storedToFile(let file):
            if checkIfUploadingToDevicePossible() {
                uploadFWToDevice(file: file)
            } else {
                changeState(toNewState: .error(error: .deviceIsNotReady))
            }
        case .uploadedToDevice:
            installAndRelaunch { [weak self] (success) in
                if success {
                    self?.changeState(toNewState: .done)
                } else {
                    self?.changeState(toNewState: .error(error: .deviceInstallingError))
                }
            }
        default:
            break
        }
    }

    private func checkPrerequisites() -> FWUpdateIntermediateResult<Int> {
        guard let currentVersion = dataStore.currentFWVersion() else {
            return FWUpdateIntermediateResult.failure(.noCurrentVersion)
        }
        return FWUpdateIntermediateResult.success(currentVersion)
    }

    private func checkIfUpdateIsNeeded(currentVersion: Int) {
        apiClient.checkIfUpdateNeeded(currentVersion: currentVersion) { [weak self] (result) in
            self?.processResult(result: result, function: { (newVersion) in
                self?.downloadNewVersion(newVersion: newVersion)
            })
        }
        changeState(toNewState: .checkingIfUpdateNeeded(currentVersion: currentVersion))
    }

    private func checkIfUploadingToDevicePossible() -> Bool {
        let deviceIsConnected = true // may be false
        let someOtherCondiditions = true
        return deviceIsConnected && someOtherCondiditions
    }

    private func downloadNewVersion(newVersion: Int) {
        let path = dataStore.patchToSaveNewFW()
        apiClient.downloadFirmware(
            version: newVersion,
            path: path,
            progressHandler: { [weak self] (progressResult) in
                self?.processResult(result: progressResult, function: { (percentage) in
                    let newState = State.downloadingFromAPI(newVersion: newVersion, percentage: percentage, path: path)
                    self?.changeState(toNewState: newState)
                })
            },
            completionHandler: { [weak self] (completionResult) in
                self?.processResult(result: completionResult, function: { (success) in
                    assert(success == true, "If the downloading wasn't successfull the error should be passed into the result-object")
                    self?.changeState(toNewState: .downloadedFromAPI(newVersion: newVersion, path: path))
                })
        })
        changeState(toNewState: .downloadingFromAPI(newVersion: newVersion, percentage: 0, path: path))
    }

    private func storeNewVersion(version: Int, path: String) {
        let file = FWFile(fwVersion: version, localPath: path)
        dataStore.store(file: file) { [weak self] (success) in
            if success {
                self?.changeState(toNewState: .storedToFile(file: file))
            } else {
                self?.changeState(toNewState: .error(error: .storingError))
            }
        }
    }

    private func uploadFWToDevice(file: FWFile) {
        remoteDeviceManager.uploadVerision(
            fromFile: file,
            progress: { [weak self] (progressResult) in
                self?.processResult(result: progressResult, function: { (percentage) in
                    let newState = State.uploadingToDevice(file: file, percentage: percentage)
                    self?.changeState(toNewState: newState)
                })
        }, completion: { [weak self] (completionResult) in
            self?.processResult(result: completionResult, function: { (success) in
                assert(success == true, "If the uploading wasn't successfull the error should be passed into the result-object")
                self?.changeState(toNewState: .uploadedToDevice)
            })
        })
    }

    private func installAndRelaunch(completion: @escaping (Bool)->()) {
        remoteDeviceManager.installAndRelaunch(completion: completion)
        changeState(toNewState: .waitingForDeviceRestart)
    }

    // MARK: - Helper
    private func processResult<T>(result: FWUpdateIntermediateResult<T>, function: ((T) -> ())) {
        switch result {
        case .success(let value):
            function(value)
        case .failure(let error):
            changeState(toNewState: .error(error: error))
        }
    }
}


protocol UpdateManagerUIDelegate: AnyObject {
    func stateChanged(state: State)
}


enum State {

    case none

    /*
     checking all the prerequisites before starting
     */
    case started

    /*
     checking with remote API if the update is needed
     */
    case checkingIfUpdateNeeded(currentVersion: Int)

    /*
     downloading from remote API
     */
    case downloadingFromAPI(newVersion: Int, percentage: Int, path: String)

    /*
     the file is downloaded we have to unpack and validate it
     */
    case downloadedFromAPI(newVersion: Int, path: String)

    /*
     storing the file locally
     */
    case storedToFile(file: FWFile)

    /*
     uploading the file to the device
     */
    case uploadingToDevice(file: FWFile, percentage: Int)

    /*
     uploading is completed, the device is deady to install the f/w and restart
     */
    case uploadedToDevice

    /*
     actual reinstalling and restarting was initiated,
     waiting for the device to finish the process
     */
    case waitingForDeviceRestart

    case done

    case error(error: FWUpdateError)
}


extension State {

    func stringRepresentation() -> String {
        switch self {
        case .checkingIfUpdateNeeded(let currentVersion):
            return "v.\(currentVersion) checking for update..."
        case .downloadingFromAPI(let newVersion, let percentage, _):
            return "v.\(newVersion) API downloading: \(percentage)%"
        case .downloadedFromAPI(let newVersion, _):
            return "v.\(newVersion) downloaded"
        case .storedToFile:
            return "file stored"
        case .uploadingToDevice( _, let percentage):
            return "uploading to device: \(percentage)%"
        case .error(let error):
            return "Error: \(error)"
        default:
            return String(describing: self)
        }
    }
}


extension State: Equatable {

    static func == (lhs: State, rhs: State) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (started, started):
            return true
        case (let checkingIfUpdateNeeded(version1), let checkingIfUpdateNeeded(version2)):
            return version1 == version2
        case (let downloadingFromAPI(version1, percentage1, path1), let downloadingFromAPI(version2, percentage2, path2)):
            return version1 == version2 && percentage1 == percentage2 && path1 == path2
        case (let downloadedFromAPI(version1), let downloadedFromAPI(version2)):
            return version1 == version2
        case (let storedToFile(file1), let storedToFile(file2)):
            return file1 == file2
        case (let uploadingToDevice(file1, percentage1), let uploadingToDevice(file2, percentage2)):
            return file1 == file2 && percentage1 == percentage2
        case (uploadedToDevice, uploadedToDevice):
            return true
        case (waitingForDeviceRestart, waitingForDeviceRestart):
            return true
        case (let error(err1), let error(err2)):
            return err1 == err2
        default:
            return false
        }
    }
}


enum FWUpdateError: Error, Equatable {
    case noCurrentVersion
    case downloadedVersionInvalid
    case apiError
    case unpackingError
    case deviceUploadingError
    case deviceInstallingError
    case deviceIsNotReady
    case storingError
}


struct FWFile: Equatable {
    let fwVersion: Int
    let localPath: String
}


enum FWUpdateIntermediateResult<Type> {
    case success(Type)
    case failure(FWUpdateError)
}
