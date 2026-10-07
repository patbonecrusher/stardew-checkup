import Foundation

/// Where books and special items come from. Facts compiled from the Stardew Valley
/// Wiki (Books, Special Items & Powers, Mastery Cave pages), October 2026; wording is our own.
enum ItemSourceData {
    struct Entry: Identifiable {
        let name: String        // display name used by the checkup
        let wikiPage: String
        let effect: String
        let source: String
        var id: String { name }
        var url: URL? { wikify(wikiPage).runs.first?.url }
    }

    static let books: [Entry] = [
        Entry(name: "Price Catalogue", wikiPage: "Price Catalogue", effect: "You can now see the value of your items.", source: "Bookseller, 3,000g."),
        Entry(name: "Mapping Cave Systems", wikiPage: "Mapping Cave Systems", effect: "You get a 50% discount on Marlon's item retrieval service.", source: "In a box at the back of the Adventurer's Guild; the back room opens once you have 1,000 monster kills. Also sold by the Bookseller for 20,000g from year 3."),
        Entry(name: "Way Of The Wind pt. 1", wikiPage: "Way Of The Wind pt. 1", effect: "You run a little bit faster.", source: "Bookseller, 15,000g."),
        Entry(name: "Way Of The Wind pt. 2", wikiPage: "Way Of The Wind pt. 2", effect: "You run a little bit faster.", source: "Bookseller, 35,000g, only after you have read pt. 1."),
        Entry(name: "Monster Compendium", wikiPage: "Monster Compendium", effect: "Monsters have a small chance to drop double loot.", source: "Rare monster drop. Also sold by the Bookseller for 20,000g from year 3."),
        Entry(name: "Friendship 101", wikiPage: "Friendship 101", effect: "You become friends with people a little faster.", source: "Prize machine in Lewis' house. Also sold by the Bookseller for 20,000g from year 3."),
        Entry(name: "Jack Be Nimble, Jack Be Thick", wikiPage: "Jack Be Nimble, Jack Be Thick", effect: "Gain +1 Defense.", source: "Dig up artifact spots. Also sold by the Bookseller for 20,000g from year 3."),
        Entry(name: "Woody's Secret", wikiPage: "Woody's Secret", effect: "Felled trees have a 5% chance to yield double the wood.", source: "Chance when chopping trees. Also sold by the Bookseller for 20,000g from year 3."),
        Entry(name: "Raccoon Journal", wikiPage: "Raccoon Journal", effect: "Weeds have a greater chance to yield mixed seeds.", source: "Reward for the second raccoon request; traded at the Raccoon Wife's shop for 999 Fiber; or Bookseller for 20,000g from year 3."),
        Entry(name: "Jewels Of The Sea", wikiPage: "Jewels Of The Sea", effect: "Fishing treasure chests have a chance to yield roe.", source: "Fishing treasure chests. Also sold by the Bookseller for 20,000g from year 3."),
        Entry(name: "Dwarvish Safety Manual", wikiPage: "Dwarvish Safety Manual", effect: "Bombs deal 25% less damage to you.", source: "Dwarf's shop in the Mines, 4,000g. Also sold by the Bookseller for 20,000g from year 3."),
        Entry(name: "The Art O' Crabbing", wikiPage: "The Art O' Crabbing", effect: "Crab pots have a 25% chance to yield double.", source: "Iridium-tier reward at SquidFest (once). Also sold by the Bookseller for 20,000g from year 3."),
        Entry(name: "The Alleyway Buffet", wikiPage: "The Alleyway Buffet", effect: "You have a greater chance to find items in the trash.", source: "Gold trash can hidden behind the fence between the Blacksmith and JojaMart. Also sold by the Bookseller for 20,000g from year 3."),
        Entry(name: "The Diamond Hunter", wikiPage: "The Diamond Hunter", effect: "All stones have a chance to drop a diamond when mined by hand.", source: "Dwarf vendor inside the Volcano Dungeon, 10 Diamonds."),
        Entry(name: "Book of Mysteries", wikiPage: "Book of Mysteries", effect: "You have a slightly greater chance to find Mystery Boxes.", source: "Mystery Boxes and Golden Mystery Boxes."),
        Entry(name: "Horse: The Book", wikiPage: "Horse: The Book", effect: "You gain a little extra speed when riding a horse.", source: "Bookseller, 25,000g."),
        Entry(name: "Ancient Treasures: Appraisal Guide", wikiPage: "Treasure Appraisal Guide", effect: "You will fetch a better price when selling artifacts.", source: "Artifact Troves. Also sold by the Bookseller for 20,000g from year 3."),
        Entry(name: "Ol' Slitherlegs", wikiPage: "Ol' Slitherlegs", effect: "You will now run a lot faster through grass and crops.", source: "Bookseller, 25,000g."),
        Entry(name: "Animal Catalogue", wikiPage: "Animal Catalogue", effect: "You can access Marnie's shop when she's not around.", source: "Marnie's shop, 5,000g, from year 2."),
    ]

