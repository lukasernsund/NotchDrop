import AppKit
import ColorfulX
import SwiftUI
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
            let localizedTimeUnit = NSLocalizedString(
                cvm.customStorageTimeUnit.localized.lowercased(), comment: "")
            return "\(cvm.customStorageTime) \(localizedTimeUnit)"
        }
    }

    var presentItemTypes: Set<Clipboard.ClipboardItem.ItemType> {
        Set(cvm.items.map { $0.itemType })
    }

    var filteredItems: [Clipboard.ClipboardItem] {
        let filtered = cvm.items.filter { item in
            let matchesSearch =
                searchText.isEmpty || item.fileName.localizedCaseInsensitiveContains(searchText)
                || item.previewText.localizedCaseInsensitiveContains(searchText)
                || item.labels.contains { $0.localizedCaseInsensitiveContains(searchText) }

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
            .opacity(0.0)
            .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius))

            RoundedRectangle(cornerRadius: vm.cornerRadius)
                .foregroundStyle(.white.opacity(0.0))
                .overlay {
                    content
                }
        }
        .frame(height: 152)
        .animation(.spring(), value: vm.selectedClipboardItemID)
    }

    var detailedView: some View {
        GeometryReader { geometry in
            detailedContent
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
                        let selectedItem = filteredItems.first(where: { $0.id == selectedID })
                    {
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
            .background(Color.white.opacity(0.0))
            .cornerRadius(vm.cornerRadius)
            .frame(height: 152)
            .scrollIndicators(.never)
            .onAppear {
                scrollProxy = proxy
            }
        }
    }

    func expandedInfoView(for item: Clipboard.ClipboardItem) -> some View {
        HStack(spacing: 20) {
            // Left side: Big preview
            previewContent(for: item)
                .frame(width: 300)
                .background(Color.black.opacity(0.2))
                .cornerRadius(10)

            // Right side: Metadata
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(item.itemType.rawValue.capitalized)
                        .font(.headline)
                        .foregroundColor(colorForType(item.itemType))
                    Spacer()
                    Button(action: {
                        vm.selectClipboardItem(nil)  // Close the detailed view
                    }) {
                        Image(systemName: "chevron.up")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                metadataRow(
                    icon: "clock", title: "Copied",
                    value: itemDateFormatter.string(from: item.copiedDate))
                metadataRow(icon: "app.badge", title: "Source", value: item.sourceApp ?? "Unknown")

                // File path row
                metadataRow(icon: "folder", title: "Path", value: item.storageURL.path) {
                    NSWorkspace.shared.selectFile(
                        item.storageURL.path, inFileViewerRootedAtPath: "")
                }

                // Link row
                if item.itemType == .link, let url = URL(string: item.previewText) {
                    metadataRow(icon: "link", title: "Link", value: item.previewText) {
                        NSWorkspace.shared.open(url)
                    }
                }

                // Color information rows
                if item.itemType == .color, let color = Color(hex: item.previewText) {
                    metadataRow(icon: "eyedropper", title: "Hex", value: item.previewText)
                    metadataRow(icon: "eyedropper.full", title: "RGB", value: color.rgbString)
                    metadataRow(icon: "eyedropper.halffull", title: "HSL", value: color.hslString)
                }

                if !item.labels.isEmpty {
                    Text("Tags:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    FlowLayout(alignment: .leading, spacing: 4) {
                        ForEach(Array(item.labels.sorted()), id: \.self) { label in
                            Text(label)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }

                Spacer()

                HStack {
                    Button("Copy") {
                        // Implement copy action
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Delete") {
                        cvm.delete(item.id)
                        vm.selectClipboardItem(nil)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(vm.cornerRadius)
    }

    func metadataRow(icon: String, title: String, value: String, action: (() -> Void)? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let action = action {
                    ClickableText(text: value, action: action)
                } else {
                    Text(value)
                        .font(.subheadline)
                }
            }
        }
    }

    @ViewBuilder
    func previewContent(for item: Clipboard.ClipboardItem) -> some View {
        switch item.itemType {
        case .text:
            ScrollView {
                Text(item.previewText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)  // Make text selectable
            }
        case .image:
            if let image = NSImage(contentsOf: item.storageURL) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        case .file:
            if let contentType = UTType(
                filenameExtension: URL(fileURLWithPath: item.fileName).pathExtension)
            {
                VStack {
                    Image(nsImage: NSWorkspace.shared.icon(for: contentType))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                    Text(item.fileName)
                        .font(.caption)
                }
            }
        case .link:
            VStack {
                Image(systemName: "link")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .foregroundColor(.blue)
                Text(item.previewText)
                    .font(.caption)
                    .lineLimit(3)
            }
        case .color:
            if let color = Color(hex: item.previewText) {
                color
                    .overlay(
                        Text(item.previewText)
                            .foregroundColor(color.isDark ? .white : .black)
                    )
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

    func setupKeyboardMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyPress(event)
            return event
        }
    }

    func handleKeyPress(_ event: NSEvent) {
        guard
            let currentIndex = filteredItems.firstIndex(where: {
                $0.id == vm.selectedClipboardItemID
            })
        else {
            vm.selectClipboardItem(filteredItems.first?.id)
            return
        }

        switch event.keyCode {
        case 123:  // Left arrow
            if currentIndex > 0 {
                vm.selectClipboardItem(filteredItems[currentIndex - 1].id)
            }
        case 124:  // Right arrow
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
    func metadataRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
            }
        }
    }
}

struct ClickableText: View {
    let text: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.blue)
            .underline(isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture(perform: action)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

extension Color {
    var isDark: Bool {
        var r: CGFloat
        var g: CGFloat
        var b: CGFloat
        var a: CGFloat
        (r, g, b, a) = (0, 0, 0, 0)
        NSColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luma < 0.5
    }

    var rgbString: String {
        let components = NSColor(self).cgColor.components ?? []
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return "RGB(\(r), \(g), \(b))"
    }

    var hslString: String {
        let components = NSColor(self).cgColor.components ?? []
        let r = components[0]
        let g = components[1]
        let b = components[2]

        let max = Swift.max(r, g, b)
        let min = Swift.min(r, g, b)

        var h: CGFloat = 0
        var s: CGFloat = 0
        let l = (max + min) / 2

        if max != min {
            let d = max - min
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
            switch max {
            case r: h = (g - b) / d + (g < b ? 6 : 0)
            case g: h = (b - r) / d + 2
            case b: h = (r - g) / d + 4
            default: break
            }
            h /= 6
        }

        return String(format: "HSL(%.0f°, %.0f%%, %.0f%%)", h * 360, s * 100, l * 100)
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

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
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
