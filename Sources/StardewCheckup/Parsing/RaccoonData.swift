import Foundation

/// One item the forest neighbors ask for. `preserveOf` is the base item for a
/// flavoured product (the fish in Smoked Fish, the fruit in a Jelly).
struct RaccoonWant {
    let itemId: String
    let count: Int
    let preserveOf: String?

    var name: String {
        let base = preserveOf.map { RaccoonData.itemName($0) } ?? ""
        switch itemId {
        case "SmokedFish": return "Smoked \(base)"
        case "DriedFruit": return "Dried \(base)"
        case "DriedMushroom": return "Dried \(base)"
        case "Jelly": return "\(base) Jelly"
        case "Juice": return "\(base) Juice"
        case "Pickle": return "Pickled \(base)"
        case "-5": return "Any Egg"
        default: return RaccoonData.itemName(itemId)
        }
    }

    /// How many of the base item one product takes, for flavoured products.
    var baseNeeded: Int { itemId == "DriedFruit" || itemId == "DriedMushroom" ? 5 : 1 }

    /// How to make it, for flavoured products.
    var recipe: String? {
        guard let base = preserveOf.map({ RaccoonData.itemName($0) }) else { return nil }
        switch itemId {
        case "SmokedFish": return "1 \(base) and 1 Coal in a Fish Smoker"
        case "DriedFruit", "DriedMushroom": return "5 \(base) in a Dehydrator"
        case "Jelly", "Pickle": return "1 \(base) in a Preserves Jar"
        case "Juice": return "1 \(base) in a Keg"
        default: return nil
        }
    }
}

/// Port of `StardewValley.Characters.Raccoon.GetBundle` / `AddNextIngredient` (1.6):
/// the requests are seeded from the game id and how many times the raccoons were helped.
enum RaccoonData {
    static func itemName(_ id: String) -> String { ObjectData.objects[id] ?? id }

    /// Where to find an item (or the base of a flavoured one).
    static func whereToGet(_ id: String) -> String? {
        if let hint = hints[id] { return hint }
        let name = itemName(id)
        if let fish = FishData.all.first(where: { $0.name == name }) {
            let seasons = fish.seasons.count == 4 ? "any season" : fish.seasons.joined(separator: ", ")
            return "\(fish.location), \(seasons)" + (fish.time == "Anytime" ? "" : ", \(fish.time)") + (fish.weather == .any ? "" : ", \(fish.weather.rawValue.lowercased())")
        }
        if let crop = CropData.all.first(where: { $0.name == name }) {
            return "Grow \(crop.seed) (\(crop.seasons.joined(separator: ", ")), \(crop.days) days): \(crop.source)"
        }
        return nil
    }

    private static let hints: [String: String] = [
        "-5": "Chickens or ducks; any egg counts",
        "78": "Till the dirt or break crates and barrels in the Mines",
        "157": "Fishing in the Mines (floors 20, 60, 100) or the Sewers",
        "Moss": "Grows on older trees; scrape it off with a scythe",
        "110": "Artifact spots in town, fishing treasure chests",
        "168": "Fishing, crab pots and garbage cans",
        "766": "Dropped by slimes (Mines, Slime Hutch)",
        "767": "Dropped by bats (Mines floor 31 and down, Skull Cavern)",
        "535": "Rocks and geode nodes on Mines floors 1-39",
        "536": "Rocks and geode nodes on Mines floors 40-79",
        "537": "Rocks and geode nodes on Mines floors 80-119",
        "393": "Forage on the beach",
        "397": "Forage at the tide pools east of the beach (repair the bridge first)",
        "684": "Dropped by grubs, flies and bugs in the Mines",
        "72": "Diamond nodes (Mines floor 50 and down), geodes, Skull Cavern",
        "68": "Topaz nodes on Mines floors 1-39, geodes",
        "90": "Forage in the Calico Desert, or grow Cactus Seeds indoors",
        "634": "Apricot tree (sapling from Pierre's)",
        "638": "Cherry tree (sapling from Pierre's)",
        "635": "Orange tree (sapling from Pierre's)",
        "636": "Peach tree (sapling from Pierre's)",
        "613": "Apple tree (sapling from Pierre's)",
        "637": "Pomegranate tree (sapling from Pierre's)",
        "88": "Calico Desert forage, the Oasis shop, or Ginger Island palm trees",
        "396": "Summer forage",
        "410": "Fall forage (bushes, best on Fall 8-11)",
        "406": "Fall forage",
        "414": "Winter forage",
        "422": "Mines floors 81-119, Skull Cavern, or your farm cave's mushroom boxes",
        "404": "Fall forage, the Secret Woods, or your farm cave's mushroom boxes",
        "257": "Spring forage in the Secret Woods, or your farm cave's mushroom boxes",
        "281": "Fall forage in the Secret Woods, or your farm cave's mushroom boxes",
        "16": "Spring forage",
        "22": "Spring forage",
        "416": "Winter: till the ground or dig artifact spots; Winter Seeds",
        "412": "Winter: till the ground or dig artifact spots; Winter Seeds",
    ]

