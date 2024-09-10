import SwiftUI
import ColorfulX
import UniformTypeIdentifiers

struct ClipboardView: View {
    @StateObject var vm: NotchViewModel
    @StateObject var cvm = Clipboard.shared
    @State private var searchText = ""

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

    var filteredItems: [Clipboard.ClipboardItem] {
        if searchText.isEmpty {
            return Array(cvm.items)
        } else {
            return cvm.items.filter { item in
                item.fileName.localizedCaseInsensitiveContains(searchText) ||
                item.previewText.localizedCaseInsensitiveContains(searchText)
            }
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
        VStack {
            searchBar
            if filteredItems.isEmpty {
                emptyView
            } else {
                itemList
            }
        }
    }

    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.bottom, 8)
    }

    var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
            Text(text)
                .multilineTextAlignment(.center)
                .font(.system(.headline, design: .rounded))
        }
    }

    var itemList: some View {
        ScrollView(.horizontal) {
            HStack(spacing: vm.spacing) {
                ForEach(filteredItems.prefix(10)) { item in
                    ClipboardItemView(item: item, vm: vm, cvm: cvm)
                }
                if filteredItems.count > 10 {
                    Button(action: openFileLocation) {
                        VStack {
                            Image(systemName: "ellipsis.circle")
                            Text("Show more")
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding(vm.spacing)
        }
        .padding(-vm.spacing)
        .scrollIndicators(.never)
    }

    func openFileLocation() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let clipboardItemsURL = documentsURL.appendingPathComponent(Clipboard.ClipboardItem.mainDir)
        
        if fileManager.fileExists(atPath: clipboardItemsURL.path) {
            NSWorkspace.shared.open(clipboardItemsURL)
        } else {
            print("Error: Clipboard items directory not found")
        }
    }
}

#Preview {
    ClipboardView(vm: .init())
        .padding()
        .frame(width: 550, height: 200, alignment: .center)
        .background(.black)
        .preferredColorScheme(.dark)
}
