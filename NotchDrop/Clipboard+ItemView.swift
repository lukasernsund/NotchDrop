import SwiftUI
import UniformTypeIdentifiers
import AppKit
import Quartz
import QuickLook
import QuickLookThumbnailing

struct ClipboardItemView: View {
    let item: Clipboard.ClipboardItem
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var cvm: Clipboard

    @State private var isItemHovered = false
    @State private var isPinButtonHovered = false
    @State private var isCopyButtonHovered = false
    @State private var isDeleteButtonHovered = false
    @State private var isShareButtonHovered = false
    @State private var formattedTimeAgo: String = ""
    @State private var isCopied = false
    @State private var isEditingLabels = false
    @State private var newLabel = ""
    @State private var previewImage: NSImage?

    private let itemSize: CGFloat = 120
    private let cornerRadius: CGFloat = 16
    private let buttonSize: CGFloat = 24

    private var isSelected: Bool {
        vm.selectedClipboardItemID == item.id
    }

    private var isAnyPartHovered: Bool {
        isItemHovered || isCopyButtonHovered || isDeleteButtonHovered || isPinButtonHovered
            || isShareButtonHovered
    }

    var body: some View {
        ZStack {
            var backgroundColor: Color {
                if item.itemType == .color, let color = Color(hex: item.previewText) {
                    return color
                } else {
                    // return Color.gray.opacity(0.2)
                    return Color.gray.opacity(0.0)
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
                        path.addArc(
                            center: CGPoint(x: cornerRadius, y: cornerRadius),
                            radius: cornerRadius,
                            startAngle: .degrees(180),
                            endAngle: .degrees(270),
                            clockwise: false)
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                // isAnyPartHovered ? color.opacity(0) : color.opacity(0.5),
                                isAnyPartHovered ? color.opacity(0) : color.opacity(0.0),
                                color.opacity(0),
                            ]),
                            startPoint: .topLeading,
                            endPoint: UnitPoint(x: 0.3, y: 0.3)
                        ),
                        lineWidth: 2
                    )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        Color.white.opacity(isSelected ? 1 : (isAnyPartHovered ? 0.5 : 0)),
                        lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.05 : (isAnyPartHovered ? 1.02 : 1.0))
            .animation(vm.animation, value: isAnyPartHovered)
            .animation(vm.animation, value: isSelected)
            .onHover { hovering in
                isItemHovered = hovering
            }
            HStack(spacing: 0) {
                pinButton
                    .opacity(isAnyPartHovered || item.isPinned ? 1 : 0)
                    .scaleEffect(
                        isPinButtonHovered
                            ? 1.2
                            : (item.isPinned && !isAnyPartHovered)
                                ? 0.8 : isAnyPartHovered || item.isPinned ? 1 : 0.5
                    )
                    .animation(vm.animation, value: isAnyPartHovered)
                    .animation(vm.animation, value: isPinButtonHovered)
                    .onHover { hovering in
                        isPinButtonHovered = hovering
                    }
                Spacer()
                shareButton
                    .opacity(isAnyPartHovered ? 1 : 0)
                    .scaleEffect(isShareButtonHovered ? 1.2 : isAnyPartHovered ? 1.0 : 0.5)
                    .animation(vm.animation, value: isAnyPartHovered)
                    .animation(vm.animation, value: isShareButtonHovered)
                    .onHover { hovering in
                        isShareButtonHovered = hovering
                    }
                Spacer()
                copyButton
                    .opacity(isAnyPartHovered ? 1 : 0)
                    .scaleEffect(isCopyButtonHovered ? 1.2 : isAnyPartHovered ? 1.0 : 0.5)
                    .animation(vm.animation, value: isAnyPartHovered)
                    .animation(vm.animation, value: isCopyButtonHovered)
                    .onHover { hovering in
                        isCopyButtonHovered = hovering
                    }
                Spacer()
                deleteButton
                    .opacity(isAnyPartHovered || vm.optionKeyPressed ? 1 : 0)
                    .scaleEffect(
                        isDeleteButtonHovered
                            ? 1.2 : isAnyPartHovered || vm.optionKeyPressed ? 1.0 : 0.5
                    )
                    .animation(vm.animation, value: isAnyPartHovered || vm.optionKeyPressed)
                    .animation(vm.animation, value: isDeleteButtonHovered)
                    .onHover { hovering in
                        isDeleteButtonHovered = hovering
                    }
            }
            .frame(width: itemSize - 32, height: itemSize - 8, alignment: .top)
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
            LabelEditView(item: item, cvm: cvm, isPresented: $isEditingLabels)
        }
        .contentShape(Rectangle())
        .onDrag { NSItemProvider(contentsOf: item.storageURL) ?? .init() }
        .onTapGesture {
            vm.selectClipboardItem(item.id)
        }
        .onAppear {
            updateFormattedTimeAgo()
            generatePreviewImage()
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
            case .image, .file:
                if let image = previewImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: itemSize - 16, height: 50)
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.storageURL.path))
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
                    .frame(width: buttonSize, height: buttonSize)
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .foregroundColor(copyButtonForegroundColor)
                    .font(.system(size: 14))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: buttonSize, height: buttonSize)
    }

    var copyButtonBackgroundColor: Color {
        return .white.opacity(0.0)
    }

    var copyButtonForegroundColor: Color {
        if isCopied {
            return .green
        } else if isCopyButtonHovered {
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
                    .font(.system(size: 14))
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

    var shareButton: some View {
        Button(action: {
            ShareLink(item: item.storageURL) {
                Text("Share")
            }
        }) {
            ZStack {
                Circle()
                    .fill(shareButtonBackgroundColor)
                    .frame(width: buttonSize, height: buttonSize)
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
                    .foregroundColor(shareButtonForegroundColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: buttonSize, height: buttonSize)
    }

    var shareButtonBackgroundColor: Color {
        return .white.opacity(0.0)
    }

    var shareButtonForegroundColor: Color {
        if item.itemType == .color, let color = Color(hex: item.previewText) {
            return textColorForBackground(color ?? .white)
        } else if isShareButtonHovered {
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
                Image(
                    systemName: item.isPinned && isPinButtonHovered
                        ? "pin.slash.fill" : item.isPinned ? "pin.fill" : "pin"
                )
                .font(.system(size: 14))
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
                items = [
                    NSPasteboard.PasteboardType.tiff.rawValue: image.tiffRepresentation ?? Data()
                ]
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
                pasteboardItem.setString(
                    string, forType: NSPasteboard.PasteboardType(rawValue: type))
            } else if let url = value as? URL {
                pasteboardItem.setString(
                    url.absoluteString, forType: NSPasteboard.PasteboardType(rawValue: type))
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
        let components = Calendar.current.dateComponents(
            [.second, .minute, .hour, .day, .weekOfYear, .month, .year], from: date, to: now)

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

    func textColorForBackground(_ backgroundColor: Color) -> Color {
        let components = backgroundColor.cgColor?.components ?? [0, 0, 0, 0]
        let brightness = (components[0] * 299 + components[1] * 587 + components[2] * 114) / 1000
        return brightness > 0.5 ? .black : .white
    }

    func generatePreviewImage() {
        guard item.itemType == .file || item.itemType == .image else { return }

        let size = CGSize(width: 300, height: 300)
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0

        let request = QLThumbnailGenerator.Request(
            fileAt: item.storageURL,
            size: size,
            scale: scale,
            representationTypes: .thumbnail)

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, error in
            if let thumbnail = thumbnail {
                DispatchQueue.main.async {
                    self.previewImage = thumbnail.nsImage
                }
            } else {
                print("Error generating thumbnail: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    self.previewImage = NSWorkspace.shared.icon(forFile: item.storageURL.path)
                }
            }
        }
    }
}

struct LabelEditView: View {
    let item: Clipboard.ClipboardItem
    @ObservedObject var cvm: Clipboard
    @Binding var isPresented: Bool
    @State private var newLabel = ""

    var body: some View {
        VStack {
            Text("Edit Labels")
                .font(.headline)

            List {
                ForEach(Array(item.labels), id: \.self) { label in
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
                isPresented = false
            }
        }
        .frame(width: 320, height: 400)
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
