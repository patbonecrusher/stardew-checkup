import SwiftUI

// Planner tabs for Bundles, Fishing, Museum, Shipping, Crop Shipping and Monster Hunting.

// MARK: Shared pieces

/// Heading for one group of planner cards: icon, title, count pill and a one-line explanation.
struct PlanGroupHeader: View {
    let title: String
    let symbol: String
    let color: Color
    let count: Int
    let blurb: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: symbol).foregroundStyle(color)
                Text(title).font(.headline).fontDesign(.rounded)
                Text("\(count)").font(.caption.weight(.semibold)).monospacedDigit()
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(color.opacity(0.2), in: Capsule())
            }
            .foregroundStyle(Theme.text)
            if !blurb.isEmpty {
                Text(blurb).font(.caption).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Search field and toggles row shared by the planners.
struct PlanSearchField: View {
    let prompt: String
    @Binding var text: String
    var body: some View {
        TextField(prompt, text: $text).textFieldStyle(.roundedBorder).frame(width: 220)
    }
}

/// A link to the wiki page for `name`, or plain text when there is none.
struct WikiName: View {
    let name: String
    var color: Color = Theme.text
    var body: some View {
        if let url = wikify(name).runs.first?.url {
            Link(name, destination: url).foregroundStyle(color)
        } else {
            Text(name).foregroundStyle(color)
        }
    }
}

/// One wanted item: status icon, name, quality, count, what you have.
struct PlanItemLine: View {
    let item: PlanItem

    private var symbol: String {
        if item.done { return "checkmark.seal.fill" }
        if item.isMissing { return "xmark.circle.fill" }
        return item.isReady ? "checkmark.circle.fill" : "shippingbox.fill"
    }
    private var tint: Color {
        if item.done { return Theme.secondaryText }
        if item.isMissing { return Theme.no }
        return item.isReady ? Theme.yes : Theme.accent
    }
    private var helpText: String {
        if item.done { return "Already in the bundle." }
        var t = item.isMoney ? "You have \(addCommas(item.have))g." : (item.places.isEmpty ? "You don't have any." : "You have: " + item.places)
        if let q = item.qualityLabel, !item.isMoney { t += " Needs \(q) quality or better; \(item.have) of yours qualify." }
        if let h = item.hint { t += "\nWhere to get it: " + h }
        return t
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.caption).foregroundStyle(tint)
                if item.isMoney {
                    Text(item.name)
                } else {
                    WikiName(name: item.name)
                }
                if item.need > 1 && !item.isMoney { Text("×\(item.need)").foregroundStyle(Theme.secondaryText) }
                if let q = item.qualityLabel {
                    Image(systemName: "star.fill").font(.system(size: 8))
                        .foregroundStyle(item.quality >= 4 ? Color.purple : item.quality >= 2 ? Theme.accent : Color.gray)
                        .help("\(q) quality or better")
                }
                Spacer()
                if item.done {
                    Text("done").font(.caption).foregroundStyle(Theme.secondaryText)
                } else if !item.isMoney {
                    Text("have \(item.have)").font(.caption).monospacedDigit().foregroundStyle(item.isMissing ? Theme.no : Theme.secondaryText)
                }
            }
            if item.isMissing, let h = item.hint {
                Text(h).font(.caption2).foregroundStyle(Theme.secondaryText).padding(.leading, 18)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.callout)
        .opacity(item.done ? 0.55 : 1)
        .help(helpText)
    }
}

private struct PlanCard<Content: View>: View {
    let color: Color
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 5) { content }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panelAlt.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.35), lineWidth: 1))
    }
}

private let cardColumns = [GridItem(.adaptive(minimum: 340, maximum: 520), spacing: 8, alignment: .top)]
private let chipColumns = [GridItem(.adaptive(minimum: 260, maximum: 420), spacing: 8, alignment: .top)]

// MARK: Bundles

struct BundlePlannerView: View {
    let data: BundlePlanData
    @State private var filter = ""
    @State private var showDone = false

    private static let groups: [(BundlePlanRow.State, String, String, Color, String)] = [
        (.ready, "Complete now", "checkmark.circle.fill", Theme.yes, "Everything the bundle still needs is in your backpack: walk to the Community Center."),
        (.fetch, "Fetch from storage first", "shippingbox.fill", Theme.accent, "You own enough to finish these, but some of it is in a chest, fridge or on the ground."),
        (.partial, "Can add some now", "circle.lefthalf.filled", Theme.link, "You own part of what is left; the rest is listed with where to get it."),
        (.missing, "Nothing owned yet", "cart.fill", Theme.no, "None of the remaining items are in your possession."),
        (.done, "Completed", "checkmark.seal.fill", Theme.secondaryText, ""),
    ]

