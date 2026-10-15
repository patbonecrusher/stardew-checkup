# Parse the wiki Artifacts and Minerals pages (Artifacts.html, Minerals.html, saved from
# https://stardewvalleywiki.com/Artifacts and /Minerals) into museum.json: {name: [source lines]}.
# Run from the directory holding the HTML.
import re, html, json

def clean_lines(t):
    t = re.sub(r'<(style|script)[^>]*>.*?</\1>', '', t, flags=re.S)
    t = re.sub(r'<span style="display: ?none;?">.*?</span>', '', t, flags=re.S)
    t = re.sub(r'<sup[^>]*>.*?</sup>', '', t, flags=re.S)
    t = re.sub(r'<br\s*/?>|</(p|li|div)>|<span class="nametemplate">', '\n', t)
    t = re.sub(r'<[^>]+>', ' ', t)
    t = html.unescape(t).replace('\xa0', ' ')
    out = [re.sub(r'\s+', ' ', l).strip() for l in t.split('\n')]
    return [l for l in out if l]

def top_level(s, names):
    out = []; depth = 0; start = None
    for m in re.finditer(r'<(/?)(table|tr|td|th)\b[^>]*>', s):
        closing, name = m.group(1) == '/', m.group(2)
        if name == 'table':
            depth += -1 if closing else 1; continue
        if depth != 0 or name not in names: continue
        if not closing: start = m.end()
        elif start is not None: out.append(s[start:m.start()]); start = None
    return out

def tables(s):
    for m in re.finditer(r'<table\b', s):
        depth = 0
        for e in re.finditer(r'<(/?)table\b[^>]*>', s[m.start():]):
            depth += -1 if e.group(1) else 1
            if depth == 0:
                t = s[m.start():m.start() + e.end()]
                yield t[t.find('>') + 1: t.rfind('</table>')]; break

result = {}
for page, col in (('Artifacts.html', 'Location'), ('Minerals.html', 'Source')):
    s = open(page).read()
    for t in tables(s):
        rows = top_level(t, ('tr',))
        if not rows: continue
        head = [' '.join(clean_lines(c)) for c in top_level(rows[0], ('th', 'td'))]
        if 'Name' not in head or col not in head: continue
        ni, ci = head.index('Name'), head.index(col)
        for r in rows[1:]:
            cells = top_level(r, ('td', 'th'))
            if len(cells) <= ci: continue
            # Link titles disambiguate rows whose visible name repeats (the two Strange Dolls).
            a = re.search(r'<a [^>]*title="([^"]+)"', cells[ni])
            name = html.unescape(a.group(1)) if a else ' '.join(clean_lines(cells[ni]))
            result[name] = clean_lines(cells[ci])
json.dump(result, open('museum.json', 'w'), indent=1, ensure_ascii=False)
for k, v in result.items(): print(k, '=>', v)
