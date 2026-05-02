import SwiftUI
import AppKit

struct PopoverContentView: View {
    @ObservedObject var processManager: ProcessManager
    @State private var searchText = ""
    @State private var showQuitConfirm = false
    @State private var showForceQuitConfirm = false
    @State private var quitErrors: [QuitError] = []

    private var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return processManager.runningApps
        } else {
            return processManager.runningApps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var filteredSelectedCount: Int {
        filteredApps.filter { processManager.selectedAppIds.contains($0.id) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            appListView
            Divider()
            settingsView
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
        .alert(
            "Quit Failed",
            isPresented: Binding(
                get: { !quitErrors.isEmpty },
                set: { if !$0 { quitErrors.removeAll() } }
            )
        ) {
            Button("OK") { quitErrors.removeAll() }
        } message: {
            Text(quitErrors.map { $0.message }.joined(separator: "\n"))
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

                Text("\(processManager.runningApps.count) \(AppConstants.Localizable.appsLabel) • \(processManager.selectedAppIds.count) \(AppConstants.Localizable.selectedLabel)")
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

    private var settingsView: some View {
        HStack(spacing: 16) {
            Toggle(AppConstants.Localizable.launchAtLogin, isOn: $launchAtLogin)
                .font(.system(size: 11))
                .onChange(of: launchAtLogin) { newValue in
                    LoginItemsManager.setRegistered(newValue)
                }

            Spacer()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                    Text(AppConstants.Localizable.quitCloseAll)
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppConstants.headerPaddingH)
        .padding(.vertical, 8)
    }

    @State private var launchAtLogin: Bool = LoginItemsManager.isRegistered

    private var footerView: some View {
        HStack(spacing: 12) {
            Button(action: {
                showQuitConfirm = true
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("\(AppConstants.Localizable.quitSelected) (\(processManager.selectedAppIds.count))")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(AppConstants.cornerRadius)
            }
            .buttonStyle(.plain)
            .disabled(processManager.selectedAppIds.isEmpty)

            Button(action: {
                showForceQuitConfirm = true
            }) {
                HStack {
                    Image(systemName: "xmark.octagon.fill")
                    Text(AppConstants.Localizable.force)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.orange)
                .cornerRadius(AppConstants.cornerRadius)
            }
            .buttonStyle(.plain)
            .disabled(processManager.selectedAppIds.isEmpty)
        }
        .padding(.horizontal, AppConstants.footerPaddingH)
        .padding(.vertical, AppConstants.footerPaddingV)
    }

    private func performQuitSelected(force: Bool) {
        let errors = processManager.quitSelectedApps(force: force)
        if !errors.isEmpty {
            quitErrors = errors
        }
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
