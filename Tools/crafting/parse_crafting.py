import re, html, json

def clean(t):
    t = re.sub(r'<(style|script)[^>]*>.*?</\1>', '', t, flags=re.S)
    t = re.sub(r'<span style="display: none;">.*?</span>', '', t, flags=re.S)
    t = re.sub(r'<sup[^>]*>.*?</sup>', '', t, flags=re.S)
    t = re.sub(r'<img[^>]*>', '', t)
    t = re.sub(r'<br\s*/?>', ' ', t)
    t = re.sub(r'</(p|tr|li)>', ' ; ', t)
    t = re.sub(r'<[^>]+>', ' ', t)
    t = html.unescape(t).replace('\xa0', ' ').replace('’', "'")
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

def tables(s):
    """Every top-level wikitable whose header names an Ingredients column."""
    out = []
    for m in re.finditer(r'<table\b[^>]*>', s):
        depth = 0
        for m2 in re.finditer(r'<(/?)table\b[^>]*>', s[m.start():]):
            depth += -1 if m2.group(1) else 1
            if depth == 0: end = m.start() + m2.end(); break
        t = s[m.start():end]
        inner = t[t.find('>') + 1: t.rfind('</table>')]
        rows = top_level(inner, 'tr')
        if rows and re.search(r'<th[^>]*>\s*Ingredients', rows[0]):
            out.append(rows)
    return out

def header_columns(row):
    """Column names of the first header row, expanding colspans."""
    cols = []
    for m in re.finditer(r'<th([^>]*)>(.*?)(?=<th|$)', row, flags=re.S):
        span = re.search(r'colspan="(\d+)"', m.group(1))
        cols += [clean(m.group(2))] * (int(span.group(1)) if span else 1)
    return cols

def ingredients(cell):
    spans = re.findall(r'<span class="nametemplate">(.*?)</span>', cell, flags=re.S)
    parts = [clean(x) for x in spans] if spans else [clean(cell)]
    out = []
    for p in parts:
        m = re.fullmatch(r"(.+?)\s*\((\d+)\)", p)
        out.append([m.group(1).strip(), int(m.group(2))] if m else [p.strip(), 1])
    return out

s = open('Crafting.html').read()
recipes = []
for rows in tables(s):
    cols = header_columns(rows[0])
    ni, ii, si = cols.index('Name'), cols.index('Ingredients'), cols.index('Recipe Source')
    for r in rows[1:]:
        if '<td' not in r: continue
        cells = top_level(r, ('td', 'th'))
        if len(cells) != len(cols):
            print('skip (cells %d vs cols %d): %s' % (len(cells), len(cols), clean(r)[:80])); continue
        recipes.append({'name': clean(cells[ni]), 'ingredients': ingredients(cells[ii]), 'source': clean(cells[si])})
json.dump(recipes, open('crafting.json', 'w'), indent=1, ensure_ascii=False)
print(len(recipes))
for r in recipes[:4] + recipes[-4:]: print(r)
