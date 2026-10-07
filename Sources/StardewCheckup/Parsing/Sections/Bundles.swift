import Foundation

extension Checkup {

    struct BundleInfo {
        var name: String
        var qty: Int
        var items: [RichText]
    }
    struct RoomInfo {
        var name: String
        var bundles: [(id: String, info: BundleInfo)] = []
    }

    private static let roomID: [String: Int] = [
        "Pantry": 0, "Crafts Room": 1, "Fish Tank": 2, "Boiler Room": 3, "Vault": 4, "Bulletin Board": 5, "Abandoned Joja Mart": 6,
    ]
    private static let quality: [String: String] = ["1": "Silver", "2": "Gold", "4": "Iridium"]

    private func parseBundleData(_ input: [(String, String)]) -> [Int: RoomInfo] {
        var output: [Int: RoomInfo] = [:]
        for (k, v) in input {
            let kFields = k.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            guard kFields.count >= 2, let roomIdx = Checkup.roomID[kFields[0]] else { continue }
            let id = kFields[1]
            let vFields = v.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            guard vFields.count >= 5 else { continue }
            let bundleName = vFields[0]
            let itemData = vFields[2].split(separator: " ").map(String.init)
            let qtyStr = vFields[4]
            var bundle = BundleInfo(name: bundleName, qty: num(qtyStr), items: [])
            var i = 0
            while i + 2 < itemData.count {
                let itemName = info.objects[itemData[i]] ?? "Object ID \(itemData[i])"
                let n = num(itemData[i + 1]) > 1 ? "\(itemData[i + 1])x " : ""
                let q = Checkup.quality[itemData[i + 2]].map { $0 + " " } ?? ""
                if itemData[i] == "-1" {
                    bundle.items.append(RichText(addCommas(num(itemData[i + 1])) + "g"))
                } else {
                    bundle.items.append((n + q).rt + wikify(itemName))
                }
                i += 3
            }
            if qtyStr.isEmpty { bundle.qty = bundle.items.count }
            if output[roomIdx] == nil { output[roomIdx] = RoomInfo(name: kFields[0]) }
            output[roomIdx]!.bundles.append((id, bundle))
        }
        return output
    }

    // MARK: Community Center / Joja

