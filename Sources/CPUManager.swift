import Foundation
import AppKit
import UserNotifications
import Combine

final class CPUManager: ObservableObject {
    static let shared = CPUManager()

    @Published private(set) var globalCPUPercent: Double = 0
    @Published private(set) var appCPUUsage: [String: Double] = [:]  // bundleID -> CPU%
    @Published private(set) var isWarningActive = false
    @Published private(set) var isCritical = false

    private var timer: Timer?
    private var previousTicks: host_cpu_load_info?
    private var previousSampleTime = Date()
    private var previousTaskInfos: [String: (user: UInt64, system: UInt64)] = [:]
    private var hasPostedWarning = false
    private var cancellables = Set<AnyCancellable>()

    private init() {
        AppSettings.shared.$cpuMonitoringEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if enabled {
                    self?.startMonitoring()
                } else {
                    self?.stopMonitoring()
                }
            }
            .store(in: &cancellables)

        if AppSettings.shared.cpuMonitoringEnabled {
            startMonitoring()
        }
    }

    func startMonitoring() {
        timer?.invalidate()
        previousTicks = nil
        previousSampleTime = Date()
        previousTaskInfos = [:]
        appCPUUsage = [:]
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: AppConstants.cpuCheckInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        DispatchQueue.main.async {
            self.globalCPUPercent = 0
            self.appCPUUsage = [:]
            self.isWarningActive = false
            self.isCritical = false
            self.hasPostedWarning = false
        }
    }

    private func refresh() {
        let now = Date()
        let elapsed = now.timeIntervalSince(previousSampleTime)
        guard elapsed >= 0.5 else { return }

        let cpuPercent = computeGlobalCPU(elapsed: elapsed)
        let perApp = computeAppCPU(elapsed: elapsed)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.globalCPUPercent = cpuPercent
            self.appCPUUsage = perApp

            let wasWarning = self.isWarningActive
            self.isWarningActive = cpuPercent > 80
            self.isCritical = cpuPercent > 95

            if self.isWarningActive && !wasWarning && !self.hasPostedWarning {
                self.hasPostedWarning = true
                self.postWarningNotification()
            }

            if !self.isWarningActive {
                self.hasPostedWarning = false
            }
        }

        previousSampleTime = now
    }

    private func computeGlobalCPU(elapsed: TimeInterval) -> Double {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        if let prev = previousTicks {
            let userDelta = Double(cpuLoad.cpu_ticks.0 - prev.cpu_ticks.0)
            let systemDelta = Double(cpuLoad.cpu_ticks.1 - prev.cpu_ticks.1)
            let niceDelta = Double(cpuLoad.cpu_ticks.3 - prev.cpu_ticks.3)
            let idleDelta = Double(cpuLoad.cpu_ticks.2 - prev.cpu_ticks.2)
            let totalDelta = userDelta + systemDelta + niceDelta + idleDelta
            if totalDelta > 0 {
                previousTicks = cpuLoad
                return ((userDelta + systemDelta + niceDelta) / totalDelta) * 100
            }
        }

        previousTicks = cpuLoad
        return 0
    }

    private func computeAppCPU(elapsed: TimeInterval) -> [String: Double] {
        var newInfos: [String: (user: UInt64, system: UInt64)] = [:]
        var usage: [String: Double] = [:]

        for app in NSWorkspace.shared.runningApplications {
            let pid = app.processIdentifier
            guard let bundleID = app.bundleIdentifier, pid > 0
            else { continue }

            var task: mach_port_name_t = 0
            let kr = task_for_pid(mach_task_self_, pid, &task)
            guard kr == KERN_SUCCESS else { continue }

            var info = task_basic_info_data_t()
            var count = mach_msg_type_number_t(
                MemoryLayout<task_basic_info_data_t>.size / MemoryLayout<natural_t>.size
            )
            let kr2 = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    task_info(task, task_flavor_t(TASK_BASIC_INFO), $0, &count)
                }
            }
            guard kr2 == KERN_SUCCESS else {
                mach_port_deallocate(mach_task_self_, task)
                continue
            }

            let userNS = UInt64(info.user_time.seconds) * 1_000_000_000
                       + UInt64(info.user_time.microseconds) * 1_000
            let systemNS = UInt64(info.system_time.seconds) * 1_000_000_000
                         + UInt64(info.system_time.microseconds) * 1_000
            newInfos[bundleID] = (userNS, systemNS)
            mach_port_deallocate(mach_task_self_, task)
        }

        let elapsedNS = elapsed * 1_000_000_000
        for (bundleID, current) in newInfos {
            if let prev = previousTaskInfos[bundleID], elapsedNS > 0 {
                let userDelta = current.user > prev.user ? Double(current.user - prev.user) : 0
                let systemDelta = current.system > prev.system ? Double(current.system - prev.system) : 0
                let pct = ((userDelta + systemDelta) / elapsedNS) * 100
                if pct >= 0 && pct <= 100 {
                    usage[bundleID] = pct
                }
            }
        }

        previousTaskInfos = newInfos
        return usage
    }

    func cpuForBundleID(_ bundleID: String) -> Double {
        appCPUUsage[bundleID] ?? 0
    }

    private func postWarningNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "High CPU Usage Warning"
            content.body = String(
                format: "CPU usage is at %.0f%%",
                self.globalCPUPercent
            )
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "cpu-usage-warning",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
