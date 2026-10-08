import Foundation

/// Sidebar grouping of sections, keyed by section anchor.
enum SectionGroup: String, CaseIterable, Identifiable {
    case progress = "Progress"
    case social = "Home & Social"
    case collections = "Collections"
    case island = "Ginger Island"
    case completion = "Completion"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .progress: return "chart.line.uptrend.xyaxis"
        case .social: return "heart.fill"
        case .collections: return "books.vertical.fill"
        case .island: return "sun.max.fill"
        case .completion: return "star.circle.fill"
        case .other: return "gamecontroller.fill"
        }
    }

    static func group(for anchor: String) -> SectionGroup {
        switch anchor {
        case "Summary", "Money", "Skills", "Skill_Mastery", "Quests", "Special_Orders", "Monster_Hunting", "Stardrops":
            return .progress
        case "Home_and_Family", "Social", "Calendar", "Characters", "Animal_Summary", "Forest_Neighbors":
            return .social
        case "Cooking", "Crafting", "Fishing", "Basic_Shipping", "Crop_Shipping", "Museum_Collection",
             "Books__Special_Items___Powers", "Secret_Notes":
            return .collections
        case "Golden_Walnuts", "Island_Upgrades", "Journal_Scraps":
            return .island
        case "Community_Center___Joja_Community_Development", "Grandpa_s_Evaluation", "Perfection_Tracker":
            return .completion
        default:
            return .other
        }
    }

    static func symbol(for anchor: String) -> String {
        switch anchor {
        case "Summary": return "doc.text"
        case "Money": return "dollarsign.circle"
        case "Skills": return "figure.walk"
        case "Skill_Mastery": return "graduationcap"
        case "Quests": return "scroll"
        case "Special_Orders": return "tray.full"
        case "Monster_Hunting": return "bolt.shield"
        case "Stardrops": return "sparkle"
        case "Home_and_Family": return "house"
        case "Social": return "person.2"
        case "Calendar": return "calendar"
        case "Characters": return "person.text.rectangle"
        case "Animal_Summary": return "pawprint"
        case "Forest_Neighbors": return "leaf"
        case "Cooking": return "fork.knife"
        case "Crafting": return "hammer"
        case "Fishing": return "fish"
        case "Basic_Shipping": return "shippingbox"
        case "Crop_Shipping": return "carrot"
        case "Museum_Collection": return "building.columns"
        case "Books__Special_Items___Powers": return "book"
        case "Secret_Notes": return "note.text"
        case "Journal_Scraps": return "doc.plaintext"
        case "Golden_Walnuts": return "circle.hexagongrid"
        case "Island_Upgrades": return "wrench.and.screwdriver"
        case "Community_Center___Joja_Community_Development": return "building.2"
        case "Grandpa_s_Evaluation": return "flame"
        case "Perfection_Tracker": return "star"
        case "Arcade_Games": return "gamecontroller"
        default: return "circle"
        }
    }
}

/// Aggregate of a section's achievement/milestone rows for the sidebar badge.
struct SectionStatus {
    var done = 0
    var total = 0
    var impossible = 0

    var isComplete: Bool { total > 0 && done == total }
    /// Everything left is impossible: nothing more can be done.
    var isBlocked: Bool { total > 0 && done + impossible == total && impossible > 0 }
    var remaining: Int { total - done - impossible }

    init(section: Section) {
        func scan(_ cells: [Cell]) {
            for cell in cells {
                for block in cell.summary + cell.details {
                    guard case .achList(let lines) = block else { continue }
                    for line in lines where line.kind == .achievement || line.kind == .milestone {
                        total += 1
                        switch line.state {
                        case .yes: done += 1
                        case .impossible: impossible += 1
                        case .no: break
                        }
                    }
                }
            }
        }
        scan(section.globalCells)
        // For per-player sections count only the host column so fractions stay meaningful.
        if let first = section.columns.first { scan(first) }
        scan(section.trailingCells)
    }
}
