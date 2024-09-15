import Cocoa
import Combine
import Foundation
import OrderedCollections

class Clipboard: ObservableObject {
    static let shared = Clipboard()

    var cancellables = Set<AnyCancellable>()

    @Persist(key: "clipboardKeepInterval", defaultValue: 3600 * 24)
    var keepInterval: TimeInterval

    private var lastChangeCount: Int = 0
    private var timer: Timer?

    private init() {
        Publishers.CombineLatest3(
            $selectedFileStorageTime.removeDuplicates(),
            $customStorageTime.removeDuplicates(),
            $customStorageTimeUnit.removeDuplicates()
        )
        .map { selectedFileStorageTime, customStorageTime, customStorageTimeUnit in
            let customTime =
                switch customStorageTimeUnit {
                case .hours:
                    TimeInterval(customStorageTime) * 60 * 60
                case .days:
                    TimeInterval(customStorageTime) * 60 * 60 * 24
                case .weeks:
                    TimeInterval(customStorageTime) * 60 * 60 * 24 * 7
                case .months:
                    TimeInterval(customStorageTime) * 60 * 60 * 24 * 30
                case .years:
                    TimeInterval(customStorageTime) * 60 * 60 * 24 * 365
                }
            let ans = selectedFileStorageTime.toTimeInterval(customTime: customTime)
            print("[*] using interval \(ans) to keep files")
            return ans
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] output in
            self?.keepInterval = output
        }
        .store(in: &cancellables)
        startMonitoringClipboard()
    }

    var isEmpty: Bool { items.isEmpty }

    @PublishedPersist(key: "ClipboardItems", defaultValue: .init())
    var items: OrderedSet<ClipboardItem>

    @PublishedPersist(key: "selectedFileStorageTime", defaultValue: .oneDay)
    var selectedFileStorageTime: FileStorageTime

    @PublishedPersist(key: "customStorageTime", defaultValue: 1)
    var customStorageTime: Int

    @PublishedPersist(key: "customStorageTimeUnit", defaultValue: .days)
    var customStorageTimeUnit: CustomStorageTimeUnit

    @Published var isLoading: Int = 0

    func load(_ providers: [NSItemProvider]) {
        assert(!Thread.isMainThread)
        DispatchQueue.main.asyncAndWait { isLoading += 1 }
        guard let urls = providers.interfaceConvert() else {
            DispatchQueue.main.asyncAndWait { isLoading -= 1 }
            return
        }
        do {
            let sourceApp = detectSourceApp()
            let deviceType = detectDeviceType()
            let items = try urls.map {
                try ClipboardItem(url: $0, sourceApp: sourceApp, deviceType: deviceType)
            }
            DispatchQueue.main.async {
                items.forEach { self.items.updateOrInsert($0, at: 0) }
                self.sortItems()
                self.isLoading -= 1
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading -= 1
                NSAlert.popError(error)
            }
        }
    }

    func cleanExpiredFiles() {
        var inEdit = items
        let shouldCleanItems = items.filter(\.shouldClean)
        for item in shouldCleanItems {
            inEdit.remove(item)
        }
        items = inEdit
        sortItems()
    }

    func delete(_ item: ClipboardItem.ID) {
        guard let item = items.first(where: { $0.id == item }) else { return }
        delete(item: item)
    }

    private func delete(item: ClipboardItem) {
        var inEdit = items

        var url = item.storageURL
        try? FileManager.default.removeItem(at: url)

        do {
            // loops up to the main directory
            url = url.deletingLastPathComponent()
            while url.lastPathComponent != ClipboardItem.mainDir, url != documentsDirectory {
                let contents = try FileManager.default.contentsOfDirectory(atPath: url.path)
                guard contents.isEmpty else { break }
                try FileManager.default.removeItem(at: url)
                url = url.deletingLastPathComponent()
            }
        } catch {}

        inEdit.remove(item)
        items = inEdit
        sortItems()
    }

    func removeAll() {
        items.forEach { delete(item: $0) }
    }

    func togglePin(_ id: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var updatedItem = items[index]
        updatedItem.isPinned.toggle()
        items.remove(at: index)
        items.insert(updatedItem, at: index)
        sortItems()
    }

    func addLabel(_ id: ClipboardItem.ID, label: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var updatedItem = items[index]
        updatedItem.addLabel(label)
        items.remove(at: index)
        items.insert(updatedItem, at: index)
        sortItems()
    }

    func removeLabel(_ id: ClipboardItem.ID, label: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var updatedItem = items[index]
        updatedItem.removeLabel(label)
        items.remove(at: index)
        items.insert(updatedItem, at: index)
        sortItems()
    }

    private func sortItems() {
        items = OrderedSet(
            items.sorted { item1, item2 in
                if item1.isPinned && !item2.isPinned {
                    return true
                } else if !item1.isPinned && item2.isPinned {
                    return false
                } else {
                    return item1.copiedDate > item2.copiedDate
                }
            })
    }

    private func detectSourceApp() -> String? {
        // This is a placeholder. In a real implementation, you'd need to use
        // macOS-specific APIs to detect the source app.
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }

    private func detectDeviceType() -> ClipboardItem.DeviceType {
        // This is a placeholder. In a real implementation, you'd need to implement
        // a way to detect if the content is coming from an iPhone or iPad.
        // For now, we'll always return .mac
        return .mac
    }
}

