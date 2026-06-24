import AppKit

enum GPUIconHelper {
    static func icon(tint: NSColor? = nil, size: NSSize = NSSize(width: 16, height: 16)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let color = tint ?? NSColor.controlTextColor
        color.setStroke()
        color.setFill()

        let inset: CGFloat = 1
        let bw = size.width - inset * 2
        let bh = size.height - 6
        let body = NSRect(x: inset, y: 3, width: bw, height: bh)

        let path = NSBezierPath(roundedRect: body, xRadius: 2.5, yRadius: 2.5)
        path.lineWidth = 1.6
        path.stroke()

        let pinW: CGFloat = 2.2
        let pinH: CGFloat = 2.8
        let gap: CGFloat = 2.2
        let totalPinsW = pinW * 3 + gap * 2
        let startX = (size.width - totalPinsW) / 2

        for i in 0..<3 {
            let px = startX + CGFloat(i) * (pinW + gap)
            let topRect = NSRect(x: px, y: 0, width: pinW, height: pinH)
            NSBezierPath(rect: topRect).fill()
            let botRect = NSRect(x: px, y: size.height - pinH, width: pinW, height: pinH)
            NSBezierPath(rect: botRect).fill()
        }

        image.unlockFocus()
        image.isTemplate = tint == nil
        return image
    }
}
