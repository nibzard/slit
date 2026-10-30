#!/usr/bin/env python3
"""Build a portable source handoff. Excludes signing files, caches, and generated outputs."""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parent.parent
output = root / 'dist'
output.mkdir(exist_ok=True)
files = []
for name in ['README.md', 'AGENTS.md', 'Makefile', 'project.yml', '.gitignore', '.xcodegen-version']:
    files.append(root / name)
for name in ['App', 'Config', 'Packages', 'docs', 'scripts', '.github', 'experiments']:
    for path in (root / name).rglob('*'):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if any(part in {'.git', '.build', '.swiftpm', '__pycache__', 'DerivedData', 'build', 'dist', 'xcuserdata'} for part in relative.parts):
            continue
        if path.name in {'Local.xcconfig', '.DS_Store'} or relative.as_posix() == 'App/Info.plist':
            continue
        if path.suffix in {'.pyc', '.p12', '.mobileprovision'} or path.name.startswith('.env'):
            continue
        files.append(path)
manifest = {
    'name': 'Slit developer handoff',
    'status': 'Bootstrap; native build and device validation pending',
    'files': {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(files))}
}
archive = output / 'slit-developer-handoff.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
    for path in sorted(set(files)):
        bundle.write(path, 'slit/' + path.relative_to(root).as_posix())
    bundle.writestr('slit/HANDOFF-MANIFEST.json', json.dumps(manifest, indent=2) + '\n')
(output / 'HANDOFF-MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(f'{archive}: {len(manifest["files"])} source files, {archive.stat().st_size} bytes')
