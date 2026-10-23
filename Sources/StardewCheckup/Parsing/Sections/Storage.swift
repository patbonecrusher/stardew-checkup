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
        var locations: [(node: XNode, name: String, building: FarmBuilding?)] = []
        for loc in doc.find("locations > GameLocation") {
            let locName = loc.childText("name")
            locations.append((loc, locName, nil))
            for b in loc.find("buildings > Building") {
                var name = b.childText("buildingType")
                let indoors = b.child("indoors")
                if name.isEmpty { name = indoors?.childText("name") ?? "" }
                var fb = FarmBuilding(name: name, x: num(b.childText("tileX")), y: num(b.childText("tileY")),
                                      w: num(b.childText("tilesWide")), h: num(b.childText("tilesHigh")))
                if let dx = Int(b.text("humanDoor > X")), let dy = Int(b.text("humanDoor > Y")), dx >= 0, dy >= 0 {
                    // The door step is the tile just below the door in the building's footprint.
                    fb.door = (fb.x + dx, fb.y + dy + 1)
                }
                if locName == "Farm" {
                    data.buildings.append(fb)
                    if name == "Farmhouse" { data.frontDoor = fb.door }
                }
                guard let indoors else { continue }
                seenNames[name, default: 0] += 1
                locations.append((indoors, name, locName == "Farm" ? fb : nil))
            }
        }
        // Older saves have no Farmhouse building entry; the vanilla front door step is (64, 15).
        if data.frontDoor == nil { data.frontDoor = (64, 15) }
        // Number duplicate buildings ("Shed 2") so their chests can be told apart.
        var counter: [String: Int] = [:]
        for i in locations.indices where (seenNames[locations[i].name] ?? 0) > 1 && locations[i].building != nil {
            counter[locations[i].name, default: 0] += 1
            locations[i].name += " \(counter[locations[i].name]!)"
        }

        for (loc, locName, building) in locations {
            let display = locName == "FarmHouse" ? "Farmhouse" : locName
            if let fridge = loc.child("fridge"), !fridge.children("Item").isEmpty || fridge.child("items") != nil {
                var box = StorageBox(id: "fridge-\(display)", name: "Fridge", location: display)
                box.items = items(of: fridge.child("items"))
                box.directions = directions(box, building: building, door: data.frontDoor)
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
                box.onFarm = locName == "Farm"
                box.building = building?.name
                box.directions = directions(box, building: building, door: data.frontDoor)
                data.boxes.append(box)
            }
        }

        let containers = data.boxes.count - 1
        // Number duplicate building names on the map the same way as the container locations.
        var mapCounter: [String: Int] = [:]
        for i in data.buildings.indices where (seenNames[data.buildings[i].name] ?? 0) > 1 {
            mapCounter[data.buildings[i].name, default: 0] += 1
            data.buildings[i] = FarmBuilding(name: data.buildings[i].name + " \(mapCounter[data.buildings[i].name]!)",
                                             x: data.buildings[i].x, y: data.buildings[i].y, w: data.buildings[i].w, h: data.buildings[i].h, door: data.buildings[i].door)
        }
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

    /// "12 right, 4 down from your front door" style directions for a container.
    private func directions(_ box: StorageBox, building: FarmBuilding?, door: (x: Int, y: Int)?) -> String? {
        func offset(_ x: Int, _ y: Int) -> String? {
            guard let door else { return nil }
            let dx = x - door.x, dy = y - door.y
            var parts: [String] = []
            if dx != 0 { parts.append("\(abs(dx)) \(dx > 0 ? "right (east)" : "left (west)")") }
            if dy != 0 { parts.append("\(abs(dy)) \(dy > 0 ? "down (south)" : "up (north)")") }
            return parts.isEmpty ? "right at your front door" : parts.joined(separator: ", ") + " of your front door"
        }
        if box.location == "Farmhouse" { return "Inside your house" }
        if box.name == "Backpack" { return nil }
        if box.location == "Farm", let t = box.tile { return offset(t.x, t.y).map { $0.prefix(1).uppercased() + $0.dropFirst() } }
        if let b = building {
            let where_ = b.door.flatMap { offset($0.x, $0.y) }.map { "; its door is \($0)" } ?? ""
            return "Inside the \(box.location)\(where_)"
        }
        return "In \(box.location)"
    }
}
