//
//  NotchHeaderView.swift
//  NotchDrop
//
//  Created by 秋星桥 on 2024/7/7.
//

import ColorfulX
import SwiftUI

struct NotchHeaderView: View {
    @StateObject var vm: NotchViewModel

    var body: some View {
        HStack {
            Button(action: {
                            vm.switchPage(to: .drop)
                        }) {
                            Text("Drop")
                                .foregroundColor(vm.contentType == .drop ? .primary : .secondary)
                        }
                        Button(action: {
                            vm.switchPage(to: .clipboard)
                        }) {
                            Text("Clipboard")
                                .foregroundColor(vm.contentType == .clipboard ? .primary : .secondary)
                        }
                        Spacer()
                        Image(systemName: "ellipsis")
                            .onTapGesture {
                                vm.contentType = .menu
                            }
        }
        .animation(vm.animation, value: vm.contentType)
        .font(.system(.headline, design: .rounded))
    }
}

#Preview {
    NotchHeaderView(vm: .init())
}
