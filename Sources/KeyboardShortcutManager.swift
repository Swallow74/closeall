import Cocoa

final class KeyboardShortcutManager {
    static let shared = KeyboardShortcutManager()

    private var handlers: [String: (NSEvent) -> Void] = [:]
    private var actions: [String: () -> Void] = [:]

    private init() {}

    func register(_ name: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        unregister(name)

        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }

            let effectiveFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == keyCode && effectiveFlags == modifiers {
                if let action = self.actions[name] {
                    DispatchQueue.main.async { action() }
                }
            }
        }

        handlers[name] = handler
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler)
    }

    func unregister(_ name: String) {
        if let handler = handlers.removeValue(forKey: name) {
            NSEvent.removeMonitor(handler)
        }
    }

    func unregisterAll() {
        for name in handlers.keys {
            unregister(name)
        }
    }

    func setAction(_ name: String, action: @escaping () -> Void) {
        actions[name] = action
    }

    func disableAll() {
        unregisterAll()
    }
}
