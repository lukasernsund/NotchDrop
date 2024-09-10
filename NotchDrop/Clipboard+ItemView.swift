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

    var body: some View {
        VStack {
            itemPreview
            itemInfo
        }
        .padding(8)
        .frame(width: itemSize, height: itemSize)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
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
        }
        .contentShape(Rectangle())
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale),
            removal: .movingParts.poof
        ))
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
                    .frame(width: itemSize - 16, height: 60)
            case .image:
                Image(nsImage: item.workspacePreviewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: itemSize - 16, height: 60)
            case .file:
                if let contentType = UTType(filenameExtension: URL(fileURLWithPath: item.fileName).pathExtension) {
                    Image(nsImage: NSWorkspace.shared.icon(for: contentType))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                } else {
                    Image(systemName: "doc")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                }
            }
        }
    }

    var itemInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.fileName)
                .font(.caption)
                .lineLimit(1)
            Text(item.copiedDate, style: .time)
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
}