extension Clipboard {
    enum FileStorageTime: String, CaseIterable, Identifiable, Codable {
        case oneHour = "1 Hour"
        case oneDay = "1 Day"
        case twoDays = "2 Days"
        case threeDays = "3 Days"
        case oneWeek = "1 Week"
        case never = "Forever"
        case custom = "Custom"

        var id: String { rawValue }

        var localized: String {
            NSLocalizedString(rawValue, comment: "")
        }

        func toTimeInterval(customTime: TimeInterval) -> TimeInterval {
            switch self {
            case .oneHour:
                60 * 60
            case .oneDay:
                60 * 60 * 24
            case .twoDays:
                60 * 60 * 24 * 2
            case .threeDays:
                60 * 60 * 24 * 3
            case .oneWeek:
                60 * 60 * 24 * 7
            case .never:
                TimeInterval.infinity
            case .custom:
                customTime
            }
        }
    }

    enum CustomStorageTimeUnit: String, CaseIterable, Identifiable, Codable {
        case hours = "Hours"
        case days = "Days"
        case weeks = "Weeks"
        case months = "Months"
        case years = "Years"

        var id: String { rawValue }

        var localized: String {
            NSLocalizedString(rawValue, comment: "")
        }
    }

    private func startMonitoringClipboard() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            handleClipboardChange(pasteboard)
        }
    }

    private func handleClipboardChange(_ pasteboard: NSPasteboard) {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            DispatchQueue.global().async {
                self.load(urls.map { NSItemProvider(object: $0 as NSURL) })
            }
        } else if let string = pasteboard.string(forType: .string) {
            DispatchQueue.global().async {
                self.loadString(string)
            }
        } else if let image = NSImage(pasteboard: pasteboard) {
            DispatchQueue.global().async {
                self.loadImage(image)
            }
        }
    }

    func loadString(_ string: String) {
        DispatchQueue.main.asyncAndWait { isLoading += 1 }
        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                UUID().uuidString
            ).appendingPathExtension("txt")
            try string.write(to: tempURL, atomically: true, encoding: .utf8)
            let sourceApp = detectSourceApp()
            let deviceType = detectDeviceType()
            let itemType = determineItemType(from: string)
            let item = try ClipboardItem(
                url: tempURL, itemType: itemType, sourceApp: sourceApp, deviceType: deviceType)
            DispatchQueue.main.async {
                self.items.updateOrInsert(item, at: 0)
                self.sortItems()
                self.isLoading -= 1
            }
            try FileManager.default.removeItem(at: tempURL)
        } catch {
            DispatchQueue.main.async {
                self.isLoading -= 1
                NSAlert.popError(error)
            }
        }
    }

    func loadImage(_ image: NSImage) {
        DispatchQueue.main.asyncAndWait { isLoading += 1 }
        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                UUID().uuidString
            ).appendingPathExtension("png")
            if let tiffData = image.tiffRepresentation,
                let bitmapImage = NSBitmapImageRep(data: tiffData),
                let pngData = bitmapImage.representation(using: .png, properties: [:])
            {
                try pngData.write(to: tempURL)
            }
            let sourceApp = detectSourceApp()
            let deviceType = detectDeviceType()
            let item = try ClipboardItem(url: tempURL, sourceApp: sourceApp, deviceType: deviceType)
            DispatchQueue.main.async {
                self.items.updateOrInsert(item, at: 0)
                self.sortItems()
                self.isLoading -= 1
            }
            try FileManager.default.removeItem(at: tempURL)
        } catch {
            DispatchQueue.main.async {
                self.isLoading -= 1
                NSAlert.popError(error)
            }
        }
    }

    private func determineItemType(from content: String) -> ClipboardItem.ItemType {
        if content.lowercased().hasPrefix("http://") || content.lowercased().hasPrefix("https://") {
            return .link
        } else if content.matches(regex: "^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$") {
            return .color
        } else {
            return .text
        }
    }
}

extension String {
    func matches(regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression) != nil
    }
}
