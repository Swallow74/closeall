import Foundation
import AppKit
import UserNotifications
import Combine

final class ThermalStateManager: ObservableObject {
    static let shared = ThermalStateManager()

    @Published private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    @Published private(set) var isWarningActive = false
    @Published private(set) var isCritical = false

    var localizedState: String {
        switch thermalState {
        case .nominal:  return AppConstants.Localizable.thermalStateNominal
        case .fair:     return AppConstants.Localizable.thermalStateFair
        case .serious:  return AppConstants.Localizable.thermalStateSerious
        case .critical: return AppConstants.Localizable.thermalStateCritical
        @unknown default: return "Unknown"
        }
    }

    private var hasPostedWarning = false
    private var cancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        thermalState = ProcessInfo.processInfo.thermalState

        AppSettings.shared.$thermalStateMonitoringEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if !enabled {
                    self?.resetState()
                } else {
                    self?.checkAndNotify()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func thermalStateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let newState = ProcessInfo.processInfo.thermalState
            let wasCritical = self.isCritical
            self.thermalState = newState
            self.isWarningActive = newState == .serious || newState == .critical
            self.isCritical = newState == .critical
            if AppSettings.shared.thermalStateMonitoringEnabled {
                self.checkAndNotify(wasCritical: wasCritical)
            }
        }
    }

    private func checkAndNotify(wasCritical: Bool = false) {
        if isWarningActive && !hasPostedWarning {
            hasPostedWarning = true
            postNotification()
        }
        if !isWarningActive {
            hasPostedWarning = false
        }
    }

    private func resetState() {
        hasPostedWarning = false
    }

    private func postNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Thermal Warning"
            content.body = String(
                format: "System thermal state is %@",
                self.localizedState
            )
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "thermal-state-warning",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
