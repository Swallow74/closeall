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
    private var previousTaskCPU: [String: UInt64] = [:]
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

    private let queue = DispatchQueue(label: "closeall.cpu", qos: .utility)

    func startMonitoring() {
        timer?.invalidate()
        queue.async { [weak self] in
            self?.previousTicks = nil
            self?.previousTaskCPU = [:]
            self?.previousSampleTime = Date()
        }
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
        var bundleByPID: [pid_t: String] = [:]
        for app in NSWorkspace.shared.runningApplications {
            if let id = app.bundleIdentifier, app.processIdentifier > 0 { bundleByPID[app.processIdentifier] = id }
        }
        queue.async { [weak self] in
            guard let self = self else { return }
            let now = Date()
            let elapsed = now.timeIntervalSince(self.previousSampleTime)
            guard elapsed >= 0.5 else { return }
            self.previousSampleTime = now

            let cpuPercent = self.computeGlobalCPU()
            let perApp = self.computeAppCPU(elapsed: elapsed, bundleByPID: bundleByPID)
            DispatchQueue.main.async { self.publish(cpuPercent: cpuPercent, perApp: perApp) }
        }
    }

    private func publish(cpuPercent: Double, perApp: [String: Double]) {
        globalCPUPercent = cpuPercent
        appCPUUsage = perApp

        let wasWarning = isWarningActive
        isWarningActive = cpuPercent > 80
        isCritical = cpuPercent > 95

        if isWarningActive && !wasWarning && !hasPostedWarning {
            hasPostedWarning = true
            postWarningNotification()
        }
        if !isWarningActive {
            hasPostedWarning = false
        }
    }

    private func computeGlobalCPU() -> Double {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        defer { previousTicks = cpuLoad }
        guard let prev = previousTicks else { return 0 }

        let user = Double(cpuLoad.cpu_ticks.0 &- prev.cpu_ticks.0)
        let system = Double(cpuLoad.cpu_ticks.1 &- prev.cpu_ticks.1)
        let idle = Double(cpuLoad.cpu_ticks.2 &- prev.cpu_ticks.2)
        let nice = Double(cpuLoad.cpu_ticks.3 &- prev.cpu_ticks.3)
        let total = user + system + idle + nice
        return total > 0 ? (user + system + nice) / total * 100 : 0
    }

    /// Per-app CPU % (100 = one core), counting the app's whole process tree (helpers, renderers…).
    private func computeAppCPU(elapsed: TimeInterval, bundleByPID: [pid_t: String]) -> [String: Double] {
        let snaps = ProcessScanner.scan(withNames: false)
        let owners = ProcessScanner.owners(of: snaps, roots: Set(bundleByPID.keys))
        var totals: [String: UInt64] = [:]
        for s in snaps {
            if let root = owners[s.pid], let id = bundleByPID[root] { totals[id, default: 0] &+= s.cpuNS }
        }
        defer { previousTaskCPU = totals }
        var usage: [String: Double] = [:]
        let elapsedNS = elapsed * 1_000_000_000
        for (id, cur) in totals {
            if let prev = previousTaskCPU[id], cur >= prev, elapsedNS > 0 {
                usage[id] = Double(cur - prev) / elapsedNS * 100
            }
        }
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
            content.title = loc("High CPU Usage Warning")
            content.body = String(
                format: loc("CPU usage is at %.0f%%"),
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