    private static let shellfish = ["722", "721", "716", "719", "723", "718", "372"]
    private static let smokedFish = [
        ["136", "132", "700", "702", "156", "267", "706"],
        ["136", "132", "700", "702", "156", "267", "706", "138", "701", "146", "130"],
        ["136", "132", "700", "702", "156", "701", "269", "139", "139"],
        ["136", "132", "700", "702", "156", "146", "130", "141", "269"],
    ]
    private static let fruit = [
        ["90", "634", "638", "400", "88"],
        ["90", "258", "260", "635", "636", "88", "396"],
        ["90", "613", "282", "637", "410", "88", "406"],
        ["90", "414", "414", "88", "Powdermelon", "Powdermelon"],
    ]
    private static let mushrooms = [["422", "404", "257"], ["422", "404"], ["422", "404", "281"], ["422", "404"]]
    private static let vegetables = [
        ["190", "188", "250", "192", "16", "22", "Carrot", "Carrot"],
        ["270", "264", "256", "78", "SummerSquash", "SummerSquash"],
        ["Broccoli", "Broccoli", "278", "272", "276"],
        ["416", "412", "78"],
    ]
    private static let misc = ["Moss_10", "110_1", "168_5", "766_99", "767_20", "535_8", "536_5", "537_3",
                               "393_4", "397_2", "684_20", "72_1", "68_3", "156_3"]

    /// Whether the request type picks from a per-season list.
    static func isSeasonal(_ kind: Int) -> Bool { kind != 4 }

    /// The request type (0 shellfish, 1 fruit, 2 mushrooms, 3 vegetables, 4 odds and ends)
    /// and its two items for the given helping count and season index (0 spring … 3 winter).
    static func request(gameId: UInt64, timesFed: Int, season: Int) -> (kind: Int, wants: [RaccoonWant]) {
        var random = NetRandom(seed: seed(Double(gameId), Double(timesFed * 377)))
        for _ in 0..<10 { _ = random.next() }
        let kind = timesFed < 5 ? timesFed % 5 : random.next(5)
        let s = max(0, min(3, season))
        func pick(_ list: [String]) -> String { list[random.next(list.count)] }
        func pickOther(_ list: [String], than first: String, key: (String) -> String = { $0 }) -> String {
            var other = ""
            while other.isEmpty || key(other) == key(first) { other = pick(list) }
            return other
        }
        switch kind {
        case 0:
            let a = pick(shellfish)
            return (kind, [RaccoonWant(itemId: a, count: 5, preserveOf: nil),
                           RaccoonWant(itemId: "SmokedFish", count: 1, preserveOf: pick(smokedFish[s]))])
        case 1:
            let a = pick(fruit[s])
            return (kind, [RaccoonWant(itemId: "DriedFruit", count: 1, preserveOf: a),
                           RaccoonWant(itemId: "Jelly", count: 1, preserveOf: pickOther(fruit[s], than: a))])
        case 2:
            let a = pick(mushrooms[s])
            return (kind, [RaccoonWant(itemId: "DriedMushroom", count: 1, preserveOf: a),
                           RaccoonWant(itemId: pick(["-5", "78", "157"]), count: 5, preserveOf: nil)])
        case 3:
            let a = pick(vegetables[s])
            return (kind, [RaccoonWant(itemId: "Juice", count: 1, preserveOf: a),
                           RaccoonWant(itemId: "Pickle", count: 1, preserveOf: pickOther(vegetables[s], than: a))])
        default:
            let a = pick(misc)
            let b = pickOther(misc, than: a) { String($0.split(separator: "_")[0]) }
            func want(_ s: String) -> RaccoonWant {
                let parts = s.split(separator: "_")
                return RaccoonWant(itemId: String(parts[0]), count: Int(parts[1]) ?? 1, preserveOf: nil)
            }
            return (kind, [want(a), want(b)])
        }
    }

