//
//  ProvisioningViewController.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Cocoa
import OSLog

final class ProvisioningViewController: NSViewController {
    @IBOutlet weak var diskSizeTextField: NSTextField!
    @IBOutlet weak var guestProvisioningSwitch: NSSwitch!
    @IBOutlet weak var fullNameTextField: NSTextField!
    @IBOutlet weak var usernameTextField: NSTextField!
    @IBOutlet weak var passwordSecureTextField: NSSecureTextField!
    @IBOutlet weak var autoLoginSwitch: NSSwitch!
    @IBOutlet weak var remoteLoginSwitch: NSSwitch!
    
    var restoreImageName: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        diskSizeTextField.delegate = self
    }
    
    @IBAction func guestProvsioningSwitched(_ sender: NSSwitch) {
        set(enabled: guestProvisioningSwitch.state == .on)
    }
 
    @IBAction func okButtonPressed(_ sender: Any) {
        if guestProvisioningSwitch.state == .on && fullNameTextField.stringValue.count < 1 {
            NSAlert.okCancelAlert(messageText: "Invalid Full Name", informativeText: "Full name too short, at least one character is required.", showCancelButton: false, accessoryView: nil).runModal()
        } else if guestProvisioningSwitch.state == .on && usernameTextField.stringValue.count < 1 {
            NSAlert.okCancelAlert(messageText: "Invalid Username", informativeText: "Username too short, at least one character is required.", showCancelButton: false, accessoryView: nil).runModal()
        } else if guestProvisioningSwitch.state == .on && passwordSecureTextField.stringValue.count < 4 {
            NSAlert.okCancelAlert(messageText: "Invalid Password", informativeText: "Password too short, at least 4 characters are required.", showCancelButton: false, accessoryView: nil).runModal()
        } else {
            if guestProvisioningSwitch.state == .on {
                let provisioningInfo = ProvisioningInfo(fullName: fullNameTextField.stringValue, username: usernameTextField.stringValue, password: passwordSecureTextField.stringValue, autoLogin: autoLoginSwitch.state == .on, remoteLogin: remoteLoginSwitch.state == .on)
                let encoder = PropertyListEncoder()
                encoder.outputFormat = .binary
                do {
                    let data = try encoder.encode(provisioningInfo)
                    var userInfo: [String: Any] = [:]
                    userInfo[Constants.provisioningInfoKey] = data
                    userInfo[Constants.selectedRestoreImageKey] = restoreImageName
                    let notification = Notification(name: Constants.guestProvisioningdNotification, userInfo: userInfo)
                    NotificationCenter.default.post(notification)
                } catch {
                    Logger.shared.log(level: .error, "\(error.localizedDescription)") // encode failed
                }
            } else {
                let userInfo = [Constants.selectedRestoreImageKey: restoreImageName]
                let notification = Notification(name: Constants.guestProvisioningdNotification, userInfo: userInfo)
                NotificationCenter.default.post(notification)
            }
            view.window?.close()
        }
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        view.window?.close()
    }
    
    fileprivate func set(enabled: Bool) {
        fullNameTextField.isEnabled = enabled
        usernameTextField.isEnabled = enabled
        passwordSecureTextField.isEnabled = enabled
        autoLoginSwitch.isEnabled = enabled
        remoteLoginSwitch.isEnabled = enabled
    }
}

extension ProvisioningViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        
        let filtered = field.stringValue.filter(\.isNumber)
        if field.stringValue != filtered {
            field.stringValue = filtered
        }
    }
}
