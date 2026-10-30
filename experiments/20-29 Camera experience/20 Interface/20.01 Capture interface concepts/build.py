"""Bundle the local interface study into one offline HTML file."""
from pathlib import Path
import base64
import json

root = Path(__file__).resolve().parent
image = 'data:image/jpeg;base64,' + base64.b64encode((root / 'assets/street.jpg').read_bytes()).decode()
script = (root / 'app.js').read_text().replace("'assets/street.jpg'", json.dumps(image))
html = (root / 'index.html').read_text()
html = html.replace('<link rel="stylesheet" href="styles.css">', '<style>\n' + (root / 'styles.css').read_text() + '\n</style>')
html = html.replace('src="assets/street.jpg"', 'src="' + image + '"')
html = html.replace('<script src="app.js"></script>', '<script>\n' + script + '\n</script>')
(root / 'prototype.html').write_text(html)
