import Foundation

extension Checkup {

    struct NPCInfo {
        var isDatable = false
        var isGirl = false
        var isChild = false
        var relStatus = "Friendly"
    }

    /// <hearts, event id(s) separated by '|'>
    typealias HeartEvent = (hearts: Double, id: String)

    final class SocialMeta: SectionMeta {
        var countdown = 0
        var ignore: Set<String> = []
        var npc: [String: NPCInfo] = [:]
        var npcOrder: [String] = []
        var eventList: [String: [HeartEvent]] = [:]
    }

    // MARK: Social

    func parseSocial() -> Section {
        let meta = SocialMeta()
        let spouse = doc.text("player > spouse") // only used for 1.2 engagement checking
        meta.countdown = num(doc.text("countdownToWedding"))
        meta.ignore = ["Horse", "Cat", "Dog", "Fly", "Grub", "GreenSlime", "Gunther", "Marlon", "Bouncer", "Mister Qi",
                       "Henchman", "Birdie", "Fizz", "Pet", "Raccoon", "Bat", "Truffle Crab"]
        var ev: [String: [HeartEvent]] = [
            "Abigail": [(2, "1"), (4, "2"), (6, "4"), (8, "3"), (10, "901756")],
            "Alex": [(2, "20"), (4, "2481135"), (5, "21"), (6, "2119820"), (8, "288847"), (10, "911526")],
            "Elliott": [(2, "39"), (4, "40"), (6, "423502"), (8, "1848481"), (10, "43")],
            "Emily": [(2, "471942"), (4, "463391"), (6, "917409"), (8, "2123243"), (10, "2123343")],
            "Haley": [(2, "11"), (4, "12"), (6, "13"), (8, "14"), (10, "15")],
            "Harvey": [(2, "56"), (4, "57"), (6, "58"), (8, "571102"), (10, "528052")],
            "Leah": [(2, "50"), (4, "51"), (6, "52"), (8, "53|584059"), (10, "54")],
            "Maru": [(2, "6"), (4, "7"), (6, "8"), (8, "9"), (10, "10")],
            "Penny": [(2, "34"), (4, "35"), (6, "36"), (8, "181928"), (10, "38")],
            "Sam": [(2, "44"), (3, "733330"), (4, "46"), (6, "45"), (8, "4081148"), (10, "233104")],
            "Sebastian": [(2, "2794460"), (4, "384883"), (6, "27"), (8, "29"), (10, "384882")],
            "Shane": [(2, "611944"), (4, "3910674"), (6, "3910975"), (6.8, "3910974"), (7, "831125"), (8, "3900074"), (10, "9581348")],
            "Caroline": [(6, "17")],
            "Clint": [(3, "97"), (6, "101")],
            "Demetrius": [(6, "25")],
            "Dwarf": [(0.2, "691039")],
            "Evelyn": [(4, "19")],
            "George": [(6, "18")],
            "Gus": [(4, "96")],
            "Jas": [],
            "Jodi": [(4, "94|95")],
            "Kent": [(3, "100")],
            "Krobus": [],
            "Lewis": [(6, "639373")],
            "Linus": [(0.2, "502969"), (4, "26")],
            "Marnie": [(6, "639373")],
            "Pam": [],
            "Pierre": [(6, "16")],
            "Robin": [(6, "33")],
            "Sandy": [],
            "Vincent": [],
            "Willy": [],
            "Wizard": [],
        ]
        if info.isAtLeast("1.3") {
            ev["Jas"]!.append((8, "3910979"))
            ev["Vincent"]!.append((8, "3910979"))
            ev["Linus"]!.append((8, "371652"))
            ev["Pam"]!.append((9, "503180"))
            ev["Willy"]!.append((6, "711130"))
        }
        if info.isAtLeast("1.4") {
            ev["Gus"]!.append((5, "980558"))
            ev["Caroline"]!.append((2, "719926"))
            ev["Abigail"]!.append((14, "6963327"))
            ev["Emily"]! += [(14.1, "3917600"), (14.2, "3917601")]
            ev["Haley"]! += [(14.1, "6184643"), (14.2, "8675611"), (14.3, "6184644")]
            ev["Leah"]! += [(14.1, "3911124"), (14.2, "3091462")]
            ev["Maru"]! += [(14.1, "3917666"), (14.2, "5183338")]
            ev["Penny"]! += [(14.1, "4325434"), (14.2, "4324303")]
            ev["Alex"]! += [(14.1, "3917587"), (14.2, "3917589"), (14.3, "3917590")]
            ev["Elliott"]! += [(14.1, "3912125"), (14.2, "3912132")]
            ev["Harvey"]!.append((14, "3917626"))
            ev["Sam"]! += [(14.1, "3918600"), (14.2, "3918601"), (14.3, "3918602"), (14.4, "3918603")]
            ev["Sebastian"]! += [(14.1, "9333219"), (14.2, "9333220")]
            ev["Shane"]! += [(14.1, "3917584"), (14.2, "3917585"), (14.3, "3917586")]
            ev["Krobus"]!.append((14, "7771191"))
        }
        if info.isAtLeast("1.5") {
            ev["Leo"] = [(0, "1039573"), (2, "6497423"), (4, "6497421"), (6, "6497428"), (9, "8959199")]
        }
        meta.eventList = ev

        // Search locations for NPCs (mod-friendly, and gives us children + 1.2 relationship status).
        for loc in doc.find("locations > GameLocation") {
            for npc in loc.find("characters > NPC") {
                let type = npc.attr("\(info.nsPrefix):type") ?? ""
                let who = npc.text("name")
                if meta.ignore.contains(type) || meta.ignore.contains(who) { continue }
                var n = NPCInfo()
                n.isDatable = npc.text("datable") == "true"
                n.isGirl = npc.text("gender") == "1"
                n.isChild = type == "Child"
                if info.isBefore("1.3") {
                    if npc.text("divorcedFromFarmer") == "true" {
                        n.relStatus = "Divorced"
                    } else if meta.countdown > 0 && who == String(spouse.dropLast(7)) {
                        n.relStatus = "Engaged"
                    } else if num(npc.text("daysMarried")) > 0 {
                        n.relStatus = "Married"
                    } else if npc.text("datingFarmer") == "true" {
                        n.relStatus = "Dating"
                    } else {
                        n.relStatus = "Friendly"
                    }
                }
                if meta.npc[who] == nil { meta.npcOrder.append(who) }
                meta.npc[who] = n
            }
        }

        var section = Section(title: "Social", version: "1.2")
        section.columns = perPlayer { parsePlayerSocial($0, meta) }
        section.hasDetails = meta.hasDetails
        return section
    }

