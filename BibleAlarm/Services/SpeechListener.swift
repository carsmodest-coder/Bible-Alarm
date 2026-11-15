import AVFoundation
import Foundation
import Observation
import Speech

/// Lets a value that is only touched from one place at a time cross into audio callbacks.
struct UncheckedBox<Value>: @unchecked Sendable {
    let value: Value
}

/// Owns the microphone and speech recogniser. Deliberately not tied to the main actor:
/// its callbacks arrive on background threads.
final class SpeechSession: @unchecked Sendable {
    enum SpeechError: Error {
        case unavailable
    }

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func start(locale: Locale, onText: @escaping @Sendable (String) -> Void, onEnd: @escaping @Sendable () -> Void) throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw SpeechError.unavailable
        }
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            newRequest.requiresOnDeviceRecognition = true
        }
        request = newRequest

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let boxedRequest = UncheckedBox(value: newRequest)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            boxedRequest.value.append(buffer)
        }
        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: newRequest) { result, error in
            if let result {
                onText(result.bestTranscription.formattedString)
            }
            if error != nil || (result?.isFinal ?? false) {
                onEnd()
            }
        }
    }

    func stop() {
        if engine.isRunning {
            engine.stop()
        }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Listens while the user reads a verse aloud (Premium strict mode).
@MainActor
@Observable
final class SpeechListener {
    private(set) var transcript = ""
    private(set) var isListening = false
    var errorMessage: String?

    private let session = SpeechSession()

    func start(isChinese: Bool) async {
        errorMessage = nil
        guard await SpeechSession.requestPermission(), await AVAudioApplication.requestRecordPermission() else {
            errorMessage = String(localized: "Allow the microphone and speech recognition in the Settings app to read aloud.")
            return
        }
        transcript = ""
        do {
            try session.start(
                locale: Locale(identifier: isChinese ? "zh-TW" : "en-US"),
                onText: { [weak self] text in
                    Task { @MainActor in self?.transcript = text }
                },
                onEnd: { [weak self] in
                    Task { @MainActor in self?.stop() }
                })
            isListening = true
        } catch {
            session.stop()
            isListening = false
            errorMessage = String(localized: "Speech recognition is not available right now.")
        }
    }

    func stop() {
        guard isListening else { return }
        session.stop()
        isListening = false
    }
}
