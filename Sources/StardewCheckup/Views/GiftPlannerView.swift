import SwiftUI

/// Weekly gift planner: one row per villager with gift slots left and what you already own for them.
struct GiftPlannerView: View {
    let data: GiftPlanData
    @State private var hideDone = true
    @State private var hideMaxed = true
    @State private var onlyWithIdeas = false
    @State private var filter = ""

    private var rows: [GiftPlanRow] {
        data.rows.filter { r in
            r.isMet &&
            (!hideDone || r.slotsLeft > 0) &&
            (!hideMaxed || !r.isMaxed || r.birthdayIn == 0) &&
            (!onlyWithIdeas || !r.suggestions.isEmpty) &&
            (filter.isEmpty || r.name.localizedCaseInsensitiveContains(filter))
        }
        .sorted { a, b in
            // Birthdays first, then villagers with loved ideas, then by fewest hearts.
            let ab = a.birthdayIn ?? 99, bb = b.birthdayIn ?? 99
            if ab != bb { return ab < bb }
            let al = a.suggestions.loves.isEmpty ? 1 : 0, bl = b.suggestions.loves.isEmpty ? 1 : 0
            if al != bl { return al < bl }
            if a.hearts != b.hearts { return a.hearts < b.hearts }
            return a.name < b.name
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                TextField("Search villagers", text: $filter).textFieldStyle(.roundedBorder).frame(width: 180)
                Toggle("Hide villagers already given 2 gifts", isOn: $hideDone)
                Toggle("Hide maxed hearts", isOn: $hideMaxed)
                Toggle("Only with gift ideas", isOn: $onlyWithIdeas)
                Spacer()
                Text("\(rows.count) shown").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            .toggleStyle(.checkbox).font(.callout)
            HStack(spacing: 6) {
                Image(systemName: "info.circle").foregroundStyle(Theme.secondaryText)
                Text("Ideas come from your inventory (backpack icon), chests and fridges (box), and forage lying on the ground today (leaf). A star is the best quality you own: grey silver, orange gold, purple iridium. Loved gifts give 80 friendship, liked 45; the birthday multiplier is 8×. Stardrop Tea is loved by everyone and does not count towards the two-per-week limit.")
                    .font(.caption).foregroundStyle(Theme.secondaryText)
            }
            if rows.isEmpty {
                Text(data.rows.contains(where: \.isMet) ? "Nothing left to do this week with the current filters." : "No villagers met yet.")
                    .foregroundStyle(Theme.secondaryText).padding(.vertical, 8)
            }
            ForEach(rows) { row in
                GiftPlanRowView(row: row)
            }
        }
        .padding(.leading, 22)
        .padding(.bottom, 4)
    }
}

