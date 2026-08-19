//
//  ViewController.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import Cocoa
import OSLog
import Virtualization

class MainViewControllerBase: NSViewController {
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var vmNameTextField: NSTextField!
    @IBOutlet weak var parameterOutlineView: NSOutlineView!
    @IBOutlet weak var cpuCountLabel: NSTextField!
    @IBOutlet weak var cpuCountSlider: NSSlider!
    @IBOutlet weak var ramLabel: NSTextField!
    @IBOutlet weak var ramSlider: NSSlider!
    @IBOutlet weak var microphoneSwitch: NSSwitch!
    @IBOutlet weak var autostartSwitch: NSSwitch!
    @IBOutlet weak var networkPopUpButton: NSPopUpButton!
    @IBOutlet weak var networkBridgePopUpButton: NSPopUpButton!
}

#if arch(arm64)

final class MainViewController: MainViewControllerBase {
    fileprivate let mainStoryBoard = NSStoryboard(name: "Main", bundle: nil)
    fileprivate let viewModel = MainViewModel()
    fileprivate var activeVMBundleURLs = Set<URL>()
    fileprivate var didAttemptAutostart = false
    fileprivate var windowController: WindowController? {
        return view.window?.windowController as? WindowController
    }
    
    fileprivate func updateEnabledState(enabled: Bool, vmParameters: VMParameters? = nil) {
        ramSlider.isEnabled                = enabled
        cpuCountSlider.isEnabled           = enabled
        vmNameTextField.isEnabled          = enabled
        microphoneSwitch.isEnabled         = enabled
        autostartSwitch.isEnabled          = enabled
        networkPopUpButton.isEnabled       = enabled
        networkBridgePopUpButton.isEnabled = enabled
        if vmParameters?.microphoneEnabled ?? false {
            microphoneSwitch.state = .on
        } else {
            microphoneSwitch.state = .off
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.window?.delegate           = self
        tableView.delegate              = self
        tableView.dataSource            = viewModel.tableViewDataSource
        parameterOutlineView.dataSource = viewModel.parametersViewDataSource
        parameterOutlineView.delegate   = viewModel.parametersViewDelegate
        vmNameTextField.delegate        = viewModel.textFieldDelegate
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateUI), name: NSApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateUI), name: NSControl.textDidEndEditingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateUI), name: Constants.didChangeAppSettingsNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(restoreImageSelected), name: Constants.restoreImageNameSelectedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(guestProvisioningSelected), name: Constants.guestProvisioningdNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(networkBridgeInterfaceWillPopUp), name: NSPopUpButton.willPopUpNotification, object: nil)
        
        ramSlider.target = self
        ramSlider.action = #selector(memorySliderChanged(sender:))
        cpuCountSlider.target = self
        cpuCountSlider.action = #selector(cpuCountChanged(sender:))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        windowController?.mainViewController = self
        vmNameTextField.resignFirstResponder()
        _ = URL.startAccessingVMFilesDirectory()
        FileModel.cleanUpTemporaryFiles()
        updateUI()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        if viewModel.vmParameters?.microphoneEnabled == true {
            viewModel.checkMicrophonePermission {}
        }
        
        for arg in CommandLine.arguments {
            if (arg == "start") {
                Logger.shared.log(level: .default, "auto-starting vm")
                startVM()
            }
        }

        startAutostartVMIfNeeded()
    }
    
    @IBAction func startButtonPressed(_ sender: NSButton) {
        if viewModel.vmParameters?.installFinished == true {
            startVM()
        }
    }
    
    @IBAction func installButtonPressed(_ sender: NSButton) {
        if let restoreImageViewController = mainStoryBoard.instantiateController(withIdentifier: "RestoreImageViewController") as? RestoreImageViewController
        {
            show(viewController: restoreImageViewController, title: "Restore Image")
        } else {
            Logger.shared.log(level: .default, "show restore image window failed")
        }
    }

    @IBAction func snapshotButtonPressed(_ sender: NSToolbarItem) {
        guard let bundleURL = viewModel.vmBundle?.url,
              viewModel.vmParameters?.installFinished == true else {
            return
        }

        if activeVMBundleURLs.contains(bundleURL) {
            let alert = NSAlert.okCancelAlert(
                messageText: "Stop VM First",
                informativeText: "Stop the VM before creating, restoring, or deleting a snapshot.",
                showCancelButton: false
            )
            alert.runModal()
            return
        }

        guard #available(macOS 27.0, *), SnapshotModel.isSnapshotCapable(bundleURL: bundleURL) else {
            let alert = NSAlert.okCancelAlert(
                messageText: "Snapshots Not Supported",
                informativeText: "Snapshots require an ASIF disk image created by virtualOS on macOS 27 or later. This VM uses a legacy 'Disk.img' disk.",
                showCancelButton: false
            )
            alert.runModal()
            return
        }

        let menu = NSMenu(title: "Snapshots")
        menu.addItem(withTitle: "Create Snapshot", action: #selector(createSnapshot(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        let snapshotModel = SnapshotModel(bundleURL: bundleURL)
        switch Result(catching: { (try snapshotModel.snapshots(), try snapshotModel.deletableSnapshotIDs()) }) {
        case .success(let (snapshots, deletableSnapshotIDs)) where !snapshots.isEmpty:
            for snapshot in snapshots.reversed() {
                let date = DateFormatter.localizedString(from: snapshot.createdAt, dateStyle: .short, timeStyle: .short)
                let restoreItem = menu.addItem(withTitle: "Restore \(snapshot.name) (\(date))", action: #selector(restoreSnapshot(_:)), keyEquivalent: "")
                restoreItem.representedObject = snapshot.id.uuidString
                if deletableSnapshotIDs.contains(snapshot.id) {
                    let deleteItem = menu.addItem(withTitle: "Delete \(snapshot.name) (\(date))", action: #selector(deleteSnapshot(_:)), keyEquivalent: "")
                    deleteItem.representedObject = snapshot.id.uuidString
                }
            }
            menu.addItem(.separator())
            if deletableSnapshotIDs.isEmpty {
                let item = menu.addItem(withTitle: "To delete a snapshot, restore from previous snapshot first", action: nil, keyEquivalent: "")
                item.isEnabled = false
            }
        case .success:
            let item = menu.addItem(withTitle: "No Snapshots", action: nil, keyEquivalent: "")
            item.isEnabled = false
        case .failure(let error):
            Logger.shared.log(level: .default, "could not load snapshots: \(error.localizedDescription)")
            return
        }
        menu.items.forEach { $0.target = self }
        guard let window = view.window else { return }
        let point = view.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        menu.popUp(positioning: nil, at: point, in: view)
    }

    @available(macOS 27.0, *)
    @objc fileprivate func createSnapshot(_ sender: Any?) {
        performSnapshotOperation { snapshotModel in
            _ = try snapshotModel.createSnapshot()
        }
    }

    @available(macOS 27.0, *)
    @objc fileprivate func restoreSnapshot(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String,
              let snapshotID = UUID(uuidString: identifier) else { return }
        let snapshotName = viewModel.vmBundle.flatMap { try? SnapshotModel(bundleURL: $0.url).snapshotName(for: snapshotID) } ?? "selected snapshot"
        let alert = NSAlert.okCancelAlert(
            messageText: "Restore \(snapshotName)?",
            informativeText: "Changes after this snapshot will no longer be the active disk state.",
            alertStyle: .warning
        )
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        performSnapshotOperation { snapshotModel in
            try snapshotModel.restore(snapshotID: snapshotID)
        }
    }

    @available(macOS 27.0, *)
    @objc fileprivate func deleteSnapshot(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String,
              let snapshotID = UUID(uuidString: identifier) else { return }
        let snapshotName = viewModel.vmBundle.flatMap { try? SnapshotModel(bundleURL: $0.url).snapshotName(for: snapshotID) } ?? "selected snapshot"
        let alert = NSAlert.okCancelAlert(
            messageText: "Delete \(snapshotName)?",
            informativeText: "This cannot be undone.",
            alertStyle: .warning
        )
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        performSnapshotOperation { snapshotModel in
            try snapshotModel.delete(snapshotID: snapshotID)
        }
    }

    @available(macOS 27.0, *)
    fileprivate func performSnapshotOperation(_ operation: (SnapshotModel) throws -> Void) {
        guard let bundleURL = viewModel.vmBundle?.url,
              !activeVMBundleURLs.contains(bundleURL) else { return }
        do {
            try operation(SnapshotModel(bundleURL: bundleURL))
            updateUI()
        } catch {
            Logger.shared.log(level: .default, "snapshot operation failed: \(error.localizedDescription)")
        }
    }

    @IBAction func autostartSwitchToggled(_ sender: NSSwitch) {
        guard let bundleURL = viewModel.vmBundle?.url else { return }
        UserDefaults.standard.autostartVMBundlePath = sender.state == .on ? bundleURL.path : nil
        updateUI()
    }

    @IBAction func deleteButtonPressed(_ sender: Any) {
        guard let vmBundle = viewModel.vmBundle else {
            return
        }
        
        let alert: NSAlert = NSAlert.okCancelAlert(messageText: "Delete VM '\(vmBundle.name)'?", informativeText: "This can not be undone.", alertStyle: .warning)
        let selection = alert.runModal()
        if selection == NSApplication.ModalResponse.alertFirstButtonReturn ||
            selection == NSApplication.ModalResponse.OK
        {
            if UserDefaults.standard.autostartVMBundlePath == vmBundle.url.path {
                UserDefaults.standard.autostartVMBundlePath = nil
            }
            viewModel.deleteVM(selection: selection, vmBundle: vmBundle)
            viewModel.vmBundle = nil
            viewModel.vmParameters = nil
        }
        
        self.updateUI()
    }
    
    @IBAction func sharedFolderButtonPressed(_ sender: Any) {
        guard viewModel.vmParameters?.installFinished == true else {
            return
        }
        
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.prompt = "Select"
        openPanel.message = "Select a folder to share with the VM"
        let modalResponse = openPanel.runModal()
        var sharedFolderURL: URL?
        if modalResponse == .OK,
           let selectedURL = openPanel.url
        {
            sharedFolderURL = selectedURL
        } else if modalResponse == .cancel {
            sharedFolderURL = nil
        }
        
        viewModel.set(sharedFolderUrl: sharedFolderURL)
        updateOutlineView()
    }
    
    @objc func restoreImageSelected(notification: Notification) {
        if let userInfo = notification.userInfo,
           let restoreImageName = userInfo[Constants.selectedRestoreImageKey] as? String,
           let supportsGuestProvisioning = userInfo[Constants.provisioningInfoKey] as? Bool,
           restoreImageName != Constants.restoreImageNameLatest
        {
            if #available(macOS 27.0, *),
               supportsGuestProvisioning
            {
                if let provisioningViewController = mainStoryBoard.instantiateController(withIdentifier: "ProvisioningViewController") as? ProvisioningViewController
                {
                    provisioningViewController.restoreImageName = restoreImageName
                    show(viewController: provisioningViewController, title: "Provisioning")
                } else {
                    Logger.shared.log(level: .default, "show provisioning window failed")
                }
            } else {
                let accessoryView = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 20))
                accessoryView.stringValue = "\(UserDefaults.standard.diskSize)"
                
                let alert = NSAlert.okCancelAlert(messageText: "Disk Image Size in GB", informativeText: "Disk size can not be changed after VM is created. Minimum disk size is \(Constants.minimumDiskImageSize) GB, recommended is \(Constants.defaultDiskImageSize) GB or more.", accessoryView: accessoryView)
                let modalResponse = alert.runModal()
                accessoryView.becomeFirstResponder()

                if modalResponse == .OK || modalResponse == .alertFirstButtonReturn  {
                    UserDefaults.standard.diskSize = Int(accessoryView.intValue)
                } else {
                    return // cancel install
                }
                
                showSheet(restoreImageName: restoreImageName)
            }
        }
    }
    
    @objc func guestProvisioningSelected(notification: Notification) {
        if let userInfo = notification.userInfo,
           let restoreImageName = userInfo[Constants.selectedRestoreImageKey] as? String {
            if let provisioningInfoData = userInfo[Constants.provisioningInfoKey] as? Data {
                let decoder = PropertyListDecoder()
                if let provisioningInfo = try? decoder.decode(ProvisioningInfo.self, from: provisioningInfoData) {
                    self.viewModel.provisioningInfo = provisioningInfo
                    showSheet(restoreImageName: restoreImageName)
                }
            } else {
                showSheet(restoreImageName: restoreImageName)
            }
        }
    }
    
    @objc func cpuCountChanged(sender: NSSlider) {
        updateUIAndStoreParametersToDisk()
    }
    
    @objc func memorySliderChanged(sender: NSSlider) {
        updateUIAndStoreParametersToDisk()
    }
    
    @IBAction func microphoneSwitchToggled(_ sender: NSSwitch) {
        if sender.state == .on {
            viewModel.checkMicrophonePermission { [weak self] in
                DispatchQueue.main.async {
                    let alert = NSAlert.okCancelAlert(messageText: "Microphone Permission", informativeText: "Please allow microphone access in System Settings → Privacy → Camera and Microphone to use audio input in the virtual machine.", showCancelButton: false)
                    let _ = alert.runModal()
                    self?.microphoneSwitch.state = .off
                }
            }
        }
        viewModel.vmParameters?.microphoneEnabled = sender.state == .on
        viewModel.storeParametersToDisk()
    }
    
    @IBAction func networkPopUpChanged(_ sender: NSPopUpButton) {
        var networkType = NetworkType.NAT
        if sender.selectedItem?.title == NetworkType.Bridge.rawValue {
            networkType = .Bridge
        }
        
        updateBridges()
        viewModel.vmParameters?.networkType = networkType
        viewModel.storeParametersToDisk()
        updateUI()
    }
    
    @IBAction func networkBridgeInterfacePopUpChanged(_ sender: NSPopUpButton) {
        viewModel.vmParameters?.networkBridge = sender.selectedItem?.title
        viewModel.storeParametersToDisk()
    }
    
    @objc func networkBridgeInterfaceWillPopUp() {
        updateBridges()
    }
    
    @objc func updateUI() {
        self.tableView.reloadData()
        
        if let selectedRow = viewModel.selectedRow,
           selectedRow < 0,
           viewModel.tableViewDataSource.numberOfRows(in: tableView) > 0
        {
            viewModel.selectedRow = 0 // one or more vms available, select first
        }
        
        if let selectedRow = viewModel.selectedRow,
           let vmBundle = viewModel.tableViewDataSource.vmBundle(forRow: selectedRow)
        {
            vmNameTextField.stringValue = vmBundle.name
            tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
            viewModel.vmBundle = vmBundle
            if let vmParameters = VMParameters.readFrom(url: vmBundle.url) {
                viewModel.vmParameters = vmParameters
                if vmParameters.installFinished == true {
                    viewModel.textFieldDelegate.vmBundle = vmBundle
                    updateLabels(setZero: false)
                    updateCpuCount(vmParameters)
                    updateRam(vmParameters)
                    updateNetwork(vmParameters)
                    updateEnabledState(enabled: true, vmParameters: vmParameters)
                    autostartSwitch.state = UserDefaults.standard.autostartVMBundlePath == vmBundle.url.path ? .on : .off
                    windowController?.updateButtons(hidden: false)
                    windowController?.startButton.isEnabled = !activeVMBundleURLs.contains(vmBundle.url)
                    if #available(macOS 27.0, *) {
                        // Keep this enabled for legacy disks so the user sees why snapshots are unavailable.
                        windowController?.snapshotButton.isEnabled = true
                    } else {
                        windowController?.snapshotButton.isEnabled = false
                    }
                } else {
                    invalidBundleOrInstallIncomplete()
                }
            } else {
                viewModel.vmParameters = nil
                invalidBundleOrInstallIncomplete()
            }
        } else {
            vmNameTextField.stringValue = "No virtual machines available. Press install to add one."
            viewModel.vmParameters = nil
            updateLabels(setZero: true)
            updateEnabledState(enabled: false)
            autostartSwitch.state = .off
            windowController?.updateButtons(hidden: true)
        }
        
        updateBridges()
        updateOutlineView()
    }
    
    fileprivate func invalidBundleOrInstallIncomplete() {
        updateLabels(setZero: true)
        updateEnabledState(enabled: false)
        windowController?.updateButtons(hidden: false)
        windowController?.snapshotButton.isEnabled = false
        autostartSwitch.state = .off
    }
    
    fileprivate func updateBridges() {
        networkBridgePopUpButton.removeAllItems()
        var i = 0
        let selectedBridge = viewModel.vmParameters?.networkBridge
        for interface in VZBridgedNetworkInterface.networkInterfaces {
            networkBridgePopUpButton.insertItem(withTitle: interface.description, at: i)
            i += 1
            if selectedBridge == interface.description {
                networkBridgePopUpButton.selectItem(at: i)
                viewModel.vmParameters?.networkBridge = interface.description
            }
        }
        
        if networkBridgePopUpButton.selectedItem == nil {
            networkBridgePopUpButton.selectItem(at: 0)
        }
    }
    
    func showErrorAlert(error: Error) {
        var messageText = "Error"
        var informativeText = "An unknown error occurred."
        
        if let vzError = error as? VZError,
           let reason = vzError.userInfo[NSLocalizedFailureErrorKey] as? String,
           let failureReason = vzError.userInfo[NSLocalizedFailureReasonErrorKey] as? String,
           let underlyingError = vzError.userInfo[NSUnderlyingErrorKey] as? NSError
        {
            messageText = failureReason
            informativeText = reason + " " + underlyingError.localizedDescription + "\n\n(Error Code: \(vzError.errorCode), Underlying Error Domain: \(underlyingError.domain), Underlying Error Code: \(underlyingError.code))"
            if vzError.errorCode == 10007 && underlyingError.code == 3004 {
                informativeText += "\n\nYou have to be connected to the internet to start the install."
            }
        } else if let restoreError = error as? RestoreError {
            informativeText = error.localizedDescription + " " + restoreError.localizedDescription
        } else {
            informativeText = error.localizedDescription
        }

        Logger.shared.log(level: .default, "\(messageText) \(informativeText)")
        let alert = NSAlert.okCancelAlert(messageText: messageText, informativeText: informativeText, showCancelButton: false)
        let _ = alert.runModal()
    }
    
    // MARK: - Private
        
    fileprivate func updateCpuCount(_ vmParameters: VMParameters) {
        cpuCountSlider.minValue = Double(vmParameters.cpuCountMin)
        cpuCountSlider.maxValue = Double(vmParameters.cpuCountMax)
        cpuCountSlider.numberOfTickMarks = Int(cpuCountSlider.maxValue - cpuCountSlider.minValue)
        cpuCountSlider.doubleValue = Double(vmParameters.cpuCount)
        cpuCountSlider.isEnabled = true
    }
    
    fileprivate func updateRam(_ vmParameters: VMParameters) {
        ramSlider.minValue = max(Double(vmParameters.memorySizeInGBMin), 2.0)
        ramSlider.maxValue = Double(vmParameters.memorySizeInGBMax)
        ramSlider.numberOfTickMarks = Int(ramSlider.maxValue - ramSlider.minValue)
        ramSlider.doubleValue = Double(vmParameters.memorySizeInGB)
        ramSlider.isEnabled = true
    }
    
    fileprivate func updateNetwork(_ vmParameters: VMParameters) {
        switch vmParameters.networkType {
        case .NAT:
            networkPopUpButton.selectItem(at: 0)
        case .Bridge:
            networkPopUpButton.selectItem(at: 1)
        default:
            networkPopUpButton.selectItem(at: 0)
        }
        
        if vmParameters.networkType == .NAT {
            networkBridgePopUpButton.isHidden = true
        } else {
            networkBridgePopUpButton.isHidden = false
        }
    }
    
    fileprivate func updateLabels(setZero: Bool) {
        let cpuCount = Int(round(cpuCountSlider.doubleValue))
        let memorySizeInGB = Int(round(ramSlider.doubleValue))
        viewModel.vmParameters?.cpuCount = cpuCount
        viewModel.vmParameters?.memorySizeInGB = UInt64(memorySizeInGB)
        
        if setZero {
            cpuCountLabel.stringValue = "CPU Count"
            ramLabel.stringValue = "RAM"
        } else {
            cpuCountLabel.stringValue = "CPU Count: \(cpuCount)"
            ramLabel.stringValue = "RAM: \(memorySizeInGB) GB"
        }
    }
    
    fileprivate func updateOutlineView() {
        parameterOutlineView.reloadData()
    }
    
    fileprivate func updateUIAndStoreParametersToDisk() {
        viewModel.storeParametersToDisk()
        updateLabels(setZero: false)
    }
    
    fileprivate func showSheet(restoreImageName: String)  {
        if let progressWindowController = mainStoryBoard.instantiateController(withIdentifier: "ProgressWindowController") as? NSWindowController,
           let progressWindow = progressWindowController.window,
           let progressViewController = progressWindow.contentViewController as? ProgressViewController
        {
            if restoreImageName == Constants.restoreImageNameLatest {
                progressViewController.startDownload()
            } else {
                progressViewController.startInstall(restoreImageName: restoreImageName, diskImageSize: UserDefaults.standard.diskSize)
            }
            presentAsSheet(progressViewController)
        } else {
            Logger.shared.log(level: .default, "show modal failed")
        }
    }
    
    fileprivate func show(viewController: NSViewController, title: String) {
        let newWindow = NSWindow(contentViewController: viewController)
        newWindow.title = title
        newWindow.makeKeyAndOrderFront(nil)
        if let parentFrame = view.window?.frame {
            newWindow.setFrame(parentFrame.offsetBy(dx: 90, dy: -10), display: true)
        }
    }
    
    fileprivate func startVM() {
        guard let vmBundle = viewModel.vmBundle,
              !activeVMBundleURLs.contains(vmBundle.url) else
        {
            return
        }
        if let vmViewController = mainStoryBoard.instantiateController(withIdentifier: "VMViewController") as? VMViewController
        {
            activeVMBundleURLs.insert(vmBundle.url)
            windowController?.startButton.isEnabled = false
            vmViewController.vmBundle = vmBundle
            vmViewController.vmParameters = viewModel.vmParameters
            vmViewController.provisioningInfo = viewModel.provisioningInfo
            viewModel.provisioningInfo = nil
            vmViewController.didClose = { [weak self] in
                self?.activeVMBundleURLs.remove(vmBundle.url)
                self?.updateUI()
            }
            show(viewController: vmViewController, title: vmBundle.name)
        } else {
            Logger.shared.log(level: .default, "show vm window failed")
        }
    }

    fileprivate func startAutostartVMIfNeeded() {
        guard !didAttemptAutostart else { return }
        didAttemptAutostart = true
        guard let autostartPath = UserDefaults.standard.autostartVMBundlePath else { return }

        let rowCount = viewModel.tableViewDataSource.rows()
        for row in 0..<rowCount {
            guard let vmBundle = viewModel.tableViewDataSource.vmBundle(forRow: row) else { continue }
            if vmBundle.url.path == autostartPath {
                guard VMParameters.readFrom(url: vmBundle.url)?.installFinished == true else { return }
                viewModel.selectedRow = row
                updateUI()
                Logger.shared.log(level: .default, "Autostarting VM \(vmBundle.name, privacy: .public)")
                startVM()
                return
            }
        }

        UserDefaults.standard.autostartVMBundlePath = nil
    }
    
}

