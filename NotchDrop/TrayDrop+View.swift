import SwiftUI
import ColorfulX
import UniformTypeIdentifiers

struct TrayView: View {
    @StateObject var vm: NotchViewModel
    @StateObject var tvm = TrayDrop.shared

    @State private var targeting = false

    var storageTime: String {
        switch tvm.selectedFileStorageTime {
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
            let localizedTimeUnit = NSLocalizedString(tvm.customStorageTimeUnit.localized.lowercased(), comment: "")
            return "\(tvm.customStorageTime) \(localizedTimeUnit)"
        }
    }

    var body: some View {
        panel
            .onDrop(of: [.data, .text], isTargeted: $targeting) { providers in
                DispatchQueue.global().async {
                    handleDrop(providers)
                }
                return true
            }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                        let tempFile = saveTextToTempFile(string)
                        tvm.load([NSItemProvider(contentsOf: tempFile)].compactMap { $0 })
                    }
                }
            } else {
                tvm.load([provider])
            }
        }
    }

    private func saveTextToTempFile(_ text: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "temp_text_\(UUID().uuidString).txt"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving text to temp file: \(error)")
            return fileURL // Return the URL even if writing failed
        }
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
        .animation(vm.animation, value: tvm.items)
        .animation(vm.animation, value: tvm.isLoading)
    }

    var content: some View {
        Group {
            if tvm.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down.fill")

                    Text(NSLocalizedString("Drag files here to keep them for", comment: "") + " " + storageTime + " " + NSLocalizedString("& Press Option to delete", comment: ""))
                        .font(.system(.headline, design: .rounded))
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: vm.spacing) {
                        ForEach(tvm.items) { item in
                            DropItemView(item: item, vm: vm, tvm: tvm)
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
    NotchContentView(vm: .init())
        .padding()
        .frame(width: 550, height: 150, alignment: .center)
        .background(.black)
        .preferredColorScheme(.dark)
}
