import SwiftUI
import UIKit

struct NotesView: View {
    @Environment(AppStore.self) var store
    @State private var copied = false

    var sorted: [Income] { store.state.incomes.sorted { $0.date > $1.date } }

    func bucketName(_ id: String) -> String {
        store.state.buckets.first { $0.id == id }?.name ?? id
    }

    func shortDate(_ iso: String) -> String {
        let p = iso.split(separator: "-")
        guard p.count == 3,
              let m = Int(p[1]), let d = Int(p[2]) else { return iso }
        return "\(m)/\(d)/\(String(p[0]).suffix(2))"
    }

    func buildText() -> String {
        store.state.incomes.sorted { $0.date < $1.date }.map { p in
            var lines = [shortDate(p.date), "$\(String(format: "%.2f", p.amount))"]
            for bill in p.bills {
                lines.append("\(bill.name)- \(String(format: "%.2f", bill.amount))")
            }
            for a in p.allocations {
                lines.append("\(bucketName(a.bucketId))- \(String(format: "%.2f", a.amount))")
            }
            if !p.note.isEmpty { lines.append(p.note) }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    var body: some View {
        List {
            ForEach(sorted) { p in
                Section {
                    HStack {
                        Text(shortDate(p.date)).font(.headline)
                        Spacer()
                        Text("$\(String(format: "%.2f", p.amount))").font(.headline)
                    }
                    if !p.note.isEmpty {
                        Text(p.note.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(store.accentColor)
                    }
                    ForEach(p.bills) { bill in
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(store.accentColor)
                                .frame(width: 8, height: 8)
                            Text("\(bill.name)-")
                                .font(.callout).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2f", bill.amount)).font(.callout)
                        }
                    }
                    ForEach(p.allocations, id: \.bucketId) { a in
                        let b = store.state.buckets.first { $0.id == a.bucketId }
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(b?.color ?? .gray).frame(width: 8, height: 8)
                            Text("\(bucketName(a.bucketId))-")
                                .font(.callout).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2f", a.amount)).font(.callout)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(copied ? "Copied!" : "Copy All") {
                    UIPasteboard.general.string = buildText()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                }
                .foregroundStyle(copied ? .green : store.accentColor)
            }
        }
    }
}
