import SwiftUI

/// Three pages shown once: what the app is for, alarm permission, and the Bible version.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var page = 0

    var body: some View {
        @Bindable var settings = model.settings
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    OnboardingPage(
                        systemImage: "sunrise.fill",
                        title: "Wake up to God's word",
                        message: "When your alarm rings, a Bible verse is waiting. Fill in the missing word to start your day.")
                        .tag(0)

                    OnboardingPage(
                        systemImage: "alarm.fill",
                        title: "An alarm that waits for you",
                        message: "If you stop the alarm without reading, it rings again every few minutes until you finish the verse. Bible Alarm needs your permission to ring, even in Silent mode.")
                        .tag(1)

                    VStack(spacing: 20) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Theme.accent)
                        Text("Choose your Bible")
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                        VStack(spacing: 10) {
                            ForEach(BibleVersion.all) { version in
                                Button {
                                    settings.bibleVersionID = version.id
                                } label: {
                                    HStack {
                                        Text(verbatim: version.name)
                                            .font(.headline)
                                            .foregroundStyle(Color.white)
                                        Spacer()
                                        Image(systemName: settings.bibleVersionID == version.id ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(settings.bibleVersionID == version.id ? Theme.accent : Theme.faintText)
                                    }
                                    .padding(18)
                                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("You can change this later in Settings. The app follows your iPhone's language (English or 繁體中文).")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(buttonTitle) {
                    advance()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private var buttonTitle: LocalizedStringKey {
        switch page {
        case 0: return "Continue"
        case 1: return "Allow alarms"
        default: return "Get started"
        }
    }

    private func advance() {
        switch page {
        case 0:
            withAnimation { page = 1 }
        case 1:
            Task {
                await model.alarms.requestPermission()
                withAnimation { page = 2 }
            }
        default:
            model.settings.hasOnboarded = true
        }
    }
}

struct OnboardingPage: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 72))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.title3)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(28)
    }
}
