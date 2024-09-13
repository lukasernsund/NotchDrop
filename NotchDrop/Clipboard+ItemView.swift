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

    private let itemSize: CGFloat = 120
    private let cornerRadius: CGFloat = 8
    private let buttonSize: CGFloat = 24
    private let copyButtonSize: CGFloat = 40

    private var isAnyPartHovered: Bool {
        isItemHovered || isCopyButtonHovered || isDeleteButtonHovered || isPinButtonHovered
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                itemPreview
                Spacer()
                itemInfo
            }
            .padding(8)
            .frame(width: itemSize, height: itemSize)
            .background(Color.gray.opacity(0.2))
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
                            gradient: Gradient(colors: [color.opacity(0), color.opacity(0)]),
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
            Button("Delete") {
                cvm.delete(item.id)
            }
            Button(item.isPinned ? "Unpin" : "Pin") {
                cvm.togglePin(item.id)
            }
            if item.itemType == .file || item.itemType == .image {
                ShareLink(item: item.storageURL) {
                    Text("Share")
                }
            }
        }
        .contentShape(Rectangle())
        .onDrag { NSItemProvider(contentsOf: item.storageURL) ?? .init() }
        .onTapGesture {
            guard !vm.optionKeyPressed else { return }
            vm.notchClose()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSWorkspace.shared.open(item.storageURL)
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
            }
        }
    }

    var itemInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            if item.itemType != .text {
                Text(item.fileName)
                    .font(.caption)
                    .lineLimit(1)
            }
            Text(formattedTimeAgo)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: itemSize - 16, alignment: .leading)
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
                    .fill(.white.opacity(0.0))
                    .frame(width: buttonSize, height: buttonSize)
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isDeleteButtonHovered ? .white : .white.opacity(0.7))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: buttonSize, height: buttonSize)
    }

    var pinButton: some View {
        Button(action: {
            cvm.togglePin(item.id)
        }) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.0))
                    .frame(width: buttonSize, height: buttonSize)
                Image(systemName: item.isPinned && isPinButtonHovered ? "pin.slash.fill" : item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isPinButtonHovered || item.isPinned ? .white : .white.opacity(0.7))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: buttonSize, height: buttonSize)
    }

    func copyToClipboard() {
        let items: [String: Any]
        
        switch item.itemType {
        case .text:
            items = [NSPasteboard.PasteboardType.string.rawValue: item.previewText]
        case .image:
            if let image = NSImage(contentsOf: item.storageURL) {
                items = [NSPasteboard.PasteboardType.tiff.rawValue: image.tiffRepresentation ?? Data()]
            } else {
                items = [:]
            }
        case .file:
             items = [NSPasteboard.PasteboardType.fileURL.rawValue: item.storageURL]
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
        }
    }
}
