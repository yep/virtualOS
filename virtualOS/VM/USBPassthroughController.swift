//
//  USBPassthroughController.swift
//  virtualOS
//
//  Created by Jahn Bertsch.
//  Licensed under the Apache License, see LICENSE file.
//

import AccessoryAccess
import Virtualization

@available(macOS 27.0, *)
final class USBPassthroughController: NSObject {
    private weak var virtualMachine: VZVirtualMachine?
    private weak var usbMenu: NSMenu?
    private let queue: DispatchQueue
    private let ownerID: String
    private let ownerName: String
    private let isWindowKey: () -> Bool
    private var accessories = [UInt64: AAUSBAccessory]()
    private var devices = [UInt64: VZUSBPassthroughDevice]()
    private var isRunning = false
    private var isListening = false
    private var isActiveWindow = false
    private var isDetecting = false

    init(virtualMachine: VZVirtualMachine, queue: DispatchQueue, ownerID: String, ownerName: String, isWindowKey: @escaping () -> Bool) {
        self.virtualMachine = virtualMachine
        self.queue = queue
        self.ownerID = ownerID
        self.ownerName = ownerName
        self.isWindowKey = isWindowKey
    }

    func start() {
        let start = { [weak self] in
            guard let self, !self.isListening else { return }
            self.isDetecting = true
            self.rebuildMenu()
            self.isListening = true

            Task { [weak self] in
                guard let self else { return }
                do {
                    let accessories = try await AAUSBAccessoryManager.shared.registerListener(self, matchingCriteria: [])
                    DispatchQueue.main.async {
                        self.isDetecting = false
                        for accessory in accessories {
                            self.usbAccessoryDidConnect(accessory)
                        }
                        self.rebuildMenu()
                    }
                } catch {
                    await MainActor.run {
                        self.isListening = false
                        self.isDetecting = false
                        let nsError = error as NSError
                        self.presentError(messageText: "USB Device Detection Failed", informativeText: "\(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)")
                        self.rebuildMenu()
                    }
                }
            }
        }
        if Thread.isMainThread {
            start()
        } else {
            DispatchQueue.main.async(execute: start)
        }
    }

    private func presentError(messageText: String, informativeText: String) {
        let present = {
            let alert = NSAlert()
            alert.messageText = messageText
            alert.informativeText = informativeText
            alert.alertStyle = .warning
            alert.runModal()
        }
        if Thread.isMainThread {
            present()
        } else {
            DispatchQueue.main.async(execute: present)
        }
    }

    func stop() {
        let release = { [weak self] in
            guard let self else { return }
            self.isRunning = false
            USBPassthroughOwnership.releaseAll(ownerID: self.ownerID)
            self.devices.removeAll()
            self.rebuildMenu()
        }
        if Thread.isMainThread {
            release()
        } else {
            DispatchQueue.main.async(execute: release)
        }
    }

