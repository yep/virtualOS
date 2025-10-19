//
//  ProgressViewController.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
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
    @IBOutlet weak var cancelButton: NSButton!
    
    var mode: Mode = .download
    var restoreImageName: String?
    var diskImageSize: Int? = 0
    fileprivate let restoreImageDownload = RestoreImageDownload()
    fileprivate var restoreImageInstall = RestoreImageInstall()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        progressIndicator.doubleValue = 0
        statusTextField.stringValue = "Starting"
        statusTextField.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
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
        DispatchQueue.main.async { [weak self] in
            self?.progressIndicator.doubleValue = progress * 100
            self?.statusTextField.stringValue = progressString
        }
    }
    
    func done(error: Error? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let mainViewController = self?.presentingViewController as? MainViewController else {
                return
            }
        
            mainViewController.dismiss(self)
            mainViewController.updateUI()
            
            if let error = error {
                mainViewController.showErrorAlert(error: error)
                self?.statusTextField.stringValue = "Install Failed."
                self?.cancelButton.title = "Close"
            } else {
                self?.cancelButton.title = "Done"
            }
        }
    }
}

#endif
