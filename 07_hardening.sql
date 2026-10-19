\set ON_ERROR_STOP on
SET ROLE hospital_owner;
SET search_path=pg_catalog,ext,public;
BEGIN;
CREATE FUNCTION ehr.guard_patient_identity() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$BEGIN IF NEW.patient_id IS DISTINCT FROM OLD.patient_id THEN RAISE EXCEPTION 'Clinical patient identity is immutable; use an audited correction workflow' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;
DO $$DECLARE r record; BEGIN FOR r IN SELECT n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid AND a.attname='patient_id' WHERE c.relkind IN('r','p') AND NOT c.relispartition AND n.nspname IN('ehr','adt','lab','imaging','pharmacy','billing','quality') LOOP EXECUTE format('CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON %I.%I FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()',r.nspname,r.relname); END LOOP; END$$;
CREATE FUNCTION ehr.guard_clinical_author() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$DECLARE expected bigint; supplied bigint; BEGIN SELECT staff_id INTO expected FROM iam.application_user WHERE database_principal=session_user AND active; IF expected IS NULL AND (SELECT rolsuper FROM pg_roles WHERE rolname=session_user) THEN RETURN NEW; END IF; supplied:=(to_jsonb(NEW)->>TG_ARGV[0])::bigint; IF expected IS NULL OR supplied IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Clinical author does not match authenticated staff member' USING ERRCODE='42501'; END IF; RETURN NEW; END$$;
CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.condition FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('recorded_by');
CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.allergy FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('recorded_by');
CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.observation FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('recorded_by');
CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.clinical_note FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('author_id');
CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.note_version FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('author_id');
CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.care_plan FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('author_id');
CREATE FUNCTION adt.guard_discharge() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$DECLARE a adt.admission; BEGIN SELECT * INTO a FROM adt.admission WHERE id=NEW.admission_id FOR SHARE; IF a.discharged_at IS DISTINCT FROM NEW.discharged_at THEN RAISE EXCEPTION 'Discharge instant must equal admission discharge instant' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;
CREATE TRIGGER discharge_instant_guard BEFORE INSERT OR UPDATE ON adt.discharge FOR EACH ROW EXECUTE FUNCTION adt.guard_discharge();
-- Separate imaging equipment from laboratory analyzers in the generated asset catalog.
UPDATE org.device SET modality='LAB',name='Учебный лабораторный анализатор '||id WHERE id>60;
UPDATE imaging.study SET device_id=1+(id%4) WHERE device_id<>1+(id%4);
UPDATE lab.result SET analyzer_id=61+(specimen_id%30) WHERE analyzer_id<>61+(specimen_id%30);
CREATE FUNCTION imaging.guard_modality() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$DECLARE m text; BEGIN SELECT modality INTO m FROM org.device WHERE id=NEW.device_id; IF m IS DISTINCT FROM NEW.modality THEN RAISE EXCEPTION 'Study modality differs from device modality' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;
CREATE TRIGGER study_modality_guard BEFORE INSERT OR UPDATE ON imaging.study FOR EACH ROW EXECUTE FUNCTION imaging.guard_modality();
REVOKE ALL ON FUNCTION imaging.guard_modality() FROM PUBLIC;
CREATE FUNCTION ehr.guard_signer() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$BEGIN IF NEW.signed_at IS NOT NULL AND NEW.signed_by IS DISTINCT FROM NEW.author_id THEN RAISE EXCEPTION 'Signer must be the author; countersignature requires a separate workflow' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;
CREATE TRIGGER signer_identity BEFORE INSERT OR UPDATE ON ehr.note_version FOR EACH ROW EXECUTE FUNCTION ehr.guard_signer();
CREATE FUNCTION pharmacy.guard_administration_quantity() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$DECLARE supplied numeric; used numeric; u text; BEGIN IF NEW.status='completed' AND NEW.dispense_id IS NOT NULL THEN SELECT d.quantity,m.unit_code INTO supplied,u FROM pharmacy.dispense d JOIN pharmacy.medication_order o ON o.id=d.order_id JOIN ref.medication m ON m.id=o.medication_id WHERE d.id=NEW.dispense_id FOR UPDATE OF d; SELECT coalesce(sum(quantity),0) INTO used FROM pharmacy.administration WHERE dispense_id=NEW.dispense_id AND status='completed'; IF NEW.unit_code IS DISTINCT FROM u OR used+NEW.quantity>supplied THEN RAISE EXCEPTION 'Administration exceeds dispensed quantity or uses a different unit' USING ERRCODE='23514'; END IF; END IF; RETURN NEW; END$$;
CREATE TRIGGER administration_quantity_guard BEFORE INSERT ON pharmacy.administration FOR EACH ROW EXECUTE FUNCTION pharmacy.guard_administration_quantity();
CREATE FUNCTION billing.guard_coverage() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$DECLARE p bigint; valid daterange; BEGIN IF NEW.coverage_id IS NOT NULL THEN SELECT payer_id,valid_during INTO p,valid FROM billing.coverage WHERE id=NEW.coverage_id; IF p IS DISTINCT FROM NEW.payer_id OR NOT(NEW.issued_at::date<@valid) THEN RAISE EXCEPTION 'Invoice payer/date does not match coverage' USING ERRCODE='23514'; END IF; END IF; RETURN NEW; END$$;
CREATE TRIGGER invoice_coverage_guard BEFORE INSERT OR UPDATE ON billing.invoice FOR EACH ROW EXECUTE FUNCTION billing.guard_coverage();
REVOKE ALL ON FUNCTION ehr.guard_signer(),pharmacy.guard_administration_quantity(),billing.guard_coverage() FROM PUBLIC;
-- Mirror the slot period under a trigger so PostgreSQL can enforce patient-level overlap too.
ALTER TABLE scheduling.appointment ADD COLUMN appointment_period tstzrange;
UPDATE scheduling.appointment a SET appointment_period=s.slot_period FROM scheduling.slot s WHERE s.id=a.slot_id;
ALTER TABLE scheduling.appointment ALTER COLUMN appointment_period SET NOT NULL;
ALTER TABLE scheduling.appointment ADD CONSTRAINT patient_appointment_no_overlap EXCLUDE USING gist(patient_id WITH =,appointment_period WITH &&) WHERE(status IN('booked','arrived','fulfilled'));
CREATE FUNCTION scheduling.guard_appointment_period() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$BEGIN SELECT slot_period INTO NEW.appointment_period FROM scheduling.slot WHERE id=NEW.slot_id FOR SHARE; RETURN NEW; END$$;
CREATE TRIGGER appointment_period_copy BEFORE INSERT OR UPDATE ON scheduling.appointment FOR EACH ROW EXECUTE FUNCTION scheduling.guard_appointment_period();
CREATE FUNCTION scheduling.guard_booked_slot() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$BEGIN IF NEW.slot_period IS DISTINCT FROM OLD.slot_period AND EXISTS(SELECT FROM scheduling.appointment WHERE slot_id=OLD.id) THEN RAISE EXCEPTION 'A booked slot period is immutable; reschedule the appointment explicitly' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;
CREATE TRIGGER booked_slot_period_guard BEFORE UPDATE OF slot_period ON scheduling.slot FOR EACH ROW EXECUTE FUNCTION scheduling.guard_booked_slot();
REVOKE ALL ON FUNCTION scheduling.guard_appointment_period(),scheduling.guard_booked_slot() FROM PUBLIC;
COMMENT ON COLUMN scheduling.appointment.appointment_period IS 'Controlled copy of slot period; trigger-maintained and protected by a patient overlap exclusion constraint.';
-- Stock balances can only be changed through the movement trigger, even by a future stock role.
REVOKE ALL ON inventory.stock_balance FROM hospital_clinician,hospital_registrar,hospital_billing;
REVOKE ALL ON FUNCTION ehr.guard_patient_identity(),ehr.guard_clinical_author(),adt.guard_discharge() FROM PUBLIC;
COMMENT ON FUNCTION ehr.guard_patient_identity() IS 'Forbids reassigning an existing clinical or financial record to another patient.';
COMMENT ON FUNCTION ehr.guard_clinical_author() IS 'Binds author field to authenticated database principal; session GUCs are never trusted for identity.';
INSERT INTO ops.schema_migration VALUES('07',clock_timestamp(),'Patient identity immutability, authenticated authorship and discharge instant consistency');
COMMIT;
