\set ON_ERROR_STOP on
BEGIN;
SET SESSION AUTHORIZATION hospital_demo_registrar;
WITH changed AS(UPDATE mpi.patient SET birth_date=birth_date+1 WHERE id=1 RETURNING id)
SELECT count(*) changed FROM changed \gset reg_patient_
WITH changed AS(UPDATE scheduling.appointment SET status='arrived' WHERE id=1 RETURNING id)
SELECT count(*) changed FROM changed \gset reg_appointment_
RESET SESSION AUTHORIZATION;
SELECT 1 / ((:'reg_patient_changed'::int=1 AND :'reg_appointment_changed'::int=1)::int) AS both_write_paths_validated;
DO $$BEGIN IF NOT EXISTS(SELECT FROM audit.event WHERE actor='hospital_demo_registrar' AND table_schema='mpi' AND table_name='patient' AND operation='UPDATE') OR NOT EXISTS(SELECT FROM audit.event WHERE actor='hospital_demo_registrar' AND table_schema='scheduling' AND table_name='appointment' AND operation='UPDATE') THEN RAISE EXCEPTION 'Registrar write workflow audit validation failed'; END IF; END$$;
SELECT 'REGISTRAR_WRITE_WORKFLOWS_PASS' result;
ROLLBACK;