    private func parsePlayerSocial(_ player: XNode, _ meta: SocialMeta) -> [Cell] {
        var cells: [Cell] = []
        var count5h = 0
        var count10h = 0
        var maxedCount = 0
        var maxedTotal = 0
        let umid = info.umid(of: player)
        let pd = info.data[umid]!
        let isHost = umid == info.farmerId
        var points: [String: Int] = [:]
        var giftsThisWeek: [String: Int] = [:]
        var talkedToday: Set<String> = []
        var listFam: [FriendRow] = []
        var listBach: [FriendRow] = []
        var listOther: [FriendRow] = []
        var listPoly: [FriendRow] = []
        let farmer = player.childText("name")
        var spouse: String? = player.child("spouse")?.text
        var dumpedGirls = 0
        var dumpedGuys = 0
        var hasNPCSpouse = false
        var npc = meta.npc   // per-player copy of status overrides
        let polyamory: [(String, [String])] = [
            ("All Bachelors", ["195013", "195099"]),
            ("All Bachelorettes", ["195012", "195019"]),
        ]

        if info.isAtLeast("1.3") {
            for item in player.find("activeDialogueEvents > item") {
                let which = item.text("key > string")
                let n = num(item.text("value > int"))
                if which == "dumped_Girls" { dumpedGirls = n } else if which == "dumped_Guys" { dumpedGuys = n }
            }
            for item in player.find("friendshipData > item") {
                let who = item.text("key > string")
                // Doved children still have friendshipData but no longer exist as characters.
                if meta.ignore.contains(who) || npc[who] == nil { continue }
                let n = num(item.text("value > Friendship > Points"))
                if n >= 2500 { count10h += 1 }
                if n >= 1250 { count5h += 1 }
                if meta.eventList[who] != nil {
                    maxedTotal += 1
                    if (npc[who]!.isDatable && n >= 2000) || n >= 2500 { maxedCount += 1 }
                }
                points[who] = n
                giftsThisWeek[who] = num(item.text("value > Friendship > GiftsThisWeek"))
                if item.text("value > Friendship > TalkedToToday") == "true" { talkedToday.insert(who) }
                npc[who]!.relStatus = item.text("value > Friendship > Status")
                let isRoommate = item.text("value > Friendship > RoommateMarriage") == "true"
                if npc[who]!.relStatus == "Married" && isRoommate {
                    npc[who]!.relStatus = "Roommate"
                }
            }
        } else {
            for item in player.find("friendships > item") {
                let who = item.text("key > string")
                let n = num(item.find("value > ArrayOfInt > int").first?.text)
                if n >= 2500 { count10h += 1 }
                if n >= 1250 { count5h += 1 }
                points[who] = n
            }
            if meta.countdown > 0, let s = spouse {
                spouse = String(s.dropLast(7))
            }
        }

        let hasSpouseStardrop = pd.hasMail("CF_Spouse")
        let hasPamHouse = pd.hasMail("pamHouseUpgrade")

        func eventCheck(_ arr: HeartEvent, _ who: String) -> (RichText, FriendEvent) {
            var seen = false
            var neg: MarkState = .no
            for e in arr.id.split(separator: "|") where pd.hasEvent(String(e)) {
                seen = true
            }
            // Permanently missable events: Clint 6H, Sam 3H, Penny 4H/6H after Pam's house in some versions.
            if (arr.id == "101" && (pd.hasEvent("2123243") || pd.hasEvent("2123343"))) ||
                (arr.id == "733330" && pd.stat("daysPlayed") > 84) ||
                (arr.id == "35" && hasPamHouse && info.isBefore("1.5")) ||
                (arr.id == "36" && hasPamHouse && info.isBefore("1.4")) {
                neg = .imp
            }
            // 10-heart events are impossible without a bouquet.
            if arr.hearts == 10, let n = npc[who], n.isDatable, n.relStatus == "Friendly" {
                neg = .imp
            }
            // 14-heart events are impossible if married to someone else.
            if arr.hearts >= 14 && who != spouse {
                neg = .imp
            }
            var extra = ""
            if arr.id == "3910979" { extra = " (Jas & Vincent both)" }
            else if arr.id == "639373" { extra = " (Lewis & Marnie both)" }
            let state: MarkState = seen ? .yes : neg
            if isHost { hostEventStates[arr.id] = state }
            return (" ".rt + Fmt.marker(jsNum(arr.hearts) + "♥" + extra, state),
                    FriendEvent(label: jsNum(arr.hearts) + "♥", state: state, note: extra.trimmingCharacters(in: .whitespaces)))
        }

        for who in meta.npcOrder {
            guard var n = npc[who] else { continue }
            // Status override for the confrontation events.
            if dumpedGirls > 0 && n.isDatable && n.isGirl {
                n.relStatus = "Angry (\(dumpedGirls) more day(s))"
            } else if dumpedGuys > 0 && n.isDatable && !n.isGirl {
                n.relStatus = "Angry (\(dumpedGuys) more day(s))"
            }
            var pts = 0
            if let p = points[who] { pts = p } else { n.relStatus = "Unmet" }
            npc[who] = n
            let hearts = pts / 250
            var entry = n.isChild ? "\(who) (".rt + wikify("Child", "Children") + ")" : wikify(who)
            entry += ": \(n.relStatus), \(hearts)♥ (\(pts) pts) -- "

            var eventLine: RichText? = nil
            var events: [FriendEvent] = []
            if let list = meta.eventList[who], !list.isEmpty {
                var line = RichText("Event(s):")
                for a in list.sorted(by: { $0.hearts < $1.hearts }) {
                    let (t, e) = eventCheck(a, who)
                    line += t
                    events.append(e)
                }
                eventLine = line
            }
            var row = FriendRow(name: who, url: n.isChild ? nil : wikify(who).runs.first?.url, status: n.relStatus,
                                hearts: hearts, points: pts, isChild: n.isChild, events: events, text: entry, eventLine: eventLine)
            if who == spouse {
                // Spouse Stardrop threshold is 3375 (3125 w/ stardrop); 3500 (14 hearts) in 1.4
                var maxPts = hasSpouseStardrop ? 3250 : 3375
                if info.isAtLeast("1.4") { maxPts = 3500 }
                row.need = pts >= maxPts ? RichText(runs: [Run(text: "MAX (can still decay)", color: .yes)])
                    : RichText(runs: [Run(text: "need \(maxPts - pts) more", color: .no)])
                row.maxHearts = 14
                hasNPCSpouse = true
            } else if n.isDatable {
                let maxPts = n.relStatus == "Dating" ? 2500 : 2000
                row.need = pts >= maxPts ? RichText(runs: [Run(text: "MAX", color: .yes)])
                    : RichText(runs: [Run(text: "need \(maxPts - pts) more", color: .no)])
                if n.relStatus != "Dating" { row.lockedFrom = 8 }
            } else {
                row.need = pts >= 2500 ? RichText(runs: [Run(text: "MAX", color: .yes)])
                    : RichText(runs: [Run(text: "need \(2500 - pts) more", color: .no)])
            }
            row.text = entry + row.need
            if isHost && !n.isChild {
                hostCharacterStatus[who] = CharacterStatus(
                    name: who, isMet: points[who] != nil, hearts: hearts, points: pts, maxHearts: row.maxHearts,
                    lockedFrom: row.lockedFrom, status: n.relStatus, isDatable: n.isDatable, need: row.need,
                    giftsThisWeek: giftsThisWeek[who] ?? 0, talkedToday: talkedToday.contains(who))
            }
            if who == spouse {
                listFam.append(row)
            } else if n.isDatable {
                listBach.append(row)
            } else if n.isChild {
                listFam.append(row)
            } else {
                listOther.append(row)
            }
        }
        if info.isAtLeast("1.3") {
            for (who, ids) in polyamory {
                let seen = ids.contains { pd.hasEvent($0) }
                let state: MarkState = seen ? .yes : (hasNPCSpouse ? .imp : .no)
                if isHost { hostEventStates[ids.joined(separator: "|")] = state }
                listPoly.append(FriendRow(name: who, url: nil, status: "", hearts: nil,
                                          events: [FriendEvent(label: "10♥", state: state, note: "")],
                                          text: "\(who): ".rt + Fmt.marker("10♥", state)))
            }
        }
        var listIntro: [String] = []
        for s in player.find("questLog > \(info.typeIs("SocializeQuest")) > whoToGreet > string") {
            listIntro.append(s.text)
        }
        let hasCompletedIntroductions = listIntro.isEmpty

        var c1 = Cell()
        c1.summary.append(.result(RichText("\(farmer) has \(hasCompletedIntroductions ? "" : "not ")met everyone in town.")))
        let introDesc = "Complete ".rt + "Introductions".italic + " quest"
        c1.summary.append(.achList([
            listIntro.isEmpty ? Fmt.milestone(introDesc, true) : Fmt.milestone(introDesc, false) + "\(listIntro.count) more",
        ]))
        if !listIntro.isEmpty {
            c1.details.append(.need(RichText("Villagers left to meet"), listIntro.sorted().map { DetailItem($0) }, ordered: true))
        }
        cells.append(c1)

        var c2 = Cell()
        c2.summary.append(.result(RichText("\(farmer) has \(count5h) relationship(s) of 5+ hearts.")))
        func a5(_ name: String, _ n: Int, _ label: String) -> StatusLine {
            (count5h >= n ? Fmt.achieve(name, "5♥ with \(label)", true) : Fmt.achieve(name, "5♥ with \(label)", false) + "\(n - count5h) more").progress(count5h, n)
        }
        c2.summary.append(.achList([a5("A New Friend", 1, "1 person"), a5("Cliques", 4, "4 people"), a5("Networking", 10, "10 people"), a5("Popular", 20, "20 people")]))
        cells.append(c2)

        var c3 = Cell()
        c3.summary.append(.result(RichText("\(farmer) has \(count10h) relationships of 10+ hearts.")))
        func a10(_ name: String, _ n: Int, _ label: String) -> StatusLine {
            (count10h >= n ? Fmt.achieve(name, "10♥ with \(label)", true) : Fmt.achieve(name, "10♥ with \(label)", false) + "\(n - count10h) more").progress(count10h, n)
        }
        c3.summary.append(.achList([a10("Best Friends", 1, "1 person"), a10("The Beloved Farmer", 8, "8 people")]))
        cells.append(c3)

        var ptPct = RichText()
        if info.isAtLeast("1.5") {
            info.perfection.set(umid, "Great Friends", CountTotal(count: maxedCount, total: maxedTotal))
            ptPct = Fmt.ptLink(pct: maxedTotal == 0 ? 0 : Double(maxedCount) / Double(maxedTotal))
        }
        var c4 = Cell()
        c4.summary.append(.result("\(farmer) has maxed \(maxedCount) of \(maxedTotal) base game villager relationships.".rt + ptPct))
        c4.summary.append(.explain(RichText("Note: for this milestone, all dateable NPCs are considered maxed at 8 hearts.")))
        c4.summary.append(.achList([
            (maxedCount >= maxedTotal ? Fmt.milestone("Max out hearts with all base game villagers", true)
                : Fmt.milestone("Max out hearts with all base game villagers", false) + "\(maxedTotal - maxedCount) more").progress(maxedCount, maxedTotal),
        ]))
        cells.append(c4)

        var c5 = Cell()
        var groups: [FriendGroup] = []
        func sorted(_ rows: [FriendRow]) -> [FriendRow] { rows.sorted { $0.sortKey < $1.sortKey } }
        if !listFam.isEmpty { groups.append(FriendGroup(title: "Family (includes all player children)", rows: sorted(listFam))) }
        if !listBach.isEmpty { groups.append(FriendGroup(title: "Datable Villagers", rows: sorted(listBach))) }
        if !listPoly.isEmpty { groups.append(FriendGroup(title: "Polyamory Events", rows: sorted(listPoly))) }
        if !listOther.isEmpty { groups.append(FriendGroup(title: "Other Villagers", rows: sorted(listOther))) }
        c5.details.append(.result(RichText("Individual Friendship Progress for \(farmer)")))
        c5.details.append(.friends(groups))
        meta.hasDetails = true
        cells.append(c5)
        return cells
    }

