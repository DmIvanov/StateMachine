//
//  State.swift
//  StateMachine
//
//  Created by Dmitrii Ivanov on 20/12/2018.
//  Copyright © 2018 DI. All rights reserved.
//

import Foundation


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
