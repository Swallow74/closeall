import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var processManager: ProcessManager
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared
    let onBack: () -> Void

    @State private var launchAtLogin = LoginItemsManager.isRegistered
    @State private var showIgnored = false

    @AppStorage(AppConstants.UserDefaultsKeys.memoryPressureThreshold) private var memoryThreshold = AppConstants.defaultMemoryPressureThreshold
    @AppStorage(AppConstants.UserDefaultsKeys.diskSpaceThreshold) private var diskThreshold = AppConstants.defaultDiskSpaceThreshold

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button(action: onBack) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                        Text(L.back)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .keyboardShortcut(.cancelAction)
                Spacer()
                Text(L.settings).font(.system(size: 13, weight: .semibold))
                Spacer()
                Color.clear.frame(width: 44, height: 1)
            }
            .font(.system(size: 12))
            .padding(.horizontal, AppConstants.headerPaddingH)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(spacing: 14) {
                    card(title: L.settingsGeneral, icon: "gearshape") {
                        toggle(L.keyboardShortcuts, hint: "⌃⌥⌘Q  ·  ⌃⌥⌘M", isOn: $settings.keyboardShortcutsEnabled)
                        toggle(L.requireConfirmation, isOn: $settings.requireQuitConfirmation)
                        toggle(L.hideIcon, hint: L.hideIconHint, isOn: $settings.hideMenuBarIcon)
                        toggle(L.launchAtLogin, isOn: Binding(
                            get: { launchAtLogin },
                            set: { launchAtLogin = LoginItemsManager.setRegistered($0) }
                        ))
                    }

                    card(title: L.settingsMonitors, icon: "chart.bar") {
                        toggle(L.memoryMonitoring, isOn: $settings.memoryPressureMonitoringEnabled)
                        if settings.memoryPressureMonitoringEnabled {
                            pickerRow(L.memoryThreshold) {
                                Picker("", selection: $memoryThreshold) {
                                    ForEach([0.10, 0.15, 0.20, 0.25, 0.30], id: \.self) { Text("< \(Int($0 * 100))%").tag($0) }
                                }
                            }
                        }
                        toggle(L.cpuMonitoring, isOn: $settings.cpuMonitoringEnabled)
                        toggle(L.gpuMonitoring, isOn: $settings.gpuMonitoringEnabled)
                        toggle(L.diskMonitoring, isOn: $settings.diskSpaceMonitoringEnabled)
                        if settings.diskSpaceMonitoringEnabled {
                            pickerRow(L.diskThreshold) {
                                Picker("", selection: $diskThreshold) {
                                    ForEach([5.0, 10.0, 20.0, 50.0, 100.0], id: \.self) { Text("< \(Int($0)) GB").tag($0) }
                                }
                            }
                        }
                        toggle(L.thermalMonitoring, isOn: $settings.thermalStateMonitoringEnabled)
                    }

                    card(title: L.settingsAutoFree, icon: "sparkles") {
                        toggle(L.autoFreeMemory, hint: L.autoFreeHint, isOn: $settings.autoFreeMemoryEnabled)
                            .disabled(!settings.memoryPressureMonitoringEnabled)
                        Button(action: { showIgnored.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.slash")
                                Text("\(L.manageIgnored) (\(processManager.ignoredAppNames().count))")
                                Spacer()
                                Image(systemName: showIgnored ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .semibold))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        if showIgnored { ignoredList }
                    }

                    card(title: L.about, icon: "info.circle") {
                        HStack {
                            Text("CloseAll \(version)")
                            Spacer()
                            Button(L.checkForUpdates) { updateChecker.checkForUpdates(manual: true) }
                                .controlSize(.small)
                                .disabled(updateChecker.checking)
                        }
                        if updateChecker.checking {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text(L.checking).foregroundColor(.secondary)
                            }
                        } else if updateChecker.updateAvailable {
                            HStack {
                                Text(String(format: L.updateAvailable, updateChecker.latestVersion)).foregroundColor(.accentColor)
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
                        } else if updateChecker.upToDate {
                            Label(L.upToDate, systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if let err = updateChecker.error {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(AppConstants.headerPaddingH)
            }
        }
    }

    // MARK: - Pieces

    private func card<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title.uppercased(), systemImage: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 9) {
                content()
            }
            .font(.system(size: 12))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08)))
        }
    }

    private func toggle(_ label: String, hint: String? = nil, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                if let hint {
                    Text(hint).font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .contentShape(Rectangle())
        .onTapGesture { isOn.wrappedValue.toggle() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(isOn.wrappedValue ? "1" : "0")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { isOn.wrappedValue.toggle() }
    }

    private func pickerRow<P: View>(_ label: String, @ViewBuilder picker: () -> P) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            picker().labelsHidden().pickerStyle(.menu).fixedSize()
        }
        .padding(.leading, 4)
    }

    private var ignoredList: some View {
        let ignored = processManager.ignoredAppNames()
        return VStack(spacing: 2) {
            if ignored.isEmpty {
                Text(L.noIgnoredApps).foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            ForEach(ignored, id: \.bundleID) { item in
                HStack(spacing: 8) {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleID) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 18, height: 18)
                    }
                    Text(item.name).lineLimit(1)
                    Spacer()
                    Button(L.unignore) { processManager.removeFromIgnored(item.bundleID) }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}
