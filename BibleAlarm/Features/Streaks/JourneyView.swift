import SwiftData
import SwiftUI

/// Streak, history of completed verses, and favourites.
struct JourneyView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \VerseRecord.completedAt, order: .reverse) private var records: [VerseRecord]

    @State private var showFavoritesOnly = false
    @State private var showPaywall = false
    @State private var isMemorizing = false

    private var streak: StreakSummary {
        StreakCalculator.summarize(dates: records.map { $0.completedAt }, now: Date(), calendar: .current)
    }
    private var shown: [VerseRecord] {
        showFavoritesOnly ? records.filter { $0.isFavorite } : records
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        StatTile(value: streak.current, title: "Day streak", systemImage: "flame.fill")
                        StatTile(value: streak.best, title: "Best streak", systemImage: "trophy.fill")
                        StatTile(value: records.count, title: "Verses read", systemImage: "book.fill")
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    Button {
                        if model.isPremium {
                            isMemorizing = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack {
                            Label("Memorize mode", systemImage: "brain.head.profile")
                            Spacer()
                            if !model.isPremium { PremiumBadge() }
                        }
                    }
                    .disabled(model.isPremium && records.isEmpty)
                } footer: {
                    Text("Quiz yourself on verses you have already read.")
                }
                .cardRow()

                Section {
                    Picker("Show", selection: $showFavoritesOnly) {
                        Text("All").tag(false)
                        Text("Favorites").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)

                    if shown.isEmpty {
                        Text(showFavoritesOnly ? "No favorites yet. Tap the heart on a verse to keep it here." : "Verses you complete will appear here.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .cardRow()
                    }
                    ForEach(shown) { record in
                        NavigationLink {
                            RecordDetailView(record: record)
                        } label: {
                            RecordRow(record: record)
                        }
                        .cardRow()
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            model.context.delete(shown[index])
                        }
                        try? model.context.save()
                    }
                } header: {
                    Text("History")
                }
            }
            .screenBackground()
            .navigationTitle("Journey")
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .fullScreenCover(isPresented: $isMemorizing) {
                MemorizeView(records: Array(records.shuffled().prefix(5)))
            }
        }
    }
}

struct StatTile: View {
    let value: Int
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.accent)
            Text(verbatim: "\(value)")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct RecordRow: View {
    let record: VerseRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.asVerse.referenceText)
                    .font(.headline)
                    .foregroundStyle(Color.white)
                if record.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                Text(record.completedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Text(record.text)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

/// One completed verse: full text, reflection, favourite, share, and a link to read the chapter.
struct RecordDetailView: View {
    @Bindable var record: VerseRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(record.text)
                    .font(.system(size: record.asVerse.isChinese ? 28 : 24, weight: .medium, design: .serif))
                    .lineSpacing(8)
                    .foregroundStyle(Color.white)
                Text(verbatim: "\(record.asVerse.referenceText) · \(record.asVerse.version.shortName)")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                Text(record.completedAt.formatted(date: .complete, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)

                Text("Reflection")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                TextField("Write a thought (optional)", text: $record.reflection, axis: .vertical)
                    .lineLimit(3...8)
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 12) {
                    Button {
                        record.isFavorite.toggle()
                    } label: {
                        Label(record.isFavorite ? "Saved" : "Favorite", systemImage: record.isFavorite ? "heart.fill" : "heart")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    ShareVerseButton(verse: record.asVerse)
                }

                NavigationLink {
                    ChapterReaderView(bookID: record.bookID, chapter: record.chapter, highlightVerse: record.verse)
                } label: {
                    Label("Read the whole chapter", systemImage: "book")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Premium: a short quiz on verses already read, with more words hidden than in the morning.
struct MemorizeView: View {
    let records: [VerseRecord]

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [ChallengeSession] = []
    @State private var index = 0
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if isLoading {
                ProgressView()
            } else if index < sessions.count {
                VStack(spacing: 0) {
                    Text("Verse \(index + 1) of \(sessions.count)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 12)
                    VerseChallengeView(session: sessions[index], onSolved: {
                        withAnimation { index += 1 }
                    }, onClose: {
                        dismiss()
                    })
                    .id(sessions[index].id)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.accent)
                    Text("Well done")
                        .font(.largeTitle.weight(.bold))
                    Text("Verses reviewed: \(sessions.count)")
                        .foregroundStyle(Theme.secondaryText)
                    Button("Done") { dismiss() }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 12)
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            var built: [ChallengeSession] = []
            for record in records {
                built.append(await model.makeSession(
                    verse: record.asVerse, blankCount: 4, mode: .tap, kind: .memorize, fromAlarm: false))
            }
            sessions = built
            isLoading = false
        }
    }
}
