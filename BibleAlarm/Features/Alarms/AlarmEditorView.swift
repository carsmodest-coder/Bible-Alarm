import SwiftData
import SwiftUI

/// Create or edit an alarm: time, repeat days, label, sound, difficulty and follow-up interval.
struct AlarmEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Query private var customSounds: [CustomSound]

    private let alarm: AlarmEntry?

    @State private var time: Date
    @State private var label: String
    @State private var repeatMask: Int
    @State private var soundID: String
    @State private var difficulty: Difficulty
    @State private var backupInterval: Int
    @State private var isSaving = false

    init(alarm: AlarmEntry?) {
        self.alarm = alarm
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: alarm?.hour ?? 7, minute: alarm?.minute ?? 0, second: 0, of: Date()) ?? Date()
        _time = State(initialValue: start)
        _label = State(initialValue: alarm?.label ?? "")
        _repeatMask = State(initialValue: alarm?.repeatMask ?? Weekdays.everyDay)
        _soundID = State(initialValue: alarm?.soundID ?? SoundID.defaultID)
        _difficulty = State(initialValue: alarm?.difficulty ?? .normal)
        _backupInterval = State(initialValue: alarm?.backupIntervalMinutes ?? BackupPolicy.defaultInterval)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }
                .cardRow()

                Section("Repeat") {
                    WeekdayPicker(mask: $repeatMask)
                    Text(Formatters.repeatSummary(mask: repeatMask))
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
                .cardRow()

                Section {
                    TextField("Label", text: $label)
                    NavigationLink {
                        SoundPickerView(selection: $soundID)
                    } label: {
                        LabeledContent("Sound", value: SoundCatalog.resolve(soundID, customSounds: customSounds).displayName)
                    }
                }
                .cardRow()

                Section {
                    Picker("Difficulty", selection: $difficulty) {
                        Text("Easy (1 word)").tag(Difficulty.easy)
                        Text("Normal (2 words)").tag(Difficulty.normal)
                    }
                    Picker("Ring again every", selection: $backupInterval) {
                        ForEach(BackupPolicy.allowedIntervals, id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                } footer: {
                    Text("If you stop the alarm without finishing the verse, it rings again until you do.")
                }
                .cardRow()

                if let alarm {
                    Section {
                        Button("Delete alarm", role: .destructive) {
                            model.deleteAlarm(alarm)
                            dismiss()
                        }
                    }
                    .cardRow()
                }
            }
            .screenBackground()
            .navigationTitle(alarm == nil ? "New alarm" : "Edit alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving)
                }
            }
            .onDisappear { model.player.stop() }
        }
    }

    private func save() {
        isSaving = true
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let entry: AlarmEntry
        if let alarm {
            entry = alarm
        } else {
            entry = AlarmEntry(hour: 7, minute: 0)
            model.context.insert(entry)
        }
        entry.hour = parts.hour ?? 7
        entry.minute = parts.minute ?? 0
        entry.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.repeatMask = repeatMask
        entry.soundID = soundID
        entry.difficulty = difficulty
        entry.backupIntervalMinutes = backupInterval
        entry.isEnabled = true
        Task {
            await model.syncAlarm(entry)
            dismiss()
        }
    }
}

/// Seven round buttons, one per day of the week.
struct WeekdayPicker: View {
    @Binding var mask: Int

    var body: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let isOn = Weekdays.contains(mask, day: day)
                Button {
                    mask ^= 1 << (day - 1)
                } label: {
                    Text(symbols[day - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .foregroundStyle(isOn ? Color.black : Color.white)
                        .background(isOn ? Theme.accent : Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}
