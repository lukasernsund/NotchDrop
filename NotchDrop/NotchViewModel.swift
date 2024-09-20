import Cocoa
import Combine
import Foundation
import LaunchAtLogin
import SwiftUI

class NotchViewModel: NSObject, ObservableObject {
    var cancellables: Set<AnyCancellable> = []
    let inset: CGFloat

    init(inset: CGFloat = -4) {
        self.inset = inset
        super.init()
        setupCancellables()
        setupClipboardMonitoring()
    }

    deinit {
        destroy()
    }

    let animation: Animation = .interactiveSpring(
        duration: 0.5,
        extraBounce: 0.25,
        blendDuration: 0.125
    )
    @Published var notchOpenedSize: CGSize = .init(width: 600, height: 160)
    let dropDetectorRange: CGFloat = 32

    enum Status: String, Codable, Hashable, Equatable {
        case closed
        case opened
        case popping
    }

    enum OpenReason: String, Codable, Hashable, Equatable {
        case click
        case drag
        case boot
        case unknown
    }

    enum ContentType: Int, Codable, Hashable, Equatable {
        case drop
        case clipboard
        case menu
        case settings
    }

    var notchOpenedRect: CGRect {
        .init(
            x: screenRect.origin.x + (screenRect.width - notchOpenedSize.width) / 2,
            y: screenRect.origin.y + screenRect.height - notchOpenedSize.height,
            width: notchOpenedSize.width,
            height: notchOpenedSize.height
        )
    }

    var headlineOpenedRect: CGRect {
        .init(
            x: screenRect.origin.x + (screenRect.width - notchOpenedSize.width) / 2,
            y: screenRect.origin.y + screenRect.height - deviceNotchRect.height,
            width: notchOpenedSize.width,
            height: deviceNotchRect.height
        )
    }

    @Published private(set) var status: Status = .closed
    @Published var openReason: OpenReason = .unknown
    @Published var contentType: ContentType = .drop {
        didSet {
            updateNotchSize()
        }
    }

    @Published var spacing: CGFloat = 16
    @Published var cornerRadius: CGFloat = 16
    @Published var deviceNotchRect: CGRect = .zero
    @Published var screenRect: CGRect = .zero
    @Published var optionKeyPressed: Bool = false
    @Published var notchVisible: Bool = true

    @PublishedPersist(key: "selectedLanguage", defaultValue: .system)
    var selectedLanguage: Language

    let hapticSender = PassthroughSubject<Void, Never>()

    @Published var clipboardItems: [ClipboardItem] = []

    @Published var shouldScrollClipboardToStart: Bool = false

    @Published var selectedClipboardItemID: UUID?
    @Published var isAnimatingClipboardSelection: Bool = false

    func notchOpen(_ reason: OpenReason) {
        // contentType = .drop// Always set to Drop page when opening
        openReason = reason
        status = .opened
        shouldScrollClipboardToStart = true
        updateNotchSize()
        
        // Call makeKeyAndOrderFront to ensure the window receives focus
        DispatchQueue.main.async {
            NSApp.delegate?.makeKeyAndOrderFront()
        }
    }

    func notchClose() {
        openReason = .unknown
        status = .closed
        selectedClipboardItemID = nil
    }

    func showSettings() {
        contentType = .settings
    }

    func notchPop() {
        openReason = .unknown
        status = .popping
    }

    func switchPage(to page: ContentType) {
        contentType = page
    }

    func showDropPage() {
        contentType = .drop
        if status != .opened {
            notchOpen(.drag)
        }
    }

    private func updateNotchSize() {
        switch contentType {
        case .clipboard:
            notchOpenedSize = .init(width: 600, height: selectedClipboardItemID != nil ? 800 : 325)
        default:
            notchOpenedSize = .init(width: 600, height: 160)
        }
    }

    private func setupClipboardMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkClipboardChanges()
        }
    }

    private func checkClipboardChanges() {
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount
            != UserDefaults.standard.integer(forKey: "LastPasteboardChangeCount")
        {
            UserDefaults.standard.set(pasteboard.changeCount, forKey: "LastPasteboardChangeCount")
            updateClipboardItems()
        }
    }

    private func updateClipboardItems() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            let newItem = ClipboardItem(content: .text(string))
            DispatchQueue.main.async {
                self.clipboardItems.insert(newItem, at: 0)
                self.trimClipboardItems()
            }
        } else if let image = pasteboard.data(forType: .tiff).flatMap(NSImage.init(data:)) {
            let newItem = ClipboardItem(content: .image(image))
            DispatchQueue.main.async {
                self.clipboardItems.insert(newItem, at: 0)
                self.trimClipboardItems()
            }
        }
    }

    private func trimClipboardItems() {
        if clipboardItems.count > 10 {
            clipboardItems = Array(clipboardItems.prefix(10))
        }
    }

    func selectClipboardItem(_ id: UUID?) {
        isAnimatingClipboardSelection = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedClipboardItemID == id {
                // If the tapped item is already selected, deselect it
                selectedClipboardItemID = nil
            } else {
                // Otherwise, select the tapped item
                selectedClipboardItemID = id
            }
            updateNotchSize()
        }

        // Reset the animation flag after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isAnimatingClipboardSelection = false
        }
    }
}

struct ClipboardItem: Identifiable {
    let id = UUID()
    let content: ClipboardContent
    let timestamp = Date()
}

enum ClipboardContent {
    case text(String)
    case image(NSImage)
}
