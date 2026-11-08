import Foundation

extension Checkup {

    // MARK: Scarecrows

    /// The eight Rarecrows, the Deluxe Scarecrow letter, and which crops on the farm the crows can reach.
    func parseScarecrows() -> Section? {
        guard let storage = storageData else { return nil }
        var section = Section(title: "Scarecrows", version: "1.3")
        var data = ScarecrowData()
        data.buildings = storage.buildings
        data.frontDoor = storage.frontDoor
        // "IslandWest" → "Ginger Island West" for display.
        func place(_ loc: String) -> String {
            loc.hasPrefix("Island") ? "Ginger Island " + loc.dropFirst(6) : loc
        }
        data.scarecrows = placedScarecrows.map { c in
            var c2 = PlacedScarecrow(name: c.name, location: place(c.location), tile: c.tile, radius: c.radius)
            c2.directions = c.location.hasPrefix("Island") ? nil : c.directions
            return c2
        }

        for n in 1...8 {
            var r = RarecrowStatus(number: n, source: RarecrowData.sources[n] ?? "")
            let name = "Rarecrow #\(n)"
            r.placed = data.scarecrows.filter { $0.name == name }.map { "\($0.location) (\($0.tile.x), \($0.tile.y))" }
            for box in storage.boxes {
                let count = box.items.filter { $0.name == name }.reduce(0) { $0 + $1.count }
                if count > 0 { r.stored.append(box.label + (count > 1 ? " ×\(count)" : "")) }
            }
            data.rarecrows.append(r)
        }

        data.hasLetter = info.host.hasMail("RarecrowSociety")
        for item in hostPlayer.find("craftingRecipes > item") where item.text("key > string") == "Deluxe Scarecrow" {
            data.knowsDeluxe = true
            data.deluxeCrafted = num(item.text("value > int"))
        }

        // Crows only visit the Farm map; a scarecrow covers tiles closer than radius + 1.
        let guards = placedScarecrows.filter(\.onFarm)
        if let farm = doc.find("locations > GameLocation").first(where: { $0.childText("name") == "Farm" }) {
            for entry in farm.child("terrainFeatures")?.children("item") ?? [] {
                guard let dirt = entry.first("value > TerrainFeature"), let crop = dirt.child("crop"),
                      crop.childText("dead") != "true" else { continue }
                let x = num(entry.text("key > Vector2 > X")), y = num(entry.text("key > Vector2 > Y"))
                let safe = guards.contains { g in
                    let dx = Double(x - g.tile.x), dy = Double(y - g.tile.y)
                    return (dx * dx + dy * dy).squareRoot() < Double(g.radius + 1)
                }
                data.crops.append((x, y, safe))
            }
        }

        let have = data.rarecrows.filter(\.have).count
        var cell = Cell()
        cell.summary.append(.result(RichText("\(info.intro) \(have) of 8 Rarecrows and \(placedScarecrows.count) scarecrow\(placedScarecrows.count == 1 ? "" : "s") placed (\(guards.count) on the farm).")))
        var lines = [(have == 8 ? Fmt.milestone("Collect all 8 Rarecrows", true) : Fmt.milestone("Collect all 8 Rarecrows", false) + "\(8 - have) more").progress(have, 8)]
        if info.isAtLeast("1.5") {
            let got = data.hasLetter || data.knowsDeluxe
            lines.append(got ? Fmt.milestone("Get the Deluxe Scarecrow recipe from the Rarecrow Society", true)
                : Fmt.milestone("Get the Deluxe Scarecrow recipe from the Rarecrow Society", false) + "all 8 Rarecrows placed on the farm")
        }
        cell.summary.append(.achList(lines))
        if !data.crops.isEmpty {
            let open = data.unprotected
            cell.summary.append(.result(RichText(open == 0
                ? (data.crops.count == 1 ? "Your one crop on the farm is covered by a scarecrow." : "All \(data.crops.count) crops on the farm are covered by a scarecrow.")
                : "\(open) of \(data.crops.count) crops on the farm are not covered by any scarecrow.")))
        }
        if !data.hasLetter && info.isAtLeast("1.5") {
            cell.summary.append(.explain(RichText(have == 8
                ? "Place all 8 Rarecrows on your farm at the same time; the Rarecrow Society's letter with the Deluxe Scarecrow recipe arrives the next morning."
                : "Once you have all 8, place them on your farm at the same time to get the Rarecrow Society's letter with the Deluxe Scarecrow recipe.")))
        }
        cell.details.append(.scarecrows(data))
        section.hasDetails = true
        section.globalCells = [cell]
        return section
    }
}
