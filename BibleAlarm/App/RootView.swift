import SwiftUI

/// Phase 0 placeholder screen. Its only job is to prove the build pipeline
/// works end to end: GitHub -> Codemagic -> iPhone.
struct RootView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "sunrise.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.orange)

                Text("Bible Alarm")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)

                Text("Thy word is a lamp unto my feet, and a light unto my path.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.85))

                Text("Psalm 119:105 (KJV)")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.6))

                Spacer()

                Text("Test build \(appVersion) (\(buildNumber))")
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .padding(32)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }
}
