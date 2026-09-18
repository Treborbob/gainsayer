import AppKit
import CoreGraphics
import Foundation

/// Intercepts the keyboard volume keys (F10/F11/F12 and their Touch Bar equivalents).
///
/// macOS delivers these as system-defined events. We install a session-level event tap so we can
/// swallow them when Gainsayer is managing the output, and let them through untouched otherwise.
/// Requires the Accessibility permission.
final class MediaKeyMonitor {
    enum Key {
        case volumeUp, volumeDown, mute
    }

    /// Return true to take the key. Called on the main run loop, keep it quick.
    var shouldIntercept: () -> Bool = { false }
    /// Called for each key-down (including auto-repeat) that was intercepted. `fine` is true when
    /// Shift+Option is held, which macOS treats as a quarter-step nudge.
    var onKey: (Key, _ fine: Bool) -> Void = { _, _ in }

    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    private static let systemDefinedEventType = CGEventType(rawValue: 14)!  // NX_SYSDEFINED
    private static let auxControlSubtype = 8  // NX_SUBTYPE_AUX_CONTROL_BUTTONS

    var isRunning: Bool { port != nil }

    static func isTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Returns false if the tap could not be created, almost always because Accessibility is not granted.
    @discardableResult
    func start() -> Bool {
        guard port == nil else { return true }
        let mask = CGEventMask(1) << Self.systemDefinedEventType.rawValue
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<MediaKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }
        guard
            let port = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: callback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let port { CGEvent.tapEnable(tap: port, enable: false) }
        source = nil
        port = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let passThrough = Unmanaged.passUnretained(event)

        // macOS disables a tap that is slow to respond. Re-enable and carry on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return passThrough
        }

        guard type == Self.systemDefinedEventType,
            let nsEvent = NSEvent(cgEvent: event),
            nsEvent.subtype.rawValue == Self.auxControlSubtype
        else { return passThrough }

        let data = nsEvent.data1
        let keyCode = (data & 0xFFFF_0000) >> 16
        let keyFlags = data & 0x0000_FFFF
        let isKeyDown = (keyFlags & 0xFF00) >> 8 == 0x0A

        let key: Key
        switch keyCode {
        case 0: key = .volumeUp  // NX_KEYTYPE_SOUND_UP
        case 1: key = .volumeDown  // NX_KEYTYPE_SOUND_DOWN
        case 7: key = .mute  // NX_KEYTYPE_MUTE
        default: return passThrough
        }

        guard shouldIntercept() else { return passThrough }
        if isKeyDown {
            let fine = nsEvent.modifierFlags.isSuperset(of: [.shift, .option])
            onKey(key, fine)
        }
        return nil  // swallow both down and up so macOS does not also act on it
    }
}