    static let powers: [Entry] = [
        Entry(name: "Bear's Knowledge", wikiPage: "Bear's Knowledge", effect: "Increases sell price of Blackberries and Salmonberries by 3x.", source: "Bring Maple Syrup to the bear in the Secret Woods after reading Secret Note #23."),
        Entry(name: "Qi Club Card", wikiPage: "Club Card", effect: "Used to enter the Casino .", source: "Finish the quest \"The Mysterious Qi\"."),
        Entry(name: "Dark Talisman", wikiPage: "Dark Talisman", effect: "Quest item", source: "Chest in the Mutant Bug Lair (Railroad quest line)."),
        Entry(name: "Dwarvish Translation Guide", wikiPage: "Dwarvish Translation Guide", effect: "Unlocks the ability to speak to the Dwarf in the Mines and the dwarf in the Volcano Dungeon .", source: "Museum reward for donating all four Dwarf Scrolls."),
        Entry(name: "Forest Magic", wikiPage: "Forest Magic", effect: "Unlocks the ability to read the language of the Junimos.", source: "Reward for the \"Meet The Wizard\" quest, which starts the morning after you read the golden scroll in the Community Center."),
        Entry(name: "Key to the Town", wikiPage: "Key To The Town", effect: "Allows access to all buildings in town, at any time of day (with some restrictions).", source: "Qi's Walnut Room, 20 Qi Gems."),
        Entry(name: "Magic Ink", wikiPage: "Magic Ink", effect: "Quest item", source: "On the table in the Witch's Hut (after returning the Dark Talisman)."),
        Entry(name: "Magnifying Glass", wikiPage: "Magnifying Glass", effect: "Unlocks the ability to find Secret Notes .", source: "Finish the \"A Winter Mystery\" quest (follow the shadowy figure)."),
        Entry(name: "Rusty Key", wikiPage: "Rusty Key", effect: "Used to enter the Sewers .", source: "Gunther hands it over the day after your 60th museum donation."),
        Entry(name: "Skull Key", wikiPage: "Skull Key", effect: "Unlocks the door to the Skull Cavern and unlocks the Junimo Kart machine in the Stardrop Saloon .", source: "Chest on floor 120 of the Mines."),
        Entry(name: "Special Charm", wikiPage: "Special Charm", effect: "Permanently increases daily luck .", source: "Give a Rabbit's Foot to the truck driver outside JojaMart (or the theater) after reading Secret Note #20."),
        Entry(name: "Spring Onion Mastery", wikiPage: "Spring Onion Mastery", effect: "Increases sell price of Spring Onions by 5x.", source: "Watch Jas and Vincent's 8-heart event."),
        Entry(name: "Farming Mastery Perk", wikiPage: "Mastery_Cave", effect: "Statue Of Blessings recipe; animals' products and crops have a chance to be iridium quality (Farming Mastery)", source: "Chosen at the pedestal in the Mastery Cave (the door south of the Adventurer's Guild opens once all five skills are level 10). Each perk costs mastery XP: 10,000 for the first, then 15,000, 20,000, 25,000 and 30,000 more."),
        Entry(name: "Fishing Mastery Perk", wikiPage: "Mastery_Cave", effect: "Advanced Iridium Rod; Challenge Bait recipe (Fishing Mastery)", source: "Chosen at the pedestal in the Mastery Cave (the door south of the Adventurer's Guild opens once all five skills are level 10). Each perk costs mastery XP: 10,000 for the first, then 15,000, 20,000, 25,000 and 30,000 more."),
        Entry(name: "Foraging Mastery Perk", wikiPage: "Mastery_Cave", effect: "Mystic Tree Seed and Treasure Totem recipes; trees have a chance to drop mystic syrup items (Foraging Mastery)", source: "Chosen at the pedestal in the Mastery Cave (the door south of the Adventurer's Guild opens once all five skills are level 10). Each perk costs mastery XP: 10,000 for the first, then 15,000, 20,000, 25,000 and 30,000 more."),
        Entry(name: "Mining Mastery Perk", wikiPage: "Mastery_Cave", effect: "Heavy Furnace recipe; gem nodes always drop double (Mining Mastery)", source: "Chosen at the pedestal in the Mastery Cave (the door south of the Adventurer's Guild opens once all five skills are level 10). Each perk costs mastery XP: 10,000 for the first, then 15,000, 20,000, 25,000 and 30,000 more."),
        Entry(name: "Combat Mastery Perk", wikiPage: "Mastery_Cave", effect: "Anvil and Mini-Forge recipes; a chance to recover health on monster kills (Combat Mastery)", source: "Chosen at the pedestal in the Mastery Cave (the door south of the Adventurer's Guild opens once all five skills are level 10). Each perk costs mastery XP: 10,000 for the first, then 15,000, 20,000, 25,000 and 30,000 more."),
    ]
}
