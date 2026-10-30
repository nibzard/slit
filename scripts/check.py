#!/usr/bin/env python3
"""Portable handoff checks. This does not compile Swift or validate camera behavior."""
from pathlib import Path
import json
import plistlib
import re
import subprocess
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
errors = []
required = ['project.yml', 'Packages/SlitCore/Package.swift', 'App/Sources/SlitApp.swift',
            'docs/specs/0002-first-native-mvp.md', 'docs/handoff/BACKLOG.md',
            'docs/handoff/STATUS.md', 'docs/handoff/SETUP.md']
for relative in required:
    if not (ROOT / relative).is_file():
        errors.append(f'Missing {relative}')
for path in (ROOT / 'scripts').glob('*.sh'):
    result = subprocess.run(['bash', '-n', str(path)], capture_output=True, text=True)
    if result.returncode:
        errors.append(result.stderr)
for path in (ROOT / 'App').rglob('*.xcprivacy'):
    try:
        plistlib.loads(path.read_bytes())
    except Exception as error:
        errors.append(f'{path}: {error}')
for path in (ROOT / 'docs/handoff').rglob('*.json'):
    try:
        json.loads(path.read_text())
    except Exception as error:
        errors.append(f'{path}: {error}')
# Validate the portable specification and handoff, not archived research references to temporary files.
paths = [ROOT / 'README.md', ROOT / 'AGENTS.md', *list((ROOT / 'docs/handoff').rglob('*.md')),
         ROOT / 'docs/specs/0002-first-native-mvp.md']
for path in paths:
    if not path.exists():
        errors.append(f'Missing {path}')
        continue
    content = path.read_text()
    if content.count('```') % 2:
        errors.append(f'Unclosed code fence: {path}')
    for target in re.findall(r'\]\((<[^>]+>|[^\s)]+)\)', content):
        target = unquote(target.strip('<>')).split('#')[0]
        if not target or target.startswith(('https:', 'http:', 'mailto:')):
            continue
        if target.startswith('/'):
            errors.append(f'Nonportable link in {path.relative_to(ROOT)}: {target}')
        elif not (path.parent / target).exists():
            errors.append(f'Broken link in {path.relative_to(ROOT)}: {target}')
spec = (ROOT / 'docs/specs/0002-first-native-mvp.md').read_text()
ids = re.findall(r'^\| (M\d+) \|', spec, re.M)
if ids != [f'M{i:02}' for i in range(1, 25)]:
    errors.append('Specification must contain all 24 unique acceptance IDs')
backlog = (ROOT / 'docs/handoff/BACKLOG.md').read_text()
for identifier in ids:
    if identifier not in backlog:
        errors.append(f'Acceptance check missing from backlog: {identifier}')
if errors:
    raise SystemExit('\n'.join(errors))
print('PASS: files, shell syntax, privacy plist, JSON, portable links, and acceptance coverage.')
print('NOT RUN: Swift compilation, Xcode project generation, UI tests, or physical-device tests.')
