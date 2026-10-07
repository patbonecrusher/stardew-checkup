import Foundation

/// Experience reference data. Values taken from stardewvalleywiki.com
/// (Farming, Fishing, Fish, Crops, Foraging, Mining, Combat pages), October 2026.
enum XPData {
    struct Source {
        let name: String
        let detail: String
        let xp: Int
    }
    struct Crop {
        let name: String
        let price: Int
    }
    struct Fish {
        let name: String
        let difficulty: Int
        let legendary: Bool
    }

    /// One short note per skill, shown above the table.
    static let notes: [[String]] = [
        ["Harvest XP = round(16 × ln(0.018 × sell price + 1)); multi-produce crops (blueberry, cranberry, potato…) only give XP for the first item.",
         "Fruit trees, tea bushes and machine products give no Farming XP."],
        ["Fish XP = 3 × (quality + 1) + difficulty ÷ 3, truncated. Quality: normal 0, silver 1, gold 2, iridium 4.",
         "A perfect catch multiplies by 2.4 and a treasure chest by 2.2 (applied one after the other, truncating each time). Legendary fish are ×5."],
        ["Berry bushes, tappers and fruit trees give little or no XP; chopping trees and picking forage are the main sources."],
        ["Plain rocks inside the Mines give no XP unless they drop coal or ore. Geologist's double gem spawns halve the node XP (noted in the table)."],
        ["XP is awarded per kill. Monsters killed on the Farm give only one third of the listed amount."],
    ]

    static func cropXP(price: Int) -> Int {
        Int((16 * log(0.018 * Double(price) + 1)).rounded())
    }

    static func fishXP(difficulty: Int, quality: Int, perfect: Bool, legendary: Bool) -> Int {
        var xp = max(1, (quality + 1) * 3 + difficulty / 3)
        if perfect { xp = Int(Double(xp) * 2.4) }
        if legendary { xp *= 5 }
        return xp
    }

    static let crops: [Crop] = [
        Crop(name: "Blue Jazz", price: 50),
        Crop(name: "Carrot", price: 35),
        Crop(name: "Cauliflower", price: 175),
        Crop(name: "Coffee Bean", price: 15),
        Crop(name: "Garlic", price: 60),
        Crop(name: "Green Bean", price: 40),
        Crop(name: "Kale", price: 110),
        Crop(name: "Parsnip", price: 35),
        Crop(name: "Potato", price: 80),
        Crop(name: "Rhubarb", price: 220),
        Crop(name: "Strawberry", price: 120),
        Crop(name: "Tulip", price: 30),
        Crop(name: "Unmilled Rice", price: 30),
        Crop(name: "Blueberry", price: 50),
        Crop(name: "Corn", price: 50),
        Crop(name: "Hops", price: 25),
        Crop(name: "Hot Pepper", price: 40),
        Crop(name: "Melon", price: 250),
        Crop(name: "Poppy", price: 140),
        Crop(name: "Radish", price: 90),
        Crop(name: "Red Cabbage", price: 260),
        Crop(name: "Starfruit", price: 750),
        Crop(name: "Summer Spangle", price: 90),
        Crop(name: "Summer Squash", price: 45),
        Crop(name: "Sunflower", price: 80),
        Crop(name: "Tomato", price: 60),
        Crop(name: "Wheat", price: 25),
        Crop(name: "Amaranth", price: 150),
        Crop(name: "Artichoke", price: 160),
        Crop(name: "Beet", price: 100),
        Crop(name: "Bok Choy", price: 80),
        Crop(name: "Broccoli", price: 70),
        Crop(name: "Cranberries", price: 75),
        Crop(name: "Eggplant", price: 60),
        Crop(name: "Fairy Rose", price: 290),
        Crop(name: "Grape", price: 80),
        Crop(name: "Pumpkin", price: 320),
        Crop(name: "Yam", price: 160),
        Crop(name: "Powdermelon", price: 60),
        Crop(name: "Ancient Fruit", price: 550),
        Crop(name: "Cactus Fruit", price: 75),
        Crop(name: "Pineapple", price: 300),
        Crop(name: "Taro Root", price: 100),
        Crop(name: "Sweet Gem Berry", price: 3000),
        Crop(name: "Tea Leaves", price: 50),
        Crop(name: "Qi Fruit", price: 1),
    ]

