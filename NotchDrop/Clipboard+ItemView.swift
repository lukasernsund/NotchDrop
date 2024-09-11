import Foundation
import Pow
import SwiftUI
import UniformTypeIdentifiers

struct ClipboardItemView: View {
    let item: Clipboard.ClipboardItem
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var cvm: Clipboard

    @State private var isHovered = false

    private let itemSize: CGFloat = 120
    private let cornerRadius: CGFloat = 8

    var body: some View {
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
                        gradient: Gradient(colors: [color, color.opacity(0)]),
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.3, y: 0.3)
                    ),
                    lineWidth: 2
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(isHovered ? 0.5 : 0), lineWidth: 2)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Copy") {
                copyToClipboard()
            }
            Button("Delete") {
                cvm.delete(item.id)
            }
            if item.itemType == .file || item.itemType == .image {
                ShareLink(item: item.storageURL) {
                    Text("Share")
                }
            }
        }
        .contentShape(Rectangle())
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(vm.animation, value: isHovered)
        .onDrag { NSItemProvider(contentsOf: item.storageURL) ?? .init() }
        .onTapGesture {
            guard !vm.optionKeyPressed else { return }
            vm.notchClose()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSWorkspace.shared.open(item.storageURL)
            }
        }
        .overlay {
            Image(systemName: "xmark.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.red)
                .background(Color.white.clipShape(Circle()).padding(1))
                .frame(width: vm.spacing, height: vm.spacing)
                .opacity(isHovered || vm.optionKeyPressed ? 1 : 0)
                .scaleEffect(isHovered || vm.optionKeyPressed ? 1 : 0.5)
                .animation(vm.animation, value: isHovered || vm.optionKeyPressed)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: vm.spacing / 2, y: -vm.spacing / 2)
                .onTapGesture { cvm.delete(item.id) }
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
            Text(item.fileName)
                .font(.caption)
                .lineLimit(1)
            Text(formattedDate(item.copiedDate))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: itemSize - 16, alignment: .leading)
    }

    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.itemType {
        case .text:
            pasteboard.setString(item.previewText, forType: .string)
        case .image:
            if let image = NSImage(contentsOf: item.storageURL) {
                pasteboard.writeObjects([image])
            }
        case .file:
            pasteboard.writeObjects([item.storageURL as NSURL])
        }
    }

    func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let minutes = components.minute, minutes < 1 {
            return "Just now"
        } else if let minutes = components.minute, minutes < 60 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "Yesterday, \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
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