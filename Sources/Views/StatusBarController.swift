import AppKit
import SwiftUI
import Combine

final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private weak var button: NSStatusBarButton?
    private let contextMenu: NSMenu = NSMenu()
    private var popover: NSPopover
    private let processManager = ProcessManager.shared
    private let memoryManager = MemoryPressureManager.shared
    private var memoryCancellable: AnyCancellable?
    private var memoryCriticalCancellable: AnyCancellable?
    private let clickMenu = NSMenu()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()

        super.init()

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(popoverDidClose),
            name: NSPopover.didCloseNotification,
            object: popover
        )

        memoryCancellable = memoryManager.$isWarningActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateButtonImage()
            }

        memoryCriticalCancellable = memoryManager.$isCritical
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateButtonImage()
            }
    }

    private func setupStatusBarButton() {
        guard let btn = statusItem.button else { return }
        button = btn
        updateButtonImage()

        clickMenu.delegate = self
        statusItem.menu = clickMenu

        let rightClick = NSClickGestureRecognizer(target: self, action: #selector(handleRightClick))
        rightClick.buttonMask = 1 << 1
        btn.addGestureRecognizer(rightClick)
    }

    private func updateButtonImage() {
        guard let btn = button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let pct = memoryManager.freeMemoryPercentage * 100

        if memoryManager.isCritical {
            let symName = "exclamationmark.octagon.fill"
            let image = NSImage(systemSymbolName: symName, accessibilityDescription: "Critical memory")!
                .withSymbolConfiguration(config)!
            image.isTemplate = false
            btn.image = image
            btn.contentTintColor = .systemRed
            btn.toolTip = String(format: AppConstants.Localizable.memoryPressureBad, pct)
        } else if memoryManager.isWarningActive {
            let symName = "exclamationmark.triangle.fill"
            let image = NSImage(systemSymbolName: symName, accessibilityDescription: "Low memory")!
                .withSymbolConfiguration(config)!
            image.isTemplate = false
            btn.contentTintColor = nil
            btn.image = image
            btn.toolTip = String(format: AppConstants.Localizable.memoryPressureBad, pct)
        } else {
            let image = NSImage(systemSymbolName: AppConstants.Localizable.statusBarSymbol, accessibilityDescription: "CloseAll")!
                .withSymbolConfiguration(config)!
            image.isTemplate = true
            btn.contentTintColor = nil
            btn.image = image
            btn.toolTip = String(format: AppConstants.Localizable.memoryPressureGood, pct)
        }
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

    @objc private func popoverDidClose() {
        statusItem.menu = clickMenu
    }

    @objc private func handleRightClick() {
        closePopover()
        guard let btn = button else { return }
        contextMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: btn.bounds.height), in: btn)
    }

    @objc private func minimizeAllAction() {
        DispatchQueue.main.async { self.processManager.minimizeAllApps() }
    }

    @objc private func quitAllAction() {
        if AppSettings.shared.requireQuitConfirmation {
            showQuitAllAlert()
        } else {
            DispatchQueue.main.async { self.processManager.quitAllApps() }
        }
    }

    @objc private func openSettingsAction() {
        showPopover()
    }

    private func showPopover() {
        guard let btn = button else { return }
        if popover.isShown { return }
        statusItem.menu = nil
        popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)

        if let mainScreen = NSScreen.main,
           let popoverWin = popover.contentViewController?.view.window {
            let targetFrame = popoverWin.frame
            let visibleFrame = mainScreen.visibleFrame
            let x = min(max(targetFrame.origin.x, visibleFrame.minX + 4),
                        visibleFrame.maxX - targetFrame.width - 4)
            let y = visibleFrame.maxY - targetFrame.height - 4
            popoverWin.setFrameOrigin(NSPoint(x: x, y: y))
        }

        processManager.refreshRunningApps()
    }

    private func closePopover() {
        guard popover.isShown else { return }
        popover.performClose(nil)
        statusItem.menu = clickMenu
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

    func updateVisibility() {
        applyIconVisibility()
    }

    private func applyIconVisibility() {
        button?.isHidden = AppSettings.shared.hideMenuBarIcon
    }

    @objc private func handleSettingsChanged() {
        applyIconVisibility()
        updateButtonImage()
        closePopover()
    }
}

extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        menu.cancelTracking()
        if popover.isShown {
            closePopover()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.showPopover()
            }
        }
    }
}
