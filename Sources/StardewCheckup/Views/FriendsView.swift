import SwiftUI

/// Social details: one row per villager with a heart meter and event pills.
struct FriendsView: View {
    let groups: [FriendGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.leading, 4)
                    VStack(spacing: 2) {
                        ForEach(group.rows) { row in
                            FriendRowView(row: row)
                        }
                    }
                }
            }
        }
        .padding(.leading, 22)
        .padding(.bottom, 4)
    }
}

struct FriendRowView: View {
    let row: FriendRow

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Name + status
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if let url = row.url {
                        Link(row.name, destination: url).foregroundStyle(Theme.link)
                    } else {
                        Text(row.name).foregroundStyle(Theme.text)
                    }
                    if row.isChild {
                        Image(systemName: "figure.and.child.holdinghands").font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                }
                .font(.body.weight(.medium))
                if !row.status.isEmpty {
                    Text(row.status).font(.caption).foregroundStyle(statusColor)
                }
            }
            .frame(width: 150, alignment: .leading)

            if let hearts = row.hearts {
                HeartMeter(filled: hearts, total: row.maxHearts, lockedFrom: row.lockedFrom)
                    .help("\(hearts)♥ (\(row.points) pts)")
                Text("\(row.points) pts")
                    .font(.caption).monospacedDigit().foregroundStyle(Theme.secondaryText)
                    .frame(width: 62, alignment: .trailing)
                RichTextView(text: row.need, baseFont: .caption)
                    .frame(width: 150, alignment: .leading)
            }

            if !row.events.isEmpty {
                HStack(spacing: 3) {
                    if row.hearts != nil {
                        Text("Events").font(.caption2).foregroundStyle(Theme.secondaryText)
                    }
                    ForEach(row.events) { ev in
                        EventPill(event: ev)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .background(Theme.panelAlt.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
    }

    private var statusColor: Color {
        switch row.status {
        case "Married", "Roommate", "Dating", "Engaged": return Theme.yes
        case "Unmet", "Divorced": return Theme.no
        default: return Theme.secondaryText
        }
    }
}

struct HeartMeter: View {
    let filled: Int
    let total: Int
    let lockedFrom: Int?

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<total, id: \.self) { i in
                let locked = lockedFrom.map { i >= $0 } ?? false
                Image(systemName: i < filled ? "heart.fill" : "heart")
                    .font(.system(size: 11))
                    .foregroundStyle(i < filled ? Theme.heart : (locked ? Theme.impossible.opacity(0.5) : Theme.secondaryText.opacity(0.6)))
                    .overlay(alignment: .bottomTrailing) {
                        if locked && i >= filled {
                            Image(systemName: "lock.fill").font(.system(size: 5)).foregroundStyle(Theme.impossible)
                        }
                    }
            }
        }
        .help(lockedFrom != nil ? "Hearts 9–10 unlock after giving a bouquet" : "")
    }
}

struct EventPill: View {
    let event: FriendEvent

    var body: some View {
        let color: Color = event.state == .yes ? Theme.yes : (event.state == .no ? Theme.no : Theme.impossible)
        Text(event.label)
            .font(.caption2.weight(.semibold)).monospacedDigit()
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(color.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1))
            .foregroundStyle(color)
            .help(tooltip)
    }

    private var tooltip: String {
        let what: String
        switch event.state {
        case .yes: what = "seen"
        case .no: what = "not seen yet"
        case .imp: what = "no longer possible"
        }
        return "\(event.label) heart event \(event.note) — \(what)".replacingOccurrences(of: "  ", with: " ")
    }
}
