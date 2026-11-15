import SwiftData
import SwiftUI

/// Home screen: today's verse and the list of alarms.
struct AlarmListView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: [SortDescriptor(\AlarmEntry.hour), SortDescriptor(\AlarmEntry.minute)]) private var alarms: [AlarmEntry]
    @Query private var records: [VerseRecord]

    @State private var editing: AlarmEntry?
    @State private var isAdding = false

    private var streak: StreakSummary {
        StreakCalculator.summarize(dates: records.map { $0.completedAt }, now: Date(), calendar: .current)
    }

    var body: some View {
        @Bindable var alarmService = model.alarms
        NavigationStack {
            List {
                Section {
                    TodayCard(streak: streak)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if model.alarms.permission == .denied {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Alarms are turned off", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .foregroundStyle(Theme.accent)
                            Text("Bible Alarm needs permission to ring. Allow alarms in the Settings app.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .cardRow()
                    }
                }

                Section {
                    if alarms.isEmpty {
                        VStack(spacing: 10) {
                            Text("No alarms yet")
                                .font(.headline)
                            Text("Add an alarm to start each day with a verse.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .cardRow()
                    }
                    ForEach(alarms) { alarm in
                        AlarmRow(alarm: alarm) {
                            editing = alarm
                        }
                        .cardRow()
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            model.deleteAlarm(alarms[index])
                        }
                    }
                } header: {
                    Text("Alarms")
                }
            }
            .screenBackground()
            .navigationTitle("Bible Alarm")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add alarm")
                }
            }
            .sheet(item: $editing) { alarm in
                AlarmEditorView(alarm: alarm)
            }
            .sheet(isPresented: $isAdding) {
                AlarmEditorView(alarm: nil)
            }
            .alert("Alarm", isPresented: Binding(
                get: { alarmService.errorMessage != nil },
                set: { if !$0 { alarmService.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alarmService.errorMessage ?? "")
            }
        }
    }
}

/// Card at the top of the home screen: streak and a button to read today's verse.
struct TodayCard: View {
    @Environment(AppModel.self) private var model
    let streak: StreakSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sunrise.fill")
                    .font(.title)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Label {
                    Text(verbatim: "\(streak.current)")
                } icon: {
                    Image(systemName: "flame.fill")
                }
                    .font(.headline)
                    .foregroundStyle(streak.current > 0 ? Theme.accent : Theme.faintText)
                    .accessibilityLabel("Streak")
            }
            Text(streak.completedToday ? "Today's verse is done" : "Start today with God's word")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.white)
            Button {
                Task { await model.startTodaysChallenge(fromAlarm: false) }
            } label: {
                Text(streak.completedToday ? "Read it again" : "Read today's verse")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct AlarmRow: View {
    @Environment(AppModel.self) private var model
    @Bindable var alarm: AlarmEntry
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Formatters.time(hour: alarm.hour, minute: alarm.minute))
                        .font(.system(size: 40, weight: .light, design: .rounded))
                        .foregroundStyle(alarm.isEnabled ? Color.white : Theme.faintText)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { newValue in
                    alarm.isEnabled = newValue
                    Task { await model.syncAlarm(alarm) }
                }
            ))
            .labelsHidden()
            .tint(Theme.accent)
        }
        .padding(.vertical, 6)
    }

    private var subtitle: String {
        let repeatText = Formatters.repeatSummary(mask: alarm.repeatMask)
        return alarm.label.isEmpty ? repeatText : "\(alarm.label) · \(repeatText)"
    }
}
