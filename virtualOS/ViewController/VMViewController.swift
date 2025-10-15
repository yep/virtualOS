//
//  VMViewController.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Virtualization
import OSLog

#if arch(arm64)

final class VMViewController: NSViewController {
    @IBOutlet var containerView: NSView!
    @IBOutlet weak var statusLabel: NSTextField!
    
    var vmBundle: VMBundle?
    var vmParameters: VMParameters?
    fileprivate var vmConfiguration: VMConfiguration?
    fileprivate var vm: VZVirtualMachine?
    fileprivate let vmView = VZVirtualMachineView()
    fileprivate let queue = DispatchQueue.global(qos: .userInteractive)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        createVM()
        setupConstraints()
        
        queue.async { [weak self] in
            self?.vm?.start { (result: Result<Void, Error>) in
                switch result {
                case .success:
                    Logger.shared.log(level: .default, "running")
                case .failure(let error):
                    Logger.shared.log(level: .default, "running failed \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Private
    
    fileprivate func createVM() {
        guard let bundleURL = vmBundle?.url,
              let vmParameters = vmParameters else
        {
            Logger.shared.log(level: .default, "bundle url or vm parameters invalid")
            return
        }
        
        let macPlatformConfigurationResult = MacPlatformConfiguration.read(fromBundleURL: bundleURL)
        if case .failure(let restoreError) = macPlatformConfigurationResult {
            Logger.shared.log(level: .default, "\(restoreError.localizedDescription)")
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
                Logger.shared.log(level: .default, "failed to validate vm configuration: \(error.localizedDescription)")
                return
            }
            
            let vm = VZVirtualMachine(configuration: vmConfiguration, queue: queue)
            vm.delegate = self
            
            vmView.virtualMachine = vm
            vmView.automaticallyReconfiguresDisplay = true
            vmView.capturesSystemKeys = true
            self.vm = vm
        } else {
            Logger.shared.log(level: .default, "Could not create platform configuration.")
            return
        }
    }
    
    fileprivate func setupConstraints() {
        if let containerView  {
            let top = NSLayoutConstraint(item: containerView, attribute: .top, relatedBy: .equal, toItem: vmView, attribute: .top, multiplier: 1, constant: 0)
            let bottom = NSLayoutConstraint(item: containerView, attribute: .bottom, relatedBy: .equal, toItem: vmView, attribute: .bottom, multiplier: 1, constant: 0)
            let leading = NSLayoutConstraint(item: containerView, attribute: .leading, relatedBy: .equal, toItem: vmView, attribute: .leading, multiplier: 1, constant: 0)
            let trailing = NSLayoutConstraint(item: containerView, attribute: .trailing, relatedBy: .equal, toItem: vmView, attribute: .trailing, multiplier: 1, constant: 0)
            
            containerView.addSubview(vmView)
            containerView.addConstraint(top)
            containerView.addConstraint(bottom)
            containerView.addConstraint(leading)
            containerView.addConstraint(trailing)
            
            let centerX = NSLayoutConstraint(item: containerView, attribute: .centerX, relatedBy: .equal, toItem: statusLabel, attribute: .centerX, multiplier: 1, constant: 1)
            let centerY = NSLayoutConstraint(item: containerView, attribute: .centerY, relatedBy: .equal, toItem: statusLabel, attribute: .centerY, multiplier: 1, constant: 0)

            statusLabel.stringValue = ""
            statusLabel.removeFromSuperview()
            containerView.addSubview(statusLabel)
            containerView.addConstraint(centerX)
            containerView.addConstraint(centerY)
        }
    }
}

extension VMViewController: VZVirtualMachineDelegate {
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        let message = "Guest did stop"
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.stringValue = message
        }
        Logger.shared.log(level: .default, "\(message)")
    }
    
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.stringValue = "Guest did stop with error: \(error.localizedDescription)"
        }
        Logger.shared.log(level: .default, "\(self.statusLabel.stringValue)")
    }
}

#endif
