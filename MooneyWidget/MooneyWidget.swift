//
//  MooneyWidget.swift
//  MooneyWidget
//
//  Created by Nick Pearson on 8/19/26.
//

import WidgetKit
import SwiftUI

struct BalanceEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetBalanceSnapshot?
}

struct BalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry {
        BalanceEntry(date: Date(), snapshot: WidgetBalanceSnapshot(accountName: "Checking", balance: 1234.56, asOf: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (BalanceEntry) -> Void) {
        completion(BalanceEntry(date: Date(), snapshot: WidgetBalanceStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceEntry>) -> Void) {
        let entry = BalanceEntry(date: Date(), snapshot: WidgetBalanceStore.read())
        // The main app nudges WidgetCenter.reloadTimelines whenever it
        // fetches a fresh balance; this periodic re-check is just the
        // fallback for when the app hasn't been opened in a while. Actual
        // cadence is still capped by iOS's background refresh budget —
        // that's the "(relatively) current" tradeoff of a cached-snapshot
        // widget instead of one that calls the Tailscale-only backend
        // directly (which background widget refreshes can't reliably do).
        let nextCheck = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextCheck)))
    }
}

struct MooneyWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: BalanceEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryInline:
            inlineView
        default:
            rectangularView
        }
    }

    private var circularView: some View {
        Gauge(value: 1) {
            Image(systemName: "dollarsign")
        } currentValueLabel: {
            if let snapshot = entry.snapshot {
                Text(Self.compact(snapshot.balance))
                    .font(.system(size: 14, weight: .semibold))
                    .minimumScaleFactor(0.6)
            } else {
                Image(systemName: "questionmark")
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let snapshot = entry.snapshot {
                Text(snapshot.accountName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(Self.currency(snapshot.balance))
                    .font(.system(size: 20, weight: .semibold))
                    .minimumScaleFactor(0.7)
                Text(snapshot.asOf, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Mooney")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Not connected")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
    }

    private var inlineView: some View {
        Group {
            if let snapshot = entry.snapshot {
                Text("\(snapshot.accountName): \(Self.currency(snapshot.balance))")
            } else {
                Text("Mooney: not connected")
            }
        }
    }

    private static func currency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }

    private static func compact(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

struct MooneyWidget: Widget {
    let kind: String = "MooneyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BalanceProvider()) { entry in
            MooneyWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Checking Balance")
        .description("Shows your connected checking account balance.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .accessoryRectangular) {
    MooneyWidget()
} timeline: {
    BalanceEntry(date: .now, snapshot: WidgetBalanceSnapshot(accountName: "Checking", balance: 1532.10, asOf: .now))
    BalanceEntry(date: .now, snapshot: nil)
}
