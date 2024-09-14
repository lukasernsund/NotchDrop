import SwiftUI
import UniformTypeIdentifiers

struct ClipboardItemView: View {
    let item: Clipboard.ClipboardItem
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var cvm: Clipboard

    @State private var isItemHovered = false
    @State private var isCopyButtonHovered = false
    @State private var isDeleteButtonHovered = false
    @State private var isPinButtonHovered = false
    @State private var formattedTimeAgo: String = ""
    @State private var isCopied = false
    @State private var isEditingLabels = false
    @State private var newLabel = ""

    private let itemSize: CGFloat = 120
    private let cornerRadius: CGFloat = 8
    private let buttonSize: CGFloat = 24
    private let copyButtonSize: CGFloat = 40

    private var isAnyPartHovered: Bool {
        isItemHovered || isCopyButtonHovered || isDeleteButtonHovered || isPinButtonHovered
    }

    var body: some View {
        ZStack {
            var backgroundColor: Color {
                if item.itemType == .color, let color = Color(hex: item.previewText) {
                    return color
                } else {
                    return Color.gray.opacity(0.2)
                }
            }
            var foregroundColor: Color {
                if item.itemType == .color, let color = Color(hex: item.previewText) {
                    return color
                } else {
                    return Color.gray.opacity(0.2)
                }
            }
            
            VStack(spacing: 0) {
                Spacer()
                itemPreview
                Spacer()
                itemInfo.foregroundColor(textColorForBackground(foregroundColor ?? .white))
            }
            .padding(8)
            .frame(width: itemSize, height: itemSize)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(
                GeometryReader { geometry in
                    let color = colorForType(item.itemType)
                    Path { path in
                        let rect = CGRect(origin: .zero, size: geometry.size)
                        path.move(to: CGPoint(x: cornerRadius, y: 0))
                        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
                        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
                        path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                                    radius: cornerRadius,
                                    startAngle: .degrees(180),
                                    endAngle: .degrees(270),
                                    clockwise: false)
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [isAnyPartHovered ? color.opacity(0) : color.opacity(0.5), color.opacity(0)]),
                            startPoint: .topLeading,
                            endPoint: UnitPoint(x: 0.3, y: 0.3)
                        ),
                        lineWidth: 2
                    )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(isAnyPartHovered ? 0.5 : 0), lineWidth: 2)
            )
            .scaleEffect(isAnyPartHovered ? 1.05 : 1.0)
            .animation(vm.animation, value: isAnyPartHovered)
            .onHover { hovering in
                isItemHovered = hovering
            }

            copyButton
                .opacity(isAnyPartHovered ? 1 : 0)
                .scaleEffect(isCopyButtonHovered ? 1.2 : isAnyPartHovered ? 1.0 : 0.5)
                .animation(vm.animation, value: isAnyPartHovered)
                .animation(vm.animation, value: isCopyButtonHovered)
                .onHover { hovering in
                    isCopyButtonHovered = hovering
                }

            deleteButton
                .opacity(isAnyPartHovered || vm.optionKeyPressed ? 1 : 0)
                .scaleEffect(isDeleteButtonHovered ? 1.2 : isAnyPartHovered || vm.optionKeyPressed ? 1 : 0.5)
                .animation(vm.animation, value: isAnyPartHovered || vm.optionKeyPressed)
                .animation(vm.animation, value: isDeleteButtonHovered)
                .onHover { hovering in
                    isDeleteButtonHovered = hovering
                }
                .offset(x: itemSize / 2 - buttonSize / 2 - 4, y: -itemSize / 2 + buttonSize / 2 + 4)

            pinButton
                .opacity(isAnyPartHovered || item.isPinned ? 1 : 0)
                .scaleEffect(isPinButtonHovered ? 1.2 : (item.isPinned && !isAnyPartHovered) ? 0.8 : isAnyPartHovered || item.isPinned ? 1 : 0.5)
                .animation(vm.animation, value: isAnyPartHovered)
                .animation(vm.animation, value: isPinButtonHovered)
                .onHover { hovering in
                    isPinButtonHovered = hovering
                }
                .offset(x: -itemSize / 2 + buttonSize / 2 + 4, y: -itemSize / 2 + buttonSize / 2 + 4)
        }
        .contextMenu {
            Button("Copy") {
                copyToClipboard()
            }
            if item.itemType == .link {
                Button("Copy URL") {
                    copyToClipboard(contentOnly: true)
                }
            }
            if item.itemType == .color {
                Button("Copy Color Code") {
                    copyToClipboard(contentOnly: true)
                }
            }
            Button("Delete") {
                cvm.delete(item.id)
            }
            Button(item.isPinned ? "Unpin" : "Pin") {
                cvm.togglePin(item.id)
            }
            Button("Edit Labels") {
                isEditingLabels = true
            }
            if item.itemType == .file || item.itemType == .image {
                ShareLink(item: item.storageURL) {
                    Text("Share")
                }
            }
        }
        .sheet(isPresented: $isEditingLabels) {
            labelEditView
        }
        .contentShape(Rectangle())
        .onDrag { NSItemProvider(contentsOf: item.storageURL) ?? .init() }
        .onTapGesture {
            guard !vm.optionKeyPressed else { return }
            vm.notchClose()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if item.itemType == .link, let url = URL(string: item.previewText) {
                    NSWorkspace.shared.open(url)
                } else {
                    NSWorkspace.shared.open(item.storageURL)
                }
            }
        }
        .onAppear {
            updateFormattedTimeAgo()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            updateFormattedTimeAgo()
        }
    }

    var itemPreview: some View {
        Group {
            switch item.itemType {
            case .text:
                Text(item.previewText)
                    .lineLimit(3)
                    .frame(width: itemSize - 16, alignment: .center)
            case .image:
                Image(nsImage: item.workspacePreviewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: itemSize - 16, height: 50)
            case .file:
                if let contentType = UTType(filenameExtension: URL(fileURLWithPath: item.fileName).pathExtension) {
                    Image(nsImage: NSWorkspace.shared.icon(for: contentType))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                } else {
                    Image(systemName: "doc")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                }
            case .link:
                VStack {
                    Image(systemName: "link")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(.blue)
                }
            case .color:
                EmptyView()
            }
        }
    }

    var itemInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch item.itemType {
            case .color:
                Text(item.previewText)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(textColorForBackground(Color(hex: item.previewText) ?? .white))
            case .link:
                Text(item.previewText)
                    .font(.caption)
                    .lineLimit(2)
            case .text:
                EmptyView()
            default:
                Text(item.fileName)
                    .font(.caption)
                    .lineLimit(1)
            }
            Text(formattedTimeAgo)
                .font(.caption2)
                .foregroundColor(.secondary)
            // labelsView
        }
        .frame(width: itemSize - 16, alignment: .leading)
    }

    var labelsView: some View {
        FlowLayout(alignment: .leading, spacing: 4) {
            ForEach(Array(item.labels), id: \.self) { label in
                Text(label)
                    .font(.system(size: 8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(labelColor(for: label))
                    .cornerRadius(4)
            }
        }
        .frame(width: itemSize - 16)
    }

    var labelEditView: some View {
        VStack {
            Text("Edit Labels")
                .font(.headline)
            
            List {
                ForEach(Array(userEditableLabels), id: \.self) { label in
                    HStack {
                        Text(label)
                        Spacer()
                        Button(action: {
                            cvm.removeLabel(item.id, label: label)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            HStack {
                TextField("New Label", text: $newLabel)
                Button("Add") {
                    if !newLabel.isEmpty {
                        cvm.addLabel(item.id, label: newLabel)
                        newLabel = ""
                    }
                }
            }
            .padding()
            
            Button("Done") {
                isEditingLabels = false
            }
        }
        .frame(width: 320, height: 400)
    }

    var copyButton: some View {
        Button(action: {
            copyToClipboard()
        }) {
            ZStack {
                Circle()
                    .fill(copyButtonBackgroundColor)
                    .frame(width: copyButtonSize, height: copyButtonSize)
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .foregroundColor(copyButtonForegroundColor)
                    .font(.system(size: 14))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: copyButtonSize, height: copyButtonSize)
    }

    var copyButtonBackgroundColor: Color {
        if isCopied {
            return .green
        } else if isCopyButtonHovered {
            return .gray
        } else {
            return .gray
        }
    }

    var copyButtonForegroundColor: Color {
        if isCopied || isCopyButtonHovered {
            return .white
        } else {
            return .white.opacity(0.7)
        }
    }

    var deleteButton: some View {
        Button(action: {
            cvm.delete(item.id)
        }) {
            ZStack {
                Circle()
                    .fill(deleteButtonBackgroundColor)
                    .frame(width: buttonSize, height: buttonSize)
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(deleteButtonForegroundColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: buttonSize, height: buttonSize)
    }

    var deleteButtonBackgroundColor: Color {
        return .white.opacity(0.0)
    }

    var deleteButtonForegroundColor: Color {
        if item.itemType == .color, let color = Color(hex: item.previewText) {
            return textColorForBackground(color ?? .white)
        } else if isDeleteButtonHovered {
            return .white
        } else {
            return .white.opacity(0.7)
        }
    }

    var pinButton: some View {
        Button(action: {
            cvm.togglePin(item.id)
        }) {
            ZStack {
                Circle()
                    .fill(pinButtonBackgroundColor)
                    .frame(width: buttonSize, height: buttonSize)
                Image(systemName: item.isPinned && isPinButtonHovered ? "pin.slash.fill" : item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(pinButtonForegroundColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: buttonSize, height: buttonSize)
    }

    var pinButtonBackgroundColor: Color {
        return .white.opacity(0.0)
    }

    var pinButtonForegroundColor: Color {
        if item.itemType == .color, let color = Color(hex: item.previewText) {
            return textColorForBackground(color ?? .white)
        } else if isPinButtonHovered || item.isPinned {
            return .white
        } else {
            return .white.opacity(0.7)
        }
    }

    func copyToClipboard(contentOnly: Bool = false) {
        let items: [String: Any]
        
        switch item.itemType {
        case .text, .link, .color:
            items = [NSPasteboard.PasteboardType.string.rawValue: item.previewText]
        case .image:
            if let image = NSImage(contentsOf: item.storageURL) {
                items = [NSPasteboard.PasteboardType.tiff.rawValue: image.tiffRepresentation ?? Data()]
            } else {
                items = [:]
            }
        case .file:
            if contentOnly {
                if let fileContent = try? String(contentsOf: item.storageURL, encoding: .utf8) {
                    items = [NSPasteboard.PasteboardType.string.rawValue: fileContent]
                } else {
                    items = [:]
                }
            } else {
                items = [NSPasteboard.PasteboardType.fileURL.rawValue: item.storageURL]
            }
        }
        
        let pasteboardItem = NSPasteboardItem()
        for (type, value) in items {
            if let data = value as? Data {
                pasteboardItem.setData(data, forType: NSPasteboard.PasteboardType(rawValue: type))
            } else if let string = value as? String {
                pasteboardItem.setString(string, forType: NSPasteboard.PasteboardType(rawValue: type))
            } else if let url = value as? URL {
                pasteboardItem.setString(url.absoluteString, forType: NSPasteboard.PasteboardType(rawValue: type))
            }
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([pasteboardItem])
    
        // Update the UI state
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isCopied = false
        }
    }

    func updateFormattedTimeAgo() {
        formattedTimeAgo = formattedDate(item.copiedDate)
    }

    func formattedDate(_ date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.second, .minute, .hour, .day, .weekOfYear, .month, .year], from: date, to: now)
        
        if let year = components.year, year > 0 {
            return year == 1 ? "1 year ago" : "\(year) years ago"
        } else if let month = components.month, month > 0 {
            return month == 1 ? "1 month ago" : "\(month) months ago"
        } else if let week = components.weekOfYear, week > 0 {
            return week == 1 ? "1 week ago" : "\(week) weeks ago"
        } else if let day = components.day, day > 0 {
            if day == 1 {
                return "Yesterday"
            } else if day < 7 {
                return "\(day) days ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: date)
            }
        } else if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1 hour ago" : "\(hour) hours ago"
        } else if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1 minute ago" : "\(minute) minutes ago"
        } else if let second = components.second, second > 0 {
            return second == 1 ? "1 second ago" : "\(second) seconds ago"
        } else {
            return "Just now"
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

    func labelColor(for label: String) -> Color {
        if isSystemLabel(label) {
            return .gray.opacity(0.3)
        } else {
            return .blue.opacity(0.3)
        }
    }

    func isSystemLabel(_ label: String) -> Bool {
        let systemLabels = [item.itemType.rawValue, item.sourceApp, item.deviceType?.rawValue].compactMap { $0 }
        return systemLabels.contains(label)
    }

    var userEditableLabels: [String] {
        return item.labels.filter { !isSystemLabel($0) }
    }

    func textColorForBackground(_ backgroundColor: Color) -> Color {
        let components = backgroundColor.cgColor?.components ?? [0, 0, 0, 0]
        let brightness = (components[0] * 299 + components[1] * 587 + components[2] * 114) / 1000
        return brightness > 0.5 ? .black : .white
    }
}

struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return arrangeSubviews(sizes: sizes, in: proposal.width ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var origin = bounds.origin
        var maxY: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            if origin.x + sizes[index].width > bounds.maxX {
                origin.x = bounds.origin.x
                origin.y = maxY + spacing
            }

            subview.place(at: origin, proposal: ProposedViewSize(sizes[index]))
            origin.x += sizes[index].width + spacing
            maxY = max(maxY, origin.y + sizes[index].height)
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

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
