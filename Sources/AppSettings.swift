import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var keyboardShortcutsEnabled: Bool {
        didSet { UserDefaults.standard.set(keyboardShortcutsEnabled, forKey: AppConstants.UserDefaultsKeys.keyboardShortcuts) }
    }

    @Published var requireQuitConfirmation: Bool {
        didSet { UserDefaults.standard.set(requireQuitConfirmation, forKey: AppConstants.UserDefaultsKeys.requireConfirmation) }
    }

    @Published var hideMenuBarIcon: Bool {
        didSet { UserDefaults.standard.set(hideMenuBarIcon, forKey: AppConstants.UserDefaultsKeys.hideMenuBarIcon) }
    }

    @Published var memoryPressureMonitoringEnabled: Bool {
        didSet { UserDefaults.standard.set(memoryPressureMonitoringEnabled, forKey: AppConstants.UserDefaultsKeys.memoryPressure) }
    }

    @Published var thermalStateMonitoringEnabled: Bool {
        didSet { UserDefaults.standard.set(thermalStateMonitoringEnabled, forKey: AppConstants.UserDefaultsKeys.thermalState) }
    }

    @Published var diskSpaceMonitoringEnabled: Bool {
        didSet { UserDefaults.standard.set(diskSpaceMonitoringEnabled, forKey: AppConstants.UserDefaultsKeys.diskSpace) }
    }

    @Published var cpuMonitoringEnabled: Bool {
        didSet { UserDefaults.standard.set(cpuMonitoringEnabled, forKey: AppConstants.UserDefaultsKeys.cpuMonitoring) }
    }

    @Published var gpuMonitoringEnabled: Bool {
        didSet { UserDefaults.standard.set(gpuMonitoringEnabled, forKey: AppConstants.UserDefaultsKeys.gpuMonitoring) }
    }

    @Published var autoFreeMemoryEnabled: Bool {
        didSet { UserDefaults.standard.set(autoFreeMemoryEnabled, forKey: AppConstants.UserDefaultsKeys.autoFreeMemory) }
    }

    var memoryPressureThreshold: Double {
        UserDefaults.standard.double(forKey: AppConstants.UserDefaultsKeys.memoryPressureThreshold)
    }

    var diskSpaceThreshold: Double {
        let val = UserDefaults.standard.double(forKey: AppConstants.UserDefaultsKeys.diskSpaceThreshold)
        return val > 0 ? val : AppConstants.defaultDiskSpaceThreshold
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        UserDefaults.standard.register(defaults: [
            AppConstants.UserDefaultsKeys.keyboardShortcuts: true,
            AppConstants.UserDefaultsKeys.requireConfirmation: false,
            AppConstants.UserDefaultsKeys.hideMenuBarIcon: false,
            AppConstants.UserDefaultsKeys.memoryPressure: true,
            AppConstants.UserDefaultsKeys.memoryPressureThreshold: AppConstants.defaultMemoryPressureThreshold,
            AppConstants.UserDefaultsKeys.thermalState: false,
            AppConstants.UserDefaultsKeys.diskSpace: false,
            AppConstants.UserDefaultsKeys.diskSpaceThreshold: AppConstants.defaultDiskSpaceThreshold,
            AppConstants.UserDefaultsKeys.cpuMonitoring: false,
            AppConstants.UserDefaultsKeys.gpuMonitoring: false,
            AppConstants.UserDefaultsKeys.autoFreeMemory: false,
        ])
        
        keyboardShortcutsEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.keyboardShortcuts)
        requireQuitConfirmation = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.requireConfirmation)
        hideMenuBarIcon = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.hideMenuBarIcon)
        memoryPressureMonitoringEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.memoryPressure)
        thermalStateMonitoringEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.thermalState)
        diskSpaceMonitoringEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.diskSpace)
        cpuMonitoringEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.cpuMonitoring)
        gpuMonitoringEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.gpuMonitoring)
        autoFreeMemoryEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.autoFreeMemory)

        Publishers.CombineLatest3(
            $keyboardShortcutsEnabled,
            $requireQuitConfirmation,
            $hideMenuBarIcon
        )
        .dropFirst()
        .sink { _, _, _ in
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        .store(in: &cancellables)
    }

    func reload() {
        keyboardShortcutsEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.keyboardShortcuts)
        requireQuitConfirmation = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.requireConfirmation)
        hideMenuBarIcon = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.hideMenuBarIcon)
        memoryPressureMonitoringEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.memoryPressure)
        thermalStateMonitoringEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.thermalState)
        diskSpaceMonitoringEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.diskSpace)
        cpuMonitoringEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.cpuMonitoring)
        gpuMonitoringEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.gpuMonitoring)
        autoFreeMemoryEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.autoFreeMemory)
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}
