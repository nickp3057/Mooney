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

    private var accentColor: Color { store.accentColor(for: .subscriptions) }

    private func sortedSubset(_ subs: [Subscription]) -> [Subscription] {
        switch sortOption {
        case .nextDue:
            return subs.sorted { ($0.upcomingDueDate() ?? .distantFuture) < ($1.upcomingDueDate() ?? .distantFuture) }
        case .added:
            return subs
        case .amount:
            return subs.sorted { $0.amount > $1.amount }
        }
    }

    private var monthlySubscriptionsSorted: [Subscription] {
        sortedSubset(store.state.subscriptions.filter { $0.cadence != .yearly })
    }

    private var yearlySubscriptionsSorted: [Subscription] {
        sortedSubset(store.state.subscriptions.filter { $0.cadence == .yearly })
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

    // Subscription charges landing in the displayed month.
    private var displayedMonthSubscriptionTotal: Double {
        monthEvents.filter { $0.kind == .subscription }.compactMap(\.amount).reduce(0, +)
    }

    private var isShowingCurrentMonth: Bool {
        cal.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
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
                    monthCard
                }
                .cardRow()

                Section {
                    HStack(spacing: 10) {
                        StatTile(
                            title: isShowingCurrentMonth ? "Due this month" : "Due in \(shortMonthTitle)",
                            value: fmt(displayedMonthSubscriptionTotal),
                            tint: accentColor,
                            systemImage: "calendar"
                        )
                        StatTile(
                            title: "Every month",
                            value: fmt(store.monthlySubscriptionTotal),
                            systemImage: "arrow.clockwise"
                        )
                    }
                }
                .cardRow()

                if let selectedDate {
                    Section(agendaTitle(for: selectedDate)) {
                        if selectedDayEvents.isEmpty {
                            HStack(spacing: 12) {
                                SoftIconTile(systemName: "checkmark", color: .secondary, size: 30)
                                Text("Nothing scheduled").foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(selectedDayEvents) { event in
                                eventRow(event)
                            }
                        }
                    }
                }

                if store.state.subscriptions.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No subscriptions yet", systemImage: "arrow.clockwise.circle")
                        } description: {
                            Text("Add the things that bill you every month or year to see them on the calendar.")
                        } actions: {
                            Button("Add Subscription") { showAdd = true }
                                .buttonStyle(.pill(accentColor, prominent: true))
                        }
                        .padding(.vertical, 8)
                    }
                    .cardRow()
                } else {
                    Section {
                        Picker("Sort by", selection: $sortOption) {
                            ForEach(SubscriptionSortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .cardRow()

                    if !monthlySubscriptionsSorted.isEmpty {
                        Section("Monthly") {
                            ForEach(monthlySubscriptionsSorted) { sub in
                                subscriptionRow(sub)
                            }
                        }
                    }
                    if !yearlySubscriptionsSorted.isEmpty {
                        Section("Yearly") {
                            ForEach(yearlySubscriptionsSorted) { sub in
                                subscriptionRow(sub)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(14)
            .screenBackground()
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
        .environment(\.tabAccentColor, accentColor)
    }

    private var shortMonthTitle: String {
        let df = DateFormatter()
        df.dateFormat = "MMM"
        return df.string(from: displayedMonth)
    }

    // MARK: - Month grid

    private var monthCard: some View {
        VStack(spacing: 14) {
            HStack {
                monthNavButton("chevron.left") { changeMonth(by: -1) }
                Spacer()
                Button {
                    withAnimation(.snappy) {
                        displayedMonth = cal.startOfDay(for: Date())
                        selectedDate = cal.startOfDay(for: Date())
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(monthTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if !isShowingCurrentMonth {
                            Text("Today")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(accentColor.opacity(0.14)))
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                monthNavButton("chevron.right") { changeMonth(by: 1) }
            }

            HStack {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                    dayCell(day)
                }
            }
            .id(displayedMonth)
            .contentShape(Rectangle())
            // .simultaneousGesture (not .gesture) so this never claims the
            // touch ahead of the List's own vertical scroll pan — both get
            // to recognize, and the direction check below just no-ops on a
            // vertical drag instead of blocking the scroll.
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        guard abs(horizontal) > abs(vertical) else { return }
                        changeMonth(by: horizontal < 0 ? 1 : -1)
                    }
            )
        }
        .surfaceCard()
    }

    private func monthNavButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accentColor)
                .frame(width: 30, height: 30)
                .background(Circle().fill(accentColor.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }

    private func agendaTitle(for date: Date) -> String {
        if cal.isDateInToday(date) { return "Today" }
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        return df.string(from: date)
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let events = eventsByDay[day] ?? []
            let subscriptionEvents = events.filter { $0.kind == .subscription }
            let cardEvents = events.filter { $0.kind == .cardPayment }
            let hasPaycheck = events.contains { $0.kind == .paycheck }
            let subscriptionTotal = subscriptionEvents.compactMap(\.amount).reduce(0, +)
            let cardColorHex = cardEvents.contains { $0.colorHex == "#FF3B30" } ? "#FF3B30" : "#8E8E93"
            let isSelected = selectedDate.map { cal.isDate(day, inSameDayAs: $0) } ?? false
            let isToday = cal.isDateInToday(day)
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    if let selectedDate, cal.isDate(day, inSameDayAs: selectedDate) {
                        self.selectedDate = nil
                    } else {
                        selectedDate = day
                    }
                }
            } label: {
                VStack(spacing: 3) {
                    Text("\(cal.component(.day, from: day))")
                        .font(.system(size: 15, weight: isToday || isSelected ? .bold : .regular, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : (isToday ? accentColor : .primary))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(isSelected ? accentColor : (isToday ? accentColor.opacity(0.14) : Color.clear))
                        )
                    HStack(spacing: 2) {
                        if !subscriptionEvents.isEmpty {
                            Text(fmtCompact(subscriptionTotal))
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#5E5CE6"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        if hasPaycheck {
                            Text("$")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(hex: "#34C759"))
                        }
                        if !cardEvents.isEmpty {
                            Circle().fill(Color(hex: cardColorHex)).frame(width: 5, height: 5)
                        }
                    }
                    .frame(height: 11)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 46)
        }
    }

    private func iconName(for kind: CalendarEvent.Kind) -> String {
        switch kind {
        case .subscription: return "arrow.clockwise"
        case .cardPayment:  return "creditcard.fill"
        case .paycheck:     return "dollarsign"
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func eventRow(_ event: CalendarEvent) -> some View {
        Button {
            handleTap(event)
        } label: {
            HStack(spacing: 12) {
                IconTile(systemName: iconName(for: event.kind), color: Color(hex: event.colorHex), size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title).foregroundStyle(.primary)
                    Text(event.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let amount = event.amount {
                    Text(fmt(amount))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                } else if event.kind != .paycheck {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func subscriptionRow(_ sub: Subscription) -> some View {
        let cardName = sub.creditCardId.flatMap { id in store.state.creditCards.first { $0.id == id }?.name }
        let dueISO = sub.upcomingDueDate().map { isoDateFormatter.string(from: $0) } ?? sub.nextDueDate
        let initial = String(sub.name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
        Button { editingSubscription = sub } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accentColor.opacity(0.16))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Text(initial.isEmpty ? "•" : initial)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(sub.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if sub.status != .active {
                            StatusChip(title: sub.status.label, isOn: false, tint: accentColor)
                        }
                    }
                    Text("\(sub.cadence.label) · due \(fmtDueDate(dueISO))\(cardName.map { " · \($0)" } ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(fmt(sub.amount))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .opacity(sub.status == .active ? 1 : 0.55)
            .contentShape(Rectangle())
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
        withAnimation(.snappy(duration: 0.25)) {
            displayedMonth = cal.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
        }
    }
}

// Rounds to the nearest dollar for the tight calendar-cell label — the
// agenda list below shows the precise amount.
private func fmtCompact(_ n: Double) -> String {
    "$\(Int(n.rounded()))"
}
