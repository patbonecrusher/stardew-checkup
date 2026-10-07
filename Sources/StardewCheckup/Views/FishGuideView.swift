import SwiftUI

/// Reference table of every fish: where, when, weather, difficulty and whether it's been caught.
struct FishGuideView: View {
    let caught: Set<String>
    let currentSeason: String
    let fishingLevel: Int
    let expanded: Bool

    @State private var isOpen: Bool
    @State private var filter = ""
    @State private var onlyUncaught = false
    @State private var season = "Any"         // "Any", "Spring", ...
    @State private var weather = "Any"        // "Any", "Sun", "Rain"
    @State private var hideCrabPot = false

    private static let seasons = ["Spring", "Summer", "Fall", "Winter"]
    private static let levelXP = [100, 380, 770, 1300, 2150, 3300, 4800, 6900, 10000, 15000]

    static func level(forXP xp: Int) -> Int { levelXP.firstIndex { $0 > xp } ?? 10 }

    init(caught: Set<String>, currentSeason: String, fishingLevel: Int, expanded: Bool) {
        self.caught = caught
        self.currentSeason = currentSeason
        self.fishingLevel = fishingLevel
        self.expanded = expanded
        _isOpen = State(initialValue: expanded)
        if CommandLine.arguments.contains("--fish-now") {
            _season = State(initialValue: currentSeason)
            _onlyUncaught = State(initialValue: true)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right").font(.caption.weight(.bold))
                    Image(systemName: "fish.fill").foregroundStyle(Theme.accent)
                    Text("Fish Guide: where, when and how hard").font(.headline).fontDesign(.rounded)
                    Text("from the wiki").font(.caption).foregroundStyle(Theme.secondaryText)
                }
                .foregroundStyle(Theme.text)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)

            if isOpen {
                VStack(alignment: .leading, spacing: 10) {
                    controls
                    legend
                    table
                }
                .padding(12)
                .background(Theme.panelAlt.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                .padding(.leading, 4)
            }
        }
        .padding(.top, 6)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondaryText)
                    TextField("Filter by name or location", text: $filter).textFieldStyle(.plain)
                    if !filter.isEmpty {
                        Button { filter = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(Theme.secondaryText)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.4), lineWidth: 1))
                .frame(maxWidth: 300)
                Toggle("Only uncaught", isOn: $onlyUncaught).toggleStyle(.checkbox)
                Toggle("Hide crab pot", isOn: $hideCrabPot).toggleStyle(.checkbox)
                Spacer()
            }
            HStack(spacing: 12) {
                Picker("Season", selection: $season) {
                    Text("Any season").tag("Any")
                    ForEach(Self.seasons, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented).fixedSize()
                if !currentSeason.isEmpty && Self.seasons.contains(currentSeason) {
                    Button("Now: \(currentSeason)") { season = currentSeason }
                        .controlSize(.small)
                        .help("Show fish available in the save's current season")
                }
                Picker("Weather", selection: $weather) {
                    Text("Any weather").tag("Any"); Text("Sun").tag("Sun"); Text("Rain").tag("Rain")
                }
                .pickerStyle(.segmented).fixedSize()
                Spacer()
            }
            .font(.callout)
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            Label("caught", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.yes)
            Label("not caught", systemImage: "circle").foregroundStyle(Theme.no)
            Label("needs a higher fishing level (you are \(fishingLevel))", systemImage: "lock.fill").foregroundStyle(Theme.impossible)
            Spacer()
        }
        .font(.caption).foregroundStyle(Theme.secondaryText)
    }

    // MARK: Table

    private var rows: [FishInfo] {
        var list = FishData.all
        if hideCrabPot { list = list.filter { !$0.crabPot } }
        if onlyUncaught { list = list.filter { !caught.contains($0.name) } }
        if season != "Any" { list = list.filter { $0.seasons.contains(season) } }
        if weather != "Any" { list = list.filter { $0.weather == .any || $0.weather.rawValue == weather } }
        let q = filter.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.location.localizedCaseInsensitiveContains(q) || $0.note.localizedCaseInsensitiveContains(q) }
        }
        return list.sorted { a, b in
            if a.crabPot != b.crabPot { return !a.crabPot }
            if a.legendary != b.legendary { return !a.legendary }
            return a.name < b.name
        }
    }

    private var table: some View {
        let list = rows
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(list.count) fish" + (onlyUncaught ? " left to catch" : "")).font(.caption).foregroundStyle(Theme.secondaryText)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                GridRow {
                    Text("")
                    Text("Fish")
                    Text("Location")
                    Text("Time")
                    Text("Season")
                    Text("Weather")
                    Text("Difficulty").gridColumnAlignment(.trailing)
                    Text("Base XP").gridColumnAlignment(.trailing)
                }
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                Divider().gridCellColumns(8)
                ForEach(list) { f in
                    FishRow(fish: f, caught: caught.contains(f.name), locked: f.minLevel > fishingLevel)
                }
            }
        }
    }
}