private struct GiftPlanRowView: View {
    let row: GiftPlanRow
    @State private var showAllLikes = false

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
                    if let b = row.birthdayIn {
                        Label(b == 0 ? "birthday today" : "birthday in \(b)d", systemImage: "birthday.cake.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(row.birthdayGifted ? Theme.yes : Theme.heart)
                            .help(row.birthdayGifted ? "Birthday gift already given" : "A loved gift today is worth 8×")
                    }
                }
                .font(.body.weight(.semibold))
                HeartMeter(filled: row.hearts, total: row.maxHearts, lockedFrom: row.lockedFrom)
                HStack(spacing: 8) {
                    slots
                    if row.isMaxed {
                        Text(row.isSpouse ? "max (decays)" : "maxed").font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                    if row.talkedToday {
                        Image(systemName: "bubble.left.fill").font(.caption2).foregroundStyle(Theme.yes).help("Talked to today")
                    }
                }
            }
            .frame(width: 190, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                if !row.suggestions.loves.isEmpty {
                    tierRow("Loves", "heart.fill", Theme.heart, row.suggestions.loves, showAll: true)
                } else {
                    wishList
                }
                if !row.suggestions.likes.isEmpty {
                    tierRow("Likes", "hand.thumbsup.fill", Theme.yes, row.suggestions.likes, showAll: showAllLikes || row.suggestions.loves.isEmpty)
                } else if row.suggestions.loves.isEmpty {
                    Text("Nothing you own is liked either.").font(.caption).foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(Theme.panelAlt.opacity(row.birthdayIn == 0 ? 0.9 : 0.55), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(row.birthdayIn == 0 ? Theme.heart.opacity(0.6) : Color.clear, lineWidth: 1))
        .opacity(row.slotsLeft == 0 ? 0.6 : 1)
    }

    /// Shown when you own no loved item: what they would love, to cook, buy or find.
    private var wishList: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Label("Loves", systemImage: "heart").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText).frame(width: 58, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text("none owned; they would love:").font(.caption).foregroundStyle(Theme.secondaryText)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 4) {
                    ForEach(row.lovedItems, id: \.self) { item in
                        HStack(spacing: 4) {
                            Image(systemName: "heart").font(.system(size: 9)).foregroundStyle(Theme.secondaryText)
                            if let url = wikify(item).runs.first?.url {
                                Link(item, destination: url).foregroundStyle(Theme.secondaryText)
                            } else {
                                Text(item).foregroundStyle(Theme.secondaryText)
                            }
                        }
                        .font(.callout).lineLimit(1)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(Capsule().stroke(Theme.border.opacity(0.35), lineWidth: 1))
                    }
                }
                Text("plus the universal loves: Pearl, Rabbit's Foot, Prismatic Shard, Golden Pumpkin, Magic Rock Candy, Stardrop Tea")
                    .font(.caption2).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var slots: some View {
        HStack(spacing: 3) {
            if row.isSpouse {
                Image(systemName: row.giftedToday ? "gift.fill" : "gift").font(.system(size: 11))
                    .foregroundStyle(row.giftedToday ? Theme.secondaryText : Theme.accent)
                Text(row.giftedToday ? "gift given today" : "one gift a day (spouse)")
                    .font(.caption).foregroundStyle(row.giftedToday ? Theme.secondaryText : Theme.text)
            } else {
                ForEach(0..<2, id: \.self) { i in
                    Image(systemName: i < row.giftsThisWeek ? "gift.fill" : "gift")
                        .font(.system(size: 11))
                        .foregroundStyle(i < row.giftsThisWeek ? Theme.secondaryText : Theme.accent)
                }
                Text(row.slotsLeft == 0 ? "done this week" : "\(row.slotsLeft) left this week")
                    .font(.caption).foregroundStyle(row.slotsLeft == 0 ? Theme.secondaryText : Theme.text)
            }
        }
    }

    private func tierRow(_ title: String, _ symbol: String, _ color: Color, _ items: [GiftSuggestion], showAll: Bool) -> some View {
        let limit = 6
        let visible = showAll ? items : Array(items.prefix(limit))
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Label(title, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(color).frame(width: 58, alignment: .leading)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 4) {
                ForEach(visible) { s in
                    GiftChip(suggestion: s, color: color)
                }
                if !showAll && items.count > limit {
                    Button("+\(items.count - limit) more") { showAllLikes = true }
                        .buttonStyle(.link).font(.caption)
                }
            }
        }
    }
}

struct GiftChip: View {
    let suggestion: GiftSuggestion
    let color: Color

    private var qualityText: String {
        switch suggestion.bestQuality {
        case 4...: return "Best quality owned: iridium. "
        case 2...: return "Best quality owned: gold. "
        case 1: return "Best quality owned: silver. "
        default: return "Normal quality. "
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: suggestion.inInventory ? "backpack.fill" : (suggestion.onlyOnGround ? "leaf.fill" : "shippingbox"))
                .font(.system(size: 9)).foregroundStyle(suggestion.inInventory ? color : (suggestion.onlyOnGround ? Theme.yes : Theme.secondaryText))
            if let url = wikify(suggestion.name).runs.first?.url {
                Link(suggestion.name, destination: url).foregroundStyle(Theme.text)
            } else {
                Text(suggestion.name)
            }
            Text("×\(suggestion.count)").font(.caption).monospacedDigit().foregroundStyle(Theme.secondaryText)
            if suggestion.bestQuality >= 4 {
                Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(Color.purple)
            } else if suggestion.bestQuality >= 2 {
                Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(Theme.accent)
            } else if suggestion.bestQuality >= 1 {
                Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(Color.gray)
            }
        }
        .font(.callout).lineLimit(1)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(color.opacity(0.1), in: Capsule())
        .help(qualityText + (suggestion.inInventory ? "In your inventory. " : (suggestion.onlyOnGround ? "Forage on the ground today. " : "")) + "Found in: " + suggestion.places)
    }
}
