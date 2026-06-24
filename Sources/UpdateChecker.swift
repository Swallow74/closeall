import SwiftUI

final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var updateAvailable = false
    @Published var latestVersion = ""
    @Published var downloadURL = ""
    @Published var checking = false
    @Published var error: String?

    private let repo = "Swallow74/closeall"
    private let userDefaultsKey = "CloseAllLastUpdateCheck"

    private(set) var currentVersion: String = ""

    private init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates() {
        let now = Date().timeIntervalSince1970
        let lastCheck = UserDefaults.standard.double(forKey: userDefaultsKey)
        if now - lastCheck < 86400 {
            return
        }

        checking = true
        error = nil

        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            checking = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, _, err in
            DispatchQueue.main.async {
                guard let self else { return }
                self.checking = false

                if let err {
                    self.error = err.localizedDescription
                    return
                }

                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String,
                      let htmlURL = json["html_url"] as? String
                else {
                    return
                }

                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.userDefaultsKey)

                let cleanTag = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                guard self.isNewer(cleanTag, than: self.currentVersion) else {
                    return
                }

                self.latestVersion = cleanTag
                self.downloadURL = htmlURL
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
