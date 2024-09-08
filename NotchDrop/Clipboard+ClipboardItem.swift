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

        enum ItemType: String, Codable {
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
                    workspacePreviewImageData = image.pngRepresentation
                } else {
                    workspacePreviewImageData = NSWorkspace.shared.icon(forFileType: url.pathExtension).pngRepresentation
                }
                previewText = ""
            } else {
                itemType = .file
                workspacePreviewImageData = url.snapshotPreview().pngRepresentation
                previewText = ""
            }

            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(at: url, to: storageURL)
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
        .init(data: workspacePreviewImageData) ?? .init()
    }

    var shouldClean: Bool {
        if !FileManager.default.fileExists(atPath: storageURL.path) { return true }
        let keepInterval = Clipboard.shared.keepInterval
        guard keepInterval > 0 else { return true } // avoid non-reasonable value deleting user's files
        if Date().timeIntervalSince(copiedDate) > Clipboard.shared.keepInterval { return true }
        return false
    }
}