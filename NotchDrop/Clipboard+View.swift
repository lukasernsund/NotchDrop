import SwiftUI
import ColorfulX

struct ClipboardView: View {
    @StateObject var vm: NotchViewModel
    @StateObject var cvm = Clipboard.shared

    var storageTime: String {
        switch cvm.selectedFileStorageTime {
        case .oneHour:
            return NSLocalizedString("an hour", comment: "")
        case .oneDay:
            return NSLocalizedString("a day", comment: "")
        case .twoDays:
            return NSLocalizedString("two days", comment: "")
        case .threeDays:
            return NSLocalizedString("three days", comment: "")
        case .oneWeek:
            return NSLocalizedString("a week", comment: "")
        case .never:
            return NSLocalizedString("forever", comment: "")
        case .custom:
            let localizedTimeUnit = NSLocalizedString(cvm.customStorageTimeUnit.localized.lowercased(), comment: "")
            return "\(cvm.customStorageTime) \(localizedTimeUnit)"
        }
    }

    var body: some View {
        panel
    }

    var panel: some View {
        ZStack {
            ColorfulView(
                color: .constant(ColorfulPreset.starry.colors),
                speed: .constant(0.5),
                transitionSpeed: .constant(25)
            )
            .opacity(0.5)
            .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius))

            RoundedRectangle(cornerRadius: vm.cornerRadius)
                .foregroundStyle(.white.opacity(0.1))
                .overlay {
                    content
                        .padding()
                }
        }
        .animation(vm.animation, value: cvm.items)
        .animation(vm.animation, value: cvm.isLoading)
    }

    var text: String {
        [
            String(
                format: NSLocalizedString("Copied items are kept for %@", comment: ""),
                storageTime
            ),
            "&",
            NSLocalizedString("Press Option to delete", comment: ""),
        ].joined(separator: " ")
    }

    var content: some View {
        Group {
            if cvm.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                    Text(text)
                        .multilineTextAlignment(.center)
                        .font(.system(.headline, design: .rounded))
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: vm.spacing) {
                        ForEach(cvm.items) { item in
                            ClipboardItemView(item: item, vm: vm, cvm: cvm)
                        }
                    }
                    .padding(vm.spacing)
                }
                .padding(-vm.spacing)
                .scrollIndicators(.never)
            }
        }
    }
}

#Preview {
    ClipboardView(vm: .init())
        .padding()
        .frame(width: 550, height: 150, alignment: .center)
        .background(.black)
        .preferredColorScheme(.dark)
}