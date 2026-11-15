import AVFoundation
import Foundation
import Observation

/// How an alarm's sound choice is stored: "system", "builtin:<name>" or "custom:<uuid>".
enum SoundID {
    static let system = "system"
    static let defaultID = "builtin:dawn"

    static func builtIn(_ sound: BuiltInSound) -> String { "builtin:\(sound.rawValue)" }
    static func custom(_ id: UUID) -> String { "custom:\(id.uuidString)" }
}

/// Tones generated for this app (see Tools/make_sounds.py and CREDITS.md).
enum BuiltInSound: String, CaseIterable, Identifiable, Sendable {
    case dawn
    case chimes
    case harp
    case stillWaters = "still_waters"

    var id: String { rawValue }
    var fileName: String { rawValue + ".wav" }
    var url: URL? { Bundle.main.url(forResource: rawValue, withExtension: "wav") }

    var displayName: String {
        switch self {
        case .dawn: return String(localized: "Dawn")
        case .chimes: return String(localized: "Chimes")
        case .harp: return String(localized: "Harp")
        case .stillWaters: return String(localized: "Still Waters")
        }
    }
}

/// The folder iOS looks in for custom alert sounds.
enum SoundFiles {
    static var directory: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let folder = library.appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func url(forFileName fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(forFileName: fileName))
    }

    static func temporaryURL(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
    }
}

/// A sound choice turned into what the app needs to show and play it.
struct ResolvedSound {
    let displayName: String
    /// File name to hand to AlarmKit, or nil for the system alarm sound.
    let fileName: String?
    /// Where the file is, for previews.
    let url: URL?
}

enum SoundCatalog {
    @MainActor
    static func resolve(_ soundID: String, customSounds: [CustomSound]) -> ResolvedSound {
        if soundID.hasPrefix("builtin:"), let sound = BuiltInSound(rawValue: String(soundID.dropFirst(8))) {
            return ResolvedSound(displayName: sound.displayName, fileName: sound.fileName, url: sound.url)
        }
        if soundID.hasPrefix("custom:"),
           let custom = customSounds.first(where: { SoundID.custom($0.id) == soundID }) {
            let url = SoundFiles.url(forFileName: custom.fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                return ResolvedSound(displayName: custom.displayName, fileName: custom.fileName, url: url)
            }
        }
        if soundID == SoundID.system || soundID.hasPrefix("custom:") {
            return ResolvedSound(displayName: String(localized: "iPhone alarm sound"), fileName: nil, url: nil)
        }
        return ResolvedSound(displayName: BuiltInSound.dawn.displayName, fileName: BuiltInSound.dawn.fileName, url: BuiltInSound.dawn.url)
    }
}

/// Reads audio files and turns a section of one into an alarm sound.
enum SoundImporter {
    /// Alarm clips are kept to this length.
    static let maxClipSeconds = 30.0
    static let minClipSeconds = 5.0

    enum ImportError: Error {
        case unreadable
        case empty
    }

    static func duration(of url: URL) throws -> Double {
        let file = try AVAudioFile(forReading: url)
        let rate = file.processingFormat.sampleRate
        guard rate > 0, file.length > 0 else { throw ImportError.unreadable }
        return Double(file.length) / rate
    }

    /// Copies `length` seconds starting at `start` into an uncompressed .caf file, the format alert sounds need.
    /// Returns the length of the clip that was written.
    @discardableResult
    static func exportClip(from source: URL, start: Double, length: Double, fadeIn: Double, to destination: URL) throws -> Double {
        let file = try AVAudioFile(forReading: source)
        let format = file.processingFormat
        let rate = format.sampleRate
        let total = file.length
        guard rate > 0, total > 0 else { throw ImportError.unreadable }

        let startFrame = min(max(0, AVAudioFramePosition(start * rate)), total - 1)
        let wantedSeconds = min(max(length, 0.5), maxClipSeconds)
        let wantedFrames = min(Double(total - startFrame), wantedSeconds * rate)
        let frameCount = AVAudioFrameCount(max(0, wantedFrames))
        guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw ImportError.empty
        }
        file.framePosition = startFrame
        try file.read(into: buffer, frameCount: frameCount)
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { throw ImportError.empty }

