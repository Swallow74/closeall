import Foundation
import AppKit
import UserNotifications
import Combine

final class MemoryPressureManager: ObservableObject {
    static let shared = MemoryPressureManager()

    @Published private(set) var freeMemoryPercentage: Double = 1.0
    @Published private(set) var isWarningActive = false
    @Published private(set) var isCritical = false
    @Published private(set) var freeMemoryGB: Double = 0.0
    @Published private(set) var totalMemoryGB: Double = 0.0
    @Published private(set) var appMemoryUsage: [String: UInt64] = [:]
    @Published private(set) var processMemoryUsage: [pid_t: UInt64] = [:]
    @Published private(set) var processNames: [pid_t: String] = [:]
    @Published private(set) var processIsSystem: [pid_t: Bool] = [:]
    @Published private(set) var processParentPID: [pid_t: pid_t] = [:]

    var usedMemoryGB: Double {
        totalMemoryGB - freeMemoryGB
    }

    private var timer: Timer?
    private var hasPostedWarning = false
    private var hasAutoFreed = false
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

        AppSettings.shared.$autoFreeMemoryEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if !enabled {
                    self?.hasAutoFreed = false
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
        let (perApp, perPID) = collectPerAppMemory()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.freeMemoryPercentage = free
            self.freeMemoryGB = freeGB
            self.totalMemoryGB = totalGB
            self.appMemoryUsage = perApp
            self.processMemoryUsage = perPID
            let (names, system, ppid) = collectAllProcessInfo()
            self.processNames = names
            self.processIsSystem = system
            self.processParentPID = ppid

            let threshold = AppSettings.shared.memoryPressureThreshold
            let wasWarning = self.isWarningActive
            let wasCritical = self.isCritical
            self.isWarningActive = free < threshold
            self.isCritical = free < 0.1

            if self.isWarningActive && !wasWarning && !self.hasPostedWarning {
                self.hasPostedWarning = true
                self.postWarningNotification()
                if AppSettings.shared.autoFreeMemoryEnabled && !self.hasAutoFreed {
                    self.hasAutoFreed = true
                    self.performAutoFree()
                }
            }

            if !self.isWarningActive {
                self.hasPostedWarning = false
                self.hasAutoFreed = false
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

    private func collectPerAppMemory() -> (byBundle: [String: UInt64], byPID: [pid_t: UInt64]) {
        var byBundle: [String: UInt64] = [:]
        var byPID: [pid_t: UInt64] = [:]
        let bufSize = max(Int(proc_listallpids(nil, 0)), 4096)
        var pidBuffer = [pid_t](repeating: 0, count: bufSize)
        let count = proc_listallpids(&pidBuffer, Int32(MemoryLayout<pid_t>.size) * Int32(pidBuffer.count))
        guard count > 0 else { return (byBundle, byPID) }
        for i in 0..<Int(count) {
            let pid = pidBuffer[i]
            guard pid > 0 else { continue }
            var taskInfo = proc_taskinfo()
            let size = MemoryLayout<proc_taskinfo>.size
            if proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(size)) == size {
                byPID[pid] = taskInfo.pti_resident_size
            }
        }
        for app in NSWorkspace.shared.runningApplications {
            if let bundleID = app.bundleIdentifier, let mem = byPID[app.processIdentifier] {
                byBundle[bundleID] = mem
            }
        }
        return (byBundle, byPID)
    }

    private func collectAllProcessInfo() -> (names: [pid_t: String], isSystem: [pid_t: Bool], parentPID: [pid_t: pid_t]) {
        var names: [pid_t: String] = [:]
        var isSystem: [pid_t: Bool] = [:]
        var ppid: [pid_t: pid_t] = [:]
        let bufSize = max(Int(proc_listallpids(nil, 0)), 4096)
        var pidBuffer = [pid_t](repeating: 0, count: bufSize)
        let count = proc_listallpids(&pidBuffer, Int32(MemoryLayout<pid_t>.size) * Int32(pidBuffer.count))
        guard count > 0 else { return (names, isSystem, ppid) }
        for i in 0..<Int(count) {
            let pid = pidBuffer[i]
            guard pid > 0 else { continue }
            var pathBuffer = [CChar](repeating: 0, count: 4096)
            let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            if pathLen > 0 {
                let path = String(cString: pathBuffer)
                names[pid] = (path as NSString).lastPathComponent
                isSystem[pid] = path.hasPrefix("/System/")
            } else {
                var nameBuffer = [CChar](repeating: 0, count: 64)
                proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
                let name = String(cString: nameBuffer).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    names[pid] = name
                }
                isSystem[pid] = false
            }
            var allInfo = proc_taskallinfo()
            let infoSize = MemoryLayout<proc_taskallinfo>.size
            if proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &allInfo, Int32(infoSize)) == infoSize {
                ppid[pid] = pid_t(allInfo.pbsd.pbi_ppid)
            }
        }
        return (names, isSystem, ppid)
    }

    func memoryForBundleID(_ bundleID: String) -> UInt64 {
        appMemoryUsage[bundleID] ?? 0
    }

    func memoryForPID(_ pid: pid_t) -> UInt64 {
        processMemoryUsage[pid] ?? 0
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

    private func performAutoFree() {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        var freedCount = 0
        var freedBytes: UInt64 = 0

        let pm = ProcessManager.shared
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  let bundleID = app.bundleIdentifier,
                  bundleID != ownBundleID,
                  bundleID != AppConstants.BundleIdentifiers.finder,
                  bundleID != frontApp?.bundleIdentifier,
                  !pm.ignoredBundleIdentifiers.contains(bundleID),
                  !pm.autoQuitProtectedBundleIdentifiers.contains(bundleID)
            else { continue }

            var task: mach_port_name_t = 0
            if task_for_pid(mach_task_self_, app.processIdentifier, &task) == KERN_SUCCESS {
                var info = task_basic_info_64_data_t()
                var count = mach_msg_type_number_t(
                    MemoryLayout<task_basic_info_64_data_t>.size / MemoryLayout<natural_t>.size
                )
                if withUnsafeMutablePointer(to: &info, {
                    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                        task_info(task, task_flavor_t(TASK_BASIC_INFO_64), $0, &count)
                    }
                }) == KERN_SUCCESS {
                    freedBytes += UInt64(info.resident_size)
                }
                mach_port_deallocate(mach_task_self_, task)
            }

            app.terminate()
            freedCount += 1
        }

        if freedCount > 0 {
            let freedMB = Double(freedBytes) / 1_048_576
            postAutoFreeNotification(count: freedCount, freedMB: freedMB)
        }
    }

    private func postAutoFreeNotification(count: Int, freedMB: Double) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Memory Auto-Freed"
            content.body = String(
                format: "Quit %d app(s), freed %.0f MB of memory",
                count, freedMB
            )
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "auto-free-memory",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
