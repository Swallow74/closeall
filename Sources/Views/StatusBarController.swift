import AppKit
import SwiftUI
import Combine

final class StatusBarController {
    private var statusItem: NSStatusItem
    private weak var button: NSStatusBarButton?
    private let contextMenu: NSMenu = NSMenu()
    private var popoverWindow: NSWindow?
    private var eventMonitor: Any?
    private let processManager = ProcessManager.shared
    private let memoryManager = MemoryPressureManager.shared
    private var memoryCancellable: AnyCancellable?
    private var memoryCriticalCancellable: AnyCancellable?

    private var isPopoverShown: Bool {
        popoverWindow?.isVisible == true
    }

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupStatusBarButton()
        setupContextMenu()
        applyIconVisibility()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: .settingsChanged,
            object: nil
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
        btn.action = #selector(handleLeftClick)
        btn.target = self

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

    @objc private func handleLeftClick() {
        if isPopoverShown {
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
        closePopover()

        let popoverContent = PopoverContentView(
            processManager: processManager,
            onDismiss: { [weak self] in self?.closePopover() }
        )
        let hostingController = NSHostingController(rootView: popoverContent)

        let contentSize = NSSize(width: AppConstants.popoverWidth, height: AppConstants.popoverHeight)
        hostingController.view.frame.size = contentSize

        let window = NSPanel(contentViewController: hostingController)
        window.styleMask = [.borderless]
        window.level = .statusBar
        window.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor.windowBackgroundColor
        window.hasShadow = true
        window.isOpaque = true
        window.hidesOnDeactivate = true
        window.setFrame(NSRect(origin: .zero, size: contentSize), display: false)

        let screen = btn.window?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let btnFrameInWindow = btn.convert(btn.bounds, to: nil)
        let btnFrameOnScreen = btn.window!.convertToScreen(btnFrameInWindow)
        var origin = NSPoint(
            x: btnFrameOnScreen.midX - contentSize.width / 2,
            y: btnFrameOnScreen.minY - contentSize.height - 4
        )
        let visibleFrame = screen.visibleFrame
        if origin.x < visibleFrame.minX + 4 {
            origin.x = visibleFrame.minX + 4
        } else if origin.x + contentSize.width > visibleFrame.maxX - 4 {
            origin.x = visibleFrame.maxX - contentSize.width - 4
        }
        window.setFrameOrigin(origin)

        popoverWindow = window
        window.makeKeyAndOrderFront(nil)

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let popoverWindow = self.popoverWindow else { return event }
            if event.window?.windowNumber != popoverWindow.windowNumber {
                self.closePopover()
            }
            return event
        }

        processManager.refreshRunningApps()
    }

    private func closePopover() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        popoverWindow?.close()
        popoverWindow = nil
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
        updateButtonImage()
    }
}