        if let channels = buffer.floatChannelData {
            let fadeInFrames = min(frames, max(0, Int(fadeIn * rate)))
            let fadeOutFrames = min(frames, Int(0.15 * rate))
            for channel in 0..<Int(format.channelCount) {
                let samples = channels[channel]
                if fadeInFrames > 1 {
                    for index in 0..<fadeInFrames {
                        samples[index] *= Float(index) / Float(fadeInFrames)
                    }
                }
                if fadeOutFrames > 1 {
                    for index in 0..<fadeOutFrames {
                        samples[frames - 1 - index] *= Float(index) / Float(fadeOutFrames)
                    }
                }
            }
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: rate,
            AVNumberOfChannelsKey: Int(format.channelCount),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        try? FileManager.default.removeItem(at: destination)
        do {
            let output = try AVAudioFile(
                forWriting: destination, settings: settings,
                commonFormat: format.commonFormat, interleaved: format.isInterleaved)
            try output.write(from: buffer)
        }
        return Double(frames) / rate
    }

    /// Loudness peaks across the whole file, scaled 0...1, for drawing a waveform.
    static func waveform(of url: URL, buckets: Int) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let total = Int(file.length)
        guard total > 0, buckets > 0 else { return [] }
        let chunk: AVAudioFrameCount = 32768
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunk) else { return [] }

        var peaks = [Float](repeating: 0, count: buckets)
        var position = 0
        while position < total {
            try file.read(into: buffer, frameCount: chunk)
            let frames = Int(buffer.frameLength)
            if frames == 0 { break }
            if let channels = buffer.floatChannelData {
                let samples = channels[0]
                var index = 0
                while index < frames {
                    let bucket = min(buckets - 1, (position + index) * buckets / total)
                    let value = abs(samples[index])
                    if value > peaks[bucket] { peaks[bucket] = value }
                    index += 8
                }
            }
            position += frames
        }
        let highest = peaks.max() ?? 0
        return highest > 0 ? peaks.map { $0 / highest } : peaks
    }
}

/// Plays short previews of alarm sounds inside the app.
@MainActor
@Observable
final class SoundPreviewPlayer {
    private(set) var playingID: String?
    private var player: AVAudioPlayer?
    private var stopTask: Task<Void, Never>?

    /// Starts the preview, or stops it if this sound is already playing.
    func toggle(id: String, url: URL?, from start: Double = 0, length: Double? = nil) {
        if playingID == id {
            stop()
            return
        }
        stop()
        guard let url else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.currentTime = min(max(0, start), max(0, newPlayer.duration - 0.1))
            newPlayer.play()
            player = newPlayer
            playingID = id
            let playFor = min(length ?? newPlayer.duration, max(0.2, newPlayer.duration - newPlayer.currentTime))
            stopTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(playFor))
                if !Task.isCancelled { self?.stop() }
            }
        } catch {
            stop()
        }
    }

    func stop() {
        stopTask?.cancel()
        stopTask = nil
        player?.stop()
        player = nil
        playingID = nil
    }
}

/// Records the user's own alarm sound (Premium).
@MainActor
@Observable
final class VoiceRecorder {
    private(set) var isRecording = false
    private(set) var startedAt: Date?
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    /// Asks for the microphone if needed and starts recording. Returns false if that was not possible.
    func start() async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        let url = SoundFiles.temporaryURL(extension: "caf")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            guard newRecorder.record(forDuration: SoundImporter.maxClipSeconds) else { return false }
            recorder = newRecorder
            fileURL = url
            startedAt = Date()
            isRecording = true
            return true
        } catch {
            return false
        }
    }

    /// Stops recording and returns the recorded file.
    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        isRecording = false
        startedAt = nil
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        return fileURL
    }
}
