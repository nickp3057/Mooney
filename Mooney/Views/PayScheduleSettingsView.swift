import SwiftUI

struct PayScheduleSettingsView: View {
    @Environment(AppStore.self) var store
    @Environment(\.tabAccentColor) private var accentColor
    @Environment(\.dismiss) var dismiss

    @State private var nextPayDate = Date()
    @State private var frequency: TransferFrequency = .biweekly

    var body: some View {
        Form {
            Section {
                DatePicker("Next Pay Date", selection: $nextPayDate, displayedComponents: .date)
                Picker("Repeats", selection: $frequency) {
                    ForEach(TransferFrequency.allCases) { f in
                        Text(f.label).tag(f)
                    }
                }
                .pickerStyle(.menu)
            } footer: {
                Text("Set this once and the app will use your actual upcoming pay dates to calculate how much you need per paycheck to hit a savings goal.")
                    .foregroundStyle(Color.helperText)
            }

            Section {
                Button("Save") {
                    store.setPaySchedule(nextPayDate: isoDateFormatter.string(from: nextPayDate), frequency: frequency)
                    dismiss()
                }
                .foregroundStyle(accentColor)
            }

            if store.state.paySchedule != nil {
                Section {
                    Button("Clear Schedule", role: .destructive) {
                        store.clearPaySchedule()
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("Paycheck Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let schedule = store.state.paySchedule {
                nextPayDate = isoDateFormatter.date(from: schedule.nextPayDate) ?? Date()
                frequency = schedule.frequency
            }
        }
    }
}
