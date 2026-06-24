import SwiftUI
import AppKit

struct PopoverContentView: View {
    @ObservedObject var processManager: ProcessManager
    @ObservedObject private var memoryManager = MemoryPressureManager.shared
    @ObservedObject private var thermalManager = ThermalStateManager.shared
    @ObservedObject private var diskManager = DiskSpaceManager.shared
    @ObservedObject private var cpuManager = CPUManager.shared
    @ObservedObject private var gpuManager = GPUManager.shared
    @StateObject private var updateChecker = UpdateChecker.shared
    var onDismiss: () -> Void = {}

    @State private var searchText = ""
    @State private var showQuitConfirm = false
    @State private var showForceQuitConfirm = false
    @State private var showSettings = false
    @State private var showIgnoredSheet = false
    @State private var expandedGroups: Set<String> = ["General", "Monitors", "Auto-Free"]
    @State private var expandedApps: Set<String> = []
    @State private var hoveringPID: Int32? = nil

    @AppStorage(AppConstants.UserDefaultsKeys.keyboardShortcuts) private var keyboardShortcutsEnabled = true
    @AppStorage(AppConstants.UserDefaultsKeys.requireConfirmation) private var requireQuitConfirmation = false
    @AppStorage(AppConstants.UserDefaultsKeys.hideMenuBarIcon) private var hideMenuBarIcon = false
    @AppStorage(AppConstants.UserDefaultsKeys.launchAtLogin) private var launchAtLogin = false
    @AppStorage(AppConstants.UserDefaultsKeys.memoryPressure) private var memoryPressureMonitoringEnabled = true
    @AppStorage(AppConstants.UserDefaultsKeys.thermalState) private var thermalStateMonitoringEnabled = false
    @AppStorage(AppConstants.UserDefaultsKeys.diskSpace) private var diskSpaceMonitoringEnabled = false
    @AppStorage(AppConstants.UserDefaultsKeys.cpuMonitoring) private var cpuMonitoringEnabled = false
    @AppStorage(AppConstants.UserDefaultsKeys.gpuMonitoring) private var gpuMonitoringEnabled = false
    @AppStorage(AppConstants.UserDefaultsKeys.autoFreeMemory) private var autoFreeMemoryEnabled = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                settingsView
            } else {
                mainView
            }
        }
        .frame(width: AppConstants.popoverWidth, height: AppConstants.popoverHeight)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Main View

    private var mainView: some View {
        VStack(spacing: 0) {
            if anyWarningActive {
                warningBanners
            }
            if updateChecker.updateAvailable {
                updateBanner
            }
            headerView
            Divider()
            appListView
            Divider()
            footerView
        }
        .alert(
            AppConstants.AlertMessages.quitSelectedTitle,
            isPresented: $showQuitConfirm
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Quit") { performQuitSelected(force: false) }
        } message: {
            Text(String(format: AppConstants.AlertMessages.quitSelectedMessage, processManager.selectedAppIds.count))
        }
        .alert(
            AppConstants.AlertMessages.forceQuitSelectedTitle,
            isPresented: $showForceQuitConfirm
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Force Quit") { performQuitSelected(force: true) }
        } message: {
            Text(String(format: AppConstants.AlertMessages.forceQuitSelectedMessage, processManager.selectedAppIds.count))
        }
        .sheet(isPresented: $showIgnoredSheet) {
            ignoredAppsSheet
        }
    }

    // MARK: - Settings View

    private var settingsView: some View {
        VStack(spacing: 0) {
            HStack {
                Text(AppConstants.Localizable.settings)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Done") { showSettings = false }
                    .font(.system(size: 11))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, AppConstants.headerPaddingH)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    settingsGroup(
                        id: "General",
                        icon: "gearshape",
                        label: AppConstants.Localizable.settingsGeneral
                    ) {
                        checkbox(AppConstants.Localizable.keyboardShortcuts, isOn: $keyboardShortcutsEnabled)
                        checkbox(AppConstants.Localizable.requireConfirmation, isOn: $requireQuitConfirmation)
                        checkbox(AppConstants.Localizable.hideIcon, isOn: $hideMenuBarIcon)
                        checkbox(AppConstants.Localizable.launchAtLogin, isOn: $launchAtLogin)
                    }
                    .onChange(of: launchAtLogin) { newValue in
                        LoginItemsManager.setRegistered(newValue)
                    }

                    Divider().padding(.horizontal, AppConstants.headerPaddingH)

                    settingsGroup(
                        id: "Monitors",
                        icon: "chart.bar",
                        label: AppConstants.Localizable.settingsMonitors
                    ) {
                        checkbox(AppConstants.Localizable.memoryMonitoring, isOn: $memoryPressureMonitoringEnabled)
                        checkbox(AppConstants.Localizable.thermalMonitoring, isOn: $thermalStateMonitoringEnabled)
                        checkbox(AppConstants.Localizable.diskMonitoring, isOn: $diskSpaceMonitoringEnabled)
                        checkbox(AppConstants.Localizable.cpuMonitoring, isOn: $cpuMonitoringEnabled)
                        checkbox(AppConstants.Localizable.gpuMonitoring, isOn: $gpuMonitoringEnabled)
                    }

                    Divider().padding(.horizontal, AppConstants.headerPaddingH)

                    settingsGroup(
                        id: "Auto-Free",
                        icon: "sparkles",
                        label: AppConstants.Localizable.settingsAutoFree
                    ) {
                        checkbox(AppConstants.Localizable.autoFreeMemory, isOn: $autoFreeMemoryEnabled)
                            .disabled(!memoryPressureMonitoringEnabled)

                        Button(action: { showIgnoredSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.slash.fill")
                                    .font(.system(size: 10))
                                Text(AppConstants.Localizable.manageIgnored)
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func settingsGroup<Content: View>(id: String, icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        let isExpanded = expandedGroups.contains(id)
        return VStack(spacing: 0) {
            Button(action: {
                if isExpanded { expandedGroups.remove(id) }
                else { expandedGroups.insert(id) }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, AppConstants.headerPaddingH)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    content()
                }
                .font(.system(size: 11))
                .padding(.horizontal, AppConstants.headerPaddingH)
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Ignored Apps Sheet

    private var ignoredAppsSheet: some View {
        let ignored = processManager.ignoredAppNames()
        return VStack(spacing: 0) {
            HStack {
                Text("Ignored Apps")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { showIgnoredSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if ignored.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text(AppConstants.Localizable.noIgnoredApps)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(ignored, id: \.bundleID) { item in
                            HStack {
                                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleID) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                }
                                Text(item.name)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Spacer()
                                Button(AppConstants.Localizable.unignore) {
                                    processManager.removeFromIgnored(item.bundleID)
                                }
                                .font(.system(size: 11))
                                .buttonStyle(.plain)
                                .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 100, maxHeight: 250)
            }

            Divider()
            HStack {
                Spacer()
                Button("Done") { showIgnoredSheet = false }
                    .font(.system(size: 11))
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 280, height: ignored.isEmpty ? 160 : 320)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Warning Banners

    private var anyWarningActive: Bool {
        (memoryManager.isWarningActive && memoryPressureMonitoringEnabled) ||
        (thermalManager.isWarningActive && thermalStateMonitoringEnabled) ||
        (diskManager.isWarningActive && diskSpaceMonitoringEnabled) ||
        (cpuManager.isWarningActive && cpuMonitoringEnabled) ||
        (gpuManager.isWarningActive && gpuMonitoringEnabled)
    }

    @ViewBuilder
    private var updateBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.blue)
            Text("v\(updateChecker.latestVersion) available")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.blue)
            Spacer()
            Button("Download") {
                if let url = URL(string: updateChecker.downloadURL) {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.blue)
            .cornerRadius(4)
        }
        .padding(.horizontal, AppConstants.headerPaddingH)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.08))
    }

    private var warningBanners: some View {
        VStack(spacing: 1) {
            if memoryManager.isWarningActive && memoryPressureMonitoringEnabled {
                warningBanner(
                    icon: "exclamationmark.triangle.fill",
                    color: memoryManager.isCritical ? .red : .orange,
                    text: String(
                        format: AppConstants.Localizable.memoryWarningMessage,
                        memoryManager.freeMemoryPercentage * 100,
                        memoryManager.freeMemoryGB,
                        memoryManager.totalMemoryGB
                    )
                )
            }
            if thermalManager.isWarningActive && thermalStateMonitoringEnabled {
                warningBanner(
                    icon: "thermometer.sun.fill",
                    color: thermalManager.isCritical ? .red : .orange,
                    text: String(
                        format: AppConstants.Localizable.thermalWarningMessage,
                        thermalManager.localizedState
                    )
                )
            }
            if diskManager.isWarningActive && diskSpaceMonitoringEnabled {
                warningBanner(
                    icon: "externaldrive.badge.exclamationmark",
                    color: diskManager.isCritical ? .red : .orange,
                    text: String(
                        format: AppConstants.Localizable.diskWarningMessage,
                        diskManager.freeGB,
                        (1 - diskManager.freePercentage) * 100,
                        diskManager.totalGB
                    )
                )
            }
            if cpuManager.isWarningActive && cpuMonitoringEnabled {
                warningBanner(
                    icon: "cpu.fill",
                    color: cpuManager.isCritical ? .red : .orange,
                    text: String(
                        format: AppConstants.Localizable.cpuWarningMessage,
                        cpuManager.globalCPUPercent
                    )
                )
            }
            if gpuManager.isWarningActive && gpuMonitoringEnabled {
                let gpuBannerColor: Color = gpuManager.isCritical ? .red : .orange
                HStack(spacing: 8) {
                    Image(nsImage: GPUIconHelper.icon(
                        tint: gpuManager.isCritical ? .systemRed : .systemOrange,
                        size: NSSize(width: 12, height: 12)
                    ))
                    .resizable()
                    .frame(width: 14, height: 14)
                    Text(String(
                        format: AppConstants.Localizable.gpuWarningMessage,
                        gpuManager.gpuUtilizationPercent
                    ))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(gpuBannerColor.opacity(0.85))
            }
        }
    }

    private func warningBanner(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.85))
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                if cpuMonitoringEnabled {
                    compactIndicator(
                        icon: "cpu",
                        color: cpuManager.isCritical ? .red :
                            cpuManager.isWarningActive ? .orange : .primary,
                        text: String(format: "%.0f%%", cpuManager.globalCPUPercent),
                        help: String(
                            format: "CPU: %.0f%%\nGlobal CPU usage",
                            cpuManager.globalCPUPercent
                        )
                    )
                }
                if gpuMonitoringEnabled {
                    let gpuTint: NSColor? = gpuManager.isCritical ? .systemRed :
                        gpuManager.isWarningActive ? .systemOrange : nil
                    HStack(spacing: 4) {
                        Image(nsImage: GPUIconHelper.icon(tint: gpuTint, size: NSSize(width: 12, height: 12)))
                            .resizable()
                            .frame(width: 12, height: 12)
                        Text(String(format: "%.0f%%", gpuManager.gpuUtilizationPercent))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .tooltip(String(
                        format: "GPU: %.0f%%\nGPU utilization",
                        gpuManager.gpuUtilizationPercent
                    ))
                }
                if memoryPressureMonitoringEnabled {
                    compactIndicator(
                        icon: "memorychip",
                        color: memoryPressureColor,
                        text: String(format: "%.0f%%", memoryManager.freeMemoryPercentage * 100),
                        help: String(
                            format: "Memory: %.0f%%\nFree: %.1f GB / %.1f GB — Used: %.1f GB",
                            memoryManager.freeMemoryPercentage * 100,
                            memoryManager.freeMemoryGB,
                            memoryManager.totalMemoryGB,
                            memoryManager.usedMemoryGB
                        )
                    )
                }
                if diskSpaceMonitoringEnabled && diskManager.totalGB > 0 {
                    compactIndicator(
                        icon: "externaldrive",
                        color: diskManager.isCritical ? .red :
                            diskManager.isWarningActive ? .orange : .primary,
                        text: String(format: "%.0f%%", (1 - diskManager.freePercentage) * 100),
                        help: String(
                            format: "Disk: %.0f%%\nFree: %.1f GB / %.1f GB",
                            (1 - diskManager.freePercentage) * 100,
                            diskManager.freeGB,
                            diskManager.totalGB
                        )
                    )
                }
                if thermalStateMonitoringEnabled {
                    let thermalColor: Color = thermalManager.isCritical ? .red :
                        thermalManager.isWarningActive ? .orange : .primary
                    compactIndicator(
                        icon: "thermometer",
                        color: thermalColor,
                        text: thermalStateShortLabel(thermalManager.thermalState),
                        help: String(
                            format: "Thermal: %@\n%@",
                            thermalManager.localizedState,
                            thermalManager.isCritical ? "Critical — performance throttled" :
                                thermalManager.isWarningActive ? "Warning — reduce workload" :
                                "Normal"
                        )
                    )
                }

            }
            .padding(.horizontal, AppConstants.headerPaddingH)
            .padding(.top, 8)

            TextField(AppConstants.Localizable.searchPlaceholder, text: $searchText)
                .font(.system(size: 12))
                .padding(.horizontal, AppConstants.headerPaddingH)
                .padding(.vertical, 6)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)

            HStack {
                Text("\(filteredApps.count) \(AppConstants.Localizable.appsLabel)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    if processManager.allSelected {
                        processManager.deselectAll()
                    } else {
                        processManager.selectAll()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: processManager.allSelected ? "checkmark.square.fill" : "square")
                        Text(processManager.allSelected ? AppConstants.Localizable.deselectAll : AppConstants.Localizable.selectAll)
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppConstants.headerPaddingH)
        }
        .padding(.bottom, 4)
    }

    private func compactIndicator(icon: String, color: Color, text: String, help: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .tooltip(help)
    }

    private func thermalStateShortLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:  return "N"
        case .fair:     return "F"
        case .serious:  return "S"
        case .critical: return "C"
        @unknown default: return "?"
        }
    }

    private var memoryPressureColor: Color {
        let pct = memoryManager.freeMemoryPercentage
        if pct < 0.1 { return .red }
        if pct < 0.2 { return .orange }
        return .primary
    }

    // MARK: - Combined App & Process List

    private enum CombinedRowType {
        case app(app: AppInfo, hasChildren: Bool)
        case child(name: String, memory: UInt64)
        case orphan(name: String, memory: UInt64)
        case divider
    }

    private struct CombinedRow: Identifiable {
        let id: String
        let type: CombinedRowType
        let memory: UInt64
        let indentLevel: Int
        let pid: Int32?
    }

    private var combinedRows: [CombinedRow] {
        let apps = filteredApps
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        var rows: [CombinedRow] = []
        var usedPIDs = Set<Int32>()


        for app in apps {
            guard let nsApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == app.bundleIdentifier })
            else {
                rows.append(CombinedRow(id: "app-\(app.id)", type: .app(app: app, hasChildren: false), memory: 0, indentLevel: 0, pid: nil))
                continue
            }
            let appPID = nsApp.processIdentifier
            usedPIDs.insert(appPID)
            let appMem = memoryManager.memoryForPID(appPID)

            let children = memoryManager.processParentPID
                .filter { $0.value == appPID && $0.key > 0 && !usedPIDs.contains($0.key) }
                .keys
            let hasChildren = !children.isEmpty
            rows.append(CombinedRow(id: "app-\(app.id)", type: .app(app: app, hasChildren: hasChildren), memory: appMem, indentLevel: 0, pid: appPID))

            if expandedApps.contains(app.id) {
                let childRows: [CombinedRow] = children.compactMap { pid in
                    usedPIDs.insert(pid)
                    guard let name = memoryManager.processNames[pid], !name.isEmpty
                    else { return nil }
                    let mem = memoryManager.processMemoryUsage[pid] ?? 0
                    return CombinedRow(id: "child-\(pid)", type: .child(name: name, memory: mem), memory: mem, indentLevel: 1, pid: pid)
                }.sorted { $0.memory > $1.memory }
                rows.append(contentsOf: childRows)
            } else {
                children.forEach { usedPIDs.insert($0) }
            }
        }

        let orphans: [CombinedRow] = memoryManager.processMemoryUsage
            .filter { pid, mem in
                pid > 0 && pid != ownPID && !usedPIDs.contains(pid)
                    && mem > 20 * 1_048_576
                    && !(memoryManager.processIsSystem[pid] ?? false)
                    && !(memoryManager.processNames[pid]?.isEmpty ?? true)
            }
            .map { pid, mem in
                let name = memoryManager.processNames[pid] ?? ""
                return CombinedRow(id: "orphan-\(pid)", type: .orphan(name: name, memory: mem), memory: mem, indentLevel: 0, pid: pid)
            }
            .sorted { $0.memory > $1.memory }
        if !orphans.isEmpty {
            rows.append(CombinedRow(id: "_divider", type: .divider, memory: 0, indentLevel: 0, pid: nil))
            rows.append(contentsOf: orphans)
        }

        return rows
    }

    private var appListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                let rows = searchText.isEmpty ? combinedRows : combinedRows.filter {
                    if case .app(let app, _) = $0.type {
                        return app.name.localizedCaseInsensitiveContains(searchText)
                    }
                    return false
                }

                ForEach(rows) { row in
                    switch row.type {
                    case .app(let app, let hasChildren):
                        HStack(spacing: 4) {
                            if hasChildren {
                                Button(action: {
                                    if expandedApps.contains(app.id) {
                                        expandedApps.remove(app.id)
                                    } else {
                                        expandedApps.insert(app.id)
                                    }
                                }) {
                                    Image(systemName: expandedApps.contains(app.id) ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                        .frame(width: 12)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Spacer().frame(width: 12)
                            }

                            AppRowView(
                                app: app,
                                isIgnored: processManager.ignoredBundleIdentifiers.contains(app.bundleIdentifier),
                                isSelected: processManager.selectedAppIds.contains(app.id),
                                isQuitting: processManager.isQuitting(app.id),
                                cpuPercent: cpuMonitoringEnabled ? cpuManager.cpuForBundleID(app.bundleIdentifier) : nil,
                                memoryUsage: memoryPressureMonitoringEnabled ? memoryManager.memoryForBundleID(app.bundleIdentifier) : nil,
                                isProtected: processManager.isAutoQuitProtected(app.bundleIdentifier),
                                onQuit: { force in processManager.quitApp(app, force: force) },
                                onToggleIgnore: { processManager.toggleIgnored(app.bundleIdentifier) },
                                onToggleSelect: { processManager.toggleSelection(app.id) },
                                onToggleProtect: { processManager.toggleAutoQuitProtection(app.bundleIdentifier) }
                            )
                        }

                    case .child(let name, let mem):
                        procRow(name: name, memory: mem, pid: row.pid, indent: row.indentLevel)

                    case .orphan(let name, let mem):
                        procRow(name: name, memory: mem, pid: row.pid, indent: row.indentLevel)

                    case .divider:
                        Divider()
                            .padding(.vertical, 4)
                    }
                }

                if rows.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text("No apps matching \"\(searchText)\"")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 60)
                }
            }
            .padding(.horizontal, AppConstants.listPaddingH)
            .padding(.vertical, AppConstants.listPaddingV)
        }
        .frame(maxHeight: .infinity)
    }

    private func procRow(name: String, memory: UInt64, pid: Int32?, indent: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(name)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            let label: String = {
                if memory == 0 { return "?" }
                let mb = Double(memory) / 1_048_576
                return mb >= 1024
                    ? String(format: "%.1f GB", mb / 1024)
                    : String(format: "%.0f MB", mb)
            }()
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(3)

            if let pid = pid, hoveringPID == pid {
                HStack(spacing: 4) {
                    Button(action: { kill(pid, SIGTERM) }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .tooltip("Terminate")

                    Button(action: { kill(pid, SIGKILL) }) {
                        Image(systemName: "xmark.octagon.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .tooltip("Force Kill")
                }
            }
        }
        .padding(.horizontal, AppConstants.rowPaddingH)
        .padding(.vertical, AppConstants.rowPaddingV)
        .padding(.leading, CGFloat(indent) * 20)
        .background(
            pid != nil && hoveringPID == pid
                ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3)
                : Color.clear
        )
        .cornerRadius(AppConstants.cornerRadius)
        .onHover { hovering in
            if let pid = pid {
                hoveringPID = hovering ? pid : nil
            }
        }
    }

    private var filteredApps: [AppInfo] {
        let apps = searchText.isEmpty
            ? processManager.runningApps
            : processManager.runningApps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }

        if memoryPressureMonitoringEnabled {
            return apps.sorted {
                let m1 = memoryManager.memoryForBundleID($0.bundleIdentifier)
                let m2 = memoryManager.memoryForBundleID($1.bundleIdentifier)
                return m1 > m2
            }
        }
        return apps
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    nativeButton(
                        title: AppConstants.Localizable.minimizeAll,
                        icon: "arrow.down.square",
                        action: {
                            onDismiss()
                            DispatchQueue.main.async { processManager.minimizeAllApps() }
                        }
                    )

                    nativeButton(
                        title: AppConstants.Localizable.quitAll,
                        icon: "xmark.circle.fill",
                        role: .destructive,
                        isProminent: true,
                        action: handleQuitAll
                    )
                }

                if processManager.selectedAppIds.isEmpty {
                    HStack(spacing: 0) {
                        Spacer()
                        nativeButton(
                            title: AppConstants.Localizable.settings,
                            icon: "gearshape.fill",
                            action: { showSettings = true }
                        )
                        Spacer()
                    }
                } else {
                    HStack(spacing: 6) {
                        Button(action: {
                            onDismiss()
                            DispatchQueue.main.async { processManager.quitSelectedApps(force: false) }
                        }) {
                            Label(
                                "\(AppConstants.Localizable.quitSelected) (\(processManager.selectedAppIds.count))",
                                systemImage: "checkmark.circle"
                            )
                            .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(BorderedProminentButtonStyle())
                        .tint(.blue)
                        .controlSize(.small)

                        Spacer()

                        Button(action: {
                            onDismiss()
                            DispatchQueue.main.async { processManager.quitSelectedApps(force: true) }
                        }) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(BorderedButtonStyle())
                        .tint(.orange)
                        .controlSize(.small)
                        .tooltip(AppConstants.Localizable.forceQuit)

                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 11, weight: .medium))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(BorderedButtonStyle())
                        .tint(.gray)
                        .controlSize(.small)
                        .tooltip(AppConstants.Localizable.settings)
                    }
                }

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Label(AppConstants.Localizable.quitCloseAll, systemImage: "power")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(0.45)
            }
            .padding(.horizontal, AppConstants.footerPaddingH)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func nativeButton(
        title: String,
        icon: String,
        role: ButtonRole? = nil,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        if isProminent {
            Button(role: role, action: action) {
                Label(title, systemImage: icon)
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .tint(.red)
            .controlSize(.small)
        } else {
            Button(role: role, action: action) {
                Label(title, systemImage: icon)
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.small)
        }
    }

    private func handleQuitAll() {
        onDismiss()
        if requireQuitConfirmation {
            showQuitAllAlert()
        } else {
            DispatchQueue.main.async { processManager.quitAllApps() }
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
            DispatchQueue.main.async { processManager.quitAllApps() }
        }
    }

    private func performQuitSelected(force: Bool) {
        let errors = processManager.quitSelectedApps(force: force)
    }

    private func checkbox(_ label: String, isOn: Binding<Bool>) -> some View {
        Button(action: { isOn.wrappedValue.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .foregroundColor(isOn.wrappedValue ? .accentColor : .secondary)
                    .font(.system(size: 13))
                Text(label)
                    .foregroundColor(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func toolTip(_ tip: String) -> some View {
        self.overlay(
            ToolTipView(tip: tip)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        )
    }

    func tooltip(_ tip: String) -> some View {
        self.background(
            ToolTipView(tip: tip)
                .allowsHitTesting(false)
        )
    }
}

private struct ToolTipView: NSViewRepresentable {
    let tip: String

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.toolTip = tip
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.toolTip = tip
    }
}

enum LoginItemsManager {
    static var isRegistered: Bool {
        UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.launchAtLogin)
    }

    static func setRegistered(_ registered: Bool) {
        UserDefaults.standard.set(registered, forKey: AppConstants.UserDefaultsKeys.launchAtLogin)
        if registered {
            openPrivacySettings()
        }
    }

    private static func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}
