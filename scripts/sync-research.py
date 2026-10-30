#!/usr/bin/env python3
"""Copy selected /notes research and make project documentation links portable."""
from pathlib import Path
from urllib.parse import quote
import argparse
import os
import re
import shutil

root = Path(__file__).resolve().parent.parent
source = Path('/notes')
destination = root / 'docs/research'
names = [
    'chromagraph.md', 'iphone-16-plus-camera.md', 'iphone-16-plus-camera-development.md',
    'iphone-camera-ui-ux.md', 'iphone-camera-ui-visual-references.md',
    'photography-styles-moriyama-winogrand-cartier-bresson-meyerowitz.md',
    'street-photography-workflow.md', 'street-camera-interface.md',
    'street-camera-interface-prototypes.md', 'street-camera-mvp-spec.md',
    'portable-photographic-looks-rfc.md', 'iphone-open-source-cameras.md',
    'street-camera-developer-handoff.md', 'slit-capability-probe-2026-10-30.md'
]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--only', choices=names, action='append', help='Export only the named notes')
args = parser.parse_args()
if args.only:
    names = args.only
missing = [name for name in names if not (source / name).exists()]
if missing:
    raise SystemExit('Missing research sources: ' + ', '.join(missing))
destination.mkdir(parents=True, exist_ok=True)
for name in names:
    shutil.copy2(source / name, destination / name)
if not args.only:
    shutil.copytree(source / 'references/iphone-camera-ios27', destination / 'references/iphone-camera-ios27', dirs_exist_ok=True)

def rewrite(match, parent):
    raw = match.group(1).strip('<>')
    if raw.startswith('/notes/'):
        target = destination / raw.removeprefix('/notes/')
    elif raw.startswith('/home/agent/slit/'):
        target = root / raw.removeprefix('/home/agent/slit/')
    else:
        return match.group(0)
    relative = os.path.relpath(target, parent)
    return '](' + quote(relative, safe='/#') + ')'

# Only link targets change. Research prose, dates, and source URLs remain intact.
paths = ([destination / name for name in names] if args.only else
         [*list((root / 'docs').rglob('*.md')), *list((root / 'experiments').rglob('*.md'))])
for path in paths:
    text = path.read_text()
    text = re.sub(r'\]\((<[^>]+>|/(?:notes|home/agent/slit)/[^)\n]+)\)', lambda match: rewrite(match, path.parent), text)
    path.write_text(text)
print(f'Copied {len(names)} selected notes; rewrote portable local links.')
