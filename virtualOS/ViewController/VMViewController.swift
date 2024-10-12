//
//  VMViewController.swift
//  virtualOS
//
//  Created by Jahn Bertsch
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
    fileprivate let logger = Logger.init(subsystem: "com.github.virtualOS", category: "log")
    fileprivate let queue = DispatchQueue.global(qos: .userInteractive)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        createVM()
        setupConstraints()
        
        queue.async { [weak self] in
            self?.vm?.start { (result: Result<Void, Error>) in
                switch result {
                case .success:
                    self?.logger.log(level: .default, "running")
                case .failure(let error):
                    self?.logger.log(level: .default, "running failed \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Private
    
    fileprivate func createVM() {
        if let bundleURL = vmBundle?.url,
           let vmParameters = vmParameters,
           let macPlatformConfiguration = MacPlatformConfiguration.read(fromBundleURL: bundleURL)
        {
            let vmConfiguration = VMConfiguration()
            vmConfiguration.setup(parameters: vmParameters, macPlatformConfiguration: macPlatformConfiguration, bundleURL: bundleURL)
            self.vmConfiguration = vmConfiguration
        } else {
            logger.log(level: .default, "could not create vm config")
            return
        }

        guard let vmConfiguration else {
            logger.log(level: .default, "no vm config")
            return
        }
        
        do {
            try vmConfiguration.validate()
            logger.log(level: .default, "vm configuration is valid")
        } catch let error {
            logger.log(level: .default, "failed to validate vm configuration: \(error.localizedDescription)")
            return
        }
        
        let vm = VZVirtualMachine(configuration: vmConfiguration, queue: queue)
        vm.delegate = self
        
        vmView.virtualMachine = vm
        vmView.automaticallyReconfiguresDisplay = true
        vmView.capturesSystemKeys = true
        self.vm = vm
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
        logger.log(level: .default, "\(message)")
    }
    
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: any Error) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.stringValue = "Guest did stop with error: \(error.localizedDescription)"
        }
        logger.log(level: .default, "\(self.statusLabel.stringValue)")
    }
}

#endif
