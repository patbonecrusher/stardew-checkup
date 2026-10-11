import SwiftUI

/// Heart-event to-do list: per villager, what can be triggered now and what it takes to unlock the rest.
struct EventPlannerView: View {
    let data: EventPlanData
    @State private var hideComplete = true
    @State private var onlyReady = false
    @State private var onlyCandidates = false
    @State private var filter = ""

    private var rows: [EventPlanRow] {
        data.rows.filter { r in
            (!hideComplete || !r.isComplete) &&
            (!onlyReady || r.readyCount > 0) &&
            (!onlyCandidates || r.isMarriageCandidate) &&
            (filter.isEmpty || r.name.localizedCaseInsensitiveContains(filter))
        }
        .sorted { a, b in
            // Ready events first, then the closest locked event, then name.
            if (a.readyCount > 0) != (b.readyCount > 0) { return a.readyCount > 0 }
            let an = a.steps.first { $0.kind == .locked }?.pointsNeeded ?? Int.max
            let bn = b.steps.first { $0.kind == .locked }?.pointsNeeded ?? Int.max
            if an != bn { return an < bn }
            return a.name < b.name
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                TextField("Search villagers", text: $filter).textFieldStyle(.roundedBorder).frame(width: 180)
                Toggle("Hide villagers with nothing left", isOn: $hideComplete)
                Toggle("Only ready now", isOn: $onlyReady)
                Toggle("Marriage candidates only", isOn: $onlyCandidates)
                Spacer()
                Text("\(rows.count) shown").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            .toggleStyle(.checkbox).font(.callout)
            HStack(spacing: 12) {
                legend("Ready: go trigger it", "play.circle.fill", Theme.yes)
                legend("Needs more hearts", "lock.fill", Theme.accent)
                legend("Needs a bouquet", "gift.fill", Theme.heart)
                legend("Needs a wedding", "heart.circle.fill", Theme.heart)
                legend("No longer possible", "minus.circle.fill", Theme.impossible)
            }
            .font(.caption).foregroundStyle(Theme.secondaryText)
            if rows.isEmpty {
                Text("Nothing to show with the current filters.").foregroundStyle(Theme.secondaryText).padding(.vertical, 8)
            }
            ForEach(rows) { row in
                EventPlanRowView(row: row)
            }
        }
        .padding(.leading, 22)
        .padding(.bottom, 4)
    }

    private func legend(_ text: String, _ symbol: String, _ color: Color) -> some View {
        Label(text, systemImage: symbol).foregroundStyle(color)
    }
}

private struct EventPlanRowView: View {
    let row: EventPlanRow

    private var url: URL? { wikify(row.name).runs.first?.url }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let url {
                        Link(row.name, destination: url).foregroundStyle(Theme.link)
                    } else {
                        Text(row.name)
                    }
                    if row.readyCount > 0 {
                        Text("\(row.readyCount) ready").font(.caption.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Theme.yes.opacity(0.2), in: Capsule()).foregroundStyle(Theme.yes)
                    }
                }
                .font(.body.weight(.semibold))
                HeartMeter(filled: row.hearts, total: row.maxHearts, lockedFrom: row.lockedFrom)
                Text("\(row.hearts)♥ · \(row.points) pts · \(row.status)").font(.caption).foregroundStyle(Theme.secondaryText)
                Text("\(row.seenCount)/\(row.totalTracked) events seen").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            .frame(width: 190, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                if row.isComplete {
                    Text(row.totalTracked == 0 ? "No tracked heart events." : "All possible heart events seen.")
                        .font(.callout).foregroundStyle(Theme.secondaryText)
                }
                ForEach(row.steps) { step in
                    EventStepView(step: step, villager: row.name)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(Theme.panelAlt.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(row.readyCount > 0 ? Theme.yes.opacity(0.5) : Color.clear, lineWidth: 1))
    }
}

private struct EventStepView: View {
    let step: EventStep
    let villager: String

    private var color: Color {
        switch step.kind {
        case .ready: return Theme.yes
        case .locked: return Theme.accent
        case .bouquet, .marriage: return Theme.heart
        case .impossible: return Theme.impossible
        }
    }

    private var symbol: String {
        switch step.kind {
        case .ready: return "play.circle.fill"
        case .locked: return "lock.fill"
        case .bouquet: return "gift.fill"
        case .marriage: return "heart.circle.fill"
        case .impossible: return "minus.circle.fill"
        }
    }

    private var todo: String {
        switch step.kind {
        case .ready:
            return "Ready now."
        case .locked:
            var t = "Reach \(step.hearts ?? 0)♥: \(step.pointsNeeded) more points"
            if let gift = step.bestGift {
                t += " ≈ \(step.giftsNeeded) × \(gift) (+\(step.bestGiftPoints) each)"
            } else {
                t += " ≈ \(step.giftsNeeded) loved gift(s)"
            }
            return t + ", or talk daily for +20."
        case .bouquet:
            return "Give a Bouquet (Pierre's, 200g, needs 8♥) to start dating; hearts 9–10 and this event then unlock."
        case .marriage:
            return "Only after marrying \(villager) (Mermaid's Pendant from the Old Mariner, 10♥, upgraded house)."
        case .impossible:
            return "Can no longer happen on this save."
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 16)
            Text(step.hearts.map { "\($0)♥" } ?? "♥")
                .font(.caption.weight(.bold)).monospacedDigit()
                .frame(width: 36)
                .padding(.vertical, 1)
                .background(color.opacity(0.18), in: Capsule())
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(step.title).font(.callout.weight(.semibold)).foregroundStyle(Theme.text)
                    Text(todo).font(.caption).foregroundStyle(color)
                    Spacer()
                    if let url = URL(string: "https://stardewvalleywiki.com/\(villager)#\(step.anchor)") {
                        Link(destination: url) { Image(systemName: "arrow.up.right.square") }.font(.caption)
                    }
                }
                Text(step.trigger).font(.callout).foregroundStyle(step.kind == .impossible ? Theme.secondaryText : Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 3)
        .opacity(step.kind == .impossible ? 0.6 : 1)
    }
}