    /// `Utility.CreateRandomSeed` (non-legacy): xxHash32 of the five seeds as int32s.
    static func seed(_ values: Double...) -> Int32 {
        var bytes: [UInt8] = []
        for i in 0..<5 {
            let v = i < values.count ? values[i] : 0
            let n = Int32(truncatingIfNeeded: Int64(v.truncatingRemainder(dividingBy: 2147483647.0)))
            withUnsafeBytes(of: n.littleEndian) { bytes.append(contentsOf: $0) }
        }
        return Int32(bitPattern: xxHash32(bytes))
    }

    static func xxHash32(_ b: [UInt8], seed: UInt32 = 0) -> UInt32 {
        let p1: UInt32 = 2654435761, p2: UInt32 = 2246822519, p3: UInt32 = 3266489917, p4: UInt32 = 668265263, p5: UInt32 = 374761393
        func rotl(_ x: UInt32, _ r: UInt32) -> UInt32 { (x << r) | (x >> (32 - r)) }
        func word(_ i: Int) -> UInt32 { UInt32(b[i]) | UInt32(b[i + 1]) << 8 | UInt32(b[i + 2]) << 16 | UInt32(b[i + 3]) << 24 }
        var i = 0
        var h: UInt32
        if b.count >= 16 {
            var v = [seed &+ p1 &+ p2, seed &+ p2, seed, seed &- p1]
            while i + 16 <= b.count {
                for k in 0..<4 { v[k] = rotl(v[k] &+ word(i) &* p2, 13) &* p1; i += 4 }
            }
            h = rotl(v[0], 1) &+ rotl(v[1], 7) &+ rotl(v[2], 12) &+ rotl(v[3], 18)
        } else {
            h = seed &+ p5
        }
        h = h &+ UInt32(b.count)
        while i + 4 <= b.count { h = rotl(h &+ word(i) &* p3, 17) &* p4; i += 4 }
        while i < b.count { h = rotl(h &+ UInt32(b[i]) &* p5, 11) &* p1; i += 1 }
        h ^= h >> 15; h = h &* p2; h ^= h >> 13; h = h &* p3; h ^= h >> 16
        return h
    }
}

/// .NET's seeded `System.Random` (the Knuth subtractive generator).
struct NetRandom {
    private static let mbig: Int32 = .max
    private var seeds = [Int32](repeating: 0, count: 56)
    private var inext = 0, inextp = 21

    init(seed: Int32) {
        let subtraction = seed == .min ? Int32.max : abs(seed)
        var mj = 161803398 - subtraction
        seeds[55] = mj
        var mk: Int32 = 1
        for i in 1..<55 {
            let ii = (21 * i) % 55
            seeds[ii] = mk
            mk = mj &- mk
            if mk < 0 { mk &+= Self.mbig }
            mj = seeds[ii]
        }
        for _ in 1..<5 {
            for i in 1..<56 {
                seeds[i] &-= seeds[1 + (i + 30) % 55]
                if seeds[i] < 0 { seeds[i] &+= Self.mbig }
            }
        }
    }

    mutating func next() -> Int {
        var i = inext + 1, j = inextp + 1
        if i >= 56 { i = 1 }
        if j >= 56 { j = 1 }
        var r = seeds[i] &- seeds[j]
        if r == Self.mbig { r -= 1 }
        if r < 0 { r &+= Self.mbig }
        seeds[i] = r
        inext = i; inextp = j
        return Int(r)
    }

    mutating func next(_ max: Int) -> Int { Int(Double(next()) * (1.0 / Double(Self.mbig)) * Double(max)) }
}
