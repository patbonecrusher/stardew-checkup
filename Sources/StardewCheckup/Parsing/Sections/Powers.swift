import Foundation

extension Checkup {

    // MARK: Books, Special Items & Powers (1.6)

    func parsePowers() -> Section? {
        // Power information is taken and modified from Data/Powers.xnb
        let version = "1.6"
        if info.isBefore(version) { return nil }
        let bookPowers: [(String, String)] = [
            "Book_AnimalCatalogue", "Book_Artifact", "Book_Bombs", "Book_Crabbing", "Book_Defense", "Book_Diamonds", "Book_Friendship",
            "Book_Grass", "Book_Horse", "Book_Marlon", "Book_Mystery", "Book_PriceCatalogue", "Book_Roe", "Book_Speed", "Book_Speed2",
            "Book_Trash", "Book_Void", "Book_WildSeeds", "Book_Woodcutting",
        ].map { ($0, "PLAYER_STAT Current \($0) 1") }
        let otherPowers: [(String, String)] = [
            ("BearPaw", "PLAYER_HAS_SEEN_EVENT Current 2120303"),
            ("ClubCard", "PLAYER_HAS_FLAG Current HasClubCard"),
            ("DarkTalisman", "PLAYER_HAS_FLAG Current HasDarkTalisman"),
            ("DwarvishTranslationGuide", "PLAYER_HAS_FLAG Host HasDwarvishTranslationGuide"),
            ("ForestMagic", "PLAYER_HAS_FLAG Current canReadJunimoText"),
            ("KeyToTheTown", "PLAYER_HAS_FLAG Current HasTownKey"),
            ("MagicInk", "PLAYER_HAS_FLAG Current HasMagicInk"),
            ("MagnifyingGlass", "PLAYER_HAS_FLAG Current HasMagnifyingGlass"),
            ("Mastery_Combat", "PLAYER_STAT Current mastery_4 1"),
            ("Mastery_Farming", "PLAYER_STAT Current mastery_0 1"),
            ("Mastery_Fishing", "PLAYER_STAT Current mastery_1 1"),
            ("Mastery_Foraging", "PLAYER_STAT Current mastery_2 1"),
            ("Mastery_Mining", "PLAYER_STAT Current mastery_3 1"),
            ("RustyKey", "PLAYER_HAS_FLAG Host HasRustyKey"),
            ("SkullKey", "PLAYER_HAS_FLAG Host HasSkullKey"),
            ("SpecialCharm", "PLAYER_HAS_FLAG Current HasSpecialCharm"),
            ("SpringOnionMastery", "PLAYER_HAS_SEEN_EVENT Current 3910979"),
        ]
        let translate: [String: String] = [
            "BearPaw": "Bear's Knowledge", "ClubCard": "Qi Club Card", "DarkTalisman": "Dark Talisman",
            "DwarvishTranslationGuide": "Dwarvish Translation Guide", "ForestMagic": "Forest Magic", "KeyToTheTown": "Key to the Town",
            "MagicInk": "Magic Ink", "MagnifyingGlass": "Magnifying Glass", "Mastery_Combat": "Combat Mastery Perk",
            "Mastery_Farming": "Farming Mastery Perk", "Mastery_Fishing": "Fishing Mastery Perk", "Mastery_Foraging": "Foraging Mastery Perk",
            "Mastery_Mining": "Mining Mastery Perk", "RustyKey": "Rusty Key", "SkullKey": "Skull Key", "SpecialCharm": "Special Charm",
            "SpringOnionMastery": "Spring Onion Mastery",
        ]

        /// Evaluates one query string; `atLeast` uses the site's `>=` comparison (books), otherwise exact match.
        func check(_ query: String, _ pd: PlayerData, atLeast: Bool) -> Bool {
            let f = query.split(separator: " ").map(String.init)
            guard f.count >= 3 else { return false }
            let checkVal = f.count > 3 ? f[3] : nil
            func test(_ p: PlayerData) -> Bool {
                switch f[0] {
                case "PLAYER_HAS_SEEN_EVENT": return p.hasEvent(f[2])
                case "PLAYER_HAS_FLAG": return p.hasMail(f[2])
                case "PLAYER_STAT":
                    guard let v = p.stats[f[2]] else { return false }
                    guard let cv = checkVal else { return true }
                    return atLeast ? num(v) >= num(cv) : v == cv
                default: return false
                }
            }
            // A Host check also checks the current player.
            if f[1] == "Host" && test(info.host) { return true }
            return test(pd)
        }

        return playerSection(title: "Books, Special Items & Powers", version: version) { player, meta in
            let umid = player.childText("UniqueMultiplayerID")
            let pd = info.data[umid]!
            var haveBook = 0
            var haveOther = 0
            var need: [DetailItem] = []
            let isHost = umid == info.farmerId
            for (k, q) in bookPowers {
                if check(q, pd, atLeast: true) {
                    haveBook += 1
                    if isHost { info.overview.booksRead.insert(translate[k] ?? info.objects[k] ?? k) }
                } else {
                    let txt = translate[k] ?? info.objects[k] ?? k
                    need.append(DetailItem(txt.italic))
                }
            }
            for (k, q) in otherPowers {
                if check(q, pd, atLeast: false) {
                    haveOther += 1
                    if isHost { info.overview.powersHave.insert(translate[k] ?? info.objects[k] ?? k) }
                } else {
                    need.append(DetailItem(translate[k] ?? info.objects[k] ?? k))
                }
            }
            let name = info.playerName(umid)
            var cell = Cell()
            cell.summary.append(.result(RichText("\(name) has read \(haveBook) of \(bookPowers.count) books.")))
            cell.summary.append(.achList([
                (haveBook >= bookPowers.count ? Fmt.achieve("Well Read", "Read all books", true) : Fmt.achieve("Well-read", "Read all books", false) + "\(bookPowers.count - haveBook) more").progress(haveBook, bookPowers.count),
            ]))
            cell.summary.append(.result(RichText("\(name) has received \(haveOther) of \(otherPowers.count) special items & powers.")))
            cell.summary.append(.achList([
                (haveOther >= otherPowers.count ? Fmt.milestone("Acquire all special items & powers", true) : Fmt.milestone("Acquire all special items & powers", false) + "\(otherPowers.count - haveOther) more").progress(haveOther, otherPowers.count),
            ]))
            if !need.isEmpty {
                meta.hasDetails = true
                let label = "Left:" + (haveBook < bookPowers.count ? " (Books listed first)" : "")
                cell.details.append(.need(RichText(label), Checkup.sortedItems(need), ordered: true))
            }
            return [cell]
        }
    }

