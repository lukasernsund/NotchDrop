import SwiftUI
import ColorfulX
import UniformTypeIdentifiers

struct ClipboardView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var cvm: Clipboard
    @State private var searchText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @State private var selectedFilters: Set<Clipboard.ClipboardItem.ItemType> = []
    @FocusState private var isSearchFocused: Bool
    @State private var isTrashHovered = false

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

    var presentItemTypes: Set<Clipboard.ClipboardItem.ItemType> {
        Set(cvm.items.map { $0.itemType })
    }

    var filteredItems: [Clipboard.ClipboardItem] {
        let filtered = cvm.items.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.fileName.localizedCaseInsensitiveContains(searchText) ||
                item.previewText.localizedCaseInsensitiveContains(searchText) ||
                item.labels.contains { $0.localizedCaseInsensitiveContains(searchText) }
            
            let matchesFilter = selectedFilters.isEmpty || selectedFilters.contains(item.itemType)
            
            return matchesSearch && matchesFilter
        }
        
        return filtered.sorted { item1, item2 in
            if item1.isPinned && !item2.isPinned {
                return true
            } else if !item1.isPinned && item2.isPinned {
                return false
            } else {
                return item1.copiedDate > item2.copiedDate
            }
        }
    }

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isSearchFocused = false
                }
            
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
                            .scaleEffect(isTrashHovered ? 1.2 : 1.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        isTrashHovered = hovering
                    }
                    .animation(vm.animation, value: isTrashHovered)
                }
                HStack(spacing: 0) {
                    searchBar
                        .padding(.leading, vm.spacing)
                        .padding(.vertical, vm.spacing)
                    
                    Spacer()
                    
                    filterOptions
                        .padding(.trailing, vm.spacing)
                        .padding(.vertical, vm.spacing / 4)
                }
                .background(Color.black)
                panel
            }
        }
    }

    var panel: some View {
        ZStack {
            ColorfulView(
                color: .constant(ColorfulPreset.starry.colors),
                speed: .constant(0.5),
                transitionSpeed: .constant(50)
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
                .focused($isSearchFocused)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .frame(width: 320)
    }

    var filterOptions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Clipboard.ClipboardItem.ItemType.allCases, id: \.self) { type in
                    if presentItemTypes.contains(type) {
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
            }
        }
        .frame(width: 200)
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
                LazyHStack(spacing: vm.spacing) {
                    ForEach(filteredItems) { item in
                        ClipboardItemView(item: item, vm: vm, cvm: cvm)
                            .id(item.id)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(vm.spacing)
                .animation(.spring(), value: filteredItems)
            }
            .background(Color.white.opacity(0.1))
            .cornerRadius(vm.cornerRadius)
            .frame(height: 152)
            .scrollIndicators(.never)
            .onAppear {
                scrollProxy = proxy
            }
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
        case .link:
            return .purple
        case .color:
            return .pink
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
