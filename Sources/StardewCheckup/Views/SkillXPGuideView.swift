import SwiftUI

/// Reference guide: what grants experience in each skill, with "how many to next level"
/// computed from the host player's current XP. Data: stardewvalleywiki.com (Oct 2026).
struct SkillXPGuideView: View {
    let skillXP: [Int]
    let expanded: Bool
    @State private var isOpen: Bool
    @State private var skill = 0
    @State private var filter = ""
    @State private var quality = 0       // fishing: 0 normal, 1 silver, 2 gold, 4 iridium
    @State private var perfect = false

    private static let levelXP = [100, 380, 770, 1300, 2150, 3300, 4800, 6900, 10000, 15000]

    init(skillXP: [Int], expanded: Bool) {
        self.skillXP = skillXP
        self.expanded = expanded
        _isOpen = State(initialValue: expanded)
        // Test hook: `--xp-skill <0-4>` preselects a tab.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--xp-skill"), i + 1 < args.count, let n = Int(args[i + 1]), (0..<5).contains(n) {
            _skill = State(initialValue: n)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right").font(.caption.weight(.bold))
                    Image(systemName: "book.closed.fill").foregroundStyle(Theme.accent)
                    Text("XP Guide: what gives experience").font(.headline).fontDesign(.rounded)
                    Text("from the wiki").font(.caption).foregroundStyle(Theme.secondaryText)
                }
                .foregroundStyle(Theme.text)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)

            if isOpen {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $skill) {
                        ForEach(0..<5, id: \.self) { Text(Checkup.skillNames[$0]).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 480)
                    .onChange(of: skill) { _, _ in filter = "" }

                    progressLine
                    notes
                    if skill == 1 { fishingControls }
                    table
                }
                .padding(12)
                .background(Theme.panelAlt.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                .padding(.leading, 4)
            }
        }
        .padding(.top, 6)
    }

    // MARK: Current standing

    private var xp: Int { skill < skillXP.count ? skillXP[skill] : 0 }
    private var level: Int { Self.levelXP.firstIndex { $0 > xp } ?? 10 }
    private var toNext: Int? { level < 10 ? Self.levelXP[level] - xp : nil }
    private var toMax: Int { max(0, 15000 - xp) }

    private var progressLine: some View {
        HStack(spacing: 14) {
            Label("Level \(level)", systemImage: "star.fill").foregroundStyle(Theme.accent)
            Text("\(addCommas(xp)) xp").monospacedDigit()
            if let n = toNext {
                Text("\(addCommas(n)) to level \(level + 1)").monospacedDigit().foregroundStyle(Theme.no)
            }
            if toMax > 0 {
                Text("\(addCommas(toMax)) to max").monospacedDigit().foregroundStyle(Theme.secondaryText)
            } else {
                Label("Maxed", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.yes)
            }
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(Theme.text)
    }

    @ViewBuilder
    private var notes: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(XPData.notes[skill].enumerated()), id: \.offset) { _, n in
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: "info.circle").font(.caption).foregroundStyle(Theme.accent)
                    Text(n).font(.callout).foregroundStyle(Theme.text)
                }
            }
        }
    }

    private var fishingControls: some View {
        HStack(spacing: 14) {
            Picker("Quality", selection: $quality) {
                Text("Normal").tag(0); Text("Silver").tag(1); Text("Gold").tag(2); Text("Iridium").tag(4)
            }
            .pickerStyle(.segmented).fixedSize()
            Toggle("Perfect catch (×2.4)", isOn: $perfect).toggleStyle(.checkbox)
            Spacer()
        }
        .font(.callout)
    }

    // MARK: Table

    private struct Row: Identifiable {
        let id = UUID()
        let name: String
        let url: URL?
        let detail: String
        let xp: Int
    }

    private var rows: [Row] {
        var out: [Row]
        switch skill {
        case 0:
            out = XPData.crops.map { c in
                Row(name: c.name, url: wikiURL(c.name), detail: "\(c.price)g crop", xp: XPData.cropXP(price: c.price))
            } + XPData.farmingOther.map { Row(name: $0.name, url: nil, detail: $0.detail, xp: $0.xp) }
        case 1:
            out = XPData.fish.map { f in
                let base = XPData.fishXP(difficulty: f.difficulty, quality: quality, perfect: perfect, legendary: f.legendary)
                return Row(name: f.name, url: wikiURL(f.name), detail: "difficulty \(f.difficulty)" + (f.legendary ? " · legendary ×5" : ""), xp: base)
            } + XPData.fishingOther.map { Row(name: $0.name, url: nil, detail: $0.detail, xp: $0.xp) }
        case 2:
            out = XPData.foraging.map { Row(name: $0.name, url: nil, detail: $0.detail, xp: $0.xp) }
        case 3:
            out = XPData.mining.map { Row(name: $0.name, url: nil, detail: $0.detail, xp: $0.xp) }
        default:
            out = XPData.monsters.map { Row(name: $0.name, url: wikiURL($0.name), detail: $0.detail, xp: $0.xp) }
        }
        out.sort { $0.xp == $1.xp ? $0.name < $1.name : $0.xp > $1.xp }
        let q = filter.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty { out = out.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.detail.localizedCaseInsensitiveContains(q) } }
        return out
    }

    private func wikiURL(_ name: String) -> URL? {
        wikify(name).runs.first?.url
    }

    private func count(_ need: Int?, per: Int) -> String {
        guard let need, per > 0 else { return "–" }
        return "×\(addCommas(Int((Double(need) / Double(per)).rounded(.up))))"
    }

    private var table: some View {
        let list = rows
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondaryText)
                TextField("Filter \(list.count) sources", text: $filter).textFieldStyle(.plain)
                if !filter.isEmpty {
                    Button { filter = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.4), lineWidth: 1))
            .frame(maxWidth: 320)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                GridRow {
                    Text("Source").gridColumnAlignment(.leading)
                    Text("")
                    Text("XP").gridColumnAlignment(.trailing)
                    Text(toNext != nil ? "To level \(level + 1)" : "").gridColumnAlignment(.trailing)
                    Text("To max").gridColumnAlignment(.trailing)
                }
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                Divider().gridCellColumns(5)
                ForEach(list) { r in
                    GridRow {
                        Group {
                            if let url = r.url { Link(r.name, destination: url).foregroundStyle(Theme.link) }
                            else { Text(r.name).foregroundStyle(Theme.text) }
                        }
                        Text(r.detail).font(.caption).foregroundStyle(Theme.secondaryText)
                        Text("\(r.xp)").monospacedDigit().foregroundStyle(Theme.text).fontWeight(.semibold)
                        Text(count(toNext, per: r.xp)).monospacedDigit().foregroundStyle(Theme.no)
                        Text(toMax > 0 ? count(toMax, per: r.xp) : "–").monospacedDigit().foregroundStyle(Theme.secondaryText)
                    }
                    .font(.callout)
                }
            }
        }
    }
}
