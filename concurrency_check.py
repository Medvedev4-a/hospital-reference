"""Concurrency tests run ONLY against a disposable restored copy, never the main database."""
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parent
PSQL = r'C:\Program Files\PostgreSQL\18\bin\psql.exe'
DB = sys.argv[1] if len(sys.argv) > 1 else ''
if not DB.endswith('_restore_check'):
    raise SystemExit('A disposable *_restore_check database is required')
ENV = dict(os.environ, PGCLIENTENCODING='UTF8')
BASE = [PSQL, '-X', '-w', '-h', 'localhost', '-U', 'postgres', '-d', DB,
        '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose', '-At']

def run(sql, required=True):
    p = subprocess.run(BASE + ['-c', sql], text=True, encoding='utf-8', errors='replace',
                       capture_output=True, env=ENV, timeout=90)
    if required and p.returncode:
        raise RuntimeError(p.stderr)
    return p

def scalar(sql):
    return run(sql).stdout.strip().splitlines()[0]

workflow = subprocess.run(BASE + ['-f', str(ROOT / '10_validate_registrar.sql')], text=True,
                          encoding='utf-8', errors='replace', capture_output=True, env=ENV, timeout=120)
workflow_ok = workflow.returncode == 0 and 'REGISTRAR_WRITE_WORKFLOWS_PASS' in workflow.stdout
(ROOT / 'restore_authorized_workflows.log').write_text(workflow.stdout + workflow.stderr, encoding='utf-8')
if not workflow_ok:
    raise RuntimeError('Restored registrar write validation failed: ' + workflow.stderr)

lot = int(scalar("INSERT INTO inventory.lot(item_id,lot_number,expires_on,supplier_id,received_on) "
                 "VALUES(1,'SYNTH-CONCURRENCY-TEST','2028-12-31',1,'2023-01-01') RETURNING id"))
run(f"INSERT INTO inventory.stock_movement(location_id,lot_id,quantity_delta,movement_type,occurred_at,recorded_by,reason) "
    f"VALUES(2,{lot},10,'receipt',now(),541,'Disposable restoration concurrency test')")

def race(sqls):
    barrier = threading.Barrier(2)
    def worker(sql):
        barrier.wait(timeout=15)
        return run('BEGIN; '+sql+'; SELECT pg_sleep(0.4); COMMIT;', required=False)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        return list(pool.map(worker, sqls))

stock_sql = (f"INSERT INTO inventory.stock_movement(location_id,lot_id,quantity_delta,movement_type,occurred_at,recorded_by,reason) "
             f"VALUES(2,{lot},-7,'adjustment',now(),541,'Competing withdrawal')")
stock = race([stock_sql, stock_sql])
stock_qty = scalar(f'SELECT quantity FROM inventory.stock_balance WHERE location_id=2 AND lot_id={lot}')
stock_ok = sum(p.returncode == 0 for p in stock) == 1 and float(stock_qty) == 3 and any('23514' in p.stderr for p in stock)

invoice = int(scalar("INSERT INTO billing.invoice(patient_id,encounter_id,invoice_number,payer_id,coverage_id,issued_at,due_at,status,currency_code) "
                     "VALUES(1,1,'SYNTH-CONCURRENCY-INVOICE',1,1,now(),now()+interval '30 days','draft','KZT') RETURNING id"))
run(f"INSERT INTO billing.invoice_line(invoice_id,line_no,service_id,quantity,unit_price) VALUES({invoice},1,1,1,10); "
    f"UPDATE billing.invoice SET status='issued' WHERE id={invoice}")
payment_ids = []
for k in range(2):
    payment_ids.append(int(scalar("INSERT INTO billing.payment(patient_id,payer_id,received_at,amount,currency_code,method,external_reference) "
                                  f"VALUES(1,1,now(),7,'KZT','transfer','SYNTH-CONCURRENCY-PAY-{k}') RETURNING id")))
payments = race([f"INSERT INTO billing.payment_allocation(payment_id,invoice_id,patient_id,amount) VALUES({p},{invoice},1,7)"
                 for p in payment_ids])
allocated = scalar(f'SELECT coalesce(sum(amount),0) FROM billing.payment_allocation WHERE invoice_id={invoice}')
payment_ok = sum(p.returncode == 0 for p in payments) == 1 and float(allocated) == 7 and any('23514' in p.stderr for p in payments)
result = {
    'database': DB,
    'registrar_workflows': {'passed': workflow_ok},
    'stock_race': {'passed': stock_ok, 'concurrent_requests': 2, 'successful_requests': sum(p.returncode == 0 for p in stock), 'opening_stock': 10, 'requested_each': 7, 'closing_stock': float(stock_qty)},
    'payment_race': {'passed': payment_ok, 'concurrent_requests': 2, 'successful_requests': sum(p.returncode == 0 for p in payments), 'invoice_amount': 10, 'requested_each': 7, 'allocated': float(allocated)},
}
(ROOT / 'concurrency_results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(result, ensure_ascii=False, indent=2))
if not (stock_ok and payment_ok):
    raise SystemExit('Concurrency validation failed')
