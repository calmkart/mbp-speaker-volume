import Foundation
import CoreAudio

enum SpeakerError: LocalizedError {
    case missing
    case unavailable(OSStatus)
    case readOnly
    case invalidVolume

    var errorDescription: String? {
        switch self {
        case .missing: return "未找到 MacBook Pro 内置扬声器"
        case .unavailable: return "暂时无法读取或调整扬声器音量"
        case .readOnly: return "内置扬声器暂不支持音量调节"
        case .invalidVolume: return "音量需要在 0–100% 之间"
        }
    }
}

struct SpeakerSnapshot: Codable {
    let name: String
    let volume: Float32
    let defaultOutput: String
}

struct SpeakerAudio {
    private let speakerUID = "BuiltInSpeakerDevice"

    private func address(_ selector: AudioObjectPropertySelector,
                         scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private func check(_ status: OSStatus) throws {
        guard status == noErr else { throw SpeakerError.unavailable(status) }
    }

    private func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> String {
        var key = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check(AudioObjectGetPropertyData(object, &key, 0, nil, &size, &value))
        guard let value else { throw SpeakerError.unavailable(-1) }
        return value.takeRetainedValue() as String
    }

    func speaker() throws -> AudioDeviceID {
        var key = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &key, 0, nil, &size))
        guard size >= MemoryLayout<AudioDeviceID>.size else { throw SpeakerError.missing }
        var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        try devices.withUnsafeMutableBytes { buffer in
            try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &key,
                                                 0, nil, &size, buffer.baseAddress!))
        }
        guard let device = devices.first(where: {
            (try? string($0, kAudioDevicePropertyDeviceUID)) == speakerUID
        }) else { throw SpeakerError.missing }
        return device
    }

    func snapshot() throws -> SpeakerSnapshot {
        let device = try speaker()
        var volumeKey = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput)
        var settable: DarwinBoolean = false
        try check(AudioObjectIsPropertySettable(device, &volumeKey, &settable))
        guard settable.boolValue else { throw SpeakerError.readOnly }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        try check(AudioObjectGetPropertyData(device, &volumeKey, 0, nil, &size, &volume))
        var defaultKey = address(kAudioHardwarePropertyDefaultOutputDevice)
        var output = AudioDeviceID(0)
        size = UInt32(MemoryLayout<AudioDeviceID>.size)
        try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultKey,
                                             0, nil, &size, &output))
        return SpeakerSnapshot(name: try string(device, kAudioObjectPropertyName), volume: volume,
                               defaultOutput: try string(output, kAudioObjectPropertyName))
    }

    func setVolume(_ volume: Float32) throws {
        guard volume.isFinite && (0...1).contains(volume) else { throw SpeakerError.invalidVolume }
        // Resolve the physical speaker by UID every time. Never write to the
        // default output, the multi-output device, or BlackHole.
        let device = try speaker()
        var key = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput)
        var writable: DarwinBoolean = false
        try check(AudioObjectIsPropertySettable(device, &key, &writable))
        guard writable.boolValue else { throw SpeakerError.readOnly }
        var value = volume
        try check(AudioObjectSetPropertyData(device, &key, 0, nil,
                                             UInt32(MemoryLayout<Float32>.size), &value))
    }
}
