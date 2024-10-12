//
//  ProgressViewController.swift
//  virtualOS
//
//  Created by Jahn Bertsch
//

import AppKit
import OSLog

#if arch(arm64)

final class ProgressViewController: NSViewController {
    enum Mode {
        case download
        case install
    }

    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var statusTextField: NSTextField!
    
    var mode: Mode = .download
    var restoreImageName: String?
    var diskImageSize: Int? = 0
    fileprivate let restoreImageDownload = RestoreImageDownload()
    fileprivate var restoreImageInstall = RestoreImageInstall()
    fileprivate let logger = Logger.init(subsystem: "com.github.virtualOS", category: "log")

    override func viewWillAppear() {
        super.viewWillAppear()
        progressIndicator.doubleValue = 0
        statusTextField.stringValue = "Starting"
        // logger.log(level: .default, "\(progressViewController.mode): \(mode))")
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        if restoreImageName == Constants.restoreImageNameLatest ||
           mode == .download
        {
            restoreImageDownload.delegate = self
            restoreImageDownload.fetch()
            mode = .download // restoreImageNameLatest is also a download
        } else if mode == .install {
            restoreImageInstall.restoreImageName = restoreImageName
            restoreImageInstall.diskImageSize = diskImageSize
            restoreImageInstall.delegate = self
            restoreImageInstall.install()
        }
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        cancel()
    }
    
    @IBAction func cancelButtonPressed(_ sender: NSButton) {
        cancel()
        if let mainViewController = presentingViewController as? MainViewController {
            mainViewController.updateUI()
            mainViewController.dismiss(self)
        }
    }
    
    fileprivate func cancel() {
        if mode == .download {
            restoreImageDownload.cancel()
        } else if mode == .install {
            restoreImageInstall.cancel()
        }
    }
}

extension ProgressViewController: ProgressDelegate {
    func progress(_ progress: Double, progressString: String) {
        progressIndicator.doubleValue = progress * 100
        statusTextField.stringValue = progressString
    }
    
    func done() {
        DispatchQueue.main.async { [weak self] in
            if let mainViewController = self?.presentingViewController as? MainViewController {
                mainViewController.dismiss(self)
            }
        }
    }
}

#endif
