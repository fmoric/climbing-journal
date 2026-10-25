"""Turns a Flutter web build into the installable web app (or the demo).

Usage: python3 prepare.py BUILD_DIR app|demo

app:  adds the service worker for offline use, asks the browser to keep
      the app's storage, and names it "Climbing Journal".
demo: names it "Climbing Journal Demo" so the two don't look alike when
      both are added to a home screen.
"""
import hashlib
import json
import pathlib
import sys

build = pathlib.Path(sys.argv[1])
kind = sys.argv[2]
here = pathlib.Path(__file__).parent

manifest_path = build / 'manifest.json'
manifest = json.loads(manifest_path.read_text())
manifest.update(
    name='Climbing Journal' if kind == 'app' else 'Climbing Journal Demo',
    short_name='Climbing' if kind == 'app' else 'Climb demo',
    start_url='.',
    scope='.',
    display='standalone',
    background_color='#F4F2EE',
    theme_color='#0F6E6A',
)
manifest_path.write_text(json.dumps(manifest, indent=2))

index_path = build / 'index.html'
index = index_path.read_text()
if kind == 'demo':
    index = index.replace('<title>Climbing Journal</title>', '<title>Climbing Journal Demo</title>')
else:
    script = """
  <script>
    if ('serviceWorker' in navigator) {
      // A new version took over: reload once so the page runs it.
      var hadController = !!navigator.serviceWorker.controller;
      var reloaded = false;
      navigator.serviceWorker.addEventListener('controllerchange', function () {
        if (hadController && !reloaded) {
          reloaded = true;
          window.location.reload();
        }
      });
      window.addEventListener('load', function () {
        navigator.serviceWorker.register('sw.js', { updateViaCache: 'none' });
      });
    }
    if (navigator.storage && navigator.storage.persist) {
      navigator.storage.persist();
    }
  </script>
"""
    if '</body>' not in index:
        sys.exit('index.html has no </body>')
    index = index.replace('</body>', script + '</body>', 1)
index_path.write_text(index)

if kind == 'app':
    # Hash the final files (index.html included) and the worker template,
    # so every deploy that changes anything gets a new cache name.
    files = sorted(
        str(f.relative_to(build)).replace('\\', '/')
        for f in build.rglob('*')
        if f.is_file()
        and not f.name.endswith('.symbols')
        and not f.name.startswith('skwasm')
        and f.name not in ('flutter_service_worker.js', 'sw.js')
    )
    template = (here / 'sw.js').read_text()
    digest = hashlib.sha256(template.encode())
    for name in files:
        digest.update(name.encode())
        digest.update((build / name).read_bytes())
    sw = template.replace("'__CACHE__'", json.dumps('climbing-journal-app-' + digest.hexdigest()[:12]))
    sw = sw.replace('__PRECACHE__', json.dumps(['./'] + files, indent=2))
    (build / 'sw.js').write_text(sw)

print(f'Prepared {kind} build in {build}')
