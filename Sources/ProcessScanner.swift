import Foundation
import Darwin

struct ProcSnapshot {
    let pid: pid_t
    let ppid: pid_t
    let name: String
    let isSystem: Bool
    let resident: UInt64
    let cpuNS: UInt64
}

/// Reads every process via libproc. Works without task_for_pid (no root/entitlement needed).
enum ProcessScanner {
    private static let timebase: mach_timebase_info_data_t = {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return tb
    }()

    static func scan(withNames: Bool) -> [ProcSnapshot] {
        let estimate = Int(proc_listallpids(nil, 0))
        var pids = [pid_t](repeating: 0, count: max(estimate * 2, 4096))
        let count = Int(proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count)))
        guard count > 0 else { return [] }

        var out: [ProcSnapshot] = []
        out.reserveCapacity(count)
        let infoSize = Int32(MemoryLayout<proc_taskallinfo>.size)
        var pathBuffer = [CChar](repeating: 0, count: 4096)

        for i in 0..<count {
            let pid = pids[i]
            guard pid > 0 else { continue }
            var info = proc_taskallinfo()
            guard proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, infoSize) == infoSize else { continue }

            var name = ""
            var isSystem = false
            if withNames {
                if proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 {
                    let path = String(cString: pathBuffer)
                    name = (path as NSString).lastPathComponent
                    isSystem = path.hasPrefix("/System/")
                } else {
                    name = withUnsafePointer(to: info.pbsd.pbi_comm) {
                        $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: info.pbsd.pbi_comm)) {
                            String(cString: $0)
                        }
                    }
                }
            }

            let ticks = info.ptinfo.pti_total_user &+ info.ptinfo.pti_total_system
            let ns = ticks &* UInt64(timebase.numer) / UInt64(max(timebase.denom, 1))
            out.append(ProcSnapshot(
                pid: pid,
                ppid: pid_t(info.pbsd.pbi_ppid),
                name: name,
                isSystem: isSystem,
                resident: info.ptinfo.pti_resident_size,
                cpuNS: ns
            ))
        }
        return out
    }

    static func residentSize(of pid: pid_t) -> UInt64 {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        return proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size ? info.pti_resident_size : 0
    }

    /// Maps every process to the closest ancestor in `roots` (or itself).
    static func owners(of snapshots: [ProcSnapshot], roots: Set<pid_t>) -> [pid_t: pid_t] {
        let parent = Dictionary(snapshots.map { ($0.pid, $0.ppid) }, uniquingKeysWith: { a, _ in a })
        var result: [pid_t: pid_t] = [:]
        for snap in snapshots {
            var cur = snap.pid
            var hops = 0
            while hops < 32 {
                if roots.contains(cur) { result[snap.pid] = cur; break }
                guard let p = parent[cur], p > 1, p != cur else { break }
                cur = p
                hops += 1
            }
        }
        return result
    }
}
