import Foundation

extension Checkup {

    // MARK: Cooking Planner

    /// For every recipe: known or not, cooked or not, and whether the host has the ingredients.
    func buildCookingPlan() -> CookPlanData {
        let recipes = cookingRecipeMap()
        let validNames = Set(recipes.pairs.map(\.1))
        var known: Set<String> = []
        for item in hostPlayer.find("cookingRecipes > item") {
            var id = item.text("key > string")
            if let t = Checkup.cookingTranslate[id] { id = t }
            known.insert(id)
        }
        var cooked: [String: Int] = [:]
        for item in hostPlayer.find("recipesCooked > item") {
            let id = item.first("key")?.allChildren.first?.text ?? ""
            let n = num(item.text("value > int"))
            if let r = recipes[id], n > 0 { cooked[r] = n }
        }

        let season = capitalize(doc.text("currentSeason"))
        let day = num(doc.text("dayOfMonth"))
        let year = num(doc.text("year"))
        let seasons = CalendarData.seasons
        func dateKey(_ d: Int, _ s: String, _ y: Int) -> Int { y * 1000 + (seasons.firstIndex(of: s) ?? 0) * 100 + d }
        let today = dateKey(day, season, year)

        let owned = hostOwnedItems
        let dishes = Set(CookingData.recipes.map(\.name))
        func inReach(_ places: [String: Int]) -> Int {
            places.filter { $0.key == "Inventory" || $0.key.hasPrefix("Fridge") || $0.key.hasPrefix("Mini-Fridge") }.values.reduce(0, +)
        }
        /// Category ingredients accept any item of the category.
        let categoryOf: [String: Int] = ["Egg": GiftTastes.egg, "Milk": GiftTastes.milk, "Any Fish": GiftTastes.fish]

        var data = CookPlanData()
        data.hasKitchen = num(hostPlayer.childText("houseUpgradeLevel")) >= 1
        for recipe in CookingData.recipes where validNames.contains(recipe.name) {
            var row = CookPlanRow(name: recipe.name, state: .learn, known: known.contains(recipe.name), source: recipe.source)
            row.timesCooked = cooked[recipe.name] ?? 0
            for (name, count) in recipe.ingredients {
                var ing = CookIngredient(name: name, need: count)
                ing.isDish = dishes.contains(name)
                var places: [String: Int] = [:]
                let matches: [OwnedItem]
                if let cat = categoryOf[name] {
                    matches = owned.values.filter { $0.category == cat }
                } else {
                    matches = owned[name].map { [$0] } ?? []
                }
                for m in matches {
                    ing.have += m.count
                    for (k, v) in m.places { places[k, default: 0] += v }
                }
                ing.inReach = inReach(places)
                if categoryOf[name] != nil {
                    ing.places = matches.sorted { $0.count > $1.count }.map { "\($0.name) ×\($0.count)" }.joined(separator: ", ")
                } else {
                    ing.places = places.sorted { $0.value > $1.value }.map { "\($0.key) ×\($0.value)" }.joined(separator: ", ")
                }
                row.ingredients.append(ing)
            }
            if let tv = recipe.tv, !row.known {
                row.tvNote = dateKey(tv.0, tv.1, tv.2) <= today
                    ? "Already aired: it can come back on a Wednesday rerun of the Queen of Sauce."
                    : "Airs on Sunday \(tv.1) \(tv.0), year \(tv.2)."
            }
            let allOwned = row.ingredients.allSatisfy { !$0.isMissing }
            let allInReach = row.ingredients.allSatisfy { $0.inReach >= $0.need }
            if row.timesCooked > 0 {
                row.state = .cooked
            } else if !row.known {
                row.state = .learn
            } else if allInReach {
                row.state = .cookNow
            } else if allOwned {
                row.state = .fetch
            } else {
                row.state = .missing
            }
            data.rows.append(row)
        }

        return data
    }
}
