import Foundation

extension Checkup {

    // MARK: Storage

    /// Every container the host can store things in, with its contents and where it stands.
    func parseStorage() -> Section {
        var section = Section(title: "Storage", version: "1.3")
        var data = StorageData()
        let xsi = "\(info.nsPrefix):type"

        func items(of node: XNode?) -> [StoredItem] {
            guard let node else { return [] }
            return node.children("Item").compactMap { item in
                let name = item.childText("name")
                guard !name.isEmpty, item.attr("\(info.nsPrefix):nil") != "true" else { return nil }
                let type = item.attr(xsi) ?? "Object"
                let kind: String
                switch type {
                case "Tool", "WateringCan", "Axe", "Pickaxe", "Hoe", "FishingRod", "Pan", "Shears", "MilkPail", "Wand", "GenericTool", "Lantern", "MagnifyingGlass": kind = "Tool"
                case "MeleeWeapon", "Slingshot": kind = "Weapon"
                case "Ring", "CombinedRing": kind = "Ring"
                case "Hat": kind = "Hat"
                case "Boots": kind = "Boots"
                case "Clothing": kind = "Clothing"
                case "Furniture", "BedFurniture", "StorageFurniture", "FishTankFurniture", "TV": kind = "Furniture"
                case "Trinket": kind = "Trinket"
                default: kind = "Item"
                }
                return StoredItem(name: name, count: max(1, num(item.childText("stack"))), quality: num(item.childText("quality")), kind: kind)
            }
        }
        func color(of chest: XNode) -> (Int, Int, Int)? {
            // Packed as ABGR; all-zero RGB is the default wooden colour.
            guard let packed = UInt32(chest.text("playerChoiceColor > PackedValue")) else { return nil }
            let r = Int(packed & 0xFF), g = Int((packed >> 8) & 0xFF), b = Int((packed >> 16) & 0xFF)
            return r == 0 && g == 0 && b == 0 ? nil : (r, g, b)
        }

        var backpack = StorageBox(id: "backpack", name: "Backpack", location: "you", capacity: max(12, num(hostPlayer.childText("maxItems"))))
        backpack.items = items(of: hostPlayer.child("items"))
        data.boxes.append(backpack)

        var globals: [String: XNode] = [:]
        for g in doc.find("globalInventories > item") { globals[g.text("key > string")] = g.first("value > ArrayOfItem") }

        var seenNames: [String: Int] = [:]
        var locations: [(XNode, String)] = []
        for loc in doc.find("locations > GameLocation") {
            locations.append((loc, loc.childText("name")))
            for b in loc.find("buildings > Building") {
                guard let indoors = b.child("indoors") else { continue }
                var name = b.childText("buildingType")
                if name.isEmpty { name = indoors.childText("name") }
                seenNames[name, default: 0] += 1
                locations.append((indoors, name))
            }
        }
        // Number duplicate buildings ("Shed 2") so their chests can be told apart.
        var counter: [String: Int] = [:]
        for i in locations.indices where (seenNames[locations[i].1] ?? 0) > 1 {
            counter[locations[i].1, default: 0] += 1
            locations[i].1 += " \(counter[locations[i].1]!)"
        }

        for (loc, locName) in locations {
            let display = locName == "FarmHouse" ? "Farmhouse" : locName
            if let fridge = loc.child("fridge"), !fridge.children("Item").isEmpty || fridge.child("items") != nil {
                var box = StorageBox(id: "fridge-\(display)", name: "Fridge", location: display)
                box.items = items(of: fridge.child("items"))
                if !box.items.isEmpty { data.boxes.append(box) }
            }
            // Direct children only: buildings nest their own indoors under the Farm.
            for entry in loc.child("objects")?.children("item") ?? [] {
                guard let obj = entry.first("value > Object") else { continue }
                let tile = (num(entry.text("key > Vector2 > X")), num(entry.text("key > Vector2 > Y")))
                var chest: XNode? = nil
                var name = obj.childText("name")
                if obj.attr(xsi) == "Chest" {
                    chest = obj
                    let special = obj.childText("specialChestType")
                    if special == "MiniShippingBin" { continue }
                    if special == "BigChest" { name = name == "Stone Chest" ? "Big Stone Chest" : "Big Chest" }
                    if special == "JunimoChest" { name = "Junimo Chest" }
                } else if let held = obj.child("heldObject"), held.attr(xsi) == "Chest" {
                    chest = held  // Auto-Grabber and the like keep their output in a held chest
                }
                guard let chest else { continue }
                var box = StorageBox(id: "\(display)-\(tile.0)-\(tile.1)", name: name, location: display, tile: tile)
                box.color = color(of: chest).map { ($0.0, $0.1, $0.2) }
                box.capacity = name.hasPrefix("Big") ? 70 : 36
                let gid = chest.childText("globalInventoryId")
                box.items = items(of: gid.isEmpty ? chest.child("items") : globals[gid])
                data.boxes.append(box)
            }
        }

        let containers = data.boxes.count - 1
        let empty = data.boxes.filter { $0.items.isEmpty && $0.name != "Backpack" }.count
        var cell = Cell()
        let emptyNote = empty == 0 ? "" : empty == 1 ? " 1 is empty." : " \(empty) are empty."
        cell.summary.append(.result(RichText("\(containers) container\(containers == 1 ? "" : "s") (chests, fridges, auto-grabbers) plus your backpack, holding \(data.totalStacks) stacks.\(emptyNote)")))
        cell.summary.append(.explain(RichText("Search for an item to see which chest it's in; tile coordinates count from the top-left corner of the map.")))
        cell.details.append(.storage(data))
        section.hasDetails = true
        section.globalCells = [cell]
        return section
    }
}
