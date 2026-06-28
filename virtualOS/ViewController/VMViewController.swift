//
//  VMViewController.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Virtualization
import StoreKit
import AccessoryAccess // for usb passthrough
import OSLog

#if arch(arm64)

final class VMViewController: NSViewController {
    @IBOutlet var containerView: NSView!
    @IBOutlet var vmView: VZVirtualMachineView!
    @IBOutlet var statusLabel: NSTextField!
    
    var vmBundle: VMBundle?
    var vmParameters: VMParameters?
    fileprivate var vmConfiguration: VMConfiguration?
    fileprivate var vm: VZVirtualMachine?
    fileprivate let queue = DispatchQueue.global(qos: .userInteractive)

    override func viewDidLoad() {
        super.viewDidLoad()
        statusLabel.stringValue = ""

        createVM()
        
        queue.async { [weak self] in
            self?.vm?.start { (result: Result<Void, Error>) in
                switch result {
                case .success:
                    Logger.shared.log(level: .default, "vm started")
                    self?.setupUSBPassthrough()
                case .failure(let error):
                    self?.show(errorString: "Starting VM failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.delegate = self
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        UserDefaults.standard.userRatingCounter += 1
        if UserDefaults.standard.userRatingCounter.isMultiple(of: 5) {
            AppStore.requestReview(in: self)
        }
    }
    
    // MARK: - Private
    
    fileprivate func createVM() {
        guard let bundleURL = vmBundle?.url,
              let vmParameters = vmParameters else
        {
            show(errorString: "Bundle URL or VM parameters invalid")
            return
        }
        
        let macPlatformConfigurationResult = MacPlatformConfiguration.read(fromBundleURL: bundleURL)
        if case .failure(let restoreError) = macPlatformConfigurationResult {
            show(errorString: restoreError.localizedDescription)
            return
        } else if case .success(let macPlatformConfiguration) = macPlatformConfigurationResult,
               let macPlatformConfiguration = macPlatformConfiguration
        {
            let vmConfiguration = VMConfiguration()
            vmConfiguration.setup(parameters: vmParameters, macPlatformConfiguration: macPlatformConfiguration, bundleURL: bundleURL)
            self.vmConfiguration = vmConfiguration
            
            do {
                try vmConfiguration.validate()
                Logger.shared.log(level: .default, "vm configuration is valid, using \(vmParameters.cpuCount) cpus and \(vmParameters.memorySizeInGB) gb ram")
            } catch let error {
                show(errorString: "Failed to validate VM configuration: \(error.localizedDescription)")
                return
            }
            
            let vm = VZVirtualMachine(configuration: vmConfiguration, queue: queue)
            vm.delegate = self
            
            vmView.virtualMachine = vm
            vmView.automaticallyReconfiguresDisplay = true
            vmView.capturesSystemKeys = true
            self.vm = vm
        } else {
            show(errorString: "Could not create platform configuration.")
            return
        }
    }
    
    func setupUSBPassthrough() {
        if #available(macOS 27.0, *) {
            let criteria: [AAUSBAccessoryMatchingCriteria] = []
            Task {
                if let accessories = try? await AAUSBAccessoryManager.shared.registerListener(self, matchingCriteria: criteria) {
                    for accessory in accessories {
                        usbAccessoryDidConnect(accessory)
                    }
                }
            }
        }
    }
    
    fileprivate func show(errorString: String) {
        Logger.shared.log(level: .default, "\(errorString)")
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.stringValue = errorString
        }
    }
}

extension VMViewController: VZVirtualMachineDelegate {
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        show(errorString: "Guest did stop")
    }
    
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
        show(errorString: "Guest did stop with error: \(error.localizedDescription)")
    }
}

@available(macOS 27.0, *)
extension VMViewController: AAUSBAccessoryListener {
    func usbAccessoryDidConnect(_ usbAccessory: AAUSBAccessory) {
        queue.async { [weak self] in
            do {
                let configuration = VZUSBPassthroughDeviceConfiguration(device: usbAccessory)
                let device = try VZUSBPassthroughDevice(configuration: configuration)
                self?.vm?.usbControllers.first?.attach(device: device) { error in
                    if let error {
                        Logger.shared.log(level: .default, "usbAccessoryDidConnect: \(error)")
                    }
                }
            } catch {
                Logger.shared.log(level: .default, "usbAccessoryDidConnect: \(error)")
            }
        }
    }
    
    func usbAccessoryDidDisconnect(_ usbAccessory: AAUSBAccessory) {
        // Logger.shared.log(level: .default, "usbAccessoryDidDisconnect")
    }
}

extension VMViewController: NSWindowDelegate  {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let alert: NSAlert = NSAlert.okCancelAlert(messageText: "Stop VM", informativeText: "Are you sure you want to stop the VM?", alertStyle: .warning)
        let selection = alert.runModal()
        if selection == NSApplication.ModalResponse.alertFirstButtonReturn ||
           selection == NSApplication.ModalResponse.OK
        {
            return true
        } else {
            return false
        }
    }
}

#endif
