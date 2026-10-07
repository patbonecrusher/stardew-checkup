import Foundation

/// Fish reference data (location, time, season, weather, difficulty) from the
/// stardewvalleywiki.com Fish page, October 2026.
struct FishInfo: Identifiable {
    enum Weather: String { case any = "Any", sun = "Sun", rain = "Rain" }
    let name: String
    let location: String
    let time: String
    let seasons: [String]
    let note: String
    let weather: Weather
    let difficulty: Int
    let behavior: String
    let minLevel: Int
    let legendary: Bool
    let crabPot: Bool
    var id: String { name }
    var allSeasons: Bool { seasons.count == 4 }
}

enum FishData {
    static let all: [FishInfo] = [
        FishInfo(name: "Pufferfish", location: "Ocean, Ginger Island Oceans", time: "12pm – 4pm", seasons: ["Summer"], note: "All Seasons on Ginger Island", weather: .sun, difficulty: 80, behavior: "floater", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Anchovy", location: "Ocean", time: "Anytime", seasons: ["Spring", "Fall"], note: "", weather: .any, difficulty: 30, behavior: "dart", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Tuna", location: "Ocean, Ginger Island Oceans", time: "6am – 7pm", seasons: ["Summer", "Winter"], note: "All Seasons on Ginger Island", weather: .any, difficulty: 70, behavior: "smooth", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Sardine", location: "Ocean", time: "6am – 7pm", seasons: ["Spring", "Fall", "Winter"], note: "", weather: .any, difficulty: 30, behavior: "dart", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Bream", location: "Town River, Forest River", time: "6pm – 2am", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 35, behavior: "smooth", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Largemouth Bass", location: "Mountain Lake", time: "6am – 7pm", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 50, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Smallmouth Bass", location: "Town River, Forest Pond", time: "Anytime", seasons: ["Spring", "Fall"], note: "", weather: .any, difficulty: 28, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Rainbow Trout", location: "Town River, Forest River, Mountain Lake", time: "6am – 7pm", seasons: ["Summer"], note: "", weather: .sun, difficulty: 45, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Salmon", location: "Town River, Forest River, Forest Waterfalls", time: "6am – 7pm", seasons: ["Fall"], note: "", weather: .any, difficulty: 50, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Walleye", location: "Town River, Forest River, Forest Pond, Mountain Lake", time: "12pm – 2am", seasons: ["Fall", "Winter"], note: "Winter with Rain Totem", weather: .rain, difficulty: 45, behavior: "smooth", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Perch", location: "Town River, Forest River, Forest Pond, Mountain Lake", time: "Anytime", seasons: ["Winter"], note: "", weather: .any, difficulty: 35, behavior: "dart", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Carp", location: "Mountain Lake, Secret Woods, Sewers, Mutant Bug Lair", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 15, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Catfish", location: "Town River, Forest River, Secret Woods, Witch's Swamp", time: "6am – 12am", seasons: ["Spring", "Fall"], note: "Spring & Summer in Secret Woods Pond; Winter with Rain Totem", weather: .rain, difficulty: 75, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Pike", location: "Town River, Forest River, Forest Pond", time: "Anytime", seasons: ["Summer", "Winter"], note: "", weather: .any, difficulty: 60, behavior: "dart", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Sunfish", location: "Town River, Forest River", time: "6am – 7pm", seasons: ["Spring", "Summer"], note: "", weather: .sun, difficulty: 30, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Red Mullet", location: "Ocean", time: "6am – 7pm", seasons: ["Summer", "Winter"], note: "", weather: .any, difficulty: 55, behavior: "smooth", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Herring", location: "Ocean", time: "Anytime", seasons: ["Spring", "Winter"], note: "", weather: .any, difficulty: 25, behavior: "dart", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Eel", location: "Ocean", time: "4pm – 2am", seasons: ["Spring", "Fall"], note: "", weather: .rain, difficulty: 70, behavior: "smooth", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Octopus", location: "Ocean, Ginger Island Oceans", time: "6am – 1pm", seasons: ["Summer"], note: "All Seasons on Ginger Island", weather: .any, difficulty: 95, behavior: "sinker", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Red Snapper", location: "Ocean", time: "6am – 7pm", seasons: ["Summer", "Fall", "Winter"], note: "Winter with Rain Totem", weather: .rain, difficulty: 40, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Squid", location: "Ocean", time: "6pm – 2am", seasons: ["Winter"], note: "", weather: .any, difficulty: 75, behavior: "sinker", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Sea Cucumber", location: "Ocean", time: "6am – 7pm", seasons: ["Fall", "Winter"], note: "", weather: .any, difficulty: 40, behavior: "sinker", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Super Cucumber", location: "Ocean, Ginger Island Oceans", time: "6pm – 2am", seasons: ["Summer", "Fall"], note: "All Seasons on Ginger Island", weather: .any, difficulty: 80, behavior: "sinker", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Ghostfish", location: "Mines (Floors 20 & 60), Ghost Drops", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 50, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Stonefish", location: "Mines (Floor 20)", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 65, behavior: "sinker", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Ice Pip", location: "Mines (Floor 60)", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 85, behavior: "dart", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Lava Eel", location: "Mines (Floor 100), Volcano Caldera", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 90, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Sandfish", location: "Desert", time: "6am – 8pm", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 65, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Scorpion Carp", location: "Desert", time: "6am – 8pm", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 90, behavior: "dart", minLevel: 4, legendary: false, crabPot: false),
        FishInfo(name: "Flounder", location: "Ocean, Ginger Island Oceans", time: "6am – 8pm", seasons: ["Spring", "Summer"], note: "All Seasons on Ginger Island", weather: .any, difficulty: 50, behavior: "sinker", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Midnight Carp", location: "Forest Pond, Mountain Lake, Ginger Island Rivers", time: "10pm – 2am", seasons: ["Fall", "Winter"], note: "All Seasons on Ginger Island", weather: .any, difficulty: 55, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Sturgeon", location: "Mountain Lake", time: "6am – 7pm", seasons: ["Summer", "Winter"], note: "", weather: .any, difficulty: 78, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Tiger Trout", location: "Town River, Forest River", time: "6am – 7pm", seasons: ["Fall", "Winter"], note: "", weather: .any, difficulty: 60, behavior: "dart", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Bullhead", location: "Mountain Lake", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 46, behavior: "smooth", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Tilapia", location: "Ocean, Ginger Island Rivers", time: "6am – 2pm", seasons: ["Summer", "Fall"], note: "All Seasons on Ginger Island", weather: .any, difficulty: 50, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Chub", location: "Forest River, Mountain Lake", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 35, behavior: "dart", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Dorado", location: "Forest River", time: "6am – 7pm", seasons: ["Summer"], note: "", weather: .any, difficulty: 78, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Albacore", location: "Ocean", time: "6am – 11am 6pm – 2am", seasons: ["Fall", "Winter"], note: "", weather: .any, difficulty: 60, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Shad", location: "Town River, Forest River", time: "9am – 2am", seasons: ["Spring", "Summer", "Fall"], note: "", weather: .rain, difficulty: 45, behavior: "smooth", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Lingcod", location: "Town River, Forest River, Mountain Lake", time: "Anytimetime", seasons: ["Winter"], note: "", weather: .any, difficulty: 85, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Halibut", location: "Ocean", time: "6am – 11am 7pm – 2am", seasons: ["Spring", "Summer", "Winter"], note: "", weather: .any, difficulty: 50, behavior: "sinker", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Woodskip", location: "Secret Woods, Forest Farm", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 50, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Void Salmon", location: "Witch's Swamp", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 80, behavior: "mixed", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Slimejack", location: "Mutant Bug Lair", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 55, behavior: "dart", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Stingray", location: "Pirate Cove (Ginger Island)", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 80, behavior: "sinker", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Lionfish", location: "Ginger Island Oceans", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 50, behavior: "smooth", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Blue Discus", location: "Ginger Island Rivers", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 60, behavior: "dart", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Goby", location: "Forest Waterfalls", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 55, behavior: "dart", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Midnight Squid", location: "Night Market submarine", time: "5pm – 2am", seasons: ["Winter"], note: "Night Market, days 15–17", weather: .any, difficulty: 55, behavior: "sinker", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Spook Fish", location: "Night Market submarine", time: "5pm – 2am", seasons: ["Winter"], note: "Night Market, days 15–17", weather: .any, difficulty: 60, behavior: "dart", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Blobfish", location: "Night Market submarine", time: "5pm – 2am", seasons: ["Winter"], note: "Night Market, days 15–17", weather: .any, difficulty: 75, behavior: "floater", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Crimsonfish", location: "East Pier on The Beach", time: "Anytime", seasons: ["Summer"], note: "", weather: .any, difficulty: 95, behavior: "mixed", minLevel: 5, legendary: true, crabPot: false),
        FishInfo(name: "Angler", location: "Near the waterfall north of JojaMart", time: "Anytime", seasons: ["Fall"], note: "", weather: .any, difficulty: 85, behavior: "smooth", minLevel: 3, legendary: true, crabPot: false),
        FishInfo(name: "Legend", location: "The Mountain Lake near the log", time: "Anytime", seasons: ["Spring"], note: "", weather: .rain, difficulty: 110, behavior: "mixed", minLevel: 10, legendary: true, crabPot: false),
        FishInfo(name: "Glacierfish", location: "South end of Arrowhead Island in Cindersap Forest", time: "Anytime", seasons: ["Winter"], note: "", weather: .any, difficulty: 100, behavior: "mixed", minLevel: 6, legendary: true, crabPot: false),
        FishInfo(name: "Mutant Carp", location: "The Sewers", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 80, behavior: "dart", minLevel: 0, legendary: true, crabPot: false),
        FishInfo(name: "Son of Crimsonfish", location: "East Pier on The Beach", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "Qi's Extended Family quest", weather: .any, difficulty: 95, behavior: "mixed", minLevel: 5, legendary: false, crabPot: false),
        FishInfo(name: "Ms. Angler", location: "Near the waterfall north of JojaMart", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "Qi's Extended Family quest", weather: .any, difficulty: 85, behavior: "smooth", minLevel: 3, legendary: false, crabPot: false),
        FishInfo(name: "Legend II", location: "The Mountain Lake near the log", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "Qi's Extended Family quest", weather: .any, difficulty: 110, behavior: "mixed", minLevel: 10, legendary: false, crabPot: false),
        FishInfo(name: "Glacierfish Jr.", location: "South end of Arrowhead Island in Cindersap Forest", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "Qi's Extended Family quest", weather: .any, difficulty: 100, behavior: "mixed", minLevel: 6, legendary: false, crabPot: false),
        FishInfo(name: "Radioactive Carp", location: "The Sewers", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "Qi's Extended Family quest", weather: .any, difficulty: 80, behavior: "dart", minLevel: 0, legendary: false, crabPot: false),
        FishInfo(name: "Lobster", location: "Ocean (crab pot)", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 0, behavior: "", minLevel: 0, legendary: false, crabPot: true),
        FishInfo(name: "Crayfish", location: "Freshwater (crab pot)", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 0, behavior: "", minLevel: 0, legendary: false, crabPot: true),
        FishInfo(name: "Crab", location: "Ocean (crab pot)", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 0, behavior: "", minLevel: 0, legendary: false, crabPot: true),
        FishInfo(name: "Cockle", location: "Ocean (crab pot)", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 0, behavior: "", minLevel: 0, legendary: false, crabPot: true),
        FishInfo(name: "Mussel", location: "Ocean (crab pot)", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 0, behavior: "", minLevel: 0, legendary: false, crabPot: true),
        FishInfo(name: "Shrimp", location: "Ocean (crab pot)", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 0, behavior: "", minLevel: 0, legendary: false, crabPot: true),
        FishInfo(name: "Snail", location: "Freshwater (crab pot)", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 0, behavior: "", minLevel: 0, legendary: false, crabPot: true),
        FishInfo(name: "Periwinkle", location: "Freshwater (crab pot)", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 0, behavior: "", minLevel: 0, legendary: false, crabPot: true),
        FishInfo(name: "Oyster", location: "Ocean (crab pot)", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 0, behavior: "", minLevel: 0, legendary: false, crabPot: true),
        FishInfo(name: "Clam", location: "Ocean (crab pot)", time: "Anytime", seasons: ["Spring", "Summer", "Fall", "Winter"], note: "", weather: .any, difficulty: 0, behavior: "", minLevel: 0, legendary: false, crabPot: true),
    ]
}