    static let farmingOther: [Source] = [
        Source(name: "Milking a cow or goat", detail: "each", xp: 5),
        Source(name: "Shearing a sheep", detail: "each", xp: 5),
        Source(name: "Petting a farm animal", detail: "each, once a day", xp: 5),
        Source(name: "Picking up a coop product", detail: "egg, feather, foot, etc.", xp: 5),
        Source(name: "Wild Seeds plant", detail: "per plant (also 2 Foraging XP)", xp: 3),
        Source(name: "Stardew Valley Almanac / Book Of Stars", detail: "read once each", xp: 250),
    ]

    static let fish: [Fish] = [
        Fish(name: "Pufferfish", difficulty: 80, legendary: false),
        Fish(name: "Anchovy", difficulty: 30, legendary: false),
        Fish(name: "Tuna", difficulty: 70, legendary: false),
        Fish(name: "Sardine", difficulty: 30, legendary: false),
        Fish(name: "Bream", difficulty: 35, legendary: false),
        Fish(name: "Largemouth Bass", difficulty: 50, legendary: false),
        Fish(name: "Smallmouth Bass", difficulty: 28, legendary: false),
        Fish(name: "Rainbow Trout", difficulty: 45, legendary: false),
        Fish(name: "Salmon", difficulty: 50, legendary: false),
        Fish(name: "Walleye", difficulty: 45, legendary: false),
        Fish(name: "Perch", difficulty: 35, legendary: false),
        Fish(name: "Carp", difficulty: 15, legendary: false),
        Fish(name: "Catfish", difficulty: 75, legendary: false),
        Fish(name: "Pike", difficulty: 60, legendary: false),
        Fish(name: "Sunfish", difficulty: 30, legendary: false),
        Fish(name: "Red Mullet", difficulty: 55, legendary: false),
        Fish(name: "Herring", difficulty: 25, legendary: false),
        Fish(name: "Eel", difficulty: 70, legendary: false),
        Fish(name: "Octopus", difficulty: 95, legendary: false),
        Fish(name: "Red Snapper", difficulty: 40, legendary: false),
        Fish(name: "Squid", difficulty: 75, legendary: false),
        Fish(name: "Sea Cucumber", difficulty: 40, legendary: false),
        Fish(name: "Super Cucumber", difficulty: 80, legendary: false),
        Fish(name: "Ghostfish", difficulty: 50, legendary: false),
        Fish(name: "Stonefish", difficulty: 65, legendary: false),
        Fish(name: "Ice Pip", difficulty: 85, legendary: false),
        Fish(name: "Lava Eel", difficulty: 90, legendary: false),
        Fish(name: "Sandfish", difficulty: 65, legendary: false),
        Fish(name: "Scorpion Carp", difficulty: 90, legendary: false),
        Fish(name: "Flounder", difficulty: 50, legendary: false),
        Fish(name: "Midnight Carp", difficulty: 55, legendary: false),
        Fish(name: "Sturgeon", difficulty: 78, legendary: false),
        Fish(name: "Tiger Trout", difficulty: 60, legendary: false),
        Fish(name: "Bullhead", difficulty: 46, legendary: false),
        Fish(name: "Tilapia", difficulty: 50, legendary: false),
        Fish(name: "Chub", difficulty: 35, legendary: false),
        Fish(name: "Dorado", difficulty: 78, legendary: false),
        Fish(name: "Albacore", difficulty: 60, legendary: false),
        Fish(name: "Shad", difficulty: 45, legendary: false),
        Fish(name: "Lingcod", difficulty: 85, legendary: false),
        Fish(name: "Halibut", difficulty: 50, legendary: false),
        Fish(name: "Woodskip", difficulty: 50, legendary: false),
        Fish(name: "Void Salmon", difficulty: 80, legendary: false),
        Fish(name: "Slimejack", difficulty: 55, legendary: false),
        Fish(name: "Stingray", difficulty: 80, legendary: false),
        Fish(name: "Lionfish", difficulty: 50, legendary: false),
        Fish(name: "Blue Discus", difficulty: 60, legendary: false),
        Fish(name: "Goby", difficulty: 55, legendary: false),
        Fish(name: "Midnight Squid", difficulty: 55, legendary: false),
        Fish(name: "Spook Fish", difficulty: 60, legendary: false),
        Fish(name: "Blobfish", difficulty: 75, legendary: false),
        Fish(name: "Crimsonfish", difficulty: 95, legendary: true),
        Fish(name: "Angler", difficulty: 85, legendary: true),
        Fish(name: "Legend", difficulty: 110, legendary: true),
        Fish(name: "Glacierfish", difficulty: 100, legendary: true),
        Fish(name: "Mutant Carp", difficulty: 80, legendary: true),
        Fish(name: "Son of Crimsonfish", difficulty: 95, legendary: false),
        Fish(name: "Ms. Angler", difficulty: 85, legendary: false),
        Fish(name: "Legend II", difficulty: 110, legendary: false),
        Fish(name: "Glacierfish Jr.", difficulty: 100, legendary: false),
        Fish(name: "Radioactive Carp", difficulty: 80, legendary: false),
    ]

