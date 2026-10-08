# Checkup for Stardew Valley (macOS)

A native SwiftUI macOS app that replicates the logic of MouseyPounds'
[Stardew Checkup](https://mouseypounds.github.io/stardew-checkup/) web app
(v5.0.5). It reads a Stardew Valley save file and reports progress on
achievements, Grandpa's evaluation, Community Center bundles, Ginger Island,
Perfection, social relationships and more, listing exactly what is still
missing.

Website: https://patbonecrusher.github.io/stardew-checkup/

## Install

```sh
brew install --cask patbonecrusher/tap/stardew-checkup
```

or download the notarized zip from the [releases page](https://github.com/patbonecrusher/stardew-checkup/releases).

## Build and run

Requires Xcode 15+ / Swift 5.9+ on macOS 14 or later. No Xcode project: it is a Swift
Package, and `build.sh` assembles the `.app` bundle (Info.plist, generated icon, signature).

```sh
swift run                 # run directly for development
./build.sh                # release build → "build/Checkup for Stardew Valley.app"
./build.sh --open         # …and launch it
```

Signed / notarized releases: see [RELEASING.md](RELEASING.md).

## Headless check

The same engine can print a plain-text report, which is handy for testing:

```sh
swift run StardewCheckup --dump ~/.config/StardewValley/Saves/Name_123456789/Name_123456789
```

## Notes

- The Overview page shows Perfection, achievements, Grandpa's candles, money
  and farmer level at a glance, progress tiles for each collection, and the
  goals closest to completion. Every tile links to its section.
- Social shows a heart meter per villager (bouquet-locked hearts are marked)
  and heart-event pills with hover details.
- Long "left to do" lists render as filterable grids.
- The Skills section includes an XP Guide: every crop, fish, forage action,
  rock/node and monster with its experience value (from the wiki), plus how
  many of each you need for your next level and for level 10.
- The Fishing section includes a Fish Guide: every fish with location, time,
  season, weather, difficulty and base XP, marked caught / not caught /
  level-locked for your farmer, with season, weather and "only uncaught"
  filters and a "Now" button for the save's current season.
- The Calendar section shows each season as a day grid with villager birthdays
  (read from the save, so modded villagers appear), festivals and seasonal
  forage windows, today highlighted, birthday gifts already given this year,
  festivals attended before, and what's coming up.
- The Characters section has a page per villager: birthday, home and family,
  where to find them (wiki schedules by season, weekday, weather and date, with
  the one likely in effect today highlighted), loved / liked / disliked / hated
  gifts, and every heart event with its trigger and seen / pending / missed
  status from your save, plus hearts, gifts given this week and talked-to-today.
- The Books, Special Items & Powers section lists where every book and power
  comes from (wiki text), with have / missing status and an "only missing"
  filter.
- The sidebar groups sections (Progress, Home & Social, Collections, Ginger
  Island, Completion) and shows a done/total badge per section. Click a
  section to view it on its own page, or "All Sections" for the full report.
- Light and dark appearance both supported (follows the system setting).

- On first launch the app asks you to point it at your Saves folder (usually
  `~/.config/StardewValley/Saves`); it reads nothing until you do. The choice is
  remembered, and "Change Saves Folder…" lets you pick another location.
- Use the full save file named after your farmer plus an ID number
  (e.g. `Fred_148093307`), not `SaveGameInfo`.
- Compressed Nintendo Switch saves are supported.
- Auto-reload: the app watches the save's folder and refreshes the report a
  couple of seconds after the game saves (the toolbar toggle pauses it; ⌘R
  reloads manually).
- Output Preferences (show/hide summary and details for old vs. 1.6 "new"
  sections) are persisted between launches, like the site's cookies.
- Multiplayer saves show one column per player, and the bottom bar toggles
  players on and off.
- Hidden spoilers for Golden Walnut locations appear as tooltips when you
  hover over "Hover for spoilers".

## Layout

- `Sources/StardewCheckup/Parsing/` — the port of `stardew-checkup.js`,
  one file per group of sections under `Sections/`, plus the data tables.
- `Sources/StardewCheckup/Model/` — report structures and save metadata.
- `Sources/StardewCheckup/Views/` — SwiftUI rendering styled after the site.
