import SwiftUI

final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var updateAvailable = false
    @Published var latestVersion = ""
    @Published var downloadURL = ""
    @Published var checking = false
    @Published var installing = false
    @Published var error: String?
    @Published var upToDate = false
    private var zipURL: URL?

    /// In-app install possible: release has a .zip and the running copy's folder is writable.
    var canInstall: Bool {
        let bundle = Bundle.main.bundleURL
        return zipURL != nil && bundle.pathExtension == "app"
            && FileManager.default.isWritableFile(atPath: bundle.deletingLastPathComponent().path)
    }

    /// Downloads the zip, checks it is this same app and newer, swaps the bundle after quitting, relaunches.
    func install() {
        guard let zip = zipURL, !installing else { return }
        installing = true
        func fail(_ why: String) {
            DispatchQueue.main.async {
                self.installing = false
                self.error = why
                if let u = URL(string: self.downloadURL) { NSWorkspace.shared.open(u) }
            }
        }
        URLSession.shared.downloadTask(with: zip) { [currentVersion, isNewer] tmp, resp, _ in
            guard let tmp, (resp as? HTTPURLResponse)?.statusCode == 200 else { return fail("Download failed.") }
            let fm = FileManager.default
            let work = fm.temporaryDirectory.appendingPathComponent("CloseAllUpdate-\(UUID().uuidString)")
            let archive = work.appendingPathComponent("update.zip")
            let out = work.appendingPathComponent("x")
            do {
                try fm.createDirectory(at: out, withIntermediateDirectories: true)
                try fm.moveItem(at: tmp, to: archive)
            } catch { return fail("Couldn't prepare the update.") }
            guard Self.run("/usr/bin/ditto", ["-x", "-k", archive.path, out.path]) == 0,
                  let app = (try? fm.contentsOfDirectory(at: out, includingPropertiesForKeys: nil))?
                      .first(where: { $0.pathExtension == "app" }),
                  let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
                  info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
                  let ver = info["CFBundleShortVersionString"] as? String, isNewer(ver, currentVersion),
                  Self.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path]) == 0
            else { return fail("The downloaded update didn't pass verification.") }

            // Helper outlives us: waits for exit, swaps the bundle (restores old on failure), strips quarantine, reopens.
            let script = work.appendingPathComponent("swap.sh")
            let body = """
            #!/bin/bash
            while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
            BK="$4"
            if mv "$2" "$BK"; then
                if ditto "$3" "$2" && xattr -dr com.apple.quarantine "$2"; then rm -rf "$BK"
                else rm -rf "$2"; mv "$BK" "$2"; fi
            fi
            open "$2"
            rm -rf "$5"
            """
            do { try body.write(to: script, atomically: true, encoding: .utf8) } catch { return fail("Couldn't prepare the update.") }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = [script.path, String(getpid()), Bundle.main.bundlePath, app.path,
                           work.appendingPathComponent("old.app").path, work.path]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            do { try p.run() } catch { return fail("Couldn't start the installer.") }
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }.resume()
    }

    private static func run(_ tool: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run(); p.waitUntilExit() } catch { return -1 }
        return p.terminationStatus
    }

    private let repo = "Swallow74/closeall"
    private let userDefaultsKey = "CloseAllLastUpdateCheck"

    private(set) var currentVersion: String = ""

    private init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// `manual`: user-initiated, skips the 24h throttle and reports every outcome.
    func checkForUpdates(manual: Bool = false) {
        guard !checking else { return }
        let now = Date().timeIntervalSince1970
        let lastCheck = UserDefaults.standard.double(forKey: userDefaultsKey)
        if !manual && now - lastCheck < 86400 {
            return
        }

        checking = true
        error = nil
        upToDate = false

        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            checking = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, resp, err in
            DispatchQueue.main.async {
                guard let self else { return }
                self.checking = false

                if let err {
                    self.error = err.localizedDescription
                    return
                }

                guard (resp as? HTTPURLResponse)?.statusCode == 200,
                      let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String,
                      let htmlURL = json["html_url"] as? String
                else {
                    self.error = L.updateCheckFailed
                    return
                }

                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.userDefaultsKey)

                let cleanTag = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                guard self.isNewer(cleanTag, than: self.currentVersion) else {
                    self.upToDate = true
                    return
                }

                self.latestVersion = cleanTag
                self.downloadURL = htmlURL
                let assets = json["assets"] as? [[String: Any]] ?? []
                self.zipURL = assets.first { ($0["name"] as? String)?.hasSuffix(".zip") == true }
                    .flatMap { ($0["browser_download_url"] as? String).flatMap(URL.init(string:)) }
                self.updateAvailable = true
            }
        }.resume()
    }

    private func isNewer(_ new: String, than old: String) -> Bool {
        let newComps = new.split(separator: ".").compactMap { Int($0) }
        let oldComps = old.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(newComps.count, oldComps.count)
        for i in 0..<maxLen {
            let n = i < newComps.count ? newComps[i] : 0
            let o = i < oldComps.count ? oldComps[i] : 0
            if n > o { return true }
            if n < o { return false }
        }
        return false
    }
}
