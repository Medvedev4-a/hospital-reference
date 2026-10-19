--
-- PostgreSQL database dump
--

\restrict ffO9If5sYyIPBWkQmLMJpfBkpqgifyfPu3BEdMQJLPD1riMncfdfykDhxBh4uCA

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: adt; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA adt;


ALTER SCHEMA adt OWNER TO hospital_owner;

--
-- Name: analytics; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA analytics;


ALTER SCHEMA analytics OWNER TO hospital_owner;

--
-- Name: audit; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA audit;


ALTER SCHEMA audit OWNER TO hospital_owner;

--
-- Name: billing; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA billing;


ALTER SCHEMA billing OWNER TO hospital_owner;

--
-- Name: ehr; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA ehr;


ALTER SCHEMA ehr OWNER TO hospital_owner;

--
-- Name: ext; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA ext;


ALTER SCHEMA ext OWNER TO postgres;

--
-- Name: iam; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA iam;


ALTER SCHEMA iam OWNER TO hospital_owner;

--
-- Name: imaging; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA imaging;


ALTER SCHEMA imaging OWNER TO hospital_owner;

--
-- Name: integration; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA integration;


ALTER SCHEMA integration OWNER TO hospital_owner;

--
-- Name: inventory; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA inventory;


ALTER SCHEMA inventory OWNER TO hospital_owner;

--
-- Name: lab; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA lab;


ALTER SCHEMA lab OWNER TO hospital_owner;

--
-- Name: mpi; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA mpi;


ALTER SCHEMA mpi OWNER TO hospital_owner;

--
-- Name: ops; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA ops;


ALTER SCHEMA ops OWNER TO hospital_owner;

--
-- Name: org; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA org;


ALTER SCHEMA org OWNER TO hospital_owner;

--
-- Name: pharmacy; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA pharmacy;


ALTER SCHEMA pharmacy OWNER TO hospital_owner;

--
-- Name: quality; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA quality;


ALTER SCHEMA quality OWNER TO hospital_owner;

--
-- Name: ref; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA ref;


ALTER SCHEMA ref OWNER TO hospital_owner;

--
-- Name: scheduling; Type: SCHEMA; Schema: -; Owner: hospital_owner
--

CREATE SCHEMA scheduling;


ALTER SCHEMA scheduling OWNER TO hospital_owner;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA ext;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA ext;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA ext;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA ext;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: nonblank_text; Type: DOMAIN; Schema: ref; Owner: hospital_owner
--

CREATE DOMAIN ref.nonblank_text AS text
	CONSTRAINT nonblank_text_check CHECK ((length(btrim(VALUE)) > 0));


ALTER DOMAIN ref.nonblank_text OWNER TO hospital_owner;

--
-- Name: nonnegative_money; Type: DOMAIN; Schema: ref; Owner: hospital_owner
--

CREATE DOMAIN ref.nonnegative_money AS numeric(18,2)
	CONSTRAINT nonnegative_money_check CHECK ((VALUE >= (0)::numeric));


ALTER DOMAIN ref.nonnegative_money OWNER TO hospital_owner;

--
-- Name: positive_quantity; Type: DOMAIN; Schema: ref; Owner: hospital_owner
--

CREATE DOMAIN ref.positive_quantity AS numeric(18,4)
	CONSTRAINT positive_quantity_check CHECK ((VALUE > (0)::numeric));


ALTER DOMAIN ref.positive_quantity OWNER TO hospital_owner;

--
-- Name: guard_admission(); Type: FUNCTION; Schema: adt; Owner: hospital_owner
--

CREATE FUNCTION adt.guard_admission() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$DECLARE e ehr.encounter; BEGIN SELECT * INTO e FROM ehr.encounter WHERE id=NEW.encounter_id; IF e.type_code<>'inpatient' OR NEW.admitted_at<e.started_at OR (NEW.discharged_at IS NOT NULL AND e.ended_at IS NOT NULL AND NEW.discharged_at>e.ended_at) THEN RAISE EXCEPTION 'Admission must fit an inpatient encounter' USING ERRCODE='23514'; END IF; IF TG_OP='UPDATE' AND EXISTS(SELECT FROM adt.bed_stay WHERE admission_id=NEW.id AND NOT (occupied_during <@ tstzrange(NEW.admitted_at,NEW.discharged_at,'[)'))) THEN RAISE EXCEPTION 'Admission change would orphan bed stay period' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION adt.guard_admission() OWNER TO hospital_owner;

--
-- Name: guard_bed_stay(); Type: FUNCTION; Schema: adt; Owner: hospital_owner
--

CREATE FUNCTION adt.guard_bed_stay() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$DECLARE p tstzrange; is_active boolean; BEGIN SELECT tstzrange(admitted_at,discharged_at,'[)') INTO p FROM adt.admission WHERE id=NEW.admission_id FOR SHARE; SELECT active INTO is_active FROM org.bed WHERE id=NEW.bed_id; IF NOT (NEW.occupied_during <@ p) OR NOT is_active THEN RAISE EXCEPTION 'Bed inactive or bed stay outside admission period' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION adt.guard_bed_stay() OWNER TO hospital_owner;

--
-- Name: guard_discharge(); Type: FUNCTION; Schema: adt; Owner: hospital_owner
--

CREATE FUNCTION adt.guard_discharge() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$DECLARE a adt.admission; BEGIN SELECT * INTO a FROM adt.admission WHERE id=NEW.admission_id FOR SHARE; IF a.discharged_at IS DISTINCT FROM NEW.discharged_at THEN RAISE EXCEPTION 'Discharge instant must equal admission discharge instant' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION adt.guard_discharge() OWNER TO hospital_owner;

--
-- Name: capture_change(); Type: FUNCTION; Schema: audit; Owner: hospital_owner
--

CREATE FUNCTION audit.capture_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$DECLARE oldj jsonb; newj jsonb; keyj jsonb; cols text[]; BEGIN IF TG_OP<>'INSERT' THEN oldj=to_jsonb(OLD); END IF; IF TG_OP<>'DELETE' THEN newj=to_jsonb(NEW); END IF; SELECT jsonb_object_agg(key,value) INTO keyj FROM jsonb_each(coalesce(newj,oldj)) WHERE key=ANY(TG_ARGV); IF TG_OP='UPDATE' THEN SELECT array_agg(key ORDER BY key) INTO cols FROM jsonb_each(newj) WHERE value IS DISTINCT FROM oldj->key; END IF; INSERT INTO audit.event(actor,transaction_id,table_schema,table_name,operation,entity_key,changed_columns,request_id) VALUES(session_user,txid_current(),TG_TABLE_SCHEMA,TG_TABLE_NAME,TG_OP,coalesce(keyj,'{}'),cols,left(current_setting('app.request_id',true),100)); IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW; END$$;


ALTER FUNCTION audit.capture_change() OWNER TO hospital_owner;

--
-- Name: record_patient_access(bigint, text, text, uuid, text); Type: FUNCTION; Schema: audit; Owner: hospital_owner
--

CREATE FUNCTION audit.record_patient_access(p_patient_id bigint, p_purpose text, p_action text, p_request_id uuid, p_reason text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$DECLARE rid bigint; BEGIN IF NOT iam.has_patient_access(p_patient_id,p_purpose) THEN RAISE EXCEPTION 'Patient access denied' USING ERRCODE='42501'; END IF; IF p_reason IS NULL OR length(btrim(p_reason))<5 THEN RAISE EXCEPTION 'Access reason required' USING ERRCODE='23514'; END IF; INSERT INTO audit.access_event(actor,patient_id,purpose,action,request_id,reason) VALUES(session_user,p_patient_id,p_purpose,p_action,p_request_id,p_reason) RETURNING id INTO rid; RETURN rid; END$$;


ALTER FUNCTION audit.record_patient_access(p_patient_id bigint, p_purpose text, p_action text, p_request_id uuid, p_reason text) OWNER TO hospital_owner;

--
-- Name: guard_allocation(); Type: FUNCTION; Schema: billing; Owner: hospital_owner
--

CREATE FUNCTION billing.guard_allocation() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$DECLARE pc char(3); ic char(3); paid numeric; billed numeric; pa numeric; ia numeric; ps bigint; ips bigint; st text; BEGIN SELECT currency_code,amount,payer_id INTO pc,paid,ps FROM billing.payment WHERE id=NEW.payment_id FOR UPDATE; SELECT currency_code,payer_id,status INTO ic,ips,st FROM billing.invoice WHERE id=NEW.invoice_id FOR UPDATE; IF pc<>ic OR ps<>ips OR st<>'issued' THEN RAISE EXCEPTION 'Allocation currency, payer or invoice status mismatch' USING ERRCODE='23514'; END IF; SELECT coalesce(sum(amount),0) INTO pa FROM billing.payment_allocation WHERE payment_id=NEW.payment_id; SELECT coalesce(sum(amount),0) INTO ia FROM billing.payment_allocation WHERE invoice_id=NEW.invoice_id; SELECT coalesce(sum(net_amount+tax_amount),0) INTO billed FROM billing.invoice_line WHERE invoice_id=NEW.invoice_id; IF pa+NEW.amount>paid OR ia+NEW.amount>billed THEN RAISE EXCEPTION 'Allocation exceeds payment or invoice balance' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION billing.guard_allocation() OWNER TO hospital_owner;

--
-- Name: guard_coverage(); Type: FUNCTION; Schema: billing; Owner: hospital_owner
--

CREATE FUNCTION billing.guard_coverage() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$DECLARE p bigint; valid daterange; BEGIN IF NEW.coverage_id IS NOT NULL THEN SELECT payer_id,valid_during INTO p,valid FROM billing.coverage WHERE id=NEW.coverage_id; IF p IS DISTINCT FROM NEW.payer_id OR NOT(NEW.issued_at::date<@valid) THEN RAISE EXCEPTION 'Invoice payer/date does not match coverage' USING ERRCODE='23514'; END IF; END IF; RETURN NEW; END$$;


ALTER FUNCTION billing.guard_coverage() OWNER TO hospital_owner;

--
-- Name: guard_invoice(); Type: FUNCTION; Schema: billing; Owner: hospital_owner
--

CREATE FUNCTION billing.guard_invoice() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$BEGIN IF OLD.status='void' OR (OLD.status='issued' AND (NEW.status<>'void' OR EXISTS(SELECT FROM billing.payment_allocation WHERE invoice_id=OLD.id))) THEN RAISE EXCEPTION 'Issued invoice is immutable; void unpaid invoice or use adjustment workflow' USING ERRCODE='23514'; END IF; IF NEW.patient_id<>OLD.patient_id OR NEW.encounter_id<>OLD.encounter_id OR NEW.payer_id<>OLD.payer_id OR NEW.currency_code<>OLD.currency_code THEN RAISE EXCEPTION 'Invoice identity/currency immutable' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION billing.guard_invoice() OWNER TO hospital_owner;

--
-- Name: guard_invoice_line(); Type: FUNCTION; Schema: billing; Owner: hospital_owner
--

CREATE FUNCTION billing.guard_invoice_line() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$DECLARE st text; iid bigint; BEGIN iid:=CASE WHEN TG_OP='DELETE' THEN OLD.invoice_id ELSE NEW.invoice_id END; SELECT status INTO st FROM billing.invoice WHERE id=iid FOR UPDATE; IF st<>'draft' THEN RAISE EXCEPTION 'Only draft invoice lines can be changed' USING ERRCODE='23514'; END IF; IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW; END$$;


ALTER FUNCTION billing.guard_invoice_line() OWNER TO hospital_owner;

--
-- Name: guard_administration(); Type: FUNCTION; Schema: ehr; Owner: hospital_owner
--

CREATE FUNCTION ehr.guard_administration() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$DECLARE dispense_order bigint; t timestamptz; BEGIN IF NEW.dispense_id IS NOT NULL THEN SELECT order_id,dispensed_at INTO dispense_order,t FROM pharmacy.dispense WHERE id=NEW.dispense_id; IF dispense_order<>NEW.order_id OR NEW.administered_at<t THEN RAISE EXCEPTION 'Administration conflicts with dispensing order/time' USING ERRCODE='23514'; END IF; END IF; RETURN NEW; END$$;


ALTER FUNCTION ehr.guard_administration() OWNER TO hospital_owner;

--
-- Name: guard_clinical_author(); Type: FUNCTION; Schema: ehr; Owner: hospital_owner
--

CREATE FUNCTION ehr.guard_clinical_author() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$DECLARE expected bigint; supplied bigint; BEGIN SELECT staff_id INTO expected FROM iam.application_user WHERE database_principal=session_user AND active; IF expected IS NULL AND (SELECT rolsuper FROM pg_roles WHERE rolname=session_user) THEN RETURN NEW; END IF; supplied:=(to_jsonb(NEW)->>TG_ARGV[0])::bigint; IF expected IS NULL OR supplied IS DISTINCT FROM expected THEN RAISE EXCEPTION 'Clinical author does not match authenticated staff member' USING ERRCODE='42501'; END IF; RETURN NEW; END$$;


ALTER FUNCTION ehr.guard_clinical_author() OWNER TO hospital_owner;

--
-- Name: FUNCTION guard_clinical_author(); Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON FUNCTION ehr.guard_clinical_author() IS 'Binds author field to authenticated database principal; session GUCs are never trusted for identity.';


--
-- Name: guard_encounter(); Type: FUNCTION; Schema: ehr; Owner: hospital_owner
--

CREATE FUNCTION ehr.guard_encounter() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$DECLARE dob date; dod timestamptz; BEGIN SELECT birth_date,deceased_at INTO dob,dod FROM mpi.patient WHERE id=NEW.patient_id; IF NEW.started_at::date<dob THEN RAISE EXCEPTION 'Encounter precedes birth' USING ERRCODE='23514'; END IF; IF dod IS NOT NULL AND NEW.started_at>dod THEN RAISE EXCEPTION 'Encounter after recorded death' USING ERRCODE='23514'; END IF; IF TG_OP='UPDATE' AND (NEW.patient_id<>OLD.patient_id OR NEW.started_at<>OLD.started_at) THEN RAISE EXCEPTION 'Patient and start time of encounter are immutable' USING ERRCODE='23514'; END IF; IF TG_OP='UPDATE' AND NEW.status<>OLD.status AND NOT ((OLD.status='planned' AND NEW.status IN('in-progress','cancelled')) OR (OLD.status='in-progress' AND NEW.status IN('finished','cancelled'))) THEN RAISE EXCEPTION 'Invalid encounter status transition' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION ehr.guard_encounter() OWNER TO hospital_owner;

--
-- Name: guard_note_version(); Type: FUNCTION; Schema: ehr; Owner: hospital_owner
--

CREATE FUNCTION ehr.guard_note_version() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$BEGIN IF OLD.signed_at IS NOT NULL THEN RAISE EXCEPTION 'Signed note is immutable; append an amendment' USING ERRCODE='23514'; END IF; IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW; END$$;


ALTER FUNCTION ehr.guard_note_version() OWNER TO hospital_owner;

--
-- Name: guard_observation(); Type: FUNCTION; Schema: ehr; Owner: hospital_owner
--

CREATE FUNCTION ehr.guard_observation() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$DECLARE k text; u text; BEGIN SELECT value_type,unit_code INTO k,u FROM ref.test WHERE id=NEW.test_id; IF k IS NULL THEN RETURN NEW; END IF; IF (k='numeric' AND (NEW.value_numeric IS NULL OR NEW.unit_code IS DISTINCT FROM u)) OR (k='text' AND NEW.value_text IS NULL) OR (k='coded' AND NEW.value_concept_id IS NULL) OR (k='boolean' AND NEW.value_boolean IS NULL) THEN RAISE EXCEPTION 'Observation value type/unit does not match catalog' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION ehr.guard_observation() OWNER TO hospital_owner;

--
-- Name: guard_patient_dates(); Type: FUNCTION; Schema: ehr; Owner: hospital_owner
--

CREATE FUNCTION ehr.guard_patient_dates() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$BEGIN IF NEW.birth_date>OLD.birth_date AND EXISTS(SELECT FROM ehr.encounter WHERE patient_id=NEW.id AND started_at::date<NEW.birth_date) THEN RAISE EXCEPTION 'Birth date conflicts with encounter history' USING ERRCODE='23514'; END IF; IF NEW.deceased_at IS NOT NULL AND EXISTS(SELECT FROM ehr.encounter WHERE patient_id=NEW.id AND started_at>NEW.deceased_at) THEN RAISE EXCEPTION 'Death date conflicts with encounter history' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION ehr.guard_patient_dates() OWNER TO hospital_owner;

--
-- Name: guard_patient_identity(); Type: FUNCTION; Schema: ehr; Owner: hospital_owner
--

CREATE FUNCTION ehr.guard_patient_identity() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$BEGIN IF NEW.patient_id IS DISTINCT FROM OLD.patient_id THEN RAISE EXCEPTION 'Clinical patient identity is immutable; use an audited correction workflow' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION ehr.guard_patient_identity() OWNER TO hospital_owner;

--
-- Name: FUNCTION guard_patient_identity(); Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON FUNCTION ehr.guard_patient_identity() IS 'Forbids reassigning an existing clinical or financial record to another patient.';


--
-- Name: guard_signer(); Type: FUNCTION; Schema: ehr; Owner: hospital_owner
--

CREATE FUNCTION ehr.guard_signer() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$BEGIN IF NEW.signed_at IS NOT NULL AND NEW.signed_by IS DISTINCT FROM NEW.author_id THEN RAISE EXCEPTION 'Signer must be the author; countersignature requires a separate workflow' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION ehr.guard_signer() OWNER TO hospital_owner;

--
-- Name: has_patient_access(bigint, text); Type: FUNCTION; Schema: iam; Owner: hospital_owner
--

CREATE FUNCTION iam.has_patient_access(p_patient_id bigint, p_purpose text DEFAULT 'treatment'::text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$ SELECT EXISTS(SELECT FROM iam.application_user u JOIN iam.user_role ur ON ur.user_id=u.id WHERE u.database_principal=session_user AND u.active AND ((p_purpose='treatment' AND ur.role_code='clinician') OR (p_purpose='registration' AND ur.role_code='registrar') OR (p_purpose='billing' AND ur.role_code='billing')) AND (EXISTS(SELECT FROM iam.access_grant g WHERE g.user_id=u.id AND g.patient_id=p_patient_id AND g.purpose=p_purpose AND statement_timestamp()<@g.valid_during) OR (p_purpose='treatment' AND EXISTS(SELECT FROM iam.break_glass b WHERE b.user_id=u.id AND b.patient_id=p_patient_id AND statement_timestamp()<@b.valid_during)))) $$;


ALTER FUNCTION iam.has_patient_access(p_patient_id bigint, p_purpose text) OWNER TO hospital_owner;

--
-- Name: guard_modality(); Type: FUNCTION; Schema: imaging; Owner: hospital_owner
--

CREATE FUNCTION imaging.guard_modality() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$DECLARE m text; BEGIN SELECT modality INTO m FROM org.device WHERE id=NEW.device_id; IF m IS DISTINCT FROM NEW.modality THEN RAISE EXCEPTION 'Study modality differs from device modality' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION imaging.guard_modality() OWNER TO hospital_owner;

--
-- Name: guard_movement(); Type: FUNCTION; Schema: inventory; Owner: hospital_owner
--

CREATE FUNCTION inventory.guard_movement() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$BEGIN IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Stock ledger is append-only; post compensating entry' USING ERRCODE='23514'; END IF; INSERT INTO inventory.stock_balance(location_id,lot_id,quantity) VALUES(NEW.location_id,NEW.lot_id,0) ON CONFLICT DO NOTHING; UPDATE inventory.stock_balance SET quantity=quantity+NEW.quantity_delta,updated_at=clock_timestamp() WHERE location_id=NEW.location_id AND lot_id=NEW.lot_id; RETURN NEW; END$$;


ALTER FUNCTION inventory.guard_movement() OWNER TO hospital_owner;

--
-- Name: guard_report_result(); Type: FUNCTION; Schema: lab; Owner: hospital_owner
--

CREATE FUNCTION lab.guard_report_result() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$BEGIN IF NOT EXISTS(SELECT FROM lab.diagnostic_report d JOIN lab.request_specimen rs ON rs.request_id=d.request_id AND rs.patient_id=d.patient_id JOIN lab.result r ON r.specimen_id=rs.specimen_id AND r.patient_id=rs.patient_id WHERE d.id=NEW.report_id AND r.id=NEW.result_id) THEN RAISE EXCEPTION 'Result specimen does not belong to report request' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION lab.guard_report_result() OWNER TO hospital_owner;

--
-- Name: guard_result(); Type: FUNCTION; Schema: lab; Owner: hospital_owner
--

CREATE FUNCTION lab.guard_result() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$DECLARE received timestamptz; k text; u text; BEGIN SELECT coalesce(received_at,collected_at) INTO received FROM lab.specimen WHERE id=NEW.specimen_id; SELECT value_type,unit_code INTO k,u FROM ref.test WHERE id=NEW.test_id; IF NEW.measured_at<received OR (k='numeric' AND (NEW.value_numeric IS NULL OR NEW.unit_code IS DISTINCT FROM u)) OR (k='text' AND NEW.value_text IS NULL) OR k IN('boolean','coded') THEN RAISE EXCEPTION 'Result timing, type or unit mismatch' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION lab.guard_result() OWNER TO hospital_owner;

--
-- Name: deny_mutation(); Type: FUNCTION; Schema: ops; Owner: hospital_owner
--

CREATE FUNCTION ops.deny_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN RAISE EXCEPTION 'Append-only record: mutation denied' USING ERRCODE='23514'; END$$;


ALTER FUNCTION ops.deny_mutation() OWNER TO hospital_owner;

--
-- Name: touch_row(); Type: FUNCTION; Schema: ops; Owner: hospital_owner
--

CREATE FUNCTION ops.touch_row() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN NEW.updated_at=clock_timestamp(); NEW.row_version=OLD.row_version+1; RETURN NEW; END$$;


ALTER FUNCTION ops.touch_row() OWNER TO hospital_owner;

--
-- Name: guard_administration_quantity(); Type: FUNCTION; Schema: pharmacy; Owner: hospital_owner
--

CREATE FUNCTION pharmacy.guard_administration_quantity() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$DECLARE supplied numeric; used numeric; u text; BEGIN IF NEW.status='completed' AND NEW.dispense_id IS NOT NULL THEN SELECT d.quantity,m.unit_code INTO supplied,u FROM pharmacy.dispense d JOIN pharmacy.medication_order o ON o.id=d.order_id JOIN ref.medication m ON m.id=o.medication_id WHERE d.id=NEW.dispense_id FOR UPDATE OF d; SELECT coalesce(sum(quantity),0) INTO used FROM pharmacy.administration WHERE dispense_id=NEW.dispense_id AND status='completed'; IF NEW.unit_code IS DISTINCT FROM u OR used+NEW.quantity>supplied THEN RAISE EXCEPTION 'Administration exceeds dispensed quantity or uses a different unit' USING ERRCODE='23514'; END IF; END IF; RETURN NEW; END$$;


ALTER FUNCTION pharmacy.guard_administration_quantity() OWNER TO hospital_owner;

--
-- Name: guard_dispense(); Type: FUNCTION; Schema: pharmacy; Owner: hospital_owner
--

CREATE FUNCTION pharmacy.guard_dispense() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$DECLARE correct_med int; exp date; order_status text; p tstzrange; BEGIN SELECT i.medication_id,l.expires_on INTO correct_med,exp FROM inventory.item i JOIN inventory.lot l ON l.item_id=i.id WHERE l.id=NEW.lot_id; SELECT status,valid_during INTO order_status,p FROM pharmacy.medication_order WHERE id=NEW.order_id; IF correct_med IS DISTINCT FROM NEW.medication_id OR exp<NEW.dispensed_at::date OR order_status NOT IN('active','completed') OR NOT (NEW.dispensed_at <@ p) THEN RAISE EXCEPTION 'Dispense medication, expiry, order status or validity mismatch' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION pharmacy.guard_dispense() OWNER TO hospital_owner;

--
-- Name: post_dispense(); Type: FUNCTION; Schema: pharmacy; Owner: hospital_owner
--

CREATE FUNCTION pharmacy.post_dispense() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$BEGIN INSERT INTO inventory.stock_movement(location_id,lot_id,quantity_delta,movement_type,occurred_at,recorded_by,dispense_id,idempotency_key,reason) VALUES(NEW.location_id,NEW.lot_id,-NEW.quantity,'dispense',NEW.dispensed_at,NEW.dispensed_by,NEW.id,NEW.idempotency_key,'Medication dispensing'); RETURN NEW; END$$;


ALTER FUNCTION pharmacy.post_dispense() OWNER TO hospital_owner;

--
-- Name: guard_appointment_period(); Type: FUNCTION; Schema: scheduling; Owner: hospital_owner
--

CREATE FUNCTION scheduling.guard_appointment_period() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$BEGIN SELECT slot_period INTO NEW.appointment_period FROM scheduling.slot WHERE id=NEW.slot_id FOR SHARE; RETURN NEW; END$$;


ALTER FUNCTION scheduling.guard_appointment_period() OWNER TO hospital_owner;

--
-- Name: guard_booked_slot(); Type: FUNCTION; Schema: scheduling; Owner: hospital_owner
--

CREATE FUNCTION scheduling.guard_booked_slot() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$BEGIN IF NEW.slot_period IS DISTINCT FROM OLD.slot_period AND EXISTS(SELECT FROM scheduling.appointment WHERE slot_id=OLD.id) THEN RAISE EXCEPTION 'A booked slot period is immutable; reschedule the appointment explicitly' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION scheduling.guard_booked_slot() OWNER TO hospital_owner;

--
-- Name: guard_slot(); Type: FUNCTION; Schema: scheduling; Owner: hospital_owner
--

CREATE FUNCTION scheduling.guard_slot() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$DECLARE p daterange; BEGIN SELECT valid_during INTO p FROM scheduling.schedule WHERE id=NEW.schedule_id; IF NOT (lower(NEW.slot_period)::date <@ p) OR NOT ((upper(NEW.slot_period)-interval '1 microsecond')::date <@ p) THEN RAISE EXCEPTION 'Slot outside schedule dates' USING ERRCODE='23514'; END IF; RETURN NEW; END$$;


ALTER FUNCTION scheduling.guard_slot() OWNER TO hospital_owner;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admission; Type: TABLE; Schema: adt; Owner: hospital_owner
--

CREATE TABLE adt.admission (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint NOT NULL,
    admission_number text NOT NULL,
    admitted_at timestamp with time zone NOT NULL,
    discharged_at timestamp with time zone,
    admission_source text NOT NULL,
    CONSTRAINT admission_admission_source_check CHECK ((admission_source = ANY (ARRAY['emergency'::text, 'referral'::text, 'transfer'::text]))),
    CONSTRAINT admission_check CHECK (((discharged_at IS NULL) OR (discharged_at > admitted_at)))
);

ALTER TABLE ONLY adt.admission FORCE ROW LEVEL SECURITY;


ALTER TABLE adt.admission OWNER TO hospital_owner;

--
-- Name: TABLE admission; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON TABLE adt.admission IS 'Hospital reference model / adt / admission. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN admission.id; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.admission.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN admission.patient_id; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.admission.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN admission.encounter_id; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.admission.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN admission.admission_number; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.admission.admission_number IS 'admission number; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN admission.admitted_at; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.admission.admitted_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN admission.discharged_at; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.admission.discharged_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN admission.admission_source; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.admission.admission_source IS 'admission source; see table constraints and DATA_MODEL.md.';


--
-- Name: admission_id_seq; Type: SEQUENCE; Schema: adt; Owner: hospital_owner
--

ALTER TABLE adt.admission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME adt.admission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: bed_stay; Type: TABLE; Schema: adt; Owner: hospital_owner
--

CREATE TABLE adt.bed_stay (
    id bigint NOT NULL,
    admission_id bigint NOT NULL,
    patient_id bigint NOT NULL,
    bed_id bigint NOT NULL,
    occupied_during tstzrange NOT NULL,
    CONSTRAINT bed_stay_occupied_during_check CHECK (((NOT isempty(occupied_during)) AND (NOT lower_inf(occupied_during)) AND lower_inc(occupied_during) AND (NOT upper_inc(occupied_during))))
);

ALTER TABLE ONLY adt.bed_stay FORCE ROW LEVEL SECURITY;


ALTER TABLE adt.bed_stay OWNER TO hospital_owner;

--
-- Name: TABLE bed_stay; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON TABLE adt.bed_stay IS 'Hospital reference model / adt / bed stay. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN bed_stay.id; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.bed_stay.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN bed_stay.admission_id; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.bed_stay.admission_id IS 'admission id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN bed_stay.patient_id; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.bed_stay.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN bed_stay.bed_id; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.bed_stay.bed_id IS 'bed id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN bed_stay.occupied_during; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.bed_stay.occupied_during IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: bed_stay_id_seq; Type: SEQUENCE; Schema: adt; Owner: hospital_owner
--

ALTER TABLE adt.bed_stay ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME adt.bed_stay_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: discharge; Type: TABLE; Schema: adt; Owner: hospital_owner
--

CREATE TABLE adt.discharge (
    admission_id bigint NOT NULL,
    patient_id bigint NOT NULL,
    discharged_at timestamp with time zone NOT NULL,
    disposition text NOT NULL,
    summary_note_id bigint NOT NULL,
    approved_by bigint NOT NULL,
    CONSTRAINT discharge_disposition_check CHECK ((disposition = ANY (ARRAY['home'::text, 'transfer'::text, 'deceased'::text, 'other'::text])))
);

ALTER TABLE ONLY adt.discharge FORCE ROW LEVEL SECURITY;


ALTER TABLE adt.discharge OWNER TO hospital_owner;

--
-- Name: TABLE discharge; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON TABLE adt.discharge IS 'Hospital reference model / adt / discharge. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN discharge.admission_id; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.discharge.admission_id IS 'admission id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN discharge.patient_id; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.discharge.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN discharge.discharged_at; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.discharge.discharged_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN discharge.disposition; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.discharge.disposition IS 'disposition; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN discharge.summary_note_id; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.discharge.summary_note_id IS 'summary note id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN discharge.approved_by; Type: COMMENT; Schema: adt; Owner: hospital_owner
--

COMMENT ON COLUMN adt.discharge.approved_by IS 'approved by; see table constraints and DATA_MODEL.md.';


--
-- Name: bed; Type: TABLE; Schema: org; Owner: hospital_owner
--

CREATE TABLE org.bed (
    id bigint NOT NULL,
    room_id bigint NOT NULL,
    code text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    bed_type text NOT NULL,
    CONSTRAINT bed_bed_type_check CHECK ((bed_type = ANY (ARRAY['standard'::text, 'icu'::text, 'isolation'::text, 'pediatric'::text])))
);


ALTER TABLE org.bed OWNER TO hospital_owner;

--
-- Name: TABLE bed; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON TABLE org.bed IS 'Hospital reference model / org / bed. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN bed.id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.bed.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN bed.room_id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.bed.room_id IS 'room id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN bed.code; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.bed.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN bed.active; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.bed.active IS 'active; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN bed.bed_type; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.bed.bed_type IS 'bed type; see table constraints and DATA_MODEL.md.';


--
-- Name: department; Type: TABLE; Schema: org; Owner: hospital_owner
--

CREATE TABLE org.department (
    id bigint NOT NULL,
    site_id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    kind text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT department_kind_check CHECK ((kind = ANY (ARRAY['clinical'::text, 'diagnostic'::text, 'support'::text])))
);


ALTER TABLE org.department OWNER TO hospital_owner;

--
-- Name: TABLE department; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON TABLE org.department IS 'Hospital reference model / org / department. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN department.id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.department.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN department.site_id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.department.site_id IS 'site id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN department.code; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.department.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN department.name; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.department.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN department.kind; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.department.kind IS 'kind; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN department.active; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.department.active IS 'active; see table constraints and DATA_MODEL.md.';


--
-- Name: room; Type: TABLE; Schema: org; Owner: hospital_owner
--

CREATE TABLE org.room (
    id bigint NOT NULL,
    department_id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    kind text NOT NULL,
    floor_number smallint NOT NULL,
    CONSTRAINT room_kind_check CHECK ((kind = ANY (ARRAY['ward'::text, 'consultation'::text, 'procedure'::text, 'laboratory'::text, 'operating'::text, 'storage'::text])))
);


ALTER TABLE org.room OWNER TO hospital_owner;

--
-- Name: TABLE room; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON TABLE org.room IS 'Hospital reference model / org / room. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN room.id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.room.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN room.department_id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.room.department_id IS 'department id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN room.code; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.room.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN room.name; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.room.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN room.kind; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.room.kind IS 'kind; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN room.floor_number; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.room.floor_number IS 'floor number; see table constraints and DATA_MODEL.md.';


--
-- Name: bed_occupancy; Type: VIEW; Schema: analytics; Owner: hospital_owner
--

CREATE VIEW analytics.bed_occupancy AS
 SELECT d.id AS department_id,
    d.name AS department,
    count(*) FILTER (WHERE b.active) AS active_beds,
    count(*) FILTER (WHERE (b.active AND (EXISTS ( SELECT
           FROM adt.bed_stay s
          WHERE ((s.bed_id = b.id) AND (clock_timestamp() <@ s.occupied_during)))))) AS occupied_beds
   FROM ((org.bed b
     JOIN org.room r ON ((r.id = b.room_id)))
     JOIN org.department d ON ((d.id = r.department_id)))
  GROUP BY d.id, d.name;


ALTER VIEW analytics.bed_occupancy OWNER TO hospital_owner;

--
-- Name: VIEW bed_occupancy; Type: COMMENT; Schema: analytics; Owner: hospital_owner
--

COMMENT ON VIEW analytics.bed_occupancy IS 'Hospital reference model / analytics / bed occupancy. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: encounter; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.encounter (
    id bigint NOT NULL,
    public_id uuid DEFAULT gen_random_uuid() NOT NULL,
    patient_id bigint NOT NULL,
    type_code text NOT NULL,
    department_id bigint NOT NULL,
    attending_staff_id bigint NOT NULL,
    status text NOT NULL,
    started_at timestamp with time zone NOT NULL,
    ended_at timestamp with time zone,
    chief_complaint text,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT encounter_check CHECK (((ended_at IS NULL) OR (ended_at > started_at))),
    CONSTRAINT encounter_check1 CHECK (((status <> 'finished'::text) OR (ended_at IS NOT NULL))),
    CONSTRAINT encounter_check2 CHECK (((status <> 'in-progress'::text) OR (ended_at IS NULL))),
    CONSTRAINT encounter_status_check CHECK ((status = ANY (ARRAY['planned'::text, 'in-progress'::text, 'finished'::text, 'cancelled'::text])))
);

ALTER TABLE ONLY ehr.encounter FORCE ROW LEVEL SECURITY;


ALTER TABLE ehr.encounter OWNER TO hospital_owner;

--
-- Name: TABLE encounter; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON TABLE ehr.encounter IS 'Hospital reference model / ehr / encounter. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN encounter.id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN encounter.public_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter.public_id IS 'Opaque UUID for external references; does not confer authorization.';


--
-- Name: COLUMN encounter.patient_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN encounter.type_code; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter.type_code IS 'type code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN encounter.department_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter.department_id IS 'department id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN encounter.attending_staff_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter.attending_staff_id IS 'attending staff id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN encounter.status; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN encounter.started_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter.started_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN encounter.ended_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter.ended_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN encounter.chief_complaint; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter.chief_complaint IS 'chief complaint; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN encounter.created_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter.created_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN encounter.updated_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter.updated_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN encounter.row_version; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter.row_version IS 'row version; see table constraints and DATA_MODEL.md.';


--
-- Name: daily_activity; Type: MATERIALIZED VIEW; Schema: analytics; Owner: hospital_owner
--

CREATE MATERIALIZED VIEW analytics.daily_activity AS
 SELECT (e.started_at)::date AS activity_date,
    e.department_id,
    d.name AS department,
    e.type_code,
    count(*) AS encounters,
    count(DISTINCT e.patient_id) AS patients,
    round(avg((EXTRACT(epoch FROM (e.ended_at - e.started_at)) / (60)::numeric)), 2) AS average_duration_minutes
   FROM (ehr.encounter e
     JOIN org.department d ON ((d.id = e.department_id)))
  GROUP BY ((e.started_at)::date), e.department_id, d.name, e.type_code
  WITH NO DATA;


ALTER MATERIALIZED VIEW analytics.daily_activity OWNER TO hospital_owner;

--
-- Name: MATERIALIZED VIEW daily_activity; Type: COMMENT; Schema: analytics; Owner: hospital_owner
--

COMMENT ON MATERIALIZED VIEW analytics.daily_activity IS 'Hospital reference model / analytics / daily activity. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: invoice; Type: TABLE; Schema: billing; Owner: hospital_owner
--

CREATE TABLE billing.invoice (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint NOT NULL,
    invoice_number text NOT NULL,
    payer_id bigint NOT NULL,
    coverage_id bigint,
    issued_at timestamp with time zone NOT NULL,
    due_at timestamp with time zone NOT NULL,
    status text NOT NULL,
    currency_code character(3) NOT NULL,
    CONSTRAINT invoice_check CHECK ((due_at >= issued_at)),
    CONSTRAINT invoice_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'issued'::text, 'void'::text])))
);

ALTER TABLE ONLY billing.invoice FORCE ROW LEVEL SECURITY;


ALTER TABLE billing.invoice OWNER TO hospital_owner;

--
-- Name: TABLE invoice; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON TABLE billing.invoice IS 'Hospital reference model / billing / invoice. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN invoice.id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN invoice.patient_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN invoice.encounter_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN invoice.invoice_number; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice.invoice_number IS 'invoice number; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN invoice.payer_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice.payer_id IS 'payer id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN invoice.coverage_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice.coverage_id IS 'coverage id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN invoice.issued_at; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice.issued_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN invoice.due_at; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice.due_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN invoice.status; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN invoice.currency_code; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice.currency_code IS 'currency code; see table constraints and DATA_MODEL.md.';


--
-- Name: invoice_line; Type: TABLE; Schema: billing; Owner: hospital_owner
--

CREATE TABLE billing.invoice_line (
    invoice_id bigint NOT NULL,
    line_no integer NOT NULL,
    service_id integer NOT NULL,
    quantity ref.positive_quantity NOT NULL,
    unit_price ref.nonnegative_money NOT NULL,
    discount_amount ref.nonnegative_money DEFAULT 0 NOT NULL,
    tax_rate numeric(7,6) DEFAULT 0 NOT NULL,
    net_amount numeric(18,2) GENERATED ALWAYS AS (round((((quantity)::numeric * (unit_price)::numeric) - (discount_amount)::numeric), 2)) STORED,
    tax_amount numeric(18,2) GENERATED ALWAYS AS (round(((((quantity)::numeric * (unit_price)::numeric) - (discount_amount)::numeric) * tax_rate), 2)) STORED,
    CONSTRAINT invoice_line_check CHECK (((discount_amount)::numeric <= ((quantity)::numeric * (unit_price)::numeric))),
    CONSTRAINT invoice_line_line_no_check CHECK ((line_no > 0)),
    CONSTRAINT invoice_line_tax_rate_check CHECK (((tax_rate >= (0)::numeric) AND (tax_rate <= (1)::numeric)))
);

ALTER TABLE ONLY billing.invoice_line FORCE ROW LEVEL SECURITY;


ALTER TABLE billing.invoice_line OWNER TO hospital_owner;

--
-- Name: TABLE invoice_line; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON TABLE billing.invoice_line IS 'Hospital reference model / billing / invoice line. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN invoice_line.invoice_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice_line.invoice_id IS 'invoice id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN invoice_line.line_no; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice_line.line_no IS 'line no; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN invoice_line.service_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice_line.service_id IS 'service id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN invoice_line.quantity; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice_line.quantity IS 'quantity; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN invoice_line.unit_price; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice_line.unit_price IS 'unit price; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN invoice_line.discount_amount; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice_line.discount_amount IS 'discount amount; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN invoice_line.tax_rate; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice_line.tax_rate IS 'tax rate; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN invoice_line.net_amount; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice_line.net_amount IS 'net amount; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN invoice_line.tax_amount; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.invoice_line.tax_amount IS 'tax amount; see table constraints and DATA_MODEL.md.';


--
-- Name: payer; Type: TABLE; Schema: billing; Owner: hospital_owner
--

CREATE TABLE billing.payer (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    kind text NOT NULL,
    CONSTRAINT payer_kind_check CHECK ((kind = ANY (ARRAY['public'::text, 'private'::text, 'self-pay'::text])))
);


ALTER TABLE billing.payer OWNER TO hospital_owner;

--
-- Name: TABLE payer; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON TABLE billing.payer IS 'Hospital reference model / billing / payer. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN payer.id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payer.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN payer.code; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payer.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN payer.name; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payer.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN payer.kind; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payer.kind IS 'kind; see table constraints and DATA_MODEL.md.';


--
-- Name: payment_allocation; Type: TABLE; Schema: billing; Owner: hospital_owner
--

CREATE TABLE billing.payment_allocation (
    id bigint NOT NULL,
    payment_id bigint NOT NULL,
    invoice_id bigint NOT NULL,
    patient_id bigint NOT NULL,
    amount ref.nonnegative_money NOT NULL,
    allocated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT payment_allocation_amount_check CHECK (((amount)::numeric > (0)::numeric))
);

ALTER TABLE ONLY billing.payment_allocation FORCE ROW LEVEL SECURITY;


ALTER TABLE billing.payment_allocation OWNER TO hospital_owner;

--
-- Name: TABLE payment_allocation; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON TABLE billing.payment_allocation IS 'Append-only allocation, serialized by payment and invoice row locks. Currency, payer, patient identity and available balances are checked.';


--
-- Name: COLUMN payment_allocation.id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payment_allocation.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN payment_allocation.payment_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payment_allocation.payment_id IS 'payment id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN payment_allocation.invoice_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payment_allocation.invoice_id IS 'invoice id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN payment_allocation.patient_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payment_allocation.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN payment_allocation.amount; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payment_allocation.amount IS 'amount; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN payment_allocation.allocated_at; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payment_allocation.allocated_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: v_invoice_balance; Type: VIEW; Schema: billing; Owner: hospital_owner
--

CREATE VIEW billing.v_invoice_balance WITH (security_invoker='true') AS
 SELECT i.id,
    i.patient_id,
    i.invoice_number,
    i.payer_id,
    i.currency_code,
    i.status,
    i.issued_at,
    i.due_at,
    (COALESCE(l.total_amount, (0)::numeric))::numeric(18,2) AS total_amount,
    (COALESCE(p.paid_amount, (0)::numeric))::numeric(18,2) AS paid_amount,
    ((COALESCE(l.total_amount, (0)::numeric) - COALESCE(p.paid_amount, (0)::numeric)))::numeric(18,2) AS outstanding_amount
   FROM ((billing.invoice i
     LEFT JOIN ( SELECT invoice_line.invoice_id,
            sum((invoice_line.net_amount + invoice_line.tax_amount)) AS total_amount
           FROM billing.invoice_line
          GROUP BY invoice_line.invoice_id) l ON ((l.invoice_id = i.id)))
     LEFT JOIN ( SELECT payment_allocation.invoice_id,
            sum((payment_allocation.amount)::numeric) AS paid_amount
           FROM billing.payment_allocation
          GROUP BY payment_allocation.invoice_id) p ON ((p.invoice_id = i.id)));


ALTER VIEW billing.v_invoice_balance OWNER TO hospital_owner;

--
-- Name: VIEW v_invoice_balance; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON VIEW billing.v_invoice_balance IS 'Hospital reference model / billing / v invoice balance. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: monthly_revenue; Type: MATERIALIZED VIEW; Schema: analytics; Owner: hospital_owner
--

CREATE MATERIALIZED VIEW analytics.monthly_revenue AS
 SELECT (date_trunc('month'::text, i.issued_at))::date AS reporting_month,
    i.payer_id,
    p.name AS payer,
    i.currency_code,
    count(*) AS invoices,
    (sum(i.total_amount))::numeric(20,2) AS billed,
    (sum(i.paid_amount))::numeric(20,2) AS paid,
    (sum(i.outstanding_amount))::numeric(20,2) AS outstanding
   FROM (billing.v_invoice_balance i
     JOIN billing.payer p ON ((p.id = i.payer_id)))
  WHERE (i.status = 'issued'::text)
  GROUP BY ((date_trunc('month'::text, i.issued_at))::date), i.payer_id, p.name, i.currency_code
  WITH NO DATA;


ALTER MATERIALIZED VIEW analytics.monthly_revenue OWNER TO hospital_owner;

--
-- Name: MATERIALIZED VIEW monthly_revenue; Type: COMMENT; Schema: analytics; Owner: hospital_owner
--

COMMENT ON MATERIALIZED VIEW analytics.monthly_revenue IS 'Hospital reference model / analytics / monthly revenue. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: v_catalog; Type: VIEW; Schema: analytics; Owner: hospital_owner
--

CREATE VIEW analytics.v_catalog AS
 SELECT n.nspname AS schema_name,
    c.relname AS table_name,
    obj_description(c.oid, 'pg_class'::name) AS description,
    (c.reltuples)::bigint AS estimated_rows,
        CASE
            WHEN (c.relkind = 'p'::"char") THEN ( SELECT (sum(pg_total_relation_size(pt.relid)))::bigint AS sum
               FROM pg_partition_tree((c.oid)::regclass) pt(relid, parentrelid, isleaf, level)
              WHERE pt.isleaf)
            ELSE pg_total_relation_size((c.oid)::regclass)
        END AS total_bytes,
    c.relrowsecurity AS row_security,
    c.relforcerowsecurity AS forced_row_security
   FROM (pg_class c
     JOIN pg_namespace n ON ((n.oid = c.relnamespace)))
  WHERE ((c.relkind = ANY (ARRAY['r'::"char", 'p'::"char"])) AND (NOT c.relispartition) AND (n.nspname <> ALL (ARRAY['ext'::name, 'pg_catalog'::name, 'information_schema'::name])));


ALTER VIEW analytics.v_catalog OWNER TO hospital_owner;

--
-- Name: VIEW v_catalog; Type: COMMENT; Schema: analytics; Owner: hospital_owner
--

COMMENT ON VIEW analytics.v_catalog IS 'Hospital reference model / analytics / v catalog. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: access_event; Type: TABLE; Schema: audit; Owner: hospital_owner
--

CREATE TABLE audit.access_event (
    id bigint NOT NULL,
    occurred_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    actor name NOT NULL,
    patient_id bigint NOT NULL,
    purpose text NOT NULL,
    action text NOT NULL,
    request_id uuid NOT NULL,
    reason text NOT NULL,
    CONSTRAINT access_event_action_check CHECK ((action = ANY (ARRAY['read'::text, 'export'::text, 'break-glass'::text])))
);

ALTER TABLE ONLY audit.access_event FORCE ROW LEVEL SECURITY;


ALTER TABLE audit.access_event OWNER TO hospital_owner;

--
-- Name: TABLE access_event; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON TABLE audit.access_event IS 'Hospital reference model / audit / access event. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN access_event.id; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.access_event.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN access_event.occurred_at; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.access_event.occurred_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN access_event.actor; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.access_event.actor IS 'actor; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN access_event.patient_id; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.access_event.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN access_event.purpose; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.access_event.purpose IS 'purpose; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN access_event.action; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.access_event.action IS 'action; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN access_event.request_id; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.access_event.request_id IS 'request id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN access_event.reason; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.access_event.reason IS 'reason; see table constraints and DATA_MODEL.md.';


--
-- Name: access_event_id_seq; Type: SEQUENCE; Schema: audit; Owner: hospital_owner
--

ALTER TABLE audit.access_event ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME audit.access_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: event; Type: TABLE; Schema: audit; Owner: hospital_owner
--

CREATE TABLE audit.event (
    id bigint NOT NULL,
    occurred_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    actor name NOT NULL,
    transaction_id bigint NOT NULL,
    table_schema name NOT NULL,
    table_name name NOT NULL,
    operation text NOT NULL,
    entity_key jsonb NOT NULL,
    changed_columns text[],
    request_id text,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT event_operation_check CHECK ((operation = ANY (ARRAY['INSERT'::text, 'UPDATE'::text, 'DELETE'::text, 'BASELINE'::text])))
);


ALTER TABLE audit.event OWNER TO hospital_owner;

--
-- Name: TABLE event; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON TABLE audit.event IS 'Append-only DML metadata; actor=session_user. Baseline explicitly denotes synthetic load. No full clinical bodies are duplicated. Superusers remain trusted.';


--
-- Name: COLUMN event.id; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.event.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN event.occurred_at; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.event.occurred_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN event.actor; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.event.actor IS 'actor; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN event.transaction_id; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.event.transaction_id IS 'transaction id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN event.table_schema; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.event.table_schema IS 'table schema; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN event.table_name; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.event.table_name IS 'table name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN event.operation; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.event.operation IS 'operation; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN event.entity_key; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.event.entity_key IS 'entity key; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN event.changed_columns; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.event.changed_columns IS 'changed columns; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN event.request_id; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.event.request_id IS 'request id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN event.details; Type: COMMENT; Schema: audit; Owner: hospital_owner
--

COMMENT ON COLUMN audit.event.details IS 'details; see table constraints and DATA_MODEL.md.';


--
-- Name: event_id_seq; Type: SEQUENCE; Schema: audit; Owner: hospital_owner
--

ALTER TABLE audit.event ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME audit.event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: claim; Type: TABLE; Schema: billing; Owner: hospital_owner
--

CREATE TABLE billing.claim (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    invoice_id bigint NOT NULL,
    payer_id bigint NOT NULL,
    claim_number text NOT NULL,
    status text NOT NULL,
    submitted_at timestamp with time zone,
    adjudicated_at timestamp with time zone,
    rejection_reason text,
    CONSTRAINT claim_check CHECK (((adjudicated_at IS NULL) OR (adjudicated_at >= submitted_at))),
    CONSTRAINT claim_check1 CHECK (((status <> 'rejected'::text) OR (rejection_reason IS NOT NULL))),
    CONSTRAINT claim_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'submitted'::text, 'accepted'::text, 'rejected'::text])))
);

ALTER TABLE ONLY billing.claim FORCE ROW LEVEL SECURITY;


ALTER TABLE billing.claim OWNER TO hospital_owner;

--
-- Name: TABLE claim; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON TABLE billing.claim IS 'Hospital reference model / billing / claim. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN claim.id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.claim.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN claim.patient_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.claim.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN claim.invoice_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.claim.invoice_id IS 'invoice id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN claim.payer_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.claim.payer_id IS 'payer id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN claim.claim_number; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.claim.claim_number IS 'claim number; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN claim.status; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.claim.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN claim.submitted_at; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.claim.submitted_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN claim.adjudicated_at; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.claim.adjudicated_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN claim.rejection_reason; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.claim.rejection_reason IS 'rejection reason; see table constraints and DATA_MODEL.md.';


--
-- Name: claim_id_seq; Type: SEQUENCE; Schema: billing; Owner: hospital_owner
--

ALTER TABLE billing.claim ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME billing.claim_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: coverage; Type: TABLE; Schema: billing; Owner: hospital_owner
--

CREATE TABLE billing.coverage (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    payer_id bigint NOT NULL,
    policy_number text NOT NULL,
    valid_during daterange NOT NULL,
    priority smallint NOT NULL,
    CONSTRAINT coverage_priority_check CHECK ((priority > 0)),
    CONSTRAINT coverage_valid_during_check CHECK ((NOT isempty(valid_during)))
);

ALTER TABLE ONLY billing.coverage FORCE ROW LEVEL SECURITY;


ALTER TABLE billing.coverage OWNER TO hospital_owner;

--
-- Name: TABLE coverage; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON TABLE billing.coverage IS 'Hospital reference model / billing / coverage. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN coverage.id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.coverage.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN coverage.patient_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.coverage.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN coverage.payer_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.coverage.payer_id IS 'payer id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN coverage.policy_number; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.coverage.policy_number IS 'policy number; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN coverage.valid_during; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.coverage.valid_during IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: COLUMN coverage.priority; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.coverage.priority IS 'priority; see table constraints and DATA_MODEL.md.';


--
-- Name: coverage_id_seq; Type: SEQUENCE; Schema: billing; Owner: hospital_owner
--

ALTER TABLE billing.coverage ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME billing.coverage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: invoice_id_seq; Type: SEQUENCE; Schema: billing; Owner: hospital_owner
--

ALTER TABLE billing.invoice ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME billing.invoice_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: payer_id_seq; Type: SEQUENCE; Schema: billing; Owner: hospital_owner
--

ALTER TABLE billing.payer ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME billing.payer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: payment; Type: TABLE; Schema: billing; Owner: hospital_owner
--

CREATE TABLE billing.payment (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    payer_id bigint NOT NULL,
    received_at timestamp with time zone NOT NULL,
    amount ref.nonnegative_money NOT NULL,
    currency_code character(3) NOT NULL,
    method text NOT NULL,
    external_reference text NOT NULL,
    CONSTRAINT payment_amount_check CHECK (((amount)::numeric > (0)::numeric)),
    CONSTRAINT payment_method_check CHECK ((method = ANY (ARRAY['card'::text, 'transfer'::text, 'cash'::text])))
);

ALTER TABLE ONLY billing.payment FORCE ROW LEVEL SECURITY;


ALTER TABLE billing.payment OWNER TO hospital_owner;

--
-- Name: TABLE payment; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON TABLE billing.payment IS 'Hospital reference model / billing / payment. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN payment.id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payment.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN payment.patient_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payment.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN payment.payer_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payment.payer_id IS 'payer id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN payment.received_at; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payment.received_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN payment.amount; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payment.amount IS 'amount; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN payment.currency_code; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payment.currency_code IS 'currency code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN payment.method; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payment.method IS 'method; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN payment.external_reference; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.payment.external_reference IS 'external reference; see table constraints and DATA_MODEL.md.';


--
-- Name: payment_allocation_id_seq; Type: SEQUENCE; Schema: billing; Owner: hospital_owner
--

ALTER TABLE billing.payment_allocation ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME billing.payment_allocation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: payment_id_seq; Type: SEQUENCE; Schema: billing; Owner: hospital_owner
--

ALTER TABLE billing.payment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME billing.payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tariff; Type: TABLE; Schema: billing; Owner: hospital_owner
--

CREATE TABLE billing.tariff (
    id bigint NOT NULL,
    service_id integer NOT NULL,
    payer_id bigint NOT NULL,
    valid_during daterange NOT NULL,
    amount ref.nonnegative_money NOT NULL,
    currency_code character(3) NOT NULL,
    CONSTRAINT tariff_valid_during_check CHECK ((NOT isempty(valid_during)))
);


ALTER TABLE billing.tariff OWNER TO hospital_owner;

--
-- Name: TABLE tariff; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON TABLE billing.tariff IS 'Hospital reference model / billing / tariff. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN tariff.id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.tariff.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN tariff.service_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.tariff.service_id IS 'service id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN tariff.payer_id; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.tariff.payer_id IS 'payer id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN tariff.valid_during; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.tariff.valid_during IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: COLUMN tariff.amount; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.tariff.amount IS 'amount; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN tariff.currency_code; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON COLUMN billing.tariff.currency_code IS 'currency code; see table constraints and DATA_MODEL.md.';


--
-- Name: tariff_id_seq; Type: SEQUENCE; Schema: billing; Owner: hospital_owner
--

ALTER TABLE billing.tariff ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME billing.tariff_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: patient; Type: TABLE; Schema: mpi; Owner: hospital_owner
--

CREATE TABLE mpi.patient (
    id bigint NOT NULL,
    public_id uuid DEFAULT gen_random_uuid() NOT NULL,
    mrn text NOT NULL,
    family_name ref.nonblank_text NOT NULL,
    given_name ref.nonblank_text NOT NULL,
    birth_date date NOT NULL,
    administrative_gender text NOT NULL,
    deceased_at timestamp with time zone,
    active boolean DEFAULT true NOT NULL,
    is_synthetic boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    CONSTRAINT patient_administrative_gender_check CHECK ((administrative_gender = ANY (ARRAY['female'::text, 'male'::text, 'other'::text, 'unknown'::text]))),
    CONSTRAINT patient_birth_date_check CHECK (((birth_date >= '1850-01-01'::date) AND (birth_date <= '2100-01-01'::date))),
    CONSTRAINT patient_check CHECK (((deceased_at IS NULL) OR ((deceased_at)::date >= birth_date))),
    CONSTRAINT patient_row_version_check CHECK ((row_version > 0))
);

ALTER TABLE ONLY mpi.patient FORCE ROW LEVEL SECURITY;


ALTER TABLE mpi.patient OWNER TO hospital_owner;

--
-- Name: TABLE patient; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON TABLE mpi.patient IS 'Master patient index; synthetic MRN and UUID. No real national identifiers or contact details. Row-level access is deny-by-default.';


--
-- Name: COLUMN patient.id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.patient.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN patient.public_id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.patient.public_id IS 'Opaque UUID for external references; does not confer authorization.';


--
-- Name: COLUMN patient.mrn; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.patient.mrn IS 'mrn; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN patient.family_name; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.patient.family_name IS 'family name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN patient.given_name; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.patient.given_name IS 'given name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN patient.birth_date; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.patient.birth_date IS 'birth date; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN patient.administrative_gender; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.patient.administrative_gender IS 'administrative gender; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN patient.deceased_at; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.patient.deceased_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN patient.active; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.patient.active IS 'active; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN patient.is_synthetic; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.patient.is_synthetic IS 'is synthetic; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN patient.created_at; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.patient.created_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN patient.updated_at; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.patient.updated_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN patient.row_version; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.patient.row_version IS 'row version; see table constraints and DATA_MODEL.md.';


--
-- Name: v_patient_identity; Type: VIEW; Schema: billing; Owner: hospital_owner
--

CREATE VIEW billing.v_patient_identity WITH (security_barrier='true') AS
 SELECT id AS patient_id,
    mrn,
    ('Пациент '::text || "right"(mrn, 4)) AS display_label
   FROM mpi.patient
  WHERE iam.has_patient_access(id, 'billing'::text);


ALTER VIEW billing.v_patient_identity OWNER TO hospital_owner;

--
-- Name: VIEW v_patient_identity; Type: COMMENT; Schema: billing; Owner: hospital_owner
--

COMMENT ON VIEW billing.v_patient_identity IS 'Hospital reference model / billing / v patient identity. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: allergy; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.allergy (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    substance_concept_id integer NOT NULL,
    clinical_status text NOT NULL,
    verification_status text NOT NULL,
    criticality text NOT NULL,
    reaction_text text,
    recorded_at timestamp with time zone NOT NULL,
    recorded_by bigint NOT NULL,
    CONSTRAINT allergy_clinical_status_check CHECK ((clinical_status = ANY (ARRAY['active'::text, 'inactive'::text, 'resolved'::text]))),
    CONSTRAINT allergy_criticality_check CHECK ((criticality = ANY (ARRAY['low'::text, 'high'::text, 'unable-to-assess'::text]))),
    CONSTRAINT allergy_verification_status_check CHECK ((verification_status = ANY (ARRAY['unconfirmed'::text, 'confirmed'::text, 'refuted'::text])))
);

ALTER TABLE ONLY ehr.allergy FORCE ROW LEVEL SECURITY;


ALTER TABLE ehr.allergy OWNER TO hospital_owner;

--
-- Name: TABLE allergy; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON TABLE ehr.allergy IS 'Hospital reference model / ehr / allergy. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN allergy.id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.allergy.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN allergy.patient_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.allergy.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN allergy.substance_concept_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.allergy.substance_concept_id IS 'substance concept id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN allergy.clinical_status; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.allergy.clinical_status IS 'clinical status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN allergy.verification_status; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.allergy.verification_status IS 'verification status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN allergy.criticality; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.allergy.criticality IS 'criticality; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN allergy.reaction_text; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.allergy.reaction_text IS 'reaction text; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN allergy.recorded_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.allergy.recorded_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN allergy.recorded_by; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.allergy.recorded_by IS 'recorded by; see table constraints and DATA_MODEL.md.';


--
-- Name: allergy_id_seq; Type: SEQUENCE; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.allergy ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ehr.allergy_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: care_plan; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.care_plan (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint,
    status text NOT NULL,
    title text NOT NULL,
    valid_during tstzrange NOT NULL,
    author_id bigint NOT NULL,
    CONSTRAINT care_plan_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'completed'::text, 'revoked'::text]))),
    CONSTRAINT care_plan_valid_during_check CHECK ((NOT isempty(valid_during)))
);

ALTER TABLE ONLY ehr.care_plan FORCE ROW LEVEL SECURITY;


ALTER TABLE ehr.care_plan OWNER TO hospital_owner;

--
-- Name: TABLE care_plan; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON TABLE ehr.care_plan IS 'Hospital reference model / ehr / care plan. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN care_plan.id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.care_plan.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN care_plan.patient_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.care_plan.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN care_plan.encounter_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.care_plan.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN care_plan.status; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.care_plan.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN care_plan.title; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.care_plan.title IS 'title; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN care_plan.valid_during; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.care_plan.valid_during IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: COLUMN care_plan.author_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.care_plan.author_id IS 'author id; see table constraints and DATA_MODEL.md.';


--
-- Name: care_plan_activity; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.care_plan_activity (
    id bigint NOT NULL,
    care_plan_id bigint NOT NULL,
    service_id integer NOT NULL,
    status text NOT NULL,
    scheduled_at timestamp with time zone NOT NULL,
    assigned_staff_id bigint,
    CONSTRAINT care_plan_activity_status_check CHECK ((status = ANY (ARRAY['scheduled'::text, 'in-progress'::text, 'completed'::text, 'cancelled'::text])))
);

ALTER TABLE ONLY ehr.care_plan_activity FORCE ROW LEVEL SECURITY;


ALTER TABLE ehr.care_plan_activity OWNER TO hospital_owner;

--
-- Name: TABLE care_plan_activity; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON TABLE ehr.care_plan_activity IS 'Hospital reference model / ehr / care plan activity. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN care_plan_activity.id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.care_plan_activity.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN care_plan_activity.care_plan_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.care_plan_activity.care_plan_id IS 'care plan id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN care_plan_activity.service_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.care_plan_activity.service_id IS 'service id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN care_plan_activity.status; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.care_plan_activity.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN care_plan_activity.scheduled_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.care_plan_activity.scheduled_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN care_plan_activity.assigned_staff_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.care_plan_activity.assigned_staff_id IS 'assigned staff id; see table constraints and DATA_MODEL.md.';


--
-- Name: care_plan_activity_id_seq; Type: SEQUENCE; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.care_plan_activity ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ehr.care_plan_activity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: care_plan_id_seq; Type: SEQUENCE; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.care_plan ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ehr.care_plan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: clinical_note; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.clinical_note (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint NOT NULL,
    note_type text NOT NULL,
    author_id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    current_version integer DEFAULT 1 NOT NULL,
    CONSTRAINT clinical_note_current_version_check CHECK ((current_version > 0)),
    CONSTRAINT clinical_note_note_type_check CHECK ((note_type = ANY (ARRAY['progress'::text, 'consultation'::text, 'discharge'::text, 'nursing'::text])))
);

ALTER TABLE ONLY ehr.clinical_note FORCE ROW LEVEL SECURITY;


ALTER TABLE ehr.clinical_note OWNER TO hospital_owner;

--
-- Name: TABLE clinical_note; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON TABLE ehr.clinical_note IS 'Hospital reference model / ehr / clinical note. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN clinical_note.id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.clinical_note.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN clinical_note.patient_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.clinical_note.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN clinical_note.encounter_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.clinical_note.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN clinical_note.note_type; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.clinical_note.note_type IS 'note type; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN clinical_note.author_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.clinical_note.author_id IS 'author id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN clinical_note.created_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.clinical_note.created_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN clinical_note.current_version; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.clinical_note.current_version IS 'current version; see table constraints and DATA_MODEL.md.';


--
-- Name: clinical_note_id_seq; Type: SEQUENCE; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.clinical_note ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ehr.clinical_note_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: condition; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.condition (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint,
    concept_id integer NOT NULL,
    clinical_status text NOT NULL,
    verification_status text NOT NULL,
    onset_at timestamp with time zone NOT NULL,
    abatement_at timestamp with time zone,
    rank smallint,
    recorded_by bigint NOT NULL,
    CONSTRAINT condition_check CHECK (((abatement_at IS NULL) OR (abatement_at >= onset_at))),
    CONSTRAINT condition_clinical_status_check CHECK ((clinical_status = ANY (ARRAY['active'::text, 'resolved'::text, 'remission'::text]))),
    CONSTRAINT condition_rank_check CHECK ((rank > 0)),
    CONSTRAINT condition_verification_status_check CHECK ((verification_status = ANY (ARRAY['provisional'::text, 'confirmed'::text, 'refuted'::text])))
);

ALTER TABLE ONLY ehr.condition FORCE ROW LEVEL SECURITY;


ALTER TABLE ehr.condition OWNER TO hospital_owner;

--
-- Name: TABLE condition; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON TABLE ehr.condition IS 'Hospital reference model / ehr / condition. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN condition.id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.condition.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN condition.patient_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.condition.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN condition.encounter_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.condition.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN condition.concept_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.condition.concept_id IS 'concept id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN condition.clinical_status; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.condition.clinical_status IS 'clinical status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN condition.verification_status; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.condition.verification_status IS 'verification status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN condition.onset_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.condition.onset_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN condition.abatement_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.condition.abatement_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN condition.rank; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.condition.rank IS 'rank; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN condition.recorded_by; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.condition.recorded_by IS 'recorded by; see table constraints and DATA_MODEL.md.';


--
-- Name: condition_id_seq; Type: SEQUENCE; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.condition ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ehr.condition_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: death_record; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.death_record (
    patient_id bigint NOT NULL,
    encounter_id bigint,
    death_at timestamp with time zone NOT NULL,
    certified_by bigint NOT NULL,
    cause_concept_id integer,
    certificate_number text NOT NULL
);

ALTER TABLE ONLY ehr.death_record FORCE ROW LEVEL SECURITY;


ALTER TABLE ehr.death_record OWNER TO hospital_owner;

--
-- Name: TABLE death_record; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON TABLE ehr.death_record IS 'Hospital reference model / ehr / death record. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN death_record.patient_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.death_record.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN death_record.encounter_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.death_record.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN death_record.death_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.death_record.death_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN death_record.certified_by; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.death_record.certified_by IS 'certified by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN death_record.cause_concept_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.death_record.cause_concept_id IS 'cause concept id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN death_record.certificate_number; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.death_record.certificate_number IS 'certificate number; see table constraints and DATA_MODEL.md.';


--
-- Name: document; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.document (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint,
    document_type text NOT NULL,
    storage_uri text NOT NULL,
    media_type text NOT NULL,
    size_bytes bigint NOT NULL,
    sha256 bytea NOT NULL,
    created_at timestamp with time zone NOT NULL,
    author_id bigint NOT NULL,
    CONSTRAINT document_sha256_check CHECK ((octet_length(sha256) = 32)),
    CONSTRAINT document_size_bytes_check CHECK ((size_bytes > 0))
);

ALTER TABLE ONLY ehr.document FORCE ROW LEVEL SECURITY;


ALTER TABLE ehr.document OWNER TO hospital_owner;

--
-- Name: TABLE document; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON TABLE ehr.document IS 'Hospital reference model / ehr / document. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN document.id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.document.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN document.patient_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.document.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN document.encounter_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.document.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN document.document_type; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.document.document_type IS 'document type; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN document.storage_uri; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.document.storage_uri IS 'storage uri; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN document.media_type; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.document.media_type IS 'media type; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN document.size_bytes; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.document.size_bytes IS 'size bytes; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN document.sha256; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.document.sha256 IS 'sha256; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN document.created_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.document.created_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN document.author_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.document.author_id IS 'author id; see table constraints and DATA_MODEL.md.';


--
-- Name: document_id_seq; Type: SEQUENCE; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.document ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ehr.document_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: encounter_id_seq; Type: SEQUENCE; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.encounter ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ehr.encounter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: encounter_participant; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.encounter_participant (
    encounter_id bigint NOT NULL,
    staff_id bigint NOT NULL,
    role_code text NOT NULL,
    participation_period tstzrange NOT NULL,
    CONSTRAINT encounter_participant_participation_period_check CHECK ((NOT isempty(participation_period)))
);

ALTER TABLE ONLY ehr.encounter_participant FORCE ROW LEVEL SECURITY;


ALTER TABLE ehr.encounter_participant OWNER TO hospital_owner;

--
-- Name: TABLE encounter_participant; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON TABLE ehr.encounter_participant IS 'Hospital reference model / ehr / encounter participant. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN encounter_participant.encounter_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter_participant.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN encounter_participant.staff_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter_participant.staff_id IS 'staff id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN encounter_participant.role_code; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter_participant.role_code IS 'role code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN encounter_participant.participation_period; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.encounter_participant.participation_period IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: immunization; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.immunization (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint NOT NULL,
    vaccine_concept_id integer NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    status text NOT NULL,
    lot_number text,
    performer_id bigint NOT NULL,
    CONSTRAINT immunization_status_check CHECK ((status = ANY (ARRAY['completed'::text, 'not-done'::text, 'entered-in-error'::text])))
);

ALTER TABLE ONLY ehr.immunization FORCE ROW LEVEL SECURITY;


ALTER TABLE ehr.immunization OWNER TO hospital_owner;

--
-- Name: TABLE immunization; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON TABLE ehr.immunization IS 'Hospital reference model / ehr / immunization. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN immunization.id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.immunization.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN immunization.patient_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.immunization.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN immunization.encounter_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.immunization.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN immunization.vaccine_concept_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.immunization.vaccine_concept_id IS 'vaccine concept id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN immunization.occurred_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.immunization.occurred_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN immunization.status; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.immunization.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN immunization.lot_number; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.immunization.lot_number IS 'lot number; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN immunization.performer_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.immunization.performer_id IS 'performer id; see table constraints and DATA_MODEL.md.';


--
-- Name: immunization_id_seq; Type: SEQUENCE; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.immunization ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ehr.immunization_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: note_version; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.note_version (
    note_id bigint NOT NULL,
    version integer NOT NULL,
    body ref.nonblank_text NOT NULL,
    created_at timestamp with time zone NOT NULL,
    author_id bigint NOT NULL,
    signed_at timestamp with time zone,
    signed_by bigint,
    supersedes_version integer,
    amendment_reason text,
    body_sha256 bytea GENERATED ALWAYS AS (ext.digest((body)::text, 'sha256'::text)) STORED,
    CONSTRAINT note_version_check CHECK (((signed_at IS NULL) = (signed_by IS NULL))),
    CONSTRAINT note_version_check1 CHECK (((signed_at IS NULL) OR (signed_at >= created_at))),
    CONSTRAINT note_version_check2 CHECK ((((version = 1) AND (supersedes_version IS NULL)) OR ((version > 1) AND (supersedes_version = (version - 1)) AND (amendment_reason IS NOT NULL)))),
    CONSTRAINT note_version_version_check CHECK ((version > 0))
);

ALTER TABLE ONLY ehr.note_version FORCE ROW LEVEL SECURITY;


ALTER TABLE ehr.note_version OWNER TO hospital_owner;

--
-- Name: TABLE note_version; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON TABLE ehr.note_version IS 'Append a new version to amend a signed note. Signed versions cannot be updated/deleted. SHA-256 detects body differences; it is not a qualified electronic signature.';


--
-- Name: COLUMN note_version.note_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.note_version.note_id IS 'note id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN note_version.version; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.note_version.version IS 'version; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN note_version.body; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.note_version.body IS 'body; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN note_version.created_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.note_version.created_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN note_version.author_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.note_version.author_id IS 'author id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN note_version.signed_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.note_version.signed_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN note_version.signed_by; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.note_version.signed_by IS 'signed by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN note_version.supersedes_version; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.note_version.supersedes_version IS 'supersedes version; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN note_version.amendment_reason; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.note_version.amendment_reason IS 'amendment reason; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN note_version.body_sha256; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.note_version.body_sha256 IS 'body sha256; see table constraints and DATA_MODEL.md.';


--
-- Name: observation; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint NOT NULL,
    test_id integer NOT NULL,
    observed_at timestamp with time zone NOT NULL,
    status text NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
)
PARTITION BY RANGE (observed_at);

ALTER TABLE ONLY ehr.observation FORCE ROW LEVEL SECURITY;


ALTER TABLE ehr.observation OWNER TO hospital_owner;

--
-- Name: TABLE observation; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON TABLE ehr.observation IS 'Typed clinical measurements, monthly RANGE partitions 2024–2027; exactly one value, unit checked against catalog. Partition key is part of primary key.';


--
-- Name: COLUMN observation.id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.observation.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN observation.patient_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.observation.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN observation.encounter_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.observation.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN observation.test_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.observation.test_id IS 'test id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN observation.observed_at; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.observation.observed_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN observation.status; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.observation.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN observation.value_numeric; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.observation.value_numeric IS 'value numeric; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN observation.value_text; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.observation.value_text IS 'value text; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN observation.value_concept_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.observation.value_concept_id IS 'value concept id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN observation.value_boolean; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.observation.value_boolean IS 'value boolean; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN observation.unit_code; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.observation.unit_code IS 'unit code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN observation.recorded_by; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.observation.recorded_by IS 'recorded by; see table constraints and DATA_MODEL.md.';


--
-- Name: observation_2024_01; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2024_01 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2024_01 OWNER TO hospital_owner;

--
-- Name: observation_2024_02; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2024_02 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2024_02 OWNER TO hospital_owner;

--
-- Name: observation_2024_03; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2024_03 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2024_03 OWNER TO hospital_owner;

--
-- Name: observation_2024_04; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2024_04 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2024_04 OWNER TO hospital_owner;

--
-- Name: observation_2024_05; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2024_05 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2024_05 OWNER TO hospital_owner;

--
-- Name: observation_2024_06; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2024_06 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2024_06 OWNER TO hospital_owner;

--
-- Name: observation_2024_07; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2024_07 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2024_07 OWNER TO hospital_owner;

--
-- Name: observation_2024_08; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2024_08 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2024_08 OWNER TO hospital_owner;

--
-- Name: observation_2024_09; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2024_09 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2024_09 OWNER TO hospital_owner;

--
-- Name: observation_2024_10; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2024_10 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2024_10 OWNER TO hospital_owner;

--
-- Name: observation_2024_11; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2024_11 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2024_11 OWNER TO hospital_owner;

--
-- Name: observation_2024_12; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2024_12 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2024_12 OWNER TO hospital_owner;

--
-- Name: observation_2025_01; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2025_01 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2025_01 OWNER TO hospital_owner;

--
-- Name: observation_2025_02; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2025_02 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2025_02 OWNER TO hospital_owner;

--
-- Name: observation_2025_03; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2025_03 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2025_03 OWNER TO hospital_owner;

--
-- Name: observation_2025_04; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2025_04 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2025_04 OWNER TO hospital_owner;

--
-- Name: observation_2025_05; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2025_05 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2025_05 OWNER TO hospital_owner;

--
-- Name: observation_2025_06; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2025_06 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2025_06 OWNER TO hospital_owner;

--
-- Name: observation_2025_07; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2025_07 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2025_07 OWNER TO hospital_owner;

--
-- Name: observation_2025_08; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2025_08 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2025_08 OWNER TO hospital_owner;

--
-- Name: observation_2025_09; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2025_09 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2025_09 OWNER TO hospital_owner;

--
-- Name: observation_2025_10; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2025_10 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2025_10 OWNER TO hospital_owner;

--
-- Name: observation_2025_11; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2025_11 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2025_11 OWNER TO hospital_owner;

--
-- Name: observation_2025_12; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2025_12 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2025_12 OWNER TO hospital_owner;

--
-- Name: observation_2026_01; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2026_01 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2026_01 OWNER TO hospital_owner;

--
-- Name: observation_2026_02; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2026_02 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2026_02 OWNER TO hospital_owner;

--
-- Name: observation_2026_03; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2026_03 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2026_03 OWNER TO hospital_owner;

--
-- Name: observation_2026_04; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2026_04 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2026_04 OWNER TO hospital_owner;

--
-- Name: observation_2026_05; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2026_05 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2026_05 OWNER TO hospital_owner;

--
-- Name: observation_2026_06; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2026_06 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2026_06 OWNER TO hospital_owner;

--
-- Name: observation_2026_07; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2026_07 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2026_07 OWNER TO hospital_owner;

--
-- Name: observation_2026_08; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2026_08 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2026_08 OWNER TO hospital_owner;

--
-- Name: observation_2026_09; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2026_09 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2026_09 OWNER TO hospital_owner;

--
-- Name: observation_2026_10; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2026_10 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2026_10 OWNER TO hospital_owner;

--
-- Name: observation_2026_11; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2026_11 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2026_11 OWNER TO hospital_owner;

--
-- Name: observation_2026_12; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2026_12 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2026_12 OWNER TO hospital_owner;

--
-- Name: observation_2027_01; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2027_01 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2027_01 OWNER TO hospital_owner;

--
-- Name: observation_2027_02; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2027_02 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2027_02 OWNER TO hospital_owner;

--
-- Name: observation_2027_03; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2027_03 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2027_03 OWNER TO hospital_owner;

--
-- Name: observation_2027_04; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2027_04 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2027_04 OWNER TO hospital_owner;

--
-- Name: observation_2027_05; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2027_05 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2027_05 OWNER TO hospital_owner;

--
-- Name: observation_2027_06; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2027_06 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2027_06 OWNER TO hospital_owner;

--
-- Name: observation_2027_07; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2027_07 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2027_07 OWNER TO hospital_owner;

--
-- Name: observation_2027_08; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2027_08 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2027_08 OWNER TO hospital_owner;

--
-- Name: observation_2027_09; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2027_09 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2027_09 OWNER TO hospital_owner;

--
-- Name: observation_2027_10; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2027_10 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2027_10 OWNER TO hospital_owner;

--
-- Name: observation_2027_11; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2027_11 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2027_11 OWNER TO hospital_owner;

--
-- Name: observation_2027_12; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.observation_2027_12 (
    id bigint CONSTRAINT observation_id_not_null NOT NULL,
    patient_id bigint CONSTRAINT observation_patient_id_not_null NOT NULL,
    encounter_id bigint CONSTRAINT observation_encounter_id_not_null NOT NULL,
    test_id integer CONSTRAINT observation_test_id_not_null NOT NULL,
    observed_at timestamp with time zone CONSTRAINT observation_observed_at_not_null NOT NULL,
    status text CONSTRAINT observation_status_not_null NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    value_concept_id integer,
    value_boolean boolean,
    unit_code text,
    recorded_by bigint CONSTRAINT observation_recorded_by_not_null NOT NULL,
    CONSTRAINT observation_check CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1)),
    CONSTRAINT observation_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT observation_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))
);


ALTER TABLE ehr.observation_2027_12 OWNER TO hospital_owner;

--
-- Name: observation_id_seq; Type: SEQUENCE; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.observation ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ehr.observation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: procedure; Type: TABLE; Schema: ehr; Owner: hospital_owner
--

CREATE TABLE ehr.procedure (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint NOT NULL,
    service_id integer NOT NULL,
    status text NOT NULL,
    performed_period tstzrange NOT NULL,
    performer_id bigint NOT NULL,
    outcome_text text,
    CONSTRAINT procedure_performed_period_check CHECK ((NOT isempty(performed_period))),
    CONSTRAINT procedure_status_check CHECK ((status = ANY (ARRAY['preparation'::text, 'in-progress'::text, 'completed'::text, 'not-done'::text])))
);

ALTER TABLE ONLY ehr.procedure FORCE ROW LEVEL SECURITY;


ALTER TABLE ehr.procedure OWNER TO hospital_owner;

--
-- Name: TABLE procedure; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON TABLE ehr.procedure IS 'Hospital reference model / ehr / procedure. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN procedure.id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.procedure.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN procedure.patient_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.procedure.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN procedure.encounter_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.procedure.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN procedure.service_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.procedure.service_id IS 'service id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN procedure.status; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.procedure.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN procedure.performed_period; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.procedure.performed_period IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: COLUMN procedure.performer_id; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.procedure.performer_id IS 'performer id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN procedure.outcome_text; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON COLUMN ehr.procedure.outcome_text IS 'outcome text; see table constraints and DATA_MODEL.md.';


--
-- Name: procedure_id_seq; Type: SEQUENCE; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.procedure ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ehr.procedure_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: staff; Type: TABLE; Schema: org; Owner: hospital_owner
--

CREATE TABLE org.staff (
    id bigint NOT NULL,
    staff_number text NOT NULL,
    display_name text NOT NULL,
    profession text NOT NULL,
    specialty_concept_id integer,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT staff_profession_check CHECK ((profession = ANY (ARRAY['physician'::text, 'nurse'::text, 'technician'::text, 'pharmacist'::text, 'administrator'::text])))
);


ALTER TABLE org.staff OWNER TO hospital_owner;

--
-- Name: TABLE staff; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON TABLE org.staff IS 'Hospital reference model / org / staff. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN staff.id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.staff.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN staff.staff_number; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.staff.staff_number IS 'staff number; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN staff.display_name; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.staff.display_name IS 'display name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN staff.profession; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.staff.profession IS 'profession; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN staff.specialty_concept_id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.staff.specialty_concept_id IS 'specialty concept id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN staff.active; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.staff.active IS 'active; see table constraints and DATA_MODEL.md.';


--
-- Name: v_patient_timeline; Type: VIEW; Schema: ehr; Owner: hospital_owner
--

CREATE VIEW ehr.v_patient_timeline WITH (security_invoker='true') AS
 SELECT e.id AS encounter_id,
    e.patient_id,
    e.type_code,
    e.status,
    e.started_at,
    e.ended_at,
    d.name AS department,
    s.display_name AS attending
   FROM ((ehr.encounter e
     JOIN org.department d ON ((d.id = e.department_id)))
     JOIN org.staff s ON ((s.id = e.attending_staff_id)));


ALTER VIEW ehr.v_patient_timeline OWNER TO hospital_owner;

--
-- Name: VIEW v_patient_timeline; Type: COMMENT; Schema: ehr; Owner: hospital_owner
--

COMMENT ON VIEW ehr.v_patient_timeline IS 'Hospital reference model / ehr / v patient timeline. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: access_grant; Type: TABLE; Schema: iam; Owner: hospital_owner
--

CREATE TABLE iam.access_grant (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    patient_id bigint NOT NULL,
    purpose text NOT NULL,
    valid_during tstzrange NOT NULL,
    granted_by bigint NOT NULL,
    reason text NOT NULL,
    CONSTRAINT access_grant_purpose_check CHECK ((purpose = ANY (ARRAY['treatment'::text, 'registration'::text, 'billing'::text]))),
    CONSTRAINT access_grant_valid_during_check CHECK ((NOT isempty(valid_during)))
);

ALTER TABLE ONLY iam.access_grant FORCE ROW LEVEL SECURITY;


ALTER TABLE iam.access_grant OWNER TO hospital_owner;

--
-- Name: TABLE access_grant; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON TABLE iam.access_grant IS 'Patient/purpose/time-limited authorization; keyed to session_user via application_user. Custom session GUCs are not an authorization source.';


--
-- Name: COLUMN access_grant.id; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.access_grant.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN access_grant.user_id; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.access_grant.user_id IS 'user id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN access_grant.patient_id; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.access_grant.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN access_grant.purpose; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.access_grant.purpose IS 'purpose; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN access_grant.valid_during; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.access_grant.valid_during IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: COLUMN access_grant.granted_by; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.access_grant.granted_by IS 'granted by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN access_grant.reason; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.access_grant.reason IS 'reason; see table constraints and DATA_MODEL.md.';


--
-- Name: access_grant_id_seq; Type: SEQUENCE; Schema: iam; Owner: hospital_owner
--

ALTER TABLE iam.access_grant ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME iam.access_grant_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: application_user; Type: TABLE; Schema: iam; Owner: hospital_owner
--

CREATE TABLE iam.application_user (
    id bigint NOT NULL,
    database_principal name NOT NULL,
    staff_id bigint,
    display_name text NOT NULL,
    active boolean DEFAULT true NOT NULL
);


ALTER TABLE iam.application_user OWNER TO hospital_owner;

--
-- Name: TABLE application_user; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON TABLE iam.application_user IS 'Hospital reference model / iam / application user. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN application_user.id; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.application_user.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN application_user.database_principal; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.application_user.database_principal IS 'database principal; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN application_user.staff_id; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.application_user.staff_id IS 'staff id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN application_user.display_name; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.application_user.display_name IS 'display name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN application_user.active; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.application_user.active IS 'active; see table constraints and DATA_MODEL.md.';


--
-- Name: application_user_id_seq; Type: SEQUENCE; Schema: iam; Owner: hospital_owner
--

ALTER TABLE iam.application_user ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME iam.application_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: break_glass; Type: TABLE; Schema: iam; Owner: hospital_owner
--

CREATE TABLE iam.break_glass (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    patient_id bigint NOT NULL,
    reason ref.nonblank_text NOT NULL,
    valid_during tstzrange NOT NULL,
    approved_by bigint NOT NULL,
    reviewed_at timestamp with time zone,
    CONSTRAINT break_glass_check CHECK ((user_id <> approved_by)),
    CONSTRAINT break_glass_valid_during_check CHECK (((NOT isempty(valid_during)) AND (NOT lower_inf(valid_during)) AND (NOT upper_inf(valid_during)) AND ((upper(valid_during) - lower(valid_during)) <= '01:00:00'::interval)))
);

ALTER TABLE ONLY iam.break_glass FORCE ROW LEVEL SECURITY;


ALTER TABLE iam.break_glass OWNER TO hospital_owner;

--
-- Name: TABLE break_glass; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON TABLE iam.break_glass IS 'Hospital reference model / iam / break glass. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN break_glass.id; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.break_glass.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN break_glass.user_id; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.break_glass.user_id IS 'user id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN break_glass.patient_id; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.break_glass.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN break_glass.reason; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.break_glass.reason IS 'reason; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN break_glass.valid_during; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.break_glass.valid_during IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: COLUMN break_glass.approved_by; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.break_glass.approved_by IS 'approved by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN break_glass.reviewed_at; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.break_glass.reviewed_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: break_glass_id_seq; Type: SEQUENCE; Schema: iam; Owner: hospital_owner
--

ALTER TABLE iam.break_glass ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME iam.break_glass_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: business_role; Type: TABLE; Schema: iam; Owner: hospital_owner
--

CREATE TABLE iam.business_role (
    code text NOT NULL,
    name text NOT NULL
);


ALTER TABLE iam.business_role OWNER TO hospital_owner;

--
-- Name: TABLE business_role; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON TABLE iam.business_role IS 'Hospital reference model / iam / business role. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN business_role.code; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.business_role.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN business_role.name; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.business_role.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: user_role; Type: TABLE; Schema: iam; Owner: hospital_owner
--

CREATE TABLE iam.user_role (
    user_id bigint NOT NULL,
    role_code text NOT NULL
);


ALTER TABLE iam.user_role OWNER TO hospital_owner;

--
-- Name: TABLE user_role; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON TABLE iam.user_role IS 'Hospital reference model / iam / user role. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN user_role.user_id; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.user_role.user_id IS 'user id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN user_role.role_code; Type: COMMENT; Schema: iam; Owner: hospital_owner
--

COMMENT ON COLUMN iam.user_role.role_code IS 'role code; see table constraints and DATA_MODEL.md.';


--
-- Name: imaging_order; Type: TABLE; Schema: imaging; Owner: hospital_owner
--

CREATE TABLE imaging.imaging_order (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint NOT NULL,
    service_id integer NOT NULL,
    requested_at timestamp with time zone NOT NULL,
    requested_by bigint NOT NULL,
    status text NOT NULL,
    CONSTRAINT imaging_order_status_check CHECK ((status = ANY (ARRAY['active'::text, 'completed'::text, 'cancelled'::text])))
);

ALTER TABLE ONLY imaging.imaging_order FORCE ROW LEVEL SECURITY;


ALTER TABLE imaging.imaging_order OWNER TO hospital_owner;

--
-- Name: TABLE imaging_order; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON TABLE imaging.imaging_order IS 'Hospital reference model / imaging / imaging order. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN imaging_order.id; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.imaging_order.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN imaging_order.patient_id; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.imaging_order.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN imaging_order.encounter_id; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.imaging_order.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN imaging_order.service_id; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.imaging_order.service_id IS 'service id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN imaging_order.requested_at; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.imaging_order.requested_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN imaging_order.requested_by; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.imaging_order.requested_by IS 'requested by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN imaging_order.status; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.imaging_order.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: imaging_order_id_seq; Type: SEQUENCE; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE imaging.imaging_order ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME imaging.imaging_order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: series; Type: TABLE; Schema: imaging; Owner: hospital_owner
--

CREATE TABLE imaging.series (
    id bigint NOT NULL,
    study_id bigint NOT NULL,
    series_instance_uid text NOT NULL,
    series_number integer NOT NULL,
    instance_count integer NOT NULL,
    storage_uri text NOT NULL,
    CONSTRAINT series_instance_count_check CHECK ((instance_count >= 0)),
    CONSTRAINT series_series_number_check CHECK ((series_number > 0))
);

ALTER TABLE ONLY imaging.series FORCE ROW LEVEL SECURITY;


ALTER TABLE imaging.series OWNER TO hospital_owner;

--
-- Name: TABLE series; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON TABLE imaging.series IS 'Hospital reference model / imaging / series. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN series.id; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.series.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN series.study_id; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.series.study_id IS 'study id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN series.series_instance_uid; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.series.series_instance_uid IS 'series instance uid; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN series.series_number; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.series.series_number IS 'series number; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN series.instance_count; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.series.instance_count IS 'instance count; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN series.storage_uri; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.series.storage_uri IS 'storage uri; see table constraints and DATA_MODEL.md.';


--
-- Name: series_id_seq; Type: SEQUENCE; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE imaging.series ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME imaging.series_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: study; Type: TABLE; Schema: imaging; Owner: hospital_owner
--

CREATE TABLE imaging.study (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    order_id bigint NOT NULL,
    study_instance_uid text NOT NULL,
    accession_number text NOT NULL,
    modality text NOT NULL,
    started_at timestamp with time zone NOT NULL,
    status text NOT NULL,
    device_id bigint NOT NULL,
    report_text text,
    CONSTRAINT study_modality_check CHECK ((modality = ANY (ARRAY['CT'::text, 'MR'::text, 'US'::text, 'DX'::text]))),
    CONSTRAINT study_status_check CHECK ((status = ANY (ARRAY['registered'::text, 'available'::text, 'cancelled'::text])))
);

ALTER TABLE ONLY imaging.study FORCE ROW LEVEL SECURITY;


ALTER TABLE imaging.study OWNER TO hospital_owner;

--
-- Name: TABLE study; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON TABLE imaging.study IS 'Hospital reference model / imaging / study. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN study.id; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.study.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN study.patient_id; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.study.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN study.order_id; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.study.order_id IS 'order id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN study.study_instance_uid; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.study.study_instance_uid IS 'study instance uid; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN study.accession_number; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.study.accession_number IS 'accession number; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN study.modality; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.study.modality IS 'modality; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN study.started_at; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.study.started_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN study.status; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.study.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN study.device_id; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.study.device_id IS 'device id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN study.report_text; Type: COMMENT; Schema: imaging; Owner: hospital_owner
--

COMMENT ON COLUMN imaging.study.report_text IS 'report text; see table constraints and DATA_MODEL.md.';


--
-- Name: study_id_seq; Type: SEQUENCE; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE imaging.study ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME imaging.study_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: export_job; Type: TABLE; Schema: integration; Owner: hospital_owner
--

CREATE TABLE integration.export_job (
    id bigint NOT NULL,
    requested_by bigint NOT NULL,
    purpose text NOT NULL,
    requested_at timestamp with time zone NOT NULL,
    status text NOT NULL,
    filter_json jsonb NOT NULL,
    output_uri text,
    completed_at timestamp with time zone,
    CONSTRAINT export_job_check CHECK (((completed_at IS NULL) OR (completed_at >= requested_at))),
    CONSTRAINT export_job_filter_json_check CHECK ((jsonb_typeof(filter_json) = 'object'::text)),
    CONSTRAINT export_job_status_check CHECK ((status = ANY (ARRAY['queued'::text, 'running'::text, 'completed'::text, 'failed'::text])))
);


ALTER TABLE integration.export_job OWNER TO hospital_owner;

--
-- Name: TABLE export_job; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON TABLE integration.export_job IS 'Hospital reference model / integration / export job. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN export_job.id; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.export_job.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN export_job.requested_by; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.export_job.requested_by IS 'requested by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN export_job.purpose; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.export_job.purpose IS 'purpose; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN export_job.requested_at; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.export_job.requested_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN export_job.status; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.export_job.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN export_job.filter_json; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.export_job.filter_json IS 'filter json; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN export_job.output_uri; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.export_job.output_uri IS 'output uri; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN export_job.completed_at; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.export_job.completed_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: export_job_id_seq; Type: SEQUENCE; Schema: integration; Owner: hospital_owner
--

ALTER TABLE integration.export_job ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME integration.export_job_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: external_identifier; Type: TABLE; Schema: integration; Owner: hospital_owner
--

CREATE TABLE integration.external_identifier (
    id bigint NOT NULL,
    resource_type text NOT NULL,
    internal_public_id uuid NOT NULL,
    system_uri text NOT NULL,
    external_id text NOT NULL,
    CONSTRAINT external_identifier_resource_type_check CHECK ((resource_type = ANY (ARRAY['Patient'::text, 'Encounter'::text, 'DiagnosticReport'::text, 'MedicationRequest'::text])))
);


ALTER TABLE integration.external_identifier OWNER TO hospital_owner;

--
-- Name: TABLE external_identifier; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON TABLE integration.external_identifier IS 'Hospital reference model / integration / external identifier. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN external_identifier.id; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.external_identifier.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN external_identifier.resource_type; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.external_identifier.resource_type IS 'resource type; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN external_identifier.internal_public_id; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.external_identifier.internal_public_id IS 'internal public id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN external_identifier.system_uri; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.external_identifier.system_uri IS 'system uri; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN external_identifier.external_id; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.external_identifier.external_id IS 'external id; see table constraints and DATA_MODEL.md.';


--
-- Name: external_identifier_id_seq; Type: SEQUENCE; Schema: integration; Owner: hospital_owner
--

ALTER TABLE integration.external_identifier ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME integration.external_identifier_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: inbox; Type: TABLE; Schema: integration; Owner: hospital_owner
--

CREATE TABLE integration.inbox (
    source text NOT NULL,
    message_id text NOT NULL,
    received_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    payload_sha256 bytea NOT NULL,
    status text NOT NULL,
    processed_at timestamp with time zone,
    error_text text,
    CONSTRAINT inbox_payload_sha256_check CHECK ((octet_length(payload_sha256) = 32)),
    CONSTRAINT inbox_status_check CHECK ((status = ANY (ARRAY['received'::text, 'processed'::text, 'failed'::text])))
);


ALTER TABLE integration.inbox OWNER TO hospital_owner;

--
-- Name: TABLE inbox; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON TABLE integration.inbox IS 'Hospital reference model / integration / inbox. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN inbox.source; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.inbox.source IS 'source; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN inbox.message_id; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.inbox.message_id IS 'message id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN inbox.received_at; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.inbox.received_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN inbox.payload_sha256; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.inbox.payload_sha256 IS 'payload sha256; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN inbox.status; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.inbox.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN inbox.processed_at; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.inbox.processed_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN inbox.error_text; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.inbox.error_text IS 'error text; see table constraints and DATA_MODEL.md.';


--
-- Name: outbox; Type: TABLE; Schema: integration; Owner: hospital_owner
--

CREATE TABLE integration.outbox (
    id bigint NOT NULL,
    event_id uuid DEFAULT gen_random_uuid() NOT NULL,
    aggregate_type text NOT NULL,
    aggregate_id text NOT NULL,
    event_type text NOT NULL,
    payload jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    published_at timestamp with time zone,
    attempts integer DEFAULT 0 NOT NULL,
    next_attempt_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    last_error text,
    CONSTRAINT outbox_attempts_check CHECK ((attempts >= 0)),
    CONSTRAINT outbox_payload_check CHECK ((jsonb_typeof(payload) = 'object'::text))
);


ALTER TABLE integration.outbox OWNER TO hospital_owner;

--
-- Name: TABLE outbox; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON TABLE integration.outbox IS 'Transactional outbox envelope; use SELECT FOR UPDATE SKIP LOCKED in a short transaction; delivery requires an external worker.';


--
-- Name: COLUMN outbox.id; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.outbox.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN outbox.event_id; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.outbox.event_id IS 'event id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN outbox.aggregate_type; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.outbox.aggregate_type IS 'aggregate type; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN outbox.aggregate_id; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.outbox.aggregate_id IS 'aggregate id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN outbox.event_type; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.outbox.event_type IS 'event type; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN outbox.payload; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.outbox.payload IS 'payload; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN outbox.created_at; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.outbox.created_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN outbox.published_at; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.outbox.published_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN outbox.attempts; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.outbox.attempts IS 'attempts; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN outbox.next_attempt_at; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.outbox.next_attempt_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN outbox.last_error; Type: COMMENT; Schema: integration; Owner: hospital_owner
--

COMMENT ON COLUMN integration.outbox.last_error IS 'last error; see table constraints and DATA_MODEL.md.';


--
-- Name: outbox_id_seq; Type: SEQUENCE; Schema: integration; Owner: hospital_owner
--

ALTER TABLE integration.outbox ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME integration.outbox_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: item; Type: TABLE; Schema: inventory; Owner: hospital_owner
--

CREATE TABLE inventory.item (
    id bigint NOT NULL,
    sku text NOT NULL,
    name text NOT NULL,
    medication_id integer,
    unit_code text NOT NULL,
    reorder_point numeric(18,4) NOT NULL,
    CONSTRAINT item_reorder_point_check CHECK ((reorder_point >= (0)::numeric))
);


ALTER TABLE inventory.item OWNER TO hospital_owner;

--
-- Name: TABLE item; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON TABLE inventory.item IS 'Hospital reference model / inventory / item. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN item.id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.item.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN item.sku; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.item.sku IS 'sku; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN item.name; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.item.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN item.medication_id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.item.medication_id IS 'medication id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN item.unit_code; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.item.unit_code IS 'unit code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN item.reorder_point; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.item.reorder_point IS 'reorder point; see table constraints and DATA_MODEL.md.';


--
-- Name: item_id_seq; Type: SEQUENCE; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE inventory.item ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventory.item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: location; Type: TABLE; Schema: inventory; Owner: hospital_owner
--

CREATE TABLE inventory.location (
    id bigint NOT NULL,
    department_id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL
);


ALTER TABLE inventory.location OWNER TO hospital_owner;

--
-- Name: TABLE location; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON TABLE inventory.location IS 'Hospital reference model / inventory / location. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN location.id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.location.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN location.department_id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.location.department_id IS 'department id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN location.code; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.location.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN location.name; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.location.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: location_id_seq; Type: SEQUENCE; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE inventory.location ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventory.location_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: lot; Type: TABLE; Schema: inventory; Owner: hospital_owner
--

CREATE TABLE inventory.lot (
    id bigint NOT NULL,
    item_id bigint NOT NULL,
    lot_number text NOT NULL,
    expires_on date NOT NULL,
    supplier_id bigint NOT NULL,
    received_on date NOT NULL,
    CONSTRAINT lot_check CHECK ((expires_on > received_on))
);


ALTER TABLE inventory.lot OWNER TO hospital_owner;

--
-- Name: TABLE lot; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON TABLE inventory.lot IS 'Hospital reference model / inventory / lot. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN lot.id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.lot.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN lot.item_id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.lot.item_id IS 'item id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN lot.lot_number; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.lot.lot_number IS 'lot number; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN lot.expires_on; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.lot.expires_on IS 'expires on; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN lot.supplier_id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.lot.supplier_id IS 'supplier id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN lot.received_on; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.lot.received_on IS 'received on; see table constraints and DATA_MODEL.md.';


--
-- Name: lot_id_seq; Type: SEQUENCE; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE inventory.lot ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventory.lot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: purchase_order; Type: TABLE; Schema: inventory; Owner: hospital_owner
--

CREATE TABLE inventory.purchase_order (
    id bigint NOT NULL,
    order_number text NOT NULL,
    supplier_id bigint NOT NULL,
    status text NOT NULL,
    ordered_at timestamp with time zone NOT NULL,
    currency_code character(3) NOT NULL,
    CONSTRAINT purchase_order_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'approved'::text, 'received'::text, 'cancelled'::text])))
);


ALTER TABLE inventory.purchase_order OWNER TO hospital_owner;

--
-- Name: TABLE purchase_order; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON TABLE inventory.purchase_order IS 'Hospital reference model / inventory / purchase order. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN purchase_order.id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.purchase_order.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN purchase_order.order_number; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.purchase_order.order_number IS 'order number; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN purchase_order.supplier_id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.purchase_order.supplier_id IS 'supplier id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN purchase_order.status; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.purchase_order.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN purchase_order.ordered_at; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.purchase_order.ordered_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN purchase_order.currency_code; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.purchase_order.currency_code IS 'currency code; see table constraints and DATA_MODEL.md.';


--
-- Name: purchase_order_id_seq; Type: SEQUENCE; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE inventory.purchase_order ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventory.purchase_order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: purchase_order_line; Type: TABLE; Schema: inventory; Owner: hospital_owner
--

CREATE TABLE inventory.purchase_order_line (
    order_id bigint NOT NULL,
    line_no integer NOT NULL,
    item_id bigint NOT NULL,
    quantity ref.positive_quantity NOT NULL,
    unit_price ref.nonnegative_money NOT NULL,
    CONSTRAINT purchase_order_line_line_no_check CHECK ((line_no > 0))
);


ALTER TABLE inventory.purchase_order_line OWNER TO hospital_owner;

--
-- Name: TABLE purchase_order_line; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON TABLE inventory.purchase_order_line IS 'Hospital reference model / inventory / purchase order line. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN purchase_order_line.order_id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.purchase_order_line.order_id IS 'order id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN purchase_order_line.line_no; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.purchase_order_line.line_no IS 'line no; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN purchase_order_line.item_id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.purchase_order_line.item_id IS 'item id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN purchase_order_line.quantity; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.purchase_order_line.quantity IS 'quantity; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN purchase_order_line.unit_price; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.purchase_order_line.unit_price IS 'unit price; see table constraints and DATA_MODEL.md.';


--
-- Name: stock_balance; Type: TABLE; Schema: inventory; Owner: hospital_owner
--

CREATE TABLE inventory.stock_balance (
    location_id bigint NOT NULL,
    lot_id bigint NOT NULL,
    quantity numeric(18,4) DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT stock_balance_quantity_check CHECK ((quantity >= (0)::numeric))
);


ALTER TABLE inventory.stock_balance OWNER TO hospital_owner;

--
-- Name: TABLE stock_balance; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON TABLE inventory.stock_balance IS 'Hospital reference model / inventory / stock balance. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN stock_balance.location_id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.stock_balance.location_id IS 'location id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN stock_balance.lot_id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.stock_balance.lot_id IS 'lot id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN stock_balance.quantity; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.stock_balance.quantity IS 'quantity; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN stock_balance.updated_at; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.stock_balance.updated_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: stock_movement; Type: TABLE; Schema: inventory; Owner: hospital_owner
--

CREATE TABLE inventory.stock_movement (
    id bigint NOT NULL,
    location_id bigint NOT NULL,
    lot_id bigint NOT NULL,
    quantity_delta numeric(18,4) NOT NULL,
    movement_type text NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    recorded_by bigint NOT NULL,
    dispense_id bigint,
    idempotency_key uuid DEFAULT gen_random_uuid() NOT NULL,
    reason ref.nonblank_text NOT NULL,
    CONSTRAINT stock_movement_check CHECK ((((movement_type = ANY (ARRAY['receipt'::text, 'transfer-in'::text])) AND (quantity_delta > (0)::numeric)) OR ((movement_type = ANY (ARRAY['dispense'::text, 'transfer-out'::text])) AND (quantity_delta < (0)::numeric)) OR (movement_type = 'adjustment'::text))),
    CONSTRAINT stock_movement_check1 CHECK (((movement_type = 'dispense'::text) = (dispense_id IS NOT NULL))),
    CONSTRAINT stock_movement_movement_type_check CHECK ((movement_type = ANY (ARRAY['receipt'::text, 'dispense'::text, 'adjustment'::text, 'transfer-in'::text, 'transfer-out'::text]))),
    CONSTRAINT stock_movement_quantity_delta_check CHECK ((quantity_delta <> (0)::numeric))
);


ALTER TABLE inventory.stock_movement OWNER TO hospital_owner;

--
-- Name: TABLE stock_movement; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON TABLE inventory.stock_movement IS 'Append-only inventory ledger. A per-location/lot balance is updated under row lock; negative stock rolls back the movement and dispensing transaction.';


--
-- Name: COLUMN stock_movement.id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.stock_movement.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN stock_movement.location_id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.stock_movement.location_id IS 'location id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN stock_movement.lot_id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.stock_movement.lot_id IS 'lot id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN stock_movement.quantity_delta; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.stock_movement.quantity_delta IS 'quantity delta; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN stock_movement.movement_type; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.stock_movement.movement_type IS 'movement type; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN stock_movement.occurred_at; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.stock_movement.occurred_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN stock_movement.recorded_by; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.stock_movement.recorded_by IS 'recorded by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN stock_movement.dispense_id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.stock_movement.dispense_id IS 'dispense id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN stock_movement.idempotency_key; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.stock_movement.idempotency_key IS 'idempotency key; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN stock_movement.reason; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.stock_movement.reason IS 'reason; see table constraints and DATA_MODEL.md.';


--
-- Name: stock_movement_id_seq; Type: SEQUENCE; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE inventory.stock_movement ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventory.stock_movement_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: supplier; Type: TABLE; Schema: inventory; Owner: hospital_owner
--

CREATE TABLE inventory.supplier (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    is_synthetic boolean DEFAULT true NOT NULL
);


ALTER TABLE inventory.supplier OWNER TO hospital_owner;

--
-- Name: TABLE supplier; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON TABLE inventory.supplier IS 'Hospital reference model / inventory / supplier. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN supplier.id; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.supplier.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN supplier.code; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.supplier.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN supplier.name; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.supplier.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN supplier.is_synthetic; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON COLUMN inventory.supplier.is_synthetic IS 'is synthetic; see table constraints and DATA_MODEL.md.';


--
-- Name: supplier_id_seq; Type: SEQUENCE; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE inventory.supplier ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME inventory.supplier_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: v_stock; Type: VIEW; Schema: inventory; Owner: hospital_owner
--

CREATE VIEW inventory.v_stock AS
 SELECT l.id AS lot_id,
    i.sku,
    i.name,
    lo.code AS location_code,
    l.expires_on,
    b.quantity,
    i.reorder_point,
    (b.quantity < i.reorder_point) AS below_reorder
   FROM (((inventory.stock_balance b
     JOIN inventory.lot l ON ((l.id = b.lot_id)))
     JOIN inventory.item i ON ((i.id = l.item_id)))
     JOIN inventory.location lo ON ((lo.id = b.location_id)));


ALTER VIEW inventory.v_stock OWNER TO hospital_owner;

--
-- Name: VIEW v_stock; Type: COMMENT; Schema: inventory; Owner: hospital_owner
--

COMMENT ON VIEW inventory.v_stock IS 'Hospital reference model / inventory / v stock. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: diagnostic_report; Type: TABLE; Schema: lab; Owner: hospital_owner
--

CREATE TABLE lab.diagnostic_report (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    request_id bigint NOT NULL,
    status text NOT NULL,
    issued_at timestamp with time zone NOT NULL,
    verified_by bigint NOT NULL,
    conclusion_text text,
    version integer DEFAULT 1 NOT NULL,
    CONSTRAINT diagnostic_report_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text]))),
    CONSTRAINT diagnostic_report_version_check CHECK ((version > 0))
);

ALTER TABLE ONLY lab.diagnostic_report FORCE ROW LEVEL SECURITY;


ALTER TABLE lab.diagnostic_report OWNER TO hospital_owner;

--
-- Name: TABLE diagnostic_report; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON TABLE lab.diagnostic_report IS 'Hospital reference model / lab / diagnostic report. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN diagnostic_report.id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.diagnostic_report.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN diagnostic_report.patient_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.diagnostic_report.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN diagnostic_report.request_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.diagnostic_report.request_id IS 'request id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN diagnostic_report.status; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.diagnostic_report.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN diagnostic_report.issued_at; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.diagnostic_report.issued_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN diagnostic_report.verified_by; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.diagnostic_report.verified_by IS 'verified by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN diagnostic_report.conclusion_text; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.diagnostic_report.conclusion_text IS 'conclusion text; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN diagnostic_report.version; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.diagnostic_report.version IS 'version; see table constraints and DATA_MODEL.md.';


--
-- Name: diagnostic_report_id_seq; Type: SEQUENCE; Schema: lab; Owner: hospital_owner
--

ALTER TABLE lab.diagnostic_report ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME lab.diagnostic_report_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: report_result; Type: TABLE; Schema: lab; Owner: hospital_owner
--

CREATE TABLE lab.report_result (
    report_id bigint NOT NULL,
    result_id bigint NOT NULL,
    patient_id bigint NOT NULL
);

ALTER TABLE ONLY lab.report_result FORCE ROW LEVEL SECURITY;


ALTER TABLE lab.report_result OWNER TO hospital_owner;

--
-- Name: TABLE report_result; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON TABLE lab.report_result IS 'Versioned diagnostic report membership; composite keys prevent patient mismatch. Further amendment workflow requires application orchestration.';


--
-- Name: COLUMN report_result.report_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.report_result.report_id IS 'report id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN report_result.result_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.report_result.result_id IS 'result id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN report_result.patient_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.report_result.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: request_specimen; Type: TABLE; Schema: lab; Owner: hospital_owner
--

CREATE TABLE lab.request_specimen (
    request_id bigint NOT NULL,
    specimen_id bigint NOT NULL,
    patient_id bigint NOT NULL
);

ALTER TABLE ONLY lab.request_specimen FORCE ROW LEVEL SECURITY;


ALTER TABLE lab.request_specimen OWNER TO hospital_owner;

--
-- Name: TABLE request_specimen; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON TABLE lab.request_specimen IS 'Hospital reference model / lab / request specimen. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN request_specimen.request_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.request_specimen.request_id IS 'request id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN request_specimen.specimen_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.request_specimen.specimen_id IS 'specimen id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN request_specimen.patient_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.request_specimen.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: result; Type: TABLE; Schema: lab; Owner: hospital_owner
--

CREATE TABLE lab.result (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    specimen_id bigint NOT NULL,
    test_id integer NOT NULL,
    measured_at timestamp with time zone NOT NULL,
    status text NOT NULL,
    value_numeric numeric(18,4),
    value_text text,
    unit_code text,
    reference_low numeric(18,4),
    reference_high numeric(18,4),
    interpretation text,
    analyzer_id bigint,
    CONSTRAINT result_check CHECK ((num_nonnulls(value_numeric, value_text) = 1)),
    CONSTRAINT result_check1 CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL))),
    CONSTRAINT result_check2 CHECK (((reference_low IS NULL) OR (reference_high IS NULL) OR (reference_low <= reference_high))),
    CONSTRAINT result_interpretation_check CHECK ((interpretation = ANY (ARRAY['N'::text, 'L'::text, 'H'::text, 'critical'::text, 'not-applicable'::text]))),
    CONSTRAINT result_status_check CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text])))
);

ALTER TABLE ONLY lab.result FORCE ROW LEVEL SECURITY;


ALTER TABLE lab.result OWNER TO hospital_owner;

--
-- Name: TABLE result; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON TABLE lab.result IS 'Hospital reference model / lab / result. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN result.id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.result.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN result.patient_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.result.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN result.specimen_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.result.specimen_id IS 'specimen id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN result.test_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.result.test_id IS 'test id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN result.measured_at; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.result.measured_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN result.status; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.result.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN result.value_numeric; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.result.value_numeric IS 'value numeric; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN result.value_text; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.result.value_text IS 'value text; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN result.unit_code; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.result.unit_code IS 'unit code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN result.reference_low; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.result.reference_low IS 'reference low; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN result.reference_high; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.result.reference_high IS 'reference high; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN result.interpretation; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.result.interpretation IS 'interpretation; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN result.analyzer_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.result.analyzer_id IS 'analyzer id; see table constraints and DATA_MODEL.md.';


--
-- Name: result_id_seq; Type: SEQUENCE; Schema: lab; Owner: hospital_owner
--

ALTER TABLE lab.result ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME lab.result_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: service_request; Type: TABLE; Schema: lab; Owner: hospital_owner
--

CREATE TABLE lab.service_request (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint NOT NULL,
    service_id integer NOT NULL,
    panel_id integer,
    ordered_by bigint NOT NULL,
    ordered_at timestamp with time zone NOT NULL,
    priority text NOT NULL,
    status text NOT NULL,
    CONSTRAINT service_request_priority_check CHECK ((priority = ANY (ARRAY['routine'::text, 'urgent'::text, 'stat'::text]))),
    CONSTRAINT service_request_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'completed'::text, 'cancelled'::text])))
);

ALTER TABLE ONLY lab.service_request FORCE ROW LEVEL SECURITY;


ALTER TABLE lab.service_request OWNER TO hospital_owner;

--
-- Name: TABLE service_request; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON TABLE lab.service_request IS 'Hospital reference model / lab / service request. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN service_request.id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.service_request.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN service_request.patient_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.service_request.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN service_request.encounter_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.service_request.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN service_request.service_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.service_request.service_id IS 'service id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN service_request.panel_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.service_request.panel_id IS 'panel id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN service_request.ordered_by; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.service_request.ordered_by IS 'ordered by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN service_request.ordered_at; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.service_request.ordered_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN service_request.priority; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.service_request.priority IS 'priority; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN service_request.status; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.service_request.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: service_request_id_seq; Type: SEQUENCE; Schema: lab; Owner: hospital_owner
--

ALTER TABLE lab.service_request ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME lab.service_request_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: specimen; Type: TABLE; Schema: lab; Owner: hospital_owner
--

CREATE TABLE lab.specimen (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    accession_number text NOT NULL,
    type_code text NOT NULL,
    collected_at timestamp with time zone NOT NULL,
    received_at timestamp with time zone,
    status text NOT NULL,
    collected_by bigint NOT NULL,
    CONSTRAINT specimen_check CHECK (((received_at IS NULL) OR (received_at >= collected_at))),
    CONSTRAINT specimen_status_check CHECK ((status = ANY (ARRAY['available'::text, 'unavailable'::text, 'unsatisfactory'::text])))
);

ALTER TABLE ONLY lab.specimen FORCE ROW LEVEL SECURITY;


ALTER TABLE lab.specimen OWNER TO hospital_owner;

--
-- Name: TABLE specimen; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON TABLE lab.specimen IS 'Hospital reference model / lab / specimen. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN specimen.id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.specimen.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN specimen.patient_id; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.specimen.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN specimen.accession_number; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.specimen.accession_number IS 'accession number; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN specimen.type_code; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.specimen.type_code IS 'type code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN specimen.collected_at; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.specimen.collected_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN specimen.received_at; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.specimen.received_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN specimen.status; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.specimen.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN specimen.collected_by; Type: COMMENT; Schema: lab; Owner: hospital_owner
--

COMMENT ON COLUMN lab.specimen.collected_by IS 'collected by; see table constraints and DATA_MODEL.md.';


--
-- Name: specimen_id_seq; Type: SEQUENCE; Schema: lab; Owner: hospital_owner
--

ALTER TABLE lab.specimen ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME lab.specimen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: address; Type: TABLE; Schema: mpi; Owner: hospital_owner
--

CREATE TABLE mpi.address (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    use_code text NOT NULL,
    country_code character(2) NOT NULL,
    city text NOT NULL,
    line_text text NOT NULL,
    postal_code text,
    location ext.geography(Point,4326),
    valid_during daterange NOT NULL,
    CONSTRAINT address_use_code_check CHECK ((use_code = ANY (ARRAY['home'::text, 'temporary'::text, 'work'::text]))),
    CONSTRAINT address_valid_during_check CHECK ((NOT isempty(valid_during)))
);

ALTER TABLE ONLY mpi.address FORCE ROW LEVEL SECURITY;


ALTER TABLE mpi.address OWNER TO hospital_owner;

--
-- Name: TABLE address; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON TABLE mpi.address IS 'Hospital reference model / mpi / address. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN address.id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.address.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN address.patient_id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.address.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN address.use_code; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.address.use_code IS 'use code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN address.country_code; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.address.country_code IS 'country code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN address.city; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.address.city IS 'city; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN address.line_text; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.address.line_text IS 'line text; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN address.postal_code; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.address.postal_code IS 'postal code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN address.location; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.address.location IS 'location; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN address.valid_during; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.address.valid_during IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: address_id_seq; Type: SEQUENCE; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE mpi.address ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME mpi.address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: consent; Type: TABLE; Schema: mpi; Owner: hospital_owner
--

CREATE TABLE mpi.consent (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    scope text NOT NULL,
    status text NOT NULL,
    valid_during tstzrange NOT NULL,
    recorded_at timestamp with time zone NOT NULL,
    recorded_by bigint NOT NULL,
    document_reference text,
    CONSTRAINT consent_scope_check CHECK ((scope = ANY (ARRAY['treatment'::text, 'data_exchange'::text, 'research'::text]))),
    CONSTRAINT consent_status_check CHECK ((status = ANY (ARRAY['active'::text, 'revoked'::text, 'expired'::text]))),
    CONSTRAINT consent_valid_during_check CHECK ((NOT isempty(valid_during)))
);

ALTER TABLE ONLY mpi.consent FORCE ROW LEVEL SECURITY;


ALTER TABLE mpi.consent OWNER TO hospital_owner;

--
-- Name: TABLE consent; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON TABLE mpi.consent IS 'Hospital reference model / mpi / consent. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN consent.id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.consent.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN consent.patient_id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.consent.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN consent.scope; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.consent.scope IS 'scope; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN consent.status; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.consent.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN consent.valid_during; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.consent.valid_during IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: COLUMN consent.recorded_at; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.consent.recorded_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN consent.recorded_by; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.consent.recorded_by IS 'recorded by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN consent.document_reference; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.consent.document_reference IS 'document reference; see table constraints and DATA_MODEL.md.';


--
-- Name: consent_id_seq; Type: SEQUENCE; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE mpi.consent ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME mpi.consent_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: contact; Type: TABLE; Schema: mpi; Owner: hospital_owner
--

CREATE TABLE mpi.contact (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    system text NOT NULL,
    value text NOT NULL,
    use_code text NOT NULL,
    rank smallint NOT NULL,
    CONSTRAINT contact_rank_check CHECK ((rank > 0)),
    CONSTRAINT contact_system_check CHECK ((system = ANY (ARRAY['phone'::text, 'email'::text])))
);

ALTER TABLE ONLY mpi.contact FORCE ROW LEVEL SECURITY;


ALTER TABLE mpi.contact OWNER TO hospital_owner;

--
-- Name: TABLE contact; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON TABLE mpi.contact IS 'Hospital reference model / mpi / contact. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN contact.id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.contact.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN contact.patient_id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.contact.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN contact.system; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.contact.system IS 'system; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN contact.value; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.contact.value IS 'value; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN contact.use_code; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.contact.use_code IS 'use code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN contact.rank; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.contact.rank IS 'rank; see table constraints and DATA_MODEL.md.';


--
-- Name: contact_id_seq; Type: SEQUENCE; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE mpi.contact ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME mpi.contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: identifier; Type: TABLE; Schema: mpi; Owner: hospital_owner
--

CREATE TABLE mpi.identifier (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    system_uri text NOT NULL,
    value ref.nonblank_text NOT NULL,
    valid_during daterange DEFAULT daterange(NULL::date, NULL::date, '[)'::text) NOT NULL,
    CONSTRAINT identifier_valid_during_check CHECK ((NOT isempty(valid_during)))
);

ALTER TABLE ONLY mpi.identifier FORCE ROW LEVEL SECURITY;


ALTER TABLE mpi.identifier OWNER TO hospital_owner;

--
-- Name: TABLE identifier; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON TABLE mpi.identifier IS 'Hospital reference model / mpi / identifier. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN identifier.id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.identifier.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN identifier.patient_id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.identifier.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN identifier.system_uri; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.identifier.system_uri IS 'system uri; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN identifier.value; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.identifier.value IS 'value; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN identifier.valid_during; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.identifier.valid_during IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: identifier_id_seq; Type: SEQUENCE; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE mpi.identifier ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME mpi.identifier_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: merge_history; Type: TABLE; Schema: mpi; Owner: hospital_owner
--

CREATE TABLE mpi.merge_history (
    id bigint NOT NULL,
    source_patient_id bigint NOT NULL,
    target_patient_id bigint NOT NULL,
    merged_at timestamp with time zone NOT NULL,
    merged_by bigint NOT NULL,
    reason ref.nonblank_text NOT NULL,
    CONSTRAINT merge_history_check CHECK ((source_patient_id <> target_patient_id))
);

ALTER TABLE ONLY mpi.merge_history FORCE ROW LEVEL SECURITY;


ALTER TABLE mpi.merge_history OWNER TO hospital_owner;

--
-- Name: TABLE merge_history; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON TABLE mpi.merge_history IS 'Hospital reference model / mpi / merge history. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN merge_history.id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.merge_history.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN merge_history.source_patient_id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.merge_history.source_patient_id IS 'source patient id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN merge_history.target_patient_id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.merge_history.target_patient_id IS 'target patient id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN merge_history.merged_at; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.merge_history.merged_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN merge_history.merged_by; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.merge_history.merged_by IS 'merged by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN merge_history.reason; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.merge_history.reason IS 'reason; see table constraints and DATA_MODEL.md.';


--
-- Name: merge_history_id_seq; Type: SEQUENCE; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE mpi.merge_history ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME mpi.merge_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: patient_id_seq; Type: SEQUENCE; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE mpi.patient ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME mpi.patient_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: related_person; Type: TABLE; Schema: mpi; Owner: hospital_owner
--

CREATE TABLE mpi.related_person (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    display_name text NOT NULL,
    relationship text NOT NULL,
    contact_text text,
    is_emergency_contact boolean DEFAULT false NOT NULL
);

ALTER TABLE ONLY mpi.related_person FORCE ROW LEVEL SECURITY;


ALTER TABLE mpi.related_person OWNER TO hospital_owner;

--
-- Name: TABLE related_person; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON TABLE mpi.related_person IS 'Hospital reference model / mpi / related person. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN related_person.id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.related_person.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN related_person.patient_id; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.related_person.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN related_person.display_name; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.related_person.display_name IS 'display name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN related_person.relationship; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.related_person.relationship IS 'relationship; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN related_person.contact_text; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.related_person.contact_text IS 'contact text; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN related_person.is_emergency_contact; Type: COMMENT; Schema: mpi; Owner: hospital_owner
--

COMMENT ON COLUMN mpi.related_person.is_emergency_contact IS 'is emergency contact; see table constraints and DATA_MODEL.md.';


--
-- Name: related_person_id_seq; Type: SEQUENCE; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE mpi.related_person ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME mpi.related_person_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: schema_migration; Type: TABLE; Schema: ops; Owner: hospital_owner
--

CREATE TABLE ops.schema_migration (
    version text NOT NULL,
    applied_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    description text NOT NULL
);


ALTER TABLE ops.schema_migration OWNER TO hospital_owner;

--
-- Name: TABLE schema_migration; Type: COMMENT; Schema: ops; Owner: hospital_owner
--

COMMENT ON TABLE ops.schema_migration IS 'Hospital reference model / ops / schema migration. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN schema_migration.version; Type: COMMENT; Schema: ops; Owner: hospital_owner
--

COMMENT ON COLUMN ops.schema_migration.version IS 'version; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN schema_migration.applied_at; Type: COMMENT; Schema: ops; Owner: hospital_owner
--

COMMENT ON COLUMN ops.schema_migration.applied_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN schema_migration.description; Type: COMMENT; Schema: ops; Owner: hospital_owner
--

COMMENT ON COLUMN ops.schema_migration.description IS 'description; see table constraints and DATA_MODEL.md.';


--
-- Name: bed_id_seq; Type: SEQUENCE; Schema: org; Owner: hospital_owner
--

ALTER TABLE org.bed ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME org.bed_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: credential; Type: TABLE; Schema: org; Owner: hospital_owner
--

CREATE TABLE org.credential (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    credential_type text NOT NULL,
    identifier text NOT NULL,
    valid_during daterange NOT NULL,
    issuer text NOT NULL,
    is_synthetic boolean DEFAULT true NOT NULL,
    CONSTRAINT credential_valid_during_check CHECK ((NOT isempty(valid_during)))
);


ALTER TABLE org.credential OWNER TO hospital_owner;

--
-- Name: TABLE credential; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON TABLE org.credential IS 'Hospital reference model / org / credential. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN credential.id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.credential.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN credential.staff_id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.credential.staff_id IS 'staff id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN credential.credential_type; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.credential.credential_type IS 'credential type; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN credential.identifier; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.credential.identifier IS 'identifier; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN credential.valid_during; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.credential.valid_during IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: COLUMN credential.issuer; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.credential.issuer IS 'issuer; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN credential.is_synthetic; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.credential.is_synthetic IS 'is synthetic; see table constraints and DATA_MODEL.md.';


--
-- Name: credential_id_seq; Type: SEQUENCE; Schema: org; Owner: hospital_owner
--

ALTER TABLE org.credential ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME org.credential_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: department_id_seq; Type: SEQUENCE; Schema: org; Owner: hospital_owner
--

ALTER TABLE org.department ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME org.department_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: device; Type: TABLE; Schema: org; Owner: hospital_owner
--

CREATE TABLE org.device (
    id bigint NOT NULL,
    department_id bigint NOT NULL,
    asset_tag text NOT NULL,
    name text NOT NULL,
    modality text,
    serial_number text,
    active boolean DEFAULT true NOT NULL,
    next_maintenance_on date
);


ALTER TABLE org.device OWNER TO hospital_owner;

--
-- Name: TABLE device; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON TABLE org.device IS 'Hospital reference model / org / device. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN device.id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.device.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN device.department_id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.device.department_id IS 'department id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN device.asset_tag; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.device.asset_tag IS 'asset tag; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN device.name; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.device.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN device.modality; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.device.modality IS 'modality; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN device.serial_number; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.device.serial_number IS 'serial number; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN device.active; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.device.active IS 'active; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN device.next_maintenance_on; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.device.next_maintenance_on IS 'next maintenance on; see table constraints and DATA_MODEL.md.';


--
-- Name: device_id_seq; Type: SEQUENCE; Schema: org; Owner: hospital_owner
--

ALTER TABLE org.device ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME org.device_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: organization; Type: TABLE; Schema: org; Owner: hospital_owner
--

CREATE TABLE org.organization (
    id bigint NOT NULL,
    public_id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    name ref.nonblank_text NOT NULL,
    kind text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT organization_kind_check CHECK ((kind = ANY (ARRAY['hospital'::text, 'clinic'::text, 'laboratory'::text])))
);


ALTER TABLE org.organization OWNER TO hospital_owner;

--
-- Name: TABLE organization; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON TABLE org.organization IS 'Hospital reference model / org / organization. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN organization.id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.organization.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN organization.public_id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.organization.public_id IS 'Opaque UUID for external references; does not confer authorization.';


--
-- Name: COLUMN organization.code; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.organization.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN organization.name; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.organization.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN organization.kind; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.organization.kind IS 'kind; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN organization.active; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.organization.active IS 'active; see table constraints and DATA_MODEL.md.';


--
-- Name: organization_id_seq; Type: SEQUENCE; Schema: org; Owner: hospital_owner
--

ALTER TABLE org.organization ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME org.organization_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: room_id_seq; Type: SEQUENCE; Schema: org; Owner: hospital_owner
--

ALTER TABLE org.room ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME org.room_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: site; Type: TABLE; Schema: org; Owner: hospital_owner
--

CREATE TABLE org.site (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    time_zone text DEFAULT 'Asia/Qyzylorda'::text NOT NULL,
    address_text text NOT NULL,
    location ext.geography(Point,4326)
);


ALTER TABLE org.site OWNER TO hospital_owner;

--
-- Name: TABLE site; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON TABLE org.site IS 'Hospital reference model / org / site. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN site.id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.site.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN site.organization_id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.site.organization_id IS 'organization id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN site.code; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.site.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN site.name; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.site.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN site.time_zone; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.site.time_zone IS 'time zone; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN site.address_text; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.site.address_text IS 'address text; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN site.location; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.site.location IS 'location; see table constraints and DATA_MODEL.md.';


--
-- Name: site_id_seq; Type: SEQUENCE; Schema: org; Owner: hospital_owner
--

ALTER TABLE org.site ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME org.site_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: staff_department; Type: TABLE; Schema: org; Owner: hospital_owner
--

CREATE TABLE org.staff_department (
    staff_id bigint NOT NULL,
    department_id bigint NOT NULL,
    valid_during daterange NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    CONSTRAINT staff_department_valid_during_check CHECK ((NOT isempty(valid_during)))
);


ALTER TABLE org.staff_department OWNER TO hospital_owner;

--
-- Name: TABLE staff_department; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON TABLE org.staff_department IS 'Hospital reference model / org / staff department. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN staff_department.staff_id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.staff_department.staff_id IS 'staff id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN staff_department.department_id; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.staff_department.department_id IS 'department id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN staff_department.valid_during; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.staff_department.valid_during IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: COLUMN staff_department.is_primary; Type: COMMENT; Schema: org; Owner: hospital_owner
--

COMMENT ON COLUMN org.staff_department.is_primary IS 'is primary; see table constraints and DATA_MODEL.md.';


--
-- Name: staff_id_seq; Type: SEQUENCE; Schema: org; Owner: hospital_owner
--

ALTER TABLE org.staff ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME org.staff_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: administration; Type: TABLE; Schema: pharmacy; Owner: hospital_owner
--

CREATE TABLE pharmacy.administration (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    order_id bigint NOT NULL,
    dispense_id bigint,
    administered_at timestamp with time zone NOT NULL,
    status text NOT NULL,
    quantity ref.positive_quantity,
    unit_code text,
    performed_by bigint NOT NULL,
    note text,
    CONSTRAINT administration_check CHECK (((status <> 'completed'::text) OR ((quantity IS NOT NULL) AND (unit_code IS NOT NULL)))),
    CONSTRAINT administration_status_check CHECK ((status = ANY (ARRAY['completed'::text, 'not-done'::text, 'entered-in-error'::text])))
);

ALTER TABLE ONLY pharmacy.administration FORCE ROW LEVEL SECURITY;


ALTER TABLE pharmacy.administration OWNER TO hospital_owner;

--
-- Name: TABLE administration; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON TABLE pharmacy.administration IS 'Hospital reference model / pharmacy / administration. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN administration.id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.administration.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN administration.patient_id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.administration.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN administration.order_id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.administration.order_id IS 'order id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN administration.dispense_id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.administration.dispense_id IS 'dispense id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN administration.administered_at; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.administration.administered_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN administration.status; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.administration.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN administration.quantity; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.administration.quantity IS 'quantity; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN administration.unit_code; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.administration.unit_code IS 'unit code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN administration.performed_by; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.administration.performed_by IS 'performed by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN administration.note; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.administration.note IS 'note; see table constraints and DATA_MODEL.md.';


--
-- Name: administration_id_seq; Type: SEQUENCE; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE pharmacy.administration ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME pharmacy.administration_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dispense; Type: TABLE; Schema: pharmacy; Owner: hospital_owner
--

CREATE TABLE pharmacy.dispense (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    order_id bigint NOT NULL,
    medication_id integer NOT NULL,
    item_id bigint NOT NULL,
    lot_id bigint NOT NULL,
    location_id bigint NOT NULL,
    quantity ref.positive_quantity NOT NULL,
    dispensed_at timestamp with time zone NOT NULL,
    dispensed_by bigint NOT NULL,
    idempotency_key uuid DEFAULT gen_random_uuid() NOT NULL
);

ALTER TABLE ONLY pharmacy.dispense FORCE ROW LEVEL SECURITY;


ALTER TABLE pharmacy.dispense OWNER TO hospital_owner;

--
-- Name: TABLE dispense; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON TABLE pharmacy.dispense IS 'Hospital reference model / pharmacy / dispense. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN dispense.id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.dispense.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN dispense.patient_id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.dispense.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN dispense.order_id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.dispense.order_id IS 'order id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN dispense.medication_id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.dispense.medication_id IS 'medication id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN dispense.item_id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.dispense.item_id IS 'item id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN dispense.lot_id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.dispense.lot_id IS 'lot id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN dispense.location_id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.dispense.location_id IS 'location id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN dispense.quantity; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.dispense.quantity IS 'quantity; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN dispense.dispensed_at; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.dispense.dispensed_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN dispense.dispensed_by; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.dispense.dispensed_by IS 'dispensed by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN dispense.idempotency_key; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.dispense.idempotency_key IS 'idempotency key; see table constraints and DATA_MODEL.md.';


--
-- Name: dispense_id_seq; Type: SEQUENCE; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE pharmacy.dispense ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME pharmacy.dispense_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: medication_order; Type: TABLE; Schema: pharmacy; Owner: hospital_owner
--

CREATE TABLE pharmacy.medication_order (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint NOT NULL,
    medication_id integer NOT NULL,
    ordered_by bigint NOT NULL,
    ordered_at timestamp with time zone NOT NULL,
    status text NOT NULL,
    route_code text NOT NULL,
    instructions text NOT NULL,
    valid_during tstzrange NOT NULL,
    CONSTRAINT medication_order_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'completed'::text, 'stopped'::text, 'cancelled'::text]))),
    CONSTRAINT medication_order_valid_during_check CHECK ((NOT isempty(valid_during)))
);

ALTER TABLE ONLY pharmacy.medication_order FORCE ROW LEVEL SECURITY;


ALTER TABLE pharmacy.medication_order OWNER TO hospital_owner;

--
-- Name: TABLE medication_order; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON TABLE pharmacy.medication_order IS 'Hospital reference model / pharmacy / medication order. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN medication_order.id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_order.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN medication_order.patient_id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_order.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN medication_order.encounter_id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_order.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN medication_order.medication_id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_order.medication_id IS 'medication id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN medication_order.ordered_by; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_order.ordered_by IS 'ordered by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN medication_order.ordered_at; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_order.ordered_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN medication_order.status; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_order.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN medication_order.route_code; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_order.route_code IS 'route code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN medication_order.instructions; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_order.instructions IS 'instructions; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN medication_order.valid_during; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_order.valid_during IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: medication_order_id_seq; Type: SEQUENCE; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE pharmacy.medication_order ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME pharmacy.medication_order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: medication_reconciliation; Type: TABLE; Schema: pharmacy; Owner: hospital_owner
--

CREATE TABLE pharmacy.medication_reconciliation (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint NOT NULL,
    reconciled_at timestamp with time zone NOT NULL,
    reconciled_by bigint NOT NULL,
    status text NOT NULL,
    note text NOT NULL,
    CONSTRAINT medication_reconciliation_status_check CHECK ((status = ANY (ARRAY['in-progress'::text, 'completed'::text])))
);

ALTER TABLE ONLY pharmacy.medication_reconciliation FORCE ROW LEVEL SECURITY;


ALTER TABLE pharmacy.medication_reconciliation OWNER TO hospital_owner;

--
-- Name: TABLE medication_reconciliation; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON TABLE pharmacy.medication_reconciliation IS 'Hospital reference model / pharmacy / medication reconciliation. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN medication_reconciliation.id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_reconciliation.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN medication_reconciliation.patient_id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_reconciliation.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN medication_reconciliation.encounter_id; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_reconciliation.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN medication_reconciliation.reconciled_at; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_reconciliation.reconciled_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN medication_reconciliation.reconciled_by; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_reconciliation.reconciled_by IS 'reconciled by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN medication_reconciliation.status; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_reconciliation.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN medication_reconciliation.note; Type: COMMENT; Schema: pharmacy; Owner: hospital_owner
--

COMMENT ON COLUMN pharmacy.medication_reconciliation.note IS 'note; see table constraints and DATA_MODEL.md.';


--
-- Name: medication_reconciliation_id_seq; Type: SEQUENCE; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE pharmacy.medication_reconciliation ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME pharmacy.medication_reconciliation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: incident; Type: TABLE; Schema: quality; Owner: hospital_owner
--

CREATE TABLE quality.incident (
    id bigint NOT NULL,
    patient_id bigint,
    encounter_id bigint,
    department_id bigint NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    reported_at timestamp with time zone NOT NULL,
    reported_by bigint NOT NULL,
    category text NOT NULL,
    severity text NOT NULL,
    status text NOT NULL,
    description text NOT NULL,
    CONSTRAINT incident_check CHECK ((reported_at >= occurred_at)),
    CONSTRAINT incident_check1 CHECK (((encounter_id IS NULL) OR (patient_id IS NOT NULL))),
    CONSTRAINT incident_severity_check CHECK ((severity = ANY (ARRAY['near-miss'::text, 'minor'::text, 'moderate'::text, 'severe'::text]))),
    CONSTRAINT incident_status_check CHECK ((status = ANY (ARRAY['open'::text, 'investigating'::text, 'closed'::text])))
);

ALTER TABLE ONLY quality.incident FORCE ROW LEVEL SECURITY;


ALTER TABLE quality.incident OWNER TO hospital_owner;

--
-- Name: TABLE incident; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON TABLE quality.incident IS 'Hospital reference model / quality / incident. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN incident.id; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.incident.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN incident.patient_id; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.incident.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN incident.encounter_id; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.incident.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN incident.department_id; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.incident.department_id IS 'department id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN incident.occurred_at; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.incident.occurred_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN incident.reported_at; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.incident.reported_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN incident.reported_by; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.incident.reported_by IS 'reported by; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN incident.category; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.incident.category IS 'category; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN incident.severity; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.incident.severity IS 'severity; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN incident.status; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.incident.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN incident.description; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.incident.description IS 'description; see table constraints and DATA_MODEL.md.';


--
-- Name: incident_id_seq; Type: SEQUENCE; Schema: quality; Owner: hospital_owner
--

ALTER TABLE quality.incident ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME quality.incident_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: infection_case; Type: TABLE; Schema: quality; Owner: hospital_owner
--

CREATE TABLE quality.infection_case (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint NOT NULL,
    onset_at timestamp with time zone NOT NULL,
    classification text NOT NULL,
    organism_concept_id integer,
    reported_by bigint NOT NULL,
    CONSTRAINT infection_case_classification_check CHECK ((classification = ANY (ARRAY['suspected'::text, 'confirmed'::text, 'excluded'::text])))
);

ALTER TABLE ONLY quality.infection_case FORCE ROW LEVEL SECURITY;


ALTER TABLE quality.infection_case OWNER TO hospital_owner;

--
-- Name: TABLE infection_case; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON TABLE quality.infection_case IS 'Hospital reference model / quality / infection case. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN infection_case.id; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.infection_case.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN infection_case.patient_id; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.infection_case.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN infection_case.encounter_id; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.infection_case.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN infection_case.onset_at; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.infection_case.onset_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN infection_case.classification; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.infection_case.classification IS 'classification; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN infection_case.organism_concept_id; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.infection_case.organism_concept_id IS 'organism concept id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN infection_case.reported_by; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.infection_case.reported_by IS 'reported by; see table constraints and DATA_MODEL.md.';


--
-- Name: infection_case_id_seq; Type: SEQUENCE; Schema: quality; Owner: hospital_owner
--

ALTER TABLE quality.infection_case ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME quality.infection_case_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: patient_feedback; Type: TABLE; Schema: quality; Owner: hospital_owner
--

CREATE TABLE quality.patient_feedback (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    encounter_id bigint NOT NULL,
    submitted_at timestamp with time zone NOT NULL,
    rating smallint NOT NULL,
    comment_text text,
    CONSTRAINT patient_feedback_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);

ALTER TABLE ONLY quality.patient_feedback FORCE ROW LEVEL SECURITY;


ALTER TABLE quality.patient_feedback OWNER TO hospital_owner;

--
-- Name: TABLE patient_feedback; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON TABLE quality.patient_feedback IS 'Hospital reference model / quality / patient feedback. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN patient_feedback.id; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.patient_feedback.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN patient_feedback.patient_id; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.patient_feedback.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN patient_feedback.encounter_id; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.patient_feedback.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN patient_feedback.submitted_at; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.patient_feedback.submitted_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN patient_feedback.rating; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.patient_feedback.rating IS 'rating; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN patient_feedback.comment_text; Type: COMMENT; Schema: quality; Owner: hospital_owner
--

COMMENT ON COLUMN quality.patient_feedback.comment_text IS 'comment text; see table constraints and DATA_MODEL.md.';


--
-- Name: patient_feedback_id_seq; Type: SEQUENCE; Schema: quality; Owner: hospital_owner
--

ALTER TABLE quality.patient_feedback ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME quality.patient_feedback_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: code_system; Type: TABLE; Schema: ref; Owner: hospital_owner
--

CREATE TABLE ref.code_system (
    id smallint NOT NULL,
    uri text NOT NULL,
    name ref.nonblank_text NOT NULL,
    version text NOT NULL,
    is_demo boolean DEFAULT true NOT NULL
);


ALTER TABLE ref.code_system OWNER TO hospital_owner;

--
-- Name: TABLE code_system; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON TABLE ref.code_system IS 'Hospital reference model / ref / code system. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN code_system.id; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.code_system.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN code_system.uri; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.code_system.uri IS 'uri; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN code_system.name; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.code_system.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN code_system.version; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.code_system.version IS 'version; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN code_system.is_demo; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.code_system.is_demo IS 'is demo; see table constraints and DATA_MODEL.md.';


--
-- Name: code_system_id_seq; Type: SEQUENCE; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ref.code_system ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.code_system_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: concept; Type: TABLE; Schema: ref; Owner: hospital_owner
--

CREATE TABLE ref.concept (
    id integer NOT NULL,
    system_id smallint NOT NULL,
    code text NOT NULL,
    display ref.nonblank_text NOT NULL,
    active boolean DEFAULT true NOT NULL
);


ALTER TABLE ref.concept OWNER TO hospital_owner;

--
-- Name: TABLE concept; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON TABLE ref.concept IS 'Hospital reference model / ref / concept. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN concept.id; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.concept.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN concept.system_id; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.concept.system_id IS 'system id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN concept.code; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.concept.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN concept.display; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.concept.display IS 'display; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN concept.active; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.concept.active IS 'active; see table constraints and DATA_MODEL.md.';


--
-- Name: concept_id_seq; Type: SEQUENCE; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ref.concept ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.concept_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: currency; Type: TABLE; Schema: ref; Owner: hospital_owner
--

CREATE TABLE ref.currency (
    code character(3) NOT NULL,
    label text NOT NULL,
    minor_units smallint NOT NULL,
    CONSTRAINT currency_minor_units_check CHECK (((minor_units >= 0) AND (minor_units <= 4)))
);


ALTER TABLE ref.currency OWNER TO hospital_owner;

--
-- Name: TABLE currency; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON TABLE ref.currency IS 'Hospital reference model / ref / currency. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN currency.code; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.currency.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN currency.label; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.currency.label IS 'label; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN currency.minor_units; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.currency.minor_units IS 'minor units; see table constraints and DATA_MODEL.md.';


--
-- Name: encounter_type; Type: TABLE; Schema: ref; Owner: hospital_owner
--

CREATE TABLE ref.encounter_type (
    code text NOT NULL,
    label text NOT NULL
);


ALTER TABLE ref.encounter_type OWNER TO hospital_owner;

--
-- Name: TABLE encounter_type; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON TABLE ref.encounter_type IS 'Hospital reference model / ref / encounter type. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN encounter_type.code; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.encounter_type.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN encounter_type.label; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.encounter_type.label IS 'label; see table constraints and DATA_MODEL.md.';


--
-- Name: medication; Type: TABLE; Schema: ref; Owner: hospital_owner
--

CREATE TABLE ref.medication (
    id integer NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    form text NOT NULL,
    unit_code text NOT NULL,
    is_demo boolean DEFAULT true NOT NULL,
    active boolean DEFAULT true NOT NULL
);


ALTER TABLE ref.medication OWNER TO hospital_owner;

--
-- Name: TABLE medication; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON TABLE ref.medication IS 'Hospital reference model / ref / medication. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN medication.id; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.medication.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN medication.code; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.medication.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN medication.name; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.medication.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN medication.form; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.medication.form IS 'form; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN medication.unit_code; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.medication.unit_code IS 'unit code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN medication.is_demo; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.medication.is_demo IS 'is demo; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN medication.active; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.medication.active IS 'active; see table constraints and DATA_MODEL.md.';


--
-- Name: medication_id_seq; Type: SEQUENCE; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ref.medication ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.medication_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: panel_item; Type: TABLE; Schema: ref; Owner: hospital_owner
--

CREATE TABLE ref.panel_item (
    panel_id integer NOT NULL,
    test_id integer NOT NULL,
    "position" smallint NOT NULL,
    CONSTRAINT panel_item_position_check CHECK (("position" > 0))
);


ALTER TABLE ref.panel_item OWNER TO hospital_owner;

--
-- Name: TABLE panel_item; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON TABLE ref.panel_item IS 'Hospital reference model / ref / panel item. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN panel_item.panel_id; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.panel_item.panel_id IS 'panel id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN panel_item.test_id; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.panel_item.test_id IS 'test id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN panel_item."position"; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.panel_item."position" IS 'position; see table constraints and DATA_MODEL.md.';


--
-- Name: route; Type: TABLE; Schema: ref; Owner: hospital_owner
--

CREATE TABLE ref.route (
    code text NOT NULL,
    name text NOT NULL
);


ALTER TABLE ref.route OWNER TO hospital_owner;

--
-- Name: TABLE route; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON TABLE ref.route IS 'Hospital reference model / ref / route. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN route.code; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.route.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN route.name; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.route.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: service; Type: TABLE; Schema: ref; Owner: hospital_owner
--

CREATE TABLE ref.service (
    id integer NOT NULL,
    code text NOT NULL,
    name ref.nonblank_text NOT NULL,
    category text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT service_category_check CHECK ((category = ANY (ARRAY['consultation'::text, 'laboratory'::text, 'imaging'::text, 'procedure'::text, 'bed_day'::text])))
);


ALTER TABLE ref.service OWNER TO hospital_owner;

--
-- Name: TABLE service; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON TABLE ref.service IS 'Hospital reference model / ref / service. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN service.id; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.service.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN service.code; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.service.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN service.name; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.service.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN service.category; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.service.category IS 'category; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN service.active; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.service.active IS 'active; see table constraints and DATA_MODEL.md.';


--
-- Name: service_id_seq; Type: SEQUENCE; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ref.service ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.service_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: test; Type: TABLE; Schema: ref; Owner: hospital_owner
--

CREATE TABLE ref.test (
    id integer NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    unit_code text,
    value_type text NOT NULL,
    reference_note text DEFAULT 'Synthetic demonstration; no clinical reference interval'::text NOT NULL,
    CONSTRAINT test_value_type_check CHECK ((value_type = ANY (ARRAY['numeric'::text, 'text'::text, 'coded'::text, 'boolean'::text])))
);


ALTER TABLE ref.test OWNER TO hospital_owner;

--
-- Name: TABLE test; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON TABLE ref.test IS 'Hospital reference model / ref / test. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN test.id; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.test.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN test.code; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.test.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN test.name; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.test.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN test.unit_code; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.test.unit_code IS 'unit code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN test.value_type; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.test.value_type IS 'value type; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN test.reference_note; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.test.reference_note IS 'reference note; see table constraints and DATA_MODEL.md.';


--
-- Name: test_id_seq; Type: SEQUENCE; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ref.test ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.test_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: test_panel; Type: TABLE; Schema: ref; Owner: hospital_owner
--

CREATE TABLE ref.test_panel (
    id integer NOT NULL,
    code text NOT NULL,
    name text NOT NULL
);


ALTER TABLE ref.test_panel OWNER TO hospital_owner;

--
-- Name: TABLE test_panel; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON TABLE ref.test_panel IS 'Hospital reference model / ref / test panel. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN test_panel.id; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.test_panel.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN test_panel.code; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.test_panel.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN test_panel.name; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.test_panel.name IS 'name; see table constraints and DATA_MODEL.md.';


--
-- Name: test_panel_id_seq; Type: SEQUENCE; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ref.test_panel ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME ref.test_panel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: unit; Type: TABLE; Schema: ref; Owner: hospital_owner
--

CREATE TABLE ref.unit (
    code text NOT NULL,
    label text NOT NULL,
    dimension text NOT NULL,
    ucum_code text
);


ALTER TABLE ref.unit OWNER TO hospital_owner;

--
-- Name: TABLE unit; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON TABLE ref.unit IS 'Hospital reference model / ref / unit. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN unit.code; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.unit.code IS 'code; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN unit.label; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.unit.label IS 'label; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN unit.dimension; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.unit.dimension IS 'dimension; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN unit.ucum_code; Type: COMMENT; Schema: ref; Owner: hospital_owner
--

COMMENT ON COLUMN ref.unit.ucum_code IS 'ucum code; see table constraints and DATA_MODEL.md.';


--
-- Name: appointment; Type: TABLE; Schema: scheduling; Owner: hospital_owner
--

CREATE TABLE scheduling.appointment (
    id bigint NOT NULL,
    patient_id bigint NOT NULL,
    slot_id bigint NOT NULL,
    service_id integer NOT NULL,
    status text NOT NULL,
    created_at timestamp with time zone NOT NULL,
    encounter_id bigint,
    reason_text text,
    appointment_period tstzrange NOT NULL,
    CONSTRAINT appointment_status_check CHECK ((status = ANY (ARRAY['booked'::text, 'arrived'::text, 'fulfilled'::text, 'cancelled'::text, 'noshow'::text])))
);

ALTER TABLE ONLY scheduling.appointment FORCE ROW LEVEL SECURITY;


ALTER TABLE scheduling.appointment OWNER TO hospital_owner;

--
-- Name: TABLE appointment; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON TABLE scheduling.appointment IS 'Hospital reference model / scheduling / appointment. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN appointment.id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.appointment.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN appointment.patient_id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.appointment.patient_id IS 'Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable.';


--
-- Name: COLUMN appointment.slot_id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.appointment.slot_id IS 'slot id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN appointment.service_id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.appointment.service_id IS 'service id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN appointment.status; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.appointment.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN appointment.created_at; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.appointment.created_at IS 'Instant stored as timestamptz; display timezone Asia/Qyzylorda.';


--
-- Name: COLUMN appointment.encounter_id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.appointment.encounter_id IS 'encounter id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN appointment.reason_text; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.appointment.reason_text IS 'reason text; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN appointment.appointment_period; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.appointment.appointment_period IS 'Controlled copy of slot period; trigger-maintained and protected by a patient overlap exclusion constraint.';


--
-- Name: appointment_id_seq; Type: SEQUENCE; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE scheduling.appointment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME scheduling.appointment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: appointment_participant; Type: TABLE; Schema: scheduling; Owner: hospital_owner
--

CREATE TABLE scheduling.appointment_participant (
    appointment_id bigint NOT NULL,
    staff_id bigint NOT NULL,
    status text NOT NULL,
    CONSTRAINT appointment_participant_status_check CHECK ((status = ANY (ARRAY['accepted'::text, 'tentative'::text, 'declined'::text])))
);

ALTER TABLE ONLY scheduling.appointment_participant FORCE ROW LEVEL SECURITY;


ALTER TABLE scheduling.appointment_participant OWNER TO hospital_owner;

--
-- Name: TABLE appointment_participant; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON TABLE scheduling.appointment_participant IS 'Hospital reference model / scheduling / appointment participant. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN appointment_participant.appointment_id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.appointment_participant.appointment_id IS 'appointment id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN appointment_participant.staff_id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.appointment_participant.staff_id IS 'staff id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN appointment_participant.status; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.appointment_participant.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: schedule; Type: TABLE; Schema: scheduling; Owner: hospital_owner
--

CREATE TABLE scheduling.schedule (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    department_id bigint NOT NULL,
    valid_during daterange NOT NULL,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT schedule_valid_during_check CHECK ((NOT isempty(valid_during)))
);


ALTER TABLE scheduling.schedule OWNER TO hospital_owner;

--
-- Name: TABLE schedule; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON TABLE scheduling.schedule IS 'Hospital reference model / scheduling / schedule. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN schedule.id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.schedule.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN schedule.staff_id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.schedule.staff_id IS 'staff id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN schedule.department_id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.schedule.department_id IS 'department id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN schedule.valid_during; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.schedule.valid_during IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: COLUMN schedule.active; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.schedule.active IS 'active; see table constraints and DATA_MODEL.md.';


--
-- Name: schedule_id_seq; Type: SEQUENCE; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE scheduling.schedule ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME scheduling.schedule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: slot; Type: TABLE; Schema: scheduling; Owner: hospital_owner
--

CREATE TABLE scheduling.slot (
    id bigint NOT NULL,
    schedule_id bigint NOT NULL,
    staff_id bigint NOT NULL,
    department_id bigint NOT NULL,
    room_id bigint NOT NULL,
    slot_period tstzrange NOT NULL,
    status text NOT NULL,
    CONSTRAINT slot_slot_period_check CHECK (((NOT isempty(slot_period)) AND (NOT lower_inf(slot_period)) AND (NOT upper_inf(slot_period)) AND lower_inc(slot_period) AND (NOT upper_inc(slot_period)))),
    CONSTRAINT slot_status_check CHECK ((status = ANY (ARRAY['free'::text, 'busy'::text, 'blocked'::text])))
);


ALTER TABLE scheduling.slot OWNER TO hospital_owner;

--
-- Name: TABLE slot; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON TABLE scheduling.slot IS 'Hospital reference model / scheduling / slot. Synthetic demonstration; see DATA_MODEL.md for semantics.';


--
-- Name: COLUMN slot.id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.slot.id IS 'Internal immutable surrogate key; identity sequence.';


--
-- Name: COLUMN slot.schedule_id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.slot.schedule_id IS 'schedule id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN slot.staff_id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.slot.staff_id IS 'staff id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN slot.department_id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.slot.department_id IS 'department id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN slot.room_id; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.slot.room_id IS 'room id; see table constraints and DATA_MODEL.md.';


--
-- Name: COLUMN slot.slot_period; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.slot.slot_period IS 'Validity interval; temporal constraints apply. Use half-open [start,end) convention.';


--
-- Name: COLUMN slot.status; Type: COMMENT; Schema: scheduling; Owner: hospital_owner
--

COMMENT ON COLUMN scheduling.slot.status IS 'status; see table constraints and DATA_MODEL.md.';


--
-- Name: slot_id_seq; Type: SEQUENCE; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE scheduling.slot ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME scheduling.slot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: observation_2024_01; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2024_01 FOR VALUES FROM ('2024-01-01 00:00:00+05') TO ('2024-02-01 00:00:00+05');


--
-- Name: observation_2024_02; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2024_02 FOR VALUES FROM ('2024-02-01 00:00:00+05') TO ('2024-03-01 00:00:00+05');


--
-- Name: observation_2024_03; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2024_03 FOR VALUES FROM ('2024-03-01 00:00:00+05') TO ('2024-04-01 00:00:00+05');


--
-- Name: observation_2024_04; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2024_04 FOR VALUES FROM ('2024-04-01 00:00:00+05') TO ('2024-05-01 00:00:00+05');


--
-- Name: observation_2024_05; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2024_05 FOR VALUES FROM ('2024-05-01 00:00:00+05') TO ('2024-06-01 00:00:00+05');


--
-- Name: observation_2024_06; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2024_06 FOR VALUES FROM ('2024-06-01 00:00:00+05') TO ('2024-07-01 00:00:00+05');


--
-- Name: observation_2024_07; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2024_07 FOR VALUES FROM ('2024-07-01 00:00:00+05') TO ('2024-08-01 00:00:00+05');


--
-- Name: observation_2024_08; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2024_08 FOR VALUES FROM ('2024-08-01 00:00:00+05') TO ('2024-09-01 00:00:00+05');


--
-- Name: observation_2024_09; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2024_09 FOR VALUES FROM ('2024-09-01 00:00:00+05') TO ('2024-10-01 00:00:00+05');


--
-- Name: observation_2024_10; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2024_10 FOR VALUES FROM ('2024-10-01 00:00:00+05') TO ('2024-11-01 00:00:00+05');


--
-- Name: observation_2024_11; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2024_11 FOR VALUES FROM ('2024-11-01 00:00:00+05') TO ('2024-12-01 00:00:00+05');


--
-- Name: observation_2024_12; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2024_12 FOR VALUES FROM ('2024-12-01 00:00:00+05') TO ('2025-01-01 00:00:00+05');


--
-- Name: observation_2025_01; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2025_01 FOR VALUES FROM ('2025-01-01 00:00:00+05') TO ('2025-02-01 00:00:00+05');


--
-- Name: observation_2025_02; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2025_02 FOR VALUES FROM ('2025-02-01 00:00:00+05') TO ('2025-03-01 00:00:00+05');


--
-- Name: observation_2025_03; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2025_03 FOR VALUES FROM ('2025-03-01 00:00:00+05') TO ('2025-04-01 00:00:00+05');


--
-- Name: observation_2025_04; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2025_04 FOR VALUES FROM ('2025-04-01 00:00:00+05') TO ('2025-05-01 00:00:00+05');


--
-- Name: observation_2025_05; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2025_05 FOR VALUES FROM ('2025-05-01 00:00:00+05') TO ('2025-06-01 00:00:00+05');


--
-- Name: observation_2025_06; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2025_06 FOR VALUES FROM ('2025-06-01 00:00:00+05') TO ('2025-07-01 00:00:00+05');


--
-- Name: observation_2025_07; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2025_07 FOR VALUES FROM ('2025-07-01 00:00:00+05') TO ('2025-08-01 00:00:00+05');


--
-- Name: observation_2025_08; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2025_08 FOR VALUES FROM ('2025-08-01 00:00:00+05') TO ('2025-09-01 00:00:00+05');


--
-- Name: observation_2025_09; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2025_09 FOR VALUES FROM ('2025-09-01 00:00:00+05') TO ('2025-10-01 00:00:00+05');


--
-- Name: observation_2025_10; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2025_10 FOR VALUES FROM ('2025-10-01 00:00:00+05') TO ('2025-11-01 00:00:00+05');


--
-- Name: observation_2025_11; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2025_11 FOR VALUES FROM ('2025-11-01 00:00:00+05') TO ('2025-12-01 00:00:00+05');


--
-- Name: observation_2025_12; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2025_12 FOR VALUES FROM ('2025-12-01 00:00:00+05') TO ('2026-01-01 00:00:00+05');


--
-- Name: observation_2026_01; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2026_01 FOR VALUES FROM ('2026-01-01 00:00:00+05') TO ('2026-02-01 00:00:00+05');


--
-- Name: observation_2026_02; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2026_02 FOR VALUES FROM ('2026-02-01 00:00:00+05') TO ('2026-03-01 00:00:00+05');


--
-- Name: observation_2026_03; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2026_03 FOR VALUES FROM ('2026-03-01 00:00:00+05') TO ('2026-04-01 00:00:00+05');


--
-- Name: observation_2026_04; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2026_04 FOR VALUES FROM ('2026-04-01 00:00:00+05') TO ('2026-05-01 00:00:00+05');


--
-- Name: observation_2026_05; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2026_05 FOR VALUES FROM ('2026-05-01 00:00:00+05') TO ('2026-06-01 00:00:00+05');


--
-- Name: observation_2026_06; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2026_06 FOR VALUES FROM ('2026-06-01 00:00:00+05') TO ('2026-07-01 00:00:00+05');


--
-- Name: observation_2026_07; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2026_07 FOR VALUES FROM ('2026-07-01 00:00:00+05') TO ('2026-08-01 00:00:00+05');


--
-- Name: observation_2026_08; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2026_08 FOR VALUES FROM ('2026-08-01 00:00:00+05') TO ('2026-09-01 00:00:00+05');


--
-- Name: observation_2026_09; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2026_09 FOR VALUES FROM ('2026-09-01 00:00:00+05') TO ('2026-10-01 00:00:00+05');


--
-- Name: observation_2026_10; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2026_10 FOR VALUES FROM ('2026-10-01 00:00:00+05') TO ('2026-11-01 00:00:00+05');


--
-- Name: observation_2026_11; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2026_11 FOR VALUES FROM ('2026-11-01 00:00:00+05') TO ('2026-12-01 00:00:00+05');


--
-- Name: observation_2026_12; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2026_12 FOR VALUES FROM ('2026-12-01 00:00:00+05') TO ('2027-01-01 00:00:00+05');


--
-- Name: observation_2027_01; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2027_01 FOR VALUES FROM ('2027-01-01 00:00:00+05') TO ('2027-02-01 00:00:00+05');


--
-- Name: observation_2027_02; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2027_02 FOR VALUES FROM ('2027-02-01 00:00:00+05') TO ('2027-03-01 00:00:00+05');


--
-- Name: observation_2027_03; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2027_03 FOR VALUES FROM ('2027-03-01 00:00:00+05') TO ('2027-04-01 00:00:00+05');


--
-- Name: observation_2027_04; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2027_04 FOR VALUES FROM ('2027-04-01 00:00:00+05') TO ('2027-05-01 00:00:00+05');


--
-- Name: observation_2027_05; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2027_05 FOR VALUES FROM ('2027-05-01 00:00:00+05') TO ('2027-06-01 00:00:00+05');


--
-- Name: observation_2027_06; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2027_06 FOR VALUES FROM ('2027-06-01 00:00:00+05') TO ('2027-07-01 00:00:00+05');


--
-- Name: observation_2027_07; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2027_07 FOR VALUES FROM ('2027-07-01 00:00:00+05') TO ('2027-08-01 00:00:00+05');


--
-- Name: observation_2027_08; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2027_08 FOR VALUES FROM ('2027-08-01 00:00:00+05') TO ('2027-09-01 00:00:00+05');


--
-- Name: observation_2027_09; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2027_09 FOR VALUES FROM ('2027-09-01 00:00:00+05') TO ('2027-10-01 00:00:00+05');


--
-- Name: observation_2027_10; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2027_10 FOR VALUES FROM ('2027-10-01 00:00:00+05') TO ('2027-11-01 00:00:00+05');


--
-- Name: observation_2027_11; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2027_11 FOR VALUES FROM ('2027-11-01 00:00:00+05') TO ('2027-12-01 00:00:00+05');


--
-- Name: observation_2027_12; Type: TABLE ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation ATTACH PARTITION ehr.observation_2027_12 FOR VALUES FROM ('2027-12-01 00:00:00+05') TO ('2028-01-01 00:00:00+05');


--
-- Name: admission admission_admission_number_key; Type: CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.admission
    ADD CONSTRAINT admission_admission_number_key UNIQUE (admission_number);


--
-- Name: admission admission_encounter_id_key; Type: CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.admission
    ADD CONSTRAINT admission_encounter_id_key UNIQUE (encounter_id);


--
-- Name: admission admission_id_patient_id_key; Type: CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.admission
    ADD CONSTRAINT admission_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: admission admission_patient_id_tstzrange_excl; Type: CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.admission
    ADD CONSTRAINT admission_patient_id_tstzrange_excl EXCLUDE USING gist (patient_id WITH =, tstzrange(admitted_at, discharged_at, '[)'::text) WITH &&);


--
-- Name: admission admission_pkey; Type: CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.admission
    ADD CONSTRAINT admission_pkey PRIMARY KEY (id);


--
-- Name: bed_stay bed_stay_bed_id_occupied_during_excl; Type: CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.bed_stay
    ADD CONSTRAINT bed_stay_bed_id_occupied_during_excl EXCLUDE USING gist (bed_id WITH =, occupied_during WITH &&);


--
-- Name: bed_stay bed_stay_patient_id_occupied_during_excl; Type: CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.bed_stay
    ADD CONSTRAINT bed_stay_patient_id_occupied_during_excl EXCLUDE USING gist (patient_id WITH =, occupied_during WITH &&);


--
-- Name: bed_stay bed_stay_pkey; Type: CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.bed_stay
    ADD CONSTRAINT bed_stay_pkey PRIMARY KEY (id);


--
-- Name: discharge discharge_pkey; Type: CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.discharge
    ADD CONSTRAINT discharge_pkey PRIMARY KEY (admission_id);


--
-- Name: access_event access_event_pkey; Type: CONSTRAINT; Schema: audit; Owner: hospital_owner
--

ALTER TABLE ONLY audit.access_event
    ADD CONSTRAINT access_event_pkey PRIMARY KEY (id);


--
-- Name: event event_pkey; Type: CONSTRAINT; Schema: audit; Owner: hospital_owner
--

ALTER TABLE ONLY audit.event
    ADD CONSTRAINT event_pkey PRIMARY KEY (id);


--
-- Name: claim claim_claim_number_key; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.claim
    ADD CONSTRAINT claim_claim_number_key UNIQUE (claim_number);


--
-- Name: claim claim_invoice_id_key; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.claim
    ADD CONSTRAINT claim_invoice_id_key UNIQUE (invoice_id);


--
-- Name: claim claim_pkey; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.claim
    ADD CONSTRAINT claim_pkey PRIMARY KEY (id);


--
-- Name: coverage coverage_id_patient_id_key; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.coverage
    ADD CONSTRAINT coverage_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: coverage coverage_pkey; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.coverage
    ADD CONSTRAINT coverage_pkey PRIMARY KEY (id);


--
-- Name: coverage coverage_policy_number_key; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.coverage
    ADD CONSTRAINT coverage_policy_number_key UNIQUE (policy_number);


--
-- Name: invoice invoice_id_patient_id_key; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.invoice
    ADD CONSTRAINT invoice_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: invoice invoice_invoice_number_key; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.invoice
    ADD CONSTRAINT invoice_invoice_number_key UNIQUE (invoice_number);


--
-- Name: invoice_line invoice_line_pkey; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.invoice_line
    ADD CONSTRAINT invoice_line_pkey PRIMARY KEY (invoice_id, line_no);


--
-- Name: invoice invoice_pkey; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.invoice
    ADD CONSTRAINT invoice_pkey PRIMARY KEY (id);


--
-- Name: payer payer_code_key; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.payer
    ADD CONSTRAINT payer_code_key UNIQUE (code);


--
-- Name: payer payer_pkey; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.payer
    ADD CONSTRAINT payer_pkey PRIMARY KEY (id);


--
-- Name: payment_allocation payment_allocation_payment_id_invoice_id_key; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.payment_allocation
    ADD CONSTRAINT payment_allocation_payment_id_invoice_id_key UNIQUE (payment_id, invoice_id);


--
-- Name: payment_allocation payment_allocation_pkey; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.payment_allocation
    ADD CONSTRAINT payment_allocation_pkey PRIMARY KEY (id);


--
-- Name: payment payment_external_reference_key; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.payment
    ADD CONSTRAINT payment_external_reference_key UNIQUE (external_reference);


--
-- Name: payment payment_id_patient_id_key; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.payment
    ADD CONSTRAINT payment_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (id);


--
-- Name: tariff tariff_pkey; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.tariff
    ADD CONSTRAINT tariff_pkey PRIMARY KEY (id);


--
-- Name: tariff tariff_service_id_payer_id_valid_during_excl; Type: CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.tariff
    ADD CONSTRAINT tariff_service_id_payer_id_valid_during_excl EXCLUDE USING gist (service_id WITH =, payer_id WITH =, valid_during WITH &&);


--
-- Name: allergy allergy_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.allergy
    ADD CONSTRAINT allergy_pkey PRIMARY KEY (id);


--
-- Name: care_plan_activity care_plan_activity_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.care_plan_activity
    ADD CONSTRAINT care_plan_activity_pkey PRIMARY KEY (id);


--
-- Name: care_plan care_plan_id_patient_id_key; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.care_plan
    ADD CONSTRAINT care_plan_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: care_plan care_plan_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.care_plan
    ADD CONSTRAINT care_plan_pkey PRIMARY KEY (id);


--
-- Name: clinical_note clinical_note_id_patient_id_key; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.clinical_note
    ADD CONSTRAINT clinical_note_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: clinical_note clinical_note_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.clinical_note
    ADD CONSTRAINT clinical_note_pkey PRIMARY KEY (id);


--
-- Name: condition condition_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.condition
    ADD CONSTRAINT condition_pkey PRIMARY KEY (id);


--
-- Name: death_record death_record_certificate_number_key; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.death_record
    ADD CONSTRAINT death_record_certificate_number_key UNIQUE (certificate_number);


--
-- Name: death_record death_record_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.death_record
    ADD CONSTRAINT death_record_pkey PRIMARY KEY (patient_id);


--
-- Name: document document_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.document
    ADD CONSTRAINT document_pkey PRIMARY KEY (id);


--
-- Name: document document_storage_uri_key; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.document
    ADD CONSTRAINT document_storage_uri_key UNIQUE (storage_uri);


--
-- Name: encounter encounter_id_patient_id_key; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.encounter
    ADD CONSTRAINT encounter_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: encounter_participant encounter_participant_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.encounter_participant
    ADD CONSTRAINT encounter_participant_pkey PRIMARY KEY (encounter_id, staff_id, role_code);


--
-- Name: encounter encounter_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.encounter
    ADD CONSTRAINT encounter_pkey PRIMARY KEY (id);


--
-- Name: encounter encounter_public_id_key; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.encounter
    ADD CONSTRAINT encounter_public_id_key UNIQUE (public_id);


--
-- Name: immunization immunization_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.immunization
    ADD CONSTRAINT immunization_pkey PRIMARY KEY (id);


--
-- Name: note_version note_version_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.note_version
    ADD CONSTRAINT note_version_pkey PRIMARY KEY (note_id, version);


--
-- Name: observation observation_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation
    ADD CONSTRAINT observation_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2024_01 observation_2024_01_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2024_01
    ADD CONSTRAINT observation_2024_01_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2024_02 observation_2024_02_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2024_02
    ADD CONSTRAINT observation_2024_02_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2024_03 observation_2024_03_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2024_03
    ADD CONSTRAINT observation_2024_03_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2024_04 observation_2024_04_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2024_04
    ADD CONSTRAINT observation_2024_04_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2024_05 observation_2024_05_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2024_05
    ADD CONSTRAINT observation_2024_05_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2024_06 observation_2024_06_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2024_06
    ADD CONSTRAINT observation_2024_06_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2024_07 observation_2024_07_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2024_07
    ADD CONSTRAINT observation_2024_07_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2024_08 observation_2024_08_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2024_08
    ADD CONSTRAINT observation_2024_08_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2024_09 observation_2024_09_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2024_09
    ADD CONSTRAINT observation_2024_09_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2024_10 observation_2024_10_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2024_10
    ADD CONSTRAINT observation_2024_10_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2024_11 observation_2024_11_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2024_11
    ADD CONSTRAINT observation_2024_11_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2024_12 observation_2024_12_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2024_12
    ADD CONSTRAINT observation_2024_12_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2025_01 observation_2025_01_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2025_01
    ADD CONSTRAINT observation_2025_01_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2025_02 observation_2025_02_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2025_02
    ADD CONSTRAINT observation_2025_02_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2025_03 observation_2025_03_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2025_03
    ADD CONSTRAINT observation_2025_03_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2025_04 observation_2025_04_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2025_04
    ADD CONSTRAINT observation_2025_04_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2025_05 observation_2025_05_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2025_05
    ADD CONSTRAINT observation_2025_05_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2025_06 observation_2025_06_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2025_06
    ADD CONSTRAINT observation_2025_06_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2025_07 observation_2025_07_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2025_07
    ADD CONSTRAINT observation_2025_07_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2025_08 observation_2025_08_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2025_08
    ADD CONSTRAINT observation_2025_08_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2025_09 observation_2025_09_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2025_09
    ADD CONSTRAINT observation_2025_09_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2025_10 observation_2025_10_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2025_10
    ADD CONSTRAINT observation_2025_10_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2025_11 observation_2025_11_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2025_11
    ADD CONSTRAINT observation_2025_11_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2025_12 observation_2025_12_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2025_12
    ADD CONSTRAINT observation_2025_12_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2026_01 observation_2026_01_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2026_01
    ADD CONSTRAINT observation_2026_01_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2026_02 observation_2026_02_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2026_02
    ADD CONSTRAINT observation_2026_02_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2026_03 observation_2026_03_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2026_03
    ADD CONSTRAINT observation_2026_03_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2026_04 observation_2026_04_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2026_04
    ADD CONSTRAINT observation_2026_04_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2026_05 observation_2026_05_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2026_05
    ADD CONSTRAINT observation_2026_05_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2026_06 observation_2026_06_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2026_06
    ADD CONSTRAINT observation_2026_06_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2026_07 observation_2026_07_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2026_07
    ADD CONSTRAINT observation_2026_07_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2026_08 observation_2026_08_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2026_08
    ADD CONSTRAINT observation_2026_08_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2026_09 observation_2026_09_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2026_09
    ADD CONSTRAINT observation_2026_09_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2026_10 observation_2026_10_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2026_10
    ADD CONSTRAINT observation_2026_10_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2026_11 observation_2026_11_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2026_11
    ADD CONSTRAINT observation_2026_11_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2026_12 observation_2026_12_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2026_12
    ADD CONSTRAINT observation_2026_12_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2027_01 observation_2027_01_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2027_01
    ADD CONSTRAINT observation_2027_01_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2027_02 observation_2027_02_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2027_02
    ADD CONSTRAINT observation_2027_02_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2027_03 observation_2027_03_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2027_03
    ADD CONSTRAINT observation_2027_03_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2027_04 observation_2027_04_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2027_04
    ADD CONSTRAINT observation_2027_04_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2027_05 observation_2027_05_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2027_05
    ADD CONSTRAINT observation_2027_05_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2027_06 observation_2027_06_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2027_06
    ADD CONSTRAINT observation_2027_06_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2027_07 observation_2027_07_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2027_07
    ADD CONSTRAINT observation_2027_07_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2027_08 observation_2027_08_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2027_08
    ADD CONSTRAINT observation_2027_08_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2027_09 observation_2027_09_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2027_09
    ADD CONSTRAINT observation_2027_09_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2027_10 observation_2027_10_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2027_10
    ADD CONSTRAINT observation_2027_10_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2027_11 observation_2027_11_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2027_11
    ADD CONSTRAINT observation_2027_11_pkey PRIMARY KEY (id, observed_at);


--
-- Name: observation_2027_12 observation_2027_12_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.observation_2027_12
    ADD CONSTRAINT observation_2027_12_pkey PRIMARY KEY (id, observed_at);


--
-- Name: procedure procedure_pkey; Type: CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.procedure
    ADD CONSTRAINT procedure_pkey PRIMARY KEY (id);


--
-- Name: access_grant access_grant_pkey; Type: CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.access_grant
    ADD CONSTRAINT access_grant_pkey PRIMARY KEY (id);


--
-- Name: access_grant access_grant_user_id_patient_id_purpose_valid_during_key; Type: CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.access_grant
    ADD CONSTRAINT access_grant_user_id_patient_id_purpose_valid_during_key UNIQUE (user_id, patient_id, purpose, valid_during);


--
-- Name: application_user application_user_database_principal_key; Type: CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.application_user
    ADD CONSTRAINT application_user_database_principal_key UNIQUE (database_principal);


--
-- Name: application_user application_user_pkey; Type: CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.application_user
    ADD CONSTRAINT application_user_pkey PRIMARY KEY (id);


--
-- Name: application_user application_user_staff_id_key; Type: CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.application_user
    ADD CONSTRAINT application_user_staff_id_key UNIQUE (staff_id);


--
-- Name: break_glass break_glass_pkey; Type: CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.break_glass
    ADD CONSTRAINT break_glass_pkey PRIMARY KEY (id);


--
-- Name: business_role business_role_pkey; Type: CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.business_role
    ADD CONSTRAINT business_role_pkey PRIMARY KEY (code);


--
-- Name: user_role user_role_pkey; Type: CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.user_role
    ADD CONSTRAINT user_role_pkey PRIMARY KEY (user_id, role_code);


--
-- Name: imaging_order imaging_order_id_patient_id_key; Type: CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.imaging_order
    ADD CONSTRAINT imaging_order_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: imaging_order imaging_order_pkey; Type: CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.imaging_order
    ADD CONSTRAINT imaging_order_pkey PRIMARY KEY (id);


--
-- Name: series series_pkey; Type: CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.series
    ADD CONSTRAINT series_pkey PRIMARY KEY (id);


--
-- Name: series series_series_instance_uid_key; Type: CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.series
    ADD CONSTRAINT series_series_instance_uid_key UNIQUE (series_instance_uid);


--
-- Name: series series_study_id_series_number_key; Type: CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.series
    ADD CONSTRAINT series_study_id_series_number_key UNIQUE (study_id, series_number);


--
-- Name: study study_accession_number_key; Type: CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.study
    ADD CONSTRAINT study_accession_number_key UNIQUE (accession_number);


--
-- Name: study study_pkey; Type: CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.study
    ADD CONSTRAINT study_pkey PRIMARY KEY (id);


--
-- Name: study study_study_instance_uid_key; Type: CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.study
    ADD CONSTRAINT study_study_instance_uid_key UNIQUE (study_instance_uid);


--
-- Name: export_job export_job_pkey; Type: CONSTRAINT; Schema: integration; Owner: hospital_owner
--

ALTER TABLE ONLY integration.export_job
    ADD CONSTRAINT export_job_pkey PRIMARY KEY (id);


--
-- Name: external_identifier external_identifier_pkey; Type: CONSTRAINT; Schema: integration; Owner: hospital_owner
--

ALTER TABLE ONLY integration.external_identifier
    ADD CONSTRAINT external_identifier_pkey PRIMARY KEY (id);


--
-- Name: external_identifier external_identifier_resource_type_internal_public_id_system_key; Type: CONSTRAINT; Schema: integration; Owner: hospital_owner
--

ALTER TABLE ONLY integration.external_identifier
    ADD CONSTRAINT external_identifier_resource_type_internal_public_id_system_key UNIQUE (resource_type, internal_public_id, system_uri);


--
-- Name: external_identifier external_identifier_resource_type_system_uri_external_id_key; Type: CONSTRAINT; Schema: integration; Owner: hospital_owner
--

ALTER TABLE ONLY integration.external_identifier
    ADD CONSTRAINT external_identifier_resource_type_system_uri_external_id_key UNIQUE (resource_type, system_uri, external_id);


--
-- Name: inbox inbox_pkey; Type: CONSTRAINT; Schema: integration; Owner: hospital_owner
--

ALTER TABLE ONLY integration.inbox
    ADD CONSTRAINT inbox_pkey PRIMARY KEY (source, message_id);


--
-- Name: outbox outbox_event_id_key; Type: CONSTRAINT; Schema: integration; Owner: hospital_owner
--

ALTER TABLE ONLY integration.outbox
    ADD CONSTRAINT outbox_event_id_key UNIQUE (event_id);


--
-- Name: outbox outbox_pkey; Type: CONSTRAINT; Schema: integration; Owner: hospital_owner
--

ALTER TABLE ONLY integration.outbox
    ADD CONSTRAINT outbox_pkey PRIMARY KEY (id);


--
-- Name: item item_medication_id_key; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.item
    ADD CONSTRAINT item_medication_id_key UNIQUE (medication_id);


--
-- Name: item item_pkey; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.item
    ADD CONSTRAINT item_pkey PRIMARY KEY (id);


--
-- Name: item item_sku_key; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.item
    ADD CONSTRAINT item_sku_key UNIQUE (sku);


--
-- Name: location location_code_key; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.location
    ADD CONSTRAINT location_code_key UNIQUE (code);


--
-- Name: location location_pkey; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.location
    ADD CONSTRAINT location_pkey PRIMARY KEY (id);


--
-- Name: lot lot_id_item_id_key; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.lot
    ADD CONSTRAINT lot_id_item_id_key UNIQUE (id, item_id);


--
-- Name: lot lot_item_id_lot_number_key; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.lot
    ADD CONSTRAINT lot_item_id_lot_number_key UNIQUE (item_id, lot_number);


--
-- Name: lot lot_pkey; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.lot
    ADD CONSTRAINT lot_pkey PRIMARY KEY (id);


--
-- Name: purchase_order_line purchase_order_line_pkey; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.purchase_order_line
    ADD CONSTRAINT purchase_order_line_pkey PRIMARY KEY (order_id, line_no);


--
-- Name: purchase_order purchase_order_order_number_key; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.purchase_order
    ADD CONSTRAINT purchase_order_order_number_key UNIQUE (order_number);


--
-- Name: purchase_order purchase_order_pkey; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.purchase_order
    ADD CONSTRAINT purchase_order_pkey PRIMARY KEY (id);


--
-- Name: stock_balance stock_balance_pkey; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.stock_balance
    ADD CONSTRAINT stock_balance_pkey PRIMARY KEY (location_id, lot_id);


--
-- Name: stock_movement stock_movement_dispense_id_key; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.stock_movement
    ADD CONSTRAINT stock_movement_dispense_id_key UNIQUE (dispense_id);


--
-- Name: stock_movement stock_movement_idempotency_key_key; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.stock_movement
    ADD CONSTRAINT stock_movement_idempotency_key_key UNIQUE (idempotency_key);


--
-- Name: stock_movement stock_movement_pkey; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.stock_movement
    ADD CONSTRAINT stock_movement_pkey PRIMARY KEY (id);


--
-- Name: supplier supplier_code_key; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.supplier
    ADD CONSTRAINT supplier_code_key UNIQUE (code);


--
-- Name: supplier supplier_pkey; Type: CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.supplier
    ADD CONSTRAINT supplier_pkey PRIMARY KEY (id);


--
-- Name: diagnostic_report diagnostic_report_id_patient_id_key; Type: CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.diagnostic_report
    ADD CONSTRAINT diagnostic_report_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: diagnostic_report diagnostic_report_pkey; Type: CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.diagnostic_report
    ADD CONSTRAINT diagnostic_report_pkey PRIMARY KEY (id);


--
-- Name: diagnostic_report diagnostic_report_request_id_version_key; Type: CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.diagnostic_report
    ADD CONSTRAINT diagnostic_report_request_id_version_key UNIQUE (request_id, version);


--
-- Name: report_result report_result_pkey; Type: CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.report_result
    ADD CONSTRAINT report_result_pkey PRIMARY KEY (report_id, result_id);


--
-- Name: request_specimen request_specimen_pkey; Type: CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.request_specimen
    ADD CONSTRAINT request_specimen_pkey PRIMARY KEY (request_id, specimen_id);


--
-- Name: result result_id_patient_id_key; Type: CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.result
    ADD CONSTRAINT result_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: result result_pkey; Type: CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.result
    ADD CONSTRAINT result_pkey PRIMARY KEY (id);


--
-- Name: service_request service_request_id_patient_id_key; Type: CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.service_request
    ADD CONSTRAINT service_request_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: service_request service_request_pkey; Type: CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.service_request
    ADD CONSTRAINT service_request_pkey PRIMARY KEY (id);


--
-- Name: specimen specimen_accession_number_key; Type: CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.specimen
    ADD CONSTRAINT specimen_accession_number_key UNIQUE (accession_number);


--
-- Name: specimen specimen_id_patient_id_key; Type: CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.specimen
    ADD CONSTRAINT specimen_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: specimen specimen_pkey; Type: CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.specimen
    ADD CONSTRAINT specimen_pkey PRIMARY KEY (id);


--
-- Name: address address_pkey; Type: CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.address
    ADD CONSTRAINT address_pkey PRIMARY KEY (id);


--
-- Name: consent consent_id_patient_id_key; Type: CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.consent
    ADD CONSTRAINT consent_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: consent consent_pkey; Type: CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.consent
    ADD CONSTRAINT consent_pkey PRIMARY KEY (id);


--
-- Name: contact contact_patient_id_system_rank_key; Type: CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.contact
    ADD CONSTRAINT contact_patient_id_system_rank_key UNIQUE (patient_id, system, rank);


--
-- Name: contact contact_pkey; Type: CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.contact
    ADD CONSTRAINT contact_pkey PRIMARY KEY (id);


--
-- Name: identifier identifier_pkey; Type: CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.identifier
    ADD CONSTRAINT identifier_pkey PRIMARY KEY (id);


--
-- Name: identifier identifier_system_uri_value_key; Type: CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.identifier
    ADD CONSTRAINT identifier_system_uri_value_key UNIQUE (system_uri, value);


--
-- Name: merge_history merge_history_pkey; Type: CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.merge_history
    ADD CONSTRAINT merge_history_pkey PRIMARY KEY (id);


--
-- Name: merge_history merge_history_source_patient_id_key; Type: CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.merge_history
    ADD CONSTRAINT merge_history_source_patient_id_key UNIQUE (source_patient_id);


--
-- Name: patient patient_mrn_key; Type: CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.patient
    ADD CONSTRAINT patient_mrn_key UNIQUE (mrn);


--
-- Name: patient patient_pkey; Type: CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.patient
    ADD CONSTRAINT patient_pkey PRIMARY KEY (id);


--
-- Name: patient patient_public_id_key; Type: CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.patient
    ADD CONSTRAINT patient_public_id_key UNIQUE (public_id);


--
-- Name: related_person related_person_pkey; Type: CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.related_person
    ADD CONSTRAINT related_person_pkey PRIMARY KEY (id);


--
-- Name: schema_migration schema_migration_pkey; Type: CONSTRAINT; Schema: ops; Owner: hospital_owner
--

ALTER TABLE ONLY ops.schema_migration
    ADD CONSTRAINT schema_migration_pkey PRIMARY KEY (version);


--
-- Name: bed bed_code_key; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.bed
    ADD CONSTRAINT bed_code_key UNIQUE (code);


--
-- Name: bed bed_pkey; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.bed
    ADD CONSTRAINT bed_pkey PRIMARY KEY (id);


--
-- Name: credential credential_identifier_key; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.credential
    ADD CONSTRAINT credential_identifier_key UNIQUE (identifier);


--
-- Name: credential credential_pkey; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.credential
    ADD CONSTRAINT credential_pkey PRIMARY KEY (id);


--
-- Name: department department_code_key; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.department
    ADD CONSTRAINT department_code_key UNIQUE (code);


--
-- Name: department department_id_site_id_key; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.department
    ADD CONSTRAINT department_id_site_id_key UNIQUE (id, site_id);


--
-- Name: department department_pkey; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.department
    ADD CONSTRAINT department_pkey PRIMARY KEY (id);


--
-- Name: device device_asset_tag_key; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.device
    ADD CONSTRAINT device_asset_tag_key UNIQUE (asset_tag);


--
-- Name: device device_pkey; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.device
    ADD CONSTRAINT device_pkey PRIMARY KEY (id);


--
-- Name: device device_serial_number_key; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.device
    ADD CONSTRAINT device_serial_number_key UNIQUE (serial_number);


--
-- Name: organization organization_code_key; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.organization
    ADD CONSTRAINT organization_code_key UNIQUE (code);


--
-- Name: organization organization_pkey; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);


--
-- Name: organization organization_public_id_key; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.organization
    ADD CONSTRAINT organization_public_id_key UNIQUE (public_id);


--
-- Name: room room_department_id_code_key; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.room
    ADD CONSTRAINT room_department_id_code_key UNIQUE (department_id, code);


--
-- Name: room room_id_department_id_key; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.room
    ADD CONSTRAINT room_id_department_id_key UNIQUE (id, department_id);


--
-- Name: room room_pkey; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.room
    ADD CONSTRAINT room_pkey PRIMARY KEY (id);


--
-- Name: site site_code_key; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.site
    ADD CONSTRAINT site_code_key UNIQUE (code);


--
-- Name: site site_id_organization_id_key; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.site
    ADD CONSTRAINT site_id_organization_id_key UNIQUE (id, organization_id);


--
-- Name: site site_pkey; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.site
    ADD CONSTRAINT site_pkey PRIMARY KEY (id);


--
-- Name: staff_department staff_department_pkey; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.staff_department
    ADD CONSTRAINT staff_department_pkey PRIMARY KEY (staff_id, department_id, valid_during);


--
-- Name: staff_department staff_department_staff_id_department_id_valid_during_excl; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.staff_department
    ADD CONSTRAINT staff_department_staff_id_department_id_valid_during_excl EXCLUDE USING gist (staff_id WITH =, department_id WITH =, valid_during WITH &&);


--
-- Name: staff staff_pkey; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (id);


--
-- Name: staff staff_staff_number_key; Type: CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.staff
    ADD CONSTRAINT staff_staff_number_key UNIQUE (staff_number);


--
-- Name: administration administration_pkey; Type: CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.administration
    ADD CONSTRAINT administration_pkey PRIMARY KEY (id);


--
-- Name: dispense dispense_id_patient_id_key; Type: CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.dispense
    ADD CONSTRAINT dispense_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: dispense dispense_idempotency_key_key; Type: CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.dispense
    ADD CONSTRAINT dispense_idempotency_key_key UNIQUE (idempotency_key);


--
-- Name: dispense dispense_pkey; Type: CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.dispense
    ADD CONSTRAINT dispense_pkey PRIMARY KEY (id);


--
-- Name: medication_order medication_order_id_patient_id_key; Type: CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.medication_order
    ADD CONSTRAINT medication_order_id_patient_id_key UNIQUE (id, patient_id);


--
-- Name: medication_order medication_order_id_patient_id_medication_id_key; Type: CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.medication_order
    ADD CONSTRAINT medication_order_id_patient_id_medication_id_key UNIQUE (id, patient_id, medication_id);


--
-- Name: medication_order medication_order_pkey; Type: CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.medication_order
    ADD CONSTRAINT medication_order_pkey PRIMARY KEY (id);


--
-- Name: medication_reconciliation medication_reconciliation_pkey; Type: CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.medication_reconciliation
    ADD CONSTRAINT medication_reconciliation_pkey PRIMARY KEY (id);


--
-- Name: incident incident_pkey; Type: CONSTRAINT; Schema: quality; Owner: hospital_owner
--

ALTER TABLE ONLY quality.incident
    ADD CONSTRAINT incident_pkey PRIMARY KEY (id);


--
-- Name: infection_case infection_case_pkey; Type: CONSTRAINT; Schema: quality; Owner: hospital_owner
--

ALTER TABLE ONLY quality.infection_case
    ADD CONSTRAINT infection_case_pkey PRIMARY KEY (id);


--
-- Name: patient_feedback patient_feedback_pkey; Type: CONSTRAINT; Schema: quality; Owner: hospital_owner
--

ALTER TABLE ONLY quality.patient_feedback
    ADD CONSTRAINT patient_feedback_pkey PRIMARY KEY (id);


--
-- Name: code_system code_system_pkey; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.code_system
    ADD CONSTRAINT code_system_pkey PRIMARY KEY (id);


--
-- Name: code_system code_system_uri_key; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.code_system
    ADD CONSTRAINT code_system_uri_key UNIQUE (uri);


--
-- Name: concept concept_pkey; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.concept
    ADD CONSTRAINT concept_pkey PRIMARY KEY (id);


--
-- Name: concept concept_system_id_code_key; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.concept
    ADD CONSTRAINT concept_system_id_code_key UNIQUE (system_id, code);


--
-- Name: currency currency_pkey; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.currency
    ADD CONSTRAINT currency_pkey PRIMARY KEY (code);


--
-- Name: encounter_type encounter_type_pkey; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.encounter_type
    ADD CONSTRAINT encounter_type_pkey PRIMARY KEY (code);


--
-- Name: medication medication_code_key; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.medication
    ADD CONSTRAINT medication_code_key UNIQUE (code);


--
-- Name: medication medication_pkey; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.medication
    ADD CONSTRAINT medication_pkey PRIMARY KEY (id);


--
-- Name: panel_item panel_item_panel_id_position_key; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.panel_item
    ADD CONSTRAINT panel_item_panel_id_position_key UNIQUE (panel_id, "position");


--
-- Name: panel_item panel_item_pkey; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.panel_item
    ADD CONSTRAINT panel_item_pkey PRIMARY KEY (panel_id, test_id);


--
-- Name: route route_pkey; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.route
    ADD CONSTRAINT route_pkey PRIMARY KEY (code);


--
-- Name: service service_code_key; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.service
    ADD CONSTRAINT service_code_key UNIQUE (code);


--
-- Name: service service_pkey; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.service
    ADD CONSTRAINT service_pkey PRIMARY KEY (id);


--
-- Name: test test_code_key; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.test
    ADD CONSTRAINT test_code_key UNIQUE (code);


--
-- Name: test_panel test_panel_code_key; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.test_panel
    ADD CONSTRAINT test_panel_code_key UNIQUE (code);


--
-- Name: test_panel test_panel_pkey; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.test_panel
    ADD CONSTRAINT test_panel_pkey PRIMARY KEY (id);


--
-- Name: test test_pkey; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.test
    ADD CONSTRAINT test_pkey PRIMARY KEY (id);


--
-- Name: unit unit_pkey; Type: CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.unit
    ADD CONSTRAINT unit_pkey PRIMARY KEY (code);


--
-- Name: appointment_participant appointment_participant_pkey; Type: CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.appointment_participant
    ADD CONSTRAINT appointment_participant_pkey PRIMARY KEY (appointment_id, staff_id);


--
-- Name: appointment appointment_pkey; Type: CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.appointment
    ADD CONSTRAINT appointment_pkey PRIMARY KEY (id);


--
-- Name: appointment appointment_slot_id_key; Type: CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.appointment
    ADD CONSTRAINT appointment_slot_id_key UNIQUE (slot_id);


--
-- Name: appointment patient_appointment_no_overlap; Type: CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.appointment
    ADD CONSTRAINT patient_appointment_no_overlap EXCLUDE USING gist (patient_id WITH =, appointment_period WITH &&) WHERE ((status = ANY (ARRAY['booked'::text, 'arrived'::text, 'fulfilled'::text])));


--
-- Name: schedule schedule_id_staff_id_department_id_key; Type: CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.schedule
    ADD CONSTRAINT schedule_id_staff_id_department_id_key UNIQUE (id, staff_id, department_id);


--
-- Name: schedule schedule_pkey; Type: CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.schedule
    ADD CONSTRAINT schedule_pkey PRIMARY KEY (id);


--
-- Name: slot slot_pkey; Type: CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.slot
    ADD CONSTRAINT slot_pkey PRIMARY KEY (id);


--
-- Name: slot slot_room_id_slot_period_excl; Type: CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.slot
    ADD CONSTRAINT slot_room_id_slot_period_excl EXCLUDE USING gist (room_id WITH =, slot_period WITH &&);


--
-- Name: slot slot_staff_id_slot_period_excl; Type: CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.slot
    ADD CONSTRAINT slot_staff_id_slot_period_excl EXCLUDE USING gist (staff_id WITH =, slot_period WITH &&);


--
-- Name: fk_admission_0f1bdb7e; Type: INDEX; Schema: adt; Owner: hospital_owner
--

CREATE INDEX fk_admission_0f1bdb7e ON adt.admission USING btree (encounter_id, patient_id);


--
-- Name: fk_bed_stay_c29a441d; Type: INDEX; Schema: adt; Owner: hospital_owner
--

CREATE INDEX fk_bed_stay_c29a441d ON adt.bed_stay USING btree (admission_id, patient_id);


--
-- Name: fk_discharge_cf804a39; Type: INDEX; Schema: adt; Owner: hospital_owner
--

CREATE INDEX fk_discharge_cf804a39 ON adt.discharge USING btree (admission_id, patient_id);


--
-- Name: fk_discharge_ef5ea73e; Type: INDEX; Schema: adt; Owner: hospital_owner
--

CREATE INDEX fk_discharge_ef5ea73e ON adt.discharge USING btree (summary_note_id, patient_id);


--
-- Name: fk_discharge_f17ab3dc; Type: INDEX; Schema: adt; Owner: hospital_owner
--

CREATE INDEX fk_discharge_f17ab3dc ON adt.discharge USING btree (approved_by);


--
-- Name: daily_activity_key; Type: INDEX; Schema: analytics; Owner: hospital_owner
--

CREATE UNIQUE INDEX daily_activity_key ON analytics.daily_activity USING btree (activity_date, department_id, type_code);


--
-- Name: monthly_revenue_key; Type: INDEX; Schema: analytics; Owner: hospital_owner
--

CREATE UNIQUE INDEX monthly_revenue_key ON analytics.monthly_revenue USING btree (reporting_month, payer_id, currency_code);


--
-- Name: access_patient_time; Type: INDEX; Schema: audit; Owner: hospital_owner
--

CREATE INDEX access_patient_time ON audit.access_event USING btree (patient_id, occurred_at DESC);


--
-- Name: audit_actor_time; Type: INDEX; Schema: audit; Owner: hospital_owner
--

CREATE INDEX audit_actor_time ON audit.event USING btree (actor, occurred_at DESC);


--
-- Name: audit_entity_time; Type: INDEX; Schema: audit; Owner: hospital_owner
--

CREATE INDEX audit_entity_time ON audit.event USING btree (table_schema, table_name, occurred_at DESC);


--
-- Name: fk_access_event_139a4ea5; Type: INDEX; Schema: audit; Owner: hospital_owner
--

CREATE INDEX fk_access_event_139a4ea5 ON audit.access_event USING btree (patient_id);


--
-- Name: fk_claim_579f985c; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_claim_579f985c ON billing.claim USING btree (payer_id);


--
-- Name: fk_claim_d8ef9751; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_claim_d8ef9751 ON billing.claim USING btree (invoice_id, patient_id);


--
-- Name: fk_coverage_002e1bc1; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_coverage_002e1bc1 ON billing.coverage USING btree (payer_id);


--
-- Name: fk_coverage_511cb900; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_coverage_511cb900 ON billing.coverage USING btree (patient_id);


--
-- Name: fk_invoice_247f4620; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_invoice_247f4620 ON billing.invoice USING btree (encounter_id, patient_id);


--
-- Name: fk_invoice_8bf796cf; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_invoice_8bf796cf ON billing.invoice USING btree (patient_id);


--
-- Name: fk_invoice_8cc527d8; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_invoice_8cc527d8 ON billing.invoice USING btree (currency_code);


--
-- Name: fk_invoice_951fbf05; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_invoice_951fbf05 ON billing.invoice USING btree (coverage_id, patient_id);


--
-- Name: fk_invoice_e34766d4; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_invoice_e34766d4 ON billing.invoice USING btree (payer_id);


--
-- Name: fk_invoice_line_dfc1753f; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_invoice_line_dfc1753f ON billing.invoice_line USING btree (service_id);


--
-- Name: fk_payment_17fcad48; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_payment_17fcad48 ON billing.payment USING btree (currency_code);


--
-- Name: fk_payment_5e19938a; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_payment_5e19938a ON billing.payment USING btree (patient_id);


--
-- Name: fk_payment_7cadb626; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_payment_7cadb626 ON billing.payment USING btree (payer_id);


--
-- Name: fk_payment_allocation_9e1cdb1d; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_payment_allocation_9e1cdb1d ON billing.payment_allocation USING btree (payment_id, patient_id);


--
-- Name: fk_payment_allocation_c663b697; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_payment_allocation_c663b697 ON billing.payment_allocation USING btree (invoice_id, patient_id);


--
-- Name: fk_tariff_7cf88014; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_tariff_7cf88014 ON billing.tariff USING btree (currency_code);


--
-- Name: fk_tariff_b31b6787; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX fk_tariff_b31b6787 ON billing.tariff USING btree (payer_id);


--
-- Name: invoice_patient_issued; Type: INDEX; Schema: billing; Owner: hospital_owner
--

CREATE INDEX invoice_patient_issued ON billing.invoice USING btree (patient_id, issued_at DESC);


--
-- Name: encounter_active; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX encounter_active ON ehr.encounter USING btree (department_id, started_at) WHERE (status = 'in-progress'::text);


--
-- Name: encounter_department_period; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX encounter_department_period ON ehr.encounter USING btree (department_id, started_at DESC);


--
-- Name: encounter_patient_timeline; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX encounter_patient_timeline ON ehr.encounter USING btree (patient_id, started_at DESC) INCLUDE (type_code, department_id, status);


--
-- Name: fk_allergy_90503cbb; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_allergy_90503cbb ON ehr.allergy USING btree (recorded_by);


--
-- Name: fk_allergy_ae0c7ade; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_allergy_ae0c7ade ON ehr.allergy USING btree (patient_id);


--
-- Name: fk_allergy_f0413973; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_allergy_f0413973 ON ehr.allergy USING btree (substance_concept_id);


--
-- Name: fk_care_plan_03846d79; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_care_plan_03846d79 ON ehr.care_plan USING btree (patient_id);


--
-- Name: fk_care_plan_a8940f28; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_care_plan_a8940f28 ON ehr.care_plan USING btree (encounter_id, patient_id);


--
-- Name: fk_care_plan_activity_3bc2ebd9; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_care_plan_activity_3bc2ebd9 ON ehr.care_plan_activity USING btree (care_plan_id);


--
-- Name: fk_care_plan_activity_467236f9; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_care_plan_activity_467236f9 ON ehr.care_plan_activity USING btree (assigned_staff_id);


--
-- Name: fk_care_plan_activity_c3b992d0; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_care_plan_activity_c3b992d0 ON ehr.care_plan_activity USING btree (service_id);


--
-- Name: fk_care_plan_d527ee5b; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_care_plan_d527ee5b ON ehr.care_plan USING btree (author_id);


--
-- Name: fk_clinical_note_34a7b706; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_clinical_note_34a7b706 ON ehr.clinical_note USING btree (id, current_version);


--
-- Name: fk_clinical_note_496d0137; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_clinical_note_496d0137 ON ehr.clinical_note USING btree (encounter_id, patient_id);


--
-- Name: fk_clinical_note_5b40cab7; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_clinical_note_5b40cab7 ON ehr.clinical_note USING btree (author_id);


--
-- Name: fk_clinical_note_9b1a189b; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_clinical_note_9b1a189b ON ehr.clinical_note USING btree (patient_id);


--
-- Name: fk_condition_908a7f6a; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_condition_908a7f6a ON ehr.condition USING btree (encounter_id, patient_id);


--
-- Name: fk_condition_a16e5364; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_condition_a16e5364 ON ehr.condition USING btree (concept_id);


--
-- Name: fk_condition_a622e7ba; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_condition_a622e7ba ON ehr.condition USING btree (patient_id);


--
-- Name: fk_condition_c171954e; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_condition_c171954e ON ehr.condition USING btree (recorded_by);


--
-- Name: fk_death_record_08682f8c; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_death_record_08682f8c ON ehr.death_record USING btree (certified_by);


--
-- Name: fk_death_record_393461a0; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_death_record_393461a0 ON ehr.death_record USING btree (encounter_id, patient_id);


--
-- Name: fk_death_record_6db2f1c7; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_death_record_6db2f1c7 ON ehr.death_record USING btree (cause_concept_id);


--
-- Name: fk_document_475e0e96; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_document_475e0e96 ON ehr.document USING btree (author_id);


--
-- Name: fk_document_7c834dc5; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_document_7c834dc5 ON ehr.document USING btree (patient_id);


--
-- Name: fk_document_7f427d12; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_document_7f427d12 ON ehr.document USING btree (encounter_id, patient_id);


--
-- Name: fk_encounter_7f676129; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_encounter_7f676129 ON ehr.encounter USING btree (department_id);


--
-- Name: fk_encounter_8e8fa888; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_encounter_8e8fa888 ON ehr.encounter USING btree (patient_id);


--
-- Name: fk_encounter_a03244f7; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_encounter_a03244f7 ON ehr.encounter USING btree (attending_staff_id);


--
-- Name: fk_encounter_c4ff113d; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_encounter_c4ff113d ON ehr.encounter USING btree (type_code);


--
-- Name: fk_encounter_participant_30d21b07; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_encounter_participant_30d21b07 ON ehr.encounter_participant USING btree (staff_id);


--
-- Name: fk_immunization_a1782625; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_immunization_a1782625 ON ehr.immunization USING btree (performer_id);


--
-- Name: fk_immunization_b5f6b25e; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_immunization_b5f6b25e ON ehr.immunization USING btree (vaccine_concept_id);


--
-- Name: fk_immunization_d4b2dd09; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_immunization_d4b2dd09 ON ehr.immunization USING btree (patient_id);


--
-- Name: fk_immunization_e71d30d3; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_immunization_e71d30d3 ON ehr.immunization USING btree (encounter_id, patient_id);


--
-- Name: fk_note_version_12fdb2c2; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_note_version_12fdb2c2 ON ehr.note_version USING btree (signed_by);


--
-- Name: fk_note_version_a7b39a88; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_note_version_a7b39a88 ON ehr.note_version USING btree (author_id);


--
-- Name: fk_note_version_d1ba259c; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_note_version_d1ba259c ON ehr.note_version USING btree (note_id, supersedes_version);


--
-- Name: fk_observation_3f716295; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_observation_3f716295 ON ONLY ehr.observation USING btree (encounter_id, patient_id);


--
-- Name: fk_observation_4ac682dd; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_observation_4ac682dd ON ONLY ehr.observation USING btree (unit_code);


--
-- Name: fk_observation_98b3f216; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_observation_98b3f216 ON ONLY ehr.observation USING btree (recorded_by);


--
-- Name: fk_observation_9b4a70b7; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_observation_9b4a70b7 ON ONLY ehr.observation USING btree (value_concept_id);


--
-- Name: fk_observation_d10cfc96; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_observation_d10cfc96 ON ONLY ehr.observation USING btree (test_id);


--
-- Name: fk_observation_d4cda705; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_observation_d4cda705 ON ONLY ehr.observation USING btree (patient_id);


--
-- Name: fk_procedure_19c04dd8; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_procedure_19c04dd8 ON ehr.procedure USING btree (performer_id);


--
-- Name: fk_procedure_8c828013; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_procedure_8c828013 ON ehr.procedure USING btree (encounter_id, patient_id);


--
-- Name: fk_procedure_8ea1d096; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_procedure_8ea1d096 ON ehr.procedure USING btree (patient_id);


--
-- Name: fk_procedure_d69d7296; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX fk_procedure_d69d7296 ON ehr.procedure USING btree (service_id);


--
-- Name: observation_2024_01_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_01_encounter_id_patient_id_idx ON ehr.observation_2024_01 USING btree (encounter_id, patient_id);


--
-- Name: observation_time_brin; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_time_brin ON ONLY ehr.observation USING brin (observed_at);


--
-- Name: observation_2024_01_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_01_observed_at_idx ON ehr.observation_2024_01 USING brin (observed_at);


--
-- Name: observation_2024_01_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_01_patient_id_idx ON ehr.observation_2024_01 USING btree (patient_id);


--
-- Name: observation_timeline; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_timeline ON ONLY ehr.observation USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2024_01_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_01_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2024_01 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2024_01_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_01_recorded_by_idx ON ehr.observation_2024_01 USING btree (recorded_by);


--
-- Name: observation_2024_01_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_01_test_id_idx ON ehr.observation_2024_01 USING btree (test_id);


--
-- Name: observation_2024_01_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_01_unit_code_idx ON ehr.observation_2024_01 USING btree (unit_code);


--
-- Name: observation_2024_01_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_01_value_concept_id_idx ON ehr.observation_2024_01 USING btree (value_concept_id);


--
-- Name: observation_2024_02_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_02_encounter_id_patient_id_idx ON ehr.observation_2024_02 USING btree (encounter_id, patient_id);


--
-- Name: observation_2024_02_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_02_observed_at_idx ON ehr.observation_2024_02 USING brin (observed_at);


--
-- Name: observation_2024_02_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_02_patient_id_idx ON ehr.observation_2024_02 USING btree (patient_id);


--
-- Name: observation_2024_02_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_02_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2024_02 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2024_02_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_02_recorded_by_idx ON ehr.observation_2024_02 USING btree (recorded_by);


--
-- Name: observation_2024_02_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_02_test_id_idx ON ehr.observation_2024_02 USING btree (test_id);


--
-- Name: observation_2024_02_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_02_unit_code_idx ON ehr.observation_2024_02 USING btree (unit_code);


--
-- Name: observation_2024_02_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_02_value_concept_id_idx ON ehr.observation_2024_02 USING btree (value_concept_id);


--
-- Name: observation_2024_03_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_03_encounter_id_patient_id_idx ON ehr.observation_2024_03 USING btree (encounter_id, patient_id);


--
-- Name: observation_2024_03_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_03_observed_at_idx ON ehr.observation_2024_03 USING brin (observed_at);


--
-- Name: observation_2024_03_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_03_patient_id_idx ON ehr.observation_2024_03 USING btree (patient_id);


--
-- Name: observation_2024_03_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_03_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2024_03 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2024_03_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_03_recorded_by_idx ON ehr.observation_2024_03 USING btree (recorded_by);


--
-- Name: observation_2024_03_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_03_test_id_idx ON ehr.observation_2024_03 USING btree (test_id);


--
-- Name: observation_2024_03_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_03_unit_code_idx ON ehr.observation_2024_03 USING btree (unit_code);


--
-- Name: observation_2024_03_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_03_value_concept_id_idx ON ehr.observation_2024_03 USING btree (value_concept_id);


--
-- Name: observation_2024_04_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_04_encounter_id_patient_id_idx ON ehr.observation_2024_04 USING btree (encounter_id, patient_id);


--
-- Name: observation_2024_04_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_04_observed_at_idx ON ehr.observation_2024_04 USING brin (observed_at);


--
-- Name: observation_2024_04_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_04_patient_id_idx ON ehr.observation_2024_04 USING btree (patient_id);


--
-- Name: observation_2024_04_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_04_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2024_04 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2024_04_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_04_recorded_by_idx ON ehr.observation_2024_04 USING btree (recorded_by);


--
-- Name: observation_2024_04_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_04_test_id_idx ON ehr.observation_2024_04 USING btree (test_id);


--
-- Name: observation_2024_04_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_04_unit_code_idx ON ehr.observation_2024_04 USING btree (unit_code);


--
-- Name: observation_2024_04_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_04_value_concept_id_idx ON ehr.observation_2024_04 USING btree (value_concept_id);


--
-- Name: observation_2024_05_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_05_encounter_id_patient_id_idx ON ehr.observation_2024_05 USING btree (encounter_id, patient_id);


--
-- Name: observation_2024_05_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_05_observed_at_idx ON ehr.observation_2024_05 USING brin (observed_at);


--
-- Name: observation_2024_05_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_05_patient_id_idx ON ehr.observation_2024_05 USING btree (patient_id);


--
-- Name: observation_2024_05_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_05_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2024_05 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2024_05_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_05_recorded_by_idx ON ehr.observation_2024_05 USING btree (recorded_by);


--
-- Name: observation_2024_05_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_05_test_id_idx ON ehr.observation_2024_05 USING btree (test_id);


--
-- Name: observation_2024_05_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_05_unit_code_idx ON ehr.observation_2024_05 USING btree (unit_code);


--
-- Name: observation_2024_05_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_05_value_concept_id_idx ON ehr.observation_2024_05 USING btree (value_concept_id);


--
-- Name: observation_2024_06_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_06_encounter_id_patient_id_idx ON ehr.observation_2024_06 USING btree (encounter_id, patient_id);


--
-- Name: observation_2024_06_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_06_observed_at_idx ON ehr.observation_2024_06 USING brin (observed_at);


--
-- Name: observation_2024_06_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_06_patient_id_idx ON ehr.observation_2024_06 USING btree (patient_id);


--
-- Name: observation_2024_06_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_06_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2024_06 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2024_06_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_06_recorded_by_idx ON ehr.observation_2024_06 USING btree (recorded_by);


--
-- Name: observation_2024_06_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_06_test_id_idx ON ehr.observation_2024_06 USING btree (test_id);


--
-- Name: observation_2024_06_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_06_unit_code_idx ON ehr.observation_2024_06 USING btree (unit_code);


--
-- Name: observation_2024_06_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_06_value_concept_id_idx ON ehr.observation_2024_06 USING btree (value_concept_id);


--
-- Name: observation_2024_07_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_07_encounter_id_patient_id_idx ON ehr.observation_2024_07 USING btree (encounter_id, patient_id);


--
-- Name: observation_2024_07_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_07_observed_at_idx ON ehr.observation_2024_07 USING brin (observed_at);


--
-- Name: observation_2024_07_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_07_patient_id_idx ON ehr.observation_2024_07 USING btree (patient_id);


--
-- Name: observation_2024_07_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_07_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2024_07 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2024_07_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_07_recorded_by_idx ON ehr.observation_2024_07 USING btree (recorded_by);


--
-- Name: observation_2024_07_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_07_test_id_idx ON ehr.observation_2024_07 USING btree (test_id);


--
-- Name: observation_2024_07_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_07_unit_code_idx ON ehr.observation_2024_07 USING btree (unit_code);


--
-- Name: observation_2024_07_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_07_value_concept_id_idx ON ehr.observation_2024_07 USING btree (value_concept_id);


--
-- Name: observation_2024_08_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_08_encounter_id_patient_id_idx ON ehr.observation_2024_08 USING btree (encounter_id, patient_id);


--
-- Name: observation_2024_08_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_08_observed_at_idx ON ehr.observation_2024_08 USING brin (observed_at);


--
-- Name: observation_2024_08_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_08_patient_id_idx ON ehr.observation_2024_08 USING btree (patient_id);


--
-- Name: observation_2024_08_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_08_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2024_08 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2024_08_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_08_recorded_by_idx ON ehr.observation_2024_08 USING btree (recorded_by);


--
-- Name: observation_2024_08_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_08_test_id_idx ON ehr.observation_2024_08 USING btree (test_id);


--
-- Name: observation_2024_08_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_08_unit_code_idx ON ehr.observation_2024_08 USING btree (unit_code);


--
-- Name: observation_2024_08_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_08_value_concept_id_idx ON ehr.observation_2024_08 USING btree (value_concept_id);


--
-- Name: observation_2024_09_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_09_encounter_id_patient_id_idx ON ehr.observation_2024_09 USING btree (encounter_id, patient_id);


--
-- Name: observation_2024_09_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_09_observed_at_idx ON ehr.observation_2024_09 USING brin (observed_at);


--
-- Name: observation_2024_09_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_09_patient_id_idx ON ehr.observation_2024_09 USING btree (patient_id);


--
-- Name: observation_2024_09_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_09_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2024_09 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2024_09_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_09_recorded_by_idx ON ehr.observation_2024_09 USING btree (recorded_by);


--
-- Name: observation_2024_09_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_09_test_id_idx ON ehr.observation_2024_09 USING btree (test_id);


--
-- Name: observation_2024_09_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_09_unit_code_idx ON ehr.observation_2024_09 USING btree (unit_code);


--
-- Name: observation_2024_09_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_09_value_concept_id_idx ON ehr.observation_2024_09 USING btree (value_concept_id);


--
-- Name: observation_2024_10_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_10_encounter_id_patient_id_idx ON ehr.observation_2024_10 USING btree (encounter_id, patient_id);


--
-- Name: observation_2024_10_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_10_observed_at_idx ON ehr.observation_2024_10 USING brin (observed_at);


--
-- Name: observation_2024_10_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_10_patient_id_idx ON ehr.observation_2024_10 USING btree (patient_id);


--
-- Name: observation_2024_10_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_10_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2024_10 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2024_10_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_10_recorded_by_idx ON ehr.observation_2024_10 USING btree (recorded_by);


--
-- Name: observation_2024_10_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_10_test_id_idx ON ehr.observation_2024_10 USING btree (test_id);


--
-- Name: observation_2024_10_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_10_unit_code_idx ON ehr.observation_2024_10 USING btree (unit_code);


--
-- Name: observation_2024_10_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_10_value_concept_id_idx ON ehr.observation_2024_10 USING btree (value_concept_id);


--
-- Name: observation_2024_11_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_11_encounter_id_patient_id_idx ON ehr.observation_2024_11 USING btree (encounter_id, patient_id);


--
-- Name: observation_2024_11_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_11_observed_at_idx ON ehr.observation_2024_11 USING brin (observed_at);


--
-- Name: observation_2024_11_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_11_patient_id_idx ON ehr.observation_2024_11 USING btree (patient_id);


--
-- Name: observation_2024_11_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_11_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2024_11 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2024_11_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_11_recorded_by_idx ON ehr.observation_2024_11 USING btree (recorded_by);


--
-- Name: observation_2024_11_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_11_test_id_idx ON ehr.observation_2024_11 USING btree (test_id);


--
-- Name: observation_2024_11_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_11_unit_code_idx ON ehr.observation_2024_11 USING btree (unit_code);


--
-- Name: observation_2024_11_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_11_value_concept_id_idx ON ehr.observation_2024_11 USING btree (value_concept_id);


--
-- Name: observation_2024_12_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_12_encounter_id_patient_id_idx ON ehr.observation_2024_12 USING btree (encounter_id, patient_id);


--
-- Name: observation_2024_12_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_12_observed_at_idx ON ehr.observation_2024_12 USING brin (observed_at);


--
-- Name: observation_2024_12_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_12_patient_id_idx ON ehr.observation_2024_12 USING btree (patient_id);


--
-- Name: observation_2024_12_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_12_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2024_12 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2024_12_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_12_recorded_by_idx ON ehr.observation_2024_12 USING btree (recorded_by);


--
-- Name: observation_2024_12_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_12_test_id_idx ON ehr.observation_2024_12 USING btree (test_id);


--
-- Name: observation_2024_12_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_12_unit_code_idx ON ehr.observation_2024_12 USING btree (unit_code);


--
-- Name: observation_2024_12_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2024_12_value_concept_id_idx ON ehr.observation_2024_12 USING btree (value_concept_id);


--
-- Name: observation_2025_01_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_01_encounter_id_patient_id_idx ON ehr.observation_2025_01 USING btree (encounter_id, patient_id);


--
-- Name: observation_2025_01_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_01_observed_at_idx ON ehr.observation_2025_01 USING brin (observed_at);


--
-- Name: observation_2025_01_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_01_patient_id_idx ON ehr.observation_2025_01 USING btree (patient_id);


--
-- Name: observation_2025_01_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_01_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2025_01 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2025_01_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_01_recorded_by_idx ON ehr.observation_2025_01 USING btree (recorded_by);


--
-- Name: observation_2025_01_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_01_test_id_idx ON ehr.observation_2025_01 USING btree (test_id);


--
-- Name: observation_2025_01_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_01_unit_code_idx ON ehr.observation_2025_01 USING btree (unit_code);


--
-- Name: observation_2025_01_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_01_value_concept_id_idx ON ehr.observation_2025_01 USING btree (value_concept_id);


--
-- Name: observation_2025_02_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_02_encounter_id_patient_id_idx ON ehr.observation_2025_02 USING btree (encounter_id, patient_id);


--
-- Name: observation_2025_02_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_02_observed_at_idx ON ehr.observation_2025_02 USING brin (observed_at);


--
-- Name: observation_2025_02_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_02_patient_id_idx ON ehr.observation_2025_02 USING btree (patient_id);


--
-- Name: observation_2025_02_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_02_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2025_02 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2025_02_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_02_recorded_by_idx ON ehr.observation_2025_02 USING btree (recorded_by);


--
-- Name: observation_2025_02_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_02_test_id_idx ON ehr.observation_2025_02 USING btree (test_id);


--
-- Name: observation_2025_02_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_02_unit_code_idx ON ehr.observation_2025_02 USING btree (unit_code);


--
-- Name: observation_2025_02_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_02_value_concept_id_idx ON ehr.observation_2025_02 USING btree (value_concept_id);


--
-- Name: observation_2025_03_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_03_encounter_id_patient_id_idx ON ehr.observation_2025_03 USING btree (encounter_id, patient_id);


--
-- Name: observation_2025_03_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_03_observed_at_idx ON ehr.observation_2025_03 USING brin (observed_at);


--
-- Name: observation_2025_03_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_03_patient_id_idx ON ehr.observation_2025_03 USING btree (patient_id);


--
-- Name: observation_2025_03_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_03_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2025_03 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2025_03_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_03_recorded_by_idx ON ehr.observation_2025_03 USING btree (recorded_by);


--
-- Name: observation_2025_03_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_03_test_id_idx ON ehr.observation_2025_03 USING btree (test_id);


--
-- Name: observation_2025_03_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_03_unit_code_idx ON ehr.observation_2025_03 USING btree (unit_code);


--
-- Name: observation_2025_03_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_03_value_concept_id_idx ON ehr.observation_2025_03 USING btree (value_concept_id);


--
-- Name: observation_2025_04_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_04_encounter_id_patient_id_idx ON ehr.observation_2025_04 USING btree (encounter_id, patient_id);


--
-- Name: observation_2025_04_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_04_observed_at_idx ON ehr.observation_2025_04 USING brin (observed_at);


--
-- Name: observation_2025_04_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_04_patient_id_idx ON ehr.observation_2025_04 USING btree (patient_id);


--
-- Name: observation_2025_04_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_04_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2025_04 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2025_04_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_04_recorded_by_idx ON ehr.observation_2025_04 USING btree (recorded_by);


--
-- Name: observation_2025_04_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_04_test_id_idx ON ehr.observation_2025_04 USING btree (test_id);


--
-- Name: observation_2025_04_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_04_unit_code_idx ON ehr.observation_2025_04 USING btree (unit_code);


--
-- Name: observation_2025_04_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_04_value_concept_id_idx ON ehr.observation_2025_04 USING btree (value_concept_id);


--
-- Name: observation_2025_05_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_05_encounter_id_patient_id_idx ON ehr.observation_2025_05 USING btree (encounter_id, patient_id);


--
-- Name: observation_2025_05_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_05_observed_at_idx ON ehr.observation_2025_05 USING brin (observed_at);


--
-- Name: observation_2025_05_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_05_patient_id_idx ON ehr.observation_2025_05 USING btree (patient_id);


--
-- Name: observation_2025_05_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_05_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2025_05 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2025_05_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_05_recorded_by_idx ON ehr.observation_2025_05 USING btree (recorded_by);


--
-- Name: observation_2025_05_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_05_test_id_idx ON ehr.observation_2025_05 USING btree (test_id);


--
-- Name: observation_2025_05_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_05_unit_code_idx ON ehr.observation_2025_05 USING btree (unit_code);


--
-- Name: observation_2025_05_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_05_value_concept_id_idx ON ehr.observation_2025_05 USING btree (value_concept_id);


--
-- Name: observation_2025_06_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_06_encounter_id_patient_id_idx ON ehr.observation_2025_06 USING btree (encounter_id, patient_id);


--
-- Name: observation_2025_06_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_06_observed_at_idx ON ehr.observation_2025_06 USING brin (observed_at);


--
-- Name: observation_2025_06_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_06_patient_id_idx ON ehr.observation_2025_06 USING btree (patient_id);


--
-- Name: observation_2025_06_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_06_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2025_06 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2025_06_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_06_recorded_by_idx ON ehr.observation_2025_06 USING btree (recorded_by);


--
-- Name: observation_2025_06_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_06_test_id_idx ON ehr.observation_2025_06 USING btree (test_id);


--
-- Name: observation_2025_06_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_06_unit_code_idx ON ehr.observation_2025_06 USING btree (unit_code);


--
-- Name: observation_2025_06_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_06_value_concept_id_idx ON ehr.observation_2025_06 USING btree (value_concept_id);


--
-- Name: observation_2025_07_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_07_encounter_id_patient_id_idx ON ehr.observation_2025_07 USING btree (encounter_id, patient_id);


--
-- Name: observation_2025_07_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_07_observed_at_idx ON ehr.observation_2025_07 USING brin (observed_at);


--
-- Name: observation_2025_07_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_07_patient_id_idx ON ehr.observation_2025_07 USING btree (patient_id);


--
-- Name: observation_2025_07_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_07_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2025_07 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2025_07_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_07_recorded_by_idx ON ehr.observation_2025_07 USING btree (recorded_by);


--
-- Name: observation_2025_07_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_07_test_id_idx ON ehr.observation_2025_07 USING btree (test_id);


--
-- Name: observation_2025_07_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_07_unit_code_idx ON ehr.observation_2025_07 USING btree (unit_code);


--
-- Name: observation_2025_07_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_07_value_concept_id_idx ON ehr.observation_2025_07 USING btree (value_concept_id);


--
-- Name: observation_2025_08_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_08_encounter_id_patient_id_idx ON ehr.observation_2025_08 USING btree (encounter_id, patient_id);


--
-- Name: observation_2025_08_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_08_observed_at_idx ON ehr.observation_2025_08 USING brin (observed_at);


--
-- Name: observation_2025_08_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_08_patient_id_idx ON ehr.observation_2025_08 USING btree (patient_id);


--
-- Name: observation_2025_08_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_08_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2025_08 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2025_08_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_08_recorded_by_idx ON ehr.observation_2025_08 USING btree (recorded_by);


--
-- Name: observation_2025_08_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_08_test_id_idx ON ehr.observation_2025_08 USING btree (test_id);


--
-- Name: observation_2025_08_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_08_unit_code_idx ON ehr.observation_2025_08 USING btree (unit_code);


--
-- Name: observation_2025_08_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_08_value_concept_id_idx ON ehr.observation_2025_08 USING btree (value_concept_id);


--
-- Name: observation_2025_09_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_09_encounter_id_patient_id_idx ON ehr.observation_2025_09 USING btree (encounter_id, patient_id);


--
-- Name: observation_2025_09_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_09_observed_at_idx ON ehr.observation_2025_09 USING brin (observed_at);


--
-- Name: observation_2025_09_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_09_patient_id_idx ON ehr.observation_2025_09 USING btree (patient_id);


--
-- Name: observation_2025_09_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_09_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2025_09 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2025_09_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_09_recorded_by_idx ON ehr.observation_2025_09 USING btree (recorded_by);


--
-- Name: observation_2025_09_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_09_test_id_idx ON ehr.observation_2025_09 USING btree (test_id);


--
-- Name: observation_2025_09_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_09_unit_code_idx ON ehr.observation_2025_09 USING btree (unit_code);


--
-- Name: observation_2025_09_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_09_value_concept_id_idx ON ehr.observation_2025_09 USING btree (value_concept_id);


--
-- Name: observation_2025_10_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_10_encounter_id_patient_id_idx ON ehr.observation_2025_10 USING btree (encounter_id, patient_id);


--
-- Name: observation_2025_10_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_10_observed_at_idx ON ehr.observation_2025_10 USING brin (observed_at);


--
-- Name: observation_2025_10_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_10_patient_id_idx ON ehr.observation_2025_10 USING btree (patient_id);


--
-- Name: observation_2025_10_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_10_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2025_10 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2025_10_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_10_recorded_by_idx ON ehr.observation_2025_10 USING btree (recorded_by);


--
-- Name: observation_2025_10_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_10_test_id_idx ON ehr.observation_2025_10 USING btree (test_id);


--
-- Name: observation_2025_10_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_10_unit_code_idx ON ehr.observation_2025_10 USING btree (unit_code);


--
-- Name: observation_2025_10_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_10_value_concept_id_idx ON ehr.observation_2025_10 USING btree (value_concept_id);


--
-- Name: observation_2025_11_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_11_encounter_id_patient_id_idx ON ehr.observation_2025_11 USING btree (encounter_id, patient_id);


--
-- Name: observation_2025_11_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_11_observed_at_idx ON ehr.observation_2025_11 USING brin (observed_at);


--
-- Name: observation_2025_11_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_11_patient_id_idx ON ehr.observation_2025_11 USING btree (patient_id);


--
-- Name: observation_2025_11_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_11_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2025_11 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2025_11_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_11_recorded_by_idx ON ehr.observation_2025_11 USING btree (recorded_by);


--
-- Name: observation_2025_11_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_11_test_id_idx ON ehr.observation_2025_11 USING btree (test_id);


--
-- Name: observation_2025_11_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_11_unit_code_idx ON ehr.observation_2025_11 USING btree (unit_code);


--
-- Name: observation_2025_11_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_11_value_concept_id_idx ON ehr.observation_2025_11 USING btree (value_concept_id);


--
-- Name: observation_2025_12_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_12_encounter_id_patient_id_idx ON ehr.observation_2025_12 USING btree (encounter_id, patient_id);


--
-- Name: observation_2025_12_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_12_observed_at_idx ON ehr.observation_2025_12 USING brin (observed_at);


--
-- Name: observation_2025_12_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_12_patient_id_idx ON ehr.observation_2025_12 USING btree (patient_id);


--
-- Name: observation_2025_12_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_12_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2025_12 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2025_12_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_12_recorded_by_idx ON ehr.observation_2025_12 USING btree (recorded_by);


--
-- Name: observation_2025_12_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_12_test_id_idx ON ehr.observation_2025_12 USING btree (test_id);


--
-- Name: observation_2025_12_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_12_unit_code_idx ON ehr.observation_2025_12 USING btree (unit_code);


--
-- Name: observation_2025_12_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2025_12_value_concept_id_idx ON ehr.observation_2025_12 USING btree (value_concept_id);


--
-- Name: observation_2026_01_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_01_encounter_id_patient_id_idx ON ehr.observation_2026_01 USING btree (encounter_id, patient_id);


--
-- Name: observation_2026_01_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_01_observed_at_idx ON ehr.observation_2026_01 USING brin (observed_at);


--
-- Name: observation_2026_01_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_01_patient_id_idx ON ehr.observation_2026_01 USING btree (patient_id);


--
-- Name: observation_2026_01_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_01_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2026_01 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2026_01_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_01_recorded_by_idx ON ehr.observation_2026_01 USING btree (recorded_by);


--
-- Name: observation_2026_01_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_01_test_id_idx ON ehr.observation_2026_01 USING btree (test_id);


--
-- Name: observation_2026_01_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_01_unit_code_idx ON ehr.observation_2026_01 USING btree (unit_code);


--
-- Name: observation_2026_01_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_01_value_concept_id_idx ON ehr.observation_2026_01 USING btree (value_concept_id);


--
-- Name: observation_2026_02_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_02_encounter_id_patient_id_idx ON ehr.observation_2026_02 USING btree (encounter_id, patient_id);


--
-- Name: observation_2026_02_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_02_observed_at_idx ON ehr.observation_2026_02 USING brin (observed_at);


--
-- Name: observation_2026_02_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_02_patient_id_idx ON ehr.observation_2026_02 USING btree (patient_id);


--
-- Name: observation_2026_02_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_02_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2026_02 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2026_02_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_02_recorded_by_idx ON ehr.observation_2026_02 USING btree (recorded_by);


--
-- Name: observation_2026_02_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_02_test_id_idx ON ehr.observation_2026_02 USING btree (test_id);


--
-- Name: observation_2026_02_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_02_unit_code_idx ON ehr.observation_2026_02 USING btree (unit_code);


--
-- Name: observation_2026_02_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_02_value_concept_id_idx ON ehr.observation_2026_02 USING btree (value_concept_id);


--
-- Name: observation_2026_03_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_03_encounter_id_patient_id_idx ON ehr.observation_2026_03 USING btree (encounter_id, patient_id);


--
-- Name: observation_2026_03_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_03_observed_at_idx ON ehr.observation_2026_03 USING brin (observed_at);


--
-- Name: observation_2026_03_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_03_patient_id_idx ON ehr.observation_2026_03 USING btree (patient_id);


--
-- Name: observation_2026_03_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_03_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2026_03 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2026_03_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_03_recorded_by_idx ON ehr.observation_2026_03 USING btree (recorded_by);


--
-- Name: observation_2026_03_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_03_test_id_idx ON ehr.observation_2026_03 USING btree (test_id);


--
-- Name: observation_2026_03_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_03_unit_code_idx ON ehr.observation_2026_03 USING btree (unit_code);


--
-- Name: observation_2026_03_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_03_value_concept_id_idx ON ehr.observation_2026_03 USING btree (value_concept_id);


--
-- Name: observation_2026_04_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_04_encounter_id_patient_id_idx ON ehr.observation_2026_04 USING btree (encounter_id, patient_id);


--
-- Name: observation_2026_04_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_04_observed_at_idx ON ehr.observation_2026_04 USING brin (observed_at);


--
-- Name: observation_2026_04_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_04_patient_id_idx ON ehr.observation_2026_04 USING btree (patient_id);


--
-- Name: observation_2026_04_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_04_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2026_04 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2026_04_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_04_recorded_by_idx ON ehr.observation_2026_04 USING btree (recorded_by);


--
-- Name: observation_2026_04_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_04_test_id_idx ON ehr.observation_2026_04 USING btree (test_id);


--
-- Name: observation_2026_04_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_04_unit_code_idx ON ehr.observation_2026_04 USING btree (unit_code);


--
-- Name: observation_2026_04_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_04_value_concept_id_idx ON ehr.observation_2026_04 USING btree (value_concept_id);


--
-- Name: observation_2026_05_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_05_encounter_id_patient_id_idx ON ehr.observation_2026_05 USING btree (encounter_id, patient_id);


--
-- Name: observation_2026_05_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_05_observed_at_idx ON ehr.observation_2026_05 USING brin (observed_at);


--
-- Name: observation_2026_05_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_05_patient_id_idx ON ehr.observation_2026_05 USING btree (patient_id);


--
-- Name: observation_2026_05_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_05_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2026_05 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2026_05_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_05_recorded_by_idx ON ehr.observation_2026_05 USING btree (recorded_by);


--
-- Name: observation_2026_05_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_05_test_id_idx ON ehr.observation_2026_05 USING btree (test_id);


--
-- Name: observation_2026_05_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_05_unit_code_idx ON ehr.observation_2026_05 USING btree (unit_code);


--
-- Name: observation_2026_05_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_05_value_concept_id_idx ON ehr.observation_2026_05 USING btree (value_concept_id);


--
-- Name: observation_2026_06_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_06_encounter_id_patient_id_idx ON ehr.observation_2026_06 USING btree (encounter_id, patient_id);


--
-- Name: observation_2026_06_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_06_observed_at_idx ON ehr.observation_2026_06 USING brin (observed_at);


--
-- Name: observation_2026_06_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_06_patient_id_idx ON ehr.observation_2026_06 USING btree (patient_id);


--
-- Name: observation_2026_06_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_06_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2026_06 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2026_06_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_06_recorded_by_idx ON ehr.observation_2026_06 USING btree (recorded_by);


--
-- Name: observation_2026_06_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_06_test_id_idx ON ehr.observation_2026_06 USING btree (test_id);


--
-- Name: observation_2026_06_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_06_unit_code_idx ON ehr.observation_2026_06 USING btree (unit_code);


--
-- Name: observation_2026_06_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_06_value_concept_id_idx ON ehr.observation_2026_06 USING btree (value_concept_id);


--
-- Name: observation_2026_07_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_07_encounter_id_patient_id_idx ON ehr.observation_2026_07 USING btree (encounter_id, patient_id);


--
-- Name: observation_2026_07_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_07_observed_at_idx ON ehr.observation_2026_07 USING brin (observed_at);


--
-- Name: observation_2026_07_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_07_patient_id_idx ON ehr.observation_2026_07 USING btree (patient_id);


--
-- Name: observation_2026_07_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_07_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2026_07 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2026_07_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_07_recorded_by_idx ON ehr.observation_2026_07 USING btree (recorded_by);


--
-- Name: observation_2026_07_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_07_test_id_idx ON ehr.observation_2026_07 USING btree (test_id);


--
-- Name: observation_2026_07_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_07_unit_code_idx ON ehr.observation_2026_07 USING btree (unit_code);


--
-- Name: observation_2026_07_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_07_value_concept_id_idx ON ehr.observation_2026_07 USING btree (value_concept_id);


--
-- Name: observation_2026_08_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_08_encounter_id_patient_id_idx ON ehr.observation_2026_08 USING btree (encounter_id, patient_id);


--
-- Name: observation_2026_08_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_08_observed_at_idx ON ehr.observation_2026_08 USING brin (observed_at);


--
-- Name: observation_2026_08_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_08_patient_id_idx ON ehr.observation_2026_08 USING btree (patient_id);


--
-- Name: observation_2026_08_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_08_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2026_08 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2026_08_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_08_recorded_by_idx ON ehr.observation_2026_08 USING btree (recorded_by);


--
-- Name: observation_2026_08_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_08_test_id_idx ON ehr.observation_2026_08 USING btree (test_id);


--
-- Name: observation_2026_08_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_08_unit_code_idx ON ehr.observation_2026_08 USING btree (unit_code);


--
-- Name: observation_2026_08_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_08_value_concept_id_idx ON ehr.observation_2026_08 USING btree (value_concept_id);


--
-- Name: observation_2026_09_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_09_encounter_id_patient_id_idx ON ehr.observation_2026_09 USING btree (encounter_id, patient_id);


--
-- Name: observation_2026_09_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_09_observed_at_idx ON ehr.observation_2026_09 USING brin (observed_at);


--
-- Name: observation_2026_09_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_09_patient_id_idx ON ehr.observation_2026_09 USING btree (patient_id);


--
-- Name: observation_2026_09_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_09_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2026_09 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2026_09_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_09_recorded_by_idx ON ehr.observation_2026_09 USING btree (recorded_by);


--
-- Name: observation_2026_09_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_09_test_id_idx ON ehr.observation_2026_09 USING btree (test_id);


--
-- Name: observation_2026_09_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_09_unit_code_idx ON ehr.observation_2026_09 USING btree (unit_code);


--
-- Name: observation_2026_09_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_09_value_concept_id_idx ON ehr.observation_2026_09 USING btree (value_concept_id);


--
-- Name: observation_2026_10_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_10_encounter_id_patient_id_idx ON ehr.observation_2026_10 USING btree (encounter_id, patient_id);


--
-- Name: observation_2026_10_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_10_observed_at_idx ON ehr.observation_2026_10 USING brin (observed_at);


--
-- Name: observation_2026_10_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_10_patient_id_idx ON ehr.observation_2026_10 USING btree (patient_id);


--
-- Name: observation_2026_10_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_10_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2026_10 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2026_10_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_10_recorded_by_idx ON ehr.observation_2026_10 USING btree (recorded_by);


--
-- Name: observation_2026_10_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_10_test_id_idx ON ehr.observation_2026_10 USING btree (test_id);


--
-- Name: observation_2026_10_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_10_unit_code_idx ON ehr.observation_2026_10 USING btree (unit_code);


--
-- Name: observation_2026_10_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_10_value_concept_id_idx ON ehr.observation_2026_10 USING btree (value_concept_id);


--
-- Name: observation_2026_11_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_11_encounter_id_patient_id_idx ON ehr.observation_2026_11 USING btree (encounter_id, patient_id);


--
-- Name: observation_2026_11_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_11_observed_at_idx ON ehr.observation_2026_11 USING brin (observed_at);


--
-- Name: observation_2026_11_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_11_patient_id_idx ON ehr.observation_2026_11 USING btree (patient_id);


--
-- Name: observation_2026_11_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_11_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2026_11 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2026_11_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_11_recorded_by_idx ON ehr.observation_2026_11 USING btree (recorded_by);


--
-- Name: observation_2026_11_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_11_test_id_idx ON ehr.observation_2026_11 USING btree (test_id);


--
-- Name: observation_2026_11_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_11_unit_code_idx ON ehr.observation_2026_11 USING btree (unit_code);


--
-- Name: observation_2026_11_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_11_value_concept_id_idx ON ehr.observation_2026_11 USING btree (value_concept_id);


--
-- Name: observation_2026_12_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_12_encounter_id_patient_id_idx ON ehr.observation_2026_12 USING btree (encounter_id, patient_id);


--
-- Name: observation_2026_12_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_12_observed_at_idx ON ehr.observation_2026_12 USING brin (observed_at);


--
-- Name: observation_2026_12_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_12_patient_id_idx ON ehr.observation_2026_12 USING btree (patient_id);


--
-- Name: observation_2026_12_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_12_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2026_12 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2026_12_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_12_recorded_by_idx ON ehr.observation_2026_12 USING btree (recorded_by);


--
-- Name: observation_2026_12_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_12_test_id_idx ON ehr.observation_2026_12 USING btree (test_id);


--
-- Name: observation_2026_12_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_12_unit_code_idx ON ehr.observation_2026_12 USING btree (unit_code);


--
-- Name: observation_2026_12_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2026_12_value_concept_id_idx ON ehr.observation_2026_12 USING btree (value_concept_id);


--
-- Name: observation_2027_01_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_01_encounter_id_patient_id_idx ON ehr.observation_2027_01 USING btree (encounter_id, patient_id);


--
-- Name: observation_2027_01_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_01_observed_at_idx ON ehr.observation_2027_01 USING brin (observed_at);


--
-- Name: observation_2027_01_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_01_patient_id_idx ON ehr.observation_2027_01 USING btree (patient_id);


--
-- Name: observation_2027_01_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_01_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2027_01 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2027_01_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_01_recorded_by_idx ON ehr.observation_2027_01 USING btree (recorded_by);


--
-- Name: observation_2027_01_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_01_test_id_idx ON ehr.observation_2027_01 USING btree (test_id);


--
-- Name: observation_2027_01_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_01_unit_code_idx ON ehr.observation_2027_01 USING btree (unit_code);


--
-- Name: observation_2027_01_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_01_value_concept_id_idx ON ehr.observation_2027_01 USING btree (value_concept_id);


--
-- Name: observation_2027_02_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_02_encounter_id_patient_id_idx ON ehr.observation_2027_02 USING btree (encounter_id, patient_id);


--
-- Name: observation_2027_02_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_02_observed_at_idx ON ehr.observation_2027_02 USING brin (observed_at);


--
-- Name: observation_2027_02_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_02_patient_id_idx ON ehr.observation_2027_02 USING btree (patient_id);


--
-- Name: observation_2027_02_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_02_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2027_02 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2027_02_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_02_recorded_by_idx ON ehr.observation_2027_02 USING btree (recorded_by);


--
-- Name: observation_2027_02_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_02_test_id_idx ON ehr.observation_2027_02 USING btree (test_id);


--
-- Name: observation_2027_02_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_02_unit_code_idx ON ehr.observation_2027_02 USING btree (unit_code);


--
-- Name: observation_2027_02_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_02_value_concept_id_idx ON ehr.observation_2027_02 USING btree (value_concept_id);


--
-- Name: observation_2027_03_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_03_encounter_id_patient_id_idx ON ehr.observation_2027_03 USING btree (encounter_id, patient_id);


--
-- Name: observation_2027_03_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_03_observed_at_idx ON ehr.observation_2027_03 USING brin (observed_at);


--
-- Name: observation_2027_03_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_03_patient_id_idx ON ehr.observation_2027_03 USING btree (patient_id);


--
-- Name: observation_2027_03_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_03_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2027_03 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2027_03_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_03_recorded_by_idx ON ehr.observation_2027_03 USING btree (recorded_by);


--
-- Name: observation_2027_03_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_03_test_id_idx ON ehr.observation_2027_03 USING btree (test_id);


--
-- Name: observation_2027_03_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_03_unit_code_idx ON ehr.observation_2027_03 USING btree (unit_code);


--
-- Name: observation_2027_03_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_03_value_concept_id_idx ON ehr.observation_2027_03 USING btree (value_concept_id);


--
-- Name: observation_2027_04_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_04_encounter_id_patient_id_idx ON ehr.observation_2027_04 USING btree (encounter_id, patient_id);


--
-- Name: observation_2027_04_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_04_observed_at_idx ON ehr.observation_2027_04 USING brin (observed_at);


--
-- Name: observation_2027_04_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_04_patient_id_idx ON ehr.observation_2027_04 USING btree (patient_id);


--
-- Name: observation_2027_04_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_04_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2027_04 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2027_04_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_04_recorded_by_idx ON ehr.observation_2027_04 USING btree (recorded_by);


--
-- Name: observation_2027_04_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_04_test_id_idx ON ehr.observation_2027_04 USING btree (test_id);


--
-- Name: observation_2027_04_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_04_unit_code_idx ON ehr.observation_2027_04 USING btree (unit_code);


--
-- Name: observation_2027_04_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_04_value_concept_id_idx ON ehr.observation_2027_04 USING btree (value_concept_id);


--
-- Name: observation_2027_05_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_05_encounter_id_patient_id_idx ON ehr.observation_2027_05 USING btree (encounter_id, patient_id);


--
-- Name: observation_2027_05_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_05_observed_at_idx ON ehr.observation_2027_05 USING brin (observed_at);


--
-- Name: observation_2027_05_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_05_patient_id_idx ON ehr.observation_2027_05 USING btree (patient_id);


--
-- Name: observation_2027_05_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_05_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2027_05 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2027_05_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_05_recorded_by_idx ON ehr.observation_2027_05 USING btree (recorded_by);


--
-- Name: observation_2027_05_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_05_test_id_idx ON ehr.observation_2027_05 USING btree (test_id);


--
-- Name: observation_2027_05_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_05_unit_code_idx ON ehr.observation_2027_05 USING btree (unit_code);


--
-- Name: observation_2027_05_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_05_value_concept_id_idx ON ehr.observation_2027_05 USING btree (value_concept_id);


--
-- Name: observation_2027_06_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_06_encounter_id_patient_id_idx ON ehr.observation_2027_06 USING btree (encounter_id, patient_id);


--
-- Name: observation_2027_06_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_06_observed_at_idx ON ehr.observation_2027_06 USING brin (observed_at);


--
-- Name: observation_2027_06_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_06_patient_id_idx ON ehr.observation_2027_06 USING btree (patient_id);


--
-- Name: observation_2027_06_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_06_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2027_06 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2027_06_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_06_recorded_by_idx ON ehr.observation_2027_06 USING btree (recorded_by);


--
-- Name: observation_2027_06_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_06_test_id_idx ON ehr.observation_2027_06 USING btree (test_id);


--
-- Name: observation_2027_06_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_06_unit_code_idx ON ehr.observation_2027_06 USING btree (unit_code);


--
-- Name: observation_2027_06_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_06_value_concept_id_idx ON ehr.observation_2027_06 USING btree (value_concept_id);


--
-- Name: observation_2027_07_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_07_encounter_id_patient_id_idx ON ehr.observation_2027_07 USING btree (encounter_id, patient_id);


--
-- Name: observation_2027_07_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_07_observed_at_idx ON ehr.observation_2027_07 USING brin (observed_at);


--
-- Name: observation_2027_07_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_07_patient_id_idx ON ehr.observation_2027_07 USING btree (patient_id);


--
-- Name: observation_2027_07_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_07_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2027_07 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2027_07_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_07_recorded_by_idx ON ehr.observation_2027_07 USING btree (recorded_by);


--
-- Name: observation_2027_07_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_07_test_id_idx ON ehr.observation_2027_07 USING btree (test_id);


--
-- Name: observation_2027_07_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_07_unit_code_idx ON ehr.observation_2027_07 USING btree (unit_code);


--
-- Name: observation_2027_07_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_07_value_concept_id_idx ON ehr.observation_2027_07 USING btree (value_concept_id);


--
-- Name: observation_2027_08_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_08_encounter_id_patient_id_idx ON ehr.observation_2027_08 USING btree (encounter_id, patient_id);


--
-- Name: observation_2027_08_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_08_observed_at_idx ON ehr.observation_2027_08 USING brin (observed_at);


--
-- Name: observation_2027_08_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_08_patient_id_idx ON ehr.observation_2027_08 USING btree (patient_id);


--
-- Name: observation_2027_08_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_08_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2027_08 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2027_08_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_08_recorded_by_idx ON ehr.observation_2027_08 USING btree (recorded_by);


--
-- Name: observation_2027_08_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_08_test_id_idx ON ehr.observation_2027_08 USING btree (test_id);


--
-- Name: observation_2027_08_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_08_unit_code_idx ON ehr.observation_2027_08 USING btree (unit_code);


--
-- Name: observation_2027_08_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_08_value_concept_id_idx ON ehr.observation_2027_08 USING btree (value_concept_id);


--
-- Name: observation_2027_09_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_09_encounter_id_patient_id_idx ON ehr.observation_2027_09 USING btree (encounter_id, patient_id);


--
-- Name: observation_2027_09_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_09_observed_at_idx ON ehr.observation_2027_09 USING brin (observed_at);


--
-- Name: observation_2027_09_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_09_patient_id_idx ON ehr.observation_2027_09 USING btree (patient_id);


--
-- Name: observation_2027_09_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_09_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2027_09 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2027_09_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_09_recorded_by_idx ON ehr.observation_2027_09 USING btree (recorded_by);


--
-- Name: observation_2027_09_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_09_test_id_idx ON ehr.observation_2027_09 USING btree (test_id);


--
-- Name: observation_2027_09_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_09_unit_code_idx ON ehr.observation_2027_09 USING btree (unit_code);


--
-- Name: observation_2027_09_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_09_value_concept_id_idx ON ehr.observation_2027_09 USING btree (value_concept_id);


--
-- Name: observation_2027_10_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_10_encounter_id_patient_id_idx ON ehr.observation_2027_10 USING btree (encounter_id, patient_id);


--
-- Name: observation_2027_10_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_10_observed_at_idx ON ehr.observation_2027_10 USING brin (observed_at);


--
-- Name: observation_2027_10_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_10_patient_id_idx ON ehr.observation_2027_10 USING btree (patient_id);


--
-- Name: observation_2027_10_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_10_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2027_10 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2027_10_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_10_recorded_by_idx ON ehr.observation_2027_10 USING btree (recorded_by);


--
-- Name: observation_2027_10_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_10_test_id_idx ON ehr.observation_2027_10 USING btree (test_id);


--
-- Name: observation_2027_10_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_10_unit_code_idx ON ehr.observation_2027_10 USING btree (unit_code);


--
-- Name: observation_2027_10_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_10_value_concept_id_idx ON ehr.observation_2027_10 USING btree (value_concept_id);


--
-- Name: observation_2027_11_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_11_encounter_id_patient_id_idx ON ehr.observation_2027_11 USING btree (encounter_id, patient_id);


--
-- Name: observation_2027_11_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_11_observed_at_idx ON ehr.observation_2027_11 USING brin (observed_at);


--
-- Name: observation_2027_11_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_11_patient_id_idx ON ehr.observation_2027_11 USING btree (patient_id);


--
-- Name: observation_2027_11_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_11_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2027_11 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2027_11_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_11_recorded_by_idx ON ehr.observation_2027_11 USING btree (recorded_by);


--
-- Name: observation_2027_11_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_11_test_id_idx ON ehr.observation_2027_11 USING btree (test_id);


--
-- Name: observation_2027_11_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_11_unit_code_idx ON ehr.observation_2027_11 USING btree (unit_code);


--
-- Name: observation_2027_11_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_11_value_concept_id_idx ON ehr.observation_2027_11 USING btree (value_concept_id);


--
-- Name: observation_2027_12_encounter_id_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_12_encounter_id_patient_id_idx ON ehr.observation_2027_12 USING btree (encounter_id, patient_id);


--
-- Name: observation_2027_12_observed_at_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_12_observed_at_idx ON ehr.observation_2027_12 USING brin (observed_at);


--
-- Name: observation_2027_12_patient_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_12_patient_id_idx ON ehr.observation_2027_12 USING btree (patient_id);


--
-- Name: observation_2027_12_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_12_patient_id_observed_at_test_id_value_nu_idx ON ehr.observation_2027_12 USING btree (patient_id, observed_at DESC) INCLUDE (test_id, value_numeric, unit_code);


--
-- Name: observation_2027_12_recorded_by_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_12_recorded_by_idx ON ehr.observation_2027_12 USING btree (recorded_by);


--
-- Name: observation_2027_12_test_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_12_test_id_idx ON ehr.observation_2027_12 USING btree (test_id);


--
-- Name: observation_2027_12_unit_code_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_12_unit_code_idx ON ehr.observation_2027_12 USING btree (unit_code);


--
-- Name: observation_2027_12_value_concept_id_idx; Type: INDEX; Schema: ehr; Owner: hospital_owner
--

CREATE INDEX observation_2027_12_value_concept_id_idx ON ehr.observation_2027_12 USING btree (value_concept_id);


--
-- Name: access_grant_lookup; Type: INDEX; Schema: iam; Owner: hospital_owner
--

CREATE INDEX access_grant_lookup ON iam.access_grant USING btree (user_id, patient_id, purpose);


--
-- Name: fk_access_grant_9423fa29; Type: INDEX; Schema: iam; Owner: hospital_owner
--

CREATE INDEX fk_access_grant_9423fa29 ON iam.access_grant USING btree (granted_by);


--
-- Name: fk_access_grant_c4b02138; Type: INDEX; Schema: iam; Owner: hospital_owner
--

CREATE INDEX fk_access_grant_c4b02138 ON iam.access_grant USING btree (patient_id);


--
-- Name: fk_break_glass_8a3e9deb; Type: INDEX; Schema: iam; Owner: hospital_owner
--

CREATE INDEX fk_break_glass_8a3e9deb ON iam.break_glass USING btree (approved_by);


--
-- Name: fk_break_glass_a5a5f4e8; Type: INDEX; Schema: iam; Owner: hospital_owner
--

CREATE INDEX fk_break_glass_a5a5f4e8 ON iam.break_glass USING btree (patient_id);


--
-- Name: fk_break_glass_b7cf00b2; Type: INDEX; Schema: iam; Owner: hospital_owner
--

CREATE INDEX fk_break_glass_b7cf00b2 ON iam.break_glass USING btree (user_id);


--
-- Name: fk_user_role_78abacc2; Type: INDEX; Schema: iam; Owner: hospital_owner
--

CREATE INDEX fk_user_role_78abacc2 ON iam.user_role USING btree (role_code);


--
-- Name: fk_imaging_order_100e711e; Type: INDEX; Schema: imaging; Owner: hospital_owner
--

CREATE INDEX fk_imaging_order_100e711e ON imaging.imaging_order USING btree (encounter_id, patient_id);


--
-- Name: fk_imaging_order_c7e04220; Type: INDEX; Schema: imaging; Owner: hospital_owner
--

CREATE INDEX fk_imaging_order_c7e04220 ON imaging.imaging_order USING btree (requested_by);


--
-- Name: fk_imaging_order_cdcdaac7; Type: INDEX; Schema: imaging; Owner: hospital_owner
--

CREATE INDEX fk_imaging_order_cdcdaac7 ON imaging.imaging_order USING btree (patient_id);


--
-- Name: fk_imaging_order_e35357cc; Type: INDEX; Schema: imaging; Owner: hospital_owner
--

CREATE INDEX fk_imaging_order_e35357cc ON imaging.imaging_order USING btree (service_id);


--
-- Name: fk_study_025a1b2f; Type: INDEX; Schema: imaging; Owner: hospital_owner
--

CREATE INDEX fk_study_025a1b2f ON imaging.study USING btree (order_id, patient_id);


--
-- Name: fk_study_96719a9b; Type: INDEX; Schema: imaging; Owner: hospital_owner
--

CREATE INDEX fk_study_96719a9b ON imaging.study USING btree (device_id);


--
-- Name: fk_study_d2d0c5c1; Type: INDEX; Schema: imaging; Owner: hospital_owner
--

CREATE INDEX fk_study_d2d0c5c1 ON imaging.study USING btree (patient_id);


--
-- Name: fk_export_job_cca1f724; Type: INDEX; Schema: integration; Owner: hospital_owner
--

CREATE INDEX fk_export_job_cca1f724 ON integration.export_job USING btree (requested_by);


--
-- Name: outbox_unpublished; Type: INDEX; Schema: integration; Owner: hospital_owner
--

CREATE INDEX outbox_unpublished ON integration.outbox USING btree (next_attempt_at, id) WHERE (published_at IS NULL);


--
-- Name: fk_item_e460788c; Type: INDEX; Schema: inventory; Owner: hospital_owner
--

CREATE INDEX fk_item_e460788c ON inventory.item USING btree (unit_code);


--
-- Name: fk_location_85004a7f; Type: INDEX; Schema: inventory; Owner: hospital_owner
--

CREATE INDEX fk_location_85004a7f ON inventory.location USING btree (department_id);


--
-- Name: fk_lot_4e35a2e3; Type: INDEX; Schema: inventory; Owner: hospital_owner
--

CREATE INDEX fk_lot_4e35a2e3 ON inventory.lot USING btree (supplier_id);


--
-- Name: fk_purchase_order_35d65ada; Type: INDEX; Schema: inventory; Owner: hospital_owner
--

CREATE INDEX fk_purchase_order_35d65ada ON inventory.purchase_order USING btree (currency_code);


--
-- Name: fk_purchase_order_36ed27b3; Type: INDEX; Schema: inventory; Owner: hospital_owner
--

CREATE INDEX fk_purchase_order_36ed27b3 ON inventory.purchase_order USING btree (supplier_id);


--
-- Name: fk_purchase_order_line_b730795f; Type: INDEX; Schema: inventory; Owner: hospital_owner
--

CREATE INDEX fk_purchase_order_line_b730795f ON inventory.purchase_order_line USING btree (item_id);


--
-- Name: fk_stock_balance_853a9397; Type: INDEX; Schema: inventory; Owner: hospital_owner
--

CREATE INDEX fk_stock_balance_853a9397 ON inventory.stock_balance USING btree (lot_id);


--
-- Name: fk_stock_movement_037cf2f9; Type: INDEX; Schema: inventory; Owner: hospital_owner
--

CREATE INDEX fk_stock_movement_037cf2f9 ON inventory.stock_movement USING btree (lot_id);


--
-- Name: fk_stock_movement_a0bc7632; Type: INDEX; Schema: inventory; Owner: hospital_owner
--

CREATE INDEX fk_stock_movement_a0bc7632 ON inventory.stock_movement USING btree (recorded_by);


--
-- Name: fk_stock_movement_e0178275; Type: INDEX; Schema: inventory; Owner: hospital_owner
--

CREATE INDEX fk_stock_movement_e0178275 ON inventory.stock_movement USING btree (location_id);


--
-- Name: fk_diagnostic_report_00d8eb1c; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_diagnostic_report_00d8eb1c ON lab.diagnostic_report USING btree (verified_by);


--
-- Name: fk_diagnostic_report_9a21f52e; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_diagnostic_report_9a21f52e ON lab.diagnostic_report USING btree (patient_id);


--
-- Name: fk_diagnostic_report_d8401091; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_diagnostic_report_d8401091 ON lab.diagnostic_report USING btree (request_id, patient_id);


--
-- Name: fk_report_result_c1061a6f; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_report_result_c1061a6f ON lab.report_result USING btree (result_id, patient_id);


--
-- Name: fk_report_result_cc360a27; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_report_result_cc360a27 ON lab.report_result USING btree (report_id, patient_id);


--
-- Name: fk_request_specimen_3fa01727; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_request_specimen_3fa01727 ON lab.request_specimen USING btree (request_id, patient_id);


--
-- Name: fk_request_specimen_8796d990; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_request_specimen_8796d990 ON lab.request_specimen USING btree (specimen_id, patient_id);


--
-- Name: fk_result_0b787630; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_result_0b787630 ON lab.result USING btree (unit_code);


--
-- Name: fk_result_5284ff33; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_result_5284ff33 ON lab.result USING btree (test_id);


--
-- Name: fk_result_7f18a9b6; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_result_7f18a9b6 ON lab.result USING btree (analyzer_id);


--
-- Name: fk_result_c3bc7d18; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_result_c3bc7d18 ON lab.result USING btree (specimen_id, patient_id);


--
-- Name: fk_result_d5c60c08; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_result_d5c60c08 ON lab.result USING btree (patient_id);


--
-- Name: fk_service_request_23907e08; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_service_request_23907e08 ON lab.service_request USING btree (patient_id);


--
-- Name: fk_service_request_2b310cd8; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_service_request_2b310cd8 ON lab.service_request USING btree (ordered_by);


--
-- Name: fk_service_request_74cf6a39; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_service_request_74cf6a39 ON lab.service_request USING btree (panel_id);


--
-- Name: fk_service_request_7be96d0b; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_service_request_7be96d0b ON lab.service_request USING btree (encounter_id, patient_id);


--
-- Name: fk_service_request_e4018298; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_service_request_e4018298 ON lab.service_request USING btree (service_id);


--
-- Name: fk_specimen_a4eeeb0f; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_specimen_a4eeeb0f ON lab.specimen USING btree (collected_by);


--
-- Name: fk_specimen_d7d75638; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX fk_specimen_d7d75638 ON lab.specimen USING btree (patient_id);


--
-- Name: lab_result_specimen_test; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX lab_result_specimen_test ON lab.result USING btree (specimen_id, test_id);


--
-- Name: report_patient_issued; Type: INDEX; Schema: lab; Owner: hospital_owner
--

CREATE INDEX report_patient_issued ON lab.diagnostic_report USING btree (patient_id, issued_at DESC);


--
-- Name: address_location_gist; Type: INDEX; Schema: mpi; Owner: hospital_owner
--

CREATE INDEX address_location_gist ON mpi.address USING gist (location);


--
-- Name: fk_address_cde7a771; Type: INDEX; Schema: mpi; Owner: hospital_owner
--

CREATE INDEX fk_address_cde7a771 ON mpi.address USING btree (patient_id);


--
-- Name: fk_consent_2d7568d3; Type: INDEX; Schema: mpi; Owner: hospital_owner
--

CREATE INDEX fk_consent_2d7568d3 ON mpi.consent USING btree (patient_id);


--
-- Name: fk_consent_c1b18a07; Type: INDEX; Schema: mpi; Owner: hospital_owner
--

CREATE INDEX fk_consent_c1b18a07 ON mpi.consent USING btree (recorded_by);


--
-- Name: fk_identifier_676dd3e1; Type: INDEX; Schema: mpi; Owner: hospital_owner
--

CREATE INDEX fk_identifier_676dd3e1 ON mpi.identifier USING btree (patient_id);


--
-- Name: fk_merge_history_7a848f7c; Type: INDEX; Schema: mpi; Owner: hospital_owner
--

CREATE INDEX fk_merge_history_7a848f7c ON mpi.merge_history USING btree (merged_by);


--
-- Name: fk_merge_history_c81645e2; Type: INDEX; Schema: mpi; Owner: hospital_owner
--

CREATE INDEX fk_merge_history_c81645e2 ON mpi.merge_history USING btree (target_patient_id);


--
-- Name: fk_related_person_a3da4306; Type: INDEX; Schema: mpi; Owner: hospital_owner
--

CREATE INDEX fk_related_person_a3da4306 ON mpi.related_person USING btree (patient_id);


--
-- Name: patient_name_search; Type: INDEX; Schema: mpi; Owner: hospital_owner
--

CREATE INDEX patient_name_search ON mpi.patient USING gin (((((family_name)::text || ' '::text) || (given_name)::text)) ext.gin_trgm_ops);


--
-- Name: fk_bed_3eeb3221; Type: INDEX; Schema: org; Owner: hospital_owner
--

CREATE INDEX fk_bed_3eeb3221 ON org.bed USING btree (room_id);


--
-- Name: fk_credential_b77fee33; Type: INDEX; Schema: org; Owner: hospital_owner
--

CREATE INDEX fk_credential_b77fee33 ON org.credential USING btree (staff_id);


--
-- Name: fk_department_3f241114; Type: INDEX; Schema: org; Owner: hospital_owner
--

CREATE INDEX fk_department_3f241114 ON org.department USING btree (site_id);


--
-- Name: fk_device_f7b43ee0; Type: INDEX; Schema: org; Owner: hospital_owner
--

CREATE INDEX fk_device_f7b43ee0 ON org.device USING btree (department_id);


--
-- Name: fk_site_df78efc9; Type: INDEX; Schema: org; Owner: hospital_owner
--

CREATE INDEX fk_site_df78efc9 ON org.site USING btree (organization_id);


--
-- Name: fk_staff_50a4e999; Type: INDEX; Schema: org; Owner: hospital_owner
--

CREATE INDEX fk_staff_50a4e999 ON org.staff USING btree (specialty_concept_id);


--
-- Name: fk_staff_department_2bb2b9d6; Type: INDEX; Schema: org; Owner: hospital_owner
--

CREATE INDEX fk_staff_department_2bb2b9d6 ON org.staff_department USING btree (department_id);


--
-- Name: site_location_gist; Type: INDEX; Schema: org; Owner: hospital_owner
--

CREATE INDEX site_location_gist ON org.site USING gist (location);


--
-- Name: fk_administration_4f116ece; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_administration_4f116ece ON pharmacy.administration USING btree (order_id, patient_id);


--
-- Name: fk_administration_6d2cb73e; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_administration_6d2cb73e ON pharmacy.administration USING btree (dispense_id, patient_id);


--
-- Name: fk_administration_6deb3f90; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_administration_6deb3f90 ON pharmacy.administration USING btree (unit_code);


--
-- Name: fk_administration_d164c02b; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_administration_d164c02b ON pharmacy.administration USING btree (performed_by);


--
-- Name: fk_dispense_31890688; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_dispense_31890688 ON pharmacy.dispense USING btree (lot_id, item_id);


--
-- Name: fk_dispense_83e5fc2a; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_dispense_83e5fc2a ON pharmacy.dispense USING btree (order_id, patient_id, medication_id);


--
-- Name: fk_dispense_8856aa34; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_dispense_8856aa34 ON pharmacy.dispense USING btree (dispensed_by);


--
-- Name: fk_dispense_e2d3ff72; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_dispense_e2d3ff72 ON pharmacy.dispense USING btree (location_id);


--
-- Name: fk_medication_order_8076d248; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_medication_order_8076d248 ON pharmacy.medication_order USING btree (medication_id);


--
-- Name: fk_medication_order_b5fb8054; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_medication_order_b5fb8054 ON pharmacy.medication_order USING btree (ordered_by);


--
-- Name: fk_medication_order_b60dd91a; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_medication_order_b60dd91a ON pharmacy.medication_order USING btree (route_code);


--
-- Name: fk_medication_order_d4e759ba; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_medication_order_d4e759ba ON pharmacy.medication_order USING btree (encounter_id, patient_id);


--
-- Name: fk_medication_order_d73dfc14; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_medication_order_d73dfc14 ON pharmacy.medication_order USING btree (patient_id);


--
-- Name: fk_medication_reconciliation_14a31b61; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_medication_reconciliation_14a31b61 ON pharmacy.medication_reconciliation USING btree (reconciled_by);


--
-- Name: fk_medication_reconciliation_5bf765e6; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_medication_reconciliation_5bf765e6 ON pharmacy.medication_reconciliation USING btree (patient_id);


--
-- Name: fk_medication_reconciliation_bc76493d; Type: INDEX; Schema: pharmacy; Owner: hospital_owner
--

CREATE INDEX fk_medication_reconciliation_bc76493d ON pharmacy.medication_reconciliation USING btree (encounter_id, patient_id);


--
-- Name: fk_incident_1068ae99; Type: INDEX; Schema: quality; Owner: hospital_owner
--

CREATE INDEX fk_incident_1068ae99 ON quality.incident USING btree (reported_by);


--
-- Name: fk_incident_10e1ad0c; Type: INDEX; Schema: quality; Owner: hospital_owner
--

CREATE INDEX fk_incident_10e1ad0c ON quality.incident USING btree (patient_id);


--
-- Name: fk_incident_61c56413; Type: INDEX; Schema: quality; Owner: hospital_owner
--

CREATE INDEX fk_incident_61c56413 ON quality.incident USING btree (encounter_id, patient_id);


--
-- Name: fk_incident_eb846296; Type: INDEX; Schema: quality; Owner: hospital_owner
--

CREATE INDEX fk_incident_eb846296 ON quality.incident USING btree (department_id);


--
-- Name: fk_infection_case_599169df; Type: INDEX; Schema: quality; Owner: hospital_owner
--

CREATE INDEX fk_infection_case_599169df ON quality.infection_case USING btree (patient_id);


--
-- Name: fk_infection_case_5f0e91d9; Type: INDEX; Schema: quality; Owner: hospital_owner
--

CREATE INDEX fk_infection_case_5f0e91d9 ON quality.infection_case USING btree (organism_concept_id);


--
-- Name: fk_infection_case_aea7ef3c; Type: INDEX; Schema: quality; Owner: hospital_owner
--

CREATE INDEX fk_infection_case_aea7ef3c ON quality.infection_case USING btree (reported_by);


--
-- Name: fk_infection_case_cf5a977c; Type: INDEX; Schema: quality; Owner: hospital_owner
--

CREATE INDEX fk_infection_case_cf5a977c ON quality.infection_case USING btree (encounter_id, patient_id);


--
-- Name: fk_patient_feedback_4f6567cb; Type: INDEX; Schema: quality; Owner: hospital_owner
--

CREATE INDEX fk_patient_feedback_4f6567cb ON quality.patient_feedback USING btree (encounter_id, patient_id);


--
-- Name: fk_patient_feedback_8927fa9b; Type: INDEX; Schema: quality; Owner: hospital_owner
--

CREATE INDEX fk_patient_feedback_8927fa9b ON quality.patient_feedback USING btree (patient_id);


--
-- Name: fk_medication_2c212acc; Type: INDEX; Schema: ref; Owner: hospital_owner
--

CREATE INDEX fk_medication_2c212acc ON ref.medication USING btree (unit_code);


--
-- Name: fk_panel_item_24871a15; Type: INDEX; Schema: ref; Owner: hospital_owner
--

CREATE INDEX fk_panel_item_24871a15 ON ref.panel_item USING btree (test_id);


--
-- Name: fk_test_a1430c9d; Type: INDEX; Schema: ref; Owner: hospital_owner
--

CREATE INDEX fk_test_a1430c9d ON ref.test USING btree (unit_code);


--
-- Name: appointment_status_slot; Type: INDEX; Schema: scheduling; Owner: hospital_owner
--

CREATE INDEX appointment_status_slot ON scheduling.appointment USING btree (status, slot_id);


--
-- Name: fk_appointment_5faac194; Type: INDEX; Schema: scheduling; Owner: hospital_owner
--

CREATE INDEX fk_appointment_5faac194 ON scheduling.appointment USING btree (encounter_id, patient_id);


--
-- Name: fk_appointment_6023e09e; Type: INDEX; Schema: scheduling; Owner: hospital_owner
--

CREATE INDEX fk_appointment_6023e09e ON scheduling.appointment USING btree (service_id);


--
-- Name: fk_appointment_d486d23b; Type: INDEX; Schema: scheduling; Owner: hospital_owner
--

CREATE INDEX fk_appointment_d486d23b ON scheduling.appointment USING btree (patient_id);


--
-- Name: fk_appointment_participant_1de39074; Type: INDEX; Schema: scheduling; Owner: hospital_owner
--

CREATE INDEX fk_appointment_participant_1de39074 ON scheduling.appointment_participant USING btree (staff_id);


--
-- Name: fk_schedule_713cc608; Type: INDEX; Schema: scheduling; Owner: hospital_owner
--

CREATE INDEX fk_schedule_713cc608 ON scheduling.schedule USING btree (staff_id);


--
-- Name: fk_schedule_f31a86bf; Type: INDEX; Schema: scheduling; Owner: hospital_owner
--

CREATE INDEX fk_schedule_f31a86bf ON scheduling.schedule USING btree (department_id);


--
-- Name: fk_slot_6b863562; Type: INDEX; Schema: scheduling; Owner: hospital_owner
--

CREATE INDEX fk_slot_6b863562 ON scheduling.slot USING btree (schedule_id, staff_id, department_id);


--
-- Name: fk_slot_f7e001c8; Type: INDEX; Schema: scheduling; Owner: hospital_owner
--

CREATE INDEX fk_slot_f7e001c8 ON scheduling.slot USING btree (room_id, department_id);


--
-- Name: observation_2024_01_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2024_01_encounter_id_patient_id_idx;


--
-- Name: observation_2024_01_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2024_01_observed_at_idx;


--
-- Name: observation_2024_01_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2024_01_patient_id_idx;


--
-- Name: observation_2024_01_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2024_01_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2024_01_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2024_01_pkey;


--
-- Name: observation_2024_01_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2024_01_recorded_by_idx;


--
-- Name: observation_2024_01_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2024_01_test_id_idx;


--
-- Name: observation_2024_01_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2024_01_unit_code_idx;


--
-- Name: observation_2024_01_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2024_01_value_concept_id_idx;


--
-- Name: observation_2024_02_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2024_02_encounter_id_patient_id_idx;


--
-- Name: observation_2024_02_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2024_02_observed_at_idx;


--
-- Name: observation_2024_02_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2024_02_patient_id_idx;


--
-- Name: observation_2024_02_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2024_02_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2024_02_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2024_02_pkey;


--
-- Name: observation_2024_02_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2024_02_recorded_by_idx;


--
-- Name: observation_2024_02_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2024_02_test_id_idx;


--
-- Name: observation_2024_02_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2024_02_unit_code_idx;


--
-- Name: observation_2024_02_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2024_02_value_concept_id_idx;


--
-- Name: observation_2024_03_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2024_03_encounter_id_patient_id_idx;


--
-- Name: observation_2024_03_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2024_03_observed_at_idx;


--
-- Name: observation_2024_03_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2024_03_patient_id_idx;


--
-- Name: observation_2024_03_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2024_03_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2024_03_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2024_03_pkey;


--
-- Name: observation_2024_03_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2024_03_recorded_by_idx;


--
-- Name: observation_2024_03_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2024_03_test_id_idx;


--
-- Name: observation_2024_03_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2024_03_unit_code_idx;


--
-- Name: observation_2024_03_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2024_03_value_concept_id_idx;


--
-- Name: observation_2024_04_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2024_04_encounter_id_patient_id_idx;


--
-- Name: observation_2024_04_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2024_04_observed_at_idx;


--
-- Name: observation_2024_04_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2024_04_patient_id_idx;


--
-- Name: observation_2024_04_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2024_04_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2024_04_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2024_04_pkey;


--
-- Name: observation_2024_04_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2024_04_recorded_by_idx;


--
-- Name: observation_2024_04_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2024_04_test_id_idx;


--
-- Name: observation_2024_04_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2024_04_unit_code_idx;


--
-- Name: observation_2024_04_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2024_04_value_concept_id_idx;


--
-- Name: observation_2024_05_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2024_05_encounter_id_patient_id_idx;


--
-- Name: observation_2024_05_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2024_05_observed_at_idx;


--
-- Name: observation_2024_05_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2024_05_patient_id_idx;


--
-- Name: observation_2024_05_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2024_05_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2024_05_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2024_05_pkey;


--
-- Name: observation_2024_05_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2024_05_recorded_by_idx;


--
-- Name: observation_2024_05_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2024_05_test_id_idx;


--
-- Name: observation_2024_05_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2024_05_unit_code_idx;


--
-- Name: observation_2024_05_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2024_05_value_concept_id_idx;


--
-- Name: observation_2024_06_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2024_06_encounter_id_patient_id_idx;


--
-- Name: observation_2024_06_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2024_06_observed_at_idx;


--
-- Name: observation_2024_06_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2024_06_patient_id_idx;


--
-- Name: observation_2024_06_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2024_06_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2024_06_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2024_06_pkey;


--
-- Name: observation_2024_06_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2024_06_recorded_by_idx;


--
-- Name: observation_2024_06_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2024_06_test_id_idx;


--
-- Name: observation_2024_06_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2024_06_unit_code_idx;


--
-- Name: observation_2024_06_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2024_06_value_concept_id_idx;


--
-- Name: observation_2024_07_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2024_07_encounter_id_patient_id_idx;


--
-- Name: observation_2024_07_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2024_07_observed_at_idx;


--
-- Name: observation_2024_07_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2024_07_patient_id_idx;


--
-- Name: observation_2024_07_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2024_07_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2024_07_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2024_07_pkey;


--
-- Name: observation_2024_07_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2024_07_recorded_by_idx;


--
-- Name: observation_2024_07_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2024_07_test_id_idx;


--
-- Name: observation_2024_07_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2024_07_unit_code_idx;


--
-- Name: observation_2024_07_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2024_07_value_concept_id_idx;


--
-- Name: observation_2024_08_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2024_08_encounter_id_patient_id_idx;


--
-- Name: observation_2024_08_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2024_08_observed_at_idx;


--
-- Name: observation_2024_08_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2024_08_patient_id_idx;


--
-- Name: observation_2024_08_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2024_08_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2024_08_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2024_08_pkey;


--
-- Name: observation_2024_08_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2024_08_recorded_by_idx;


--
-- Name: observation_2024_08_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2024_08_test_id_idx;


--
-- Name: observation_2024_08_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2024_08_unit_code_idx;


--
-- Name: observation_2024_08_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2024_08_value_concept_id_idx;


--
-- Name: observation_2024_09_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2024_09_encounter_id_patient_id_idx;


--
-- Name: observation_2024_09_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2024_09_observed_at_idx;


--
-- Name: observation_2024_09_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2024_09_patient_id_idx;


--
-- Name: observation_2024_09_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2024_09_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2024_09_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2024_09_pkey;


--
-- Name: observation_2024_09_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2024_09_recorded_by_idx;


--
-- Name: observation_2024_09_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2024_09_test_id_idx;


--
-- Name: observation_2024_09_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2024_09_unit_code_idx;


--
-- Name: observation_2024_09_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2024_09_value_concept_id_idx;


--
-- Name: observation_2024_10_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2024_10_encounter_id_patient_id_idx;


--
-- Name: observation_2024_10_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2024_10_observed_at_idx;


--
-- Name: observation_2024_10_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2024_10_patient_id_idx;


--
-- Name: observation_2024_10_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2024_10_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2024_10_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2024_10_pkey;


--
-- Name: observation_2024_10_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2024_10_recorded_by_idx;


--
-- Name: observation_2024_10_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2024_10_test_id_idx;


--
-- Name: observation_2024_10_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2024_10_unit_code_idx;


--
-- Name: observation_2024_10_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2024_10_value_concept_id_idx;


--
-- Name: observation_2024_11_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2024_11_encounter_id_patient_id_idx;


--
-- Name: observation_2024_11_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2024_11_observed_at_idx;


--
-- Name: observation_2024_11_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2024_11_patient_id_idx;


--
-- Name: observation_2024_11_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2024_11_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2024_11_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2024_11_pkey;


--
-- Name: observation_2024_11_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2024_11_recorded_by_idx;


--
-- Name: observation_2024_11_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2024_11_test_id_idx;


--
-- Name: observation_2024_11_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2024_11_unit_code_idx;


--
-- Name: observation_2024_11_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2024_11_value_concept_id_idx;


--
-- Name: observation_2024_12_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2024_12_encounter_id_patient_id_idx;


--
-- Name: observation_2024_12_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2024_12_observed_at_idx;


--
-- Name: observation_2024_12_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2024_12_patient_id_idx;


--
-- Name: observation_2024_12_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2024_12_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2024_12_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2024_12_pkey;


--
-- Name: observation_2024_12_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2024_12_recorded_by_idx;


--
-- Name: observation_2024_12_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2024_12_test_id_idx;


--
-- Name: observation_2024_12_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2024_12_unit_code_idx;


--
-- Name: observation_2024_12_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2024_12_value_concept_id_idx;


--
-- Name: observation_2025_01_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2025_01_encounter_id_patient_id_idx;


--
-- Name: observation_2025_01_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2025_01_observed_at_idx;


--
-- Name: observation_2025_01_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2025_01_patient_id_idx;


--
-- Name: observation_2025_01_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2025_01_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2025_01_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2025_01_pkey;


--
-- Name: observation_2025_01_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2025_01_recorded_by_idx;


--
-- Name: observation_2025_01_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2025_01_test_id_idx;


--
-- Name: observation_2025_01_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2025_01_unit_code_idx;


--
-- Name: observation_2025_01_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2025_01_value_concept_id_idx;


--
-- Name: observation_2025_02_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2025_02_encounter_id_patient_id_idx;


--
-- Name: observation_2025_02_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2025_02_observed_at_idx;


--
-- Name: observation_2025_02_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2025_02_patient_id_idx;


--
-- Name: observation_2025_02_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2025_02_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2025_02_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2025_02_pkey;


--
-- Name: observation_2025_02_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2025_02_recorded_by_idx;


--
-- Name: observation_2025_02_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2025_02_test_id_idx;


--
-- Name: observation_2025_02_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2025_02_unit_code_idx;


--
-- Name: observation_2025_02_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2025_02_value_concept_id_idx;


--
-- Name: observation_2025_03_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2025_03_encounter_id_patient_id_idx;


--
-- Name: observation_2025_03_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2025_03_observed_at_idx;


--
-- Name: observation_2025_03_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2025_03_patient_id_idx;


--
-- Name: observation_2025_03_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2025_03_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2025_03_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2025_03_pkey;


--
-- Name: observation_2025_03_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2025_03_recorded_by_idx;


--
-- Name: observation_2025_03_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2025_03_test_id_idx;


--
-- Name: observation_2025_03_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2025_03_unit_code_idx;


--
-- Name: observation_2025_03_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2025_03_value_concept_id_idx;


--
-- Name: observation_2025_04_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2025_04_encounter_id_patient_id_idx;


--
-- Name: observation_2025_04_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2025_04_observed_at_idx;


--
-- Name: observation_2025_04_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2025_04_patient_id_idx;


--
-- Name: observation_2025_04_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2025_04_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2025_04_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2025_04_pkey;


--
-- Name: observation_2025_04_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2025_04_recorded_by_idx;


--
-- Name: observation_2025_04_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2025_04_test_id_idx;


--
-- Name: observation_2025_04_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2025_04_unit_code_idx;


--
-- Name: observation_2025_04_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2025_04_value_concept_id_idx;


--
-- Name: observation_2025_05_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2025_05_encounter_id_patient_id_idx;


--
-- Name: observation_2025_05_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2025_05_observed_at_idx;


--
-- Name: observation_2025_05_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2025_05_patient_id_idx;


--
-- Name: observation_2025_05_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2025_05_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2025_05_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2025_05_pkey;


--
-- Name: observation_2025_05_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2025_05_recorded_by_idx;


--
-- Name: observation_2025_05_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2025_05_test_id_idx;


--
-- Name: observation_2025_05_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2025_05_unit_code_idx;


--
-- Name: observation_2025_05_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2025_05_value_concept_id_idx;


--
-- Name: observation_2025_06_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2025_06_encounter_id_patient_id_idx;


--
-- Name: observation_2025_06_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2025_06_observed_at_idx;


--
-- Name: observation_2025_06_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2025_06_patient_id_idx;


--
-- Name: observation_2025_06_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2025_06_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2025_06_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2025_06_pkey;


--
-- Name: observation_2025_06_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2025_06_recorded_by_idx;


--
-- Name: observation_2025_06_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2025_06_test_id_idx;


--
-- Name: observation_2025_06_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2025_06_unit_code_idx;


--
-- Name: observation_2025_06_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2025_06_value_concept_id_idx;


--
-- Name: observation_2025_07_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2025_07_encounter_id_patient_id_idx;


--
-- Name: observation_2025_07_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2025_07_observed_at_idx;


--
-- Name: observation_2025_07_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2025_07_patient_id_idx;


--
-- Name: observation_2025_07_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2025_07_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2025_07_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2025_07_pkey;


--
-- Name: observation_2025_07_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2025_07_recorded_by_idx;


--
-- Name: observation_2025_07_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2025_07_test_id_idx;


--
-- Name: observation_2025_07_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2025_07_unit_code_idx;


--
-- Name: observation_2025_07_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2025_07_value_concept_id_idx;


--
-- Name: observation_2025_08_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2025_08_encounter_id_patient_id_idx;


--
-- Name: observation_2025_08_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2025_08_observed_at_idx;


--
-- Name: observation_2025_08_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2025_08_patient_id_idx;


--
-- Name: observation_2025_08_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2025_08_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2025_08_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2025_08_pkey;


--
-- Name: observation_2025_08_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2025_08_recorded_by_idx;


--
-- Name: observation_2025_08_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2025_08_test_id_idx;


--
-- Name: observation_2025_08_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2025_08_unit_code_idx;


--
-- Name: observation_2025_08_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2025_08_value_concept_id_idx;


--
-- Name: observation_2025_09_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2025_09_encounter_id_patient_id_idx;


--
-- Name: observation_2025_09_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2025_09_observed_at_idx;


--
-- Name: observation_2025_09_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2025_09_patient_id_idx;


--
-- Name: observation_2025_09_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2025_09_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2025_09_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2025_09_pkey;


--
-- Name: observation_2025_09_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2025_09_recorded_by_idx;


--
-- Name: observation_2025_09_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2025_09_test_id_idx;


--
-- Name: observation_2025_09_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2025_09_unit_code_idx;


--
-- Name: observation_2025_09_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2025_09_value_concept_id_idx;


--
-- Name: observation_2025_10_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2025_10_encounter_id_patient_id_idx;


--
-- Name: observation_2025_10_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2025_10_observed_at_idx;


--
-- Name: observation_2025_10_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2025_10_patient_id_idx;


--
-- Name: observation_2025_10_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2025_10_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2025_10_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2025_10_pkey;


--
-- Name: observation_2025_10_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2025_10_recorded_by_idx;


--
-- Name: observation_2025_10_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2025_10_test_id_idx;


--
-- Name: observation_2025_10_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2025_10_unit_code_idx;


--
-- Name: observation_2025_10_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2025_10_value_concept_id_idx;


--
-- Name: observation_2025_11_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2025_11_encounter_id_patient_id_idx;


--
-- Name: observation_2025_11_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2025_11_observed_at_idx;


--
-- Name: observation_2025_11_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2025_11_patient_id_idx;


--
-- Name: observation_2025_11_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2025_11_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2025_11_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2025_11_pkey;


--
-- Name: observation_2025_11_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2025_11_recorded_by_idx;


--
-- Name: observation_2025_11_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2025_11_test_id_idx;


--
-- Name: observation_2025_11_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2025_11_unit_code_idx;


--
-- Name: observation_2025_11_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2025_11_value_concept_id_idx;


--
-- Name: observation_2025_12_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2025_12_encounter_id_patient_id_idx;


--
-- Name: observation_2025_12_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2025_12_observed_at_idx;


--
-- Name: observation_2025_12_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2025_12_patient_id_idx;


--
-- Name: observation_2025_12_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2025_12_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2025_12_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2025_12_pkey;


--
-- Name: observation_2025_12_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2025_12_recorded_by_idx;


--
-- Name: observation_2025_12_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2025_12_test_id_idx;


--
-- Name: observation_2025_12_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2025_12_unit_code_idx;


--
-- Name: observation_2025_12_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2025_12_value_concept_id_idx;


--
-- Name: observation_2026_01_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2026_01_encounter_id_patient_id_idx;


--
-- Name: observation_2026_01_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2026_01_observed_at_idx;


--
-- Name: observation_2026_01_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2026_01_patient_id_idx;


--
-- Name: observation_2026_01_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2026_01_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2026_01_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2026_01_pkey;


--
-- Name: observation_2026_01_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2026_01_recorded_by_idx;


--
-- Name: observation_2026_01_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2026_01_test_id_idx;


--
-- Name: observation_2026_01_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2026_01_unit_code_idx;


--
-- Name: observation_2026_01_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2026_01_value_concept_id_idx;


--
-- Name: observation_2026_02_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2026_02_encounter_id_patient_id_idx;


--
-- Name: observation_2026_02_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2026_02_observed_at_idx;


--
-- Name: observation_2026_02_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2026_02_patient_id_idx;


--
-- Name: observation_2026_02_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2026_02_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2026_02_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2026_02_pkey;


--
-- Name: observation_2026_02_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2026_02_recorded_by_idx;


--
-- Name: observation_2026_02_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2026_02_test_id_idx;


--
-- Name: observation_2026_02_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2026_02_unit_code_idx;


--
-- Name: observation_2026_02_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2026_02_value_concept_id_idx;


--
-- Name: observation_2026_03_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2026_03_encounter_id_patient_id_idx;


--
-- Name: observation_2026_03_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2026_03_observed_at_idx;


--
-- Name: observation_2026_03_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2026_03_patient_id_idx;


--
-- Name: observation_2026_03_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2026_03_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2026_03_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2026_03_pkey;


--
-- Name: observation_2026_03_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2026_03_recorded_by_idx;


--
-- Name: observation_2026_03_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2026_03_test_id_idx;


--
-- Name: observation_2026_03_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2026_03_unit_code_idx;


--
-- Name: observation_2026_03_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2026_03_value_concept_id_idx;


--
-- Name: observation_2026_04_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2026_04_encounter_id_patient_id_idx;


--
-- Name: observation_2026_04_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2026_04_observed_at_idx;


--
-- Name: observation_2026_04_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2026_04_patient_id_idx;


--
-- Name: observation_2026_04_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2026_04_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2026_04_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2026_04_pkey;


--
-- Name: observation_2026_04_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2026_04_recorded_by_idx;


--
-- Name: observation_2026_04_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2026_04_test_id_idx;


--
-- Name: observation_2026_04_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2026_04_unit_code_idx;


--
-- Name: observation_2026_04_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2026_04_value_concept_id_idx;


--
-- Name: observation_2026_05_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2026_05_encounter_id_patient_id_idx;


--
-- Name: observation_2026_05_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2026_05_observed_at_idx;


--
-- Name: observation_2026_05_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2026_05_patient_id_idx;


--
-- Name: observation_2026_05_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2026_05_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2026_05_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2026_05_pkey;


--
-- Name: observation_2026_05_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2026_05_recorded_by_idx;


--
-- Name: observation_2026_05_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2026_05_test_id_idx;


--
-- Name: observation_2026_05_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2026_05_unit_code_idx;


--
-- Name: observation_2026_05_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2026_05_value_concept_id_idx;


--
-- Name: observation_2026_06_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2026_06_encounter_id_patient_id_idx;


--
-- Name: observation_2026_06_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2026_06_observed_at_idx;


--
-- Name: observation_2026_06_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2026_06_patient_id_idx;


--
-- Name: observation_2026_06_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2026_06_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2026_06_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2026_06_pkey;


--
-- Name: observation_2026_06_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2026_06_recorded_by_idx;


--
-- Name: observation_2026_06_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2026_06_test_id_idx;


--
-- Name: observation_2026_06_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2026_06_unit_code_idx;


--
-- Name: observation_2026_06_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2026_06_value_concept_id_idx;


--
-- Name: observation_2026_07_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2026_07_encounter_id_patient_id_idx;


--
-- Name: observation_2026_07_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2026_07_observed_at_idx;


--
-- Name: observation_2026_07_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2026_07_patient_id_idx;


--
-- Name: observation_2026_07_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2026_07_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2026_07_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2026_07_pkey;


--
-- Name: observation_2026_07_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2026_07_recorded_by_idx;


--
-- Name: observation_2026_07_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2026_07_test_id_idx;


--
-- Name: observation_2026_07_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2026_07_unit_code_idx;


--
-- Name: observation_2026_07_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2026_07_value_concept_id_idx;


--
-- Name: observation_2026_08_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2026_08_encounter_id_patient_id_idx;


--
-- Name: observation_2026_08_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2026_08_observed_at_idx;


--
-- Name: observation_2026_08_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2026_08_patient_id_idx;


--
-- Name: observation_2026_08_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2026_08_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2026_08_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2026_08_pkey;


--
-- Name: observation_2026_08_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2026_08_recorded_by_idx;


--
-- Name: observation_2026_08_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2026_08_test_id_idx;


--
-- Name: observation_2026_08_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2026_08_unit_code_idx;


--
-- Name: observation_2026_08_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2026_08_value_concept_id_idx;


--
-- Name: observation_2026_09_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2026_09_encounter_id_patient_id_idx;


--
-- Name: observation_2026_09_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2026_09_observed_at_idx;


--
-- Name: observation_2026_09_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2026_09_patient_id_idx;


--
-- Name: observation_2026_09_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2026_09_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2026_09_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2026_09_pkey;


--
-- Name: observation_2026_09_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2026_09_recorded_by_idx;


--
-- Name: observation_2026_09_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2026_09_test_id_idx;


--
-- Name: observation_2026_09_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2026_09_unit_code_idx;


--
-- Name: observation_2026_09_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2026_09_value_concept_id_idx;


--
-- Name: observation_2026_10_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2026_10_encounter_id_patient_id_idx;


--
-- Name: observation_2026_10_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2026_10_observed_at_idx;


--
-- Name: observation_2026_10_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2026_10_patient_id_idx;


--
-- Name: observation_2026_10_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2026_10_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2026_10_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2026_10_pkey;


--
-- Name: observation_2026_10_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2026_10_recorded_by_idx;


--
-- Name: observation_2026_10_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2026_10_test_id_idx;


--
-- Name: observation_2026_10_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2026_10_unit_code_idx;


--
-- Name: observation_2026_10_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2026_10_value_concept_id_idx;


--
-- Name: observation_2026_11_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2026_11_encounter_id_patient_id_idx;


--
-- Name: observation_2026_11_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2026_11_observed_at_idx;


--
-- Name: observation_2026_11_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2026_11_patient_id_idx;


--
-- Name: observation_2026_11_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2026_11_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2026_11_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2026_11_pkey;


--
-- Name: observation_2026_11_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2026_11_recorded_by_idx;


--
-- Name: observation_2026_11_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2026_11_test_id_idx;


--
-- Name: observation_2026_11_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2026_11_unit_code_idx;


--
-- Name: observation_2026_11_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2026_11_value_concept_id_idx;


--
-- Name: observation_2026_12_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2026_12_encounter_id_patient_id_idx;


--
-- Name: observation_2026_12_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2026_12_observed_at_idx;


--
-- Name: observation_2026_12_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2026_12_patient_id_idx;


--
-- Name: observation_2026_12_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2026_12_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2026_12_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2026_12_pkey;


--
-- Name: observation_2026_12_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2026_12_recorded_by_idx;


--
-- Name: observation_2026_12_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2026_12_test_id_idx;


--
-- Name: observation_2026_12_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2026_12_unit_code_idx;


--
-- Name: observation_2026_12_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2026_12_value_concept_id_idx;


--
-- Name: observation_2027_01_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2027_01_encounter_id_patient_id_idx;


--
-- Name: observation_2027_01_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2027_01_observed_at_idx;


--
-- Name: observation_2027_01_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2027_01_patient_id_idx;


--
-- Name: observation_2027_01_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2027_01_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2027_01_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2027_01_pkey;


--
-- Name: observation_2027_01_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2027_01_recorded_by_idx;


--
-- Name: observation_2027_01_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2027_01_test_id_idx;


--
-- Name: observation_2027_01_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2027_01_unit_code_idx;


--
-- Name: observation_2027_01_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2027_01_value_concept_id_idx;


--
-- Name: observation_2027_02_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2027_02_encounter_id_patient_id_idx;


--
-- Name: observation_2027_02_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2027_02_observed_at_idx;


--
-- Name: observation_2027_02_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2027_02_patient_id_idx;


--
-- Name: observation_2027_02_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2027_02_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2027_02_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2027_02_pkey;


--
-- Name: observation_2027_02_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2027_02_recorded_by_idx;


--
-- Name: observation_2027_02_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2027_02_test_id_idx;


--
-- Name: observation_2027_02_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2027_02_unit_code_idx;


--
-- Name: observation_2027_02_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2027_02_value_concept_id_idx;


--
-- Name: observation_2027_03_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2027_03_encounter_id_patient_id_idx;


--
-- Name: observation_2027_03_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2027_03_observed_at_idx;


--
-- Name: observation_2027_03_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2027_03_patient_id_idx;


--
-- Name: observation_2027_03_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2027_03_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2027_03_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2027_03_pkey;


--
-- Name: observation_2027_03_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2027_03_recorded_by_idx;


--
-- Name: observation_2027_03_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2027_03_test_id_idx;


--
-- Name: observation_2027_03_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2027_03_unit_code_idx;


--
-- Name: observation_2027_03_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2027_03_value_concept_id_idx;


--
-- Name: observation_2027_04_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2027_04_encounter_id_patient_id_idx;


--
-- Name: observation_2027_04_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2027_04_observed_at_idx;


--
-- Name: observation_2027_04_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2027_04_patient_id_idx;


--
-- Name: observation_2027_04_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2027_04_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2027_04_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2027_04_pkey;


--
-- Name: observation_2027_04_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2027_04_recorded_by_idx;


--
-- Name: observation_2027_04_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2027_04_test_id_idx;


--
-- Name: observation_2027_04_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2027_04_unit_code_idx;


--
-- Name: observation_2027_04_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2027_04_value_concept_id_idx;


--
-- Name: observation_2027_05_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2027_05_encounter_id_patient_id_idx;


--
-- Name: observation_2027_05_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2027_05_observed_at_idx;


--
-- Name: observation_2027_05_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2027_05_patient_id_idx;


--
-- Name: observation_2027_05_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2027_05_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2027_05_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2027_05_pkey;


--
-- Name: observation_2027_05_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2027_05_recorded_by_idx;


--
-- Name: observation_2027_05_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2027_05_test_id_idx;


--
-- Name: observation_2027_05_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2027_05_unit_code_idx;


--
-- Name: observation_2027_05_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2027_05_value_concept_id_idx;


--
-- Name: observation_2027_06_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2027_06_encounter_id_patient_id_idx;


--
-- Name: observation_2027_06_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2027_06_observed_at_idx;


--
-- Name: observation_2027_06_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2027_06_patient_id_idx;


--
-- Name: observation_2027_06_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2027_06_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2027_06_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2027_06_pkey;


--
-- Name: observation_2027_06_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2027_06_recorded_by_idx;


--
-- Name: observation_2027_06_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2027_06_test_id_idx;


--
-- Name: observation_2027_06_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2027_06_unit_code_idx;


--
-- Name: observation_2027_06_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2027_06_value_concept_id_idx;


--
-- Name: observation_2027_07_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2027_07_encounter_id_patient_id_idx;


--
-- Name: observation_2027_07_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2027_07_observed_at_idx;


--
-- Name: observation_2027_07_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2027_07_patient_id_idx;


--
-- Name: observation_2027_07_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2027_07_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2027_07_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2027_07_pkey;


--
-- Name: observation_2027_07_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2027_07_recorded_by_idx;


--
-- Name: observation_2027_07_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2027_07_test_id_idx;


--
-- Name: observation_2027_07_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2027_07_unit_code_idx;


--
-- Name: observation_2027_07_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2027_07_value_concept_id_idx;


--
-- Name: observation_2027_08_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2027_08_encounter_id_patient_id_idx;


--
-- Name: observation_2027_08_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2027_08_observed_at_idx;


--
-- Name: observation_2027_08_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2027_08_patient_id_idx;


--
-- Name: observation_2027_08_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2027_08_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2027_08_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2027_08_pkey;


--
-- Name: observation_2027_08_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2027_08_recorded_by_idx;


--
-- Name: observation_2027_08_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2027_08_test_id_idx;


--
-- Name: observation_2027_08_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2027_08_unit_code_idx;


--
-- Name: observation_2027_08_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2027_08_value_concept_id_idx;


--
-- Name: observation_2027_09_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2027_09_encounter_id_patient_id_idx;


--
-- Name: observation_2027_09_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2027_09_observed_at_idx;


--
-- Name: observation_2027_09_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2027_09_patient_id_idx;


--
-- Name: observation_2027_09_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2027_09_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2027_09_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2027_09_pkey;


--
-- Name: observation_2027_09_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2027_09_recorded_by_idx;


--
-- Name: observation_2027_09_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2027_09_test_id_idx;


--
-- Name: observation_2027_09_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2027_09_unit_code_idx;


--
-- Name: observation_2027_09_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2027_09_value_concept_id_idx;


--
-- Name: observation_2027_10_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2027_10_encounter_id_patient_id_idx;


--
-- Name: observation_2027_10_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2027_10_observed_at_idx;


--
-- Name: observation_2027_10_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2027_10_patient_id_idx;


--
-- Name: observation_2027_10_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2027_10_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2027_10_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2027_10_pkey;


--
-- Name: observation_2027_10_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2027_10_recorded_by_idx;


--
-- Name: observation_2027_10_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2027_10_test_id_idx;


--
-- Name: observation_2027_10_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2027_10_unit_code_idx;


--
-- Name: observation_2027_10_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2027_10_value_concept_id_idx;


--
-- Name: observation_2027_11_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2027_11_encounter_id_patient_id_idx;


--
-- Name: observation_2027_11_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2027_11_observed_at_idx;


--
-- Name: observation_2027_11_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2027_11_patient_id_idx;


--
-- Name: observation_2027_11_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2027_11_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2027_11_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2027_11_pkey;


--
-- Name: observation_2027_11_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2027_11_recorded_by_idx;


--
-- Name: observation_2027_11_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2027_11_test_id_idx;


--
-- Name: observation_2027_11_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2027_11_unit_code_idx;


--
-- Name: observation_2027_11_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2027_11_value_concept_id_idx;


--
-- Name: observation_2027_12_encounter_id_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_3f716295 ATTACH PARTITION ehr.observation_2027_12_encounter_id_patient_id_idx;


--
-- Name: observation_2027_12_observed_at_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_time_brin ATTACH PARTITION ehr.observation_2027_12_observed_at_idx;


--
-- Name: observation_2027_12_patient_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d4cda705 ATTACH PARTITION ehr.observation_2027_12_patient_id_idx;


--
-- Name: observation_2027_12_patient_id_observed_at_test_id_value_nu_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_timeline ATTACH PARTITION ehr.observation_2027_12_patient_id_observed_at_test_id_value_nu_idx;


--
-- Name: observation_2027_12_pkey; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.observation_pkey ATTACH PARTITION ehr.observation_2027_12_pkey;


--
-- Name: observation_2027_12_recorded_by_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_98b3f216 ATTACH PARTITION ehr.observation_2027_12_recorded_by_idx;


--
-- Name: observation_2027_12_test_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_d10cfc96 ATTACH PARTITION ehr.observation_2027_12_test_id_idx;


--
-- Name: observation_2027_12_unit_code_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_4ac682dd ATTACH PARTITION ehr.observation_2027_12_unit_code_idx;


--
-- Name: observation_2027_12_value_concept_id_idx; Type: INDEX ATTACH; Schema: ehr; Owner: hospital_owner
--

ALTER INDEX ehr.fk_observation_9b4a70b7 ATTACH PARTITION ehr.observation_2027_12_value_concept_id_idx;


--
-- Name: admission admission_period_guard; Type: TRIGGER; Schema: adt; Owner: hospital_owner
--

CREATE TRIGGER admission_period_guard BEFORE INSERT OR UPDATE ON adt.admission FOR EACH ROW EXECUTE FUNCTION adt.guard_admission();


--
-- Name: admission audit_change; Type: TRIGGER; Schema: adt; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON adt.admission FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: bed_stay audit_change; Type: TRIGGER; Schema: adt; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON adt.bed_stay FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: discharge audit_change; Type: TRIGGER; Schema: adt; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON adt.discharge FOR EACH ROW EXECUTE FUNCTION audit.capture_change('admission_id', 'patient_id');


--
-- Name: bed_stay bed_stay_guard; Type: TRIGGER; Schema: adt; Owner: hospital_owner
--

CREATE TRIGGER bed_stay_guard BEFORE INSERT OR UPDATE ON adt.bed_stay FOR EACH ROW EXECUTE FUNCTION adt.guard_bed_stay();


--
-- Name: discharge discharge_instant_guard; Type: TRIGGER; Schema: adt; Owner: hospital_owner
--

CREATE TRIGGER discharge_instant_guard BEFORE INSERT OR UPDATE ON adt.discharge FOR EACH ROW EXECUTE FUNCTION adt.guard_discharge();


--
-- Name: admission patient_identity_immutable; Type: TRIGGER; Schema: adt; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON adt.admission FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: bed_stay patient_identity_immutable; Type: TRIGGER; Schema: adt; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON adt.bed_stay FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: discharge patient_identity_immutable; Type: TRIGGER; Schema: adt; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON adt.discharge FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: access_event audit_access_immutable; Type: TRIGGER; Schema: audit; Owner: hospital_owner
--

CREATE TRIGGER audit_access_immutable BEFORE DELETE OR UPDATE ON audit.access_event FOR EACH ROW EXECUTE FUNCTION ops.deny_mutation();


--
-- Name: event audit_events_immutable; Type: TRIGGER; Schema: audit; Owner: hospital_owner
--

CREATE TRIGGER audit_events_immutable BEFORE DELETE OR UPDATE ON audit.event FOR EACH ROW EXECUTE FUNCTION ops.deny_mutation();


--
-- Name: payment_allocation allocation_immutable; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER allocation_immutable BEFORE DELETE OR UPDATE ON billing.payment_allocation FOR EACH ROW EXECUTE FUNCTION ops.deny_mutation();


--
-- Name: claim audit_change; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.claim FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: coverage audit_change; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.coverage FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: invoice audit_change; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.invoice FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: invoice_line audit_change; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.invoice_line FOR EACH ROW EXECUTE FUNCTION audit.capture_change('invoice_id', 'line_no');


--
-- Name: payer audit_change; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.payer FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: payment audit_change; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.payment FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: payment_allocation audit_change; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.payment_allocation FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: tariff audit_change; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.tariff FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: invoice invoice_coverage_guard; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER invoice_coverage_guard BEFORE INSERT OR UPDATE ON billing.invoice FOR EACH ROW EXECUTE FUNCTION billing.guard_coverage();


--
-- Name: invoice invoice_guard; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER invoice_guard BEFORE UPDATE ON billing.invoice FOR EACH ROW EXECUTE FUNCTION billing.guard_invoice();


--
-- Name: invoice_line invoice_line_guard; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER invoice_line_guard BEFORE INSERT OR DELETE OR UPDATE ON billing.invoice_line FOR EACH ROW EXECUTE FUNCTION billing.guard_invoice_line();


--
-- Name: claim patient_identity_immutable; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON billing.claim FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: coverage patient_identity_immutable; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON billing.coverage FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: invoice patient_identity_immutable; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON billing.invoice FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: payment patient_identity_immutable; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON billing.payment FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: payment_allocation patient_identity_immutable; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON billing.payment_allocation FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: payment_allocation payment_allocation_guard; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER payment_allocation_guard BEFORE INSERT ON billing.payment_allocation FOR EACH ROW EXECUTE FUNCTION billing.guard_allocation();


--
-- Name: payment payment_immutable; Type: TRIGGER; Schema: billing; Owner: hospital_owner
--

CREATE TRIGGER payment_immutable BEFORE DELETE OR UPDATE ON billing.payment FOR EACH ROW EXECUTE FUNCTION ops.deny_mutation();


--
-- Name: allergy audit_change; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.allergy FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: care_plan audit_change; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.care_plan FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: care_plan_activity audit_change; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.care_plan_activity FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: clinical_note audit_change; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.clinical_note FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: condition audit_change; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.condition FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: death_record audit_change; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.death_record FOR EACH ROW EXECUTE FUNCTION audit.capture_change('patient_id');


--
-- Name: document audit_change; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.document FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: encounter audit_change; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.encounter FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: encounter_participant audit_change; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.encounter_participant FOR EACH ROW EXECUTE FUNCTION audit.capture_change('encounter_id', 'role_code', 'staff_id');


--
-- Name: immunization audit_change; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.immunization FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: note_version audit_change; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.note_version FOR EACH ROW EXECUTE FUNCTION audit.capture_change('note_id', 'version');


--
-- Name: observation audit_change; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.observation FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'observed_at', 'patient_id');


--
-- Name: procedure audit_change; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.procedure FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: allergy author_identity; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.allergy FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('recorded_by');


--
-- Name: care_plan author_identity; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.care_plan FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('author_id');


--
-- Name: clinical_note author_identity; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.clinical_note FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('author_id');


--
-- Name: condition author_identity; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.condition FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('recorded_by');


--
-- Name: note_version author_identity; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.note_version FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('author_id');


--
-- Name: observation author_identity; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.observation FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('recorded_by');


--
-- Name: encounter encounter_guard; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER encounter_guard BEFORE INSERT OR UPDATE ON ehr.encounter FOR EACH ROW EXECUTE FUNCTION ehr.guard_encounter();


--
-- Name: encounter encounter_touch; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER encounter_touch BEFORE UPDATE ON ehr.encounter FOR EACH ROW EXECUTE FUNCTION ops.touch_row();


--
-- Name: observation observation_type_guard; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER observation_type_guard BEFORE INSERT OR UPDATE ON ehr.observation FOR EACH ROW EXECUTE FUNCTION ehr.guard_observation();


--
-- Name: allergy patient_identity_immutable; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.allergy FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: care_plan patient_identity_immutable; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.care_plan FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: clinical_note patient_identity_immutable; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.clinical_note FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: condition patient_identity_immutable; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.condition FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: death_record patient_identity_immutable; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.death_record FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: document patient_identity_immutable; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.document FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: encounter patient_identity_immutable; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.encounter FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: immunization patient_identity_immutable; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.immunization FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: observation patient_identity_immutable; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.observation FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: procedure patient_identity_immutable; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.procedure FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: note_version signed_note_immutable; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER signed_note_immutable BEFORE DELETE OR UPDATE ON ehr.note_version FOR EACH ROW EXECUTE FUNCTION ehr.guard_note_version();


--
-- Name: note_version signer_identity; Type: TRIGGER; Schema: ehr; Owner: hospital_owner
--

CREATE TRIGGER signer_identity BEFORE INSERT OR UPDATE ON ehr.note_version FOR EACH ROW EXECUTE FUNCTION ehr.guard_signer();


--
-- Name: access_grant audit_change; Type: TRIGGER; Schema: iam; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON iam.access_grant FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: application_user audit_change; Type: TRIGGER; Schema: iam; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON iam.application_user FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: break_glass audit_change; Type: TRIGGER; Schema: iam; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON iam.break_glass FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: business_role audit_change; Type: TRIGGER; Schema: iam; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON iam.business_role FOR EACH ROW EXECUTE FUNCTION audit.capture_change('code');


--
-- Name: user_role audit_change; Type: TRIGGER; Schema: iam; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON iam.user_role FOR EACH ROW EXECUTE FUNCTION audit.capture_change('role_code', 'user_id');


--
-- Name: imaging_order audit_change; Type: TRIGGER; Schema: imaging; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON imaging.imaging_order FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: series audit_change; Type: TRIGGER; Schema: imaging; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON imaging.series FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: study audit_change; Type: TRIGGER; Schema: imaging; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON imaging.study FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: imaging_order patient_identity_immutable; Type: TRIGGER; Schema: imaging; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON imaging.imaging_order FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: study patient_identity_immutable; Type: TRIGGER; Schema: imaging; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON imaging.study FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: study study_modality_guard; Type: TRIGGER; Schema: imaging; Owner: hospital_owner
--

CREATE TRIGGER study_modality_guard BEFORE INSERT OR UPDATE ON imaging.study FOR EACH ROW EXECUTE FUNCTION imaging.guard_modality();


--
-- Name: export_job audit_change; Type: TRIGGER; Schema: integration; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON integration.export_job FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: external_identifier audit_change; Type: TRIGGER; Schema: integration; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON integration.external_identifier FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: inbox audit_change; Type: TRIGGER; Schema: integration; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON integration.inbox FOR EACH ROW EXECUTE FUNCTION audit.capture_change('message_id', 'source');


--
-- Name: outbox audit_change; Type: TRIGGER; Schema: integration; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON integration.outbox FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: item audit_change; Type: TRIGGER; Schema: inventory; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.item FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: location audit_change; Type: TRIGGER; Schema: inventory; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.location FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: lot audit_change; Type: TRIGGER; Schema: inventory; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.lot FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: purchase_order audit_change; Type: TRIGGER; Schema: inventory; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.purchase_order FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: purchase_order_line audit_change; Type: TRIGGER; Schema: inventory; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.purchase_order_line FOR EACH ROW EXECUTE FUNCTION audit.capture_change('line_no', 'order_id');


--
-- Name: stock_balance audit_change; Type: TRIGGER; Schema: inventory; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.stock_balance FOR EACH ROW EXECUTE FUNCTION audit.capture_change('location_id', 'lot_id');


--
-- Name: stock_movement audit_change; Type: TRIGGER; Schema: inventory; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.stock_movement FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: supplier audit_change; Type: TRIGGER; Schema: inventory; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.supplier FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: stock_movement stock_ledger_guard; Type: TRIGGER; Schema: inventory; Owner: hospital_owner
--

CREATE TRIGGER stock_ledger_guard BEFORE INSERT OR DELETE OR UPDATE ON inventory.stock_movement FOR EACH ROW EXECUTE FUNCTION inventory.guard_movement();


--
-- Name: diagnostic_report audit_change; Type: TRIGGER; Schema: lab; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON lab.diagnostic_report FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: report_result audit_change; Type: TRIGGER; Schema: lab; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON lab.report_result FOR EACH ROW EXECUTE FUNCTION audit.capture_change('patient_id', 'report_id', 'result_id');


--
-- Name: request_specimen audit_change; Type: TRIGGER; Schema: lab; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON lab.request_specimen FOR EACH ROW EXECUTE FUNCTION audit.capture_change('patient_id', 'request_id', 'specimen_id');


--
-- Name: result audit_change; Type: TRIGGER; Schema: lab; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON lab.result FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: service_request audit_change; Type: TRIGGER; Schema: lab; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON lab.service_request FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: specimen audit_change; Type: TRIGGER; Schema: lab; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON lab.specimen FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: diagnostic_report patient_identity_immutable; Type: TRIGGER; Schema: lab; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON lab.diagnostic_report FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: report_result patient_identity_immutable; Type: TRIGGER; Schema: lab; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON lab.report_result FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: request_specimen patient_identity_immutable; Type: TRIGGER; Schema: lab; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON lab.request_specimen FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: result patient_identity_immutable; Type: TRIGGER; Schema: lab; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON lab.result FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: service_request patient_identity_immutable; Type: TRIGGER; Schema: lab; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON lab.service_request FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: specimen patient_identity_immutable; Type: TRIGGER; Schema: lab; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON lab.specimen FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: report_result report_result_guard; Type: TRIGGER; Schema: lab; Owner: hospital_owner
--

CREATE TRIGGER report_result_guard BEFORE INSERT OR UPDATE ON lab.report_result FOR EACH ROW EXECUTE FUNCTION lab.guard_report_result();


--
-- Name: result result_type_time_guard; Type: TRIGGER; Schema: lab; Owner: hospital_owner
--

CREATE TRIGGER result_type_time_guard BEFORE INSERT OR UPDATE ON lab.result FOR EACH ROW EXECUTE FUNCTION lab.guard_result();


--
-- Name: address audit_change; Type: TRIGGER; Schema: mpi; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON mpi.address FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: consent audit_change; Type: TRIGGER; Schema: mpi; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON mpi.consent FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: contact audit_change; Type: TRIGGER; Schema: mpi; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON mpi.contact FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: identifier audit_change; Type: TRIGGER; Schema: mpi; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON mpi.identifier FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: merge_history audit_change; Type: TRIGGER; Schema: mpi; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON mpi.merge_history FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: patient audit_change; Type: TRIGGER; Schema: mpi; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON mpi.patient FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: related_person audit_change; Type: TRIGGER; Schema: mpi; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON mpi.related_person FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: patient patient_dates_guard; Type: TRIGGER; Schema: mpi; Owner: hospital_owner
--

CREATE TRIGGER patient_dates_guard BEFORE UPDATE OF birth_date, deceased_at ON mpi.patient FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_dates();


--
-- Name: patient patient_touch; Type: TRIGGER; Schema: mpi; Owner: hospital_owner
--

CREATE TRIGGER patient_touch BEFORE UPDATE ON mpi.patient FOR EACH ROW EXECUTE FUNCTION ops.touch_row();


--
-- Name: bed audit_change; Type: TRIGGER; Schema: org; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.bed FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: credential audit_change; Type: TRIGGER; Schema: org; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.credential FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: department audit_change; Type: TRIGGER; Schema: org; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.department FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: device audit_change; Type: TRIGGER; Schema: org; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.device FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: organization audit_change; Type: TRIGGER; Schema: org; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.organization FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: room audit_change; Type: TRIGGER; Schema: org; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.room FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: site audit_change; Type: TRIGGER; Schema: org; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.site FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: staff audit_change; Type: TRIGGER; Schema: org; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.staff FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: staff_department audit_change; Type: TRIGGER; Schema: org; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.staff_department FOR EACH ROW EXECUTE FUNCTION audit.capture_change('department_id', 'staff_id', 'valid_during');


--
-- Name: administration administration_guard; Type: TRIGGER; Schema: pharmacy; Owner: hospital_owner
--

CREATE TRIGGER administration_guard BEFORE INSERT ON pharmacy.administration FOR EACH ROW EXECUTE FUNCTION ehr.guard_administration();


--
-- Name: administration administration_immutable; Type: TRIGGER; Schema: pharmacy; Owner: hospital_owner
--

CREATE TRIGGER administration_immutable BEFORE DELETE OR UPDATE ON pharmacy.administration FOR EACH ROW EXECUTE FUNCTION ops.deny_mutation();


--
-- Name: administration administration_quantity_guard; Type: TRIGGER; Schema: pharmacy; Owner: hospital_owner
--

CREATE TRIGGER administration_quantity_guard BEFORE INSERT ON pharmacy.administration FOR EACH ROW EXECUTE FUNCTION pharmacy.guard_administration_quantity();


--
-- Name: administration audit_change; Type: TRIGGER; Schema: pharmacy; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON pharmacy.administration FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: dispense audit_change; Type: TRIGGER; Schema: pharmacy; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON pharmacy.dispense FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: medication_order audit_change; Type: TRIGGER; Schema: pharmacy; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON pharmacy.medication_order FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: medication_reconciliation audit_change; Type: TRIGGER; Schema: pharmacy; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON pharmacy.medication_reconciliation FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: dispense dispense_guard; Type: TRIGGER; Schema: pharmacy; Owner: hospital_owner
--

CREATE TRIGGER dispense_guard BEFORE INSERT ON pharmacy.dispense FOR EACH ROW EXECUTE FUNCTION pharmacy.guard_dispense();


--
-- Name: dispense dispense_immutable; Type: TRIGGER; Schema: pharmacy; Owner: hospital_owner
--

CREATE TRIGGER dispense_immutable BEFORE DELETE OR UPDATE ON pharmacy.dispense FOR EACH ROW EXECUTE FUNCTION ops.deny_mutation();


--
-- Name: dispense dispense_posts_stock; Type: TRIGGER; Schema: pharmacy; Owner: hospital_owner
--

CREATE TRIGGER dispense_posts_stock AFTER INSERT ON pharmacy.dispense FOR EACH ROW EXECUTE FUNCTION pharmacy.post_dispense();


--
-- Name: administration patient_identity_immutable; Type: TRIGGER; Schema: pharmacy; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON pharmacy.administration FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: dispense patient_identity_immutable; Type: TRIGGER; Schema: pharmacy; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON pharmacy.dispense FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: medication_order patient_identity_immutable; Type: TRIGGER; Schema: pharmacy; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON pharmacy.medication_order FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: medication_reconciliation patient_identity_immutable; Type: TRIGGER; Schema: pharmacy; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON pharmacy.medication_reconciliation FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: incident audit_change; Type: TRIGGER; Schema: quality; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON quality.incident FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: infection_case audit_change; Type: TRIGGER; Schema: quality; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON quality.infection_case FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: patient_feedback audit_change; Type: TRIGGER; Schema: quality; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON quality.patient_feedback FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: incident patient_identity_immutable; Type: TRIGGER; Schema: quality; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON quality.incident FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: infection_case patient_identity_immutable; Type: TRIGGER; Schema: quality; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON quality.infection_case FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: patient_feedback patient_identity_immutable; Type: TRIGGER; Schema: quality; Owner: hospital_owner
--

CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON quality.patient_feedback FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity();


--
-- Name: code_system audit_change; Type: TRIGGER; Schema: ref; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.code_system FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: concept audit_change; Type: TRIGGER; Schema: ref; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.concept FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: currency audit_change; Type: TRIGGER; Schema: ref; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.currency FOR EACH ROW EXECUTE FUNCTION audit.capture_change('code');


--
-- Name: encounter_type audit_change; Type: TRIGGER; Schema: ref; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.encounter_type FOR EACH ROW EXECUTE FUNCTION audit.capture_change('code');


--
-- Name: medication audit_change; Type: TRIGGER; Schema: ref; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.medication FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: panel_item audit_change; Type: TRIGGER; Schema: ref; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.panel_item FOR EACH ROW EXECUTE FUNCTION audit.capture_change('panel_id', 'test_id');


--
-- Name: route audit_change; Type: TRIGGER; Schema: ref; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.route FOR EACH ROW EXECUTE FUNCTION audit.capture_change('code');


--
-- Name: service audit_change; Type: TRIGGER; Schema: ref; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.service FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: test audit_change; Type: TRIGGER; Schema: ref; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.test FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: test_panel audit_change; Type: TRIGGER; Schema: ref; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.test_panel FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: unit audit_change; Type: TRIGGER; Schema: ref; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.unit FOR EACH ROW EXECUTE FUNCTION audit.capture_change('code');


--
-- Name: appointment appointment_period_copy; Type: TRIGGER; Schema: scheduling; Owner: hospital_owner
--

CREATE TRIGGER appointment_period_copy BEFORE INSERT OR UPDATE ON scheduling.appointment FOR EACH ROW EXECUTE FUNCTION scheduling.guard_appointment_period();


--
-- Name: appointment audit_change; Type: TRIGGER; Schema: scheduling; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON scheduling.appointment FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id');


--
-- Name: appointment_participant audit_change; Type: TRIGGER; Schema: scheduling; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON scheduling.appointment_participant FOR EACH ROW EXECUTE FUNCTION audit.capture_change('appointment_id', 'staff_id');


--
-- Name: schedule audit_change; Type: TRIGGER; Schema: scheduling; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON scheduling.schedule FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: slot audit_change; Type: TRIGGER; Schema: scheduling; Owner: hospital_owner
--

CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON scheduling.slot FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id');


--
-- Name: slot booked_slot_period_guard; Type: TRIGGER; Schema: scheduling; Owner: hospital_owner
--

CREATE TRIGGER booked_slot_period_guard BEFORE UPDATE OF slot_period ON scheduling.slot FOR EACH ROW EXECUTE FUNCTION scheduling.guard_booked_slot();


--
-- Name: slot slot_dates_guard; Type: TRIGGER; Schema: scheduling; Owner: hospital_owner
--

CREATE TRIGGER slot_dates_guard BEFORE INSERT OR UPDATE ON scheduling.slot FOR EACH ROW EXECUTE FUNCTION scheduling.guard_slot();


--
-- Name: admission admission_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.admission
    ADD CONSTRAINT admission_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: admission admission_patient_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.admission
    ADD CONSTRAINT admission_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: bed_stay bed_stay_admission_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.bed_stay
    ADD CONSTRAINT bed_stay_admission_id_patient_id_fkey FOREIGN KEY (admission_id, patient_id) REFERENCES adt.admission(id, patient_id);


--
-- Name: bed_stay bed_stay_bed_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.bed_stay
    ADD CONSTRAINT bed_stay_bed_id_fkey FOREIGN KEY (bed_id) REFERENCES org.bed(id);


--
-- Name: discharge discharge_admission_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.discharge
    ADD CONSTRAINT discharge_admission_id_patient_id_fkey FOREIGN KEY (admission_id, patient_id) REFERENCES adt.admission(id, patient_id);


--
-- Name: discharge discharge_approved_by_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.discharge
    ADD CONSTRAINT discharge_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES org.staff(id);


--
-- Name: discharge discharge_summary_note_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: hospital_owner
--

ALTER TABLE ONLY adt.discharge
    ADD CONSTRAINT discharge_summary_note_id_patient_id_fkey FOREIGN KEY (summary_note_id, patient_id) REFERENCES ehr.clinical_note(id, patient_id);


--
-- Name: access_event access_event_patient_id_fkey; Type: FK CONSTRAINT; Schema: audit; Owner: hospital_owner
--

ALTER TABLE ONLY audit.access_event
    ADD CONSTRAINT access_event_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: claim claim_invoice_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.claim
    ADD CONSTRAINT claim_invoice_id_patient_id_fkey FOREIGN KEY (invoice_id, patient_id) REFERENCES billing.invoice(id, patient_id);


--
-- Name: claim claim_payer_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.claim
    ADD CONSTRAINT claim_payer_id_fkey FOREIGN KEY (payer_id) REFERENCES billing.payer(id);


--
-- Name: coverage coverage_patient_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.coverage
    ADD CONSTRAINT coverage_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: coverage coverage_payer_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.coverage
    ADD CONSTRAINT coverage_payer_id_fkey FOREIGN KEY (payer_id) REFERENCES billing.payer(id);


--
-- Name: invoice invoice_coverage_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.invoice
    ADD CONSTRAINT invoice_coverage_id_patient_id_fkey FOREIGN KEY (coverage_id, patient_id) REFERENCES billing.coverage(id, patient_id);


--
-- Name: invoice invoice_currency_code_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.invoice
    ADD CONSTRAINT invoice_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES ref.currency(code);


--
-- Name: invoice invoice_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.invoice
    ADD CONSTRAINT invoice_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: invoice_line invoice_line_invoice_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.invoice_line
    ADD CONSTRAINT invoice_line_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES billing.invoice(id);


--
-- Name: invoice_line invoice_line_service_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.invoice_line
    ADD CONSTRAINT invoice_line_service_id_fkey FOREIGN KEY (service_id) REFERENCES ref.service(id);


--
-- Name: invoice invoice_patient_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.invoice
    ADD CONSTRAINT invoice_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: invoice invoice_payer_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.invoice
    ADD CONSTRAINT invoice_payer_id_fkey FOREIGN KEY (payer_id) REFERENCES billing.payer(id);


--
-- Name: payment_allocation payment_allocation_invoice_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.payment_allocation
    ADD CONSTRAINT payment_allocation_invoice_id_patient_id_fkey FOREIGN KEY (invoice_id, patient_id) REFERENCES billing.invoice(id, patient_id);


--
-- Name: payment_allocation payment_allocation_payment_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.payment_allocation
    ADD CONSTRAINT payment_allocation_payment_id_patient_id_fkey FOREIGN KEY (payment_id, patient_id) REFERENCES billing.payment(id, patient_id);


--
-- Name: payment payment_currency_code_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.payment
    ADD CONSTRAINT payment_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES ref.currency(code);


--
-- Name: payment payment_patient_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.payment
    ADD CONSTRAINT payment_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: payment payment_payer_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.payment
    ADD CONSTRAINT payment_payer_id_fkey FOREIGN KEY (payer_id) REFERENCES billing.payer(id);


--
-- Name: tariff tariff_currency_code_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.tariff
    ADD CONSTRAINT tariff_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES ref.currency(code);


--
-- Name: tariff tariff_payer_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.tariff
    ADD CONSTRAINT tariff_payer_id_fkey FOREIGN KEY (payer_id) REFERENCES billing.payer(id);


--
-- Name: tariff tariff_service_id_fkey; Type: FK CONSTRAINT; Schema: billing; Owner: hospital_owner
--

ALTER TABLE ONLY billing.tariff
    ADD CONSTRAINT tariff_service_id_fkey FOREIGN KEY (service_id) REFERENCES ref.service(id);


--
-- Name: allergy allergy_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.allergy
    ADD CONSTRAINT allergy_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: allergy allergy_recorded_by_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.allergy
    ADD CONSTRAINT allergy_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES org.staff(id);


--
-- Name: allergy allergy_substance_concept_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.allergy
    ADD CONSTRAINT allergy_substance_concept_id_fkey FOREIGN KEY (substance_concept_id) REFERENCES ref.concept(id);


--
-- Name: care_plan_activity care_plan_activity_assigned_staff_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.care_plan_activity
    ADD CONSTRAINT care_plan_activity_assigned_staff_id_fkey FOREIGN KEY (assigned_staff_id) REFERENCES org.staff(id);


--
-- Name: care_plan_activity care_plan_activity_care_plan_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.care_plan_activity
    ADD CONSTRAINT care_plan_activity_care_plan_id_fkey FOREIGN KEY (care_plan_id) REFERENCES ehr.care_plan(id);


--
-- Name: care_plan_activity care_plan_activity_service_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.care_plan_activity
    ADD CONSTRAINT care_plan_activity_service_id_fkey FOREIGN KEY (service_id) REFERENCES ref.service(id);


--
-- Name: care_plan care_plan_author_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.care_plan
    ADD CONSTRAINT care_plan_author_id_fkey FOREIGN KEY (author_id) REFERENCES org.staff(id);


--
-- Name: care_plan care_plan_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.care_plan
    ADD CONSTRAINT care_plan_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: care_plan care_plan_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.care_plan
    ADD CONSTRAINT care_plan_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: clinical_note clinical_note_author_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.clinical_note
    ADD CONSTRAINT clinical_note_author_id_fkey FOREIGN KEY (author_id) REFERENCES org.staff(id);


--
-- Name: clinical_note clinical_note_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.clinical_note
    ADD CONSTRAINT clinical_note_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: clinical_note clinical_note_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.clinical_note
    ADD CONSTRAINT clinical_note_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: condition condition_concept_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.condition
    ADD CONSTRAINT condition_concept_id_fkey FOREIGN KEY (concept_id) REFERENCES ref.concept(id);


--
-- Name: condition condition_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.condition
    ADD CONSTRAINT condition_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: condition condition_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.condition
    ADD CONSTRAINT condition_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: condition condition_recorded_by_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.condition
    ADD CONSTRAINT condition_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES org.staff(id);


--
-- Name: death_record death_record_cause_concept_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.death_record
    ADD CONSTRAINT death_record_cause_concept_id_fkey FOREIGN KEY (cause_concept_id) REFERENCES ref.concept(id);


--
-- Name: death_record death_record_certified_by_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.death_record
    ADD CONSTRAINT death_record_certified_by_fkey FOREIGN KEY (certified_by) REFERENCES org.staff(id);


--
-- Name: death_record death_record_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.death_record
    ADD CONSTRAINT death_record_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: death_record death_record_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.death_record
    ADD CONSTRAINT death_record_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: document document_author_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.document
    ADD CONSTRAINT document_author_id_fkey FOREIGN KEY (author_id) REFERENCES org.staff(id);


--
-- Name: document document_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.document
    ADD CONSTRAINT document_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: document document_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.document
    ADD CONSTRAINT document_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: encounter encounter_attending_staff_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.encounter
    ADD CONSTRAINT encounter_attending_staff_id_fkey FOREIGN KEY (attending_staff_id) REFERENCES org.staff(id);


--
-- Name: encounter encounter_department_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.encounter
    ADD CONSTRAINT encounter_department_id_fkey FOREIGN KEY (department_id) REFERENCES org.department(id);


--
-- Name: encounter_participant encounter_participant_encounter_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.encounter_participant
    ADD CONSTRAINT encounter_participant_encounter_id_fkey FOREIGN KEY (encounter_id) REFERENCES ehr.encounter(id);


--
-- Name: encounter_participant encounter_participant_staff_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.encounter_participant
    ADD CONSTRAINT encounter_participant_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES org.staff(id);


--
-- Name: encounter encounter_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.encounter
    ADD CONSTRAINT encounter_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: encounter encounter_type_code_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.encounter
    ADD CONSTRAINT encounter_type_code_fkey FOREIGN KEY (type_code) REFERENCES ref.encounter_type(code);


--
-- Name: immunization immunization_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.immunization
    ADD CONSTRAINT immunization_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: immunization immunization_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.immunization
    ADD CONSTRAINT immunization_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: immunization immunization_performer_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.immunization
    ADD CONSTRAINT immunization_performer_id_fkey FOREIGN KEY (performer_id) REFERENCES org.staff(id);


--
-- Name: immunization immunization_vaccine_concept_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.immunization
    ADD CONSTRAINT immunization_vaccine_concept_id_fkey FOREIGN KEY (vaccine_concept_id) REFERENCES ref.concept(id);


--
-- Name: clinical_note note_current_version_fk; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.clinical_note
    ADD CONSTRAINT note_current_version_fk FOREIGN KEY (id, current_version) REFERENCES ehr.note_version(note_id, version) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: note_version note_version_author_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.note_version
    ADD CONSTRAINT note_version_author_id_fkey FOREIGN KEY (author_id) REFERENCES org.staff(id);


--
-- Name: note_version note_version_note_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.note_version
    ADD CONSTRAINT note_version_note_id_fkey FOREIGN KEY (note_id) REFERENCES ehr.clinical_note(id);


--
-- Name: note_version note_version_note_id_supersedes_version_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.note_version
    ADD CONSTRAINT note_version_note_id_supersedes_version_fkey FOREIGN KEY (note_id, supersedes_version) REFERENCES ehr.note_version(note_id, version);


--
-- Name: note_version note_version_signed_by_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.note_version
    ADD CONSTRAINT note_version_signed_by_fkey FOREIGN KEY (signed_by) REFERENCES org.staff(id);


--
-- Name: observation observation_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.observation
    ADD CONSTRAINT observation_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: observation observation_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.observation
    ADD CONSTRAINT observation_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: observation observation_recorded_by_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.observation
    ADD CONSTRAINT observation_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES org.staff(id);


--
-- Name: observation observation_test_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.observation
    ADD CONSTRAINT observation_test_id_fkey FOREIGN KEY (test_id) REFERENCES ref.test(id);


--
-- Name: observation observation_unit_code_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.observation
    ADD CONSTRAINT observation_unit_code_fkey FOREIGN KEY (unit_code) REFERENCES ref.unit(code);


--
-- Name: observation observation_value_concept_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.observation
    ADD CONSTRAINT observation_value_concept_id_fkey FOREIGN KEY (value_concept_id) REFERENCES ref.concept(id);


--
-- Name: procedure procedure_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.procedure
    ADD CONSTRAINT procedure_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: procedure procedure_patient_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.procedure
    ADD CONSTRAINT procedure_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: procedure procedure_performer_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.procedure
    ADD CONSTRAINT procedure_performer_id_fkey FOREIGN KEY (performer_id) REFERENCES org.staff(id);


--
-- Name: procedure procedure_service_id_fkey; Type: FK CONSTRAINT; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ONLY ehr.procedure
    ADD CONSTRAINT procedure_service_id_fkey FOREIGN KEY (service_id) REFERENCES ref.service(id);


--
-- Name: access_grant access_grant_granted_by_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.access_grant
    ADD CONSTRAINT access_grant_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES iam.application_user(id);


--
-- Name: access_grant access_grant_patient_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.access_grant
    ADD CONSTRAINT access_grant_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: access_grant access_grant_user_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.access_grant
    ADD CONSTRAINT access_grant_user_id_fkey FOREIGN KEY (user_id) REFERENCES iam.application_user(id);


--
-- Name: application_user application_user_staff_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.application_user
    ADD CONSTRAINT application_user_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES org.staff(id);


--
-- Name: break_glass break_glass_approved_by_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.break_glass
    ADD CONSTRAINT break_glass_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES iam.application_user(id);


--
-- Name: break_glass break_glass_patient_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.break_glass
    ADD CONSTRAINT break_glass_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: break_glass break_glass_user_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.break_glass
    ADD CONSTRAINT break_glass_user_id_fkey FOREIGN KEY (user_id) REFERENCES iam.application_user(id);


--
-- Name: user_role user_role_role_code_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.user_role
    ADD CONSTRAINT user_role_role_code_fkey FOREIGN KEY (role_code) REFERENCES iam.business_role(code);


--
-- Name: user_role user_role_user_id_fkey; Type: FK CONSTRAINT; Schema: iam; Owner: hospital_owner
--

ALTER TABLE ONLY iam.user_role
    ADD CONSTRAINT user_role_user_id_fkey FOREIGN KEY (user_id) REFERENCES iam.application_user(id);


--
-- Name: imaging_order imaging_order_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.imaging_order
    ADD CONSTRAINT imaging_order_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: imaging_order imaging_order_patient_id_fkey; Type: FK CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.imaging_order
    ADD CONSTRAINT imaging_order_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: imaging_order imaging_order_requested_by_fkey; Type: FK CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.imaging_order
    ADD CONSTRAINT imaging_order_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES org.staff(id);


--
-- Name: imaging_order imaging_order_service_id_fkey; Type: FK CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.imaging_order
    ADD CONSTRAINT imaging_order_service_id_fkey FOREIGN KEY (service_id) REFERENCES ref.service(id);


--
-- Name: series series_study_id_fkey; Type: FK CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.series
    ADD CONSTRAINT series_study_id_fkey FOREIGN KEY (study_id) REFERENCES imaging.study(id);


--
-- Name: study study_device_id_fkey; Type: FK CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.study
    ADD CONSTRAINT study_device_id_fkey FOREIGN KEY (device_id) REFERENCES org.device(id);


--
-- Name: study study_order_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.study
    ADD CONSTRAINT study_order_id_patient_id_fkey FOREIGN KEY (order_id, patient_id) REFERENCES imaging.imaging_order(id, patient_id);


--
-- Name: study study_patient_id_fkey; Type: FK CONSTRAINT; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE ONLY imaging.study
    ADD CONSTRAINT study_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: export_job export_job_requested_by_fkey; Type: FK CONSTRAINT; Schema: integration; Owner: hospital_owner
--

ALTER TABLE ONLY integration.export_job
    ADD CONSTRAINT export_job_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES iam.application_user(id);


--
-- Name: item item_medication_id_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.item
    ADD CONSTRAINT item_medication_id_fkey FOREIGN KEY (medication_id) REFERENCES ref.medication(id);


--
-- Name: item item_unit_code_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.item
    ADD CONSTRAINT item_unit_code_fkey FOREIGN KEY (unit_code) REFERENCES ref.unit(code);


--
-- Name: location location_department_id_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.location
    ADD CONSTRAINT location_department_id_fkey FOREIGN KEY (department_id) REFERENCES org.department(id);


--
-- Name: lot lot_item_id_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.lot
    ADD CONSTRAINT lot_item_id_fkey FOREIGN KEY (item_id) REFERENCES inventory.item(id);


--
-- Name: lot lot_supplier_id_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.lot
    ADD CONSTRAINT lot_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES inventory.supplier(id);


--
-- Name: purchase_order purchase_order_currency_code_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.purchase_order
    ADD CONSTRAINT purchase_order_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES ref.currency(code);


--
-- Name: purchase_order_line purchase_order_line_item_id_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.purchase_order_line
    ADD CONSTRAINT purchase_order_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES inventory.item(id);


--
-- Name: purchase_order_line purchase_order_line_order_id_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.purchase_order_line
    ADD CONSTRAINT purchase_order_line_order_id_fkey FOREIGN KEY (order_id) REFERENCES inventory.purchase_order(id);


--
-- Name: purchase_order purchase_order_supplier_id_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.purchase_order
    ADD CONSTRAINT purchase_order_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES inventory.supplier(id);


--
-- Name: stock_balance stock_balance_location_id_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.stock_balance
    ADD CONSTRAINT stock_balance_location_id_fkey FOREIGN KEY (location_id) REFERENCES inventory.location(id);


--
-- Name: stock_balance stock_balance_lot_id_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.stock_balance
    ADD CONSTRAINT stock_balance_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES inventory.lot(id);


--
-- Name: stock_movement stock_movement_dispense_id_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.stock_movement
    ADD CONSTRAINT stock_movement_dispense_id_fkey FOREIGN KEY (dispense_id) REFERENCES pharmacy.dispense(id);


--
-- Name: stock_movement stock_movement_location_id_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.stock_movement
    ADD CONSTRAINT stock_movement_location_id_fkey FOREIGN KEY (location_id) REFERENCES inventory.location(id);


--
-- Name: stock_movement stock_movement_lot_id_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.stock_movement
    ADD CONSTRAINT stock_movement_lot_id_fkey FOREIGN KEY (lot_id) REFERENCES inventory.lot(id);


--
-- Name: stock_movement stock_movement_recorded_by_fkey; Type: FK CONSTRAINT; Schema: inventory; Owner: hospital_owner
--

ALTER TABLE ONLY inventory.stock_movement
    ADD CONSTRAINT stock_movement_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES org.staff(id);


--
-- Name: diagnostic_report diagnostic_report_patient_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.diagnostic_report
    ADD CONSTRAINT diagnostic_report_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: diagnostic_report diagnostic_report_request_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.diagnostic_report
    ADD CONSTRAINT diagnostic_report_request_id_patient_id_fkey FOREIGN KEY (request_id, patient_id) REFERENCES lab.service_request(id, patient_id);


--
-- Name: diagnostic_report diagnostic_report_verified_by_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.diagnostic_report
    ADD CONSTRAINT diagnostic_report_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES org.staff(id);


--
-- Name: report_result report_result_report_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.report_result
    ADD CONSTRAINT report_result_report_id_patient_id_fkey FOREIGN KEY (report_id, patient_id) REFERENCES lab.diagnostic_report(id, patient_id);


--
-- Name: report_result report_result_result_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.report_result
    ADD CONSTRAINT report_result_result_id_patient_id_fkey FOREIGN KEY (result_id, patient_id) REFERENCES lab.result(id, patient_id);


--
-- Name: request_specimen request_specimen_request_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.request_specimen
    ADD CONSTRAINT request_specimen_request_id_patient_id_fkey FOREIGN KEY (request_id, patient_id) REFERENCES lab.service_request(id, patient_id);


--
-- Name: request_specimen request_specimen_specimen_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.request_specimen
    ADD CONSTRAINT request_specimen_specimen_id_patient_id_fkey FOREIGN KEY (specimen_id, patient_id) REFERENCES lab.specimen(id, patient_id);


--
-- Name: result result_analyzer_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.result
    ADD CONSTRAINT result_analyzer_id_fkey FOREIGN KEY (analyzer_id) REFERENCES org.device(id);


--
-- Name: result result_patient_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.result
    ADD CONSTRAINT result_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: result result_specimen_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.result
    ADD CONSTRAINT result_specimen_id_patient_id_fkey FOREIGN KEY (specimen_id, patient_id) REFERENCES lab.specimen(id, patient_id);


--
-- Name: result result_test_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.result
    ADD CONSTRAINT result_test_id_fkey FOREIGN KEY (test_id) REFERENCES ref.test(id);


--
-- Name: result result_unit_code_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.result
    ADD CONSTRAINT result_unit_code_fkey FOREIGN KEY (unit_code) REFERENCES ref.unit(code);


--
-- Name: service_request service_request_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.service_request
    ADD CONSTRAINT service_request_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: service_request service_request_ordered_by_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.service_request
    ADD CONSTRAINT service_request_ordered_by_fkey FOREIGN KEY (ordered_by) REFERENCES org.staff(id);


--
-- Name: service_request service_request_panel_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.service_request
    ADD CONSTRAINT service_request_panel_id_fkey FOREIGN KEY (panel_id) REFERENCES ref.test_panel(id);


--
-- Name: service_request service_request_patient_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.service_request
    ADD CONSTRAINT service_request_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: service_request service_request_service_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.service_request
    ADD CONSTRAINT service_request_service_id_fkey FOREIGN KEY (service_id) REFERENCES ref.service(id);


--
-- Name: specimen specimen_collected_by_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.specimen
    ADD CONSTRAINT specimen_collected_by_fkey FOREIGN KEY (collected_by) REFERENCES org.staff(id);


--
-- Name: specimen specimen_patient_id_fkey; Type: FK CONSTRAINT; Schema: lab; Owner: hospital_owner
--

ALTER TABLE ONLY lab.specimen
    ADD CONSTRAINT specimen_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: address address_patient_id_fkey; Type: FK CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.address
    ADD CONSTRAINT address_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: consent consent_patient_id_fkey; Type: FK CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.consent
    ADD CONSTRAINT consent_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: consent consent_recorded_by_fkey; Type: FK CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.consent
    ADD CONSTRAINT consent_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES org.staff(id);


--
-- Name: contact contact_patient_id_fkey; Type: FK CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.contact
    ADD CONSTRAINT contact_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: identifier identifier_patient_id_fkey; Type: FK CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.identifier
    ADD CONSTRAINT identifier_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: merge_history merge_history_merged_by_fkey; Type: FK CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.merge_history
    ADD CONSTRAINT merge_history_merged_by_fkey FOREIGN KEY (merged_by) REFERENCES org.staff(id);


--
-- Name: merge_history merge_history_source_patient_id_fkey; Type: FK CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.merge_history
    ADD CONSTRAINT merge_history_source_patient_id_fkey FOREIGN KEY (source_patient_id) REFERENCES mpi.patient(id);


--
-- Name: merge_history merge_history_target_patient_id_fkey; Type: FK CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.merge_history
    ADD CONSTRAINT merge_history_target_patient_id_fkey FOREIGN KEY (target_patient_id) REFERENCES mpi.patient(id);


--
-- Name: related_person related_person_patient_id_fkey; Type: FK CONSTRAINT; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE ONLY mpi.related_person
    ADD CONSTRAINT related_person_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: bed bed_room_id_fkey; Type: FK CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.bed
    ADD CONSTRAINT bed_room_id_fkey FOREIGN KEY (room_id) REFERENCES org.room(id);


--
-- Name: credential credential_staff_id_fkey; Type: FK CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.credential
    ADD CONSTRAINT credential_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES org.staff(id);


--
-- Name: department department_site_id_fkey; Type: FK CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.department
    ADD CONSTRAINT department_site_id_fkey FOREIGN KEY (site_id) REFERENCES org.site(id);


--
-- Name: device device_department_id_fkey; Type: FK CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.device
    ADD CONSTRAINT device_department_id_fkey FOREIGN KEY (department_id) REFERENCES org.department(id);


--
-- Name: room room_department_id_fkey; Type: FK CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.room
    ADD CONSTRAINT room_department_id_fkey FOREIGN KEY (department_id) REFERENCES org.department(id);


--
-- Name: site site_organization_id_fkey; Type: FK CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.site
    ADD CONSTRAINT site_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES org.organization(id);


--
-- Name: staff_department staff_department_department_id_fkey; Type: FK CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.staff_department
    ADD CONSTRAINT staff_department_department_id_fkey FOREIGN KEY (department_id) REFERENCES org.department(id);


--
-- Name: staff_department staff_department_staff_id_fkey; Type: FK CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.staff_department
    ADD CONSTRAINT staff_department_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES org.staff(id);


--
-- Name: staff staff_specialty_concept_id_fkey; Type: FK CONSTRAINT; Schema: org; Owner: hospital_owner
--

ALTER TABLE ONLY org.staff
    ADD CONSTRAINT staff_specialty_concept_id_fkey FOREIGN KEY (specialty_concept_id) REFERENCES ref.concept(id);


--
-- Name: administration administration_dispense_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.administration
    ADD CONSTRAINT administration_dispense_id_patient_id_fkey FOREIGN KEY (dispense_id, patient_id) REFERENCES pharmacy.dispense(id, patient_id);


--
-- Name: administration administration_order_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.administration
    ADD CONSTRAINT administration_order_id_patient_id_fkey FOREIGN KEY (order_id, patient_id) REFERENCES pharmacy.medication_order(id, patient_id);


--
-- Name: administration administration_performed_by_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.administration
    ADD CONSTRAINT administration_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES org.staff(id);


--
-- Name: administration administration_unit_code_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.administration
    ADD CONSTRAINT administration_unit_code_fkey FOREIGN KEY (unit_code) REFERENCES ref.unit(code);


--
-- Name: dispense dispense_dispensed_by_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.dispense
    ADD CONSTRAINT dispense_dispensed_by_fkey FOREIGN KEY (dispensed_by) REFERENCES org.staff(id);


--
-- Name: dispense dispense_location_id_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.dispense
    ADD CONSTRAINT dispense_location_id_fkey FOREIGN KEY (location_id) REFERENCES inventory.location(id);


--
-- Name: dispense dispense_lot_id_item_id_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.dispense
    ADD CONSTRAINT dispense_lot_id_item_id_fkey FOREIGN KEY (lot_id, item_id) REFERENCES inventory.lot(id, item_id);


--
-- Name: dispense dispense_order_id_patient_id_medication_id_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.dispense
    ADD CONSTRAINT dispense_order_id_patient_id_medication_id_fkey FOREIGN KEY (order_id, patient_id, medication_id) REFERENCES pharmacy.medication_order(id, patient_id, medication_id);


--
-- Name: medication_order medication_order_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.medication_order
    ADD CONSTRAINT medication_order_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: medication_order medication_order_medication_id_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.medication_order
    ADD CONSTRAINT medication_order_medication_id_fkey FOREIGN KEY (medication_id) REFERENCES ref.medication(id);


--
-- Name: medication_order medication_order_ordered_by_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.medication_order
    ADD CONSTRAINT medication_order_ordered_by_fkey FOREIGN KEY (ordered_by) REFERENCES org.staff(id);


--
-- Name: medication_order medication_order_patient_id_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.medication_order
    ADD CONSTRAINT medication_order_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: medication_order medication_order_route_code_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.medication_order
    ADD CONSTRAINT medication_order_route_code_fkey FOREIGN KEY (route_code) REFERENCES ref.route(code);


--
-- Name: medication_reconciliation medication_reconciliation_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.medication_reconciliation
    ADD CONSTRAINT medication_reconciliation_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: medication_reconciliation medication_reconciliation_patient_id_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.medication_reconciliation
    ADD CONSTRAINT medication_reconciliation_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: medication_reconciliation medication_reconciliation_reconciled_by_fkey; Type: FK CONSTRAINT; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE ONLY pharmacy.medication_reconciliation
    ADD CONSTRAINT medication_reconciliation_reconciled_by_fkey FOREIGN KEY (reconciled_by) REFERENCES org.staff(id);


--
-- Name: incident incident_department_id_fkey; Type: FK CONSTRAINT; Schema: quality; Owner: hospital_owner
--

ALTER TABLE ONLY quality.incident
    ADD CONSTRAINT incident_department_id_fkey FOREIGN KEY (department_id) REFERENCES org.department(id);


--
-- Name: incident incident_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: quality; Owner: hospital_owner
--

ALTER TABLE ONLY quality.incident
    ADD CONSTRAINT incident_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: incident incident_patient_id_fkey; Type: FK CONSTRAINT; Schema: quality; Owner: hospital_owner
--

ALTER TABLE ONLY quality.incident
    ADD CONSTRAINT incident_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: incident incident_reported_by_fkey; Type: FK CONSTRAINT; Schema: quality; Owner: hospital_owner
--

ALTER TABLE ONLY quality.incident
    ADD CONSTRAINT incident_reported_by_fkey FOREIGN KEY (reported_by) REFERENCES org.staff(id);


--
-- Name: infection_case infection_case_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: quality; Owner: hospital_owner
--

ALTER TABLE ONLY quality.infection_case
    ADD CONSTRAINT infection_case_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: infection_case infection_case_organism_concept_id_fkey; Type: FK CONSTRAINT; Schema: quality; Owner: hospital_owner
--

ALTER TABLE ONLY quality.infection_case
    ADD CONSTRAINT infection_case_organism_concept_id_fkey FOREIGN KEY (organism_concept_id) REFERENCES ref.concept(id);


--
-- Name: infection_case infection_case_patient_id_fkey; Type: FK CONSTRAINT; Schema: quality; Owner: hospital_owner
--

ALTER TABLE ONLY quality.infection_case
    ADD CONSTRAINT infection_case_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: infection_case infection_case_reported_by_fkey; Type: FK CONSTRAINT; Schema: quality; Owner: hospital_owner
--

ALTER TABLE ONLY quality.infection_case
    ADD CONSTRAINT infection_case_reported_by_fkey FOREIGN KEY (reported_by) REFERENCES org.staff(id);


--
-- Name: patient_feedback patient_feedback_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: quality; Owner: hospital_owner
--

ALTER TABLE ONLY quality.patient_feedback
    ADD CONSTRAINT patient_feedback_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: patient_feedback patient_feedback_patient_id_fkey; Type: FK CONSTRAINT; Schema: quality; Owner: hospital_owner
--

ALTER TABLE ONLY quality.patient_feedback
    ADD CONSTRAINT patient_feedback_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: concept concept_system_id_fkey; Type: FK CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.concept
    ADD CONSTRAINT concept_system_id_fkey FOREIGN KEY (system_id) REFERENCES ref.code_system(id);


--
-- Name: medication medication_unit_code_fkey; Type: FK CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.medication
    ADD CONSTRAINT medication_unit_code_fkey FOREIGN KEY (unit_code) REFERENCES ref.unit(code);


--
-- Name: panel_item panel_item_panel_id_fkey; Type: FK CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.panel_item
    ADD CONSTRAINT panel_item_panel_id_fkey FOREIGN KEY (panel_id) REFERENCES ref.test_panel(id);


--
-- Name: panel_item panel_item_test_id_fkey; Type: FK CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.panel_item
    ADD CONSTRAINT panel_item_test_id_fkey FOREIGN KEY (test_id) REFERENCES ref.test(id);


--
-- Name: test test_unit_code_fkey; Type: FK CONSTRAINT; Schema: ref; Owner: hospital_owner
--

ALTER TABLE ONLY ref.test
    ADD CONSTRAINT test_unit_code_fkey FOREIGN KEY (unit_code) REFERENCES ref.unit(code);


--
-- Name: appointment appointment_encounter_id_patient_id_fkey; Type: FK CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.appointment
    ADD CONSTRAINT appointment_encounter_id_patient_id_fkey FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id);


--
-- Name: appointment_participant appointment_participant_appointment_id_fkey; Type: FK CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.appointment_participant
    ADD CONSTRAINT appointment_participant_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES scheduling.appointment(id);


--
-- Name: appointment_participant appointment_participant_staff_id_fkey; Type: FK CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.appointment_participant
    ADD CONSTRAINT appointment_participant_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES org.staff(id);


--
-- Name: appointment appointment_patient_id_fkey; Type: FK CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.appointment
    ADD CONSTRAINT appointment_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES mpi.patient(id);


--
-- Name: appointment appointment_service_id_fkey; Type: FK CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.appointment
    ADD CONSTRAINT appointment_service_id_fkey FOREIGN KEY (service_id) REFERENCES ref.service(id);


--
-- Name: appointment appointment_slot_id_fkey; Type: FK CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.appointment
    ADD CONSTRAINT appointment_slot_id_fkey FOREIGN KEY (slot_id) REFERENCES scheduling.slot(id);


--
-- Name: schedule schedule_department_id_fkey; Type: FK CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.schedule
    ADD CONSTRAINT schedule_department_id_fkey FOREIGN KEY (department_id) REFERENCES org.department(id);


--
-- Name: schedule schedule_staff_id_fkey; Type: FK CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.schedule
    ADD CONSTRAINT schedule_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES org.staff(id);


--
-- Name: slot slot_room_id_department_id_fkey; Type: FK CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.slot
    ADD CONSTRAINT slot_room_id_department_id_fkey FOREIGN KEY (room_id, department_id) REFERENCES org.room(id, department_id);


--
-- Name: slot slot_schedule_id_staff_id_department_id_fkey; Type: FK CONSTRAINT; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE ONLY scheduling.slot
    ADD CONSTRAINT slot_schedule_id_staff_id_department_id_fkey FOREIGN KEY (schedule_id, staff_id, department_id) REFERENCES scheduling.schedule(id, staff_id, department_id);


--
-- Name: admission; Type: ROW SECURITY; Schema: adt; Owner: hospital_owner
--

ALTER TABLE adt.admission ENABLE ROW LEVEL SECURITY;

--
-- Name: bed_stay; Type: ROW SECURITY; Schema: adt; Owner: hospital_owner
--

ALTER TABLE adt.bed_stay ENABLE ROW LEVEL SECURITY;

--
-- Name: admission clinician_access; Type: POLICY; Schema: adt; Owner: hospital_owner
--

CREATE POLICY clinician_access ON adt.admission TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: bed_stay clinician_access; Type: POLICY; Schema: adt; Owner: hospital_owner
--

CREATE POLICY clinician_access ON adt.bed_stay TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: discharge clinician_access; Type: POLICY; Schema: adt; Owner: hospital_owner
--

CREATE POLICY clinician_access ON adt.discharge TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: discharge; Type: ROW SECURITY; Schema: adt; Owner: hospital_owner
--

ALTER TABLE adt.discharge ENABLE ROW LEVEL SECURITY;

--
-- Name: admission owner_access; Type: POLICY; Schema: adt; Owner: hospital_owner
--

CREATE POLICY owner_access ON adt.admission TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: bed_stay owner_access; Type: POLICY; Schema: adt; Owner: hospital_owner
--

CREATE POLICY owner_access ON adt.bed_stay TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: discharge owner_access; Type: POLICY; Schema: adt; Owner: hospital_owner
--

CREATE POLICY owner_access ON adt.discharge TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: access_event; Type: ROW SECURITY; Schema: audit; Owner: hospital_owner
--

ALTER TABLE audit.access_event ENABLE ROW LEVEL SECURITY;

--
-- Name: access_event auditor_access; Type: POLICY; Schema: audit; Owner: hospital_owner
--

CREATE POLICY auditor_access ON audit.access_event TO hospital_auditor USING (true);


--
-- Name: access_event owner_access; Type: POLICY; Schema: audit; Owner: hospital_owner
--

CREATE POLICY owner_access ON audit.access_event TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: claim billing_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY billing_access ON billing.claim TO hospital_billing USING (iam.has_patient_access(patient_id, 'billing'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'billing'::text));


--
-- Name: coverage billing_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY billing_access ON billing.coverage TO hospital_billing USING (iam.has_patient_access(patient_id, 'billing'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'billing'::text));


--
-- Name: invoice billing_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY billing_access ON billing.invoice TO hospital_billing USING (iam.has_patient_access(patient_id, 'billing'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'billing'::text));


--
-- Name: invoice_line billing_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY billing_access ON billing.invoice_line TO hospital_billing USING ((EXISTS ( SELECT
   FROM billing.invoice i
  WHERE (i.id = invoice_line.invoice_id))));


--
-- Name: payment billing_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY billing_access ON billing.payment TO hospital_billing USING (iam.has_patient_access(patient_id, 'billing'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'billing'::text));


--
-- Name: payment_allocation billing_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY billing_access ON billing.payment_allocation TO hospital_billing USING (iam.has_patient_access(patient_id, 'billing'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'billing'::text));


--
-- Name: claim; Type: ROW SECURITY; Schema: billing; Owner: hospital_owner
--

ALTER TABLE billing.claim ENABLE ROW LEVEL SECURITY;

--
-- Name: claim clinician_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY clinician_access ON billing.claim TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: coverage clinician_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY clinician_access ON billing.coverage TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: invoice clinician_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY clinician_access ON billing.invoice TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: payment clinician_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY clinician_access ON billing.payment TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: payment_allocation clinician_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY clinician_access ON billing.payment_allocation TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: coverage; Type: ROW SECURITY; Schema: billing; Owner: hospital_owner
--

ALTER TABLE billing.coverage ENABLE ROW LEVEL SECURITY;

--
-- Name: invoice; Type: ROW SECURITY; Schema: billing; Owner: hospital_owner
--

ALTER TABLE billing.invoice ENABLE ROW LEVEL SECURITY;

--
-- Name: invoice_line; Type: ROW SECURITY; Schema: billing; Owner: hospital_owner
--

ALTER TABLE billing.invoice_line ENABLE ROW LEVEL SECURITY;

--
-- Name: claim owner_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY owner_access ON billing.claim TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: coverage owner_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY owner_access ON billing.coverage TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: invoice owner_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY owner_access ON billing.invoice TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: invoice_line owner_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY owner_access ON billing.invoice_line TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: payment owner_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY owner_access ON billing.payment TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: payment_allocation owner_access; Type: POLICY; Schema: billing; Owner: hospital_owner
--

CREATE POLICY owner_access ON billing.payment_allocation TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: payment; Type: ROW SECURITY; Schema: billing; Owner: hospital_owner
--

ALTER TABLE billing.payment ENABLE ROW LEVEL SECURITY;

--
-- Name: payment_allocation; Type: ROW SECURITY; Schema: billing; Owner: hospital_owner
--

ALTER TABLE billing.payment_allocation ENABLE ROW LEVEL SECURITY;

--
-- Name: allergy; Type: ROW SECURITY; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.allergy ENABLE ROW LEVEL SECURITY;

--
-- Name: care_plan; Type: ROW SECURITY; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.care_plan ENABLE ROW LEVEL SECURITY;

--
-- Name: care_plan_activity; Type: ROW SECURITY; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.care_plan_activity ENABLE ROW LEVEL SECURITY;

--
-- Name: clinical_note; Type: ROW SECURITY; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.clinical_note ENABLE ROW LEVEL SECURITY;

--
-- Name: allergy clinician_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY clinician_access ON ehr.allergy TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: care_plan clinician_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY clinician_access ON ehr.care_plan TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: care_plan_activity clinician_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY clinician_access ON ehr.care_plan_activity TO hospital_clinician USING ((EXISTS ( SELECT
   FROM ehr.care_plan p
  WHERE (p.id = care_plan_activity.care_plan_id))));


--
-- Name: clinical_note clinician_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY clinician_access ON ehr.clinical_note TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: condition clinician_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY clinician_access ON ehr.condition TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: death_record clinician_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY clinician_access ON ehr.death_record TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: document clinician_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY clinician_access ON ehr.document TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: encounter clinician_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY clinician_access ON ehr.encounter TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: encounter_participant clinician_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY clinician_access ON ehr.encounter_participant TO hospital_clinician USING ((EXISTS ( SELECT
   FROM ehr.encounter e
  WHERE (e.id = encounter_participant.encounter_id))));


--
-- Name: immunization clinician_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY clinician_access ON ehr.immunization TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: note_version clinician_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY clinician_access ON ehr.note_version TO hospital_clinician USING ((EXISTS ( SELECT
   FROM ehr.clinical_note n
  WHERE (n.id = note_version.note_id)))) WITH CHECK ((EXISTS ( SELECT
   FROM ehr.clinical_note n
  WHERE (n.id = note_version.note_id))));


--
-- Name: observation clinician_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY clinician_access ON ehr.observation TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: procedure clinician_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY clinician_access ON ehr.procedure TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: condition; Type: ROW SECURITY; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.condition ENABLE ROW LEVEL SECURITY;

--
-- Name: death_record; Type: ROW SECURITY; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.death_record ENABLE ROW LEVEL SECURITY;

--
-- Name: document; Type: ROW SECURITY; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.document ENABLE ROW LEVEL SECURITY;

--
-- Name: encounter; Type: ROW SECURITY; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.encounter ENABLE ROW LEVEL SECURITY;

--
-- Name: encounter_participant; Type: ROW SECURITY; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.encounter_participant ENABLE ROW LEVEL SECURITY;

--
-- Name: immunization; Type: ROW SECURITY; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.immunization ENABLE ROW LEVEL SECURITY;

--
-- Name: note_version; Type: ROW SECURITY; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.note_version ENABLE ROW LEVEL SECURITY;

--
-- Name: observation; Type: ROW SECURITY; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.observation ENABLE ROW LEVEL SECURITY;

--
-- Name: allergy owner_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY owner_access ON ehr.allergy TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: care_plan owner_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY owner_access ON ehr.care_plan TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: care_plan_activity owner_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY owner_access ON ehr.care_plan_activity TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: clinical_note owner_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY owner_access ON ehr.clinical_note TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: condition owner_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY owner_access ON ehr.condition TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: death_record owner_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY owner_access ON ehr.death_record TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: document owner_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY owner_access ON ehr.document TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: encounter owner_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY owner_access ON ehr.encounter TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: encounter_participant owner_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY owner_access ON ehr.encounter_participant TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: immunization owner_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY owner_access ON ehr.immunization TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: note_version owner_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY owner_access ON ehr.note_version TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: observation owner_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY owner_access ON ehr.observation TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: procedure owner_access; Type: POLICY; Schema: ehr; Owner: hospital_owner
--

CREATE POLICY owner_access ON ehr.procedure TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: procedure; Type: ROW SECURITY; Schema: ehr; Owner: hospital_owner
--

ALTER TABLE ehr.procedure ENABLE ROW LEVEL SECURITY;

--
-- Name: access_grant; Type: ROW SECURITY; Schema: iam; Owner: hospital_owner
--

ALTER TABLE iam.access_grant ENABLE ROW LEVEL SECURITY;

--
-- Name: break_glass; Type: ROW SECURITY; Schema: iam; Owner: hospital_owner
--

ALTER TABLE iam.break_glass ENABLE ROW LEVEL SECURITY;

--
-- Name: access_grant owner_access; Type: POLICY; Schema: iam; Owner: hospital_owner
--

CREATE POLICY owner_access ON iam.access_grant TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: break_glass owner_access; Type: POLICY; Schema: iam; Owner: hospital_owner
--

CREATE POLICY owner_access ON iam.break_glass TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: imaging_order clinician_access; Type: POLICY; Schema: imaging; Owner: hospital_owner
--

CREATE POLICY clinician_access ON imaging.imaging_order TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: series clinician_access; Type: POLICY; Schema: imaging; Owner: hospital_owner
--

CREATE POLICY clinician_access ON imaging.series TO hospital_clinician USING ((EXISTS ( SELECT
   FROM imaging.study s
  WHERE (s.id = series.study_id))));


--
-- Name: study clinician_access; Type: POLICY; Schema: imaging; Owner: hospital_owner
--

CREATE POLICY clinician_access ON imaging.study TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: imaging_order; Type: ROW SECURITY; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE imaging.imaging_order ENABLE ROW LEVEL SECURITY;

--
-- Name: imaging_order owner_access; Type: POLICY; Schema: imaging; Owner: hospital_owner
--

CREATE POLICY owner_access ON imaging.imaging_order TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: series owner_access; Type: POLICY; Schema: imaging; Owner: hospital_owner
--

CREATE POLICY owner_access ON imaging.series TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: study owner_access; Type: POLICY; Schema: imaging; Owner: hospital_owner
--

CREATE POLICY owner_access ON imaging.study TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: series; Type: ROW SECURITY; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE imaging.series ENABLE ROW LEVEL SECURITY;

--
-- Name: study; Type: ROW SECURITY; Schema: imaging; Owner: hospital_owner
--

ALTER TABLE imaging.study ENABLE ROW LEVEL SECURITY;

--
-- Name: diagnostic_report clinician_access; Type: POLICY; Schema: lab; Owner: hospital_owner
--

CREATE POLICY clinician_access ON lab.diagnostic_report TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: report_result clinician_access; Type: POLICY; Schema: lab; Owner: hospital_owner
--

CREATE POLICY clinician_access ON lab.report_result TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: request_specimen clinician_access; Type: POLICY; Schema: lab; Owner: hospital_owner
--

CREATE POLICY clinician_access ON lab.request_specimen TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: result clinician_access; Type: POLICY; Schema: lab; Owner: hospital_owner
--

CREATE POLICY clinician_access ON lab.result TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: service_request clinician_access; Type: POLICY; Schema: lab; Owner: hospital_owner
--

CREATE POLICY clinician_access ON lab.service_request TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: specimen clinician_access; Type: POLICY; Schema: lab; Owner: hospital_owner
--

CREATE POLICY clinician_access ON lab.specimen TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: diagnostic_report; Type: ROW SECURITY; Schema: lab; Owner: hospital_owner
--

ALTER TABLE lab.diagnostic_report ENABLE ROW LEVEL SECURITY;

--
-- Name: diagnostic_report owner_access; Type: POLICY; Schema: lab; Owner: hospital_owner
--

CREATE POLICY owner_access ON lab.diagnostic_report TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: report_result owner_access; Type: POLICY; Schema: lab; Owner: hospital_owner
--

CREATE POLICY owner_access ON lab.report_result TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: request_specimen owner_access; Type: POLICY; Schema: lab; Owner: hospital_owner
--

CREATE POLICY owner_access ON lab.request_specimen TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: result owner_access; Type: POLICY; Schema: lab; Owner: hospital_owner
--

CREATE POLICY owner_access ON lab.result TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: service_request owner_access; Type: POLICY; Schema: lab; Owner: hospital_owner
--

CREATE POLICY owner_access ON lab.service_request TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: specimen owner_access; Type: POLICY; Schema: lab; Owner: hospital_owner
--

CREATE POLICY owner_access ON lab.specimen TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: report_result; Type: ROW SECURITY; Schema: lab; Owner: hospital_owner
--

ALTER TABLE lab.report_result ENABLE ROW LEVEL SECURITY;

--
-- Name: request_specimen; Type: ROW SECURITY; Schema: lab; Owner: hospital_owner
--

ALTER TABLE lab.request_specimen ENABLE ROW LEVEL SECURITY;

--
-- Name: result; Type: ROW SECURITY; Schema: lab; Owner: hospital_owner
--

ALTER TABLE lab.result ENABLE ROW LEVEL SECURITY;

--
-- Name: service_request; Type: ROW SECURITY; Schema: lab; Owner: hospital_owner
--

ALTER TABLE lab.service_request ENABLE ROW LEVEL SECURITY;

--
-- Name: specimen; Type: ROW SECURITY; Schema: lab; Owner: hospital_owner
--

ALTER TABLE lab.specimen ENABLE ROW LEVEL SECURITY;

--
-- Name: address; Type: ROW SECURITY; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE mpi.address ENABLE ROW LEVEL SECURITY;

--
-- Name: address clinician_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY clinician_access ON mpi.address TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: consent clinician_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY clinician_access ON mpi.consent TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: contact clinician_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY clinician_access ON mpi.contact TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: identifier clinician_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY clinician_access ON mpi.identifier TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: merge_history clinician_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY clinician_access ON mpi.merge_history TO hospital_clinician USING ((iam.has_patient_access(source_patient_id, 'treatment'::text) AND iam.has_patient_access(target_patient_id, 'treatment'::text)));


--
-- Name: patient clinician_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY clinician_access ON mpi.patient TO hospital_clinician USING (iam.has_patient_access(id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(id, 'treatment'::text));


--
-- Name: related_person clinician_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY clinician_access ON mpi.related_person TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: consent; Type: ROW SECURITY; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE mpi.consent ENABLE ROW LEVEL SECURITY;

--
-- Name: contact; Type: ROW SECURITY; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE mpi.contact ENABLE ROW LEVEL SECURITY;

--
-- Name: identifier; Type: ROW SECURITY; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE mpi.identifier ENABLE ROW LEVEL SECURITY;

--
-- Name: merge_history; Type: ROW SECURITY; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE mpi.merge_history ENABLE ROW LEVEL SECURITY;

--
-- Name: address owner_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY owner_access ON mpi.address TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: consent owner_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY owner_access ON mpi.consent TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: contact owner_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY owner_access ON mpi.contact TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: identifier owner_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY owner_access ON mpi.identifier TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: merge_history owner_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY owner_access ON mpi.merge_history TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: patient owner_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY owner_access ON mpi.patient TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: related_person owner_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY owner_access ON mpi.related_person TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: patient; Type: ROW SECURITY; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE mpi.patient ENABLE ROW LEVEL SECURITY;

--
-- Name: address registrar_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY registrar_access ON mpi.address TO hospital_registrar USING (iam.has_patient_access(patient_id, 'registration'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'registration'::text));


--
-- Name: consent registrar_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY registrar_access ON mpi.consent TO hospital_registrar USING (iam.has_patient_access(patient_id, 'registration'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'registration'::text));


--
-- Name: contact registrar_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY registrar_access ON mpi.contact TO hospital_registrar USING (iam.has_patient_access(patient_id, 'registration'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'registration'::text));


--
-- Name: identifier registrar_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY registrar_access ON mpi.identifier TO hospital_registrar USING (iam.has_patient_access(patient_id, 'registration'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'registration'::text));


--
-- Name: merge_history registrar_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY registrar_access ON mpi.merge_history TO hospital_registrar USING ((iam.has_patient_access(source_patient_id, 'registration'::text) AND iam.has_patient_access(target_patient_id, 'registration'::text)));


--
-- Name: patient registrar_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY registrar_access ON mpi.patient TO hospital_registrar USING (iam.has_patient_access(id, 'registration'::text)) WITH CHECK (iam.has_patient_access(id, 'registration'::text));


--
-- Name: related_person registrar_access; Type: POLICY; Schema: mpi; Owner: hospital_owner
--

CREATE POLICY registrar_access ON mpi.related_person TO hospital_registrar USING (iam.has_patient_access(patient_id, 'registration'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'registration'::text));


--
-- Name: related_person; Type: ROW SECURITY; Schema: mpi; Owner: hospital_owner
--

ALTER TABLE mpi.related_person ENABLE ROW LEVEL SECURITY;

--
-- Name: administration; Type: ROW SECURITY; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE pharmacy.administration ENABLE ROW LEVEL SECURITY;

--
-- Name: administration clinician_access; Type: POLICY; Schema: pharmacy; Owner: hospital_owner
--

CREATE POLICY clinician_access ON pharmacy.administration TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: dispense clinician_access; Type: POLICY; Schema: pharmacy; Owner: hospital_owner
--

CREATE POLICY clinician_access ON pharmacy.dispense TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: medication_order clinician_access; Type: POLICY; Schema: pharmacy; Owner: hospital_owner
--

CREATE POLICY clinician_access ON pharmacy.medication_order TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: medication_reconciliation clinician_access; Type: POLICY; Schema: pharmacy; Owner: hospital_owner
--

CREATE POLICY clinician_access ON pharmacy.medication_reconciliation TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: dispense; Type: ROW SECURITY; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE pharmacy.dispense ENABLE ROW LEVEL SECURITY;

--
-- Name: medication_order; Type: ROW SECURITY; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE pharmacy.medication_order ENABLE ROW LEVEL SECURITY;

--
-- Name: medication_reconciliation; Type: ROW SECURITY; Schema: pharmacy; Owner: hospital_owner
--

ALTER TABLE pharmacy.medication_reconciliation ENABLE ROW LEVEL SECURITY;

--
-- Name: administration owner_access; Type: POLICY; Schema: pharmacy; Owner: hospital_owner
--

CREATE POLICY owner_access ON pharmacy.administration TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: dispense owner_access; Type: POLICY; Schema: pharmacy; Owner: hospital_owner
--

CREATE POLICY owner_access ON pharmacy.dispense TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: medication_order owner_access; Type: POLICY; Schema: pharmacy; Owner: hospital_owner
--

CREATE POLICY owner_access ON pharmacy.medication_order TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: medication_reconciliation owner_access; Type: POLICY; Schema: pharmacy; Owner: hospital_owner
--

CREATE POLICY owner_access ON pharmacy.medication_reconciliation TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: incident clinician_access; Type: POLICY; Schema: quality; Owner: hospital_owner
--

CREATE POLICY clinician_access ON quality.incident TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: infection_case clinician_access; Type: POLICY; Schema: quality; Owner: hospital_owner
--

CREATE POLICY clinician_access ON quality.infection_case TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: patient_feedback clinician_access; Type: POLICY; Schema: quality; Owner: hospital_owner
--

CREATE POLICY clinician_access ON quality.patient_feedback TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: incident; Type: ROW SECURITY; Schema: quality; Owner: hospital_owner
--

ALTER TABLE quality.incident ENABLE ROW LEVEL SECURITY;

--
-- Name: infection_case; Type: ROW SECURITY; Schema: quality; Owner: hospital_owner
--

ALTER TABLE quality.infection_case ENABLE ROW LEVEL SECURITY;

--
-- Name: incident owner_access; Type: POLICY; Schema: quality; Owner: hospital_owner
--

CREATE POLICY owner_access ON quality.incident TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: infection_case owner_access; Type: POLICY; Schema: quality; Owner: hospital_owner
--

CREATE POLICY owner_access ON quality.infection_case TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: patient_feedback owner_access; Type: POLICY; Schema: quality; Owner: hospital_owner
--

CREATE POLICY owner_access ON quality.patient_feedback TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: patient_feedback; Type: ROW SECURITY; Schema: quality; Owner: hospital_owner
--

ALTER TABLE quality.patient_feedback ENABLE ROW LEVEL SECURITY;

--
-- Name: appointment; Type: ROW SECURITY; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE scheduling.appointment ENABLE ROW LEVEL SECURITY;

--
-- Name: appointment_participant; Type: ROW SECURITY; Schema: scheduling; Owner: hospital_owner
--

ALTER TABLE scheduling.appointment_participant ENABLE ROW LEVEL SECURITY;

--
-- Name: appointment clinician_access; Type: POLICY; Schema: scheduling; Owner: hospital_owner
--

CREATE POLICY clinician_access ON scheduling.appointment TO hospital_clinician USING (iam.has_patient_access(patient_id, 'treatment'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'treatment'::text));


--
-- Name: appointment_participant clinician_access; Type: POLICY; Schema: scheduling; Owner: hospital_owner
--

CREATE POLICY clinician_access ON scheduling.appointment_participant TO hospital_clinician USING ((EXISTS ( SELECT
   FROM scheduling.appointment a
  WHERE (a.id = appointment_participant.appointment_id))));


--
-- Name: appointment owner_access; Type: POLICY; Schema: scheduling; Owner: hospital_owner
--

CREATE POLICY owner_access ON scheduling.appointment TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: appointment_participant owner_access; Type: POLICY; Schema: scheduling; Owner: hospital_owner
--

CREATE POLICY owner_access ON scheduling.appointment_participant TO hospital_owner USING (true) WITH CHECK (true);


--
-- Name: appointment registrar_access; Type: POLICY; Schema: scheduling; Owner: hospital_owner
--

CREATE POLICY registrar_access ON scheduling.appointment TO hospital_registrar USING (iam.has_patient_access(patient_id, 'registration'::text)) WITH CHECK (iam.has_patient_access(patient_id, 'registration'::text));


--
-- Name: appointment_participant registrar_access; Type: POLICY; Schema: scheduling; Owner: hospital_owner
--

CREATE POLICY registrar_access ON scheduling.appointment_participant TO hospital_registrar USING ((EXISTS ( SELECT
   FROM scheduling.appointment a
  WHERE (a.id = appointment_participant.appointment_id))));


--
-- Name: SCHEMA adt; Type: ACL; Schema: -; Owner: hospital_owner
--

GRANT USAGE ON SCHEMA adt TO hospital_clinician;


--
-- Name: SCHEMA analytics; Type: ACL; Schema: -; Owner: hospital_owner
--

GRANT USAGE ON SCHEMA analytics TO hospital_analyst;


--
-- Name: SCHEMA audit; Type: ACL; Schema: -; Owner: hospital_owner
--

GRANT USAGE ON SCHEMA audit TO hospital_auditor;
GRANT USAGE ON SCHEMA audit TO hospital_clinician;
GRANT USAGE ON SCHEMA audit TO hospital_registrar;
GRANT USAGE ON SCHEMA audit TO hospital_billing;


--
-- Name: SCHEMA billing; Type: ACL; Schema: -; Owner: hospital_owner
--

GRANT USAGE ON SCHEMA billing TO hospital_billing;


--
-- Name: SCHEMA ehr; Type: ACL; Schema: -; Owner: hospital_owner
--

GRANT USAGE ON SCHEMA ehr TO hospital_clinician;


--
-- Name: SCHEMA ext; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA ext TO hospital_owner;
GRANT USAGE ON SCHEMA ext TO hospital_clinician;
GRANT USAGE ON SCHEMA ext TO hospital_registrar;
GRANT USAGE ON SCHEMA ext TO hospital_billing;
GRANT USAGE ON SCHEMA ext TO hospital_analyst;
GRANT USAGE ON SCHEMA ext TO hospital_auditor;


--
-- Name: SCHEMA iam; Type: ACL; Schema: -; Owner: hospital_owner
--

GRANT USAGE ON SCHEMA iam TO hospital_clinician;
GRANT USAGE ON SCHEMA iam TO hospital_registrar;
GRANT USAGE ON SCHEMA iam TO hospital_billing;


--
-- Name: SCHEMA imaging; Type: ACL; Schema: -; Owner: hospital_owner
--

GRANT USAGE ON SCHEMA imaging TO hospital_clinician;


--
-- Name: SCHEMA lab; Type: ACL; Schema: -; Owner: hospital_owner
--

GRANT USAGE ON SCHEMA lab TO hospital_clinician;


--
-- Name: SCHEMA mpi; Type: ACL; Schema: -; Owner: hospital_owner
--

GRANT USAGE ON SCHEMA mpi TO hospital_clinician;
GRANT USAGE ON SCHEMA mpi TO hospital_registrar;


--
-- Name: SCHEMA org; Type: ACL; Schema: -; Owner: hospital_owner
--

GRANT USAGE ON SCHEMA org TO hospital_clinician;
GRANT USAGE ON SCHEMA org TO hospital_registrar;
GRANT USAGE ON SCHEMA org TO hospital_billing;


--
-- Name: SCHEMA pharmacy; Type: ACL; Schema: -; Owner: hospital_owner
--

GRANT USAGE ON SCHEMA pharmacy TO hospital_clinician;


--
-- Name: SCHEMA ref; Type: ACL; Schema: -; Owner: hospital_owner
--

GRANT USAGE ON SCHEMA ref TO hospital_clinician;
GRANT USAGE ON SCHEMA ref TO hospital_registrar;
GRANT USAGE ON SCHEMA ref TO hospital_billing;


--
-- Name: SCHEMA scheduling; Type: ACL; Schema: -; Owner: hospital_owner
--

GRANT USAGE ON SCHEMA scheduling TO hospital_clinician;
GRANT USAGE ON SCHEMA scheduling TO hospital_registrar;


--
-- Name: FUNCTION guard_admission(); Type: ACL; Schema: adt; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION adt.guard_admission() FROM PUBLIC;


--
-- Name: FUNCTION guard_bed_stay(); Type: ACL; Schema: adt; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION adt.guard_bed_stay() FROM PUBLIC;


--
-- Name: FUNCTION guard_discharge(); Type: ACL; Schema: adt; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION adt.guard_discharge() FROM PUBLIC;


--
-- Name: FUNCTION capture_change(); Type: ACL; Schema: audit; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION audit.capture_change() FROM PUBLIC;


--
-- Name: FUNCTION record_patient_access(p_patient_id bigint, p_purpose text, p_action text, p_request_id uuid, p_reason text); Type: ACL; Schema: audit; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION audit.record_patient_access(p_patient_id bigint, p_purpose text, p_action text, p_request_id uuid, p_reason text) FROM PUBLIC;
GRANT ALL ON FUNCTION audit.record_patient_access(p_patient_id bigint, p_purpose text, p_action text, p_request_id uuid, p_reason text) TO hospital_clinician;
GRANT ALL ON FUNCTION audit.record_patient_access(p_patient_id bigint, p_purpose text, p_action text, p_request_id uuid, p_reason text) TO hospital_registrar;
GRANT ALL ON FUNCTION audit.record_patient_access(p_patient_id bigint, p_purpose text, p_action text, p_request_id uuid, p_reason text) TO hospital_billing;


--
-- Name: FUNCTION guard_allocation(); Type: ACL; Schema: billing; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION billing.guard_allocation() FROM PUBLIC;


--
-- Name: FUNCTION guard_coverage(); Type: ACL; Schema: billing; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION billing.guard_coverage() FROM PUBLIC;


--
-- Name: FUNCTION guard_invoice(); Type: ACL; Schema: billing; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION billing.guard_invoice() FROM PUBLIC;


--
-- Name: FUNCTION guard_invoice_line(); Type: ACL; Schema: billing; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION billing.guard_invoice_line() FROM PUBLIC;


--
-- Name: FUNCTION guard_administration(); Type: ACL; Schema: ehr; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION ehr.guard_administration() FROM PUBLIC;


--
-- Name: FUNCTION guard_clinical_author(); Type: ACL; Schema: ehr; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION ehr.guard_clinical_author() FROM PUBLIC;


--
-- Name: FUNCTION guard_encounter(); Type: ACL; Schema: ehr; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION ehr.guard_encounter() FROM PUBLIC;


--
-- Name: FUNCTION guard_note_version(); Type: ACL; Schema: ehr; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION ehr.guard_note_version() FROM PUBLIC;


--
-- Name: FUNCTION guard_observation(); Type: ACL; Schema: ehr; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION ehr.guard_observation() FROM PUBLIC;


--
-- Name: FUNCTION guard_patient_dates(); Type: ACL; Schema: ehr; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION ehr.guard_patient_dates() FROM PUBLIC;


--
-- Name: FUNCTION guard_patient_identity(); Type: ACL; Schema: ehr; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION ehr.guard_patient_identity() FROM PUBLIC;


--
-- Name: FUNCTION guard_signer(); Type: ACL; Schema: ehr; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION ehr.guard_signer() FROM PUBLIC;


--
-- Name: FUNCTION has_patient_access(p_patient_id bigint, p_purpose text); Type: ACL; Schema: iam; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION iam.has_patient_access(p_patient_id bigint, p_purpose text) FROM PUBLIC;
GRANT ALL ON FUNCTION iam.has_patient_access(p_patient_id bigint, p_purpose text) TO hospital_clinician;
GRANT ALL ON FUNCTION iam.has_patient_access(p_patient_id bigint, p_purpose text) TO hospital_registrar;
GRANT ALL ON FUNCTION iam.has_patient_access(p_patient_id bigint, p_purpose text) TO hospital_billing;


--
-- Name: FUNCTION guard_modality(); Type: ACL; Schema: imaging; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION imaging.guard_modality() FROM PUBLIC;


--
-- Name: FUNCTION guard_movement(); Type: ACL; Schema: inventory; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION inventory.guard_movement() FROM PUBLIC;


--
-- Name: FUNCTION guard_report_result(); Type: ACL; Schema: lab; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION lab.guard_report_result() FROM PUBLIC;


--
-- Name: FUNCTION guard_result(); Type: ACL; Schema: lab; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION lab.guard_result() FROM PUBLIC;


--
-- Name: FUNCTION deny_mutation(); Type: ACL; Schema: ops; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION ops.deny_mutation() FROM PUBLIC;


--
-- Name: FUNCTION touch_row(); Type: ACL; Schema: ops; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION ops.touch_row() FROM PUBLIC;


--
-- Name: FUNCTION guard_administration_quantity(); Type: ACL; Schema: pharmacy; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION pharmacy.guard_administration_quantity() FROM PUBLIC;


--
-- Name: FUNCTION guard_dispense(); Type: ACL; Schema: pharmacy; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION pharmacy.guard_dispense() FROM PUBLIC;


--
-- Name: FUNCTION post_dispense(); Type: ACL; Schema: pharmacy; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION pharmacy.post_dispense() FROM PUBLIC;


--
-- Name: FUNCTION guard_appointment_period(); Type: ACL; Schema: scheduling; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION scheduling.guard_appointment_period() FROM PUBLIC;


--
-- Name: FUNCTION guard_booked_slot(); Type: ACL; Schema: scheduling; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION scheduling.guard_booked_slot() FROM PUBLIC;


--
-- Name: FUNCTION guard_slot(); Type: ACL; Schema: scheduling; Owner: hospital_owner
--

REVOKE ALL ON FUNCTION scheduling.guard_slot() FROM PUBLIC;


--
-- Name: TABLE admission; Type: ACL; Schema: adt; Owner: hospital_owner
--

GRANT SELECT ON TABLE adt.admission TO hospital_clinician;


--
-- Name: TABLE bed_stay; Type: ACL; Schema: adt; Owner: hospital_owner
--

GRANT SELECT ON TABLE adt.bed_stay TO hospital_clinician;


--
-- Name: TABLE discharge; Type: ACL; Schema: adt; Owner: hospital_owner
--

GRANT SELECT ON TABLE adt.discharge TO hospital_clinician;


--
-- Name: TABLE bed; Type: ACL; Schema: org; Owner: hospital_owner
--

GRANT SELECT ON TABLE org.bed TO hospital_clinician;
GRANT SELECT ON TABLE org.bed TO hospital_registrar;
GRANT SELECT ON TABLE org.bed TO hospital_billing;


--
-- Name: TABLE department; Type: ACL; Schema: org; Owner: hospital_owner
--

GRANT SELECT ON TABLE org.department TO hospital_clinician;
GRANT SELECT ON TABLE org.department TO hospital_registrar;
GRANT SELECT ON TABLE org.department TO hospital_billing;


--
-- Name: TABLE room; Type: ACL; Schema: org; Owner: hospital_owner
--

GRANT SELECT ON TABLE org.room TO hospital_clinician;
GRANT SELECT ON TABLE org.room TO hospital_registrar;
GRANT SELECT ON TABLE org.room TO hospital_billing;


--
-- Name: TABLE bed_occupancy; Type: ACL; Schema: analytics; Owner: hospital_owner
--

GRANT SELECT ON TABLE analytics.bed_occupancy TO hospital_analyst;


--
-- Name: TABLE encounter; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT ON TABLE ehr.encounter TO hospital_clinician;


--
-- Name: TABLE daily_activity; Type: ACL; Schema: analytics; Owner: hospital_owner
--

GRANT SELECT ON TABLE analytics.daily_activity TO hospital_analyst;


--
-- Name: TABLE invoice; Type: ACL; Schema: billing; Owner: hospital_owner
--

GRANT SELECT ON TABLE billing.invoice TO hospital_billing;


--
-- Name: TABLE invoice_line; Type: ACL; Schema: billing; Owner: hospital_owner
--

GRANT SELECT ON TABLE billing.invoice_line TO hospital_billing;


--
-- Name: TABLE payer; Type: ACL; Schema: billing; Owner: hospital_owner
--

GRANT SELECT ON TABLE billing.payer TO hospital_billing;


--
-- Name: TABLE payment_allocation; Type: ACL; Schema: billing; Owner: hospital_owner
--

GRANT SELECT ON TABLE billing.payment_allocation TO hospital_billing;


--
-- Name: TABLE v_invoice_balance; Type: ACL; Schema: billing; Owner: hospital_owner
--

GRANT SELECT ON TABLE billing.v_invoice_balance TO hospital_billing;


--
-- Name: TABLE monthly_revenue; Type: ACL; Schema: analytics; Owner: hospital_owner
--

GRANT SELECT ON TABLE analytics.monthly_revenue TO hospital_analyst;


--
-- Name: TABLE access_event; Type: ACL; Schema: audit; Owner: hospital_owner
--

GRANT SELECT ON TABLE audit.access_event TO hospital_auditor;


--
-- Name: TABLE event; Type: ACL; Schema: audit; Owner: hospital_owner
--

GRANT SELECT ON TABLE audit.event TO hospital_auditor;


--
-- Name: TABLE claim; Type: ACL; Schema: billing; Owner: hospital_owner
--

GRANT SELECT ON TABLE billing.claim TO hospital_billing;


--
-- Name: TABLE coverage; Type: ACL; Schema: billing; Owner: hospital_owner
--

GRANT SELECT ON TABLE billing.coverage TO hospital_billing;


--
-- Name: TABLE payment; Type: ACL; Schema: billing; Owner: hospital_owner
--

GRANT SELECT ON TABLE billing.payment TO hospital_billing;


--
-- Name: TABLE tariff; Type: ACL; Schema: billing; Owner: hospital_owner
--

GRANT SELECT ON TABLE billing.tariff TO hospital_billing;


--
-- Name: TABLE patient; Type: ACL; Schema: mpi; Owner: hospital_owner
--

GRANT SELECT ON TABLE mpi.patient TO hospital_clinician;
GRANT SELECT ON TABLE mpi.patient TO hospital_registrar;


--
-- Name: COLUMN patient.family_name; Type: ACL; Schema: mpi; Owner: hospital_owner
--

GRANT UPDATE(family_name) ON TABLE mpi.patient TO hospital_registrar;


--
-- Name: COLUMN patient.given_name; Type: ACL; Schema: mpi; Owner: hospital_owner
--

GRANT UPDATE(given_name) ON TABLE mpi.patient TO hospital_registrar;


--
-- Name: COLUMN patient.birth_date; Type: ACL; Schema: mpi; Owner: hospital_owner
--

GRANT UPDATE(birth_date) ON TABLE mpi.patient TO hospital_registrar;


--
-- Name: COLUMN patient.administrative_gender; Type: ACL; Schema: mpi; Owner: hospital_owner
--

GRANT UPDATE(administrative_gender) ON TABLE mpi.patient TO hospital_registrar;


--
-- Name: TABLE v_patient_identity; Type: ACL; Schema: billing; Owner: hospital_owner
--

GRANT SELECT ON TABLE billing.v_patient_identity TO hospital_billing;


--
-- Name: TABLE allergy; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,INSERT,UPDATE ON TABLE ehr.allergy TO hospital_clinician;


--
-- Name: SEQUENCE allergy_id_seq; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,USAGE ON SEQUENCE ehr.allergy_id_seq TO hospital_clinician;


--
-- Name: TABLE care_plan; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,INSERT,UPDATE ON TABLE ehr.care_plan TO hospital_clinician;


--
-- Name: TABLE care_plan_activity; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,INSERT,UPDATE ON TABLE ehr.care_plan_activity TO hospital_clinician;


--
-- Name: SEQUENCE care_plan_activity_id_seq; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,USAGE ON SEQUENCE ehr.care_plan_activity_id_seq TO hospital_clinician;


--
-- Name: SEQUENCE care_plan_id_seq; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,USAGE ON SEQUENCE ehr.care_plan_id_seq TO hospital_clinician;


--
-- Name: TABLE clinical_note; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,INSERT,UPDATE ON TABLE ehr.clinical_note TO hospital_clinician;


--
-- Name: SEQUENCE clinical_note_id_seq; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,USAGE ON SEQUENCE ehr.clinical_note_id_seq TO hospital_clinician;


--
-- Name: TABLE condition; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,INSERT,UPDATE ON TABLE ehr.condition TO hospital_clinician;


--
-- Name: SEQUENCE condition_id_seq; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,USAGE ON SEQUENCE ehr.condition_id_seq TO hospital_clinician;


--
-- Name: TABLE death_record; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT ON TABLE ehr.death_record TO hospital_clinician;


--
-- Name: TABLE document; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT ON TABLE ehr.document TO hospital_clinician;


--
-- Name: SEQUENCE document_id_seq; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,USAGE ON SEQUENCE ehr.document_id_seq TO hospital_clinician;


--
-- Name: SEQUENCE encounter_id_seq; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,USAGE ON SEQUENCE ehr.encounter_id_seq TO hospital_clinician;


--
-- Name: TABLE encounter_participant; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT ON TABLE ehr.encounter_participant TO hospital_clinician;


--
-- Name: TABLE immunization; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT ON TABLE ehr.immunization TO hospital_clinician;


--
-- Name: SEQUENCE immunization_id_seq; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,USAGE ON SEQUENCE ehr.immunization_id_seq TO hospital_clinician;


--
-- Name: TABLE note_version; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,INSERT,UPDATE ON TABLE ehr.note_version TO hospital_clinician;


--
-- Name: TABLE observation; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,INSERT,UPDATE ON TABLE ehr.observation TO hospital_clinician;


--
-- Name: SEQUENCE observation_id_seq; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,USAGE ON SEQUENCE ehr.observation_id_seq TO hospital_clinician;


--
-- Name: TABLE procedure; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT ON TABLE ehr.procedure TO hospital_clinician;


--
-- Name: SEQUENCE procedure_id_seq; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT,USAGE ON SEQUENCE ehr.procedure_id_seq TO hospital_clinician;


--
-- Name: TABLE staff; Type: ACL; Schema: org; Owner: hospital_owner
--

GRANT SELECT ON TABLE org.staff TO hospital_clinician;
GRANT SELECT ON TABLE org.staff TO hospital_registrar;
GRANT SELECT ON TABLE org.staff TO hospital_billing;


--
-- Name: TABLE v_patient_timeline; Type: ACL; Schema: ehr; Owner: hospital_owner
--

GRANT SELECT ON TABLE ehr.v_patient_timeline TO hospital_clinician;


--
-- Name: TABLE imaging_order; Type: ACL; Schema: imaging; Owner: hospital_owner
--

GRANT SELECT ON TABLE imaging.imaging_order TO hospital_clinician;


--
-- Name: TABLE series; Type: ACL; Schema: imaging; Owner: hospital_owner
--

GRANT SELECT ON TABLE imaging.series TO hospital_clinician;


--
-- Name: TABLE study; Type: ACL; Schema: imaging; Owner: hospital_owner
--

GRANT SELECT ON TABLE imaging.study TO hospital_clinician;


--
-- Name: TABLE diagnostic_report; Type: ACL; Schema: lab; Owner: hospital_owner
--

GRANT SELECT ON TABLE lab.diagnostic_report TO hospital_clinician;


--
-- Name: TABLE report_result; Type: ACL; Schema: lab; Owner: hospital_owner
--

GRANT SELECT ON TABLE lab.report_result TO hospital_clinician;


--
-- Name: TABLE request_specimen; Type: ACL; Schema: lab; Owner: hospital_owner
--

GRANT SELECT ON TABLE lab.request_specimen TO hospital_clinician;


--
-- Name: TABLE result; Type: ACL; Schema: lab; Owner: hospital_owner
--

GRANT SELECT ON TABLE lab.result TO hospital_clinician;


--
-- Name: TABLE service_request; Type: ACL; Schema: lab; Owner: hospital_owner
--

GRANT SELECT ON TABLE lab.service_request TO hospital_clinician;


--
-- Name: TABLE specimen; Type: ACL; Schema: lab; Owner: hospital_owner
--

GRANT SELECT ON TABLE lab.specimen TO hospital_clinician;


--
-- Name: TABLE address; Type: ACL; Schema: mpi; Owner: hospital_owner
--

GRANT SELECT ON TABLE mpi.address TO hospital_clinician;
GRANT SELECT ON TABLE mpi.address TO hospital_registrar;


--
-- Name: TABLE consent; Type: ACL; Schema: mpi; Owner: hospital_owner
--

GRANT SELECT ON TABLE mpi.consent TO hospital_clinician;
GRANT SELECT ON TABLE mpi.consent TO hospital_registrar;


--
-- Name: TABLE contact; Type: ACL; Schema: mpi; Owner: hospital_owner
--

GRANT SELECT ON TABLE mpi.contact TO hospital_clinician;
GRANT SELECT ON TABLE mpi.contact TO hospital_registrar;


--
-- Name: TABLE identifier; Type: ACL; Schema: mpi; Owner: hospital_owner
--

GRANT SELECT ON TABLE mpi.identifier TO hospital_clinician;
GRANT SELECT ON TABLE mpi.identifier TO hospital_registrar;


--
-- Name: TABLE merge_history; Type: ACL; Schema: mpi; Owner: hospital_owner
--

GRANT SELECT ON TABLE mpi.merge_history TO hospital_clinician;
GRANT SELECT ON TABLE mpi.merge_history TO hospital_registrar;


--
-- Name: TABLE related_person; Type: ACL; Schema: mpi; Owner: hospital_owner
--

GRANT SELECT ON TABLE mpi.related_person TO hospital_clinician;
GRANT SELECT ON TABLE mpi.related_person TO hospital_registrar;


--
-- Name: TABLE credential; Type: ACL; Schema: org; Owner: hospital_owner
--

GRANT SELECT ON TABLE org.credential TO hospital_clinician;
GRANT SELECT ON TABLE org.credential TO hospital_registrar;
GRANT SELECT ON TABLE org.credential TO hospital_billing;


--
-- Name: TABLE device; Type: ACL; Schema: org; Owner: hospital_owner
--

GRANT SELECT ON TABLE org.device TO hospital_clinician;
GRANT SELECT ON TABLE org.device TO hospital_registrar;
GRANT SELECT ON TABLE org.device TO hospital_billing;


--
-- Name: TABLE organization; Type: ACL; Schema: org; Owner: hospital_owner
--

GRANT SELECT ON TABLE org.organization TO hospital_clinician;
GRANT SELECT ON TABLE org.organization TO hospital_registrar;
GRANT SELECT ON TABLE org.organization TO hospital_billing;


--
-- Name: TABLE site; Type: ACL; Schema: org; Owner: hospital_owner
--

GRANT SELECT ON TABLE org.site TO hospital_clinician;
GRANT SELECT ON TABLE org.site TO hospital_registrar;
GRANT SELECT ON TABLE org.site TO hospital_billing;


--
-- Name: TABLE staff_department; Type: ACL; Schema: org; Owner: hospital_owner
--

GRANT SELECT ON TABLE org.staff_department TO hospital_clinician;
GRANT SELECT ON TABLE org.staff_department TO hospital_registrar;
GRANT SELECT ON TABLE org.staff_department TO hospital_billing;


--
-- Name: TABLE administration; Type: ACL; Schema: pharmacy; Owner: hospital_owner
--

GRANT SELECT ON TABLE pharmacy.administration TO hospital_clinician;


--
-- Name: TABLE dispense; Type: ACL; Schema: pharmacy; Owner: hospital_owner
--

GRANT SELECT ON TABLE pharmacy.dispense TO hospital_clinician;


--
-- Name: TABLE medication_order; Type: ACL; Schema: pharmacy; Owner: hospital_owner
--

GRANT SELECT ON TABLE pharmacy.medication_order TO hospital_clinician;


--
-- Name: TABLE medication_reconciliation; Type: ACL; Schema: pharmacy; Owner: hospital_owner
--

GRANT SELECT ON TABLE pharmacy.medication_reconciliation TO hospital_clinician;


--
-- Name: TABLE code_system; Type: ACL; Schema: ref; Owner: hospital_owner
--

GRANT SELECT ON TABLE ref.code_system TO hospital_clinician;
GRANT SELECT ON TABLE ref.code_system TO hospital_registrar;
GRANT SELECT ON TABLE ref.code_system TO hospital_billing;


--
-- Name: TABLE concept; Type: ACL; Schema: ref; Owner: hospital_owner
--

GRANT SELECT ON TABLE ref.concept TO hospital_clinician;
GRANT SELECT ON TABLE ref.concept TO hospital_registrar;
GRANT SELECT ON TABLE ref.concept TO hospital_billing;


--
-- Name: TABLE currency; Type: ACL; Schema: ref; Owner: hospital_owner
--

GRANT SELECT ON TABLE ref.currency TO hospital_clinician;
GRANT SELECT ON TABLE ref.currency TO hospital_registrar;
GRANT SELECT ON TABLE ref.currency TO hospital_billing;


--
-- Name: TABLE encounter_type; Type: ACL; Schema: ref; Owner: hospital_owner
--

GRANT SELECT ON TABLE ref.encounter_type TO hospital_clinician;
GRANT SELECT ON TABLE ref.encounter_type TO hospital_registrar;
GRANT SELECT ON TABLE ref.encounter_type TO hospital_billing;


--
-- Name: TABLE medication; Type: ACL; Schema: ref; Owner: hospital_owner
--

GRANT SELECT ON TABLE ref.medication TO hospital_clinician;
GRANT SELECT ON TABLE ref.medication TO hospital_registrar;
GRANT SELECT ON TABLE ref.medication TO hospital_billing;


--
-- Name: TABLE panel_item; Type: ACL; Schema: ref; Owner: hospital_owner
--

GRANT SELECT ON TABLE ref.panel_item TO hospital_clinician;
GRANT SELECT ON TABLE ref.panel_item TO hospital_registrar;
GRANT SELECT ON TABLE ref.panel_item TO hospital_billing;


--
-- Name: TABLE route; Type: ACL; Schema: ref; Owner: hospital_owner
--

GRANT SELECT ON TABLE ref.route TO hospital_clinician;
GRANT SELECT ON TABLE ref.route TO hospital_registrar;
GRANT SELECT ON TABLE ref.route TO hospital_billing;


--
-- Name: TABLE service; Type: ACL; Schema: ref; Owner: hospital_owner
--

GRANT SELECT ON TABLE ref.service TO hospital_clinician;
GRANT SELECT ON TABLE ref.service TO hospital_registrar;
GRANT SELECT ON TABLE ref.service TO hospital_billing;


--
-- Name: TABLE test; Type: ACL; Schema: ref; Owner: hospital_owner
--

GRANT SELECT ON TABLE ref.test TO hospital_clinician;
GRANT SELECT ON TABLE ref.test TO hospital_registrar;
GRANT SELECT ON TABLE ref.test TO hospital_billing;


--
-- Name: TABLE test_panel; Type: ACL; Schema: ref; Owner: hospital_owner
--

GRANT SELECT ON TABLE ref.test_panel TO hospital_clinician;
GRANT SELECT ON TABLE ref.test_panel TO hospital_registrar;
GRANT SELECT ON TABLE ref.test_panel TO hospital_billing;


--
-- Name: TABLE unit; Type: ACL; Schema: ref; Owner: hospital_owner
--

GRANT SELECT ON TABLE ref.unit TO hospital_clinician;
GRANT SELECT ON TABLE ref.unit TO hospital_registrar;
GRANT SELECT ON TABLE ref.unit TO hospital_billing;


--
-- Name: TABLE appointment; Type: ACL; Schema: scheduling; Owner: hospital_owner
--

GRANT SELECT ON TABLE scheduling.appointment TO hospital_clinician;
GRANT SELECT ON TABLE scheduling.appointment TO hospital_registrar;


--
-- Name: COLUMN appointment.status; Type: ACL; Schema: scheduling; Owner: hospital_owner
--

GRANT UPDATE(status) ON TABLE scheduling.appointment TO hospital_registrar;


--
-- Name: COLUMN appointment.reason_text; Type: ACL; Schema: scheduling; Owner: hospital_owner
--

GRANT UPDATE(reason_text) ON TABLE scheduling.appointment TO hospital_registrar;


--
-- Name: TABLE appointment_participant; Type: ACL; Schema: scheduling; Owner: hospital_owner
--

GRANT SELECT ON TABLE scheduling.appointment_participant TO hospital_clinician;
GRANT SELECT ON TABLE scheduling.appointment_participant TO hospital_registrar;


--
-- Name: TABLE schedule; Type: ACL; Schema: scheduling; Owner: hospital_owner
--

GRANT SELECT ON TABLE scheduling.schedule TO hospital_clinician;
GRANT SELECT ON TABLE scheduling.schedule TO hospital_registrar;


--
-- Name: TABLE slot; Type: ACL; Schema: scheduling; Owner: hospital_owner
--

GRANT SELECT ON TABLE scheduling.slot TO hospital_clinician;
GRANT SELECT ON TABLE scheduling.slot TO hospital_registrar;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: hospital_owner
--

ALTER DEFAULT PRIVILEGES FOR ROLE hospital_owner REVOKE ALL ON FUNCTIONS FROM PUBLIC;


--
-- PostgreSQL database dump complete
--

\unrestrict ffO9If5sYyIPBWkQmLMJpfBkpqgifyfPu3BEdMQJLPD1riMncfdfykDhxBh4uCA

