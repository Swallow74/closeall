import SwiftUI
import AppKit

enum Format {
    static func memory(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576
        return mb >= 1024 ? String(format: "%.1f GB", mb / 1024) : String(format: "%.0f MB", mb)
    }
}

enum Level {
    case normal, warning, critical

    var color: Color {
        switch self {
        case .normal: return .secondary
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

/// Compact metric pill used in the popover header.
struct MetricChip: View {
    let icon: Image
    let text: String
    var level: Level = .normal
    let help: String

    var body: some View {
        HStack(spacing: 4) {
            icon
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(level == .normal ? .secondary : level.color)
            Text(text)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundColor(level == .normal ? .primary : level.color)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(level == .normal ? Color.secondary.opacity(0.12) : level.color.opacity(0.15))
        )
        .contentShape(Capsule())
        .tooltip(help)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(help.replacingOccurrences(of: "\n", with: ", "))
    }
}

/// Small rounded label (memory / CPU) used in rows.
struct Badge: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.12)))
    }
}

struct IconButton: View {
    let systemName: String
    let label: String
    var color: Color = .secondary
    var size: CGFloat = 13
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .foregroundColor(color)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .tooltip(label)
        .accessibilityLabel(label)
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppConstants.rowPaddingH)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }
}

extension View {
    func tooltip(_ tip: String) -> some View {
        self.background(ToolTipView(tip: tip).allowsHitTesting(false))
    }
}

private struct ToolTipView: NSViewRepresentable {
    let tip: String

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.toolTip = tip
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.toolTip = tip
    }
}

/// Modal confirmation shown outside the popover.
enum Confirm {
    static func ask(title: String, message: String, button: String, destructive: Bool = true) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: L.cancel)
        alert.alertStyle = destructive ? .warning : .informational
        return alert.runModal() == .alertFirstButtonReturn
    }
}

extension Notification.Name {
    static let popoverWillShow = Notification.Name("CloseAllPopoverWillShow")
}
