//
//  VMViewController.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Virtualization
import StoreKit
import OSLog

#if arch(arm64)

final class VMViewController: NSViewController {
    @IBOutlet var containerView: NSView!
    @IBOutlet var vmView: VZVirtualMachineView!
    @IBOutlet var statusLabel: NSTextField!
    
    var vmBundle: VMBundle?
    var vmParameters: VMParameters?
    var provisioningInfo: ProvisioningInfo?
    fileprivate var vmConfiguration: VMConfiguration?
    fileprivate var vm: VZVirtualMachine?
    fileprivate let queue = DispatchQueue.global(qos: .userInteractive)
    fileprivate var guestDidStop = false
    private var usbPassthroughStorage: AnyObject? // type erased because usb passthrough requires macOS 27
    var didClose: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusLabel.stringValue = ""

        createVM()
        
        let startOptionsResult = startOptions()
        switch startOptionsResult {
        case .failure(let error):
            show(errorString: "Guest provisioning failed: \(error.localizedDescription)")
            return
        case .success(let startOptions):
            if let startOptions {
                startWithGuestProvisioning(startOptions)
            } else {
                start()
            }
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.delegate = self
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()

        if #available(macOS 27.0, *) {
            usbPassthrough?.activate(menu: usbMenu)
            usbPassthrough?.start()
        }
        
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
            do {
                try vmConfiguration.setup(parameters: vmParameters, macPlatformConfiguration: macPlatformConfiguration, bundleURL: bundleURL)
            } catch {
                show(errorString: "Failed to configure VM storage: \(error.localizedDescription)")
                return
            }
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
            if #available(macOS 27.0, *) {
                usbPassthroughStorage = USBPassthroughController(
                    virtualMachine: vm,
                    queue: queue,
                    ownerID: bundleURL.path,
                    ownerName: bundleURL.deletingPathExtension().lastPathComponent,
                    isWindowKey: { [weak self] in self?.view.window?.isKeyWindow == true }
                )
            }
        } else {
            show(errorString: "Could not create platform configuration.")
            return
        }
    }
    
    fileprivate func startOptions() -> Result<VZVirtualMachineStartOptions?, Error> {
        if #available(macOS 27.0, *),
           let provisioningInfo
        {
            let provisioningOptions = VZMacGuestProvisioningOptions()
            provisioningOptions.fullName = provisioningInfo.fullName
            provisioningOptions.username = provisioningInfo.username
            provisioningOptions.password = provisioningInfo.password
            provisioningOptions.logsInAutomatically = provisioningInfo.autoLogin
            provisioningOptions.enablesRemoteLogin = provisioningInfo.remoteLogin
            
            let startOptions = VZMacOSVirtualMachineStartOptions()
            do {
                try startOptions.setGuestProvisioning(provisioningOptions)
            } catch let error {
                return .failure(error)
            }
            return .success(startOptions)
        }
        
        return .success(nil)
    }
    
    fileprivate func startWithGuestProvisioning(_ startOptions: VZVirtualMachineStartOptions) {
        queue.async { [weak self] in
            self?.vm?.start(options: startOptions) { error in
                if let error {
                    self?.show(errorString: "Starting VM with guest provisioning failed: \(error.localizedDescription) You can start the VM again for manual setup.")
                } else {
                    self?.started()
                }
            }
        }
    }
    
    fileprivate func start() {
        // start without guest provisioning
        queue.async { [weak self] in
            self?.vm?.start() { (result: Result<Void, Error>) in
                switch result {
                case .success:
                    self?.started()
                case .failure(let error):
                    self?.show(errorString: "Starting VM failed: \(error.localizedDescription)")
                }
            }
        }
    }

    fileprivate func started() {
        Logger.shared.log(level: .default, "vm started")
        guestDidStop = false
        if #available(macOS 27.0, *) {
            usbPassthrough?.virtualMachineStarted()
        }
    }
    
    fileprivate func show(errorString: String) {
        Logger.shared.log(level: .default, "\(errorString)")
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.stringValue = errorString
        }
    }

    @available(macOS 27.0, *)
    private var usbPassthrough: USBPassthroughController? {
        usbPassthroughStorage as? USBPassthroughController
    }

    private var usbMenu: NSMenu? {
        NSApp.mainMenu?.items.first { $0.title == "USB" }?.submenu
    }

}

extension VMViewController: VZVirtualMachineDelegate {
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        show(errorString: "Guest did stop")
        guestDidStop = true
        if #available(macOS 27.0, *) {
            usbPassthrough?.stop()
        }
    }
    
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
        show(errorString: "Guest did stop with error: \(error.localizedDescription)")
        guestDidStop = true
        if #available(macOS 27.0, *) {
            usbPassthrough?.stop()
        }
    }
}

extension VMViewController: NSWindowDelegate  {
    func windowWillClose(_ notification: Notification) {
        if #available(macOS 27.0, *) {
            usbPassthrough?.close()
        }
        vmView.virtualMachine = nil
        vm = nil
        vmConfiguration = nil
        let didClose = didClose
        DispatchQueue.main.async {
            didClose?()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if guestDidStop {
            return true
        } else {
            let alert: NSAlert = NSAlert.okCancelAlert(messageText: "Stop VM", informativeText: "Are you sure you want to stop the VM?\nAll unsaved changes will be lost.", alertStyle: .warning)
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

    func windowDidBecomeKey(_ notification: Notification) {
        if #available(macOS 27.0, *) {
            usbPassthrough?.activate(menu: usbMenu)
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        if #available(macOS 27.0, *) {
            usbPassthrough?.deactivate()
        }
    }
}

#endif