    // MARK: Arcade Games (1.5)

    func parseArcadeGames() -> Section? {
        let version = "1.5"
        if info.isBefore(version) { return nil }
        var section = playerSection(title: "Arcade Games", version: version) { player, _ in
            let umid = player.childText("UniqueMultiplayerID")
            let pd = info.data[umid]!
            let name = info.playerName(umid)
            let hasBeatenPK = pd.hasMail("Beat_PK")
            let hasBeatenJK = pd.hasMail("JunimoKart")
            var cell = Cell()
            cell.summary.append(.result(RichText("\(name) has\(hasBeatenPK ? "" : " not") beaten Journey of the Prairie King.")))
            var pkProgress = 0
            if let pkSave = player.child("JOTPKProgress") {
                let level = 1 + num(pkSave.text("whichRound > int"))
                let sublevel = 1 + num(pkSave.text("whichWave > int"))
                let died = pkSave.text("died > boolean") == "true"
                cell.summary.append(.result(RichText("\(name) has a JotPK save at stage \(level)-\(sublevel) (\(died ? "not " : "")deathless)")))
                pkProgress = level == 3 ? 8 : ((level == 2 ? 4 : -1) + sublevel)
            } else {
                cell.summary.append(.result(RichText("\(name) does not have a saved JotPK game.")))
            }
            cell.summary.append(.achList([
                hasBeatenPK ? Fmt.achieve("Prairie King", "Beat 'Journey of the Prairie King'", true)
                    : Fmt.achieve("Prairie King", "Beat 'Journey of the Prairie King'", false) + " to clear \(13 - pkProgress) more level(s)",
            ]))
            cell.summary.append(.result(RichText("\(name) has\(hasBeatenJK ? "" : " not") beaten Junimo Kart (Progress Mode).")))
            cell.summary.append(.achList([
                hasBeatenJK ? Fmt.milestone("Beat 'Junimo Kart'", true) : Fmt.milestone("Beat 'Junimo Kart'", false) + " to complete Progress Mode",
            ]))
            return [cell]
        }
        var board: [DetailItem] = []
        for e in doc.find("junimoKartLeaderboards > entries > NetLeaderboardsEntry") {
            let score = e.first("score")?.allChildren.first?.text ?? e.text("score")
            let who = e.first("name")?.allChildren.first?.text ?? e.text("name")
            board.append(DetailItem("\(addCommas(num(score))) – \(who)"))
        }
        section.hasDetails = !board.isEmpty
        if !board.isEmpty {
            var cell = Cell()
            cell.details.append(.result(RichText("Junimo Kart (Endless Mode) Leaderboard:")))
            cell.details.append(.list(board, ordered: true))
            section.trailingCells = [cell]
        }
        return section
    }

