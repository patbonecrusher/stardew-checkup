import SwiftUI

/// Cooking planner: what can be cooked now, what needs fetching or buying, and what is left to learn.
struct CookingPlannerView: View {
    let data: CookPlanData
    @State private var showCooked = false
    @State private var filter = ""

    private static let groups: [(CookPlanRow.State, String, String, String)] = [
        (.cookNow, "Cook now", "flame.fill", "Known, not cooked yet, and everything is in your inventory or fridge."),
        (.fetch, "Fetch from storage first", "shippingbox.fill", "You own everything, but some of it is in a chest or on the ground."),
        (.missing, "Missing ingredients", "cart.fill", "Known recipes you still need ingredients for."),
        (.learn, "Recipes to learn", "book.closed.fill", "Not known yet: where the recipe comes from."),
        (.cooked, "Already cooked", "checkmark.seal.fill", "Cooked at least once; shown so you can see what you could cook again."),
    ]

    private func rows(_ state: CookPlanRow.State) -> [CookPlanRow] {
        data.rows.filter { $0.state == state && (filter.isEmpty || matches($0)) }
            .sorted { a, b in a.missingCount != b.missingCount ? a.missingCount < b.missingCount : a.name < b.name }
    }

    private func matches(_ r: CookPlanRow) -> Bool {
        r.name.localizedCaseInsensitiveContains(filter) || r.ingredients.contains { $0.name.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            summary
            HStack(spacing: 14) {
                TextField("Search recipes or ingredients", text: $filter).textFieldStyle(.roundedBorder).frame(width: 240)
                Toggle("Show recipes already cooked", isOn: $showCooked).toggleStyle(.checkbox)
                Spacer()
            }
            .font(.callout)
            ForEach(Self.groups, id: \.0) { state, title, symbol, blurb in
                let list = rows(state)
                if !list.isEmpty && (state != .cooked || showCooked) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: symbol).foregroundStyle(color(state))
                            Text(title).font(.headline).fontDesign(.rounded)
                            Text("\(list.count)").font(.caption.weight(.semibold)).monospacedDigit()
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(color(state).opacity(0.2), in: Capsule())
                        }
                        .foregroundStyle(Theme.text)
                        Text(blurb).font(.caption).foregroundStyle(Theme.secondaryText)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340, maximum: 520), spacing: 8, alignment: .top)], alignment: .leading, spacing: 8) {
                            ForEach(list) { RecipeCard(row: $0, color: color(state)) }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(.leading, 22)
        .padding(.bottom, 4)
    }

    private var summary: some View {
        let count = { (s: CookPlanRow.State) in data.rows.filter { $0.state == s }.count }
        let cooked = count(.cooked), total = data.rows.count
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(cooked) of \(total) recipes cooked; \(total - cooked) left for Gourmet Chef and the Perfection cooking star.")
            Text("Of those: \(count(.cookNow)) can be cooked right now, \(count(.fetch)) need ingredients fetched from chests, \(count(.missing)) are missing ingredients, and \(count(.learn)) still have to be learned.")
            if !data.hasKitchen {
                Label("You need the first farmhouse upgrade (Robin, 10,000g and 450 Wood) to get a kitchen.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.no)
            }
            Text("The kitchen uses ingredients from your inventory, the fridge and mini-fridges; anything in a chest has to be fetched first. Egg, Milk and Any Fish accept any item of that kind. Ingredients shared between recipes are counted once per recipe.")
                .font(.caption).italic().foregroundStyle(Theme.secondaryText)
        }
        .foregroundStyle(Theme.text)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func color(_ s: CookPlanRow.State) -> Color {
        switch s {
        case .cookNow: return Theme.yes
        case .fetch: return Theme.accent
        case .missing: return Theme.no
        case .learn: return Theme.link
        case .cooked: return Theme.secondaryText
        }
    }
}

private struct RecipeCard: View {
    let row: CookPlanRow
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if let url = wikify(row.name).runs.first?.url {
                    Link(row.name, destination: url).foregroundStyle(Theme.text)
                } else {
                    Text(row.name)
                }
                if row.timesCooked > 0 {
                    Text("cooked ×\(row.timesCooked)").font(.caption).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                if row.state == .missing {
                    Text("\(row.missingCount) missing").font(.caption.weight(.semibold)).foregroundStyle(Theme.no)
                }
            }
            .font(.body.weight(.semibold))
            ForEach(row.ingredients) { ing in
                IngredientLine(ing: ing)
            }
            if !row.known {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: "book.closed").font(.caption).foregroundStyle(Theme.link)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Learn: " + row.source).font(.caption).foregroundStyle(Theme.text)
                        if let tv = row.tvNote {
                            Text(tv).font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panelAlt.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.35), lineWidth: 1))
    }
}

private struct IngredientLine: View {
    let ing: CookIngredient

    private var symbol: String {
        if ing.isMissing { return "xmark.circle.fill" }
        return ing.inReach >= ing.need ? "checkmark.circle.fill" : "shippingbox.fill"
    }

    private var tint: Color {
        if ing.isMissing { return Theme.no }
        return ing.inReach >= ing.need ? Theme.yes : Theme.accent
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.caption).foregroundStyle(tint)
            if let url = wikify(ing.name.replacingOccurrences(of: "Any ", with: "")).runs.first?.url {
                Link(ing.name, destination: url).foregroundStyle(Theme.text)
            } else {
                Text(ing.name)
            }
            Text("×\(ing.need)").foregroundStyle(Theme.secondaryText)
            if ing.isDish && ing.isMissing {
                Text("cook it first").font(.caption2).foregroundStyle(Theme.accent)
            }
            Spacer()
            Text("have \(ing.have)").font(.caption).monospacedDigit().foregroundStyle(ing.isMissing ? Theme.no : Theme.secondaryText)
        }
        .font(.callout)
        .help(ing.places.isEmpty ? "You don't have any." : "You have: " + ing.places)
    }
}
