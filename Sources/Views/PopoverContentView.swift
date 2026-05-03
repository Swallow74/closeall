import SwiftUI
import AppKit

struct PopoverContentView: View {
    @ObservedObject var processManager: ProcessManager
    @StateObject private var settings = AppSettings.shared
    var onDismiss: () -> Void = {}

    @State private var searchText = ""
    @State private var showQuitConfirm = false
    @State private var showForceQuitConfirm = false
    @State private var quitErrors: [QuitError] = []

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            appListView
            Divider()
            settingsSection
            Divider()
            footerView
        }
        .frame(width: AppConstants.popoverWidth, height: AppConstants.popoverHeight)
        .background(Color(NSColor.windowBackgroundColor))
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
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
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
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(filteredApps.count) \(AppConstants.Localizable.appsLabel)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, AppConstants.headerPaddingH)
            .padding(.vertical, 8)

            TextField(AppConstants.Localizable.searchPlaceholder, text: $searchText)
                .font(.system(size: 12))
                .padding(.horizontal, AppConstants.headerPaddingH)
                .padding(.vertical, 6)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
        }
    }

private var appListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredApps) { app in
                    AppRowView(
                        app: app,
                        isIgnored: processManager.ignoredBundleIdentifiers.contains(app.bundleIdentifier),
                        isSelected: processManager.selectedAppIds.contains(app.id),
                        isQuitting: processManager.isQuitting(app.id),
                        onQuit: { force in
                            processManager.quitApp(app, force: force)
                        },
                        onToggleIgnore: {
                            processManager.toggleIgnored(app.bundleIdentifier)
                        },
                        onToggleSelect: {
                            processManager.toggleSelection(app.id)
                        }
                    )
                }

                if filteredApps.isEmpty && !searchText.isEmpty {
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

    private var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return processManager.runningApps
        } else {
            return processManager.runningApps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        DisclosureGroup(isExpanded: $settingsExpanded) {
            VStack(spacing: 6) {
                Toggle(AppConstants.Localizable.keyboardShortcuts, isOn: $settings.keyboardShortcutsEnabled)
                    .font(.system(size: 11))

                Toggle(AppConstants.Localizable.requireConfirmation, isOn: $settings.requireQuitConfirmation)
                    .font(.system(size: 11))

                Toggle(AppConstants.Localizable.hideIcon, isOn: $settings.hideMenuBarIcon)
                    .font(.system(size: 11))

                Toggle(AppConstants.Localizable.launchAtLogin, isOn: $launchAtLogin)
                    .font(.system(size: 11))
                    .onChange(of: launchAtLogin) { newValue in
                        LoginItemsManager.setRegistered(newValue)
                    }
            }
            .padding(.horizontal, AppConstants.headerPaddingH)
        } label: {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                Text("Settings")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Image(systemName: settingsExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                settingsExpanded.toggle()
            }
        }
        .padding(.horizontal, AppConstants.headerPaddingH)
        .padding(.vertical, 8)
    }

    @State private var settingsExpanded = false

    @State private var launchAtLogin: Bool = LoginItemsManager.isRegistered

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button(action: {
                    onDismiss()
                    DispatchQueue.main.async { processManager.minimizeAllApps() }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.square")
                            .font(.system(size: 12))
                        Text(AppConstants.Localizable.minimizeAll)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.plain)

                Button(action: { handleQuitAll() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                        Text(AppConstants.Localizable.quitAll)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.red)
                    .cornerRadius(AppConstants.cornerRadius)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Button(action: {
                    onDismiss()
                    DispatchQueue.main.async { processManager.quitSelectedApps(force: false) }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 11))
                        Text("\(AppConstants.Localizable.quitSelected) (\(processManager.selectedAppIds.count))")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(AppConstants.cornerRadius)
                }
                .buttonStyle(.plain)
                .disabled(processManager.selectedAppIds.isEmpty)

                Button(action: {
                    onDismiss()
                    DispatchQueue.main.async { processManager.quitSelectedApps(force: true) }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.octagon.fill")
                            .font(.system(size: 11))
                        Text(AppConstants.Localizable.force)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(AppConstants.cornerRadius)
                }
                .buttonStyle(.plain)
                .disabled(processManager.selectedAppIds.isEmpty)
            }

            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10))
                    Text(AppConstants.Localizable.quitCloseAll)
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppConstants.footerPaddingH)
        .padding(.vertical, 8)
    }

    private func handleQuitAll() {
        onDismiss()
        if settings.requireQuitConfirmation {
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
