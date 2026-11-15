import SwiftUI

/// Decides what is on screen: onboarding, the main tabs, or the wake-up verse on top of everything.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        Group {
            if model.settings.hasOnboarded {
                MainTabs()
            } else {
                OnboardingView()
            }
        }
        .fullScreenCover(item: $model.session) { session in
            ChallengeFlowView(session: session)
        }
        .task {
            model.store.start()
            await model.appBecameActive()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.appBecameActive() }
            }
        }
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            Tab("Alarms", systemImage: "alarm.fill") {
                AlarmListView()
            }
            Tab("Journey", systemImage: "flame.fill") {
                JourneyView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}
