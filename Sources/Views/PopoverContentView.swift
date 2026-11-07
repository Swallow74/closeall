import SwiftUI
import AppKit

struct PopoverContentView: View {
    @ObservedObject var processManager: ProcessManager
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var memoryManager = MemoryPressureManager.shared
    @ObservedObject private var thermalManager = ThermalStateManager.shared
    @ObservedObject private var diskManager = DiskSpaceManager.shared
    @ObservedObject private var cpuManager = CPUManager.shared
    @ObservedObject private var gpuManager = GPUManager.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared
    var onDismiss: () -> Void = {}

    @State private var searchText = ""
    @State private var showSettings = false
    @State private var expandedApps: Set<String> = []
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(processManager: processManager, onBack: { showSettings = false })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                mainView
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showSettings)
        .frame(width: AppConstants.popoverWidth, height: AppConstants.popoverHeight)
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .popoverWillShow)) { note in
            searchText = ""
            showSettings = (note.userInfo?["settings"] as? Bool) ?? false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { searchFocused = !showSettings }
        }
    }

    // MARK: - Main

    private var mainView: some View {
        VStack(spacing: 0) {
            banners
            headerView
            Divider()
            appListView
            footerView
        }
    }

    // MARK: - Banners

    private var banners: some View {
        VStack(spacing: 1) {
            if settings.memoryPressureMonitoringEnabled && memoryManager.isWarningActive {
                warningBanner(
                    icon: "exclamationmark.triangle.fill",
                    level: memoryManager.isCritical ? .critical : .warning,
                    text: String(format: L.memoryWarningMessage, memoryManager.freeMemoryPercentage * 100,
                                 memoryManager.freeMemoryGB, memoryManager.totalMemoryGB)
                )
            }
            if settings.thermalStateMonitoringEnabled && thermalManager.isWarningActive {
                warningBanner(
                    icon: "thermometer.sun.fill",
                    level: thermalManager.isCritical ? .critical : .warning,
                    text: String(format: L.thermalWarningMessage, thermalManager.localizedState)
                )
            }
            if settings.diskSpaceMonitoringEnabled && diskManager.isWarningActive {
                warningBanner(
                    icon: "externaldrive.badge.exclamationmark",
                    level: diskManager.isCritical ? .critical : .warning,
                    text: String(format: L.diskWarningMessage, diskManager.freeGB,
                                 (1 - diskManager.freePercentage) * 100, diskManager.totalGB)
                )
            }
            if settings.cpuMonitoringEnabled && cpuManager.isWarningActive {
                warningBanner(
                    icon: "cpu.fill",
                    level: cpuManager.isCritical ? .critical : .warning,
                    text: String(format: L.cpuWarningMessage, cpuManager.globalCPUPercent)
                )
            }
            if settings.gpuMonitoringEnabled && gpuManager.isWarningActive {
                warningBanner(
                    image: Image(nsImage: GPUIconHelper.icon(tint: .white, size: NSSize(width: 12, height: 12))),
                    level: gpuManager.isCritical ? .critical : .warning,
                    text: String(format: L.gpuWarningMessage, gpuManager.gpuUtilizationPercent)
                )
            }
            if !processManager.failedApps.isEmpty {
                failureBanner
            }
            if updateChecker.updateAvailable {
                updateBanner
            }
        }
    }

    private func warningBanner(icon: String, level: Level, text: String) -> some View {
        warningBanner(image: Image(systemName: icon), level: level, text: text)
    }

    private func warningBanner(image: Image, level: Level, text: String) -> some View {
        HStack(spacing: 8) {
            image
                .font(.system(size: 12))
                .foregroundColor(.white)
                .frame(width: 14, height: 14)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(level.color.opacity(0.9))
        .accessibilityElement(children: .combine)
    }

    private var failureBanner: some View {
        let names = processManager.failedApps.map(\.name).joined(separator: ", ")
        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 13))
            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: L.failedToQuit, processManager.failedApps.count))
                    .font(.system(size: 11, weight: .semibold))
                Text(names)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            Button(L.forceQuit) {
                if Confirm.ask(title: L.forceQuit, message: String(format: L.forceQuitFailedMessage, names), button: L.forceQuit) {
                    processManager.retryFailedWithForce()
                }
            }
            .controlSize(.small)
            IconButton(systemName: "xmark", label: L.dismiss, size: 10) { processManager.dismissFailures() }
        }
        .padding(.horizontal, AppConstants.headerPaddingH)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.14))
    }

    private var updateBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
            Text(String(format: L.updateAvailable, updateChecker.latestVersion))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)
            Spacer()
            Button(updateChecker.installing ? L.installing : (updateChecker.canInstall ? L.installAndRestart : L.download)) {
                if updateChecker.canInstall {
                    updateChecker.install()
                } else if let url = URL(string: updateChecker.downloadURL) {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.small)
            .disabled(updateChecker.installing)
        }
        .padding(.horizontal, AppConstants.headerPaddingH)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.1))
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                metricChips
                Spacer(minLength: 0)
                IconButton(systemName: "gearshape", label: L.settings, size: 14) { showSettings = true }
                    .keyboardShortcut(",", modifiers: .command)
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField(L.searchPlaceholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($searchFocused)
                    .onExitCommand { searchText = "" }
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L.clearSearch)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color(NSColor.textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(searchFocused ? 0.25 : 0.1), lineWidth: 1))

            HStack {
                Text(summaryText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    if processManager.allSelected { processManager.deselectAll() } else { processManager.selectAll() }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: processManager.allSelected ? "checkmark.circle.fill" : "circle")
                        Text(processManager.allSelected ? L.deselectAll : L.selectAll)
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(processManager.runningApps.isEmpty)
            }
        }
        .padding(.horizontal, AppConstants.headerPaddingH)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var summaryText: String {
        let n = filteredApps.count
        let sel = processManager.selectedAppIds.count
        return sel > 0 ? "\(n) \(L.appsLabel) · \(sel) \(L.selectedLabel)" : "\(n) \(L.appsLabel)"
    }

    @ViewBuilder
    private var metricChips: some View {
        if settings.cpuMonitoringEnabled {
            MetricChip(icon: Image(systemName: "cpu"),
                       text: String(format: "%.0f%%", cpuManager.globalCPUPercent),
                       level: cpuManager.isCritical ? .critical : cpuManager.isWarningActive ? .warning : .normal,
                       help: String(format: L.cpuPressureGood, cpuManager.globalCPUPercent))
        }
        if settings.gpuMonitoringEnabled {
            let tint: NSColor? = gpuManager.isCritical ? .systemRed : gpuManager.isWarningActive ? .systemOrange : nil
            MetricChip(icon: Image(nsImage: GPUIconHelper.icon(tint: tint, size: NSSize(width: 12, height: 12))).renderingMode(tint == nil ? .template : .original),
                       text: String(format: "%.0f%%", gpuManager.gpuUtilizationPercent),
                       level: gpuManager.isCritical ? .critical : gpuManager.isWarningActive ? .warning : .normal,
                       help: String(format: L.gpuPressureGood, gpuManager.gpuUtilizationPercent))
        }
        if settings.memoryPressureMonitoringEnabled {
            MetricChip(icon: Image(systemName: "memorychip"),
                       text: String(format: "%.0f%%", memoryManager.freeMemoryPercentage * 100),
                       level: memoryManager.isCritical ? .critical : memoryManager.isWarningActive ? .warning : .normal,
                       help: String(format: L.memoryDetail, memoryManager.freeMemoryPercentage * 100,
                                    memoryManager.freeMemoryGB, memoryManager.totalMemoryGB, memoryManager.usedMemoryGB))
        }
        if settings.diskSpaceMonitoringEnabled && diskManager.totalGB > 0 {
            MetricChip(icon: Image(systemName: "externaldrive"),
                       text: String(format: "%.0f GB", diskManager.freeGB),
                       level: diskManager.isCritical ? .critical : diskManager.isWarningActive ? .warning : .normal,
                       help: String(format: L.diskDetail, diskManager.freeGB, diskManager.totalGB))
        }
        if settings.thermalStateMonitoringEnabled {
            MetricChip(icon: Image(systemName: "thermometer"),
                       text: thermalManager.thermalState == .nominal ? "OK" : thermalManager.localizedState,
                       level: thermalManager.isCritical ? .critical : thermalManager.isWarningActive ? .warning : .normal,
                       help: String(format: L.thermalGood, thermalManager.localizedState))
        }
    }

    // MARK: - List

    private struct ProcEntry: Identifiable {
        let pid: pid_t
        let name: String
        let memory: UInt64
        var id: pid_t { pid }
    }

    private struct AppEntry: Identifiable {
        let app: AppInfo
        let memory: UInt64
        let children: [ProcEntry]
        var id: String { app.id }
    }

    private var filteredApps: [AppInfo] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? processManager.runningApps : processManager.runningApps.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private func buildEntries() -> (apps: [AppEntry], orphans: [ProcEntry]) {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        let useMemory = settings.memoryPressureMonitoringEnabled
        let ownPID = ProcessInfo.processInfo.processIdentifier

        var childrenByParent: [pid_t: [pid_t]] = [:]
        if useMemory {
            for (pid, ppid) in memoryManager.processParentPID where pid > 0 {
                childrenByParent[ppid, default: []].append(pid)
            }
        }

        var claimed = Set<pid_t>()
        var apps: [AppEntry] = []
        for app in processManager.runningApps {
            claimed.insert(app.pid)
            let kids: [ProcEntry] = (childrenByParent[app.pid] ?? []).compactMap { pid in
                guard pid != ownPID, let name = memoryManager.processNames[pid], !name.isEmpty else { return nil }
                claimed.insert(pid)
                return ProcEntry(pid: pid, name: name, memory: memoryManager.memoryForPID(pid))
            }.sorted { $0.memory > $1.memory }

            let nameMatches = q.isEmpty || app.name.localizedCaseInsensitiveContains(q)
            let childMatches = !q.isEmpty && kids.contains { $0.name.localizedCaseInsensitiveContains(q) }
            guard nameMatches || childMatches else { continue }
            apps.append(AppEntry(app: app, memory: useMemory ? memoryManager.memoryForPID(app.pid) : 0, children: kids))
        }
        if useMemory { apps.sort { $0.memory > $1.memory } }

        var orphans: [ProcEntry] = []
        if useMemory {
            orphans = memoryManager.processMemoryUsage.compactMap { pid, mem in
                guard pid > 0, pid != ownPID, !claimed.contains(pid), mem > 20 * 1_048_576,
                      !(memoryManager.processIsSystem[pid] ?? false),
                      let name = memoryManager.processNames[pid], !name.isEmpty,
                      q.isEmpty || name.localizedCaseInsensitiveContains(q)
                else { return nil }
                return ProcEntry(pid: pid, name: name, memory: mem)
            }.sorted { $0.memory > $1.memory }
        }
        return (apps, orphans)
    }

    private var appListView: some View {
        let entries = buildEntries()
        let searching = !searchText.trimmingCharacters(in: .whitespaces).isEmpty
        return ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(entries.apps) { entry in
                    let expanded = expandedApps.contains(entry.id) || (searching && entry.children.contains {
                        $0.name.localizedCaseInsensitiveContains(searchText)
                    })
                    appRow(entry, expanded: expanded)
                    if expanded {
                        ForEach(entry.children) { child in
                            ProcessRowView(name: child.name, memory: child.memory, pid: child.pid, indent: true)
                        }
                    }
                }

                if !entries.orphans.isEmpty {
                    SectionLabel(text: L.backgroundProcesses)
                    ForEach(entries.orphans) { proc in
                        ProcessRowView(name: proc.name, memory: proc.memory, pid: proc.pid, indent: false)
                    }
                }

                if entries.apps.isEmpty && entries.orphans.isEmpty {
                    emptyState(searching: searching)
                }
            }
            .padding(.horizontal, AppConstants.listPaddingH)
            .padding(.vertical, 6)
        }
        .frame(maxHeight: .infinity)
    }

    private func appRow(_ entry: AppEntry, expanded: Bool) -> some View {
        let app = entry.app
        return AppRowView(
            app: app,
            isIgnored: processManager.ignoredBundleIdentifiers.contains(app.bundleIdentifier),
            isSelected: processManager.selectedAppIds.contains(app.id),
            isQuitting: processManager.isQuitting(app.id),
            isProtected: processManager.isAutoQuitProtected(app.bundleIdentifier),
            cpuPercent: settings.cpuMonitoringEnabled ? cpuManager.cpuForBundleID(app.bundleIdentifier) : nil,
            memoryUsage: settings.memoryPressureMonitoringEnabled ? entry.memory : nil,
            hasChildren: !entry.children.isEmpty,
            isExpanded: expanded,
            onToggleExpand: {
                if expandedApps.contains(app.id) { expandedApps.remove(app.id) } else { expandedApps.insert(app.id) }
            },
            actions: AppRowActions(
                quit: { force in processManager.quitApp(app, force: force) },
                toggleSelect: { processManager.toggleSelection(app.id) },
                toggleIgnore: { processManager.toggleIgnored(app.bundleIdentifier) },
                toggleProtect: { processManager.toggleAutoQuitProtection(app.bundleIdentifier) },
                toggleHidden: { processManager.toggleHidden(app) },
                reveal: { processManager.revealInFinder(app) },
                activate: { processManager.activate(app); onDismiss() }
            )
        )
    }

    private func emptyState(searching: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: searching ? "magnifyingglass" : "checkmark.circle")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text(searching ? String(format: L.noMatch, searchText) : L.nothingToQuit)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    // MARK: - Footer

    private var footerView: some View {
        let hasSelection = !processManager.selectedAppIds.isEmpty
        let count = processManager.selectedAppIds.count
        return VStack(spacing: 0) {
            Divider()
            VStack(spacing: 8) {
                if hasSelection {
                    HStack(spacing: 6) {
                        Button(action: quitSelected) {
                            Label("\(L.quitSelected) (\(count))", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)

                        Button(action: forceQuitSelected) {
                            Image(systemName: "bolt.fill").frame(width: 14)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .tooltip(L.forceQuit)
                        .accessibilityLabel(L.forceQuit)

                        Button(action: {
                            onDismiss()
                            DispatchQueue.main.async { processManager.minimizeSelectedApps() }
                        }) {
                            Image(systemName: "eye.slash").frame(width: 14)
                        }
                        .buttonStyle(.bordered)
                        .tooltip(L.hide)
                        .accessibilityLabel(L.hide)
                    }
                    .controlSize(.regular)
                } else {
                    HStack(spacing: 8) {
                        Button(action: {
                            onDismiss()
                            DispatchQueue.main.async { processManager.minimizeAllApps() }
                        }) {
                            Label(L.minimizeAll, systemImage: "arrow.down.right.and.arrow.up.left")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tooltip("\(L.minimizeAll)  ⌃⌥⌘M")

                        Button(action: {
                            onDismiss()
                            DispatchQueue.main.async { QuitAllCoordinator.requestQuitAll() }
                        }) {
                            Label("\(L.quitAll) (\(processManager.runningApps.count))", systemImage: "xmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(processManager.runningApps.isEmpty)
                        .tooltip("\(L.quitAll)  ⌃⌥⌘Q")
                    }
                    .controlSize(.regular)
                }

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Label(L.quitCloseAll, systemImage: "power")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: .command)
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, AppConstants.footerPaddingH)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    private func quitSelected() {
        let count = processManager.selectedAppIds.count
        onDismiss()
        DispatchQueue.main.async {
            if !settings.requireQuitConfirmation
                || Confirm.ask(title: L.quitSelectedTitle, message: String(format: L.quitSelectedMessage, count), button: L.quit) {
                processManager.quitSelectedApps(force: false)
            }
        }
    }

    private func forceQuitSelected() {
        let count = processManager.selectedAppIds.count
        onDismiss()
        DispatchQueue.main.async {
            if Confirm.ask(title: L.forceQuitSelectedTitle, message: String(format: L.forceQuitSelectedMessage, count), button: L.forceQuit) {
                processManager.quitSelectedApps(force: true)
            }
        }
    }
}
