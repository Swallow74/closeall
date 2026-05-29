import Foundation
import AppKit
import UserNotifications
import Combine

final class MemoryPressureManager: ObservableObject {
    static let shared = MemoryPressureManager()

    @Published private(set) var freeMemoryPercentage: Double = 1.0
    @Published private(set) var isWarningActive = false
    @Published private(set) var freeMemoryGB: Double = 0.0
    @Published private(set) var totalMemoryGB: Double = 0.0

    private var timer: Timer?
    private var hasPostedWarning = false
    private var cancellables = Set<AnyCancellable>()

    private init() {
        AppSettings.shared.$memoryPressureMonitoringEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if enabled {
                    self?.startMonitoring()
                } else {
                    self?.stopMonitoring()
                }
            }
            .store(in: &cancellables)

        if AppSettings.shared.memoryPressureMonitoringEnabled {
            startMonitoring()
        }
    }

    func startMonitoring() {
        timer?.invalidate()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        DispatchQueue.main.async {
            self.freeMemoryPercentage = 1.0
            self.isWarningActive = false
            self.hasPostedWarning = false
        }
    }

    private func refresh() {
        let (free, freeGB, totalGB) = freeMemoryInfo()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.freeMemoryPercentage = free
            self.freeMemoryGB = freeGB
            self.totalMemoryGB = totalGB

            let threshold = AppSettings.shared.memoryPressureThreshold
            let wasWarning = self.isWarningActive
            self.isWarningActive = free < threshold

            if self.isWarningActive && !wasWarning && !self.hasPostedWarning {
                self.hasPostedWarning = true
                self.postWarningNotification()
            }

            if !self.isWarningActive {
                self.hasPostedWarning = false
            }
        }
    }

    private func freeMemoryInfo() -> (percentage: Double, freeGB: Double, totalGB: Double) {
        let pageSize = Double(vm_page_size)
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (1.0, 0, 0)
        }

        let totalPages = Double(vmStats.active_count + vmStats.inactive_count + vmStats.wire_count + vmStats.free_count + vmStats.compressor_page_count)
        let availablePages = Double(vmStats.free_count + vmStats.inactive_count + vmStats.purgeable_count)

        let totalBytes = totalPages * pageSize
        let freeBytes = availablePages * pageSize

        let percentage = totalPages > 0 ? availablePages / totalPages : 1.0
        let freeGB = freeBytes / 1_073_741_824
        let totalGB = totalBytes / 1_073_741_824

        return (min(percentage, 1.0), freeGB, totalGB)
    }

    private func postWarningNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Low Memory Warning"
            content.body = String(
                format: "Free memory is at %.0f%% (%.1f GB / %.1f GB)",
                self.freeMemoryPercentage * 100,
                self.freeMemoryGB,
                self.totalMemoryGB
            )
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "memory-pressure-warning",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
