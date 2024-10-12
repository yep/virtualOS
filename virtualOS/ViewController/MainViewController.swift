//
//  ViewController.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//

import Cocoa
import Virtualization
import OSLog

#if arch(arm64)

final class MainViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var vmNameTextField: NSTextField!
    @IBOutlet weak var parameterOutlinew: NSOutlineView!
    @IBOutlet weak var startButton: NSButton!
    @IBOutlet weak var sharedFolderButton: NSButton!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var cpuCountLabel: NSTextField!
    @IBOutlet weak var cpuCountSlider: NSSlider!
    @IBOutlet weak var ramLabel: NSTextField!
    @IBOutlet weak var ramSlider: NSSlider!
    
    fileprivate let mainStoryBoard = NSStoryboard(name: "Main", bundle: nil)
    fileprivate let viewModel = MainViewModel()
    fileprivate let logger = Logger()
    fileprivate var diskImageSize = 1

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource         = viewModel.tableViewDataSource
        tableView.delegate           = self
        parameterOutlinew.dataSource = viewModel.parametersViewDataSource
        parameterOutlinew.delegate   = viewModel.parametersViewDelegate
        vmNameTextField.delegate     = viewModel.textFieldDelegate
        
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: NSApplication.didBecomeActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(textDidEndEditing), name: NSControl.textDidEndEditingNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(restoreImageSelected), name: Constants.restoreImageNameSelectedNotification, object: nil)

        ramSlider.target = self
        ramSlider.action = #selector(memorySliderChanged(sender:))
        cpuCountSlider.target = self
        cpuCountSlider.action = #selector(cpuCountChanged(sender:))
    }
    
    @objc func didBecomeActive(notification: Notification) {
        self.tableView.reloadData()
        self.updateUI()
    }
    
    @objc func textDidEndEditing(notification: Notification) {
        self.tableView.reloadData()
        self.updateUI()
    }
    
    @objc func restoreImageSelected(notification: Notification) {
        if let userInfo = notification.userInfo,
           let restoreImageName = userInfo[Constants.selectedRestoreImage] as? String
        {
            if restoreImageName != Constants.restoreImageNameLatest {
                let accessory = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 20))
                accessory.stringValue = "\(UserDefaults.standard.diskSize)"
                
                let alert: NSAlert = NSAlert()
                alert.messageText = "Disk Image Size in GB"
                alert.informativeText = "Disk size can not be changed after VM is created."
                alert.accessoryView = accessory
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Cancel")
                            
                let modalResponse = alert.runModal()
                accessory.becomeFirstResponder()

                if modalResponse == .OK || modalResponse == .alertFirstButtonReturn  {
                    diskImageSize = Int(accessory.intValue)
                } else {
                    return // cancel install
                }
                if diskImageSize < 30 {
                    self.diskImageSize = 30
                }
            }
            
            showSheet(mode: .install, restoreImageName: restoreImageName, diskImageSize: self.diskImageSize)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        vmNameTextField.resignFirstResponder()
        tableView.reloadData()
        self.updateUI()
    }
    
    @IBAction func startButtonPressed(_ sender: NSButton) {
        if let vmViewController = mainStoryBoard.instantiateController(withIdentifier: "VMViewController") as? VMViewController,
           let windowController = mainStoryBoard.instantiateController(withIdentifier: "NSWindowController") as? NSWindowController
        {
            vmViewController.vmBundle = viewModel.vmBundle
            vmViewController.vmParameters = viewModel.vmParameters
            windowController.showWindow(self)
            windowController.contentViewController = vmViewController
        } else {
            logger.log(level: .default, "show window failed")
        }
    }
    
    @IBAction func installButtonPressed(_ sender: NSButton) {
        if let restoreImageViewController = mainStoryBoard.instantiateController(withIdentifier: "RestoreImageViewController") as? RestoreImageViewController,
           let windowController = mainStoryBoard.instantiateController(withIdentifier: "NSWindowController") as? NSWindowController
        {
            windowController.showWindow(self)
            windowController.contentViewController = restoreImageViewController
        }
    }
    
    @IBAction func deleteButtonPressed(_ sender: Any) {
        guard let vmBundle = viewModel.vmBundle else {
            return
        }
        
        let alert: NSAlert = NSAlert()
        alert.messageText = "Delete VM \(vmBundle.name)?"
        alert.informativeText = "This can not be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let selection = alert.runModal()
        if selection == NSApplication.ModalResponse.alertFirstButtonReturn ||
           selection == NSApplication.ModalResponse.OK
        {
            viewModel.deleteVM(selection: selection, vmBundle: vmBundle)
            viewModel.vmBundle = nil
        }
        tableView.reloadData()
        self.updateUI()
    }
        
    @IBAction func sharedFolderButtonPressed(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.prompt = "Select"
        let modalResponse = openPanel.runModal()
        var sharedFolderURL: URL?
        if modalResponse == .OK,
           let selectedURL = openPanel.url
        {
            sharedFolderURL = selectedURL
        } else if modalResponse == .cancel {
            sharedFolderURL = nil
        }
        if let vmParameters = viewModel.set(sharedFolderUrl: sharedFolderURL) {
            viewModel.parametersViewDataSource.vmParameters = vmParameters
            parameterOutlinew.reloadData()
        }
    }
    
    @IBAction func usbButtonPressed(_ sender: NSButtonCell) {
        print("usb")
    }

    @objc func cpuCountChanged(sender: NSSlider) {
        updateLabels()
        viewModel.storeParametersToDisk()
    }
    
    @objc func memorySliderChanged(sender: NSSlider) {
        updateLabels()
        viewModel.storeParametersToDisk()
    }
        
    func updateUI() {
        cpuCountSlider.isEnabled = false
        ramSlider.isEnabled = false
        
        if let selectedRow = viewModel.selectedRow,
           let vmBundle = viewModel.tableViewDataSource.vmBundle(forRow: selectedRow)
        {
            vmNameTextField.stringValue = vmBundle.name
            tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
            viewModel.vmBundle = vmBundle
            if let vmParameters = VMParameters.readFrom(url: vmBundle.url) {
                viewModel.vmParameters = vmParameters
                viewModel.parametersViewDataSource.vmParameters = viewModel.vmParameters
                parameterOutlinew.reloadData()
                viewModel.textFieldDelegate.vmBundle = vmBundle
                updateCpuCount(vmParameters)
                updateRam(vmParameters)
                updateLabels()
                updateButtons(enabled: true)
            }
        } else {
            vmNameTextField.stringValue = ""
            viewModel.parametersViewDataSource.vmParameters = nil
            viewModel.selectedRow = 0
            updateLabels(setZero: true)
            updateButtons(enabled: false)
        }
        tableView.reloadData()
    }
    
    fileprivate func updateButtons(enabled: Bool) {
        startButton.isEnabled = enabled
        sharedFolderButton.isEnabled = enabled
        deleteButton.isEnabled = enabled
        vmNameTextField.isEnabled = enabled
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
    
    fileprivate func updateLabels(setZero: Bool = false) {
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
        
        viewModel.parametersViewDataSource.vmParameters = viewModel.vmParameters
        parameterOutlinew.reloadData()
    }
    
    // MARK: - Private
    
    fileprivate func showSheet(mode: ProgressViewController.Mode, restoreImageName: String?, diskImageSize: Int?)  {
        if let progressWindowController = mainStoryBoard.instantiateController(withIdentifier: "ProgressWindowController") as? NSWindowController,
           let progressWindow = progressWindowController.window
        {
            if let progressViewController = progressWindow.contentViewController as? ProgressViewController {
                progressViewController.mode = mode
                progressViewController.diskImageSize = diskImageSize
                progressViewController.restoreImageName = restoreImageName
                presentAsSheet(progressViewController)
            }
        } else {
            logger.log(level: .default, "show modal failed")
        }
    }
    
    fileprivate func updateButtonEnabledState() {
        var enabled = false
        if viewModel.selectedRow != nil {
            enabled = true
        }
        vmNameTextField.isEnabled    = enabled
        startButton.isEnabled        = enabled
        sharedFolderButton.isEnabled = enabled
        deleteButton.isEnabled       = enabled
        ramSlider.isEnabled          = enabled
        cpuCountSlider.isEnabled     = enabled
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
            updateButtonEnabledState()
        }
    }
}

#else

// minimum implementation used for intel cpus

final class MainViewController: NSViewController {
    @IBOutlet weak var vmNameTextField: NSTextField!
    @IBOutlet weak var installButton: NSButton!
    @IBOutlet weak var startButton: NSButton!
    @IBOutlet weak var sharedFolderButton: NSButton!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var cpuCountLabel: NSTextField!
    @IBOutlet weak var cpuCountSlider: NSSlider!
    @IBOutlet weak var ramLabel: NSTextField!
    @IBOutlet weak var ramSlider: NSSlider!

    override func viewWillAppear() {
        super.viewWillAppear()
        vmNameTextField.stringValue = "Virtualization requires an Apple Silicon machine"
        vmNameTextField.isEditable = false
        installButton.isEnabled = false
        startButton.isEnabled = false
        sharedFolderButton.isEnabled = false
        deleteButton.isEnabled = false
        cpuCountSlider.isEnabled = false
        ramSlider.isEnabled = false
        cpuCountLabel.stringValue = ""
        ramLabel.stringValue = ""
    }
}

#endif

// place all code before #else
