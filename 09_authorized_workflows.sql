\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE hospital_owner;
-- Triggers may inspect protected parent data, while callers retain only their intended column grants.
-- Both functions already have a fixed pg_catalog search_path and schema-qualified object references.
ALTER FUNCTION ehr.guard_patient_dates() SECURITY DEFINER;
ALTER FUNCTION scheduling.guard_appointment_period() SECURITY DEFINER;
INSERT INTO ops.schema_migration VALUES('09',clock_timestamp(),'Authorized registrar updates use narrow definer triggers without granting access to clinical history or slot mutation');
COMMIT;
-- Exercise the actual write grants as a registrar; retain no changed patient or appointment.
BEGIN;
SET SESSION AUTHORIZATION hospital_demo_registrar;
UPDATE mpi.patient SET birth_date=birth_date+1 WHERE id=1 RETURNING id;
UPDATE scheduling.appointment SET status='arrived' WHERE id=1 RETURNING id,status;
RESET SESSION AUTHORIZATION;
DO $$BEGIN IF NOT EXISTS(SELECT FROM audit.event WHERE actor='hospital_demo_registrar' AND table_schema='mpi' AND table_name='patient' AND operation='UPDATE') OR NOT EXISTS(SELECT FROM audit.event WHERE actor='hospital_demo_registrar' AND table_schema='scheduling' AND table_name='appointment' AND operation='UPDATE') THEN RAISE EXCEPTION 'Registrar write workflow audit validation failed'; END IF; END$$;
SELECT 'REGISTRAR_WRITE_WORKFLOWS_PASS' result;
ROLLBACK;
