import SwiftData
import SwiftUI

/// The wake-up flow: fill in the verse, then the success screen.
struct ChallengeFlowView: View {
    let session: ChallengeSession

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var record: VerseRecord?
    @State private var isFinished = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if isFinished {
                SuccessView(verse: session.verse, record: record) {
                    dismiss()
                }
                .transition(.opacity)
            } else {
                VerseChallengeView(session: session, onSolved: {
                    record = model.completeDaily(session)
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isFinished = true
                    }
                }, onClose: {
                    dismiss()
                })
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// The verse with hidden words and the controls to answer them.
struct VerseChallengeView: View {
    let session: ChallengeSession
    let onSolved: () -> Void
    let onClose: () -> Void

    @State private var mode: ChallengeMode
    @State private var solvedCount = 0
    @State private var wrongCount = 0
    @State private var typed = ""
    @State private var didFinish = false
    @State private var listener = SpeechListener()
    @FocusState private var typingFocused: Bool

    init(session: ChallengeSession, onSolved: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.session = session
        self.onSolved = onSolved
        self.onClose = onClose
        _mode = State(initialValue: session.mode)
    }

    private var blanks: [BlankChallenge.Blank] { session.challenge.blanks }
    private var currentBlank: BlankChallenge.Blank? {
        solvedCount < blanks.count ? blanks[solvedCount] : nil
    }
    private var spokenScore: Double {
        SpeechMatcher.score(spoken: listener.transcript, verse: session.verse.text, isChinese: session.verse.isChinese)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(session.verse.referenceText)
                    .font(.headline)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(10)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            ScrollView {
                Text(verseText)
                    .font(.system(size: session.verse.isChinese ? 34 : 30, weight: .medium, design: .serif))
                    .lineSpacing(10)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .accessibilityIdentifier("verse-text")
                    .modifier(ShakeEffect(animatableData: CGFloat(wrongCount)))
            }

            answerArea
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .sensoryFeedback(.error, trigger: wrongCount)
        .sensoryFeedback(.success, trigger: solvedCount)
        .onChange(of: listener.transcript) { _, _ in
            if mode == .speak, spokenScore >= SpeechMatcher.passingScore {
                listener.stop()
                finish()
            }
        }
        .onDisappear { listener.stop() }
    }

    // MARK: - Verse text

    private var verseText: AttributedString {
        var result = AttributedString()
        for (index, segment) in session.challenge.segments.enumerated() {
            if mode != .speak, let blank = session.challenge.blank(atSegment: index) {
                if blank.id < solvedCount {
                    var part = AttributedString(blank.answer)
                    part.foregroundColor = Theme.accent
                    result.append(part)
                } else {
                    var part = AttributedString(placeholder(for: blank))
                    part.foregroundColor = blank.id == solvedCount ? Theme.accent : Theme.faintText
                    result.append(part)
                }
            } else {
                var part = AttributedString(segment.text)
                part.foregroundColor = Color.white
                result.append(part)
            }
        }
        return result
    }

    private func placeholder(for blank: BlankChallenge.Blank) -> String {
        session.verse.isChinese
            ? String(repeating: "＿", count: max(2, blank.answer.count))
            : "_____"
    }

    // MARK: - Answering

    @ViewBuilder
    private var answerArea: some View {
        switch mode {
        case .tap:
            if let blank = currentBlank {
                VStack(spacing: 14) {
                    Text("Tap the missing word")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Array(blank.choices.enumerated()), id: \.element) { index, choice in
                            Button {
                                answer(choice)
                            } label: {
                                Text(choice)
                                    .font(.title2.weight(.semibold))
                                    .minimumScaleFactor(0.6)
                                    .lineLimit(1)
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 64)
                                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("choice-\(index)")
                        }
                    }
                }
                .id(blank.id)
            }
        case .type:
            VStack(spacing: 14) {
                TextField("Type the missing word", text: $typed)
                    .font(.title2)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($typingFocused)
                    .submitLabel(.done)
                    .onSubmit { answer(typed) }
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                Button("Check") { answer(typed) }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .onAppear { typingFocused = true }
        case .speak:
            VStack(spacing: 14) {
                Text(listener.isListening ? "Listening… read the verse aloud" : "Read the verse aloud")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                ProgressView(value: min(1, spokenScore / SpeechMatcher.passingScore))
                    .tint(Theme.accent)
                if let message = listener.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.accent)
                        .multilineTextAlignment(.center)
                }
                Button {
                    if listener.isListening {
                        listener.stop()
                    } else {
                        Task { await listener.start(isChinese: session.verse.isChinese) }
                    }
                } label: {
                    Label(listener.isListening ? "Stop" : "Start reading", systemImage: listener.isListening ? "stop.fill" : "mic.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Tap the words instead") {
                    listener.stop()
                    mode = .tap
                }
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func answer(_ attempt: String) {
        guard let blank = currentBlank else { return }
        if BlankGenerator.matches(attempt, answer: blank.answer) {
            typed = ""
            withAnimation(.easeOut(duration: 0.25)) {
                solvedCount += 1
            }
            if solvedCount >= blanks.count {
                finish()
            }
        } else {
            withAnimation(.linear(duration: 0.4)) {
                wrongCount += 1
            }
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        typingFocused = false
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            onSolved()
        }
    }

    private func close() {
        listener.stop()
        onClose()
    }
}
