import SwiftUI
import ColorfulX
import UniformTypeIdentifiers

struct ClipboardView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var cvm: Clipboard
    @State private var searchText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @State private var selectedFilters: Set<Clipboard.ClipboardItem.ItemType> = []

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
        cvm.items.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.fileName.localizedCaseInsensitiveContains(searchText) ||
                item.previewText.localizedCaseInsensitiveContains(searchText)
            
            let matchesFilter = selectedFilters.isEmpty || selectedFilters.contains(item.itemType)
            
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Clipboard")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.leading, vm.spacing)
                    .padding(.vertical, vm.spacing / 4)
                
                Spacer()
                
                Button {
                    cvm.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.title2)
                        .padding(.trailing, vm.spacing)
                        .padding(.vertical, vm.spacing / 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            HStack(spacing: 0) {
                searchBar
                    .padding(.leading, vm.spacing)
                    .padding(.vertical, vm.spacing / 4)
                
                Spacer() // This will push the search bar and filter options to the edges
                
                filterOptions
                    .padding(.trailing, vm.spacing)
                    .padding(.vertical, vm.spacing / 4)
            }
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
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .frame(width: 300)
    }

    var filterOptions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Clipboard.ClipboardItem.ItemType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.rawValue.capitalized,
                        isSelected: selectedFilters.contains(type),
                        color: colorForType(type),
                        action: {
                            if selectedFilters.contains(type) {
                                selectedFilters.remove(type)
                            } else {
                                selectedFilters.insert(type)
                            }
                        }
                    )
                }
            }
            .frame(width: 200)
        }
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
            .frame(height: 180)
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

    func colorForType(_ type: Clipboard.ClipboardItem.ItemType) -> Color {
        switch type {
        case .file:
            return .blue
        case .text:
            return .green
        case .image:
            return .orange
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(isSelected ? color.opacity(0.2) : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? color : .primary.opacity(0.5))
                .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
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