    // MARK: Animal Summary (1.6)

    func parseAnimals() -> Section? {
        let version = "1.6"
        if info.isBefore(version) { return nil }
        var section = Section(title: "Animal Summary", version: version)
        section.hasDetails = true
        var pets: [DetailItem] = []
        for npc in doc.find("locations > GameLocation > Characters > NPC") {
            let t = npc.attr("\(info.nsPrefix):type") ?? ""
            if t == "Pet" || t == "Cat" || t == "Dog" {
                let type = npc.text("petType")
                let love = num(npc.text("friendshipTowardFarmer"))
                pets.append(DetailItem("\(type) named \(npc.find("name").first?.text ?? "") (\(love) friendship points)"))
            }
        }
        var cells: [Cell] = []
        var petCell = Cell()
        petCell.summary.append(.result(RichText("Farm Pets (\(pets.count))")))
        petCell.details.append(.list(Checkup.sortedItems(pets), ordered: true))
        cells.append(petCell)

        let barns: Set<String> = ["Coop", "Big Coop", "Deluxe Coop", "Barn", "Big Barn", "Deluxe Barn"]
        for b in doc.find("\(info.typeIs("Farm")) Building") {
            let btype = b.text("buildingType")
            guard barns.contains(btype) else { continue }
            let cur = b.text("currentOccupants")
            let maxOcc = b.text("maxOccupants")
            var list: [DetailItem] = []
            for a in b.find("indoors > Animals > SerializableDictionaryOfInt64FarmAnimal FarmAnimal") {
                let cracker = a.text("hasEatenAnimalCracker") == "true"
                let type = a.text("type")
                let extra: RichText
                if type == "Pig" {
                    extra = " ".rt + Fmt.marker("cannot eat cracker", .imp)
                } else {
                    extra = " ".rt + Fmt.marker(cracker ? "has eaten cracker" : "has not eaten cracker", cracker ? .yes : .no)
                }
                list.append(DetailItem("\(type) named \(a.text("name"))".rt + extra))
            }
            var cell = Cell()
            cell.summary.append(.result(RichText("\(btype) (\(cur)/\(maxOcc))")))
            cell.details.append(.list(Checkup.sortedItems(list), ordered: true))
            cells.append(cell)
        }
        section.globalCells = cells
        return section
    }
}
