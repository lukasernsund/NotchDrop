//
//  TrayDrop+DropItem.swift
//  TrayDrop
//
//  Created by 秋星桥 on 2024/7/8.
//

import Cocoa
import Foundation
import QuickLook

extension TrayDrop {
    struct DropItem: Identifiable, Codable, Equatable, Hashable {
        let id: UUID
        let fileName: String
        let size: Int
        let copiedDate: Date
        let workspacePreviewImageData: Data
        
        init(url: URL) throws {
            id = UUID()
            fileName = url.lastPathComponent
            copiedDate = Date()
            
            // Perform potentially slow operations on a background queue
            let (size, previewData) = try DropItem.backgroundOperations(for: url)
            self.size = size
            self.workspacePreviewImageData = previewData
            
            try FileManager.default.createDirectory(
                at: Self.storageDirectoryURL,
                withIntermediateDirectories: true
            )
            
            // Check if the file already exists in the storage directory
            let destinationURL = Self.storageDirectoryURL.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                // File already exists, no need to copy
                print("File already exists in storage: \(fileName)")
            } else {
                // File doesn't exist, copy it
                try FileManager.default.copyItem(at: url, to: destinationURL)
                print("File copied to storage: \(fileName)")
            }
        }
        
        private static func backgroundOperations(for url: URL) throws -> (Int, Data) {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            let previewData = url.snapshotPreview().pngRepresentation
            return (size, previewData)
        }
    }
}

extension TrayDrop.DropItem {
    static let mainDir = "CopiedItems"

    static var storageDirectoryURL: URL {
        documentsDirectory.appendingPathComponent(Self.mainDir)
    }

    var storageURL: URL {
        Self.storageDirectoryURL.appendingPathComponent(fileName)
    }

    var workspacePreviewImage: NSImage {
        .init(data: workspacePreviewImageData) ?? .init()
    }

    var shouldClean: Bool {
        if !FileManager.default.fileExists(atPath: storageURL.path) { return true }
        let keepInterval = TrayDrop.shared.keepInterval
        guard keepInterval > 0 else { return true } // avoid non-reasonable value deleting user's files
        if Date().timeIntervalSince(copiedDate) > TrayDrop.shared.keepInterval { return true }
        return false
    }
}
