import ColorfulX
import SwiftUI

struct NotchHeaderView: View {
    @StateObject var vm: NotchViewModel

    var body: some View {
        HStack {
            ToggleButton(title: "Drop", isSelected: vm.contentType == .drop) {
                vm.switchPage(to: .drop)
            }
            ToggleButton(title: "Clipboard", isSelected: vm.contentType == .clipboard) {
                vm.switchPage(to: .clipboard)
            }
            Spacer()
            Button(action: {
                vm.switchPage(to: .settings)
            }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 8)
            Button(action: {
                vm.contentType = .menu
            }) {
                Image(systemName: "ellipsis")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .animation(vm.animation, value: vm.contentType)
        .font(.system(.headline, design: .rounded))
    }
}

struct ToggleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(isSelected ? Color.primary.opacity(0.1) : Color.clear)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NotchHeaderView(vm: .init())
}
