-- pgAdmin Query Tool: select a statement and run. Administrative session sees all rows.
-- 1. Operational overview
SELECT * FROM analytics.bed_occupancy ORDER BY department_id;
SELECT * FROM analytics.monthly_revenue ORDER BY reporting_month DESC,payer_id LIMIT 36;
-- 2. Timeline and most recent measurements for a patient
SELECT * FROM ehr.v_patient_timeline WHERE patient_id=1 ORDER BY started_at DESC;
SELECT DISTINCT ON(test_id) test_id,observed_at,value_numeric,unit_code
FROM ehr.observation WHERE patient_id=1 ORDER BY test_id,observed_at DESC;
-- 3. Complete laboratory lineage
SELECT r.id request_id,s.accession_number,t.name,result.value_numeric,result.unit_code,d.issued_at
FROM lab.service_request r JOIN lab.request_specimen rs ON rs.request_id=r.id
JOIN lab.specimen s ON s.id=rs.specimen_id JOIN lab.result result ON result.specimen_id=s.id
JOIN ref.test t ON t.id=result.test_id JOIN lab.report_result rr ON rr.result_id=result.id
JOIN lab.diagnostic_report d ON d.id=rr.report_id WHERE r.patient_id=1 ORDER BY r.id,t.id;
-- 4. Signed clinical note and amendments
SELECT n.id,n.encounter_id,v.version,v.body,v.signed_at,encode(v.body_sha256,'hex') sha256
FROM ehr.clinical_note n JOIN ehr.note_version v ON v.note_id=n.id WHERE n.patient_id=1 ORDER BY n.id,v.version;
-- 5. Current hospital census
SELECT a.admission_number,p.mrn,b.code bed,d.name department,lower(s.occupied_during) since
FROM adt.bed_stay s JOIN adt.admission a ON a.id=s.admission_id JOIN mpi.patient p ON p.id=s.patient_id
JOIN org.bed b ON b.id=s.bed_id JOIN org.room r ON r.id=b.room_id JOIN org.department d ON d.id=r.department_id
WHERE now()<@s.occupied_during ORDER BY d.id,b.code;
-- 6. Outstanding invoices, grouped without demographic disclosure
SELECT payer_id,currency_code,count(*) invoices,sum(outstanding_amount) outstanding
FROM billing.v_invoice_balance WHERE status='issued' AND outstanding_amount>0 GROUP BY 1,2;
-- 7. Stock availability and lot expiry
SELECT * FROM inventory.v_stock ORDER BY expires_on,sku;
-- 8. Spatial catchment, synthetic locations only
SELECT p.mrn,round(ext.ST_Distance(a.location,s.location)) distance_meters
FROM mpi.address a JOIN mpi.patient p ON p.id=a.patient_id CROSS JOIN org.site s
WHERE s.id=1 AND ext.ST_DWithin(a.location,s.location,2000) ORDER BY distance_meters LIMIT 30;
-- 9. RLS demo (administrator only; no login or password is created)
BEGIN;
SET SESSION AUTHORIZATION hospital_demo_clinician;
SELECT count(*) FROM mpi.patient; -- 100
SELECT * FROM ehr.v_patient_timeline WHERE patient_id=101; -- no rows
RESET SESSION AUTHORIZATION;
ROLLBACK;
-- 10. Inspect design
SELECT * FROM analytics.v_catalog ORDER BY schema_name,table_name;
SELECT version,applied_at,description FROM ops.schema_migration ORDER BY version;
-- 11. Optimistic concurrency pattern (ROLLBACK keeps demo unchanged)
BEGIN;
UPDATE mpi.patient SET given_name=given_name WHERE id=1 AND row_version=1 RETURNING id,row_version;
ROLLBACK;
-- 12. Outbox worker claim pattern; payloads in this demo are synthetic envelopes
BEGIN;
SELECT id,event_id,event_type,payload FROM integration.outbox
WHERE published_at IS NULL AND next_attempt_at<=now() ORDER BY id FOR UPDATE SKIP LOCKED LIMIT 20;
ROLLBACK;
-- 13. Partition pruning and timeline performance
EXPLAIN(ANALYZE,BUFFERS) SELECT * FROM ehr.observation
WHERE patient_id=42 AND observed_at>='2024-01-01 00:00+05' AND observed_at<'2024-02-01 00:00+05'
ORDER BY observed_at DESC LIMIT 20;
-- 14. True stock ledger/projection reconciliation
SELECT b.location_id,b.lot_id,b.quantity,sum(m.quantity_delta) ledger_quantity
FROM inventory.stock_balance b JOIN inventory.stock_movement m USING(location_id,lot_id)
GROUP BY b.location_id,b.lot_id,b.quantity HAVING b.quantity<>sum(m.quantity_delta);