    static let fishingOther: [Source] = [
        Source(name: "Crab pot", detail: "per collection, any contents", xp: 5),
        Source(name: "Non-fish item", detail: "trash, algae, seaweed, etc.", xp: 3),
        Source(name: "Bait And Bobber / Book Of Stars", detail: "read once each", xp: 250),
    ]

    static let foraging: [Source] = [
        Source(name: "Large Stump or Large Log", detail: "hardwood, with an axe", xp: 25),
        Source(name: "Seed Spot / Artifact Spot", detail: "digging it up with a hoe", xp: 15),
        Source(name: "Large Green Rain weed", detail: "destroying it", xp: 15),
        Source(name: "Tree chopped down", detail: "fully grown, with an axe", xp: 14),
        Source(name: "Foraged item", detail: "picked up from the ground", xp: 7),
        Source(name: "Ginger", detail: "harvested on Ginger Island", xp: 7),
        Source(name: "Farm Cave fruit", detail: "fruit bats option", xp: 7),
        Source(name: "Panning", detail: "per item panned", xp: 7),
        Source(name: "Farm Cave mushroom", detail: "mushroom option", xp: 5),
        Source(name: "Spring Onion", detail: "Cindersap Forest in spring", xp: 3),
        Source(name: "Wild Seeds plant", detail: "per plant (also 3 Farming XP)", xp: 2),
        Source(name: "Tree stump", detail: "after chopping the tree", xp: 2),
        Source(name: "Twig", detail: "chopped", xp: 1),
        Source(name: "Moss", detail: "per piece harvested from a tree", xp: 1),
        Source(name: "Blackberry / Salmonberry", detail: "per berry shaken from a bush", xp: 1),
        Source(name: "Woodcutter's Weekly / Book Of Stars", detail: "read once each", xp: 250),
    ]

    static let mining: [Source] = [
        Source(name: "Iridium Node", detail: "Skull Cavern; farm quarry at level 10", xp: 50),
        Source(name: "Gold Node", detail: "Mines 80+, Skull Cavern", xp: 18),
        Source(name: "Iron Node", detail: "Mines 40–79, Skull Cavern", xp: 12),
        Source(name: "Copper Node", detail: "Mines 1+", xp: 5),
        Source(name: "Radioactive Node", detail: "dangerous Mines / Skull Cavern", xp: 18),
        Source(name: "Diamond Node", detail: "Mines 50+ (100 with multiple spawns)", xp: 150),
        Source(name: "Mystic Stone", detail: "Mines 100+, Skull Cavern, Volcano", xp: 150),
        Source(name: "Emerald Node", detail: "Mines 80+ (50 with multiple spawns)", xp: 80),
        Source(name: "Ruby Node", detail: "Mines 80+ (50 with multiple spawns)", xp: 80),
        Source(name: "Aquamarine Node", detail: "Mines 40+ (20 with multiple spawns)", xp: 40),
        Source(name: "Jade Node", detail: "Mines 40+ (20 with multiple spawns)", xp: 40),
        Source(name: "Amethyst Node", detail: "Mines 1+ (8 with multiple spawns)", xp: 16),
        Source(name: "Topaz Node", detail: "Mines 1+ (8 with multiple spawns)", xp: 16),
        Source(name: "Omni Geode Node", detail: "Mines, Skull Cavern", xp: 64),
        Source(name: "Magma Geode Node", detail: "Mines 80+, Skull Cavern", xp: 32),
        Source(name: "Frozen Geode Node", detail: "Mines 40–79", xp: 16),
        Source(name: "Geode Node", detail: "Mines 1–39", xp: 8),
        Source(name: "Calico Egg Node", detail: "Desert Festival", xp: 50),
        Source(name: "Cinder Shard Node", detail: "Volcano", xp: 12),
        Source(name: "Coal Node", detail: "Mines, Skull Cavern", xp: 10),
        Source(name: "Bone Node", detail: "Skull Cavern / Ginger Island", xp: 6),
        Source(name: "Clay Node", detail: "Ginger Island dig site", xp: 6),
        Source(name: "Mussel Node", detail: "Ginger Island beach", xp: 5),
        Source(name: "Rock in the Mines with coal/ore drop", detail: "no XP otherwise", xp: 5),
        Source(name: "Dark gray rock in the Mines", detail: "4 if coal drops", xp: 3),
        Source(name: "Any rock outside the Mines", detail: "1 or 6 if coal drops", xp: 1),
        Source(name: "Ore panned", detail: "per piece of copper/iron/gold/iridium", xp: 1),
        Source(name: "Mining Monthly / Book Of Stars", detail: "read once each", xp: 250),
    ]

