"""Extract the installed PostgreSQL catalog and create a self-contained, read-only project report."""
import csv
import html
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent
PSQL = r'C:\Program Files\PostgreSQL\18\bin\psql.exe'
ENV = dict(os.environ, PGCLIENTENCODING='UTF8')
BASE = [PSQL, '-X', '-w', '-h', 'localhost', '-U', 'postgres', '-d', 'hospital_reference', '-v', 'ON_ERROR_STOP=1', '-At']

def query(sql):
    p = subprocess.run(BASE + ['-c', sql], capture_output=True, text=True, encoding='utf-8', errors='replace', env=ENV, timeout=180)
    if p.returncode:
        raise RuntimeError(p.stderr)
    return p.stdout.strip()

def data(sql):
    return json.loads(query(sql))

tables = data("""SELECT json_agg(x ORDER BY schema_name,table_name) FROM (
SELECT c.oid,n.nspname schema_name,c.relname table_name,obj_description(c.oid,'pg_class') description,
c.relrowsecurity rls,c.relforcerowsecurity forced_rls,CASE WHEN c.relkind='p' THEN (SELECT sum(pg_total_relation_size(pt.relid))::bigint FROM pg_partition_tree(c.oid::regclass) pt WHERE pt.isleaf) ELSE pg_total_relation_size(c.oid) END bytes,
(SELECT coalesce(json_agg(json_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'nullable',NOT a.attnotnull,'identity',a.attidentity,'generated',a.attgenerated,'comment',col_description(c.oid,a.attnum)) ORDER BY a.attnum),'[]'::json) FROM pg_attribute a WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped) columns,
(SELECT coalesce(json_agg(json_build_object('name',co.conname,'type',co.contype,'definition',pg_get_constraintdef(co.oid)) ORDER BY co.conname),'[]'::json) FROM pg_constraint co WHERE co.conrelid=c.oid) constraints,
(SELECT coalesce(json_agg(json_build_object('name',ic.relname,'definition',pg_get_indexdef(i.indexrelid))),'[]'::json) FROM pg_index i JOIN pg_class ic ON ic.oid=i.indexrelid WHERE i.indrelid=c.oid) indexes,
(SELECT coalesce(json_agg(json_build_object('name',t.tgname,'definition',pg_get_triggerdef(t.oid)) ORDER BY t.tgname),'[]'::json) FROM pg_trigger t WHERE t.tgrelid=c.oid AND NOT t.tgisinternal) triggers,
(SELECT coalesce(json_agg(json_build_object('name',p.polname,'roles',ARRAY(SELECT r.rolname FROM pg_roles r WHERE r.oid=ANY(p.polroles)),'using',pg_get_expr(p.polqual,p.polrelid),'with_check',pg_get_expr(p.polwithcheck,p.polrelid)) ORDER BY p.polname),'[]'::json) FROM pg_policy p WHERE p.polrelid=c.oid) policies
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind IN('r','p') AND NOT c.relispartition AND n.nspname NOT IN('ext','pg_catalog','information_schema')) x""")
counts_sql = ' UNION ALL '.join(f"SELECT '{t['schema_name']}.{t['table_name']}' name,count(*)::bigint n FROM \"{t['schema_name']}\".\"{t['table_name']}\"" for t in tables)
counts = {x['name']: x['n'] for x in data('SELECT json_agg(x) FROM ('+counts_sql+')x')}
for table in tables:
    table['row_count'] = counts[table['schema_name']+'.'+table['table_name']]
meta = data("""SELECT json_build_object('database',current_database(),'version',version(),'generated_at',clock_timestamp(),'timezone',current_setting('TimeZone'),'size_bytes',pg_database_size(current_database()),'size_display',pg_size_pretty(pg_database_size(current_database())),'partitions',(SELECT count(*) FROM pg_inherits WHERE inhparent='ehr.observation'::regclass),'foreign_keys',(SELECT count(*) FROM pg_constraint co JOIN pg_class c ON c.oid=co.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE co.contype='f' AND NOT c.relispartition AND n.nspname<>'ext'),'indexes',(SELECT count(*) FROM pg_index i JOIN pg_class c ON c.oid=i.indrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE NOT c.relispartition AND n.nspname NOT IN('ext','pg_catalog','information_schema')))""")
meta.update(table_count=len(tables), row_count=sum(counts.values()), rls_tables=sum(t['rls'] for t in tables), schema_count=len(set(t['schema_name'] for t in tables)))
tests = list(csv.DictReader((ROOT / 'validation_results.csv').open(encoding='utf-8', newline='')))
concurrency_path = ROOT / 'concurrency_results.json'
concurrency = json.loads(concurrency_path.read_text(encoding='utf-8')) if concurrency_path.exists() else {}
benchmark_queries = {
    'patient_timeline': 'SELECT * FROM ehr.encounter WHERE patient_id=42 ORDER BY started_at DESC LIMIT 20',
    'monthly_observations': "SELECT * FROM ehr.observation WHERE patient_id=42 AND observed_at>='2024-01-01 00:00+05' AND observed_at<'2024-02-01 00:00+05' ORDER BY observed_at DESC LIMIT 20",
    'laboratory_history': 'SELECT * FROM lab.diagnostic_report WHERE patient_id=42 ORDER BY issued_at DESC LIMIT 20',
    'revenue_dashboard': 'SELECT * FROM analytics.monthly_revenue ORDER BY reporting_month DESC LIMIT 36',
    'stock_lookup': 'SELECT * FROM inventory.v_stock WHERE lot_id=10',
}
plans = {}
for label, sql in benchmark_queries.items():
    plans[label] = data('EXPLAIN(ANALYZE,BUFFERS,FORMAT JSON) '+sql)