extension MainViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        var row: Int? = nil
        
        if let userInfo = notification.userInfo,
           let indexSet = userInfo["NSTableViewCurrentRowSelectionUserInfoKey"] as? NSIndexSet {
            if indexSet.count > 0 {
                row = indexSet.firstIndex
            }
        }
        
        if let row  = row {
            viewModel.selectedRow = row
            updateUI()
        }
    }
}

extension MainViewController: NSWindowDelegate  {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let alert: NSAlert = NSAlert.okCancelAlert(messageText: "Quit", informativeText: "Quitting the app will stop all virtual machines.", alertStyle: .warning)
        let selection = alert.runModal()
        if selection == NSApplication.ModalResponse.alertFirstButtonReturn ||
            selection == NSApplication.ModalResponse.OK
        {
            NSApplication.shared.terminate(self)
            return true
        } else {
            return false
        }
    }
}

#else

// minimum implementation used for intel cpus

final class MainViewController: MainViewControllerBase {
    override func viewWillAppear() {
        super.viewWillAppear()
        vmNameTextField.stringValue = "Virtualization requires an Apple Silicon machine"
        vmNameTextField.isEditable = false
        cpuCountSlider.isEnabled = false
        ramSlider.isEnabled = false
        microphoneSwitch.isEnabled = false
        networkPopUpButton.isEnabled = false
        networkBridgePopUpButton.isEnabled = false
        cpuCountLabel.stringValue = ""
        ramLabel.stringValue = ""
    }
}

#endif

// place all code before #else