    static let monsters: [Source] = [
        Source(name: "Green Slime", detail: "Mines 1–39, farm", xp: 3),
        Source(name: "Dust Sprite", detail: "Mines 40–79", xp: 2),
        Source(name: "Bat", detail: "Mines 1–39", xp: 3),
        Source(name: "Frost Bat", detail: "Mines 40–79", xp: 7),
        Source(name: "Lava Bat", detail: "Mines 80–120", xp: 15),
        Source(name: "Iridium Bat", detail: "Skull Cavern", xp: 22),
        Source(name: "Stone Golem", detail: "Mines 1–39", xp: 5),
        Source(name: "Wilderness Golem", detail: "Wilderness farm", xp: 5),
        Source(name: "Iridium Golem", detail: "Wilderness farm (level 10 combat)", xp: 15),
        Source(name: "Grub", detail: "Mines 1–39", xp: 2),
        Source(name: "Cave Fly", detail: "Mines 1–39", xp: 10),
        Source(name: "Frost Jelly", detail: "Mines 40–79", xp: 6),
        Source(name: "Sludge", detail: "Mines 80–120", xp: 10),
        Source(name: "Ghost", detail: "Mines 50–79", xp: 15),
        Source(name: "Carbon Ghost", detail: "Skull Cavern", xp: 20),
        Source(name: "Duggy", detail: "Mines 1–39", xp: 10),
        Source(name: "Rock Crab", detail: "Mines 1–39", xp: 4),
        Source(name: "Truffle Crab", detail: "Farm (Truffle)", xp: 4),
        Source(name: "Lava Crab", detail: "Mines 80–120", xp: 12),
        Source(name: "Iridium Crab", detail: "Skull Cavern", xp: 20),
        Source(name: "Squid Kid", detail: "Mines 80–120", xp: 15),
        Source(name: "Shadow Brute", detail: "Mines 80–120", xp: 15),
        Source(name: "Shadow Shaman", detail: "Mines 80–120", xp: 15),
        Source(name: "Skeleton", detail: "Mines 70–79", xp: 8),
        Source(name: "Metal Head", detail: "Mines 80–120", xp: 6),
        Source(name: "Bug", detail: "Mines 1–39", xp: 1),
        Source(name: "Mummy", detail: "Skull Cavern", xp: 20),
        Source(name: "Big Slime", detail: "Skull Cavern / Secret Woods", xp: 7),
        Source(name: "Serpent", detail: "Skull Cavern", xp: 20),
        Source(name: "Mutant Grub", detail: "Mutant Bug Lair", xp: 6),
        Source(name: "Mutant Fly", detail: "Mutant Bug Lair", xp: 10),
        Source(name: "Pepper Rex", detail: "Skull Cavern", xp: 7),
        Source(name: "Haunted Skull", detail: "Quarry Mine", xp: 15),
        Source(name: "Tiger Slime", detail: "Ginger Island", xp: 20),
        Source(name: "Lava Lurk", detail: "Volcano", xp: 12),
        Source(name: "Hot Head", detail: "Volcano", xp: 16),
        Source(name: "Magma Sprite", detail: "Volcano", xp: 15),
        Source(name: "Magma Duggy", detail: "Volcano", xp: 18),
        Source(name: "Magma Sparker", detail: "Volcano", xp: 17),
        Source(name: "False Magma Cap", detail: "Volcano", xp: 14),
        Source(name: "Dwarvish Sentry", detail: "Volcano", xp: 15),
        Source(name: "Putrid Ghost", detail: "Dangerous mines", xp: 25),
        Source(name: "Shadow Sniper", detail: "Dangerous mines", xp: 20),
        Source(name: "Spider", detail: "Dangerous mines", xp: 15),
        Source(name: "Stick Bug", detail: "Dangerous mines", xp: 4),
        Source(name: "Royal Serpent", detail: "Dangerous Skull Cavern", xp: 20),
        Source(name: "Blue Squid", detail: "Dangerous mines", xp: 15),
    ]
}
