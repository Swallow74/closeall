import SwiftUI
import AppKit

struct AppRowView: View {
    let app: AppInfo
    let isIgnored: Bool
    let isSelected: Bool
    let isQuitting: Bool
    let onQuit: (Bool) -> Void
    let onToggleIgnore: () -> Void
    let onToggleSelect: () -> Void

    @State private var isHovering = false
    @State private var showForceHint = false

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

            if isHovering {
                HStack(spacing: 4) {
                    Button(action: onToggleIgnore) {
                        Image(systemName: isIgnored ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isIgnored ? AppConstants.Localizable.unignoreApp : AppConstants.Localizable.ignoreApp)

                    Button(action: { onQuit(false) }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help(AppConstants.Localizable.quit)

                    Button(action: { onQuit(true) }) {
                        Image(systemName: "xmark.octagon.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .help(AppConstants.Localizable.forceQuit)
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
}
