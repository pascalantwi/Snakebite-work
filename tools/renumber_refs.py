# Renumber citations in MANUSCRIPT_DRAFT.md by order of first appearance and reorder the reference list.
# Handles linked groups [[n](url),[m](url)] and plain groups [n] / [n,m]. Usage: python3 tools/renumber_refs.py MANUSCRIPT_DRAFT.md
import re, sys
p = sys.argv[1]; s = open(p).read()
refpos = s.index("## References"); body, refs = s[:refpos], s[refpos:]
LINK_GROUP = re.compile(r'\[((?:\[\d+\]\([^)\s]+\))(?:,\s*\[\d+\]\([^)\s]+\))*)\]')
LINK = re.compile(r'\[(\d+)\]\(([^)\s]+)\)')
PLAIN = re.compile(r'(?<![\w\]])\[(\d+(?:\s*,\s*\d+)*)\](?!\()')
order = []
tokens = []
for m in re.finditer(LINK_GROUP.pattern + '|' + PLAIN.pattern, body):
    if m.group(1):
        nums = [int(x) for x, _ in LINK.findall(m.group(1))]
    else:
        nums = [int(x) for x in re.split(r'\s*,\s*', m.group(2))]
    for n in nums:
        if n not in order: order.append(n)
mapping = {old: i + 1 for i, old in enumerate(order)}
def fix_link_group(m):
    return '[' + ','.join(f'[{mapping[int(n)]}]({u})' for n, u in LINK.findall(m.group(1))) + ']'
body = LINK_GROUP.sub(fix_link_group, body)
body = PLAIN.sub(lambda m: '[' + ','.join(str(mapping[int(x)]) for x in re.split(r'\s*,\s*', m.group(1))) + ']', body)
lines = refs.split('\n'); head, entries, tail = [], {}, []
for ln in lines:
    m = re.match(r'^(\d+)\. (.*)$', ln)
    if m: entries[int(m.group(1))] = m.group(2)
    elif not entries: head.append(ln)
    else: tail.append(ln)
unused = sorted(set(entries) - set(mapping)); missing = sorted(set(mapping) - set(entries))
assert not missing, f"cited but not in list: {missing}"
new_refs = '\n'.join(head) + '\n' + '\n'.join(f'{mapping[o]}. {entries[o]}' for o in sorted(mapping, key=mapping.get))
if unused: print("WARNING uncited references dropped:", unused)
open(p, 'w').write(body + new_refs.rstrip('\n') + '\n' + ('\n'.join(t for t in tail if t.strip()) + '\n' if any(t.strip() for t in tail) else ''))
print(f"{len(mapping)} references renumbered; changed: {sum(1 for k,v in mapping.items() if k!=v)}")
