import SwiftUI

/// One achievement / milestone / point / perfection row with status icon and optional progress bar.
struct StatusRow: View {
    let line: StatusLine

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: Theme.symbol(line.state))
                .foregroundStyle(Theme.color(line.state))
                .font(.system(size: 15))
                .frame(width: 18)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if line.kind == .achievement {
                        Image(systemName: "trophy.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.accent)
                            .help("Steam / in-game achievement")
                    }
                    RichTextView(text: line.text)
                }
                if let p = line.progress {
                    ProgressBar(fraction: p.goal > 0 ? min(p.current / p.goal, 1) : 0, state: line.state, label: line.progressLabel)
                }
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panelAlt.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
    }
}

struct ProgressBar: View {
    let fraction: Double
    let state: StatusLine.State
    let label: String?

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.barTrack)
                    Capsule().fill(Theme.color(state)).frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 6)
            .frame(maxWidth: 260)
            if let label {
                Text(label).font(.caption2).monospacedDigit().foregroundStyle(Theme.secondaryText)
            } else {
                Text("\(Int((fraction * 100).rounded()))%").font(.caption2).monospacedDigit().foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

struct BlockView: View {
    let block: Block

    var body: some View {
        switch block {
        case .result(let t):
            prefixed("diamond.fill", t)
        case .note(let t):
            prefixed("info.circle", t.italicized())
        case .explain(let t):
            prefixed("asterisk", t.italicized())
        case .warn(let t):
            prefixed("exclamationmark.triangle.fill", t.italicized()).fontWeight(.semibold)
        case .achList(let items):
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    StatusRow(line: item)
                }
            }
            .padding(.leading, 22)
            .padding(.bottom, 4)
        case .need(let label, let items, let ordered):
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "list.bullet.clipboard").foregroundStyle(Theme.accent).font(.caption)
                    RichTextView(text: label.bolded())
                }
                if !items.isEmpty {
                    NeedListView(items: items, ordered: ordered)
                        .padding(.leading, 18)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panelAlt.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            .padding(.leading, 22)
            .padding(.bottom, 4)
        case .list(let items, let ordered):
            DetailListView(items: items, ordered: ordered)
                .padding(.leading, 22)
                .padding(.bottom, 4)
        case .friends(let groups):
            FriendsView(groups: groups)
        case .calendar(let data):
            CalendarView(data: data)
        }
    }

    private func prefixed(_ symbol: String, _ t: RichText) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol).font(.system(size: 9)).foregroundStyle(Theme.accent).frame(width: 12)
            RichTextView(text: t)
        }
        .padding(.leading, 4)
    }
}

/// Nested ordered/unordered list (the site's <ol>/<ul> inside details).
struct DetailListView: View {
    let items: [DetailItem]
    let ordered: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(numbered.enumerated()), id: \.element.0.id) { _, pair in
                let (item, n) = pair
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(ordered ? "\(n)." : "•")
                            .foregroundStyle(Theme.secondaryText)
                            .frame(minWidth: ordered ? 22 : 10, alignment: .trailing)
                            .monospacedDigit()
                        RichTextView(text: item.text)
                    }
                    if !item.children.isEmpty {
                        DetailListView(items: item.children, ordered: item.childrenOrdered)
                            .padding(.leading, 26)
                    }
                }
            }
        }
    }

    private var numbered: [(DetailItem, Int)] {
        var n = 0
        return items.map { item in
            n = item.value ?? (n + 1)
            return (item, n)
        }
    }
}

struct CellView: View {
    let cell: Cell
    let showSummary: Bool
    let showDetails: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showSummary {
                ForEach(cell.summary) { BlockView(block: $0) }
            }
            if showDetails {
                ForEach(cell.details) { BlockView(block: $0) }
            }
        }
    }
}
