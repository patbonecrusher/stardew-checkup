# Turn museum.json (from parse_museum.py) into Sources/StardewCheckup/Parsing/MuseumSourceData.swift:
# a short "where to find" hint per museum artifact/mineral, condensed into our own wording.
import json, re
data = json.load(open('museum.json'))
ROOT = '/Users/pat/Projects/stardewvalley-checker/Sources/StardewCheckup/'
def q(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

REGIONS = ['Farm', 'Town', 'Forest', 'Mountain', 'Beach', 'Bus Stop', 'Railroad', 'Backwoods', 'Desert']
GEODES = ['Geode', 'Frozen Geode', 'Magma Geode', 'Omni Geode']
MONSTER_FIX = {'Bats': 'bats', 'Green Slimes': 'Green Slimes', 'Blue Slimes': 'Blue Slimes'}

IRREGULAR = {'Duggy': 'Duggies', 'Pepper Rex': 'Pepper Rexes', 'Mummy': 'Mummies'}
def plural(m): return IRREGULAR.get(m) or (m if m.endswith('s') else m + 's')
def floors(s): return s.replace('-', '–')

def hint(name, lines):
    spots, geodes, mobs, other, low = [], [], [], [], []
    def add(lst, x):
        if x not in lst: lst.append(x)
    for raw in lines:
        l = re.sub(r'\s*\((?:≈?[\d. ,+%-]+|\d+(?:\.\d+)?% each)\)\s*$', '', raw)   # drop drop-rate notes
        l = re.sub(r'\s*\((?:[\d.]+% \+ )?[\d.]+(?:-[\d.]+)?%\)', '', l).strip()
        l = l.replace(' . ', '.')
        # split "Fishing Treasure Chest Any monster ..." glued cells
        if l.startswith('Fishing Treasure Chest '):
            add(other, 'fishing chests'); l = l[len('Fishing Treasure Chest '):]
        if l in REGIONS: add(spots, l); continue
        if l in GEODES: add(geodes, l); continue
        m = re.fullmatch(r'Tilling in Mines/Skull Cavern \(any floor\)', l)
        if m: add(other, 'hoeing Mines or Skull Cavern dirt'); continue
        if l == 'Tilling in Mines/Skull Cavern (any floor)': continue
        m = re.fullmatch(r'Tilling in Mines \(floor ([\d-]+\+?)\)', l)
        if m: add(other, f'hoeing dirt on Mines floors {floors(m.group(1))}'); continue
        m = re.fullmatch(r'The Mines \(Floors? ([\d-]+)\)', l)
        if m: add(other, f'Mines floors {floors(m.group(1))}'); continue
        if l in ('Fishing Chest', 'Fishing Treasure Chest'): add(other, 'fishing chests'); continue
        if l == 'Artifact Trove': add(low, 'Artifact Troves'); continue
        if l == 'Bone Nodes': add(other, 'Bone Nodes'); continue
        if l == 'Panning': add(other, 'panning'); continue
        if l == 'Garbage Can': add(low, 'garbage cans'); continue
        if l == 'Feast of the Winter Star': add(low, 'Winter Star gift'); continue
        if l == 'Dwarvish Sentry': add(mobs, 'Dwarvish Sentries'); continue
        if l == 'Slime Ball': add(other, 'Slime Balls'); continue
        if l == 'Mystic Stone': add(other, 'Mystic Stones'); continue
        if l == 'Iridium Node': add(other, 'Iridium nodes'); continue
        if l == 'Gem Node': add(other, 'gem nodes'); continue
        m = re.fullmatch(r'(\w+) Node', l)
        if m: add(other, f'{m.group(1)} nodes'); continue
        m = re.fullmatch(r'Secret Note #(\d+)', l)
        if m: add(other, f'Secret Note #{m.group(1)}'); continue
        if l.startswith('Any monster after reaching the bottom'): add(low, 'any monster once Mines floor 120 is reached'); continue
        if l.startswith('Any Monster (other than'): add(mobs, 'most monsters'); continue
        if l.startswith('Several monsters'):
            add(mobs, 'many monsters'); continue
        if l.startswith('Foraged on prehistoric floors'): add(other, 'forage on Skull Cavern prehistoric floors'); continue
        m = re.fullmatch(r'Monster drop \((.+?): [\d.]+%\)', raw.strip())
        if m:
            add(mobs, 'bugs, flies and grubs'); continue
        m = re.fullmatch(r'Bats drop \(except Iridium Bat\)', l)
        if m: add(mobs, 'bats'); continue
        m = re.fullmatch(r'(.+?) drop', l)
        if m:
            for x in re.split(r'\s*,\s*', m.group(1)): add(mobs, plural(x.strip()))
            continue
        if l in ('Duggy', 'Haunted Skull', 'Stone Golem', 'Dust Sprite', 'Black Slime', 'Green Slimes',
                 'Blue Slimes', 'Shadow Brute', 'Shadow Shaman', 'Mummy', 'Serpent'):
            add(mobs, plural(l)); continue
        raise SystemExit(f'unhandled source for {name}: {raw!r}')
    # "Emerald nodes" + "gem nodes" read better merged.
    specific = [p for p in other if re.fullmatch(r'[A-Z]\w+ nodes', p) and p != 'Iridium nodes']
    if specific and 'gem nodes' in other:
        i = other.index(specific[0]); other[i] = specific[0].replace(' nodes', ' or gem nodes in the Mines')
        other.remove('gem nodes')
    parts = []
    if len(spots) >= 5: parts.append('very rarely from any Artifact Spot')
    elif spots: parts.append('Artifact Spots: ' + ', '.join(spots))
    parts += [p for p in other if p.startswith(('Mines floors', 'hoeing'))]
    if geodes:
        names = [g + 's' for g in geodes]
        parts.append(names[0] if len(names) == 1 else ', '.join(names[:-1]) + ' or ' + names[-1])
    parts += [p for p in other if not p.startswith(('Mines floors', 'hoeing'))]
    if mobs: parts.append('dropped by ' + ', '.join(mobs))
    full = parts + low
    # Keep under ~120 chars: shed the least useful extras first.
    while len('; '.join(full)) > 120 and low:
        low.pop(); full = parts + low
    s = '; '.join(full)
    if len(s) > 120 and mobs:
        while len(s) > 120 and len(mobs) > 1:
            mobs.pop(); parts[-1] = 'dropped by ' + ', '.join(mobs) + ' and others'; s = '; '.join(parts)
    return s[0].upper() + s[1:]

src = open(ROOT + 'Parsing/CollectionData.swift').read()
names = []
for k in ('artifacts', 'minerals'):
    blk = src[src.index(f'static let {k}'):]; blk = blk[:blk.index(']\n')]
    names += re.findall(r'\("\d+", "([^"]+)"\)', blk)
missing = [n for n in names if n not in data]
print('missing:', missing)
lines = []
for n in names:
    h = hint(n, data[n])
    if len(h) > 120: print('LONG', len(h), n, h)
    lines.append(f'        {q(n)}: {q(h)},')
out = '''import Foundation

/// Short "where to find it" hints for every artifact and mineral the museum accepts. Facts compiled from the
/// Stardew Valley Wiki (Artifacts and Minerals pages, CC BY-NC-SA 3.0), October 2026; wording is our own.
/// Generated by Tools/museum/gen_museum.py.
enum MuseumSourceData {
    static let sources: [String: String] = [
''' + '\n'.join(lines) + '''
    ]
}
'''
open(ROOT + 'Parsing/MuseumSourceData.swift', 'w').write(out)
print(len(lines))
