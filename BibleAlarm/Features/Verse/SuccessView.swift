import SwiftData
import SwiftUI

/// Shown after the verse is completed: the full verse, Amen, then an optional reflection.
struct SuccessView: View {
    let verse: Verse
    let record: VerseRecord?
    let onDone: () -> Void

    @State private var saidAmen = false
    @State private var reflection = ""
    @State private var isFavorite = false
    @State private var showChapter = false
    @FocusState private var reflectionFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 32)

                Text(verse.text)
                    .font(.system(size: verse.isChinese ? 30 : 26, weight: .medium, design: .serif))
                    .lineSpacing(8)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)

                Text(verse.referenceText)
                    .font(.headline)
                    .foregroundStyle(Theme.secondaryText)

                if !saidAmen {
                    Button("Amen") {
                        withAnimation { saidAmen = true }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 12)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        if record != nil {
                            Text("What stands out to you today?")
                                .font(.headline)
                                .foregroundStyle(Color.white)
                            TextField("Write a thought (optional)", text: $reflection, axis: .vertical)
                                .lineLimit(3...6)
                                .focused($reflectionFocused)
                                .padding(14)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                        }
                        HStack(spacing: 12) {
                            if record != nil {
                                Button {
                                    isFavorite.toggle()
                                } label: {
                                    Label(isFavorite ? "Saved" : "Favorite", systemImage: isFavorite ? "heart.fill" : "heart")
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            }
                            ShareVerseButton(verse: verse)
                        }
                        Button {
                            showChapter = true
                        } label: {
                            Label("Read the whole chapter", systemImage: "book")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        Button("Done") { finish() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .transition(.opacity)
                }
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.success, trigger: saidAmen)
        .sheet(isPresented: $showChapter) {
            NavigationStack {
                ChapterReaderView(bookID: verse.ref.bookID, chapter: verse.ref.chapter, highlightVerse: verse.ref.verse)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showChapter = false }
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func finish() {
        if let record {
            record.reflection = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
            record.isFavorite = isFavorite
            try? record.modelContext?.save()
        }
        onDone()
    }
}

/// The verse as an image for sharing.
struct ShareCardView: View {
    let verse: Verse

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.055, blue: 0.15), Color(red: 0.16, green: 0.11, blue: 0.27)],
                startPoint: .top, endPoint: .bottom)
            VStack(spacing: 20) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.accent)
                Text(verse.text)
                    .font(.system(size: verse.text.count > 160 ? 17 : 21, weight: .medium, design: .serif))
                    .lineSpacing(6)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                Text(verbatim: "\(verse.referenceText) · \(verse.version.shortName)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(32)
        }
        .frame(width: 360, height: 450)
    }
}

/// Share button that sends the verse as a typographic card image.
struct ShareVerseButton: View {
    let verse: Verse
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview(verse.referenceText, image: image)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(Theme.faintText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
            }
        }
        .task(id: verse) {
            let renderer = ImageRenderer(content: ShareCardView(verse: verse))
            renderer.scale = 3
            if let rendered = renderer.uiImage {
                image = Image(uiImage: rendered)
            }
        }
    }
}

/// Reads a whole chapter. Used from reading plans and from a saved verse.
struct ChapterReaderView: View {
    @Environment(AppModel.self) private var model
    let bookID: String
    let chapter: Int
    var highlightVerse: Int?

    @State private var verses: [String] = []

    var body: some View {
        let isChinese = model.settings.bibleVersion.isChinese
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(verses.enumerated()), id: \.offset) { index, text in
                    if !text.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(verbatim: "\(index + 1)")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 26, alignment: .trailing)
                            Text(text)
                                .font(.system(size: 20, design: .serif))
                                .lineSpacing(6)
                                .foregroundStyle(index + 1 == highlightVerse ? Theme.accent : Color.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(BookNames.chapterTitle(bookID: bookID, chapter: chapter, chinese: isChinese))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            verses = await model.bible.chapter(bookID: bookID, chapter: chapter, versionID: model.settings.bibleVersionID)
        }
    }
}
