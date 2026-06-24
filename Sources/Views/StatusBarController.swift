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
    private let thermalManager = ThermalStateManager.shared
    private let diskManager = DiskSpaceManager.shared
    private let cpuManager = CPUManager.shared
    private var monitorCancellables = Set<AnyCancellable>()
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

        let publishers = [
            memoryManager.$isWarningActive.eraseToAnyPublisher(),
            memoryManager.$isCritical.eraseToAnyPublisher(),
            thermalManager.$isWarningActive.eraseToAnyPublisher(),
            thermalManager.$isCritical.eraseToAnyPublisher(),
            diskManager.$isWarningActive.eraseToAnyPublisher(),
            cpuManager.$isWarningActive.eraseToAnyPublisher(),
            cpuManager.$isCritical.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(publishers)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateButtonImage()
            }
            .store(in: &monitorCancellables)
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

        if memoryManager.isCritical {
            setButtonImage(btn, "exclamationmark.octagon.fill", config, .systemRed,
                           "Memory critically low: %.0f%%", memoryManager.freeMemoryPercentage * 100)
        } else if thermalManager.isCritical {
            setButtonImage(btn, "thermometer.sun.fill", config, .systemRed,
                           "Thermal state: Critical")
        } else if diskManager.isCritical {
            setButtonImage(btn, "externaldrive.badge.exclamationmark", config, .systemRed,
                           "Disk space critically low: %.1f GB free", diskManager.freeGB)
        } else if memoryManager.isWarningActive {
            setButtonImage(btn, "exclamationmark.triangle.fill", config, nil,
                           "Memory: %.0f%% free", memoryManager.freeMemoryPercentage * 100)
        } else if cpuManager.isCritical {
            setButtonImage(btn, "cpu.fill", config, .systemRed,
                           "CPU: %.0f%%", cpuManager.globalCPUPercent)
        } else if cpuManager.isWarningActive {
            setButtonImage(btn, "cpu.fill", config, .systemOrange,
                           "CPU: %.0f%%", cpuManager.globalCPUPercent)
        } else if thermalManager.isWarningActive {
            setButtonImage(btn, "thermometer.sun.fill", config, .systemOrange,
                           "Thermal state: %@", thermalManager.localizedState)
        } else if diskManager.isWarningActive {
            setButtonImage(btn, "externaldrive.badge.exclamationmark", config, .systemOrange,
                           "Disk space: %.1f GB free", diskManager.freeGB)
        } else {
            setButtonImage(btn, AppConstants.Localizable.statusBarSymbol, config, nil)
        }

        btn.toolTip = buildTooltip()
    }

    private func setButtonImage(_ btn: NSStatusBarButton, _ symbol: String, _ config: NSImage.SymbolConfiguration,
                                _ tint: NSColor?, _ format: String? = nil, _ args: CVarArg...) {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!
            .withSymbolConfiguration(config)!
        image.isTemplate = tint == nil
        btn.image = image
        btn.contentTintColor = tint
    }

    private func buildTooltip() -> String {
        var lines: [String] = []

        let memPct = memoryManager.freeMemoryPercentage * 100
        if memoryManager.isWarningActive {
            lines.append(String(format: AppConstants.Localizable.memoryPressureBad, memPct))
        } else {
            lines.append(String(format: AppConstants.Localizable.memoryPressureGood, memPct))
        }

        if AppSettings.shared.diskSpaceMonitoringEnabled && diskManager.totalGB > 0 {
            let diskPct = diskManager.freePercentage * 100
            if diskManager.isWarningActive {
                lines.append(String(format: AppConstants.Localizable.diskPressureBad, diskPct))
            } else {
                lines.append(String(format: AppConstants.Localizable.diskPressureGood, diskPct))
            }
        }

        if AppSettings.shared.thermalStateMonitoringEnabled {
            if thermalManager.isWarningActive {
                lines.append(String(format: AppConstants.Localizable.thermalBad, thermalManager.localizedState))
            } else {
                lines.append(String(format: AppConstants.Localizable.thermalGood, thermalManager.localizedState))
            }
        }

        if AppSettings.shared.cpuMonitoringEnabled {
            if cpuManager.isWarningActive {
                lines.append(String(format: AppConstants.Localizable.cpuPressureBad, cpuManager.globalCPUPercent))
            } else {
                lines.append(String(format: AppConstants.Localizable.cpuPressureGood, cpuManager.globalCPUPercent))
            }
        }

        return lines.joined(separator: "\n")
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
