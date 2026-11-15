import SwiftUI

/// Display names for the Premium verse sources (themed sets and reading plans).
enum VerseSources {
    static let setIDs = ["morning", "peace", "strength", "hope", "love", "faith", "joy", "comfort", "courage",
                         "guidance", "grace", "prayer", "gratitude", "wisdom", "psalms"]

    static func name(for source: String) -> String {
        switch source {
        case "all": return String(localized: "All verses")
        case "set:morning": return String(localized: "Morning")
        case "set:peace": return String(localized: "Peace")
        case "set:strength": return String(localized: "Strength")
        case "set:hope": return String(localized: "Hope")
        case "set:love": return String(localized: "Love")
        case "set:faith": return String(localized: "Faith")
        case "set:joy": return String(localized: "Joy")
        case "set:comfort": return String(localized: "Comfort")
        case "set:courage": return String(localized: "Courage")
        case "set:guidance": return String(localized: "Guidance")
        case "set:grace": return String(localized: "Grace")
        case "set:prayer": return String(localized: "Prayer")
        case "set:gratitude": return String(localized: "Gratitude")
        case "set:wisdom": return String(localized: "Wisdom")
        case "set:psalms": return String(localized: "Psalms")
        case "plan:proverbs31": return String(localized: "Proverbs in 31 days")
        case "plan:psalms30": return String(localized: "Psalms in 30 days")
        case "plan:john21": return String(localized: "Gospel of John in 21 days")
        default: return source
        }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showPaywall = false

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }

    var body: some View {
        @Bindable var settings = model.settings
        NavigationStack {
            Form {
                Section {
                    Picker("Bible version", selection: $settings.bibleVersionID) {
                        ForEach(BibleVersion.all) { version in
                            Text(verbatim: version.name).tag(version.id)
                        }
                    }
                    Picker("Difficulty", selection: $settings.difficulty) {
                        Text("Easy (1 word)").tag(Difficulty.easy)
                        Text("Normal (2 words)").tag(Difficulty.normal)
                    }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        LabeledContent("App language") {
                            Text("Change in Settings")
                        }
                    }
                    .foregroundStyle(Color.white)
                } header: {
                    Text("Reading")
                } footer: {
                    Text("Difficulty here is used when you read the verse without an alarm. Each alarm has its own setting.")
                }
                .cardRow()

                Section {
                    if model.isPremium {
                        Picker("Answer style", selection: $settings.challengeMode) {
                            Text("Tap the word").tag(ChallengeMode.tap)
                            Text("Type the word").tag(ChallengeMode.type)
                            Text("Read aloud").tag(ChallengeMode.speak)
                        }
                        NavigationLink {
                            VerseSourceView()
                        } label: {
                            LabeledContent("Verses from", value: VerseSources.name(for: settings.verseSource))
                        }
                    } else {
                        lockedRow("Strict mode", systemImage: "text.cursor")
                        lockedRow("Themed sets and reading plans", systemImage: "books.vertical.fill")
                    }
                    Button {
                        showPaywall = true
                    } label: {
                        Label(model.isPremium ? "Premium is active" : "See Premium", systemImage: "sparkles")
                    }
                    NavigationLink {
                        TipJarView()
                    } label: {
                        Label("Tip jar", systemImage: "heart")
                    }
                    Button("Restore Purchases") {
                        Task { await model.store.restore() }
                    }
                } header: {
                    Text("Premium")
                } footer: {
                    Text("No ads, ever. No tracking.")
                }
                .cardRow()

                Section("Alarms") {
                    LabeledContent("Permission") {
                        switch model.alarms.permission {
                        case .allowed: Text("Allowed")
                        case .denied: Text("Turned off")
                        case .unknown: Text("Not asked yet")
                        }
                    }
                    if model.alarms.permission != .allowed {
                        Button("Allow alarms") {
                            if model.alarms.permission == .denied {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } else {
                                Task { await model.alarms.requestPermission() }
                            }
                        }
                    }
                }
                .cardRow()

                #if SIDELOAD_TEST
                Section {
                    Toggle("Unlock Premium for testing", isOn: $settings.testUnlock)
                } header: {
                    Text("Test build")
                } footer: {
                    Text("Only in test builds. This switch is removed from the App Store version.")
                }
                .cardRow()
                #endif

                Section {
                    NavigationLink("Credits") {
                        CreditsView()
                    }
                    LabeledContent("Version", value: appVersion)
                }
                .cardRow()
            }
            .screenBackground()
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func lockedRow(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Button {
            showPaywall = true
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                PremiumBadge()
            }
        }
    }
}

/// Premium: choose where the morning verse comes from.
struct VerseSourceView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                row("all")
            }
            .cardRow()
            Section("Themed sets") {
                ForEach(VerseSources.setIDs, id: \.self) { id in
                    row("set:" + id)
                }
            }
            .cardRow()
            Section {
                ForEach(ReadingPlan.all) { plan in
                    row("plan:" + plan.id, detail: String(localized: "Day \(model.settings.planProgress(plan.id) % max(plan.days.count, 1) + 1) of \(plan.days.count)"))
                }
            } header: {
                Text("Reading plans")
            } footer: {
                Text("A plan gives you one key verse each morning, in order, with a link to read the whole chapter.")
            }
            .cardRow()
        }
        .screenBackground()
        .navigationTitle("Verses from")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ source: String, detail: String? = nil) -> some View {
        Button {
            model.settings.verseSource = source
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: VerseSources.name(for: source))
                        .foregroundStyle(Color.white)
                    if let detail {
                        Text(verbatim: detail)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                Spacer()
                if model.settings.verseSource == source {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }
}

struct CreditsView: View {
    var body: some View {
        List {
            Section("Bible text") {
                ForEach(BibleVersion.all) { version in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: version.name)
                            .font(.headline)
                        Text(verbatim: version.credit)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                Text("Text files from the open-bibles project (github.com/seven1m/open-bibles).")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            .cardRow()

            Section("Sounds") {
                Text("The built-in alarm tones were created for Bible Alarm. Sounds you add stay on your iPhone and are never uploaded.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            .cardRow()

            Section("Privacy") {
                Text("Bible Alarm has no ads and no tracking, and it collects no data.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            .cardRow()
        }
        .screenBackground()
        .navigationTitle("Credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}
