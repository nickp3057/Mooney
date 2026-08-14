import SwiftUI

enum SubscriptionSortOption: String, CaseIterable, Identifiable {
    case nextDue = "Next Up"
    case added = "Order Added"
    case amount = "Amount"

    var id: String { rawValue }
}

struct CalendarView: View {
    @Environment(AppStore.self) var store
    @State private var displayedMonth = Calendar.current.startOfDay(for: Date())
    @State private var selectedDate: Date? = Calendar.current.startOfDay(for: Date())
    @State private var editingSubscription: Subscription?
    @State private var showAdd = false
    @State private var loggingPaymentId: String?
    @AppStorage("subscriptionSortOption") private var sortOption: SubscriptionSortOption = .nextDue

    private var allSubscriptionsSorted: [Subscription] {
        switch sortOption {
        case .nextDue: return store.state.subscriptions.sorted { $0.nextDueDate < $1.nextDueDate }
        case .added:   return store.state.subscriptions
        case .amount:  return store.state.subscriptions.sorted { $0.amount > $1.amount }
        }
    }

    private let cal = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthEvents: [CalendarEvent] {
        store.calendarEvents(forMonthContaining: displayedMonth)
    }

    private var eventsByDay: [Date: [CalendarEvent]] {
        Dictionary(grouping: monthEvents) { cal.startOfDay(for: $0.date) }
    }

    private var selectedDayEvents: [CalendarEvent] {
        guard let selectedDate else { return [] }
        return eventsByDay[selectedDate] ?? []
    }

    private var gridDays: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start)
        let leadingBlanks = firstWeekday - 1
        let dayCount = cal.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayCount {
            days.append(cal.date(byAdding: .day, value: offset, to: interval.start))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var monthTitle: String {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        return df.string(from: displayedMonth)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                            Spacer()
                            Text(monthTitle).font(.headline)
                            Spacer()
                            Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                        }
                        .foregroundStyle(store.accentColor)

                        HStack {
                            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                                Text(s)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                                dayCell(day)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowSeparator(.hidden)

                if let selectedDate {
                    Section(agendaTitle(for: selectedDate)) {
                        if selectedDayEvents.isEmpty {
                            Text("Nothing scheduled").foregroundStyle(.secondary)
                        } else {
                            ForEach(selectedDayEvents) { event in
                                eventRow(event)
                            }
                        }
                    }
                } else if store.state.subscriptions.isEmpty {
                    Section("All Subscriptions") {
                        Text("No subscriptions yet.").foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        HStack {
                            Text("Total / mo")
                            Spacer()
                            Text(fmt(store.monthlySubscriptionTotal)).foregroundStyle(.secondary)
                        }
                        Picker("Sort by", selection: $sortOption) {
                            ForEach(SubscriptionSortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    Section("All Subscriptions") {
                        ForEach(allSubscriptionsSorted) { sub in
                            subscriptionRow(sub)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Subscriptions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editingSubscription) { SubscriptionEditView(subscription: $0) }
            .sheet(isPresented: $showAdd) { SubscriptionAddView() }
            .sheet(isPresented: Binding(
                get: { loggingPaymentId != nil },
                set: { if !$0 { loggingPaymentId = nil } }
            )) {
                if let loggingPaymentId {
                    LogCardPaymentView(paymentId: loggingPaymentId)
                }
            }
        }
    }

    private func agendaTitle(for date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        return df.string(from: date)
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let events = eventsByDay[day] ?? []
            let subscriptionEvents = events.filter { $0.kind == .subscription }
            let otherEvents = events.filter { $0.kind != .subscription }
            let subscriptionTotal = subscriptionEvents.compactMap(\.amount).reduce(0, +)
            let isSelected = selectedDate.map { cal.isDate(day, inSameDayAs: $0) } ?? false
            let isToday = cal.isDateInToday(day)
            Button {
                if let selectedDate, cal.isDate(day, inSameDayAs: selectedDate) {
                    self.selectedDate = nil
                } else {
                    selectedDate = day
                }
            } label: {
                VStack(spacing: 3) {
                    Text("\(cal.component(.day, from: day))")
                        .font(.system(size: 14, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isSelected ? Color.white : (isToday ? store.accentColor : .primary))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(isSelected ? store.accentColor : Color.clear)
                        )
                    if !subscriptionEvents.isEmpty {
                        Text(fmtCompact(subscriptionTotal))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(hex: "#5E5CE6"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(height: 10)
                    } else if !otherEvents.isEmpty {
                        HStack(spacing: 2) {
                            ForEach(Array(otherEvents.prefix(3).enumerated()), id: \.offset) { _, e in
                                Circle().fill(Color(hex: e.colorHex)).frame(width: 4, height: 4)
                            }
                        }
                        .frame(height: 10)
                    } else {
                        Color.clear.frame(height: 10)
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 48)
        }
    }

    @ViewBuilder
    private func eventRow(_ event: CalendarEvent) -> some View {
        Button {
            handleTap(event)
        } label: {
            HStack(spacing: 10) {
                Circle().fill(Color(hex: event.colorHex)).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title).foregroundStyle(.primary)
                    Text(event.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func subscriptionRow(_ sub: Subscription) -> some View {
        Button { editingSubscription = sub } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundStyle(store.accentColor)
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.name).foregroundStyle(.primary)
                    Text("\(sub.cadence.label) · due \(fmtDueDate(sub.nextDueDate))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(fmt(sub.amount)).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func handleTap(_ event: CalendarEvent) {
        switch event.kind {
        case .subscription:
            editingSubscription = store.state.subscriptions.first { $0.id == event.sourceId }
        case .cardPayment:
            guard let cardId = event.sourceId else { return }
            let dueISO = isoDateFormatter.string(from: event.date)
            guard let payment = store.state.cardPayments.first(where: { $0.cardId == cardId && $0.dueDate == dueISO && !$0.isPaid }) else { return }
            loggingPaymentId = payment.id
        case .paycheck:
            break
        }
    }

    private func changeMonth(by delta: Int) {
        guard let newMonth = cal.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = newMonth
    }
}

// Rounds to the nearest dollar for the tight calendar-cell label — the
// agenda list below shows the precise amount.
private func fmtCompact(_ n: Double) -> String {
    "$\(Int(n.rounded()))"
}
