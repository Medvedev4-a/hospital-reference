\set ON_ERROR_STOP on
\pset pager off
SET TIME ZONE 'Asia/Qyzylorda';
BEGIN;
CREATE TEMP TABLE validation_result(test_name text PRIMARY KEY,passed boolean NOT NULL,details text NOT NULL DEFAULT '');
CREATE FUNCTION pg_temp.assert(p_name text,p_passed boolean,p_details text DEFAULT '') RETURNS void LANGUAGE plpgsql AS $$BEGIN INSERT INTO validation_result VALUES(p_name,coalesce(p_passed,false),p_details); END$$;
CREATE FUNCTION pg_temp.rejects(p_sql text,p_state text) RETURNS boolean LANGUAGE plpgsql AS $$DECLARE actual text; BEGIN BEGIN EXECUTE p_sql; RAISE EXCEPTION 'Statement unexpectedly accepted' USING ERRCODE='P0004'; EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS actual=RETURNED_SQLSTATE; RETURN actual=p_state; END; END$$;
DO $$DECLARE n name; BEGIN SELECT nspname INTO n FROM pg_namespace WHERE oid=pg_my_temp_schema(); EXECUTE format('GRANT USAGE ON SCHEMA %I TO hospital_demo_clinician,hospital_demo_registrar,hospital_demo_billing,hospital_analyst,hospital_auditor',n); END$$;
SELECT pg_temp.assert('01.patient_count',(SELECT count(*)=120002 FROM mpi.patient));
SELECT pg_temp.assert('02.encounter_count',(SELECT count(*)=330000 FROM ehr.encounter));
SELECT pg_temp.assert('03.observation_count',(SELECT count(*)=1320000 FROM ehr.observation));
SELECT pg_temp.assert('04.lab_results',(SELECT count(*)=360000 FROM lab.result));
SELECT pg_temp.assert('05.synthetic_only',NOT EXISTS(SELECT FROM mpi.patient WHERE NOT is_synthetic) AND NOT EXISTS(SELECT FROM ref.medication WHERE NOT is_demo));
SELECT pg_temp.assert('06.birth_before_encounter',NOT EXISTS(SELECT FROM ehr.encounter e JOIN mpi.patient p ON p.id=e.patient_id WHERE e.started_at::date<p.birth_date));
SELECT pg_temp.assert('07.validated_constraints',NOT EXISTS(SELECT FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname NOT IN('pg_catalog','ext','information_schema') AND NOT c.convalidated));
SELECT pg_temp.assert('08.monthly_partitions',(SELECT count(*)=48 FROM pg_inherits WHERE inhparent='ehr.observation'::regclass));
SELECT pg_temp.assert('09.notes_have_current_version',NOT EXISTS(SELECT FROM ehr.clinical_note n LEFT JOIN ehr.note_version v ON v.note_id=n.id AND v.version=n.current_version WHERE v.note_id IS NULL));
SELECT pg_temp.assert('10.stock_balances_reconcile',NOT EXISTS(SELECT FROM inventory.stock_balance b FULL JOIN(SELECT location_id,lot_id,sum(quantity_delta) quantity FROM inventory.stock_movement GROUP BY 1,2)m USING(location_id,lot_id) WHERE b.quantity IS DISTINCT FROM m.quantity));
SELECT pg_temp.assert('11.stock_nonnegative',NOT EXISTS(SELECT FROM inventory.stock_balance WHERE quantity<0));
SELECT pg_temp.assert('12.dispense_stock_link',NOT EXISTS(SELECT FROM pharmacy.dispense d LEFT JOIN inventory.stock_movement m ON m.dispense_id=d.id WHERE m.id IS NULL OR m.quantity_delta<>-d.quantity OR m.lot_id<>d.lot_id OR m.location_id<>d.location_id));
SELECT pg_temp.assert('13.money_reconciles',(SELECT sum(amount) FROM billing.payment)=(SELECT sum(amount) FROM billing.payment_allocation));
SELECT pg_temp.assert('14.invoice_nonnegative',NOT EXISTS(SELECT FROM billing.v_invoice_balance WHERE outstanding_amount<0));
SELECT pg_temp.assert('15.allocation_bounds',NOT EXISTS(SELECT FROM billing.payment p JOIN(SELECT payment_id,sum(amount) n FROM billing.payment_allocation GROUP BY 1)a ON a.payment_id=p.id WHERE a.n>p.amount));
SELECT pg_temp.assert('16.discharge_consistency',NOT EXISTS(SELECT FROM adt.discharge d JOIN adt.admission a ON a.id=d.admission_id WHERE d.discharged_at IS DISTINCT FROM a.discharged_at));
SELECT pg_temp.assert('17.bed_stays_contained',NOT EXISTS(SELECT FROM adt.bed_stay b JOIN adt.admission a ON a.id=b.admission_id WHERE NOT(b.occupied_during<@tstzrange(a.admitted_at,a.discharged_at,'[)'))));
SELECT pg_temp.assert('18.lab_chain_consistency',NOT EXISTS(SELECT FROM lab.report_result rr JOIN lab.diagnostic_report d ON d.id=rr.report_id JOIN lab.result r ON r.id=rr.result_id LEFT JOIN lab.request_specimen rs ON rs.request_id=d.request_id AND rs.specimen_id=r.specimen_id WHERE rs.request_id IS NULL));
SELECT pg_temp.assert('19.no_runtime_login_roles',NOT EXISTS(SELECT FROM pg_roles WHERE rolname LIKE 'hospital_%' AND (rolcanlogin OR rolsuper OR rolbypassrls OR rolcreatedb OR rolcreaterole)));
SELECT pg_temp.assert('20.no_public_function_execute',NOT EXISTS(SELECT FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace CROSS JOIN LATERAL aclexplode(p.proacl) a WHERE n.nspname IN('iam','ehr','adt','lab','pharmacy','inventory','billing','audit','ops') AND a.grantee=0 AND a.privilege_type='EXECUTE'));
SELECT pg_temp.assert('21.cross_patient_condition_rejected',pg_temp.rejects($q$INSERT INTO ehr.condition(patient_id,encounter_id,concept_id,clinical_status,verification_status,onset_at,recorded_by) VALUES(2,1,1,'active','confirmed','2024-01-01 10:00+05',1)$q$,'23503'));
SELECT pg_temp.assert('22.overlapping_bed_rejected',pg_temp.rejects($q$INSERT INTO adt.bed_stay(admission_id,patient_id,bed_id,occupied_during) VALUES(1,90001,1,tstzrange('2024-01-01 11:00+05','2024-01-02 10:00+05','[)'))$q$,'23P01'));
SELECT pg_temp.assert('23.bed_outside_admission_rejected',pg_temp.rejects($q$INSERT INTO adt.bed_stay(admission_id,patient_id,bed_id,occupied_during) VALUES(1,90001,1,tstzrange('2023-01-01 10:00+05','2023-01-02 10:00+05','[)'))$q$,'23514'));
SELECT pg_temp.assert('24.overlapping_schedule_rejected',pg_temp.rejects($q$INSERT INTO scheduling.slot(schedule_id,staff_id,department_id,room_id,slot_period,status) VALUES(1,1,1,121,tstzrange('2026-10-19 08:05+05','2026-10-19 08:15+05','[)'),'free')$q$,'23P01'));
SELECT pg_temp.assert('25.unknown_patient_rejected',pg_temp.rejects($q$INSERT INTO mpi.contact(patient_id,system,value,use_code,rank) VALUES(99999999,'email','x@example.invalid','home',1)$q$,'23503'));
SELECT pg_temp.assert('26.observation_wrong_unit_rejected',pg_temp.rejects($q$INSERT INTO ehr.observation(patient_id,encounter_id,test_id,observed_at,status,value_numeric,unit_code,recorded_by) VALUES(1,1,1,'2024-01-01 08:01+05','final',80,'Cel',1)$q$,'23514'));
SELECT pg_temp.assert('27.observation_multivalue_rejected',pg_temp.rejects($q$INSERT INTO ehr.observation(patient_id,encounter_id,test_id,observed_at,status,value_numeric,value_text,unit_code,recorded_by) VALUES(1,1,1,'2024-01-01 08:01+05','final',80,'two values','1/min',1)$q$,'23514'));
SELECT pg_temp.assert('28.observation_outside_partition_rejected',pg_temp.rejects($q$INSERT INTO ehr.observation(patient_id,encounter_id,test_id,observed_at,status,value_numeric,unit_code,recorded_by) VALUES(1,1,1,'2030-01-01 08:01+05','final',80,'1/min',1)$q$,'23514'));
SELECT pg_temp.assert('29.signed_note_update_rejected',pg_temp.rejects($q$UPDATE ehr.note_version SET body='tampering' WHERE note_id=1 AND version=1$q$,'23514'));
SELECT pg_temp.assert('30.signed_note_delete_rejected',pg_temp.rejects($q$DELETE FROM ehr.note_version WHERE note_id=1 AND version=1$q$,'23514'));
SELECT pg_temp.assert('31.stock_underflow_rejected',pg_temp.rejects($q$INSERT INTO inventory.stock_movement(location_id,lot_id,quantity_delta,movement_type,occurred_at,recorded_by,reason) VALUES(1,1,-99999999,'adjustment',now(),541,'underflow test')$q$,'23514'));
SELECT pg_temp.assert('32.ledger_update_rejected',pg_temp.rejects($q$UPDATE inventory.stock_movement SET quantity_delta=100 WHERE id=1$q$,'23514'));
SELECT pg_temp.assert('33.payment_update_rejected',pg_temp.rejects($q$UPDATE billing.payment SET amount=1 WHERE id=1$q$,'23514'));
SELECT pg_temp.assert('34.issued_line_update_rejected',pg_temp.rejects($q$UPDATE billing.invoice_line SET unit_price=1 WHERE invoice_id=1 AND line_no=1$q$,'23514'));
SELECT pg_temp.assert('35.encounter_reopening_rejected',pg_temp.rejects($q$UPDATE ehr.encounter SET status='in-progress',ended_at=NULL WHERE id=1$q$,'23514'));
SELECT pg_temp.assert('36.patient_reassignment_rejected',pg_temp.rejects($q$UPDATE ehr.condition SET patient_id=2,encounter_id=2 WHERE id=1$q$,'23514'));
SELECT pg_temp.assert('37.birth_history_conflict_rejected',pg_temp.rejects($q$UPDATE mpi.patient SET birth_date='2026-01-01' WHERE id=1$q$,'23514'));
SELECT pg_temp.assert('38.audit_mutation_rejected',pg_temp.rejects($q$UPDATE audit.event SET actor='forged' WHERE id=(SELECT min(id) FROM audit.event)$q$,'23514'));
-- New versions are the supported correction path; all fixtures are rolled back below.
INSERT INTO ehr.note_version(note_id,version,body,created_at,author_id,signed_at,signed_by,supersedes_version,amendment_reason) VALUES(1,2,'Синтетическое дополнение',now(),1,now(),1,1,'Проверка корректировки');
UPDATE ehr.clinical_note SET current_version=2 WHERE id=1;
SELECT pg_temp.assert('39.signed_note_amendment_supported',(SELECT current_version=2 FROM ehr.clinical_note WHERE id=1));
INSERT INTO lab.service_request(id,patient_id,encounter_id,service_id,panel_id,ordered_by,ordered_at,priority,status) VALUES(900001,1,1,2,1,1,'2024-01-01 10:00+05','routine','completed');
INSERT INTO lab.specimen(id,patient_id,accession_number,type_code,collected_at,received_at,status,collected_by) VALUES(900001,1,'SYNTH-VALIDATION-SPEC','demo-material','2024-01-01 11:00+05','2024-01-01 12:00+05','available',241);
INSERT INTO lab.request_specimen VALUES(900001,900001,1);
INSERT INTO lab.result(id,patient_id,specimen_id,test_id,measured_at,status,value_numeric,unit_code) VALUES(900001,1,900001,5,'2024-01-01 13:00+05','final',10,'AU');
SELECT pg_temp.assert('40.wrong_order_same_patient_result_rejected',pg_temp.rejects($q$INSERT INTO lab.report_result VALUES(1,900001,1)$q$,'23514'));
SELECT pg_temp.assert('41.result_before_receipt_rejected',pg_temp.rejects($q$UPDATE lab.result SET measured_at='2023-01-01 10:00+05' WHERE id=1$q$,'23514'));
INSERT INTO billing.payment(id,patient_id,payer_id,received_at,amount,currency_code,method,external_reference) VALUES(900001,1,1,now(),100000,'KZT','transfer','SYNTH-VALIDATION-PAY');
SELECT pg_temp.assert('42.overpayment_rejected',pg_temp.rejects($q$INSERT INTO billing.payment_allocation(payment_id,invoice_id,patient_id,amount) VALUES(900001,1,1,1)$q$,'23514'));
INSERT INTO ref.currency VALUES('USD','Test currency only',2);
INSERT INTO billing.payment(id,patient_id,payer_id,received_at,amount,currency_code,method,external_reference) VALUES(900002,30001,1,now(),100000,'USD','transfer','SYNTH-VALIDATION-FX');
SELECT pg_temp.assert('43.currency_mismatch_rejected',pg_temp.rejects($q$INSERT INTO billing.payment_allocation(payment_id,invoice_id,patient_id,amount) VALUES(900002,150001,30001,1)$q$,'23514'));
-- Access control tests use the authenticated session identity, not SET ROLE alone.
SET SESSION AUTHORIZATION hospital_demo_clinician;
SELECT count(*) visible_patients FROM mpi.patient \gset clinician_
SELECT count(*) visible_encounters FROM ehr.encounter \gset clinician_
SELECT count(*) visible_note_versions FROM ehr.note_version \gset clinician_
SELECT count(*) visible_series FROM imaging.series \gset clinician_
SELECT iam.has_patient_access(101,'treatment') expired_break_glass \gset clinician_
SELECT set_config('app.user_id','4',true);
SELECT iam.has_patient_access(101,'treatment') spoofed_access \gset clinician_
SELECT pg_temp.rejects('SELECT * FROM ehr.observation_2024_01 LIMIT 1','42501') child_denied \gset clinician_
SELECT pg_temp.rejects('SELECT * FROM iam.access_grant LIMIT 1','42501') grants_denied \gset clinician_
SELECT pg_temp.rejects($q$UPDATE ehr.condition SET recorded_by=2 WHERE id=1$q$,'42501') author_spoof_denied \gset clinician_
SELECT pg_temp.rejects($q$INSERT INTO ehr.condition(patient_id,encounter_id,concept_id,clinical_status,verification_status,onset_at,recorded_by) VALUES(101,101,1,'active','confirmed','2024-01-01 10:00+05',1)$q$,'42501') denied_insert \gset clinician_
UPDATE ehr.condition SET clinical_status='remission' WHERE id=1;
SELECT audit.record_patient_access(1,'treatment','read',gen_random_uuid(),'Validation authorized access') logged_id \gset clinician_
SELECT pg_temp.rejects($q$SELECT audit.record_patient_access(101,'treatment','read',gen_random_uuid(),'Unauthorized access test')$q$,'42501') access_log_denied \gset clinician_
RESET SESSION AUTHORIZATION;
SELECT pg_temp.assert('44.clinician_scoped_patients',:'clinician_visible_patients'::int=100);
SELECT pg_temp.assert('45.clinician_scoped_encounters',:'clinician_visible_encounters'::int=300);
SELECT pg_temp.assert('46.dependent_notes_scoped',:'clinician_visible_note_versions'::int=301);
SELECT pg_temp.assert('47.dependent_dicom_scoped',:'clinician_visible_series'::int=100);
SELECT pg_temp.assert('48.expired_break_glass_denied',NOT :'clinician_expired_break_glass'::boolean);
SELECT pg_temp.assert('49.custom_guc_cannot_spoof_identity',NOT :'clinician_spoofed_access'::boolean);
SELECT pg_temp.assert('50.direct_partition_access_denied',:'clinician_child_denied'::boolean);
SELECT pg_temp.assert('51.self_grant_denied',:'clinician_grants_denied'::boolean);
SELECT pg_temp.assert('52.author_impersonation_denied',:'clinician_author_spoof_denied'::boolean);
SELECT pg_temp.assert('53.patient_write_rls_enforced',:'clinician_denied_insert'::boolean);
SELECT pg_temp.assert('54.audit_captures_actual_actor',EXISTS(SELECT FROM audit.event WHERE actor='hospital_demo_clinician' AND table_schema='ehr' AND table_name='condition' AND operation='UPDATE'));
SELECT pg_temp.assert('55.access_log_authorized',(SELECT actor='hospital_demo_clinician' FROM audit.access_event WHERE id=:'clinician_logged_id'::bigint));
SELECT pg_temp.assert('56.access_log_unauthorized_denied',:'clinician_access_log_denied'::boolean);
SET SESSION AUTHORIZATION hospital_demo_registrar;
SELECT count(*) visible_patients FROM mpi.patient \gset registrar_
SELECT pg_temp.rejects('SELECT * FROM ehr.clinical_note LIMIT 1','42501') clinical_denied \gset registrar_
RESET SESSION AUTHORIZATION;
SELECT pg_temp.assert('57.registrar_scope',:'registrar_visible_patients'::int=100);
SELECT pg_temp.assert('58.registrar_clinical_text_denied',:'registrar_clinical_denied'::boolean);
SET SESSION AUTHORIZATION hospital_demo_billing;
SELECT count(*) visible_invoices FROM billing.invoice \gset bill_
SELECT count(*) masked_identities FROM billing.v_patient_identity \gset bill_
SELECT pg_temp.rejects('SELECT * FROM mpi.patient LIMIT 1','42501') demographics_denied \gset bill_
RESET SESSION AUTHORIZATION;
SELECT pg_temp.assert('59.billing_patient_scope',:'bill_visible_invoices'::int=200);
SELECT pg_temp.assert('60.billing_masked_identity_scope',:'bill_masked_identities'::int=100);
SELECT pg_temp.assert('61.billing_full_demographics_denied',:'bill_demographics_denied'::boolean);
SET ROLE hospital_analyst;
SELECT count(*) aggregate_rows FROM analytics.daily_activity \gset analyst_
SELECT pg_temp.rejects('SELECT * FROM mpi.patient LIMIT 1','42501') patient_denied \gset analyst_
RESET ROLE;
SELECT pg_temp.assert('62.analyst_aggregate_access',:'analyst_aggregate_rows'::int>1000);
SELECT pg_temp.assert('63.analyst_patient_access_denied',:'analyst_patient_denied'::boolean);
SET ROLE hospital_auditor;
SELECT count(*) audit_rows FROM audit.event \gset auditor_
SELECT pg_temp.rejects('DELETE FROM audit.event','42501') mutation_denied \gset auditor_
RESET ROLE;
SELECT pg_temp.assert('64.auditor_read_access',:'auditor_audit_rows'::int>50);
SELECT pg_temp.assert('65.auditor_mutation_denied',:'auditor_mutation_denied'::boolean);
SELECT pg_temp.assert('66.patient_geography_valid',NOT EXISTS(SELECT FROM mpi.address WHERE location IS NULL OR NOT ext.ST_IsValid(location::ext.geometry)));
SELECT pg_temp.assert('67.note_hash_valid',NOT EXISTS(SELECT FROM ehr.note_version WHERE body_sha256<>ext.digest(body,'sha256')));
SELECT pg_temp.assert('68.current_inpatient_census',(SELECT count(*)=300 FROM adt.admission WHERE discharged_at IS NULL));
SELECT pg_temp.assert('69.over_administration_rejected',pg_temp.rejects($q$INSERT INTO pharmacy.administration(patient_id,order_id,dispense_id,administered_at,status,quantity,unit_code,performed_by) VALUES(1,1,1,now(),'completed',1,'each',241)$q$,'23514'));
SELECT pg_temp.assert('70.signer_impersonation_rejected',pg_temp.rejects($q$INSERT INTO ehr.note_version(note_id,version,body,created_at,author_id,signed_at,signed_by,supersedes_version,amendment_reason) VALUES(1,3,'test',now(),1,now(),2,2,'test')$q$,'23514'));
SELECT pg_temp.assert('71.coverage_payer_mismatch_rejected',pg_temp.rejects($q$INSERT INTO billing.invoice(patient_id,encounter_id,invoice_number,payer_id,coverage_id,issued_at,due_at,status,currency_code) VALUES(1,1,'SYNTH-BAD-PAYER',2,1,now(),now(),'draft','KZT')$q$,'23514'));
SELECT pg_temp.assert('72.imaging_modality_consistent',NOT EXISTS(SELECT FROM imaging.study s JOIN org.device d ON d.id=s.device_id WHERE s.modality<>d.modality));
SELECT pg_temp.assert('73.laboratory_analyzer_consistent',NOT EXISTS(SELECT FROM lab.result r JOIN org.device d ON d.id=r.analyzer_id WHERE d.modality<>'LAB'));
INSERT INTO inventory.lot(id,item_id,lot_number,expires_on,supplier_id,received_on) VALUES(900003,1,'SYNTH-EXPIRED-LOT','2023-12-31',1,'2023-01-01');
SELECT pg_temp.assert('74.expired_lot_rejected',pg_temp.rejects($q$INSERT INTO pharmacy.dispense(patient_id,order_id,medication_id,item_id,lot_id,location_id,quantity,dispensed_at,dispensed_by) VALUES(1,1,1,1,900003,1,1,'2024-01-01 09:00+05',541)$q$,'23514'));
SELECT pg_temp.assert('75.wrong_medication_rejected',pg_temp.rejects($q$INSERT INTO pharmacy.dispense(patient_id,order_id,medication_id,item_id,lot_id,location_id,quantity,dispensed_at,dispensed_by) VALUES(1,1,2,2,2,1,1,'2024-01-01 09:00+05',541)$q$,'23503'));
SELECT pg_temp.assert('76.slot_outside_schedule_rejected',pg_temp.rejects($q$INSERT INTO scheduling.slot(schedule_id,staff_id,department_id,room_id,slot_period,status) VALUES(1,1,1,121,tstzrange('2030-01-01 10:00+05','2030-01-01 10:20+05','[)'),'free')$q$,'23514'));
SELECT pg_temp.assert('77.receipt_before_collection_rejected',pg_temp.rejects($q$INSERT INTO lab.specimen(patient_id,accession_number,type_code,collected_at,received_at,status,collected_by) VALUES(1,'SYNTH-BAD-RECEIPT','demo-material','2024-01-01 12:00+05','2024-01-01 11:00+05','available',241)$q$,'23514'));
INSERT INTO ehr.encounter(id,patient_id,type_code,department_id,attending_staff_id,status,started_at,ended_at) VALUES(900003,90001,'inpatient',1,1,'finished','2024-01-01 10:00+05','2024-01-05 10:00+05');
SELECT pg_temp.assert('78.concurrent_patient_admission_rejected',pg_temp.rejects($q$INSERT INTO adt.admission(patient_id,encounter_id,admission_number,admitted_at,discharged_at,admission_source) VALUES(90001,900003,'SYNTH-DOUBLE-ADMISSION','2024-01-01 10:00+05','2024-01-05 10:00+05','referral')$q$,'23P01'));
SELECT pg_temp.assert('79.encounter_after_death_rejected',pg_temp.rejects($q$INSERT INTO ehr.encounter(patient_id,type_code,department_id,attending_staff_id,status,started_at,ended_at) VALUES(120002,'outpatient',1,1,'finished','2026-10-01 10:00+05','2026-10-01 10:30+05')$q$,'23514'));
SELECT pg_temp.assert('80.encounter_before_birth_rejected',pg_temp.rejects($q$INSERT INTO ehr.encounter(patient_id,type_code,department_id,attending_staff_id,status,started_at,ended_at) VALUES(1,'outpatient',1,1,'finished','1900-01-01 10:00+05','1900-01-01 10:30+05')$q$,'23514'));
INSERT INTO scheduling.slot(id,schedule_id,staff_id,department_id,room_id,slot_period,status) VALUES(900002,2,2,2,122,tstzrange('2027-01-01 08:00+05','2027-01-01 08:20+05','[)'),'busy'),(900003,3,3,3,123,tstzrange('2027-01-01 08:00+05','2027-01-01 08:20+05','[)'),'busy');
INSERT INTO scheduling.appointment(patient_id,slot_id,service_id,status,created_at) VALUES(1,900002,1,'booked',now());
SELECT pg_temp.assert('81.patient_double_booking_rejected',pg_temp.rejects($q$INSERT INTO scheduling.appointment(patient_id,slot_id,service_id,status,created_at) VALUES(1,900003,1,'booked',now())$q$,'23P01'));
SELECT pg_temp.assert('82.booked_slot_period_change_rejected',pg_temp.rejects($q$UPDATE scheduling.slot SET slot_period=tstzrange('2027-01-02 08:00+05','2027-01-02 08:20+05','[)') WHERE id=1$q$,'23514'));
SELECT pg_temp.assert('83.public_database_connect_revoked',NOT EXISTS(SELECT FROM pg_database d CROSS JOIN LATERAL aclexplode(coalesce(d.datacl,acldefault('d',d.datdba))) a WHERE d.datname=current_database() AND a.grantee=0 AND a.privilege_type='CONNECT'));
TABLE validation_result;
SELECT count(*) tests,count(*) FILTER(WHERE passed) passed,count(*) FILTER(WHERE NOT passed) failed FROM validation_result;
\copy (SELECT * FROM validation_result ORDER BY test_name) TO 'validation_results.csv' WITH(FORMAT CSV,HEADER,ENCODING 'UTF8')
DO $$BEGIN IF EXISTS(SELECT FROM validation_result WHERE NOT passed) THEN RAISE EXCEPTION 'Validation failed; inspect validation_results.csv'; END IF; END$$;
-- Deliberately leave no test patients, payments, note amendments, authorizations or audit artifacts.
ROLLBACK;
