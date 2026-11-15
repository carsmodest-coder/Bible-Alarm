import SwiftData
import SwiftUI

@main
struct BibleAlarmApp: App {
    @State private var model: AppModel

    init() {
        do {
            let container = try ModelContainer(for: AlarmEntry.self, CustomSound.self, VerseRecord.self)
            _model = State(initialValue: AppModel(container: container))
        } catch {
            fatalError("Could not open the app's database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(model.container)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