    // MARK: Home and Family

    func parseFamily() -> Section {
        let wedding = num(doc.text("countdownToWedding"))
        let isHost = true
        return playerSection(title: "Home and Family", version: "1.2") { player, _ in
            var needs: [String] = []
            var count = 0
            let maxUpgrades = isHost ? 3 : 2
            let houseType = isHost ? "FarmHouse" : "Cabin"
            let farmer = player.childText("name")
            var spouse = player.child("spouse")?.text ?? ""
            let umid = info.umid(of: player)
            var childNames: [String] = []
            let houseUpgrades = num(player.childText("houseUpgradeLevel"))
            if !spouse.isEmpty {
                if wedding > 0 && info.isBefore("1.3") { spouse = String(spouse.dropLast(7)) }
                count += 1
            } else if let partner = info.partners[umid] {
                spouse = info.playerName(partner)
                count += 1
            } else {
                spouse = "(None)"
                needs.append("spouse")
            }
            let title = spouse == "Krobus" ? "roommate" : "spouse"
            var cells: [Cell] = []
            var c1 = Cell()
            c1.summary.append(.result(RichText("\(farmer)'s \(title): \(spouse)" + (wedding > 0 ? " -- wedding in \(wedding) day(s)" : ""))))
            if let kids = info.children[umid], !kids.isEmpty {
                childNames = kids
                count += kids.count
            } else if let partner = info.partners[umid], let kids = info.children[partner], !kids.isEmpty {
                childNames = kids
                count += kids.count
            } else if let parent = player.parent {
                for c in parent.find("\(info.typeIs(houseType)) NPC\(info.typeIs("Child"))") {
                    count += 1
                    childNames.append(c.text("name"))
                }
            }
            var children = "(None)"
            if !childNames.isEmpty {
                children = childNames.joined(separator: ", ")
                if childNames.count == 1 { needs.append("1 child") }
            } else {
                needs.append("2 children")
            }
            c1.summary.append(.result(RichText("\(farmer)'s children: \(children)")))
            c1.summary.append(.achList([
                count >= 3 ? Fmt.achieve("Full House", "Married + 2 kids", true)
                    : Fmt.achieve("Full House", "Married + 2 kids", false) + needs.joined(separator: " and "),
            ]))
            cells.append(c1)
            var c2 = Cell()
            c2.summary.append(.result(RichText("\(houseType) upgraded \(houseUpgrades) time(s) of \(maxUpgrades) possible.")))
            c2.summary.append(.achList([
                (houseUpgrades >= 1 ? Fmt.achieve("Moving Up", "1 upgrade", true) : Fmt.achieve("Moving Up", "1 upgrade", false) + "\(1 - houseUpgrades) more").progress(houseUpgrades, 1),
                (houseUpgrades >= 2 ? Fmt.achieve("Living Large", "2 upgrades", true) : Fmt.achieve("Living Large", "2 upgrades", false) + "\(2 - houseUpgrades) more").progress(houseUpgrades, 2),
                (houseUpgrades >= maxUpgrades ? Fmt.milestone("House fully upgraded", true) : Fmt.milestone("House fully upgraded", false) + "\(maxUpgrades - houseUpgrades) more").progress(houseUpgrades, maxUpgrades),
            ]))
            cells.append(c2)
            return cells
        }
    }
}
