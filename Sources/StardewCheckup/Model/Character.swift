import Foundation

/// Static reference data for one villager (decoded from `CharacterData.json`).
struct CharacterInfo: Decodable, Identifiable {
    struct Birthday: Decodable { let season: String; let day: Int }
    struct Relative: Decodable, Identifiable { let name: String; let relation: String; var id: String { name } }
    struct GiftTier: Decodable { let items: [String]; let notes: [String] }
    struct Gifts: Decodable { let love, like, neutral, dislike, hate: GiftTier }
    struct ScheduleCondition: Decodable, Identifiable {
        let title: String
        let rows: [[String]]      // [time, where]
        var id: String { title + rows.map { $0.joined() }.joined() }
    }
    struct ScheduleGroup: Decodable, Identifiable {
        let title: String        // "Spring", "Summer", ..., "Marriage" or "All"
        let conditions: [ScheduleCondition]
        var id: String { title }
    }
    struct HeartEvent: Decodable, Identifiable {
        let title: String
        let hearts: Int?
        let isMail: Bool
        let isGroup: Bool
        /// Keys into the Social section's event table (e.g. "53|584059"); empty when untracked.
        let idKeys: [String]
        let trigger: String
        let anchor: String
        var id: String { title }
    }

    let name: String
    let role: String
    let birthday: Birthday
    let livesIn: String
    let address: String
    let family: [Relative]
    let marriage: String      // "yes", "no", "roommate"
    let clinic: String
    let gifts: Gifts
    let scheduleNotes: [String]
    let schedule: [ScheduleGroup]
    let heartEvents: [HeartEvent]

    var id: String { name }
    var isMarriageCandidate: Bool { marriage == "yes" }
    var wikiURL: URL? { wikify(name).runs.first?.url }
}

/// What the loaded save says about the host's relationship with one villager.
struct CharacterStatus {
    var name: String
    var isMet = false
    var hearts = 0
    var points = 0
    var maxHearts = 10
    var lockedFrom: Int? = nil
    var status = "Unmet"
    var isDatable = false
    var need = RichText()
    var giftsThisWeek = 0
    var talkedToday = false
    var birthdayGiftedThisYear = false
    /// Social-section event key → seen state.
    var eventStates: [String: MarkState] = [:]

    /// Seen / not seen / impossible for a wiki heart event; nil when the save does not track it.
    func state(of event: CharacterInfo.HeartEvent) -> MarkState? {
        guard !event.idKeys.isEmpty else { return nil }
        let states = event.idKeys.compactMap { eventStates[$0] }
        guard states.count == event.idKeys.count else { return nil }
        if states.allSatisfy({ $0 == .yes }) { return .yes }
        if states.contains(.imp) { return .imp }
        return .no
    }
}

/// Payload of the Characters section: today's context plus per-villager save status.
struct CharactersData {
    var season: String
    var day: Int
    var year: Int
    var weekday: String          // "Monday"...
    var isRaining = false
    var spouse: String? = nil
    var statuses: [String: CharacterStatus] = [:]
    /// Loved / liked items the host owns, per villager.
    var suggestions: [String: GiftSuggestions] = [:]

    func status(of name: String) -> CharacterStatus { statuses[name] ?? CharacterStatus(name: name) }
}

/// One item the host owns that a villager loves or likes.
struct GiftSuggestion: Identifiable {
    let name: String
    let count: Int
    let bestQuality: Int
    let places: String
    let inInventory: Bool
    let onlyOnGround: Bool
    let taste: GiftTaste
    var id: String { name }

    init(item: OwnedItem, taste: GiftTaste) {
        name = item.name
        count = item.count
        bestQuality = item.bestQuality
        places = item.placeSummary
        inInventory = item.places["Inventory"] != nil
        onlyOnGround = item.onlyOnGround
        self.taste = taste
    }

    /// Friendship points for the best copy you own: 80 loved / 45 liked, ×1.1 silver, ×1.25 gold,
    /// ×1.5 iridium, and ×8 on the villager's birthday.
    func points(birthday: Bool = false) -> Int {
        let base: Double = taste == .love ? 80 : 45
        let quality: Double = bestQuality >= 4 ? 1.5 : (bestQuality >= 2 ? 1.25 : (bestQuality >= 1 ? 1.1 : 1))
        return Int((base * quality * (birthday ? 8 : 1)).rounded(.down))
    }
}

struct GiftSuggestions {
    var loves: [GiftSuggestion] = []
    var likes: [GiftSuggestion] = []
    var isEmpty: Bool { loves.isEmpty && likes.isEmpty }
}

/// One villager in the weekly gift planner.
struct GiftPlanRow: Identifiable {
    let name: String
    var hearts = 0
    var maxHearts = 10
    var lockedFrom: Int? = nil
    var isMet = false
    var isMaxed = false
    var isSpouse = false
    var giftsThisWeek = 0
    var giftedToday = false
    var talkedToday = false
    /// Days until the villager's birthday (0 = today), when within the next week.
    var birthdayIn: Int? = nil
    var birthdayGifted = false
    var suggestions = GiftSuggestions()
    /// The villager's own loved items (not the universal ones), for when you own none.
    var lovedItems: [String] = []
    var id: String { name }
    /// Spouses take one gift a day; everyone else two a week (a birthday gift fits in the same limit).
    var slotsLeft: Int { isSpouse ? (giftedToday ? 0 : 1) : max(0, 2 - giftsThisWeek) }
}

struct GiftPlanData {
    var weekday: String
    var daysUntilReset: Int      // days until next Monday
    var rows: [GiftPlanRow] = []
    var ownedCount = 0
}

/// One thing to do towards a villager's heart events.
struct EventStep: Identifiable {
    enum Kind { case ready, locked, bouquet, marriage, impossible }
    let id = UUID()
    var kind: Kind
    var hearts: Int?
    var title: String
    var trigger: String
    var anchor: String
    /// For `.locked`: friendship still needed and roughly how many of your best gift that is.
    var pointsNeeded = 0
    var giftsNeeded = 0
    var bestGift: String? = nil
    var bestGiftPoints = 0
}

struct EventPlanRow: Identifiable {
    let name: String
    var hearts = 0
    var points = 0
    var maxHearts = 10
    var lockedFrom: Int? = nil
    var status = "Unmet"
    var isMet = false
    var isMarriageCandidate = false
    var steps: [EventStep] = []
    var seenCount = 0
    var totalTracked = 0
    var id: String { name }
    var readyCount: Int { steps.filter { $0.kind == .ready }.count }
    var isComplete: Bool { !steps.contains { $0.kind == .ready || $0.kind == .locked || $0.kind == .bouquet || $0.kind == .marriage } }
}

struct EventPlanData {
    var rows: [EventPlanRow] = []
    var spouse: String? = nil
}
