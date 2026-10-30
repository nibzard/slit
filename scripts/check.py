#!/usr/bin/env python3
"""Portable handoff checks. This does not compile Swift or validate camera behavior."""
from pathlib import Path
import ast
import hashlib
import json
import plistlib
import re
import subprocess
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
errors = []
for path in (ROOT / 'scripts').glob('*.py'):
    try:
        ast.parse(path.read_text(), filename=str(path))
    except SyntaxError as error:
        errors.append(f'{path}: {error}')
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
# Parse the generator and workflow YAML only when PyYAML is installed.
try:
    import yaml
except ImportError:
    yaml = None
yaml_notes = []
if yaml is None:
    yaml_notes.append('NOT RUN: project.yml and workflow YAML parsing; PyYAML is not installed.')
else:
    try:
        project = yaml.safe_load((ROOT / 'project.yml').read_text())
        yaml.safe_load((ROOT / '.github/workflows/ios.yml').read_text())
        if not isinstance(project, dict):
            raise ValueError('project.yml must define a mapping')
        targets = project.get('targets') or {}
        built = (((project.get('schemes') or {}).get('Slit') or {}).get('build') or {}).get('targets') or {}
        for target in ('Slit', 'SlitUITests'):
            if target not in targets:
                errors.append(f'project.yml must declare the {target} target')
            if target not in built:
                errors.append(f'project.yml must build the {target} target in the Slit scheme')
        usage = ((targets.get('Slit') or {}).get('info') or {}).get('properties', {}).get('NSCameraUsageDescription')
        if not isinstance(usage, str) or not usage.strip():
            errors.append('project.yml must declare NSCameraUsageDescription for the Slit target')
    except Exception as error:
        errors.append(f'YAML check: {error}')
# Minimal structural check of the task ledger against its schema.
# This is not a general JSON Schema implementation.
def read_json(name):
    """Parse a root JSON file, or record the failure under its own file name."""
    try:
        return json.loads((ROOT / name).read_text())
    except Exception as error:
        errors.append(f'{name}: {error}')
        return None


ledger = read_json('to-do.json')
schema = read_json('to-do.schema.json')
for name, document in (('to-do.json', ledger), ('to-do.schema.json', schema)):
    if document is not None and not isinstance(document, dict):
        errors.append(f'{name}: the root must be an object')
if isinstance(ledger, dict) and isinstance(schema, dict):
    try:
        task_schema = schema['properties']['tasks']['items']
        properties = task_schema['properties']
        version = schema['properties']['schema_version']['const']
    except Exception as error:
        errors.append(f'to-do.schema.json: {error}')
    else:
        for key in schema.get('required') or []:
            if key not in ledger:
                errors.append(f'to-do.json: missing required key {key}')
        if ledger.get('schema_version') != version:
            errors.append(f'to-do.json: schema_version must be {version}, not {ledger.get("schema_version")!r}')
        identifiers = set()
        tasks = ledger.get('tasks') or []
        if not isinstance(tasks, list):
            errors.append('to-do.json: tasks must be an array')
            tasks = []
        for task in tasks:
            if not isinstance(task, dict):
                errors.append('to-do.json: every task must be an object')
                continue
            for key in task_schema['required']:
                if key not in task:
                    errors.append(f'to-do.json: task {task.get("id", "?")} is missing {key}')
            for key in task:
                if key not in properties:
                    errors.append(f'to-do.json: task {task.get("id", "?")} has unknown key {key}')
            if task.get('status') not in properties['status']['enum']:
                errors.append(f'to-do.json: task {task.get("id", "?")} has invalid status {task.get("status")!r}')
            priority = task.get('priority')
            if isinstance(priority, bool) or not isinstance(priority, int):
                errors.append(f'to-do.json: task {task.get("id", "?")} needs an integer priority')
            elif not properties['priority']['minimum'] <= priority <= properties['priority']['maximum']:
                errors.append(f'to-do.json: task {task.get("id", "?")} priority {priority} is out of range')
            identifier = task.get('id')
            if identifier in identifiers:
                errors.append(f'to-do.json: duplicate task id {identifier}')
            identifiers.add(identifier)
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
acceptance_reports = [ROOT / 'docs/handoff/templates/acceptance-report.md',
                      *(ROOT / 'docs/handoff/reports').rglob('acceptance-report.md')]
