import Cocoa
import Carbon.HIToolbox

/// Global hotkeys via Carbon RegisterEventHotKey: no Accessibility permission, no duplicate monitors.
final class KeyboardShortcutManager {
    static let shared = KeyboardShortcutManager()

    private var hotKeys: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var ids: [String: UInt32] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false
    private let signature: OSType = 0x434C4F53 // 'CLOS'

    private init() {}

    func register(_ name: String, keyCode: UInt32, carbonModifiers: UInt32, action: @escaping () -> Void) {
        installHandlerIfNeeded()
        unregister(name)

        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return }
        hotKeys[id] = ref
        actions[id] = action
        ids[name] = id
    }

    func unregister(_ name: String) {
        guard let id = ids.removeValue(forKey: name) else { return }
        if let ref = hotKeys.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        actions.removeValue(forKey: id)
    }

    func unregisterAll() {
        for name in Array(ids.keys) { unregister(name) }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if status == noErr, let action = KeyboardShortcutManager.shared.actions[hotKeyID.id] {
                DispatchQueue.main.async { action() }
            }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
