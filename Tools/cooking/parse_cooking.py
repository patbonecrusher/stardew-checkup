import re, html, json

def clean(t):
    t = re.sub(r'<(style|script)[^>]*>.*?</\1>', '', t, flags=re.S)
    t = re.sub(r'<span style="display: none;">.*?</span>', '', t, flags=re.S)
    t = re.sub(r'<img[^>]*>', '', t)
    t = re.sub(r'<br\s*/?>', ' ', t)
    t = re.sub(r'</(p|tr)>', ' ; ', t)
    t = re.sub(r'<[^>]+>', ' ', t)
    t = html.unescape(t).replace(' ', ' ').replace('’', "'")
    t = re.sub(r'\s+', ' ', t)
    t = re.sub(r'\s*;\s*(;\s*)*', '; ', t)
    return t.strip(' ;')

def top_level(html_s, tag):
    """Split into top-level <tag>...</tag> chunks, honouring nesting of the same tag and of <table>."""
    out = []; depth = 0; start = None
    for m in re.finditer(r'<(/?)(table|tr|td|th)\b[^>]*>', html_s):
        closing, name = m.group(1) == '/', m.group(2)
        if name == 'table':
            depth += -1 if closing else 1
            continue
        if depth != 0 or name not in (tag if isinstance(tag, tuple) else (tag,)): continue
        if not closing: start = m.end()
        elif start is not None: out.append(html_s[start:m.start()]); start = None
    return out

s = open('Cooking.html').read()
i = s.find('<th>Ingredients</th>')
tstart = s.rfind('<table', 0, i)
# find matching end of this table
depth = 0
for m in re.finditer(r'<(/?)table\b[^>]*>', s[tstart:]):
    depth += -1 if m.group(1) else 1
    if depth == 0: tend = tstart + m.end(); break
table = s[tstart:tend]
inner = table[table.find('>') + 1: table.rfind('</table>')]
rows = top_level(inner, 'tr')
recipes = []
for r in rows[1:]:
    cells = top_level(r, ('td', 'th'))
    if len(cells) < 8: continue
    name = clean(cells[1])
    ings = [[m.group(1).strip(), int(m.group(2))] for m in re.finditer(r"([A-Z][A-Za-z' .-]*?)\s*\((\d+)\)", clean(cells[3]))]
    src = clean(cells[7])
    recipes.append({'name': name, 'ingredients': ings, 'source': src})
json.dump(recipes, open('cooking.json', 'w'), indent=1, ensure_ascii=False)
print(len(recipes))
for r in recipes[:6] + recipes[-4:]: print(r)