for path in acceptance_reports:
    if re.findall(r'^\| (M\d+) \|', path.read_text(), re.M) != ids:
        errors.append(f'{path}: acceptance IDs must match the specification in order')
backlog = (ROOT / 'docs/handoff/BACKLOG.md').read_text()
for identifier in ids:
    if identifier not in backlog:
        errors.append(f'Acceptance check missing from backlog: {identifier}')
# Handoff regeneration is an explicit release step, so manifest drift is a warning.
manifest_path = ROOT / 'dist' / 'HANDOFF-MANIFEST.json'
manifest_notes = []
if not manifest_path.is_file():
    manifest_notes.append('NOT RUN: handoff manifest freshness; dist/HANDOFF-MANIFEST.json is absent.')
    manifest_notes.append('Run make handoff to generate it.')
else:
    try:
        recorded = json.loads(manifest_path.read_text())['files']
        # Mirror the collection rules of scripts/package-handoff.py so the two
        # file sets stay comparable. Regenerate the manifest when either list
        # changes. Root files appear only when present; the archive build fails
        # loudly when one is absent.
        expected = [name for name in ['README.md', 'AGENTS.md', 'Makefile', 'project.yml', '.gitignore',
                                      '.xcodegen-version', 'to-do.json', 'to-do.schema.json']
                    if (ROOT / name).is_file()]
        excluded_parts = {'.git', '.build', '.swiftpm', '__pycache__', 'DerivedData', 'build', 'dist',
                          'xcuserdata', 'capability-probe-output'}
        for name in ['App', 'Config', 'Packages', 'docs', 'scripts', '.github', 'experiments']:
            for path in (ROOT / name).rglob('*'):
                if not path.is_file():
                    continue
                relative = path.relative_to(ROOT)
                if any(part in excluded_parts for part in relative.parts):
                    continue
                if path.name in {'Local.xcconfig', '.DS_Store'} or relative.as_posix() == 'App/Info.plist':
                    continue
                if path.suffix in {'.pyc', '.p12', '.mobileprovision'} or path.name.startswith('.env'):
                    continue
                expected.append(relative.as_posix())
        stale = []
        absent = []
        unrecorded = sorted(set(expected) - set(recorded))
        for relative, digest in sorted(recorded.items()):
            path = ROOT / relative
            if not path.is_file():
                absent.append(relative)
            elif hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                stale.append(relative)
        if stale or absent or unrecorded:
            manifest_notes.append('WARNING: dist/HANDOFF-MANIFEST.json does not match the tree; run make handoff to regenerate it.')
            manifest_notes.extend(f'  stale hash: {relative}' for relative in stale)
            manifest_notes.extend(f'  absent file: {relative}' for relative in absent)
            manifest_notes.extend(f'  unrecorded file: {relative}' for relative in unrecorded)
    except Exception as error:
        manifest_notes.append(f'WARNING: dist/HANDOFF-MANIFEST.json is unreadable ({error}); run make handoff to regenerate it.')
if errors:
    raise SystemExit('\n'.join(errors))
print('PASS: files, Python and shell syntax, privacy plist, JSON, portable links, acceptance coverage, and task ledger structure.')
if yaml is not None:
    print('PASS: project.yml scheme, targets, camera usage description, and workflow YAML.')
if yaml_notes:
    print(*yaml_notes, sep='\n')
if manifest_notes:
    print(*manifest_notes, sep='\n')
print('NOT RUN: Swift compilation, Xcode project generation, UI tests, or physical-device tests.')