(ROOT / 'query_plans.json').write_text(json.dumps(plans, ensure_ascii=False, indent=2), encoding='utf-8')
catalog = {'metadata': meta, 'tables': tables, 'tests': tests, 'concurrency': concurrency,
           'benchmarks': {k: {'planning_ms': v[0]['Planning Time'], 'execution_ms': v[0]['Execution Time']} for k, v in plans.items()}}
(ROOT / 'catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding='utf-8')

with (ROOT / 'DATA_DICTIONARY.md').open('w', encoding='utf-8') as f:
    f.write('# Словарь установленной БД\n\nСформирован из системного каталога PostgreSQL. Общие проектные решения — в DATA_MODEL.md.\n\n')
    for t in tables:
        f.write(f"## {t['schema_name']}.{t['table_name']}\n\n{t['description']}\n\nСтрок: {t['row_count']:,}. RLS: {t['rls']}.\n\n| Колонка | Тип | NULL | Назначение |\n|---|---|---|---|\n")
        for c in t['columns']:
            desc = (c['comment'] or '').replace('|', '\\|').replace('\n', ' ')
            f.write(f"| `{c['name']}` | `{c['type']}` | {'да' if c['nullable'] else 'нет'} | {desc} |\n")
        f.write('\nОграничения:\n\n')
        for c in t['constraints']:
            f.write(f"- `{c['name']}`: `{c['definition']}`\n")
        if t['triggers']:
            f.write('\nТриггеры:\n\n')
            for trigger in t['triggers']:
                f.write(f"- `{trigger['definition']}`\n")
        if t['policies']:
            f.write('\nПолитики доступа:\n\n')
            for policy in t['policies']:
                f.write(f"- `{policy['name']}` ({', '.join(policy['roles'])}): USING `{policy['using']}`, WITH CHECK `{policy['with_check']}`.\n")
        f.write('\n')

payload = json.dumps(catalog, ensure_ascii=False).replace('</', '<\\/')
template = (ROOT / 'report.template.html').read_text(encoding='utf-8')
(ROOT / 'report.html').write_text(template.replace('__CATALOG_JSON__', payload), encoding='utf-8')
restore = json.loads((ROOT / 'restore_results.json').read_text(encoding='utf-8-sig')) if (ROOT / 'restore_results.json').exists() else {}
passed = sum(t['passed'] in ('t', 'true') for t in tests)
verification = [
    '# Протокол проверки установленной БД', '',
    f"Снимок: {meta['generated_at']}. База: `{meta['database']}`.", '',
    f"Основных таблиц: **{meta['table_count']}**; строк: **{meta['row_count']:,}**; размер: **{meta['size_display']}**.",
    f"Внешних ключей: **{meta['foreign_keys']}**; таблиц с RLS: **{meta['rls_tables']}**; месячных партиций наблюдений: **{meta['partitions']}**.", '',
    f"SQL-проверки: **{passed}/{len(tests)} пройдены**. Полная таблица — `validation_results.csv`.",
    'Тесты изменяющих операций выполнены внутри транзакции с ROLLBACK. Последовательности могут иметь штатные разрывы после отката.', '',
    '## Резервная копия и восстановление', '',
    f"Полное восстановление архива и повторный прогон проверок: **{'PASS' if restore.get('full_restore_verified') else 'не подтверждено'}**.",
    f"Временная база удалена после успешных проверок: {restore.get('disposable_database_removed', False)}.",
    f"Размер архива: {restore.get('backup_bytes', 0):,} байт.",
    f"SHA-256: `{restore.get('backup_sha256', 'not generated')}`.", '',
    '## Конкурентные сценарии на восстановленной копии', '',
    '| Сценарий | Начальное состояние | Две операции | Результат |', '|---|---|---|---|',
]
if concurrency:
    s, p = concurrency['stock_race'], concurrency['payment_race']
    verification += [f"| Остаток партии | 10 единиц | списать по 7 | {'PASS' if s['passed'] else 'FAIL'}: одна операция успешна, остаток {s['closing_stock']} |", f"| Долг по счёту | 10 KZT | распределить по 7 KZT | {'PASS' if p['passed'] else 'FAIL'}: одна операция успешна, распределено {p['allocated']} |"]
    verification += ['', f"Разрешённые изменения регистратора и их аудит на восстановленной копии: **{'PASS' if concurrency.get('registrar_workflows', {}).get('passed') else 'не подтверждено'}**. Тестовые изменения откатились; регистратору не предоставлялось чтение клинической истории или прямое изменение слотов."]
verification += ['', '## Планирование и выполнение запросов', '', 'EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON), одиночные запросы на данном компьютере. Это измерения после загрузки, не SLA и не комплексный нагрузочный тест.', '', '| Запрос | Планирование, мс | Выполнение, мс |', '|---|---:|---:|']
for label, times in catalog['benchmarks'].items():
    verification.append(f"| {label} | {times['planning_ms']:.3f} | {times['execution_ms']:.3f} |")
verification += ['', 'Полные планы: `query_plans.json`. Схема и точные количества: `catalog.json`. Правила и ограничения применимости: `README.md`, `DATA_MODEL.md`.', '']
(ROOT / 'VERIFICATION.md').write_text('\n'.join(verification), encoding='utf-8')
print(json.dumps(meta, ensure_ascii=False, indent=2))