    func virtualMachineStarted() {
        let update = { [weak self] in
            guard let self else { return }
            self.isRunning = true
            self.rebuildMenu()
        }
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    func close() {
        stop()
        guard isListening else { return }
        isListening = false
        Task {
            await AAUSBAccessoryManager.shared.unregisterListener(self)
        }
    }

    func activate(menu: NSMenu?) {
        usbMenu = menu
        usbMenu?.delegate = self
        isActiveWindow = true
        rebuildMenu()
    }

    func deactivate() {
        isActiveWindow = false
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let usbMenu else { return }

        usbMenu.removeAllItems()

        guard isActiveWindow && isWindowKey() else {
            usbMenu.addDisabledItem(title: "Select a VM window")
            return
        }
        if isDetecting {
            usbMenu.addDisabledItem(title: "Detecting USB devices…")
            return
        }
        guard !accessories.isEmpty else {
            usbMenu.addDisabledItem(title: isRunning ? "No USB devices detected" : "Start VM for USB device discovery")
            return
        }

        for identifier in accessories.keys.sorted() {
            let title = "\(deviceCategory(for: accessories[identifier]!)) 0x\(String(identifier, radix: 16))"
            let item = NSMenuItem(title: title, action: #selector(toggleDevice(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: identifier)

            if devices[identifier] != nil {
                item.title = "Detach \(title)"
            } else if let ownerName = USBPassthroughOwnership.ownerName(for: identifier) {
                item.title = "\(title) (Used by \(ownerName))"
                item.isEnabled = false
            } else if !isRunning {
                item.title = "\(title) (VM is stopped)"
                item.isEnabled = false
            } else {
                item.title = "Attach \(title)"
            }
            usbMenu.addItem(item)
        }
    }

    @objc private func toggleDevice(_ sender: NSMenuItem) {
        guard let identifier = (sender.representedObject as? NSNumber)?.uint64Value else { return }
        if devices[identifier] != nil {
            detachDevice(identifier: identifier)
        } else {
            attachDevice(identifier: identifier)
        }
    }

    private func attachDevice(identifier: UInt64) {
        guard let accessory = accessories[identifier] else { return }
        if let ownerName = USBPassthroughOwnership.claim(identifier: identifier, ownerID: ownerID, ownerName: ownerName) {
            presentError(messageText: "USB Device In Use", informativeText: "This device is already in use by \(ownerName).")
            rebuildMenu()
            return
        }

        queue.async { [weak self] in
            guard let self else { return }
            do {
                let device = try VZUSBPassthroughDevice(configuration: VZUSBPassthroughDeviceConfiguration(device: accessory))
                guard let controller = self.virtualMachine?.usbControllers.first else {
                    USBPassthroughOwnership.release(identifier: identifier, ownerID: self.ownerID)
                    self.presentError(messageText: "USB Controller Unavailable", informativeText: "The VM has no USB controller.")
                    return
                }
                controller.attach(device: device) { [weak self] error in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        if let error {
                            USBPassthroughOwnership.release(identifier: identifier, ownerID: self.ownerID)
                            self.presentError(messageText: "Attaching USB Device Failed", informativeText: error.localizedDescription)
                        } else {
                            self.devices[identifier] = device
                        }
                        self.rebuildMenu()
                    }
                }
            } catch {
                USBPassthroughOwnership.release(identifier: identifier, ownerID: self.ownerID)
                self.presentError(messageText: "Creating USB Device Failed", informativeText: error.localizedDescription)
            }
        }
    }

    private func detachDevice(identifier: UInt64) {
        guard let device = devices[identifier], let controller = virtualMachine?.usbControllers.first else { return }
        if let accessory = accessories[identifier], deviceCategory(for: accessory) == "USB Mass Storage" {
            let alert = NSAlert.okCancelAlert(
                messageText: "Detach USB Mass Storage",
                informativeText: "Are you sure you want to detach the device?\nBe sure to unmount the disk in the VM first.",
                alertStyle: .warning
            )
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        queue.async { [weak self] in
            controller.detach(device: device) { error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let error {
                        self.presentError(messageText: "Detaching USB Device Failed", informativeText: error.localizedDescription)
                    } else {
                        self.devices.removeValue(forKey: identifier)
                        USBPassthroughOwnership.release(identifier: identifier, ownerID: self.ownerID)
                    }
                    self.rebuildMenu()
                }
            }
        }
    }

    private func deviceCategory(for accessory: AAUSBAccessory) -> String {
        let deviceDescriptor = [UInt8](accessory.deviceDescriptorData)
        if deviceDescriptor.count > 4, deviceDescriptor[4] != 0 {
            return categoryName(for: deviceDescriptor[4])
        }

        guard let configurationDescriptorData = accessory.configurationDescriptorData else {
            return "USB Device"
        }
        let configurationDescriptorBytes = [UInt8](configurationDescriptorData)
        var offset = 0
        while offset < configurationDescriptorBytes.count {
            let remainingBytes = configurationDescriptorBytes.count - offset
            guard remainingBytes >= 2 else { break }
            let length = Int(configurationDescriptorBytes[offset])
            guard length >= 2, length <= remainingBytes else { break }

            // descriptor type 4 is an interface descriptor, whose class field is byte 5
            if configurationDescriptorBytes[offset + 1] == 4, length >= 9 {
                let interfaceClass = configurationDescriptorBytes[offset + 5]
                if interfaceClass != 0 {
                    return categoryName(for: interfaceClass)
                }
            }
            offset += length
        }
        return "USB Device"
    }

    private func categoryName(for usbClass: UInt8) -> String {
        switch usbClass {
        case 0x01: return "USB Audio"
        case 0x02, 0x0A: return "USB Network Device"
        case 0x03: return "USB HID Device"
        case 0x05: return "USB Physical Interface Device"
        case 0x06: return "USB Imaging Device"
        case 0x07: return "USB Printer"
        case 0x08: return "USB Mass Storage"
        case 0x09: return "USB Hub"
        case 0x0B: return "USB Smart Card Reader"
        case 0x0D: return "USB Content Security Device"
        case 0x0E: return "USB Camera"
        case 0x0F: return "USB Healthcare Device"
        case 0x10: return "USB Audio/Video Device"
        case 0x11: return "USB Billboard Device"
        case 0x12: return "USB Type-C Bridge"
        case 0xDC: return "USB Diagnostic Device"
        case 0xE0: return "USB Wireless Device"
        case 0xEF: return "USB Miscellaneous Device"
        case 0xFE: return "USB Application-Specific Device"
        case 0xFF: return "USB Vendor-Specific Device"
        default: return "USB Device"
        }
    }
}

@available(macOS 27.0, *)
extension USBPassthroughController: AAUSBAccessoryListener {
    func usbAccessoryDidConnect(_ usbAccessory: AAUSBAccessory) {
        DispatchQueue.main.async { [weak self] in
            self?.accessories[usbAccessory.registryID] = usbAccessory
            self?.rebuildMenu()
        }
    }

    func usbAccessoryDidDisconnect(_ usbAccessory: AAUSBAccessory) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let identifier = usbAccessory.registryID
            self.accessories.removeValue(forKey: identifier)
            self.devices.removeValue(forKey: identifier)
            USBPassthroughOwnership.release(identifier: identifier, ownerID: self.ownerID)
            self.rebuildMenu()
        }
    }
}

@available(macOS 27.0, *)
extension USBPassthroughController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }
}

@available(macOS 27.0, *)
private enum USBPassthroughOwnership {
    private static let lock = NSLock()
    private static var owners = [UInt64: (id: String, name: String)]()

    static func ownerName(for identifier: UInt64) -> String? {
        lock.withLock { owners[identifier]?.name }
    }

    static func claim(identifier: UInt64, ownerID: String, ownerName: String) -> String? {
        lock.withLock {
            if let owner = owners[identifier] {
                return owner.name
            }
            owners[identifier] = (ownerID, ownerName)
            return nil
        }
    }

    static func release(identifier: UInt64, ownerID: String) {
        lock.withLock {
            guard owners[identifier]?.id == ownerID else { return }
            owners.removeValue(forKey: identifier)
        }
    }

    static func releaseAll(ownerID: String) {
        lock.withLock {
            owners = owners.filter { $0.value.id != ownerID }
        }
    }
}

private extension NSMenu {
    func addDisabledItem(title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        addItem(item)
    }
}
