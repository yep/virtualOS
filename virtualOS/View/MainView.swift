//
//  MainView.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 16.03.22.
//

#if arch(arm64)

import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Text(viewModel.statusLabel)
                Spacer()
                Button {
                    viewModel.buttonPressed()
                } label: {
                    Text(viewModel.buttonLabel)
                }.disabled(viewModel.buttonDisabled)
            }.padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))

            if viewModel.showConfigurationView {
                ConfigurationView(viewModel: viewModel)
            } else if viewModel.showSettingsInfo {
                VStack {
                    Spacer()
                    Button("Open Settings") {
                        viewModel.showSettings = !viewModel.showSettings
                    }
                    Text("Open settings for basic virtual machine configuration, then press Start to install.")
                        .lineLimit(nil)
                        .font(.caption)
                    Spacer()
                }
            } else {
                VirtualMachineView(virtualMachine: $viewModel.virtualMachine)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(viewModel: MainViewModel())
    }
}

#endif
