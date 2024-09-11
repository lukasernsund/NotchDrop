import SwiftUI
import ColorfulX
import UniformTypeIdentifiers

struct ClipboardView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var cvm: Clipboard
    @State private var searchText = ""
    @State private var scrollProxy: ScrollViewProxy?

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
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, vm.spacing)
                .padding(.vertical, vm.spacing / 4) // Reduced vertical padding
                .background(Color.black)
            
            panel
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
                }
        }
        .frame(height: 152)
        .animation(vm.animation, value: cvm.items)
        .animation(vm.animation, value: cvm.isLoading)
        .onChange(of: vm.shouldScrollClipboardToStart) { newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToStart()
                    vm.shouldScrollClipboardToStart = false
                }
            }
        }
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
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.vertical, 8)
    }

    var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
            Text(text)
                .multilineTextAlignment(.center)
                .font(.system(.headline, design: .rounded))
        }
        .padding(vm.spacing)
    }

    var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: vm.spacing) {
                    ForEach(filteredItems) { item in
                        ClipboardItemView(item: item, vm: vm, cvm: cvm)
                            .id(item.id)
                    }
                }
                .padding(vm.spacing)
            }
            .background(Color.white.opacity(0.1))
            .cornerRadius(vm.cornerRadius)
            .frame(height: 180) // Increased height to fit items without overflow
            .scrollIndicators(.never)
            .onAppear {
                scrollProxy = proxy
            }
        }
    }

    private func scrollToStart() {
        withAnimation {
            scrollProxy?.scrollTo(filteredItems.first?.id, anchor: .leading)
        }
    }
}

struct ClipboardView_Previews: PreviewProvider {
    static var previews: some View {
        ClipboardView(vm: NotchViewModel(), cvm: Clipboard.shared)
            .padding()
            .frame(width: 550, height: 230, alignment: .center)
            .background(.black)
            .preferredColorScheme(.dark)
    }
}
