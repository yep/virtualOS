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
    
    fileprivate func download(restoreImage: VZMacOSRestoreImage) {
        Logger.shared.log(level: .default, "downloading restore image for \(restoreImage.operatingSystemVersionString)")

        let downloadTask = URLSession.shared.downloadTask(with: restoreImage.url) { localURL, response, error in
            self.downloading = false
            self.downloadFinished(localURL: localURL, error: error)
        }
        observation = downloadTask.progress.observe(\.fractionCompleted) { _, _ in }
        downloadTask.resume()
        self.downloadTask = downloadTask
                
        func updateDownloadProgress() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                let progressString: String
                
                if let byteCompletedCount = downloadTask.progress.userInfo[ProgressUserInfoKey("NSProgressByteCompletedCountKey")] as? Int,
                   let byteTotalCount = downloadTask.progress.userInfo[ProgressUserInfoKey("NSProgressByteTotalCountKey")] as? Int
                {
                    let mbCompleted = byteCompletedCount / (1024 * 1024)
                    let mbTotal     = byteTotalCount / (1024 * 1024)
                    progressString = "Restore Image\nDownloading \(Int(downloadTask.progress.fractionCompleted * 100))% (\(mbCompleted) of \(mbTotal) MB)"
                } else {
                    progressString = "Restore Image\nDownloading \(Int(downloadTask.progress.fractionCompleted * 100))%"
                }
                Logger.shared.log(level: .default, "\(progressString)")
                
                self?.delegate?.progress(downloadTask.progress.fractionCompleted, progressString: progressString)

                if let downloading = self?.downloading, downloading {
                    updateDownloadProgress()
                }
            }
        }
        
        updateDownloadProgress()
    }
    
    fileprivate func downloadFinished(localURL: URL?, error: Error?) {
        Logger.shared.log(level: .default, "download finished")
        delegate?.progress(100, progressString: "Done")
        
        if let error = error {
            Logger.shared.log(level: .default, "\(error.localizedDescription)")
            delegate?.done(error: error)
        }
        
        if let localURL = localURL,
           let vmFilesDirectoryString = UserDefaults.standard.vmFilesDirectory
        {
            let restoreImageURL = createRestoreImageURL(vmFilesDirectoryString: vmFilesDirectoryString)
            try? FileManager.default.moveItem(at: localURL, to: restoreImageURL)
            Logger.shared.log(level: .default, "moved restore image to \(restoreImageURL)")
            delegate?.done(error: nil)
        } else {
            Logger.shared.log(level: .default, "failed to move downloaded restore image to vm files directory")
            delegate?.done(error: RestoreError(localizedDescription: "Failed to move downloaded restore image to VM files directory"))
            return
        }
    }
    
    fileprivate func createRestoreImageURL(vmFilesDirectoryString: String) -> URL {
        // try to find a filename that does not exist
        var url = URL(fileURLWithPath: vmFilesDirectoryString)
        var exists = true
        var i = 1
        while exists {
            url = nextURL(url, i)
            if FileManager.default.fileExists(atPath: url.path) {
                i += 1
            } else {
                exists = false
            }
        }
        return url
    }
    
    fileprivate func nextURL(_ url: URL, _ i: Int) -> URL {
        var filename = url.lastPathComponent
        filename = filename.replacingOccurrences(of: ".ipsw", with: "")
        
        let filenameComponents = filename.split(separator: "_")
        if filenameComponents.count > 0 {
            filename = String(filenameComponents[0])
        }
        filename += "_\(i).ipsw"
        
        let path = url.deletingLastPathComponent().appendingPathComponent(filename, conformingTo: .bundle).path
        return URL(fileURLWithPath: path)
    }

}

#endif
