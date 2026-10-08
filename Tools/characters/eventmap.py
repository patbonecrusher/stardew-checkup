import json, math
SOCIAL = {
 "Abigail": [(2,"1"),(4,"2"),(6,"4"),(8,"3"),(10,"901756"),(14,"6963327")],
 "Alex": [(2,"20"),(4,"2481135"),(5,"21"),(6,"2119820"),(8,"288847"),(10,"911526"),(14.1,"3917587"),(14.2,"3917589"),(14.3,"3917590")],
 "Elliott": [(2,"39"),(4,"40"),(6,"423502"),(8,"1848481"),(10,"43"),(14.1,"3912125"),(14.2,"3912132")],
 "Emily": [(2,"471942"),(4,"463391"),(6,"917409"),(8,"2123243"),(10,"2123343"),(14.1,"3917600"),(14.2,"3917601")],
 "Haley": [(2,"11"),(4,"12"),(6,"13"),(8,"14"),(10,"15"),(14.1,"6184643"),(14.2,"8675611"),(14.3,"6184644")],
 "Harvey": [(2,"56"),(4,"57"),(6,"58"),(8,"571102"),(10,"528052"),(14,"3917626")],
 "Leah": [(2,"50"),(4,"51"),(6,"52"),(8,"53|584059"),(10,"54"),(14.1,"3911124"),(14.2,"3091462")],
 "Maru": [(2,"6"),(4,"7"),(6,"8"),(8,"9"),(10,"10"),(14.1,"3917666"),(14.2,"5183338")],
 "Penny": [(2,"34"),(4,"35"),(6,"36"),(8,"181928"),(10,"38"),(14.1,"4325434"),(14.2,"4324303")],
 "Sam": [(2,"44"),(3,"733330"),(4,"46"),(6,"45"),(8,"4081148"),(10,"233104"),(14.1,"3918600"),(14.2,"3918601"),(14.3,"3918602"),(14.4,"3918603")],
 "Sebastian": [(2,"2794460"),(4,"384883"),(6,"27"),(8,"29"),(10,"384882"),(14.1,"9333219"),(14.2,"9333220")],
 "Shane": [(2,"611944"),(4,"3910674"),(6,"3910975"),(6.8,"3910974"),(7,"831125"),(8,"3900074"),(10,"9581348"),(14.1,"3917584"),(14.2,"3917585"),(14.3,"3917586")],
 "Caroline": [(6,"17"),(2,"719926")], "Clint": [(3,"97"),(6,"101")], "Demetrius": [(6,"25")], "Dwarf": [(0.2,"691039")],
 "Evelyn": [(4,"19")], "George": [(6,"18")], "Gus": [(4,"96"),(5,"980558")], "Jas": [(8,"3910979")], "Jodi": [(4,"94|95")],
 "Kent": [(3,"100")], "Krobus": [(14,"7771191")], "Lewis": [(6,"639373")], "Linus": [(0.2,"502969"),(4,"26"),(8,"371652")],
 "Marnie": [(6,"639373")], "Pam": [(9,"503180")], "Pierre": [(6,"16")], "Robin": [(6,"33")], "Sandy": [], "Vincent": [(8,"3910979")],
 "Willy": [(6,"711130")], "Wizard": [],
 "Leo": [(0,"1039573"),(2,"6497423"),(4,"6497421"),(6,"6497428"),(9,"8959199")],
}
WORDS = {"Zero":0,"Two":2,"Three":3,"Four":4,"Five":5,"Six":6,"Seven":7,"Eight":8,"Nine":9,"Ten":10,"Fourteen":14}
GIRLS = {"Abigail","Emily","Haley","Leah","Maru","Penny"}
OVERRIDE = {
 ("Shane","Seven Hearts I"): ["3910974"], ("Shane","Seven Hearts II"): ["831125"],
 ("Leah","Six Hearts I"): ["52"], ("Leah","Six Hearts II"): ["584059"], ("Leah","Eight Hearts"): ["53"],
 ("Dwarf","50 Friendship Points"): ["691039"], ("Linus","Zero Hearts"): ["502969"],
 ("Clint","Three Hearts II"): [], ("Marnie","Three Hearts I"): [], ("Marnie","Three Hearts II"): [], ("Kent","Three Hearts II"): [],
}
def hearts_of(title):
    w = title.split()[0]
    return WORDS.get(w)
def ids_for(name, title):
    if (name, title) in OVERRIDE: return OVERRIDE[(name, title)]
    if title == 'Group Ten-Heart Event':
        return ["195012|195019"] if name in GIRLS else ["195013|195099"]
    if 'recipe in the mail' in title: return []
    h = hearts_of(title)
    if h is None: return []
    return [i for (hh, i) in SOCIAL.get(name, []) if math.floor(hh) == h and (hh != 6.8)]
if __name__ == '__main__':
    used = set()
    for d in json.load(open('npc.json')):
        for e in d['heartEvents']:
            if e['title'] == 'Anytime': continue
            t = ' '.join(e['trigger'])
            mail = 'recipe in the mail' in t
            ids = [] if mail else ids_for(d['name'], e['title'])
            for i in ids: used.add((d['name'], i))
            print(f"{d['name']:10} {e['title']:24} {'MAIL' if mail else ''} {ids}")
    allids = {(n, i) for n, l in SOCIAL.items() for _, i in l}
    print('UNUSED social ids:', sorted(allids - used))
