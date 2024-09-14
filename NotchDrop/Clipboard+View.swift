import SwiftUI
import ColorfulX
import UniformTypeIdentifiers
import AppKit

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
                detailedView
            }
        }
        .onAppear {
            setupKeyboardMonitor()
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
        .animation(.spring(), value: vm.selectedClipboardItemID)
    }

    var detailedView: some View {
        GeometryReader { geometry in
            ZStack {
                // ColorfulView(
                //     color: .constant(ColorfulPreset.starry.colors),
                //     speed: .constant(0.5),
                //     transitionSpeed: .constant(50)
                // )
                // .opacity(0.5)
                // .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius))
                detailedContent
                // RoundedRectangle(cornerRadius: vm.cornerRadius)
                //     .foregroundStyle(.white.opacity(0.1))
                //     .overlay {
                        
                //     }
            }
            .frame(minHeight: geometry.size.height)
            .animation(.spring(), value: vm.selectedClipboardItemID)
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
                VStack(spacing: 0) {
                    itemList
                }
            }
        }
    }

    var detailedContent: some View {
        Group {
            if filteredItems.isEmpty {
                emptyView
            } else {
                VStack(spacing: 0) {
                    if let selectedID = vm.selectedClipboardItemID, 
                       let selectedItem = filteredItems.first(where: { $0.id == selectedID }) {
                        expandedInfoView(for: selectedItem)
                    }
                }
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

    func expandedInfoView(for item: Clipboard.ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("More Info")
                    .font(.headline)
                Spacer()
                Button(action: {
                    vm.selectClipboardItem(nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Text("Type: \(item.itemType.rawValue.capitalized)")
            Text("Copied from: \(item.sourceApp)")
            Text("Date: \(item.copiedDate, formatter: itemDateFormatter)")
            
            if !item.labels.isEmpty {
                Text("Tags:")
                FlowLayout(alignment: .leading, spacing: 4) {
                    ForEach(Array(item.labels), id: \.self) { label in
                        Text(label)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
            
            if item.itemType == .image {
                if let image = NSImage(contentsOf: item.storageURL) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 100)
                }
            } else if item.itemType == .file {
                Text("File path: \(item.storageURL.path)")
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(vm.cornerRadius)
        .padding(.horizontal, vm.spacing)
        .padding(.bottom, vm.spacing)
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

    func setupKeyboardMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyPress(event)
            return event
        }
    }

    func handleKeyPress(_ event: NSEvent) {
        guard let currentIndex = filteredItems.firstIndex(where: { $0.id == vm.selectedClipboardItemID }) else {
            vm.selectClipboardItem(filteredItems.first?.id)
            return
        }

        switch event.keyCode {
        case 123: // Left arrow
            if currentIndex > 0 {
                vm.selectClipboardItem(filteredItems[currentIndex - 1].id)
            }
        case 124: // Right arrow
            if currentIndex < filteredItems.count - 1 {
                vm.selectClipboardItem(filteredItems[currentIndex + 1].id)
            }
        default:
            break
        }

        if let selectedID = vm.selectedClipboardItemID {
            scrollProxy?.scrollTo(selectedID, anchor: .center)
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

private let itemDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return arrangeSubviews(sizes: sizes, in: proposal.width ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var maxY: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX {
                origin.x = bounds.origin.x
                origin.y = maxY + spacing
            }

            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            maxY = max(maxY, origin.y + size.height)
        }
    }

    private func arrangeSubviews(sizes: [CGSize], in width: CGFloat) -> CGSize {
        var origin = CGPoint.zero
        var maxY: CGFloat = 0

        for size in sizes {
            if origin.x + size.width > width {
                origin.x = 0
                origin.y = maxY + spacing
            }

            origin.x += size.width + spacing
            maxY = max(maxY, origin.y + size.height)
        }

        return CGSize(width: width, height: maxY)
    }
}
