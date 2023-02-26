//
//  ConfigurationView.swift
//  virtualOS
//
//  Created by Jahn Bertsch on 03.04.22.
//

#if arch(arm64)

import SwiftUI

struct ConfigurationView: View {
    @ObservedObject var viewModel: MainViewModel
    fileprivate let sliderTextWidth = CGFloat(150)
    @State fileprivate var cpuCountSliderValue: Float = 0 {
        didSet {
            viewModel.virtualMac.parameters.cpuCount = Int(cpuCountSliderValue)
        }
    }
    @State fileprivate var memorySliderValue: Float = 0 {
        didSet {
            viewModel.virtualMac.parameters.memorySizeInGB = UInt64(memorySliderValue)
        }
    }
    @State fileprivate var screenWidthValue: Float = 0 {
        didSet {
            viewModel.virtualMac.parameters.screenWidth = Int(screenWidthValue)
        }
    }
    @State fileprivate var screenHeightValue: Float = 0 {
        didSet {
            viewModel.virtualMac.parameters.screenHeight = Int(screenHeightValue)
        }
    }
    @State fileprivate var useCustomScreenSize = true
    @State fileprivate var useMainScreenSize = false

    var body: some View {
        VStack {
            Spacer()
            VStack {
                let parameters = viewModel.virtualMac.parameters
                Text("Virtual Machine Configuration").font(.title)

                Slider(value: Binding(get: {
                    cpuCountSliderValue
                }, set: { (newValue) in
                    cpuCountSliderValue = newValue
                }), in: Float(parameters.cpuCountMin) ... Float(parameters.cpuCountMax), step: 1) {
                    Text("CPU Count: \(viewModel.virtualMac.parameters.cpuCount)")
                        .frame(minWidth: sliderTextWidth, alignment: .leading)
                }

                Slider(value: Binding(get: {
                    memorySliderValue
                }, set: { (newValue) in
                    memorySliderValue = newValue
                }), in: Float(parameters.memorySizeInGBMin) ... Float(parameters.memorySizeInGBMax), step: 1) {
                    Text("RAM: \(viewModel.virtualMac.parameters.memorySizeInGB) GB")
                        .frame(minWidth: sliderTextWidth, alignment: .leading)
                }
                 
                HStack() {
                    Text("Screen Size:")
                    Spacer()
                    Toggle("Custom", isOn: $useCustomScreenSize).onChange(of: useCustomScreenSize) { newValue in
                        useMainScreenSize = !newValue
                    }
                    Toggle("Main Screen", isOn: $useMainScreenSize).onChange(of: useMainScreenSize) { newValue in
                        useCustomScreenSize = !newValue
                        viewModel.virtualMac.parameters.useMainScreenSize = newValue
                        if let mainScreen = NSScreen.main {
                            screenWidthValue  = Float(mainScreen.frame.width)
                            screenHeightValue = Float(mainScreen.frame.height)
                        }
                    }
                }

                Slider(value: Binding(get: {
                    screenWidthValue
                }, set: { (newValue) in
                    screenWidthValue = newValue
                }), in: 800 ... Float(NSScreen.main?.frame.width ?? CGFloat(parameters.screenWidth)), step: 100) {
                    Text("Screen Width: \(viewModel.virtualMac.parameters.screenWidth) px")
                        .frame(minWidth: sliderTextWidth, alignment: .leading)
                }.disabled(useMainScreenSize)

                Slider(value: Binding(get: {
                    screenHeightValue
                }, set: { (newValue) in
                    screenHeightValue = newValue
                }), in: 600 ... Float(NSScreen.main?.frame.height ?? CGFloat(parameters.screenHeight)), step: 50) {
                    Text("Screen Height: \(viewModel.virtualMac.parameters.screenHeight) px")
                        .frame(minWidth: sliderTextWidth, alignment: .leading)
                }.disabled(useMainScreenSize)
            }
            .padding()
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                .stroke(.tertiary, lineWidth: 1)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: 400)
        .onAppear {
            let parameters = viewModel.virtualMac.parameters
            cpuCountSliderValue     = Float(parameters.cpuCount)
            memorySliderValue       = Float(parameters.memorySizeInGB)
            useMainScreenSize          = parameters.useMainScreenSize
            screenWidthValue        = Float(parameters.screenWidth)
            screenHeightValue       = Float(parameters.screenHeight)
        }
    }
}

struct ConfigurationViewProvider_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ConfigurationView(viewModel: MainViewModel())
        }
    }
}

#endif
