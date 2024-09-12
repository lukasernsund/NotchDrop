import Foundation
import Pow
import SwiftUI
import UniformTypeIdentifiers

struct ClipboardItemView: View {
    let item: Clipboard.ClipboardItem
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var cvm: Clipboard

    @State private var isHovered = false
    @State private var formattedTimeAgo: String = ""

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
            Text(item.fileName)
                .font(.caption)
                .lineLimit(1)
            Text(formattedTimeAgo)
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