# Parse the wiki Crops page (Crops.html, saved from https://stardewvalleywiki.com/Crops) plus the
# individual crop pages (crop_<Name>.html) and, for seeds with no shop, seed pages (seed_<Seed_Name>.html)
# into crops.json. Run from the directory holding the HTML.
import re, html, json, os

WANTED = ["Parsnip", "Green Bean", "Cauliflower", "Potato", "Garlic", "Kale", "Tomato", "Wheat", "Radish",
          "Red Cabbage", "Corn", "Eggplant", "Artichoke", "Pumpkin", "Bok Choy", "Yam", "Beet", "Amaranth",
          "Hops", "Rhubarb", "Melon", "Blueberry", "Hot Pepper", "Starfruit", "Cranberries", "Grape",
          "Strawberry", "Coffee Bean",
          "Ancient Fruit", "Tulip", "Summer Spangle", "Fairy Rose", "Blue Jazz",
          "Sunflower", "Poppy", "Unmilled Rice", "Carrot", "Summer Squash", "Broccoli", "Powdermelon",
          "Pineapple", "Taro Root"]
SEASONS = ["Spring", "Summer", "Fall", "Winter"]
HEADERS = {"|", "Seeds", "Harvest", "Sells For", "Energy / Health", "Used In", "Used in"}

def lines_of(fragment):
    s = re.sub(r'<(style|script)[^>]*>.*?</\1>', '', fragment, flags=re.S)
    s = re.sub(r'<span style="display: ?none;?">.*?</span>', '', s, flags=re.S)
    s = re.sub(r'</(tr|p|li|h\d|div)>', '\n', s)
    s = re.sub(r'<br\s*/?>', '\n', s)
    s = re.sub(r'</t[dh]>', '\n|\n', s)
    s = re.sub(r'<[^>]+>', ' ', s)
    s = html.unescape(s).replace('\xa0', ' ')
    s = re.sub(r'≈?data-sort-value="[^"]*">', '', s)
    out = [re.sub(r'\s+', ' ', l).strip() for l in s.split('\n')]
    return [l for l in out if l]

page = open('Crops.html').read()
heads = list(re.finditer(r'<h([23])><span class="mw-headline" id="([^"]+)"', page))
crops = {}
season_h2 = None
for k, h in enumerate(heads):
    end = heads[k + 1].start() if k + 1 < len(heads) else len(page)
    hid = h.group(2).replace('_', ' ')
    if h.group(1) == '2':
        season_h2 = hid
        continue
    if hid not in WANTED: continue
    L = lines_of(page[h.end():end])
    i = L.index('Seeds')
    j = i + 1
    while L[j] in HEADERS or re.fullmatch(r'Stage \d+', L[j]): j += 1
    seed = L[j]
    k = j + 1; src = []
    while L[k] != '|': src.append(L[k]); k += 1
    src = ' / '.join(src)
    text = '\n'.join(L)
    total = int(re.search(r'Total:\s*(\d+) days?', text).group(1))
    rg = re.search(r'Regrowth:\s*(\d+) days?', text)
    crops[hid] = {'name': hid, 'section': season_h2, 'seed': seed, 'source_raw': src,
                  'days': total, 'regrow': int(rg.group(1)) if rg else 0}

# Seasons from each crop page's category list ("Spring crops", "Summer crops", ...), falling back to the
# Crops-page section. Pineapple and Taro Root are summer crops in-game (any season on Ginger Island).
FALLBACK = {'Pineapple': ['Summer'], 'Taro Root': ['Summer']}
for name in WANTED:
    fn = 'crop_' + name.replace(' ', '_') + '.html'
    cats = re.search(r'"wgCategories":\[([^\]]*)\]', open(fn).read()).group(1)
    seasons = [s for s in SEASONS if f'"{s} crops"' in cats]
    if not seasons: seasons = FALLBACK.get(name) or [s for s in SEASONS if crops[name]['section'].startswith(s)]
    crops[name]['seasons'] = seasons

# Seeds new in 1.6 aren't sold in shops; their seed pages list the Raccoon Wife trade.
for name, c in crops.items():
    if c['source_raw']: continue
    fn = 'seed_' + c['seed'].replace(' ', '_') + '.html'
    t = ' '.join(lines_of(open(fn).read()))
    m = re.search(r"Raccoon Wife's Shop for (\d+) ([A-Z][A-Za-z ]+?) \.", t)
    c['raccoon'] = [int(m.group(1)), m.group(2)]

missing = [n for n in WANTED if n not in crops]
print('missing:', missing)
json.dump([crops[n] for n in WANTED if n in crops], open('crops.json', 'w'), indent=1, ensure_ascii=False)
for n in WANTED:
    if n in crops: print(crops[n])
