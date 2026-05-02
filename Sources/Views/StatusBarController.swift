import AppKit
import SwiftUI

final class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let processManager = ProcessManager.shared

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()

        setupStatusBarButton()
        setupPopover()
    }

    private func setupStatusBarButton() {
        if let button = statusItem.button {
            guard var image = NSImage(systemSymbolName: AppConstants.Localizable.statusBarSymbol, accessibilityDescription: "CloseAll") else { return }
            image.isTemplate = false
            let config = NSImage.SymbolConfiguration(paletteColors: [NSColor.systemRed, NSColor.white])
            image = image.withSymbolConfiguration(config) ?? image
            button.image = image
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(processManager: processManager)
        )
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            processManager.refreshRunningApps()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
    }
}