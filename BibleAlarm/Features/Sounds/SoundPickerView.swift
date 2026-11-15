import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// An audio file the user picked or recorded, copied into the app's temporary folder.
struct PickedAudio: Identifiable {
    let id = UUID()
    let url: URL
    let suggestedName: String
}

/// Choose the alarm sound: built-in tones, the iPhone alarm sound, or the user's own sounds.
struct SoundPickerView: View {
    @Binding var selection: String

    @Environment(AppModel.self) private var model
    @Query(sort: \CustomSound.createdAt, order: .reverse) private var customSounds: [CustomSound]

    @State private var isImporting = false
    @State private var isRecording = false
    @State private var showPaywall = false
    @State private var picked: PickedAudio?
    @State private var recorded: PickedAudio?
    @State private var importError: String?

    var body: some View {
        List {
            Section("Built-in") {
                ForEach(BuiltInSound.allCases) { sound in
                    row(id: SoundID.builtIn(sound), name: sound.displayName, url: sound.url)
                }
                row(id: SoundID.system, name: String(localized: "iPhone alarm sound"), url: nil)
            }
            .cardRow()

            Section {
                ForEach(customSounds) { sound in
                    row(id: SoundID.custom(sound.id), name: sound.displayName, url: SoundFiles.url(forFileName: sound.fileName))
                }
                .onDelete(perform: deleteSounds)

                Button {
                    isImporting = true
                } label: {
                    Label("Add your own sound", systemImage: "plus.circle.fill")
                }

                Button {
                    if model.isPremium {
                        isRecording = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack {
                        Label("Record your voice", systemImage: "mic.circle.fill")
                        Spacer()
                        if !model.isPremium { PremiumBadge() }
                    }
                }
            } header: {
                Text("Your sounds")
            } footer: {
                Text("Pick an MP3, M4A, WAV or AAC file from the Files app. Your sounds stay on this iPhone and are never uploaded.")
            }
            .cardRow()
        }
        .screenBackground()
        .navigationTitle("Sound")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.audio]) { result in
            handleImport(result)
        }
        .sheet(item: $picked) { audio in
            SoundTrimmerView(source: audio) { newID in
                selection = newID
            }
        }
        .sheet(isPresented: $isRecording, onDismiss: {
            if let recorded {
                picked = recorded
                self.recorded = nil
            }
        }) {
            VoiceRecorderView { url in
                recorded = PickedAudio(url: url, suggestedName: String(localized: "My recording"))
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("This file can't be used", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .onDisappear { model.player.stop() }
    }

    private func row(id: String, name: String, url: URL?) -> some View {
        HStack {
            Button {
                selection = id
                model.player.toggle(id: id, url: url)
            } label: {
                HStack {
                    Image(systemName: selection == id ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selection == id ? Theme.accent : Theme.faintText)
                    Text(name)
                        .foregroundStyle(Color.white)
                    Spacer()
                    if url != nil {
                        Image(systemName: model.player.playingID == id ? "stop.fill" : "play.fill")
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        let protectedMessage = String(localized: "The file could not be read. Songs from Apple Music or Spotify are protected and can't be imported.")
        guard case .success(let url) = result else { return }
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }
        let copy = SoundFiles.temporaryURL(extension: url.pathExtension.isEmpty ? "m4a" : url.pathExtension)
        do {
            try FileManager.default.copyItem(at: url, to: copy)
            _ = try SoundImporter.duration(of: copy)
            picked = PickedAudio(url: copy, suggestedName: url.deletingPathExtension().lastPathComponent)
        } catch {
            try? FileManager.default.removeItem(at: copy)
            importError = protectedMessage
        }
    }

    private func deleteSounds(at offsets: IndexSet) {
        for index in offsets {
            let sound = customSounds[index]
            if selection == SoundID.custom(sound.id) {
                selection = SoundID.defaultID
            }
            SoundFiles.delete(fileName: sound.fileName)
            model.context.delete(sound)
        }
        try? model.context.save()
    }
}

/// Choose which part of an audio file becomes the alarm sound.
/// Free: pick the start point. Premium: waveform, clip length and fade-in.
struct SoundTrimmerView: View {
    let source: PickedAudio
    let onSaved: (String) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var duration: Double = 0
    @State private var start: Double = 0
    @State private var length: Double = SoundImporter.maxClipSeconds
    @State private var fadeIn = false
    @State private var waveform: [Float] = []
    @State private var isSaving = false
    @State private var showPaywall = false
    @State private var failed = false

    init(source: PickedAudio, onSaved: @escaping (String) -> Void) {
        self.source = source
        self.onSaved = onSaved
        _name = State(initialValue: source.suggestedName)
    }

    private var clipLength: Double { min(length, max(0.5, duration - start)) }
    private var maxStart: Double { max(0, duration - SoundImporter.minClipSeconds) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                }
                .cardRow()

                Section {
                    if model.isPremium {
                        WaveformView(samples: waveform, start: duration > 0 ? start / duration : 0,
                                     end: duration > 0 ? (start + clipLength) / duration : 1)
                            .frame(height: 72)
                    }
                    if maxStart > 0 {
                        Slider(value: $start, in: 0...maxStart)
                    }
                    Text("Starts at \(Formatters.clock(start)) · plays for \(Int(clipLength.rounded())) seconds")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Button {
                        model.player.toggle(id: "trim-preview", url: source.url, from: start, length: clipLength)
                    } label: {
                        Label(model.player.playingID == "trim-preview" ? "Stop" : "Preview", systemImage: model.player.playingID == "trim-preview" ? "stop.fill" : "play.fill")
                    }
                } header: {
                    Text("Start point")
                }
                .cardRow()

                Section {
                    if model.isPremium {
                        VStack(alignment: .leading) {
                            Text("Clip length: \(Int(length.rounded())) seconds")
                            Slider(value: $length, in: SoundImporter.minClipSeconds...SoundImporter.maxClipSeconds, step: 1)
                        }
                        Toggle("Fade in gently", isOn: $fadeIn)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Waveform, clip length and fade-in", systemImage: "waveform")
                                Spacer()
                                PremiumBadge()
                            }
                        }
                    }
                } header: {
                    Text("Advanced editing")
                }
                .cardRow()
            }
            .screenBackground()
            .navigationTitle("Trim sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving || duration <= 0)
                }
            }
            .task { await load() }
            .onDisappear { model.player.stop() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("The sound could not be saved", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func load() async {
        let url = source.url
        duration = (try? SoundImporter.duration(of: url)) ?? 0
        length = min(SoundImporter.maxClipSeconds, max(SoundImporter.minClipSeconds, duration))
        let samples = await Task.detached(priority: .utility) {
            (try? SoundImporter.waveform(of: url, buckets: 90)) ?? []
        }.value
        waveform = samples
    }

    private func save() {
        isSaving = true
        model.player.stop()
        let id = UUID()
        let fileName = id.uuidString + ".caf"
        let sourceURL = source.url
        let destination = SoundFiles.url(forFileName: fileName)
        let clipStart = start
        let clip = clipLength
        let fade = (model.isPremium && fadeIn) ? 3.0 : 0.0
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let written = await Task.detached(priority: .userInitiated) {
                try? SoundImporter.exportClip(from: sourceURL, start: clipStart, length: clip, fadeIn: fade, to: destination)
            }.value
            isSaving = false
            guard let written else {
                failed = true
                return
            }
            let sound = CustomSound(
                id: id, displayName: displayName.isEmpty ? String(localized: "My sound") : displayName,
                fileName: fileName, durationSeconds: written)
            model.context.insert(sound)
            try? model.context.save()
            onSaved(SoundID.custom(id))
            dismiss()
        }
    }
}

/// Simple bar waveform with the chosen clip highlighted.
struct WaveformView: View {
    let samples: [Float]
    let start: Double
    let end: Double

    var body: some View {
        GeometryReader { proxy in
            let count = max(samples.count, 1)
            let barWidth = proxy.size.width / CGFloat(count)
            HStack(alignment: .center, spacing: 0) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                    let position = Double(index) / Double(count)
                    let isSelected = position >= start && position <= end
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isSelected ? Theme.accent : Theme.faintText)
                        .frame(width: max(1, barWidth - 1), height: max(2, CGFloat(sample) * proxy.size.height))
                        .frame(width: barWidth)
                }
            }
            .frame(height: proxy.size.height)
        }
    }
}

/// Record up to 30 seconds with the microphone (Premium).
struct VoiceRecorderView: View {
    let onFinished: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recorder = VoiceRecorder()
    @State private var denied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()
                Image(systemName: recorder.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(Theme.accent)
                    .symbolEffect(.pulse, isActive: recorder.isRecording)
                if let startedAt = recorder.startedAt {
                    Text(startedAt, style: .timer)
                        .font(.system(size: 44, weight: .light, design: .rounded))
                        .monospacedDigit()
                } else {
                    Text("Record up to 30 seconds")
                        .font(.title3)
                        .foregroundStyle(Theme.secondaryText)
                }
                if denied {
                    Text("Allow the microphone in the Settings app to record.")
                        .font(.footnote)
                        .foregroundStyle(Theme.accent)
                        .multilineTextAlignment(.center)
                }
                Spacer()
                Button(recorder.isRecording ? "Stop and use" : "Start recording") {
                    if recorder.isRecording {
                        if let url = recorder.stop() {
                            onFinished(url)
                        }
                        dismiss()
                    } else {
                        Task { denied = !(await recorder.start()) }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Record your voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        _ = recorder.stop()
                        dismiss()
                    }
                }
            }
        }
    }
}
