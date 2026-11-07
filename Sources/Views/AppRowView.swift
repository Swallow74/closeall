import SwiftUI
import AppKit

struct AppRowActions {
    var quit: (Bool) -> Void
    var toggleSelect: () -> Void
    var toggleIgnore: () -> Void
    var toggleProtect: () -> Void
    var toggleHidden: () -> Void
    var reveal: () -> Void
    var activate: () -> Void
}

struct AppRowView: View {
    let app: AppInfo
    let isIgnored: Bool
    let isSelected: Bool
    let isQuitting: Bool
    let isProtected: Bool
    let cpuPercent: Double?
    let memoryUsage: UInt64?
    let hasChildren: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let actions: AppRowActions

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            if hasChildren {
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? L.collapseProcesses : L.expandProcesses)
            } else {
                Spacer().frame(width: 16)
            }

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15))
                .foregroundColor(isSelected ? .accentColor : Color.secondary.opacity(0.6))

            ZStack {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .opacity(isQuitting ? 0.35 : (app.isHidden ? 0.55 : 1))
                if isQuitting {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 0) {
                Text(app.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if isQuitting {
                    Text(L.quitting)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isProtected {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                    .tooltip(L.protectedLabel)
            }
            if isIgnored {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .tooltip(L.ignoredLabel)
            }

            if isHovering && !isQuitting {
                HStack(spacing: 0) {
                    IconButton(systemName: "xmark.circle", label: L.quit, size: 14) { actions.quit(false) }
                    IconButton(systemName: "bolt.circle.fill", label: L.forceQuit, color: .orange, size: 14) { actions.quit(true) }
                    Menu { menuItems } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .frame(width: 22, height: 22)
                    .accessibilityLabel(L.moreActions)
                }
            } else {
                HStack(spacing: 4) {
                    if let cpu = cpuPercent, cpu >= 5 {
                        Badge(text: String(format: "%.0f%%", cpu), color: cpuColor(cpu))
                    }
                    if let mem = memoryUsage, mem > 0 {
                        Badge(text: Format.memory(mem), color: memColor(mem))
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, AppConstants.rowPaddingV)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.cornerRadius)
                .fill(rowBackground)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: actions.toggleSelect)
        .onHover { isHovering = $0 }
        .contextMenu { menuItems; Divider(); Button(L.quit) { actions.quit(false) }; Button(L.forceQuit) { actions.quit(true) } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(app.name)
        .accessibilityValue(isSelected ? L.selectedLabel : "")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { actions.toggleSelect() }
    }

    @ViewBuilder
    private var menuItems: some View {
        Button(L.showApp) { actions.activate() }
        Button(app.isHidden ? L.unhide : L.hide) { actions.toggleHidden() }
        Button(L.revealInFinder) { actions.reveal() }
        Divider()
        Button(isProtected ? L.unprotectFromAutoQuit : L.protectFromAutoQuit) { actions.toggleProtect() }
        Button(isIgnored ? L.unignoreApp : L.ignoreApp) { actions.toggleIgnore() }
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(isHovering ? 0.22 : 0.14) }
        return isHovering ? Color.primary.opacity(0.07) : .clear
    }

    private func cpuColor(_ pct: Double) -> Color {
        if pct > 100 { return .red }
        if pct > 40 { return .orange }
        return .secondary
    }

    private func memColor(_ bytes: UInt64) -> Color {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 3 { return .red }
        if gb >= 1.5 { return .orange }
        return .secondary
    }
}

struct ProcessRowView: View {
    let name: String
    let memory: UInt64
    let pid: Int32
    let indent: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(name)
                .font(.system(size: 12))
                .foregroundColor(Color.primary.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isHovering {
                HStack(spacing: 0) {
                    IconButton(systemName: "xmark.circle", label: L.terminate, size: 13) { kill(pid, SIGTERM) }
                    IconButton(systemName: "bolt.circle.fill", label: L.forceKill, color: .orange, size: 13) { kill(pid, SIGKILL) }
                }
            } else {
                Badge(text: memory == 0 ? "?" : Format.memory(memory))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .padding(.leading, indent ? 40 : 16)
        .background(RoundedRectangle(cornerRadius: AppConstants.cornerRadius).fill(isHovering ? Color.primary.opacity(0.07) : .clear))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(Format.memory(memory))")
    }
}
