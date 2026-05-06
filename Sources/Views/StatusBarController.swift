import AppKit
import SwiftUI

final class StatusBarController {
    private var statusItem: NSStatusItem
    private weak var button: NSStatusBarButton?
    private let contextMenu: NSMenu = NSMenu()
    private var popover: NSPopover
    private let processManager = ProcessManager.shared

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()

        setupStatusBarButton()
        setupContextMenu()
        setupPopover()
        applyIconVisibility()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: .settingsChanged,
            object: nil
        )
    }

    private func setupStatusBarButton() {
        guard let btn = statusItem.button else { return }
        button = btn

        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = NSImage(systemSymbolName: AppConstants.Localizable.statusBarSymbol, accessibilityDescription: "CloseAll")!
            .withSymbolConfiguration(config)!
        image.isTemplate = true
        btn.image = image
        btn.action = #selector(handleLeftClick)
        btn.target = self

        let rightClick = NSClickGestureRecognizer(target: self, action: #selector(handleRightClick))
        rightClick.buttonMask = 1 << 1
        btn.addGestureRecognizer(rightClick)
    }

    private func setupContextMenu() {
        let minimizeItem = NSMenuItem(
            title: AppConstants.Localizable.minimizeAll,
            action: #selector(minimizeAllAction),
            keyEquivalent: ""
        )
        minimizeItem.image = NSImage(systemSymbolName: "arrow.down.square", accessibilityDescription: nil)
        minimizeItem.image?.isTemplate = true

        let quitAllItem = NSMenuItem(
            title: AppConstants.Localizable.quitAll,
            action: #selector(quitAllAction),
            keyEquivalent: ""
        )
        quitAllItem.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
        quitAllItem.image?.isTemplate = true

        let settingsItem = NSMenuItem(
            title: AppConstants.Localizable.settings,
            action: #selector(openSettingsAction),
            keyEquivalent: ""
        )
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
        settingsItem.image?.isTemplate = true

        contextMenu.addItem(minimizeItem)
        contextMenu.addItem(quitAllItem)
        contextMenu.addItem(.separator())
        contextMenu.addItem(settingsItem)

        minimizeItem.target = self
        quitAllItem.target = self
        settingsItem.target = self
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: AppConstants.popoverWidth, height: AppConstants.popoverHeight)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(processManager: processManager, onDismiss: { [weak self] in self?.closePopover() })
        )
    }

    @objc private func handleLeftClick() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    @objc private func handleRightClick() {
        guard let btn = button else { return }
        contextMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: btn.bounds.height), in: btn)
    }

    private func showPopover() {
        guard let btn = button else { return }
        popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
        processManager.refreshRunningApps()
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    // MARK: - Context menu actions

    @objc private func minimizeAllAction() {
        closePopover()
        DispatchQueue.main.async { self.processManager.minimizeAllApps() }
    }

    @objc private func quitAllAction() {
        closePopover()
        if AppSettings.shared.requireQuitConfirmation {
            showQuitAllAlert()
        } else {
            DispatchQueue.main.async { self.processManager.quitAllApps() }
        }
    }

    private func showQuitAllAlert() {
        let alert = NSAlert()
        alert.messageText = AppConstants.Localizable.quitAll
        alert.informativeText = String(format: AppConstants.AlertMessages.quitAllMessage, processManager.runningApps.count)
        alert.addButton(withTitle: AppConstants.Localizable.quitAll)
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            DispatchQueue.main.async { self.processManager.quitAllApps() }
        }
    }

    @objc private func openSettingsAction() {
        showPopover()
    }

    // MARK: - Icon visibility

    func updateVisibility() {
        applyIconVisibility()
    }

    private func applyIconVisibility() {
        button?.isHidden = AppSettings.shared.hideMenuBarIcon
    }

    @objc private func handleSettingsChanged() {
        applyIconVisibility()
    }
}
