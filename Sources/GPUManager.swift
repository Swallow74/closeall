import Foundation
import AppKit
import IOKit
import UserNotifications

final class GPUManager: ObservableObject {
    static let shared = GPUManager()

    @Published private(set) var gpuUtilizationPercent: Double = 0
    @Published private(set) var isWarningActive = false
    @Published private(set) var isCritical = false

    private var timer: Timer?
    private var hasPostedWarning = false

    private init() {
        timer = Timer.scheduledTimer(withTimeInterval: AppConstants.gpuCheckInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    deinit {
        timer?.invalidate()
    }

    private func refresh() {
        guard UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.gpuMonitoring) else {
            let hadWarning = isWarningActive
            if gpuUtilizationPercent != 0 || hadWarning {
                DispatchQueue.main.async { [weak self] in
                    self?.gpuUtilizationPercent = 0
                    self?.isWarningActive = false
                    self?.isCritical = false
                    self?.hasPostedWarning = false
                }
            }
            return
        }

        let util = readGPUtilization()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.gpuUtilizationPercent = util

            let wasWarning = self.isWarningActive
            self.isWarningActive = util > 70
            self.isCritical = util > 90

            if self.isWarningActive && !wasWarning && !self.hasPostedWarning {
                self.hasPostedWarning = true
                self.postWarningNotification()
            }

            if !self.isWarningActive {
                self.hasPostedWarning = false
            }
        }
    }

    private func readGPUtilization() -> Double {
        let matching = IOServiceMatching("AGXAccelerator")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return 0
        }
        defer { IOObjectRelease(iterator) }

        var totalUtil: Double = 0
        var count: Double = 0

        var service: io_object_t = IOIteratorNext(iterator)
        while service != 0 {
            if let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                if let devUtil = stats["Device Utilization %"] as? Int {
                    totalUtil += Double(devUtil)
                    count += 1
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        return count > 0 ? totalUtil / count : 0
    }

    private func postWarningNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "High GPU Usage Warning"
            content.body = String(
                format: "GPU usage is at %.0f%%",
                self.gpuUtilizationPercent
            )
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "gpu-usage-warning",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
