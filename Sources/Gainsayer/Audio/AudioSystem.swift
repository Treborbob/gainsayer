import CoreAudio
import Foundation
import os

enum Log {
    static let subsystem = "dev.robblack.gainsayer"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let keys = Logger(subsystem: subsystem, category: "keys")
}

/// An error from a Core Audio HAL call, carrying the four-character status code.
struct CoreAudioError: LocalizedError {
    let status: OSStatus
    let context: String

    var errorDescription: String? {
        "\(context) failed (\(Self.describe(status)))"
    }

    static func describe(_ status: OSStatus) -> String {
        let bytes = withUnsafeBytes(of: status.bigEndian) { Array($0) }
        let printable = bytes.allSatisfy { $0 >= 0x20 && $0 < 0x7f }
        return printable ? "'\(String(decoding: bytes, as: UTF8.self))'" : "\(status)"
    }
}

@discardableResult
func check(_ status: OSStatus, _ context: @autoclosure () -> String) throws -> OSStatus {
    guard status == noErr else { throw CoreAudioError(status: status, context: context()) }
    return status
}

/// Thin, synchronous helpers over the Core Audio HAL property API.
enum AudioSystem {
    static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    /// Reads a fixed-size property value. Returns nil if the property is absent or the read fails.
    static func get<T>(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
        default initial: T
    ) -> T? {
        var addr = address(selector, scope: scope, element: element)
        guard AudioObjectHasProperty(object, &addr) else { return nil }
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        let status = AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    static func getString(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        guard AudioObjectHasProperty(object, &addr) else { return nil }
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value)
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    // MARK: Devices

    static func defaultOutputDevice() -> AudioObjectID? {
        guard let id: AudioObjectID = get(systemObject, kAudioHardwarePropertyDefaultOutputDevice, default: kAudioObjectUnknown),
              id != kAudioObjectUnknown else { return nil }
        return id
    }

    static func name(of device: AudioObjectID) -> String {
        getString(device, kAudioObjectPropertyName) ?? "Unknown device"
    }

    static func uid(of device: AudioObjectID) -> String? {
        getString(device, kAudioDevicePropertyDeviceUID)
    }

    /// True if macOS can already adjust this device's output level itself, in which case Gainsayer stays out of the way.
    static func hasOutputVolumeControl(_ device: AudioObjectID) -> Bool {
        let elements: [AudioObjectPropertyElement] = [kAudioObjectPropertyElementMain, 1, 2]
        return elements.contains { element in
            var addr = address(kAudioDevicePropertyVolumeScalar, scope: kAudioObjectPropertyScopeOutput, element: element)
            return AudioObjectHasProperty(device, &addr)
        }
    }

    /// The HAL's object for our own process, used to exclude ourselves from the global tap.
    static func ownProcessObject() -> AudioObjectID? {
        var pid = ProcessInfo.processInfo.processIdentifier
        var addr = address(kAudioHardwarePropertyTranslatePIDToProcessObject)
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(systemObject, &addr, UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object)
        return status == noErr && object != kAudioObjectUnknown ? object : nil
    }

    // MARK: Listeners

    /// Keeps a property listener registered for as long as the token is alive.
    final class ListenerToken {
        private let object: AudioObjectID
        private var addr: AudioObjectPropertyAddress
        private let queue: DispatchQueue
        private let block: AudioObjectPropertyListenerBlock

        fileprivate init(object: AudioObjectID, addr: AudioObjectPropertyAddress, queue: DispatchQueue, block: @escaping AudioObjectPropertyListenerBlock) {
            self.object = object
            self.addr = addr
            self.queue = queue
            self.block = block
        }

        deinit {
            AudioObjectRemovePropertyListenerBlock(object, &addr, queue, block)
        }
    }

    static func listen(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        queue: DispatchQueue = .main,
        _ handler: @escaping () -> Void
    ) -> ListenerToken? {
        var addr = address(selector)
        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        guard AudioObjectAddPropertyListenerBlock(object, &addr, queue, block) == noErr else { return nil }
        return ListenerToken(object: object, addr: addr, queue: queue, block: block)
    }
}
