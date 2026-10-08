import re, html, glob, os, json

def clean(t):
    t = re.sub(r'<(script|style)[^>]*>.*?</\1>', '', t, flags=re.S)
    t = re.sub(r'<span class="mw-editsection">.*?</span>', '', t, flags=re.S)
    t = re.sub(r'<img[^>]*>', '', t)
    t = re.sub(r'<br\s*/?>', ' ', t)
    t = re.sub(r'<[^>]+>', ' ', t)
    t = html.unescape(t)
    t = t.replace('’', "'").replace(' ', ' ').replace(' ', ' ')
    return re.sub(r'\s+', ' ', t).strip()

def headings(s):
    return [(m.start(), m.group(1), m.group(2)) for m in re.finditer(r'<h(\d)><span class="mw-headline" id="([^"]*)"', s)]

def section_html(s, hid):
    hs = headings(s)
    for i, (pos, lvl, id_) in enumerate(hs):
        if id_ == hid:
            end = len(s)
            for pos2, lvl2, _ in hs[i+1:]:
                if int(lvl2) <= int(lvl): end = pos2; break
            return s[pos:end]
    return None

def subsections(s, hid):
    """(title, html) for each direct child heading of hid"""
    sec = section_html(s, hid)
    if sec is None: return []
    hs = headings(sec)
    lvl = int(hs[0][1])
    out = []
    kids = [(p, l, i) for p, l, i in hs[1:] if int(l) == lvl + 1]
    for k, (p, l, i) in enumerate(kids):
        end = kids[k+1][0] if k + 1 < len(kids) else len(sec)
        title = clean(re.search(r'<span class="mw-headline" id="[^"]*">(.*?)</span>', sec[p:end], re.S).group(1))
        out.append((title, i, sec[p:end]))
    return out

def table_rows(tbl):
    rows = re.findall(r'<tr>(.*?)</tr>', tbl, re.S)
    out = []
    for r in rows:
        cells = re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', r, re.S)
        out.append([clean(c) for c in cells])
    return out

def parse(path):
    s = open(path).read()
    name = os.path.basename(path)[:-5]
    d = {'name': name}
    # infobox
    ib = re.search(r'<table id="infoboxtable">(.*?)</table>', s, re.S).group(1)
    for r in re.findall(r'<tr>(.*?)</tr>', ib, re.S):
        cells = re.findall(r'<td[^>]*>(.*?)</td>', r, re.S)
        if len(cells) != 2: continue
        k = clean(cells[0]); v = cells[1]
        if k == 'Birthday':
            d['birthday'] = clean(v)
        elif k == 'Lives In': d['livesIn'] = clean(v)
        elif k == 'Address': d['address'] = clean(v)
        elif k == 'Family':
            d['family'] = [clean(p) for p in re.findall(r'<p[^>]*>(.*?)</p>', v, re.S)] or [clean(v)]
        elif k == 'Marriage': d['marriage'] = clean(v)
        elif k == 'Clinic Visit': d['clinic'] = clean(v)
    # gifts
    gifts = {}
    for key in ['Love', 'Like', 'Neutral', 'Dislike', 'Hate']:
        sec = section_html(s, key)
        if not sec: continue
        items = []
        for tbl in re.findall(r'<table class="wikitable[^"]*"[^>]*>(.*?)</table>', sec, re.S):
            rows = table_rows(tbl)
            if not rows or 'Name' not in rows[0]: continue
            ni = rows[0].index('Name')
            for r in rows[1:]:
                if len(r) > ni and r[ni]: items.append(r[ni])
        gifts[key.lower()] = items
    d['gifts'] = gifts
    # schedule
    sec = section_html(s, 'Schedule')
    sched = {'intro': [], 'seasons': []}
    if sec:
        pre = sec.split('<table', 1)[0]
        sched['intro'] = [clean(p) for p in re.findall(r'<p>(.*?)</p>', pre, re.S) if clean(p)]
        starts = [m.start() for m in re.finditer(r'<table class="mw-collapsible mw-collapsed"', sec)]
        if starts:
            for k, st in enumerate(starts):
                body = sec[st: starts[k+1] if k+1 < len(starts) else len(sec)]
                m = re.search(r'<th[^>]*>(.*?)</th>', body, re.S)
                season = clean(m.group(1))
                parts = re.split(r'(<table class="wikitable"[^>]*>.*?</table>)', body[m.end():], flags=re.S)
                conds = []; title = ''
                for p in parts:
                    if p.startswith('<table'):
                        rows = [r for r in table_rows(p) if len(r) >= 2 and r[0] != 'Time']
                        conds.append({'title': title or 'Schedule', 'rows': rows}); title = ''
                    else:
                        t = clean(p)
                        if t: title = t
                sched['seasons'].append({'season': season, 'conditions': conds})
        else:
            conds = []
            for tbl in re.findall(r'<table class="wikitable[^"]*"[^>]*>(.*?)</table>', sec, re.S):
                rows = table_rows(tbl)
                title = rows[0][0] if rows and len(rows[0]) == 1 else 'Schedule'
                rows = [r for r in rows if len(r) >= 2 and r[0] != 'Time']
                conds.append({'title': title, 'rows': rows})
            if conds: sched['seasons'].append({'season': 'All', 'conditions': conds})
            sched['prose'] = [clean(p) for p in re.findall(r'<p>(.*?)</p>', sec, re.S) if clean(p)]
    d['schedule'] = sched
    # heart events
    evs = []
    for title, hid, body in subsections(s, 'Heart_Events'):
        trig = body.split('<table', 1)[0]
        trig = re.sub(r'^.*?</h\d>', '', trig, count=1, flags=re.S)
        paras = [clean(p) for p in re.findall(r'<p>(.*?)</p>', trig, re.S)]
        paras = [p for p in paras if p]
        # 'Details' collapsible content
        det = re.search(r'<table class="mw-collapsible[^"]*"[^>]*>.*?<tr>\s*<td[^>]*>(.*?)</td>\s*</tr>\s*</tbody></table>', body, re.S)
        details = clean(det.group(1)) if det else ''
        evs.append({'title': title, 'id': hid, 'trigger': paras, 'details': details[:600]})
    d['heartEvents'] = evs
    return d

out = [parse(p) for p in sorted(glob.glob('npc/*.html'))]
json.dump(out, open('npc.json', 'w'), indent=1, ensure_ascii=False)
for d in out:
    g = d['gifts']
    print(f"{d['name']:10} bday={d.get('birthday','?'):12} gifts={[len(g.get(k,[])) for k in ['love','like','neutral','dislike','hate']]} seasons={len(d['schedule']['seasons'])} conds={sum(len(x['conditions']) for x in d['schedule']['seasons'])} events={len(d['heartEvents'])} {[e['title'] for e in d['heartEvents']]}")
