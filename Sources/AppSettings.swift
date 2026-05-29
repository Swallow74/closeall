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

    var memoryPressureThreshold: Double {
        UserDefaults.standard.double(forKey: AppConstants.UserDefaultsKeys.memoryPressureThreshold)
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        UserDefaults.standard.register(defaults: [
            AppConstants.UserDefaultsKeys.keyboardShortcuts: true,
            AppConstants.UserDefaultsKeys.requireConfirmation: false,
            AppConstants.UserDefaultsKeys.hideMenuBarIcon: false,
            AppConstants.UserDefaultsKeys.memoryPressure: true,
            AppConstants.UserDefaultsKeys.memoryPressureThreshold: AppConstants.defaultMemoryPressureThreshold,
        ])
        
        keyboardShortcutsEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.keyboardShortcuts)
        requireQuitConfirmation = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.requireConfirmation)
        hideMenuBarIcon = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.hideMenuBarIcon)
        memoryPressureMonitoringEnabled = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.memoryPressure)

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
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}
