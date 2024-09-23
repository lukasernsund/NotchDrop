import Cocoa
import Combine
import Foundation
import OrderedCollections

class TrayDrop: ObservableObject {
static let shared = TrayDrop()

    var cancellables = Set<AnyCancellable>()

    @Persist(key: "keepInterval", defaultValue: 3600 * 24)
    var keepInterval: TimeInterval

    private var fileSystemWatcher: FileSystemWatcher?

    private init() {
        setupFileSystemWatcher()
        setupStorageTimePublisher()
        loadExistingFiles()
    }

    private func setupFileSystemWatcher() {
        fileSystemWatcher = FileSystemWatcher(url: DropItem.storageDirectoryURL)
        fileSystemWatcher?.delegate = self
        fileSystemWatcher?.start()
    }

    private func setupStorageTimePublisher() {
Publishers.CombineLatest3(
            $selectedFileStorageTime.removeDuplicates(),
            $customStorageTime.removeDuplicates(),
            $customStorageTimeUnit.removeDuplicates()
        )
        .map { selectedFileStorageTime, customStorageTime, customStorageTimeUnit in
            let customTime = switch customStorageTimeUnit {
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
    }

    private func loadExistingFiles() {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: DropItem.storageDirectoryURL, includingPropertiesForKeys: nil) else { return }
        
        while let fileURL = enumerator.nextObject() as? URL {
            if fileURL.hasDirectoryPath || fileURL.lastPathComponent == ".DS_Store" { continue }
            handleNewFile(fileURL)
        }
    }

    var isEmpty: Bool { items.isEmpty }

    @PublishedPersist(key: "TrayDropItems", defaultValue: .init())
    var items: OrderedSet<DropItem>

    @PublishedPersist(key: "selectedFileStorageTime", defaultValue: .oneDay)
    var selectedFileStorageTime: FileStorageTime

    @PublishedPersist(key: "customStorageTime", defaultValue: 1)
    var customStorageTime: Int

    @PublishedPersist(key: "customStorageTimeUnit", defaultValue: .days)
    var customStorageTimeUnit: CustomstorageTimeUnit

    @Published var isLoading: Int = 0

    func load(_ providers: [NSItemProvider]) {
DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async { self.isLoading += 1 }
            guard let urls = providers.interfaceConvert() else {
                DispatchQueue.main.async { self.isLoading -= 1 }
                return
            }
            do {
                let items = try urls.map { try DropItem(url: $0) }
                DispatchQueue.main.async {
                    items.forEach { self.items.updateOrInsert($0, at: 0) }
                    self.isLoading -= 1
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading -= 1
                    NSAlert.popError(error)
                }
            }
        }
    }

    func cleanExpiredFiles() {
var inEdit = items
        let shouldCleanItems = items.filter(\.shouldClean)
        for item in shouldCleanItems {
            inEdit.remove(item)
            try? FileManager.default.removeItem(at: item.storageURL)
        }
        items = inEdit
    }

    func delete(_ item: DropItem.ID) {
guard let item = items.first(where: { $0.id == item }) else { return }
        delete(item: item)
    }

    private func delete(item: DropItem) {
var inEdit = items
        try? FileManager.default.removeItem(at: item.storageURL)
        inEdit.remove(item)
        items = inEdit
    }

    func removeAll() {
items.forEach { delete(item: $0) }
    }

    private func handleNewFile(_ url: URL) {
        print("Handling new file: \(url.path)")
        if url.lastPathComponent == ".DS_Store" {
            print("Ignoring .DS_Store file")
            return
        }
        
        DispatchQueue.global(qos: .default).async { [weak self] in
            do {
                let newItem = try DropItem(url: url)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if !self.items.contains(where: { $0.fileName == newItem.fileName }) {
                        self.items.updateOrInsert(newItem, at: 0)
                        print("Added new item: \(newItem.fileName)")
                        self.objectWillChange.send()
                    } else {
                        print("Item already exists: \(newItem.fileName)")
                    }
                }
            } catch {
                print("Error handling new file: \(error)")
            }
        }
    }
}

extension TrayDrop: FileSystemWatcherDelegate {
    func fileSystemWatcher(_ watcher: FileSystemWatcher, didCreate url: URL) {
        print("FileSystemWatcher didCreate: \(url.path)")
        handleNewFile(url)
    }

    func fileSystemWatcher(_ watcher: FileSystemWatcher, didModify url: URL) {
        print("FileSystemWatcher didModify: \(url.path)")
        // Handle file modifications if needed
    }

    func fileSystemWatcher(_ watcher: FileSystemWatcher, didDelete url: URL) {
        print("FileSystemWatcher didDelete: \(url.path)")
        DispatchQueue.main.async {
            let countBefore = self.items.count
            self.items.removeAll(where: { $0.storageURL == url })
            let countAfter = self.items.count
            if countBefore != countAfter {
                print("Removed item: \(url.lastPathComponent)")
                self.objectWillChange.send()
            }
        }
    }
}

extension TrayDrop {
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

    enum CustomstorageTimeUnit: String, CaseIterable, Identifiable, Codable {
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
}

class FileSystemWatcher {
    weak var delegate: FileSystemWatcherDelegate?
    private let url: URL
    private var source: DispatchSourceFileSystemObject?

    init(url: URL) {
        self.url = url
    }

    func start() {
        let fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("Failed to open file descriptor for \(url.path)")
            return
        }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .attrib, .extend, .link, .revoke],
            queue: .main
        )

        source?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let flags = self.source?.data
            print("FileSystemWatcher event triggered with flags: \(flags?.rawValue ?? 0)")
            self.checkForChanges()
        }

        source?.setCancelHandler {
            close(fileDescriptor)
        }

        source?.resume()
        print("FileSystemWatcher started for \(url.path)")
    }

    private func checkForChanges() {
        let fileManager = FileManager.default
        let currentFiles = Set((try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? [])
        let knownFiles = Set(TrayDrop.shared.items.map { $0.storageURL })

        let newFiles = currentFiles.subtracting(knownFiles)
        let deletedFiles = knownFiles.subtracting(currentFiles)

        for file in newFiles where file.lastPathComponent != ".DS_Store" {
            print("New file detected: \(file.path)")
            delegate?.fileSystemWatcher(self, didCreate: file)
        }

        for file in deletedFiles {
            print("Deleted file detected: \(file.path)")
            delegate?.fileSystemWatcher(self, didDelete: file)
        }
    }

    func stop() {
        source?.cancel()
        print("FileSystemWatcher stopped")
    }
}

protocol FileSystemWatcherDelegate: AnyObject {
    func fileSystemWatcher(_ watcher: FileSystemWatcher, didCreate url: URL)
    func fileSystemWatcher(_ watcher: FileSystemWatcher, didModify url: URL)
    func fileSystemWatcher(_ watcher: FileSystemWatcher, didDelete url: URL)
}
