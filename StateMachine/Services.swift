//
//  Services.swift
//  StateMachine
//
//  Created by Dmitrii Ivanov on 19/12/2018.
//  Copyright © 2018 DI. All rights reserved.
//

import Foundation

/*
 Mock for the real API client
 */
final class APIClient {

    var error: FWUpdateError?

    private var progressHandler: ProgressHandler?
    private var completionHandler: ComplitionHandler?

    // returns new version into completion
    func checkIfUpdateNeeded(currentVersion: Int, completion: @escaping ((FWUpdateIntermediateResult<Int>)->())) {
        DispatchQueue.global().async {
            sleep(3)
            completion(FWUpdateIntermediateResult.success(4))
        }
    }

    func downloadFirmware(version: Int, path: String, progressHandler: @escaping ProgressHandler, completionHandler: @escaping ComplitionHandler) {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            for percent in 95...100 {
                if let err = self.error {
                    completionHandler(FWUpdateIntermediateResult.failure(err))
                    return
                }
                if percent < 100 {
                    progressHandler(FWUpdateIntermediateResult.success(percent))
                } else {
                    completionHandler(FWUpdateIntermediateResult.success(true))
                }
                sleep(1)
            }
        }
    }
}


/*
 Mock for the real FWValidator client
 */
final class FWValidator {

    var error: FWUpdateError?
    weak var delegate: FWValidatorDelegate?

    func unpackAndValidate(downloadedFile: FWFile, completion: @escaping ((FWUpdateIntermediateResult<FWFile>) -> ())) {
        unpackFile(downloadedFile: downloadedFile) { (unpackingResult) in
            switch unpackingResult {
            case .failure(let error):
                completion(FWUpdateIntermediateResult.failure(error))
            case .success(let unpackedFile):
                if self.isFWValid(file: unpackedFile) {
                    completion(FWUpdateIntermediateResult.success(unpackedFile))
                } else {
                    completion(FWUpdateIntermediateResult.failure(FWUpdateError.downloadedVersionInvalid))
                }
            }
        }
    }

    private func unpackFile(downloadedFile: FWFile, completion: @escaping ((FWUpdateIntermediateResult<FWFile>)->())) {
        DispatchQueue.global().async {
            sleep(1)
            let unpackedFile = FWFile(
                fwVersion: downloadedFile.fwVersion,
                localPath: "path/for/unpacked.file"
            )
            completion(FWUpdateIntermediateResult.success(unpackedFile))
        }

    }

    private func isFWValid(file: FWFile) -> Bool {
        /*
         checking the format, the signiture and other security things
         */
        return true
    }
}

protocol FWValidatorDelegate: AnyObject {

    func validationFinished(result: FWUpdateIntermediateResult<FWFile>)
}

/*
 Mock for the real DataStore client
 */
final class DataStore {

    var error: FWUpdateError?

    func currentFWVersion() -> Int? {
        return 3
    }

    func patchToSaveNewFW() -> String {
        return "some/local/path"
    }

    func store(file: FWFile, completion: @escaping (Bool)->()) {
        // storing the data into DB
        sleep(2)
        DispatchQueue.global().async {
            completion(true)
        }
    }
}


/*
 Mock for the real RemoteDeviceManager client
 */
final class RemoteDeviceManager {

    var error: FWUpdateError?

    func uploadVerision(fromFile: FWFile, progress: @escaping ProgressHandler, completion: @escaping ComplitionHandler) {
        sleep(1)
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            for percent in 95...100 {
                if let err = self.error {
                    completion(FWUpdateIntermediateResult.failure(err))
                    return
                }
                if percent < 100 {
                    progress(FWUpdateIntermediateResult.success(percent))
                } else {
                    completion(FWUpdateIntermediateResult.success(true))
                }
                sleep(1)
            }
        }
    }

    func installAndRelaunch(completion: @escaping (Bool)->()) {
        DispatchQueue.global().async {
            sleep(5)
            completion(self.error == nil)
        }
    }
}
