import SwiftUI

/// Overview page: headline rings, collection progress tiles, and the goals closest to done.
struct DashboardView: View {
    let report: Report
    @EnvironmentObject var model: AppModel

    private var o: Overview { report.overview }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            headlineTiles
            collectionTiles
            closestGoals
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "leaf.circle.fill").font(.system(size: 34)).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(report.farmName) Farm").font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                Text("Farmer \(report.farmerName)" + (report.playerNames.count > 1 ? " and \(report.playerNames.count - 1) farmhand(s)" : "") + " · " + report.summaryLine)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    // MARK: Headline tiles

    private var achievementStatus: (Int, Int) {
        var done = 0, total = 0
        for section in report.sections {
            for cell in section.globalCells + (section.columns.first ?? []) + section.trailingCells {
                for block in cell.summary + cell.details {
                    guard case .achList(let lines) = block else { continue }
                    for line in lines where line.kind == .achievement {
                        total += 1
                        if line.state == .yes { done += 1 }
                    }
                }
            }
        }
        return (done, total)
    }

    private var headlineTiles: some View {
        let (achDone, achTotal) = achievementStatus
        return HStack(spacing: 12) {
            if let pct = o.perfectionPct {
                Tile(title: "Perfection", anchor: "Perfection_Tracker") {
                    Ring(fraction: pct / 100, label: toFixed(pct, pct < 100 ? 1 : 0) + "%", color: Theme.accent)
                    Text(pct >= 100 ? "Perfect!" : "Walnut Room shows \(Int(pct.rounded(.down)))%")
                        .font(.caption).foregroundStyle(Theme.secondaryText)
                }
            }
            Tile(title: "Achievements", anchor: nil) {
                Ring(fraction: achTotal > 0 ? Double(achDone) / Double(achTotal) : 0, label: "\(achDone)", color: Theme.yes)
                Text("of \(achTotal) tracked").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            if let pts = o.grandpaPoints {
                Tile(title: "Grandpa", anchor: "Grandpa_s_Evaluation") {
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { i in
                            Image(systemName: i < o.grandpaCandlesNext ? "flame.fill" : "flame")
                                .font(.system(size: 24))
                                .foregroundStyle(i < o.grandpaCandlesNext ? Theme.accent : Theme.secondaryText.opacity(0.5))
                        }
                    }
                    .padding(.vertical, 6)
                    Text("\(pts) / 21 points").font(.title3.weight(.semibold)).monospacedDigit()
                    Text("\(o.grandpaCandlesLit) lit now · next evaluation lights \(o.grandpaCandlesNext)")
                        .font(.caption).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)
                }
            }
            Tile(title: "Money", anchor: "Money") {
                let tiers = [15_000, 50_000, 250_000, 1_000_000, 10_000_000]
                let next = tiers.first { $0 > o.money }
                Text("\(addCommas(o.money))g").font(.title2.weight(.bold)).monospacedDigit()
                if let next {
                    ProgressBar(fraction: Double(o.money) / Double(next), state: .no, label: nil)
                        .frame(maxWidth: 160)
                    Text("\(addCommas(next - o.money))g to \(addCommas(next))g")
                        .font(.caption).foregroundStyle(Theme.secondaryText)
                } else {
                    Text("Every money achievement earned").font(.caption).foregroundStyle(Theme.yes)
                }
            }
            if let level = o.farmerLevel {
                Tile(title: "Farmer Level", anchor: "Skills") {
                    Ring(fraction: min(Double(level) / 25, 1), label: "\(level)", color: Theme.link)
                    Text(o.farmerTitle).font(.caption).foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }

    // MARK: Collection tiles

    private var collectionTiles: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Collections").font(.headline).fontDesign(.rounded).foregroundStyle(Theme.text)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190, maximum: 260), spacing: 10)], spacing: 10) {
                ForEach(Array(o.collections.enumerated()), id: \.offset) { _, c in
                    let (title, anchor, done, total) = c
                    let frac = total > 0 ? min(Double(done) / Double(total), 1) : 0
                    Button {
                        model.selectedSection = anchor
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Image(systemName: SectionGroup.symbol(for: anchor)).foregroundStyle(Theme.accent)
                                Text(title).font(.subheadline.weight(.semibold))
                                Spacer()
                                if frac >= 1 {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.yes)
                                }
                            }
                            ProgressBar(fraction: frac, state: frac >= 1 ? .yes : .no, label: nil)
                            Text("\(done) / \(total)").font(.caption).monospacedDigit().foregroundStyle(Theme.secondaryText)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.panelAlt, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.text)
                }
            }
        }
    }

    // MARK: Closest goals

    private struct Goal: Identifiable {
        let id = UUID()
        let section: Section
        let line: StatusLine
        let fraction: Double
    }

    private var goals: [Goal] {
        var out: [Goal] = []
        for section in report.sections {
            for cell in section.globalCells + (section.columns.first ?? []) + section.trailingCells {
                for block in cell.summary {
                    guard case .achList(let lines) = block else { continue }
                    for line in lines where line.state == .no && (line.kind == .achievement || line.kind == .milestone) {
                        guard let p = line.progress, p.goal > 0 else { continue }
                        out.append(Goal(section: section, line: line, fraction: min(p.current / p.goal, 1)))
                    }
                }
            }
        }
        return Array(out.sorted { $0.fraction > $1.fraction }.prefix(8))
    }

    private var closestGoals: some View {
        let list = goals
        return VStack(alignment: .leading, spacing: 6) {
            if !list.isEmpty {
                Text("Closest to done").font(.headline).fontDesign(.rounded).foregroundStyle(Theme.text)
                VStack(spacing: 3) {
                    ForEach(list) { g in
                        Button {
                            model.selectedSection = g.section.id
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: SectionGroup.symbol(for: g.section.id))
                                    .foregroundStyle(Theme.accent).frame(width: 18)
                                VStack(alignment: .leading, spacing: 3) {
                                    RichTextView(text: g.line.text)
                                    ProgressBar(fraction: g.fraction, state: .no, label: g.line.progressLabel)
                                }
                                Spacer()
                                Text(g.section.title).font(.caption).foregroundStyle(Theme.secondaryText)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondaryText)
                            }
                            .padding(.vertical, 5).padding(.horizontal, 8)
                            .background(Theme.panelAlt.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct Tile<Content: View>: View {
    let title: String
    let anchor: String?
    @ViewBuilder let content: Content
    @EnvironmentObject var model: AppModel

    var body: some View {
        Button {
            if let anchor { model.selectedSection = anchor }
        } label: {
            VStack(spacing: 6) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(Theme.panelAlt, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.text)
        .disabled(anchor == nil)
    }
}

struct Ring: View {
    let fraction: Double
    let label: String
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(Theme.barTrack, lineWidth: 9)
            Circle().trim(from: 0, to: max(0, min(fraction, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label).font(.title3.weight(.bold)).monospacedDigit()
        }
        .frame(width: 78, height: 78)
        .padding(.vertical, 2)
    }
}
