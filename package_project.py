"""Package only completed, verified artifacts; no credentials or compiled caches."""
import csv
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT.parent / 'outputs' / 'hospital-reference.zip'
catalog = json.loads((ROOT / 'catalog.json').read_text(encoding='utf-8'))
restore = json.loads((ROOT / 'restore_results.json').read_text(encoding='utf-8-sig'))
qa = json.loads((ROOT / 'report_qa.json').read_text(encoding='utf-8'))
concurrency = json.loads((ROOT / 'concurrency_results.json').read_text(encoding='utf-8'))
tests = list(csv.DictReader((ROOT / 'validation_results.csv').open(encoding='utf-8', newline='')))
assert tests and all(x['passed'] in ('t', 'true') for x in tests), 'SQL validation incomplete'
assert restore['passed'] and restore['disposable_database_removed'], 'Restore validation incomplete'
assert qa['passed'], 'Report QA incomplete'
assert all(concurrency[k]['passed'] for k in ('stock_race', 'payment_race', 'registrar_workflows')), 'Transactional or workflow validation incomplete'

def digest(file):
    h = hashlib.sha256()
    with file.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

allowed_logs = {'authorized_workflows.log', 'restore_authorized_workflows.log'}
files = [p for p in ROOT.iterdir() if p.is_file() and p.name != 'MANIFEST.json'
         and (p.suffix.lower() in ('.sql', '.ps1', '.py', '.cjs', '.md', '.json', '.csv', '.html', '.png', '.backup')
              or p.name in allowed_logs)]
manifest = {
    'database': 'hospital_reference', 'metadata': catalog['metadata'],
    'verification': {'sql_tests_passed': len(tests), 'full_restore': True, 'concurrency_scenarios_passed': 2,
                     'registrar_write_workflows': True, 'report_browser_qa': True},
    'files': [{'name': p.name, 'bytes': p.stat().st_size, 'sha256': digest(p)} for p in sorted(files)],
}
backup_digest = next(x['sha256'] for x in manifest['files'] if x['name'] == 'hospital_reference.backup')
assert backup_digest.upper() == restore['backup_sha256'].upper(), 'Backup archive changed after restore verification'
(ROOT / 'MANIFEST.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
OUTPUT.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(OUTPUT, 'w') as archive:
    for p in sorted(files + [ROOT / 'MANIFEST.json']):
        compression = zipfile.ZIP_STORED if p.suffix == '.backup' else zipfile.ZIP_DEFLATED
        archive.write(p, 'hospital/' + p.name, compress_type=compression)
with zipfile.ZipFile(OUTPUT) as archive:
    assert archive.testzip() is None, 'ZIP integrity check failed'
print(json.dumps({'package': str(OUTPUT), 'bytes': OUTPUT.stat().st_size, 'sha256': digest(OUTPUT),
                  'tables': catalog['metadata']['table_count'], 'rows': catalog['metadata']['row_count']}, ensure_ascii=False, indent=2))