    private func rows(_ s: BundlePlanRow.State) -> [BundlePlanRow] {
        data.rows.filter { $0.state == s && (filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) || $0.room.localizedCaseInsensitiveContains(filter)
            || $0.items.contains { !$0.done && $0.name.localizedCaseInsensitiveContains(filter) }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let open = data.rows.filter { $0.state != .done }
            VStack(alignment: .leading, spacing: 4) {
                if data.isJoja {
                    Label("You are a Joja member: rooms are bought as projects at JojaMart, so bundles no longer apply to rooms you haven't finished.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.no)
                }
                Text("\(data.roomsDone) of \(data.roomsTotal) rooms complete; \(open.count) bundles left. \(rows(.ready).count) can be completed right now and \(rows(.fetch).count) after a trip to your chests.")
                Text("An item can count towards several bundles here; it can only go in one. Quality stars mean that quality or better.")
                    .font(.caption).italic().foregroundStyle(Theme.secondaryText)
            }
            .foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                PlanSearchField(prompt: "Search bundles or items", text: $filter)
                Toggle("Show completed bundles", isOn: $showDone).toggleStyle(.checkbox)
                Spacer()
            }.font(.callout)
            ForEach(Self.groups, id: \.0) { state, title, symbol, color, blurb in
                let list = rows(state)
                if !list.isEmpty && (state != .done || showDone) {
                    VStack(alignment: .leading, spacing: 6) {
                        PlanGroupHeader(title: title, symbol: symbol, color: color, count: list.count, blurb: blurb)
                        LazyVGrid(columns: cardColumns, alignment: .leading, spacing: 8) {
                            ForEach(list) { row in
                                PlanCard(color: color) {
                                    HStack(spacing: 6) {
                                        Text("\(row.name) Bundle").font(.body.weight(.semibold))
                                        Text(row.room).font(.caption).foregroundStyle(Theme.secondaryText)
                                        Spacer()
                                        if row.state != .done {
                                            Text("\(row.left) left").font(.caption.weight(.semibold)).foregroundStyle(color)
                                        }
                                    }
                                    if row.slots < row.items.count {
                                        Text("Any \(row.slots) of these \(row.items.count)").font(.caption).foregroundStyle(Theme.secondaryText)
                                    }
                                    ForEach(row.items) { PlanItemLine(item: $0) }
                                    if !row.reward.isEmpty {
                                        Label("Reward: \(row.reward)", systemImage: "gift").font(.caption).foregroundStyle(Theme.secondaryText)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(.leading, 22).padding(.bottom, 4)
    }
}

// MARK: Fishing

struct FishPlannerView: View {
    let data: FishPlanData
    @State private var filter = ""

    private func rows(_ g: FishPlanRow.Group) -> [FishPlanRow] {
        data.rows.filter { $0.group == g && (filter.isEmpty || $0.fish.name.localizedCaseInsensitiveContains(filter) || $0.fish.location.localizedCaseInsensitiveContains(filter)) }
            .sorted { $0.fish.difficulty < $1.fish.difficulty }
    }

    private var groups: [(FishPlanRow.Group, String, String, Color, String)] {
        [
            (.today, "Catch today", "fish.fill", Theme.yes, "In season, right weather (\(data.isRaining ? "raining" : "dry") today) and you can reach the water. Easiest first."),
            (.otherWeather, data.isRaining ? "In season, needs a dry day" : "In season, needs rain", data.isRaining ? "sun.max.fill" : "cloud.rain.fill", Theme.accent,
             data.isRaining ? "Come back on a sunny day this season." : "Wait for a rainy day this season, or use a Rain Totem the day before."),
            (.laterSeason, "Later in the year", "calendar", Theme.link, "Not in season now; the next season it bites is shown."),
            (.blocked, "Locked for now", "lock.fill", Theme.no, "You can't reach the water yet or your fishing level is too low."),
            (.crabPot, "Crab pot", "basket.fill", Theme.secondaryText, "Any season, any weather: put a crab pot with bait in the right water."),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(data.season) \(data.day), \(data.isRaining ? "raining" : "not raining"). Fishing level \(data.fishingLevel). \(data.caught) of \(data.total) fish caught, \(data.total - data.caught) to go.")
                Text("Today's weather is what the save shows at the start of the day. Rain fish also bite during storms; the Desert and the Mines ignore the weather.")
                    .font(.caption).italic().foregroundStyle(Theme.secondaryText)
            }
            .foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
            PlanSearchField(prompt: "Search fish or locations", text: $filter).font(.callout)
            ForEach(groups, id: \.0) { g, title, symbol, color, blurb in
                let list = rows(g)
                if !list.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        PlanGroupHeader(title: title, symbol: symbol, color: color, count: list.count, blurb: blurb)
                        LazyVGrid(columns: cardColumns, alignment: .leading, spacing: 8) {
                            ForEach(list) { row in
                                PlanCard(color: color) { FishPlanCard(row: row) }
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(.leading, 22).padding(.bottom, 4)
    }
}

private struct FishPlanCard: View {
    let row: FishPlanRow
    var body: some View {
        let f = row.fish
        HStack(spacing: 6) {
            WikiName(name: f.name).font(.body.weight(.semibold))
            if f.legendary { Image(systemName: "crown.fill").font(.caption).foregroundStyle(Theme.accent).help("Legendary: one catch per save") }
            Spacer()
            if !f.crabPot {
                Text("difficulty \(f.difficulty)").font(.caption).monospacedDigit().foregroundStyle(Theme.secondaryText)
            }
        }
        Label(f.location, systemImage: "mappin.and.ellipse").font(.callout).foregroundStyle(Theme.text)
        if !f.crabPot {
            HStack(spacing: 10) {
                Label(f.time, systemImage: "clock")
                if f.weather != .any { Label(f.weather == .rain ? "rain" : "sun", systemImage: f.weather == .rain ? "cloud.rain" : "sun.max") }
                Label(f.allSeasons ? "all seasons" : f.seasons.joined(separator: ", "), systemImage: "leaf")
            }
            .font(.caption).foregroundStyle(Theme.secondaryText)
        }
        if !row.nextSeason.isEmpty && row.group == .laterSeason {
            Text("Next: \(row.nextSeason)").font(.caption.weight(.semibold)).foregroundStyle(Theme.link)
        }
        if !f.note.isEmpty { Text(f.note).font(.caption2).foregroundStyle(Theme.secondaryText) }
        ForEach(row.blockers, id: \.self) { b in
            Label("Needs " + b, systemImage: "lock").font(.caption).foregroundStyle(Theme.no)
        }
    }
}

// MARK: Museum

struct MuseumPlannerView: View {
    let data: MuseumPlanData
    @State private var filter = ""

    private static let groups: [(MuseumPlanRow.State, String, String, Color, String)] = [
        (.donateNow, "Donate now", "building.columns.fill", Theme.yes, "You own these and the museum doesn't have them yet. Take them to Gunther."),
        (.lost, "Found before, none left", "arrow.uturn.backward.circle.fill", Theme.accent, "You found one before but don't have it any more (sold or used); find another."),
        (.notFound, "Never found", "magnifyingglass", Theme.link, "Where to look."),
    ]

    private func rows(_ s: MuseumPlanRow.State) -> [MuseumPlanRow] {
        data.rows.filter { $0.state == s && (filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) || $0.hint.localizedCaseInsensitiveContains(filter)) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let next = [40, 60, data.total].first { $0 > data.donated }
            VStack(alignment: .leading, spacing: 4) {
                let now = data.rows.filter { $0.state == .donateNow }.count
                let goal = next.map { " " + ($0 == 40 ? "Treasure Trove" : $0 == 60 ? "the Rusty Key" : "A Complete Collection") + " needs \($0)." } ?? ""
                Text("\(data.donated) of \(data.total) donated. " + (now == 0 ? "Nothing new to donate right now." : "\(now) can be donated right now.") + goal)
                Text("Geodes count: crack them at Clint's to turn up minerals you haven't found yet.")
                    .font(.caption).italic().foregroundStyle(Theme.secondaryText)
            }
            .foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
            PlanSearchField(prompt: "Search items or places", text: $filter).font(.callout)
            ForEach(Self.groups, id: \.0) { state, title, symbol, color, blurb in
                let list = rows(state)
                if !list.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        PlanGroupHeader(title: title, symbol: symbol, color: color, count: list.count, blurb: blurb)
                        LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
                            ForEach(list) { row in
                                PlanCard(color: color) {
                                    HStack(spacing: 6) {
                                        WikiName(name: row.name).font(.callout.weight(.semibold))
                                        Spacer()
                                        Text(row.isArtifact ? "artifact" : "mineral").font(.caption).foregroundStyle(Theme.secondaryText)
                                    }
                                    if state == .donateNow {
                                        Label(row.places, systemImage: "shippingbox").font(.caption).foregroundStyle(Theme.secondaryText)
                                    } else if !row.hint.isEmpty {
                                        Text(row.hint).font(.caption).foregroundStyle(Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(.leading, 22).padding(.bottom, 4)
    }
}

// MARK: Shipping

struct ShipPlannerView: View {
    let data: ShipPlanData
    @State private var filter = ""

    private func rows(_ s: ShipPlanRow.State) -> [ShipPlanRow] {
        data.rows.filter { $0.state == s && (filter.isEmpty || $0.item.name.localizedCaseInsensitiveContains(filter)) }
            .sorted { $0.item.name < $1.item.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(data.shipped) of \(data.total) items shipped. \(rows(.shipNow).count) of the \(data.total - data.shipped) left are already yours: put one of each in the shipping bin.")
                Text("One of anything counts. The bin takes items from your backpack; hover an item to see where yours are.")
                    .font(.caption).italic().foregroundStyle(Theme.secondaryText)
            }
            .foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
            PlanSearchField(prompt: "Search items", text: $filter).font(.callout)
            ForEach([(ShipPlanRow.State.shipNow, "Ship now", "shippingbox.fill", Theme.yes, "Owned and never shipped."),
                     (.notOwned, "Still to get", "cart.fill", Theme.no, "Never shipped and none in your possession.")], id: \.0) { state, title, symbol, color, blurb in
                let list = rows(state)
                if !list.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        PlanGroupHeader(title: title, symbol: symbol, color: color, count: list.count, blurb: blurb)
                        LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 6) {
                            ForEach(list) { row in PlanCard(color: color) { PlanItemLine(item: row.item) } }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(.leading, 22).padding(.bottom, 4)
    }
}

struct CropPlannerView: View {
    let data: CropPlanData
    @State private var showDone = false

    private func rows(_ s: CropPlanRow.State) -> [CropPlanRow] {
        data.rows.filter { $0.state == s }.sorted { a, b in a.left != b.left ? a.left < b.left : a.name < b.name }
    }

    private var groups: [(CropPlanRow.State, String, String, Color, String)] {
        [
            (.shipNow, "Ship what you have", "shippingbox.fill", Theme.yes, "You own some of these crops; shipping them gets you closer to 15."),
            (.plantNow, "Plant today", "leaf.fill", Theme.accent, "In season and there is still time for a harvest before the season ends (no fertilizer)."),
            (.laterSeason, "Later in the year", "calendar", Theme.link, "Too late this season or wrong season; the Greenhouse and Ginger Island farm grow anything any time."),
            (.done, "Done (15 shipped)", "checkmark.seal.fill", Theme.secondaryText, ""),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let done = data.rows.filter { $0.state == .done }.count
            Text("\(done) of \(data.rows.count) crops shipped 15 times (Polyculture). It is \(data.season) \(data.day).")
                .foregroundStyle(Theme.text)
            Toggle("Show finished crops", isOn: $showDone).toggleStyle(.checkbox).font(.callout)
            ForEach(groups, id: \.0) { state, title, symbol, color, blurb in
                let list = rows(state)
                if !list.isEmpty && (state != .done || showDone) {
                    VStack(alignment: .leading, spacing: 6) {
                        PlanGroupHeader(title: title, symbol: symbol, color: color, count: list.count, blurb: blurb)
                        LazyVGrid(columns: cardColumns, alignment: .leading, spacing: 8) {
                            ForEach(list) { row in PlanCard(color: color) { CropCard(row: row) } }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(.leading, 22).padding(.bottom, 4)
    }
}

private struct CropCard: View {
    let row: CropPlanRow
    var body: some View {
        HStack(spacing: 6) {
            WikiName(name: row.name).font(.body.weight(.semibold))
            Spacer()
            Text(row.left == 0 ? "\(row.shipped) shipped" : "\(row.shipped)/15 shipped, \(row.left) to go").font(.caption).monospacedDigit()
                .foregroundStyle(row.left == 0 ? Theme.secondaryText : Theme.text)
        }
        if row.owned > 0 {
            Label("You have \(row.owned)" + (row.owned >= row.left && row.left > 0 ? ": enough to finish" : ""), systemImage: "shippingbox")
                .font(.callout).foregroundStyle(row.owned >= row.left ? Theme.yes : Theme.text)
                .help(row.ownedPlaces)
        }
        if !row.seasons.isEmpty {
            HStack(spacing: 10) {
                Label(row.seasons.joined(separator: ", "), systemImage: "leaf")
                Label("\(row.days) days" + (row.regrow > 0 ? ", regrows every \(row.regrow)" : ""), systemImage: "clock")
            }
            .font(.caption).foregroundStyle(Theme.secondaryText)
            if let h = row.harvestDay, row.left > 0 {
                Text(h <= 28 ? "Planted today: first harvest on day \(h)." : "Planted today: first harvest in \(h - 28) days into next season.")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
            }
            Text("\(row.seed)" + (row.seedsOwned > 0 ? " (you have \(row.seedsOwned))" : "") + ": \(row.seedSource)")
                .font(.caption).foregroundStyle(row.seedsOwned > 0 ? Theme.yes : Theme.secondaryText).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: Monster Hunting

struct MonsterPlannerView: View {
    let data: MonsterPlanData
    @State private var showDone = false

    private var rows: [MonsterPlanRow] {
        data.rows.filter { showDone || !$0.isDone || !$0.claimed }
            .sorted { a, b in
                if (a.isDone && !a.claimed) != (b.isDone && !b.claimed) { return a.isDone && !a.claimed }
                if a.isDone != b.isDone { return !a.isDone }
                return Double(a.killed) / Double(a.target) > Double(b.killed) / Double(b.target)
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let done = data.rows.filter(\.isDone).count
            let unclaimed = data.rows.filter { $0.isDone && !$0.claimed }.count
            VStack(alignment: .leading, spacing: 4) {
                Text("\(done) of \(data.rows.count) Monster Eradication goals done" + (unclaimed > 0 ? "; \(unclaimed) reward(s) waiting at the Adventurer's Guild." : ".")
                     + " Deepest mine floor \(data.mineLevel)" + (data.skullLevel > 0 ? ", Skull Cavern floor \(data.skullLevel)." : "."))
                Text("Closest goals first. Talk to Gil (the old man in the Guild) to claim rewards.")
                    .font(.caption).italic().foregroundStyle(Theme.secondaryText)
            }
            .foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
            Toggle("Show completed and claimed goals", isOn: $showDone).toggleStyle(.checkbox).font(.callout)
            LazyVGrid(columns: cardColumns, alignment: .leading, spacing: 8) {
                ForEach(rows) { row in
                    let color = row.isDone ? (row.claimed ? Theme.secondaryText : Theme.yes) : Theme.accent
                    PlanCard(color: color) {
                        HStack(spacing: 6) {
                            Text(row.goal).font(.body.weight(.semibold))
                            Spacer()
                            if row.isDone {
                                Text(row.claimed ? "done, claimed" : "done: claim reward!").font(.caption.weight(.semibold)).foregroundStyle(color)
                            } else {
                                Text("\(addCommas(row.left)) to go").font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(color)
                            }
                        }
                        ProgressView(value: Double(min(row.killed, row.target)), total: Double(row.target)).tint(color)
                        Text("\(addCommas(row.killed)) / \(addCommas(row.target)) killed").font(.caption).monospacedDigit().foregroundStyle(Theme.secondaryText)
                        HStack(spacing: 4) {
                            Image(systemName: "pawprint").font(.caption)
                            ForEach(Array(row.monsters.enumerated()), id: \.offset) { i, m in
                                WikiName(name: m).font(.caption)
                                if i < row.monsters.count - 1 { Text("·").font(.caption) }
                            }
                        }
                        .foregroundStyle(Theme.secondaryText)
                        Label(row.whereToFind, systemImage: "mappin.and.ellipse").font(.callout).foregroundStyle(Theme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Label("Reward: \(row.reward)", systemImage: "gift").font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        }
        .padding(.leading, 22).padding(.bottom, 4)
    }
}
