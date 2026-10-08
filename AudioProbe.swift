import Foundation

@main
struct AudioProbe {
    static func main() throws {
        let audio = SpeakerAudio()
        let snapshot = try audio.snapshot()
        for invalid in [Float32(-1), Float32(1.1), Float32.nan, Float32.infinity] {
            do {
                try audio.setVolume(invalid)
                fatalError("Invalid volume was accepted")
            } catch SpeakerError.invalidVolume {
                // Validation happens before any device write.
            }
        }
        print(String(data: try JSONEncoder().encode(snapshot), encoding: .utf8)!)
    }
}
