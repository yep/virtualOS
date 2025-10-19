//
//  Download.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Virtualization
import Combine
import OSLog

#if arch(arm64)

protocol ProgressDelegate: AnyObject {
    func progress(_ progress: Double, progressString: String)
    func done(error: Error?)
}

final class RestoreImageDownload {
    weak var delegate: ProgressDelegate?
    fileprivate var observation: NSKeyValueObservation?
    fileprivate var downloadTask: URLSessionDownloadTask?
    fileprivate var downloading = true

    deinit {
        observation?.invalidate()
    }
    
    func fetch() {
        VZMacOSRestoreImage.fetchLatestSupported { [self](result: Result<VZMacOSRestoreImage, Error>) in
            switch result {
            case let .success(restoreImage):
                download(restoreImage: restoreImage)
            case let .failure(error):
                delegate?.done(error: error)
            }
        }
    }
    
    func cancel() {
        downloadTask?.cancel()
    }
    
    // MARK: - Private
    
    fileprivate func progressDone(error: Error?) {
        FileModel.cleanUpTemporaryFiles()
        delegate?.progress(100, progressString: "Done")
        delegate?.done(error: error)
    }
    
    fileprivate func download(restoreImage: VZMacOSRestoreImage) {
        Logger.shared.log(level: .default, "downloading restore image for \(restoreImage.operatingSystemVersionString)")

        var targetURL: URL? = nil
        if let filesDirectoryString = UserDefaults.standard.restoreImagesDirectory ?? UserDefaults.standard.vmFilesDirectory {
            targetURL = createRestoreImageURL(directoryString: filesDirectoryString)
            
            // grant access for the restore images path
            guard Bookmark.startRestoreImagesDirectoryAccess() else {
                Logger.shared.warning("Could not start accessing bookmark \(filesDirectoryString)")
                return
            }
        }
        
        let downloadTask = URLSession.shared.downloadTask(with: restoreImage.url) { tempURL, response, error in
            self.downloading = false
            self.downloadFinished(tempURL: tempURL, restoreImageURL: targetURL, error: error)
        }
        observation = downloadTask.progress.observe(\.fractionCompleted) { _, _ in }
        downloadTask.resume()
        self.downloadTask = downloadTask
                
        func updateDownloadProgress() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard self?.downloading == true else {
                    return
                }
                
                let progressString: String
                
                if let byteCompletedCount = downloadTask.progress.userInfo[ProgressUserInfoKey("NSProgressByteCompletedCountKey")] as? Int,
                   let byteTotalCount = downloadTask.progress.userInfo[ProgressUserInfoKey("NSProgressByteTotalCountKey")] as? Int
                {
                    let mbCompleted = byteCompletedCount / (1024 * 1024)
                    let mbTotal     = byteTotalCount / (1024 * 1024)
                    progressString = "\(Int(downloadTask.progress.fractionCompleted * 100))% (\(mbCompleted) of \(mbTotal) MB)"
                } else {
                    progressString = "\(Int(downloadTask.progress.fractionCompleted * 100))%"
                }
                Logger.shared.log(level: .debug, "download progress: \(progressString)")
                
                self?.delegate?.progress(downloadTask.progress.fractionCompleted, progressString: "\(restoreImage.operatingSystemVersionString)\nDownloading \(progressString)")

                // continue updating
                updateDownloadProgress()
            }
        }
        
        updateDownloadProgress()
    }
    
    fileprivate func downloadFinished(tempURL: URL?, restoreImageURL: URL?, error: Error?) {
        if let error {
            Logger.shared.error("\(error.localizedDescription)")
            progressDone(error: error)
            return
        }
        Logger.shared.log(level: .default, "download finished")
        
        let moveError = RestoreError(localizedDescription: "Failed to prepare downloaded restore image")
        if let tempURL, let restoreImageURL {
            Logger.shared.log(level: .debug, "moving restore image: \(tempURL) to \(restoreImageURL)")
            delegate?.progress(99, progressString: "Preparing file. Please wait...")
            
            do {
                try FileManager.default.moveItem(at: tempURL, to: restoreImageURL)
                Logger.shared.log(level: .default, "moved restore image to \(restoreImageURL)")
                progressDone(error: nil)
            } catch {
                Logger.shared.log(level: .error, "failed to prepare restore image: \(error.localizedDescription)")
                progressDone(error: moveError)
            }
        } else {
            Logger.shared.log(level: .error, "failed to prepare downloaded restore image ")
            progressDone(error: moveError)
        }
    }
    
    fileprivate func createRestoreImageURL(directoryString: String) -> URL {
        // try to find a filename that does not exist
        var url = URL(fileURLWithPath: directoryString)
        var exists = true
        var i = 1
        while exists {
            url = URL.nextURL(for: url, index: i, baseName: "RestoreImage")
            if FileManager.default.fileExists(atPath: url.path) {
                i += 1
            } else {
                exists = false
            }
        }
        return url
    }
}

#endif
