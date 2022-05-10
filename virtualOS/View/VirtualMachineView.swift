//
//  VirtualMachineView.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 16.03.22.
//

import SwiftUI
import Virtualization

struct VirtualMachineView: NSViewRepresentable {
    @Binding var virtualMachine: VZVirtualMachine?

    func makeNSView(context: Context) -> VZVirtualMachineView {
        let view = VZVirtualMachineView()
        view.capturesSystemKeys = true
        return view
    }

    func updateNSView(_ nsView: VZVirtualMachineView, context: Context) {
        nsView.virtualMachine = virtualMachine
        nsView.window?.makeFirstResponder(nsView)
    }
}
