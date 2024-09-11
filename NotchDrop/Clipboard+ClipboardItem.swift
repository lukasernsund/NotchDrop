import Cocoa
import Foundation
import QuickLook

extension Clipboard {
    struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
        let id: UUID
        let fileName: String
        let size: Int
        let copiedDate: Date
        let workspacePreviewImageData: Data
        let itemType: ItemType
        let previewText: String

        enum ItemType: String, Codable, CaseIterable {
            case file
            case text
            case image
        }

        init(url: URL) throws {
            assert(!Thread.isMainThread)

            id = UUID()
            fileName = url.lastPathComponent
            size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            copiedDate = Date()

            if url.pathExtension.lowercased() == "txt" {
                itemType = .text
                workspacePreviewImageData = NSWorkspace.shared.icon(forFileType: "txt").pngRepresentation
                previewText = try String(contentsOf: url, encoding: .utf8).prefix(50).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if ["png", "jpg", "jpeg", "gif"].contains(url.pathExtension.lowercased()) {
                itemType = .image
                if let image = NSImage(contentsOf: url) {
                    workspacePreviewImageData = Self.compressAndResizeImage(image)
                } else {
                    workspacePreviewImageData = NSWorkspace.shared.icon(forFileType: url.pathExtension).pngRepresentation
                }
                previewText = ""
            } else {
                itemType = .file
                workspacePreviewImageData = Self.compressAndResizeImage(url.snapshotPreview())
                previewText = ""
            }

            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(at: url, to: storageURL)
        }

        static func compressAndResizeImage(_ image: NSImage) -> Data {
            let maxSize: CGFloat = 128 // Max width or height
            let aspectRatio = image.size.width / image.size.height
            let newSize: NSSize

            if image.size.width > maxSize || image.size.height > maxSize {
                if aspectRatio > 1 {
                    newSize = NSSize(width: maxSize, height: maxSize / aspectRatio)
                } else {
                    newSize = NSSize(width: maxSize * aspectRatio, height: maxSize)
                }
            } else {
                newSize = image.size // Keep original size if it's already smaller
            }

            let resizedImage = NSImage(size: newSize)
            resizedImage.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(in: NSRect(origin: .zero, size: newSize))
            resizedImage.unlockFocus()

            guard let tiffData = resizedImage.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData) else {
                return Data()
            }

            return bitmapImage.representation(using: .png, properties: [:]) ?? Data()
        }
    }
}

extension Clipboard.ClipboardItem {
    static let mainDir = "ClipboardItems"

    var storageURL: URL {
        documentsDirectory
            .appendingPathComponent(Self.mainDir)
            .appendingPathComponent(id.uuidString)
            .appendingPathComponent(fileName)
    }

    var workspacePreviewImage: NSImage {
        guard let image = NSImage(data: workspacePreviewImageData) else {
            return NSImage()
        }
        let aspectRatio = image.size.width / image.size.height
        let newSize: NSSize
        if aspectRatio > 1 {
            newSize = NSSize(width: 64, height: 64 / aspectRatio)
        } else {
            newSize = NSSize(width: 64 * aspectRatio, height: 64)
        }
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .sourceOver,
                   fraction: 1.0)
        resizedImage.unlockFocus()
        return resizedImage
    }

    var shouldClean: Bool {
        if !FileManager.default.fileExists(atPath: storageURL.path) { return true }
        let keepInterval = Clipboard.shared.keepInterval
        guard keepInterval > 0 else { return true } // avoid non-reasonable value deleting user's files
        if Date().timeIntervalSince(copiedDate) > Clipboard.shared.keepInterval { return true }
        return false
    }
}