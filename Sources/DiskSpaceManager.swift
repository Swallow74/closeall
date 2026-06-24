import Foundation
import AppKit
import UserNotifications
import Combine

final class DiskSpaceManager: ObservableObject {
    static let shared = DiskSpaceManager()

    @Published private(set) var freeGB: Double = 0
    @Published private(set) var totalGB: Double = 0
    @Published private(set) var isWarningActive = false
    @Published private(set) var isCritical = false

    var freePercentage: Double {
        totalGB > 0 ? min(freeGB / totalGB, 1.0) : 1.0
    }

    var usedGB: Double {
        totalGB - freeGB
    }

    private var timer: Timer?
    private var hasPostedWarning = false
    private var cancellables = Set<AnyCancellable>()

    private init() {
        AppSettings.shared.$diskSpaceMonitoringEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if enabled {
                    self?.startMonitoring()
                } else {
                    self?.stopMonitoring()
                }
            }
            .store(in: &cancellables)

        if AppSettings.shared.diskSpaceMonitoringEnabled {
            startMonitoring()
        }
    }

    func startMonitoring() {
        timer?.invalidate()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: AppConstants.diskSpaceCheckInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        DispatchQueue.main.async {
            self.freeGB = 0
            self.totalGB = 0
            self.isWarningActive = false
            self.isCritical = false
            self.hasPostedWarning = false
        }
    }

    private func refresh() {
        let (free, total) = diskInfo()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.freeGB = free
            self.totalGB = total

            let threshold = AppSettings.shared.diskSpaceThreshold
            let wasWarning = self.isWarningActive
            self.isWarningActive = free < threshold
            self.isCritical = free < threshold / 2

            if self.isWarningActive && !wasWarning && !self.hasPostedWarning {
                self.hasPostedWarning = true
                self.postWarningNotification()
            }

            if !self.isWarningActive {
                self.hasPostedWarning = false
            }
        }
    }

    private func diskInfo() -> (free: Double, total: Double) {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        guard let path = paths.first else { return (0, 0) }

        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: path)
            let free = (attrs[.systemFreeSize] as? NSNumber)?.doubleValue ?? 0
            let total = (attrs[.systemSize] as? NSNumber)?.doubleValue ?? 0
            return (free / 1_073_741_824, total / 1_073_741_824)
        } catch {
            return (0, 0)
        }
    }

    private func postWarningNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Low Disk Space Warning"
            content.body = String(
                format: "Free disk space: %.1f GB (%.0f%% of %.0f GB)",
                self.freeGB,
                self.freePercentage * 100,
                self.totalGB
            )
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "disk-space-warning",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
