import SwiftUI
import AppKit

struct AppRowView: View {
    let app: AppInfo
    let isIgnored: Bool
    let isSelected: Bool
    let isQuitting: Bool
    let cpuPercent: Double?
    let memoryUsage: UInt64?
    let isProtected: Bool
    let onQuit: (Bool) -> Void
    let onToggleIgnore: () -> Void
    let onToggleSelect: () -> Void
    let onToggleProtect: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)

            if isQuitting {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            }

            Text(app.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let cpu = cpuPercent, cpu > 5 {
                Text(String(format: "%.0f%%", cpu))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(cpuColor(cpu))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(cpuColor(cpu).opacity(0.1))
                    .cornerRadius(3)
            }

            if let mem = memoryUsage, mem > 0 {
                let mb = Double(mem) / 1_048_576
                let label = mb >= 1024
                    ? String(format: "%.1f GB", mb / 1024)
                    : String(format: "%.0f MB", mb)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(3)
            }

            if isProtected {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
            }

            if isHovering {
                HStack(spacing: 4) {
                    Button(action: onToggleProtect) {
                        Image(systemName: isProtected ? "lock.shield.fill" : "lock.shield")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .tooltip(isProtected ? AppConstants.Localizable.unprotectFromAutoQuit : AppConstants.Localizable.protectFromAutoQuit)

                    Button(action: onToggleIgnore) {
                        Image(systemName: isIgnored ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .tooltip(isIgnored ? AppConstants.Localizable.unignoreApp : AppConstants.Localizable.ignoreApp)

                    Button(action: { onQuit(false) }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .tooltip(AppConstants.Localizable.quit)

                    Button(action: { onQuit(true) }) {
                        Image(systemName: "xmark.octagon.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .tooltip(AppConstants.Localizable.forceQuit)
                }
            } else {
                if isIgnored {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, AppConstants.rowPaddingH)
        .padding(.vertical, AppConstants.rowPaddingV)
        .background(
            isHovering
                ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3)
                : Color.clear
        )
        .cornerRadius(AppConstants.cornerRadius)
        .onHover { hovering in isHovering = hovering }
    }

    private func cpuColor(_ pct: Double) -> Color {
        if pct > 50 { return .red }
        if pct > 20 { return .orange }
        return .secondary
    }
}