private struct FishRow: View {
    let fish: FishInfo
    let caught: Bool
    let locked: Bool

    var body: some View {
        GridRow {
            Image(systemName: caught ? "checkmark.circle.fill" : (locked ? "lock.fill" : "circle"))
                .foregroundStyle(caught ? Theme.yes : (locked ? Theme.impossible : Theme.no))
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    if let url = wikify(fish.name).runs.first?.url {
                        Link(fish.name, destination: url).foregroundStyle(Theme.link)
                    } else {
                        Text(fish.name)
                    }
                    if fish.legendary {
                        Image(systemName: "crown.fill").font(.caption2).foregroundStyle(Theme.accent).help("Legendary fish")
                    }
                }
                if fish.minLevel > 0 {
                    Text("fishing level \(fish.minLevel)").font(.caption2).foregroundStyle(Theme.secondaryText)
                }
            }
            .font(.callout.weight(.medium))
            VStack(alignment: .leading, spacing: 0) {
                Text(fish.location).font(.callout).foregroundStyle(Theme.text)
                if !fish.note.isEmpty {
                    Text(fish.note).font(.caption2).foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(maxWidth: 330, alignment: .leading)
            Text(fish.time).font(.callout).foregroundStyle(Theme.text).frame(minWidth: 90, alignment: .leading)
            seasonPills
            weatherLabel
            Text(fish.crabPot ? "–" : "\(fish.difficulty)").monospacedDigit().font(.callout).foregroundStyle(Theme.text)
                .help(fish.crabPot ? "Caught with a crab pot, no minigame" : "Behavior: \(fish.behavior)")
            Text(fish.crabPot ? "5" : "\(XPData.fishXP(difficulty: fish.difficulty, quality: 0, perfect: false, legendary: fish.legendary))")
                .monospacedDigit().font(.callout).foregroundStyle(Theme.text)
                .help(fish.crabPot ? "5 XP per crab pot collection" : "Normal quality, not perfect")
        }
        .padding(.vertical, 1)
    }

    private var seasonPills: some View {
        HStack(spacing: 2) {
            if fish.allSeasons {
                pill("All", color: Theme.secondaryText)
            } else {
                ForEach(["Spring", "Summer", "Fall", "Winter"], id: \.self) { s in
                    if fish.seasons.contains(s) { pill(String(s.prefix(2)), color: seasonColor(s)).help(s) }
                }
            }
        }
    }

    private func seasonColor(_ s: String) -> Color {
        switch s {
        case "Spring": return Color(red: 0.35, green: 0.65, blue: 0.3)
        case "Summer": return Color(red: 0.85, green: 0.6, blue: 0.15)
        case "Fall": return Color(red: 0.75, green: 0.35, blue: 0.15)
        default: return Color(red: 0.35, green: 0.55, blue: 0.85)
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(color.opacity(0.2), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1))
            .foregroundStyle(color)
    }

    @ViewBuilder
    private var weatherLabel: some View {
        switch fish.weather {
        case .any: Label("Any", systemImage: "cloud.sun").font(.caption).foregroundStyle(Theme.secondaryText)
        case .sun: Label("Sun", systemImage: "sun.max.fill").font(.caption).foregroundStyle(Theme.accent)
        case .rain: Label("Rain", systemImage: "cloud.rain.fill").font(.caption).foregroundStyle(Theme.link)
        }
    }
}
