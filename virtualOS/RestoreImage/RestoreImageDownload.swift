//
//  Download.swift
//  virtualOS
//
//  Created by Jahn Bertsch
//

import Virtualization
import Combine
import OSLog

#if arch(arm64)

protocol ProgressDelegate: AnyObject {
    func progress(_ progress: Double, progressString: String)
    func done()
}

final class RestoreImageDownload {
    weak var delegate: ProgressDelegate?
    fileprivate var observation: NSKeyValueObservation?
    fileprivate var downloadTask: URLSessionDownloadTask?
    fileprivate var downloading = true
    fileprivate let logger = Logger.init(subsystem: "com.github.virtualOS", category: "log")

    deinit {
        observation?.invalidate()
    }
    
    func fetch() {
        VZMacOSRestoreImage.fetchLatestSupported { [self](result: Result<VZMacOSRestoreImage, Error>) in
            switch result {
            case let .success(restoreImage):
                download(restoreImage: restoreImage)
            case let .failure(error):
                logger.log(level: .default, "failure: \(error.localizedDescription)")
                delegate?.done()
            }
        }
    }
    
    func cancel() {
        downloadTask?.cancel()
    }
    
    // MARK: - Private
    
    fileprivate func download(restoreImage: VZMacOSRestoreImage) {
        logger.log(level: .default, "fetched, macOS \(restoreImage.operatingSystemVersionString)")
                
        let downloadTask = URLSession.shared.downloadTask(with: restoreImage.url) {localUrl, response, error in
            self.downloading = false
            self.downloadFinished(localURL: localUrl, error: error)
        }
        observation = downloadTask.progress.observe(\.fractionCompleted) { _, _ in }
        downloadTask.resume()
        self.downloadTask = downloadTask
        
        logger.log(level: .default, "downloading")
        
        func printProgress() {
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
                self?.logger.log(level: .default, "\(progressString)")
                
                self?.delegate?.progress(downloadTask.progress.fractionCompleted, progressString: progressString)

                if let downloading = self?.downloading, downloading {
                    printProgress()
                }
            }
        }
        printProgress()
    }
    
    fileprivate func downloadFinished(localURL: URL?, error: Error?) {
        logger.log(level: .default, "download finished")
        delegate?.progress(100, progressString: "Error")
        
        if let error = error {
            logger.log(level: .default, "\(error.localizedDescription)")
            return
        }
        
        if let localURL = localURL {
            try? FileManager.default.moveItem(at: localURL, to: URL.restoreImageURL)
            logger.log(level: .default, "moved restore image to \(URL.restoreImageURL)")
            delegate?.done()
        } else {
            logger.log(level: .default, "failed to move downloaded restore image to \(URL.restoreImageURL)")
            return
        }
    }
}

#endif