    func parseBundles() -> Section {
        let version = "1.5"
        var section = Section(title: "Community Center / Joja Community Development", version: version)
        let farmer = doc.text("player > name")
        var isJojaMember = false
        var bundleHave: [String: Int] = [:]
        var itemsHave: [String: Set<Int>] = [:]
        let ccMail: [(String, Int)] = [("ccBoilerRoom", 3), ("ccCraftsRoom", 1), ("ccPantry", 0), ("ccFishTank", 2), ("ccVault", 4), ("ccBulletin", 5)]
        let ccCount = 6
        var ccHave = 0
        let ccEvent = "191393"
        let project = ["Greenhouse", "Bridge", "Panning", "Minecarts", "Bus"]
        let price = ["35,000g", "25,000g", "20,000g", "15,000g", "40,000g"]
        let jojaMail: [(String, Int)] = [("jojaBoilerRoom", 3), ("jojaCraftsRoom", 1), ("jojaPantry", 0), ("jojaFishTank", 2), ("jojaVault", 4)]
        let jojaCount = 5
        var jojaHave = 0
        let jojaEvent = "502261"
        var hasSeenCeremony = false
        var done: Set<Int> = []
        var hybrid = false
        var hybridLeft = 0
        var need: [DetailItem] = []
        let ccLoc = doc.first("locations > GameLocation\(info.typeIs("CommunityCenter"))")
        let host = info.host

        let bundleData: [Int: RoomInfo]
        if info.isBefore(version) {
            bundleData = parseBundleData(CollectionData.defaultBundleData)
        } else {
            var raw: [(String, String)] = []
            for item in doc.find("bundleData > item") {
                raw.append((item.text("key > string"), item.text("value > string")))
            }
            bundleData = parseBundleData(raw)
        }
        // Basic completion
        for (r, b) in (ccLoc?.find("areasComplete > boolean") ?? []).enumerated() where b.text == "true" {
            ccHave += 1
            done.insert(r)
        }
        // Donated items per bundle
        for item in ccLoc?.find("bundles > item") ?? [] {
            let id = item.text("key > int")
            bundleHave[id] = 0
            itemsHave[id] = []
            for (i, b) in item.find("ArrayOfBoolean > boolean").enumerated() where b.text == "true" {
                bundleHave[id]! += 1
                itemsHave[id]!.insert(i)
            }
        }
        isJojaMember = host.hasMail("JojaMember")
        for (id, room) in jojaMail where host.hasMail(id) {
            jojaHave += 1
            done.insert(room)
        }
        if ccHave > 0 && isJojaMember { hybrid = true }
        hybridLeft = jojaCount - ccHave
        if done.contains(5) { hybridLeft += 1 }
        hasSeenCeremony = host.hasEvent(isJojaMember ? jojaEvent : ccEvent)

        var cell = Cell()
        var achs: [StatusLine] = []
        if isJojaMember {
            if hybrid {
                cell.summary.append(.result(RichText("\(farmer) completed \(ccHave) Community Center room(s) and then became a Joja member.")))
                cell.summary.append(.result(RichText("\(farmer) has since completed \(jojaHave) of the remaining \(hybridLeft) projects on the Community Development Form.")))
            } else {
                cell.summary.append(.result(RichText("\(farmer) is a Joja member and has completed \(jojaHave) of the \(jojaCount) projects on the Community Development Form.")))
            }
            hybridLeft -= jojaHave
            cell.summary.append(.result(RichText("\(farmer)\(hasSeenCeremony ? " has" : " has not") attended the completion ceremony")))
            achs.append(Fmt.achieveImpossible("Local Legend", "restore the Pelican Town Community Center"))
            var temp = ""
            if !hasSeenCeremony {
                if hybridLeft > 0 {
                    temp = "\(hybridLeft) more project(s) and the ceremony"
                    for (id, room) in ccMail where id != "ccBulletin" && !done.contains(room) {
                        need.append(DetailItem(" Purchase \(project[room]) project for \(price[room])"))
                    }
                } else {
                    temp = " to attend the ceremony"
                }
                need.append(DetailItem("Attend the completion ceremony at the Joja Warehouse"))
            }
            achs.append(hasSeenCeremony ? Fmt.achieve("Joja Co. Member Of The Year", "", true) : Fmt.achieve("Joja Co. Member Of The Year", "", false) + temp)
        } else {
            cell.summary.append(.result(RichText("\(farmer) is not a Joja member and has completed \(ccHave) of the \(ccCount) Community Center rooms.")))
            cell.summary.append(.result(RichText("\(farmer)\(hasSeenCeremony ? " has" : " has not") attended the completion ceremony")))
            if ccHave == 0 {
                achs.append(Fmt.achieve("Joja Co. Member Of The Year", "", false) + "to become a Joja member and purchase all community development perks")
            } else if ccHave < ccCount {
                achs.append(Fmt.achieve("Joja Co. Member Of The Year", "", false) + "to become a Joja member and purchase any remaining community development perks (\(hybridLeft) left)")
            } else {
                achs.append(Fmt.achieveImpossible("Joja Co. Member Of The Year", "become a Joja member and purchase all community development perks"))
            }
            var temp = ""
            if !hasSeenCeremony {
                if ccHave < ccCount {
                    temp = "\(ccCount - ccHave) more room(s) and the ceremony"
                    for (_, r) in ccMail where !done.contains(r) {
                        var bundleNeed: [DetailItem] = []
                        if let room = bundleData[r] {
                            for (b, bundle) in room.bundles {
                                let have = bundleHave[b] ?? 0
                                if have < bundle.qty {
                                    var line = RichText("\(bundle.name) Bundle -- need \(bundle.qty - have) of: ")
                                    var first = true
                                    for (i, item) in bundle.items.enumerated() where !(itemsHave[b]?.contains(i) ?? false) {
                                        if !first { line += ", " }
                                        line += item
                                        first = false
                                    }
                                    bundleNeed.append(DetailItem(line))
                                }
                            }
                            need.append(DetailItem(" ".rt + wikify(room.name, "Bundles"), children: Checkup.sortedItems(bundleNeed), ordered: true))
                        }
                    }
                } else {
                    temp = " to attend the ceremony"
                }
                need.append(DetailItem("Attend the re-opening ceremony at the Community Center"))
            }
            achs.append(((ccHave >= ccCount && hasSeenCeremony) ? Fmt.achieve("Local Legend", "", true) : Fmt.achieve("Local Legend", "", false) + temp).progress(ccHave, ccCount, label: "\(ccHave) / \(ccCount) rooms"))
        }
        cell.summary.append(.achList(achs))
        if !need.isEmpty {
            section.hasDetails = true
            cell.details.append(.need(RichText("Left to do:"), Checkup.sortedItems(need), ordered: true))
        }
        section.globalCells = [cell]
        return section
    }

    // MARK: Forest Neighbors (1.6)

    func parseRaccoons() -> Section? {
        let version = "1.6"
        if info.isBefore(version) { return nil }
        var section = Section(title: "Forest Neighbors", version: version)
        let host = info.host
        let timesFed = num(doc.text("SaveGame > timesFedRaccoons"))
        let lastFed = num(doc.text("SaveGame > daysPlayedWhenLastRaccoonBundleWasFinished"))
        let daysSinceFed = host.stat("daysPlayed") - lastFed
        let intro: String
        if host.hasMail("raccoonMovedIn") {
            intro = "Mr. Raccoon has moved into the refurbished stump in the forest."
        } else if host.hasMail("raccoonTreeFallen") {
            intro = "The big tree in the forest has fallen and repairs may be needed."
        } else if host.hasMail("ccPantry") || host.hasMail("jojaPantry") {
            intro = "The Greenhouse has been repaired. Where did that raccoon go?"
        } else {
            intro = "The Greenhouse has not yet been repaired."
        }
        var cell = Cell()
        cell.summary.append(.result(RichText(intro)))
        var helped = "The neighbors have been helped \(timesFed) times"
        if lastFed > 0 { helped += " (most recently \(daysSinceFed) days ago)" }
        cell.summary.append(.result(RichText(helped + ".")))
        let ach: StatusLine
        // patch 1.6.4 changed achievement trigger from 7 to 8 babies which means 8 to 9 timesFed
        if timesFed > 9 || (timesFed == 9 && daysSinceFed > 7) {
            ach = Fmt.achieve("Good Neighbors", "help your forest neighbors grow their family", true)
        } else if timesFed == 9 && daysSinceFed <= 7 {
            ach = Fmt.achieve("Good Neighbors", "help your forest neighbors grow their family", false) + "to wait a few more days"
        } else {
            ach = Fmt.achieve("Good Neighbors", "help your forest neighbors grow their family", false) + "to help \(9 - timesFed) more times"
        }
        cell.summary.append(.achList([ach.progress(min(timesFed, 9), 9)]))
        section.globalCells = [cell]
        return section
    }
}
