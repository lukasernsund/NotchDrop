//
//  NotchContentView.swift
//  NotchDrop
//
//  Created by 秋星桥 on 2024/7/7.
//

import ColorfulX
import SwiftUI
import UniformTypeIdentifiers

struct NotchContentView: View {
    @StateObject var vm: NotchViewModel
    @StateObject var cvm = Clipboard.shared

    var body: some View {
        ZStack {
            Group {
                if vm.contentType == .drop {
                    dropView
                } else if vm.contentType == .clipboard {
                    ClipboardView(vm: vm, cvm: Clipboard.shared)
                        .frame(height: .infinity) // Ensure it uses the full height
                } else if vm.contentType == .menu {
                    NotchMenuView(vm: vm)
                } else if vm.contentType == .settings {
                    NotchSettingsView(vm: vm)
                }
            }
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
        .animation(vm.animation, value: vm.contentType)
    }
    
    private var dropView: some View {
        HStack(spacing: vm.spacing) {
            AirDropView(vm: vm)
            TrayView(vm: vm)
        }
    }
}

#Preview {
    NotchContentView(vm: .init())
        .padding()
        .frame(width: 600, height: 150, alignment: .center)
        .background(.black)
        .preferredColorScheme(.dark)
}
