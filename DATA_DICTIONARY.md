# Словарь установленной БД

Сформирован из системного каталога PostgreSQL. Общие проектные решения — в DATA_MODEL.md.

## adt.admission

Hospital reference model / adt / admission. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 30,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | нет | encounter id; see table constraints and DATA_MODEL.md. |
| `admission_number` | `text` | нет | admission number; see table constraints and DATA_MODEL.md. |
| `admitted_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `discharged_at` | `timestamp with time zone` | да | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `admission_source` | `text` | нет | admission source; see table constraints and DATA_MODEL.md. |

Ограничения:

- `admission_admission_number_key`: `UNIQUE (admission_number)`
- `admission_admission_number_not_null`: `NOT NULL admission_number`
- `admission_admission_source_check`: `CHECK ((admission_source = ANY (ARRAY['emergency'::text, 'referral'::text, 'transfer'::text])))`
- `admission_admission_source_not_null`: `NOT NULL admission_source`
- `admission_admitted_at_not_null`: `NOT NULL admitted_at`
- `admission_check`: `CHECK (((discharged_at IS NULL) OR (discharged_at > admitted_at)))`
- `admission_encounter_id_key`: `UNIQUE (encounter_id)`
- `admission_encounter_id_not_null`: `NOT NULL encounter_id`
- `admission_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `admission_id_not_null`: `NOT NULL id`
- `admission_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `admission_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `admission_patient_id_not_null`: `NOT NULL patient_id`
- `admission_patient_id_tstzrange_excl`: `EXCLUDE USING gist (patient_id WITH =, tstzrange(admitted_at, discharged_at, '[)'::text) WITH &&)`
- `admission_pkey`: `PRIMARY KEY (id)`

Триггеры:

- `CREATE TRIGGER admission_period_guard BEFORE INSERT OR UPDATE ON adt.admission FOR EACH ROW EXECUTE FUNCTION adt.guard_admission()`
- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON adt.admission FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON adt.admission FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## adt.bed_stay

Hospital reference model / adt / bed stay. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 30,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `admission_id` | `bigint` | нет | admission id; see table constraints and DATA_MODEL.md. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `bed_id` | `bigint` | нет | bed id; see table constraints and DATA_MODEL.md. |
| `occupied_during` | `tstzrange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |

Ограничения:

- `bed_stay_admission_id_not_null`: `NOT NULL admission_id`
- `bed_stay_admission_id_patient_id_fkey`: `FOREIGN KEY (admission_id, patient_id) REFERENCES adt.admission(id, patient_id)`
- `bed_stay_bed_id_fkey`: `FOREIGN KEY (bed_id) REFERENCES org.bed(id)`
- `bed_stay_bed_id_not_null`: `NOT NULL bed_id`
- `bed_stay_bed_id_occupied_during_excl`: `EXCLUDE USING gist (bed_id WITH =, occupied_during WITH &&)`
- `bed_stay_id_not_null`: `NOT NULL id`
- `bed_stay_occupied_during_check`: `CHECK (((NOT isempty(occupied_during)) AND (NOT lower_inf(occupied_during)) AND lower_inc(occupied_during) AND (NOT upper_inc(occupied_during))))`
- `bed_stay_occupied_during_not_null`: `NOT NULL occupied_during`
- `bed_stay_patient_id_not_null`: `NOT NULL patient_id`
- `bed_stay_patient_id_occupied_during_excl`: `EXCLUDE USING gist (patient_id WITH =, occupied_during WITH &&)`
- `bed_stay_pkey`: `PRIMARY KEY (id)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON adt.bed_stay FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER bed_stay_guard BEFORE INSERT OR UPDATE ON adt.bed_stay FOR EACH ROW EXECUTE FUNCTION adt.guard_bed_stay()`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON adt.bed_stay FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## adt.discharge

Hospital reference model / adt / discharge. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 29,700. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `admission_id` | `bigint` | нет | admission id; see table constraints and DATA_MODEL.md. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `discharged_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `disposition` | `text` | нет | disposition; see table constraints and DATA_MODEL.md. |
| `summary_note_id` | `bigint` | нет | summary note id; see table constraints and DATA_MODEL.md. |
| `approved_by` | `bigint` | нет | approved by; see table constraints and DATA_MODEL.md. |

Ограничения:

- `discharge_admission_id_not_null`: `NOT NULL admission_id`
- `discharge_admission_id_patient_id_fkey`: `FOREIGN KEY (admission_id, patient_id) REFERENCES adt.admission(id, patient_id)`
- `discharge_approved_by_fkey`: `FOREIGN KEY (approved_by) REFERENCES org.staff(id)`
- `discharge_approved_by_not_null`: `NOT NULL approved_by`
- `discharge_discharged_at_not_null`: `NOT NULL discharged_at`
- `discharge_disposition_check`: `CHECK ((disposition = ANY (ARRAY['home'::text, 'transfer'::text, 'deceased'::text, 'other'::text])))`
- `discharge_disposition_not_null`: `NOT NULL disposition`
- `discharge_patient_id_not_null`: `NOT NULL patient_id`
- `discharge_pkey`: `PRIMARY KEY (admission_id)`
- `discharge_summary_note_id_not_null`: `NOT NULL summary_note_id`
- `discharge_summary_note_id_patient_id_fkey`: `FOREIGN KEY (summary_note_id, patient_id) REFERENCES ehr.clinical_note(id, patient_id)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON adt.discharge FOR EACH ROW EXECUTE FUNCTION audit.capture_change('admission_id', 'patient_id')`
- `CREATE TRIGGER discharge_instant_guard BEFORE INSERT OR UPDATE ON adt.discharge FOR EACH ROW EXECUTE FUNCTION adt.guard_discharge()`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON adt.discharge FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## audit.access_event

Hospital reference model / audit / access event. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 100. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `occurred_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `actor` | `name` | нет | actor; see table constraints and DATA_MODEL.md. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `purpose` | `text` | нет | purpose; see table constraints and DATA_MODEL.md. |
| `action` | `text` | нет | action; see table constraints and DATA_MODEL.md. |
| `request_id` | `uuid` | нет | request id; see table constraints and DATA_MODEL.md. |
| `reason` | `text` | нет | reason; see table constraints and DATA_MODEL.md. |

Ограничения:

- `access_event_action_check`: `CHECK ((action = ANY (ARRAY['read'::text, 'export'::text, 'break-glass'::text])))`
- `access_event_action_not_null`: `NOT NULL action`
- `access_event_actor_not_null`: `NOT NULL actor`
- `access_event_id_not_null`: `NOT NULL id`
- `access_event_occurred_at_not_null`: `NOT NULL occurred_at`
- `access_event_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `access_event_patient_id_not_null`: `NOT NULL patient_id`
- `access_event_pkey`: `PRIMARY KEY (id)`
- `access_event_purpose_not_null`: `NOT NULL purpose`
- `access_event_reason_not_null`: `NOT NULL reason`
- `access_event_request_id_not_null`: `NOT NULL request_id`

Триггеры:

- `CREATE TRIGGER audit_access_immutable BEFORE DELETE OR UPDATE ON audit.access_event FOR EACH ROW EXECUTE FUNCTION ops.deny_mutation()`

Политики доступа:

- `auditor_access` (hospital_auditor): USING `true`, WITH CHECK `None`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## audit.event

Append-only DML metadata; actor=session_user. Baseline explicitly denotes synthetic load. No full clinical bodies are duplicated. Superusers remain trusted.

Строк: 399,257. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `occurred_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `actor` | `name` | нет | actor; see table constraints and DATA_MODEL.md. |
| `transaction_id` | `bigint` | нет | transaction id; see table constraints and DATA_MODEL.md. |
| `table_schema` | `name` | нет | table schema; see table constraints and DATA_MODEL.md. |
| `table_name` | `name` | нет | table name; see table constraints and DATA_MODEL.md. |
| `operation` | `text` | нет | operation; see table constraints and DATA_MODEL.md. |
| `entity_key` | `jsonb` | нет | entity key; see table constraints and DATA_MODEL.md. |
| `changed_columns` | `text[]` | да | changed columns; see table constraints and DATA_MODEL.md. |
| `request_id` | `text` | да | request id; see table constraints and DATA_MODEL.md. |
| `details` | `jsonb` | нет | details; see table constraints and DATA_MODEL.md. |

Ограничения:

- `event_actor_not_null`: `NOT NULL actor`
- `event_details_not_null`: `NOT NULL details`
- `event_entity_key_not_null`: `NOT NULL entity_key`
- `event_id_not_null`: `NOT NULL id`
- `event_occurred_at_not_null`: `NOT NULL occurred_at`
- `event_operation_check`: `CHECK ((operation = ANY (ARRAY['INSERT'::text, 'UPDATE'::text, 'DELETE'::text, 'BASELINE'::text])))`
- `event_operation_not_null`: `NOT NULL operation`
- `event_pkey`: `PRIMARY KEY (id)`
- `event_table_name_not_null`: `NOT NULL table_name`
- `event_table_schema_not_null`: `NOT NULL table_schema`
- `event_transaction_id_not_null`: `NOT NULL transaction_id`

Триггеры:

- `CREATE TRIGGER audit_events_immutable BEFORE DELETE OR UPDATE ON audit.event FOR EACH ROW EXECUTE FUNCTION ops.deny_mutation()`

## billing.claim

Hospital reference model / billing / claim. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 180,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `invoice_id` | `bigint` | нет | invoice id; see table constraints and DATA_MODEL.md. |
| `payer_id` | `bigint` | нет | payer id; see table constraints and DATA_MODEL.md. |
| `claim_number` | `text` | нет | claim number; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `submitted_at` | `timestamp with time zone` | да | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `adjudicated_at` | `timestamp with time zone` | да | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `rejection_reason` | `text` | да | rejection reason; see table constraints and DATA_MODEL.md. |

Ограничения:

- `claim_check`: `CHECK (((adjudicated_at IS NULL) OR (adjudicated_at >= submitted_at)))`
- `claim_check1`: `CHECK (((status <> 'rejected'::text) OR (rejection_reason IS NOT NULL)))`
- `claim_claim_number_key`: `UNIQUE (claim_number)`
- `claim_claim_number_not_null`: `NOT NULL claim_number`
- `claim_id_not_null`: `NOT NULL id`
- `claim_invoice_id_key`: `UNIQUE (invoice_id)`
- `claim_invoice_id_not_null`: `NOT NULL invoice_id`
- `claim_invoice_id_patient_id_fkey`: `FOREIGN KEY (invoice_id, patient_id) REFERENCES billing.invoice(id, patient_id)`
- `claim_patient_id_not_null`: `NOT NULL patient_id`
- `claim_payer_id_fkey`: `FOREIGN KEY (payer_id) REFERENCES billing.payer(id)`
- `claim_payer_id_not_null`: `NOT NULL payer_id`
- `claim_pkey`: `PRIMARY KEY (id)`
- `claim_status_check`: `CHECK ((status = ANY (ARRAY['draft'::text, 'submitted'::text, 'accepted'::text, 'rejected'::text])))`
- `claim_status_not_null`: `NOT NULL status`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.claim FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON billing.claim FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `billing_access` (hospital_billing): USING `iam.has_patient_access(patient_id, 'billing'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'billing'::text)`.
- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## billing.coverage

Hospital reference model / billing / coverage. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 120,002. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `payer_id` | `bigint` | нет | payer id; see table constraints and DATA_MODEL.md. |
| `policy_number` | `text` | нет | policy number; see table constraints and DATA_MODEL.md. |
| `valid_during` | `daterange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |
| `priority` | `smallint` | нет | priority; see table constraints and DATA_MODEL.md. |

Ограничения:

- `coverage_id_not_null`: `NOT NULL id`
- `coverage_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `coverage_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `coverage_patient_id_not_null`: `NOT NULL patient_id`
- `coverage_payer_id_fkey`: `FOREIGN KEY (payer_id) REFERENCES billing.payer(id)`
- `coverage_payer_id_not_null`: `NOT NULL payer_id`
- `coverage_pkey`: `PRIMARY KEY (id)`
- `coverage_policy_number_key`: `UNIQUE (policy_number)`
- `coverage_policy_number_not_null`: `NOT NULL policy_number`
- `coverage_priority_check`: `CHECK ((priority > 0))`
- `coverage_priority_not_null`: `NOT NULL priority`
- `coverage_valid_during_check`: `CHECK ((NOT isempty(valid_during)))`
- `coverage_valid_during_not_null`: `NOT NULL valid_during`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.coverage FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON billing.coverage FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `billing_access` (hospital_billing): USING `iam.has_patient_access(patient_id, 'billing'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'billing'::text)`.
- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## billing.invoice

Hospital reference model / billing / invoice. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 180,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | нет | encounter id; see table constraints and DATA_MODEL.md. |
| `invoice_number` | `text` | нет | invoice number; see table constraints and DATA_MODEL.md. |
| `payer_id` | `bigint` | нет | payer id; see table constraints and DATA_MODEL.md. |
| `coverage_id` | `bigint` | да | coverage id; see table constraints and DATA_MODEL.md. |
| `issued_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `due_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `currency_code` | `character(3)` | нет | currency code; see table constraints and DATA_MODEL.md. |

Ограничения:

- `invoice_check`: `CHECK ((due_at >= issued_at))`
- `invoice_coverage_id_patient_id_fkey`: `FOREIGN KEY (coverage_id, patient_id) REFERENCES billing.coverage(id, patient_id)`
- `invoice_currency_code_fkey`: `FOREIGN KEY (currency_code) REFERENCES ref.currency(code)`
- `invoice_currency_code_not_null`: `NOT NULL currency_code`
- `invoice_due_at_not_null`: `NOT NULL due_at`
- `invoice_encounter_id_not_null`: `NOT NULL encounter_id`
- `invoice_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `invoice_id_not_null`: `NOT NULL id`
- `invoice_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `invoice_invoice_number_key`: `UNIQUE (invoice_number)`
- `invoice_invoice_number_not_null`: `NOT NULL invoice_number`
- `invoice_issued_at_not_null`: `NOT NULL issued_at`
- `invoice_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `invoice_patient_id_not_null`: `NOT NULL patient_id`
- `invoice_payer_id_fkey`: `FOREIGN KEY (payer_id) REFERENCES billing.payer(id)`
- `invoice_payer_id_not_null`: `NOT NULL payer_id`
- `invoice_pkey`: `PRIMARY KEY (id)`
- `invoice_status_check`: `CHECK ((status = ANY (ARRAY['draft'::text, 'issued'::text, 'void'::text])))`
- `invoice_status_not_null`: `NOT NULL status`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.invoice FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER invoice_coverage_guard BEFORE INSERT OR UPDATE ON billing.invoice FOR EACH ROW EXECUTE FUNCTION billing.guard_coverage()`
- `CREATE TRIGGER invoice_guard BEFORE UPDATE ON billing.invoice FOR EACH ROW EXECUTE FUNCTION billing.guard_invoice()`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON billing.invoice FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `billing_access` (hospital_billing): USING `iam.has_patient_access(patient_id, 'billing'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'billing'::text)`.
- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## billing.invoice_line

Hospital reference model / billing / invoice line. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 360,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `invoice_id` | `bigint` | нет | invoice id; see table constraints and DATA_MODEL.md. |
| `line_no` | `integer` | нет | line no; see table constraints and DATA_MODEL.md. |
| `service_id` | `integer` | нет | service id; see table constraints and DATA_MODEL.md. |
| `quantity` | `ref.positive_quantity` | нет | quantity; see table constraints and DATA_MODEL.md. |
| `unit_price` | `ref.nonnegative_money` | нет | unit price; see table constraints and DATA_MODEL.md. |
| `discount_amount` | `ref.nonnegative_money` | нет | discount amount; see table constraints and DATA_MODEL.md. |
| `tax_rate` | `numeric(7,6)` | нет | tax rate; see table constraints and DATA_MODEL.md. |
| `net_amount` | `numeric(18,2)` | да | net amount; see table constraints and DATA_MODEL.md. |
| `tax_amount` | `numeric(18,2)` | да | tax amount; see table constraints and DATA_MODEL.md. |

Ограничения:

- `invoice_line_check`: `CHECK (((discount_amount)::numeric <= ((quantity)::numeric * (unit_price)::numeric)))`
- `invoice_line_discount_amount_not_null`: `NOT NULL discount_amount`
- `invoice_line_invoice_id_fkey`: `FOREIGN KEY (invoice_id) REFERENCES billing.invoice(id)`
- `invoice_line_invoice_id_not_null`: `NOT NULL invoice_id`
- `invoice_line_line_no_check`: `CHECK ((line_no > 0))`
- `invoice_line_line_no_not_null`: `NOT NULL line_no`
- `invoice_line_pkey`: `PRIMARY KEY (invoice_id, line_no)`
- `invoice_line_quantity_not_null`: `NOT NULL quantity`
- `invoice_line_service_id_fkey`: `FOREIGN KEY (service_id) REFERENCES ref.service(id)`
- `invoice_line_service_id_not_null`: `NOT NULL service_id`
- `invoice_line_tax_rate_check`: `CHECK (((tax_rate >= (0)::numeric) AND (tax_rate <= (1)::numeric)))`
- `invoice_line_tax_rate_not_null`: `NOT NULL tax_rate`
- `invoice_line_unit_price_not_null`: `NOT NULL unit_price`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.invoice_line FOR EACH ROW EXECUTE FUNCTION audit.capture_change('invoice_id', 'line_no')`
- `CREATE TRIGGER invoice_line_guard BEFORE INSERT OR DELETE OR UPDATE ON billing.invoice_line FOR EACH ROW EXECUTE FUNCTION billing.guard_invoice_line()`

Политики доступа:

- `billing_access` (hospital_billing): USING `(EXISTS ( SELECT
   FROM billing.invoice i
  WHERE (i.id = invoice_line.invoice_id)))`, WITH CHECK `None`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## billing.payer

Hospital reference model / billing / payer. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 3. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `name` | `text` | нет | name; see table constraints and DATA_MODEL.md. |
| `kind` | `text` | нет | kind; see table constraints and DATA_MODEL.md. |

Ограничения:

- `payer_code_key`: `UNIQUE (code)`
- `payer_code_not_null`: `NOT NULL code`
- `payer_id_not_null`: `NOT NULL id`
- `payer_kind_check`: `CHECK ((kind = ANY (ARRAY['public'::text, 'private'::text, 'self-pay'::text])))`
- `payer_kind_not_null`: `NOT NULL kind`
- `payer_name_not_null`: `NOT NULL name`
- `payer_pkey`: `PRIMARY KEY (id)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.payer FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## billing.payment

Hospital reference model / billing / payment. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 150,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `payer_id` | `bigint` | нет | payer id; see table constraints and DATA_MODEL.md. |
| `received_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `amount` | `ref.nonnegative_money` | нет | amount; see table constraints and DATA_MODEL.md. |
| `currency_code` | `character(3)` | нет | currency code; see table constraints and DATA_MODEL.md. |
| `method` | `text` | нет | method; see table constraints and DATA_MODEL.md. |
| `external_reference` | `text` | нет | external reference; see table constraints and DATA_MODEL.md. |

Ограничения:

- `payment_amount_check`: `CHECK (((amount)::numeric > (0)::numeric))`
- `payment_amount_not_null`: `NOT NULL amount`
- `payment_currency_code_fkey`: `FOREIGN KEY (currency_code) REFERENCES ref.currency(code)`
- `payment_currency_code_not_null`: `NOT NULL currency_code`
- `payment_external_reference_key`: `UNIQUE (external_reference)`
- `payment_external_reference_not_null`: `NOT NULL external_reference`
- `payment_id_not_null`: `NOT NULL id`
- `payment_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `payment_method_check`: `CHECK ((method = ANY (ARRAY['card'::text, 'transfer'::text, 'cash'::text])))`
- `payment_method_not_null`: `NOT NULL method`
- `payment_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `payment_patient_id_not_null`: `NOT NULL patient_id`
- `payment_payer_id_fkey`: `FOREIGN KEY (payer_id) REFERENCES billing.payer(id)`
- `payment_payer_id_not_null`: `NOT NULL payer_id`
- `payment_pkey`: `PRIMARY KEY (id)`
- `payment_received_at_not_null`: `NOT NULL received_at`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.payment FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON billing.payment FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`
- `CREATE TRIGGER payment_immutable BEFORE DELETE OR UPDATE ON billing.payment FOR EACH ROW EXECUTE FUNCTION ops.deny_mutation()`

Политики доступа:

- `billing_access` (hospital_billing): USING `iam.has_patient_access(patient_id, 'billing'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'billing'::text)`.
- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## billing.payment_allocation

Append-only allocation, serialized by payment and invoice row locks. Currency, payer, patient identity and available balances are checked.

Строк: 150,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `payment_id` | `bigint` | нет | payment id; see table constraints and DATA_MODEL.md. |
| `invoice_id` | `bigint` | нет | invoice id; see table constraints and DATA_MODEL.md. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `amount` | `ref.nonnegative_money` | нет | amount; see table constraints and DATA_MODEL.md. |
| `allocated_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |

Ограничения:

- `payment_allocation_allocated_at_not_null`: `NOT NULL allocated_at`
- `payment_allocation_amount_check`: `CHECK (((amount)::numeric > (0)::numeric))`
- `payment_allocation_amount_not_null`: `NOT NULL amount`
- `payment_allocation_id_not_null`: `NOT NULL id`
- `payment_allocation_invoice_id_not_null`: `NOT NULL invoice_id`
- `payment_allocation_invoice_id_patient_id_fkey`: `FOREIGN KEY (invoice_id, patient_id) REFERENCES billing.invoice(id, patient_id)`
- `payment_allocation_patient_id_not_null`: `NOT NULL patient_id`
- `payment_allocation_payment_id_invoice_id_key`: `UNIQUE (payment_id, invoice_id)`
- `payment_allocation_payment_id_not_null`: `NOT NULL payment_id`
- `payment_allocation_payment_id_patient_id_fkey`: `FOREIGN KEY (payment_id, patient_id) REFERENCES billing.payment(id, patient_id)`
- `payment_allocation_pkey`: `PRIMARY KEY (id)`

Триггеры:

- `CREATE TRIGGER allocation_immutable BEFORE DELETE OR UPDATE ON billing.payment_allocation FOR EACH ROW EXECUTE FUNCTION ops.deny_mutation()`
- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.payment_allocation FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON billing.payment_allocation FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`
- `CREATE TRIGGER payment_allocation_guard BEFORE INSERT ON billing.payment_allocation FOR EACH ROW EXECUTE FUNCTION billing.guard_allocation()`

Политики доступа:

- `billing_access` (hospital_billing): USING `iam.has_patient_access(patient_id, 'billing'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'billing'::text)`.
- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## billing.tariff

Hospital reference model / billing / tariff. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 15. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `service_id` | `integer` | нет | service id; see table constraints and DATA_MODEL.md. |
| `payer_id` | `bigint` | нет | payer id; see table constraints and DATA_MODEL.md. |
| `valid_during` | `daterange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |
| `amount` | `ref.nonnegative_money` | нет | amount; see table constraints and DATA_MODEL.md. |
| `currency_code` | `character(3)` | нет | currency code; see table constraints and DATA_MODEL.md. |

Ограничения:

- `tariff_amount_not_null`: `NOT NULL amount`
- `tariff_currency_code_fkey`: `FOREIGN KEY (currency_code) REFERENCES ref.currency(code)`
- `tariff_currency_code_not_null`: `NOT NULL currency_code`
- `tariff_id_not_null`: `NOT NULL id`
- `tariff_payer_id_fkey`: `FOREIGN KEY (payer_id) REFERENCES billing.payer(id)`
- `tariff_payer_id_not_null`: `NOT NULL payer_id`
- `tariff_pkey`: `PRIMARY KEY (id)`
- `tariff_service_id_fkey`: `FOREIGN KEY (service_id) REFERENCES ref.service(id)`
- `tariff_service_id_not_null`: `NOT NULL service_id`
- `tariff_service_id_payer_id_valid_during_excl`: `EXCLUDE USING gist (service_id WITH =, payer_id WITH =, valid_during WITH &&)`
- `tariff_valid_during_check`: `CHECK ((NOT isempty(valid_during)))`
- `tariff_valid_during_not_null`: `NOT NULL valid_during`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON billing.tariff FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## ehr.allergy

Hospital reference model / ehr / allergy. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 15,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `substance_concept_id` | `integer` | нет | substance concept id; see table constraints and DATA_MODEL.md. |
| `clinical_status` | `text` | нет | clinical status; see table constraints and DATA_MODEL.md. |
| `verification_status` | `text` | нет | verification status; see table constraints and DATA_MODEL.md. |
| `criticality` | `text` | нет | criticality; see table constraints and DATA_MODEL.md. |
| `reaction_text` | `text` | да | reaction text; see table constraints and DATA_MODEL.md. |
| `recorded_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `recorded_by` | `bigint` | нет | recorded by; see table constraints and DATA_MODEL.md. |

Ограничения:

- `allergy_clinical_status_check`: `CHECK ((clinical_status = ANY (ARRAY['active'::text, 'inactive'::text, 'resolved'::text])))`
- `allergy_clinical_status_not_null`: `NOT NULL clinical_status`
- `allergy_criticality_check`: `CHECK ((criticality = ANY (ARRAY['low'::text, 'high'::text, 'unable-to-assess'::text])))`
- `allergy_criticality_not_null`: `NOT NULL criticality`
- `allergy_id_not_null`: `NOT NULL id`
- `allergy_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `allergy_patient_id_not_null`: `NOT NULL patient_id`
- `allergy_pkey`: `PRIMARY KEY (id)`
- `allergy_recorded_at_not_null`: `NOT NULL recorded_at`
- `allergy_recorded_by_fkey`: `FOREIGN KEY (recorded_by) REFERENCES org.staff(id)`
- `allergy_recorded_by_not_null`: `NOT NULL recorded_by`
- `allergy_substance_concept_id_fkey`: `FOREIGN KEY (substance_concept_id) REFERENCES ref.concept(id)`
- `allergy_substance_concept_id_not_null`: `NOT NULL substance_concept_id`
- `allergy_verification_status_check`: `CHECK ((verification_status = ANY (ARRAY['unconfirmed'::text, 'confirmed'::text, 'refuted'::text])))`
- `allergy_verification_status_not_null`: `NOT NULL verification_status`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.allergy FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.allergy FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('recorded_by')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.allergy FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## ehr.care_plan

Hospital reference model / ehr / care plan. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 20,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | да | encounter id; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `title` | `text` | нет | title; see table constraints and DATA_MODEL.md. |
| `valid_during` | `tstzrange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |
| `author_id` | `bigint` | нет | author id; see table constraints and DATA_MODEL.md. |

Ограничения:

- `care_plan_author_id_fkey`: `FOREIGN KEY (author_id) REFERENCES org.staff(id)`
- `care_plan_author_id_not_null`: `NOT NULL author_id`
- `care_plan_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `care_plan_id_not_null`: `NOT NULL id`
- `care_plan_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `care_plan_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `care_plan_patient_id_not_null`: `NOT NULL patient_id`
- `care_plan_pkey`: `PRIMARY KEY (id)`
- `care_plan_status_check`: `CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'completed'::text, 'revoked'::text])))`
- `care_plan_status_not_null`: `NOT NULL status`
- `care_plan_title_not_null`: `NOT NULL title`
- `care_plan_valid_during_check`: `CHECK ((NOT isempty(valid_during)))`
- `care_plan_valid_during_not_null`: `NOT NULL valid_during`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.care_plan FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.care_plan FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('author_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.care_plan FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## ehr.care_plan_activity

Hospital reference model / ehr / care plan activity. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 20,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `care_plan_id` | `bigint` | нет | care plan id; see table constraints and DATA_MODEL.md. |
| `service_id` | `integer` | нет | service id; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `scheduled_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `assigned_staff_id` | `bigint` | да | assigned staff id; see table constraints and DATA_MODEL.md. |

Ограничения:

- `care_plan_activity_assigned_staff_id_fkey`: `FOREIGN KEY (assigned_staff_id) REFERENCES org.staff(id)`
- `care_plan_activity_care_plan_id_fkey`: `FOREIGN KEY (care_plan_id) REFERENCES ehr.care_plan(id)`
- `care_plan_activity_care_plan_id_not_null`: `NOT NULL care_plan_id`
- `care_plan_activity_id_not_null`: `NOT NULL id`
- `care_plan_activity_pkey`: `PRIMARY KEY (id)`
- `care_plan_activity_scheduled_at_not_null`: `NOT NULL scheduled_at`
- `care_plan_activity_service_id_fkey`: `FOREIGN KEY (service_id) REFERENCES ref.service(id)`
- `care_plan_activity_service_id_not_null`: `NOT NULL service_id`
- `care_plan_activity_status_check`: `CHECK ((status = ANY (ARRAY['scheduled'::text, 'in-progress'::text, 'completed'::text, 'cancelled'::text])))`
- `care_plan_activity_status_not_null`: `NOT NULL status`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.care_plan_activity FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `(EXISTS ( SELECT
   FROM ehr.care_plan p
  WHERE (p.id = care_plan_activity.care_plan_id)))`, WITH CHECK `None`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## ehr.clinical_note

Hospital reference model / ehr / clinical note. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 330,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | нет | encounter id; see table constraints and DATA_MODEL.md. |
| `note_type` | `text` | нет | note type; see table constraints and DATA_MODEL.md. |
| `author_id` | `bigint` | нет | author id; see table constraints and DATA_MODEL.md. |
| `created_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `current_version` | `integer` | нет | current version; see table constraints and DATA_MODEL.md. |

Ограничения:

- `clinical_note_author_id_fkey`: `FOREIGN KEY (author_id) REFERENCES org.staff(id)`
- `clinical_note_author_id_not_null`: `NOT NULL author_id`
- `clinical_note_created_at_not_null`: `NOT NULL created_at`
- `clinical_note_current_version_check`: `CHECK ((current_version > 0))`
- `clinical_note_current_version_not_null`: `NOT NULL current_version`
- `clinical_note_encounter_id_not_null`: `NOT NULL encounter_id`
- `clinical_note_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `clinical_note_id_not_null`: `NOT NULL id`
- `clinical_note_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `clinical_note_note_type_check`: `CHECK ((note_type = ANY (ARRAY['progress'::text, 'consultation'::text, 'discharge'::text, 'nursing'::text])))`
- `clinical_note_note_type_not_null`: `NOT NULL note_type`
- `clinical_note_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `clinical_note_patient_id_not_null`: `NOT NULL patient_id`
- `clinical_note_pkey`: `PRIMARY KEY (id)`
- `note_current_version_fk`: `FOREIGN KEY (id, current_version) REFERENCES ehr.note_version(note_id, version) DEFERRABLE INITIALLY DEFERRED`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.clinical_note FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.clinical_note FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('author_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.clinical_note FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## ehr.condition

Hospital reference model / ehr / condition. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 180,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | да | encounter id; see table constraints and DATA_MODEL.md. |
| `concept_id` | `integer` | нет | concept id; see table constraints and DATA_MODEL.md. |
| `clinical_status` | `text` | нет | clinical status; see table constraints and DATA_MODEL.md. |
| `verification_status` | `text` | нет | verification status; see table constraints and DATA_MODEL.md. |
| `onset_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `abatement_at` | `timestamp with time zone` | да | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `rank` | `smallint` | да | rank; see table constraints and DATA_MODEL.md. |
| `recorded_by` | `bigint` | нет | recorded by; see table constraints and DATA_MODEL.md. |

Ограничения:

- `condition_check`: `CHECK (((abatement_at IS NULL) OR (abatement_at >= onset_at)))`
- `condition_clinical_status_check`: `CHECK ((clinical_status = ANY (ARRAY['active'::text, 'resolved'::text, 'remission'::text])))`
- `condition_clinical_status_not_null`: `NOT NULL clinical_status`
- `condition_concept_id_fkey`: `FOREIGN KEY (concept_id) REFERENCES ref.concept(id)`
- `condition_concept_id_not_null`: `NOT NULL concept_id`
- `condition_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `condition_id_not_null`: `NOT NULL id`
- `condition_onset_at_not_null`: `NOT NULL onset_at`
- `condition_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `condition_patient_id_not_null`: `NOT NULL patient_id`
- `condition_pkey`: `PRIMARY KEY (id)`
- `condition_rank_check`: `CHECK ((rank > 0))`
- `condition_recorded_by_fkey`: `FOREIGN KEY (recorded_by) REFERENCES org.staff(id)`
- `condition_recorded_by_not_null`: `NOT NULL recorded_by`
- `condition_verification_status_check`: `CHECK ((verification_status = ANY (ARRAY['provisional'::text, 'confirmed'::text, 'refuted'::text])))`
- `condition_verification_status_not_null`: `NOT NULL verification_status`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.condition FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.condition FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('recorded_by')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.condition FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## ehr.death_record

Hospital reference model / ehr / death record. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 1. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | да | encounter id; see table constraints and DATA_MODEL.md. |
| `death_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `certified_by` | `bigint` | нет | certified by; see table constraints and DATA_MODEL.md. |
| `cause_concept_id` | `integer` | да | cause concept id; see table constraints and DATA_MODEL.md. |
| `certificate_number` | `text` | нет | certificate number; see table constraints and DATA_MODEL.md. |

Ограничения:

- `death_record_cause_concept_id_fkey`: `FOREIGN KEY (cause_concept_id) REFERENCES ref.concept(id)`
- `death_record_certificate_number_key`: `UNIQUE (certificate_number)`
- `death_record_certificate_number_not_null`: `NOT NULL certificate_number`
- `death_record_certified_by_fkey`: `FOREIGN KEY (certified_by) REFERENCES org.staff(id)`
- `death_record_certified_by_not_null`: `NOT NULL certified_by`
- `death_record_death_at_not_null`: `NOT NULL death_at`
- `death_record_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `death_record_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `death_record_patient_id_not_null`: `NOT NULL patient_id`
- `death_record_pkey`: `PRIMARY KEY (patient_id)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.death_record FOR EACH ROW EXECUTE FUNCTION audit.capture_change('patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.death_record FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## ehr.document

Hospital reference model / ehr / document. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 10,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | да | encounter id; see table constraints and DATA_MODEL.md. |
| `document_type` | `text` | нет | document type; see table constraints and DATA_MODEL.md. |
| `storage_uri` | `text` | нет | storage uri; see table constraints and DATA_MODEL.md. |
| `media_type` | `text` | нет | media type; see table constraints and DATA_MODEL.md. |
| `size_bytes` | `bigint` | нет | size bytes; see table constraints and DATA_MODEL.md. |
| `sha256` | `bytea` | нет | sha256; see table constraints and DATA_MODEL.md. |
| `created_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `author_id` | `bigint` | нет | author id; see table constraints and DATA_MODEL.md. |

Ограничения:

- `document_author_id_fkey`: `FOREIGN KEY (author_id) REFERENCES org.staff(id)`
- `document_author_id_not_null`: `NOT NULL author_id`
- `document_created_at_not_null`: `NOT NULL created_at`
- `document_document_type_not_null`: `NOT NULL document_type`
- `document_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `document_id_not_null`: `NOT NULL id`
- `document_media_type_not_null`: `NOT NULL media_type`
- `document_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `document_patient_id_not_null`: `NOT NULL patient_id`
- `document_pkey`: `PRIMARY KEY (id)`
- `document_sha256_check`: `CHECK ((octet_length(sha256) = 32))`
- `document_sha256_not_null`: `NOT NULL sha256`
- `document_size_bytes_check`: `CHECK ((size_bytes > 0))`
- `document_size_bytes_not_null`: `NOT NULL size_bytes`
- `document_storage_uri_key`: `UNIQUE (storage_uri)`
- `document_storage_uri_not_null`: `NOT NULL storage_uri`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.document FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.document FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## ehr.encounter

Hospital reference model / ehr / encounter. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 330,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `public_id` | `uuid` | нет | Opaque UUID for external references; does not confer authorization. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `type_code` | `text` | нет | type code; see table constraints and DATA_MODEL.md. |
| `department_id` | `bigint` | нет | department id; see table constraints and DATA_MODEL.md. |
| `attending_staff_id` | `bigint` | нет | attending staff id; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `started_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `ended_at` | `timestamp with time zone` | да | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `chief_complaint` | `text` | да | chief complaint; see table constraints and DATA_MODEL.md. |
| `created_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `updated_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `row_version` | `bigint` | нет | row version; see table constraints and DATA_MODEL.md. |

Ограничения:

- `encounter_attending_staff_id_fkey`: `FOREIGN KEY (attending_staff_id) REFERENCES org.staff(id)`
- `encounter_attending_staff_id_not_null`: `NOT NULL attending_staff_id`
- `encounter_check`: `CHECK (((ended_at IS NULL) OR (ended_at > started_at)))`
- `encounter_check1`: `CHECK (((status <> 'finished'::text) OR (ended_at IS NOT NULL)))`
- `encounter_check2`: `CHECK (((status <> 'in-progress'::text) OR (ended_at IS NULL)))`
- `encounter_created_at_not_null`: `NOT NULL created_at`
- `encounter_department_id_fkey`: `FOREIGN KEY (department_id) REFERENCES org.department(id)`
- `encounter_department_id_not_null`: `NOT NULL department_id`
- `encounter_id_not_null`: `NOT NULL id`
- `encounter_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `encounter_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `encounter_patient_id_not_null`: `NOT NULL patient_id`
- `encounter_pkey`: `PRIMARY KEY (id)`
- `encounter_public_id_key`: `UNIQUE (public_id)`
- `encounter_public_id_not_null`: `NOT NULL public_id`
- `encounter_row_version_not_null`: `NOT NULL row_version`
- `encounter_started_at_not_null`: `NOT NULL started_at`
- `encounter_status_check`: `CHECK ((status = ANY (ARRAY['planned'::text, 'in-progress'::text, 'finished'::text, 'cancelled'::text])))`
- `encounter_status_not_null`: `NOT NULL status`
- `encounter_type_code_fkey`: `FOREIGN KEY (type_code) REFERENCES ref.encounter_type(code)`
- `encounter_type_code_not_null`: `NOT NULL type_code`
- `encounter_updated_at_not_null`: `NOT NULL updated_at`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.encounter FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER encounter_guard BEFORE INSERT OR UPDATE ON ehr.encounter FOR EACH ROW EXECUTE FUNCTION ehr.guard_encounter()`
- `CREATE TRIGGER encounter_touch BEFORE UPDATE ON ehr.encounter FOR EACH ROW EXECUTE FUNCTION ops.touch_row()`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.encounter FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## ehr.encounter_participant

Hospital reference model / ehr / encounter participant. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 330,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `encounter_id` | `bigint` | нет | encounter id; see table constraints and DATA_MODEL.md. |
| `staff_id` | `bigint` | нет | staff id; see table constraints and DATA_MODEL.md. |
| `role_code` | `text` | нет | role code; see table constraints and DATA_MODEL.md. |
| `participation_period` | `tstzrange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |

Ограничения:

- `encounter_participant_encounter_id_fkey`: `FOREIGN KEY (encounter_id) REFERENCES ehr.encounter(id)`
- `encounter_participant_encounter_id_not_null`: `NOT NULL encounter_id`
- `encounter_participant_participation_period_check`: `CHECK ((NOT isempty(participation_period)))`
- `encounter_participant_participation_period_not_null`: `NOT NULL participation_period`
- `encounter_participant_pkey`: `PRIMARY KEY (encounter_id, staff_id, role_code)`
- `encounter_participant_role_code_not_null`: `NOT NULL role_code`
- `encounter_participant_staff_id_fkey`: `FOREIGN KEY (staff_id) REFERENCES org.staff(id)`
- `encounter_participant_staff_id_not_null`: `NOT NULL staff_id`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.encounter_participant FOR EACH ROW EXECUTE FUNCTION audit.capture_change('encounter_id', 'role_code', 'staff_id')`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `(EXISTS ( SELECT
   FROM ehr.encounter e
  WHERE (e.id = encounter_participant.encounter_id)))`, WITH CHECK `None`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## ehr.immunization

Hospital reference model / ehr / immunization. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 10,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | нет | encounter id; see table constraints and DATA_MODEL.md. |
| `vaccine_concept_id` | `integer` | нет | vaccine concept id; see table constraints and DATA_MODEL.md. |
| `occurred_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `lot_number` | `text` | да | lot number; see table constraints and DATA_MODEL.md. |
| `performer_id` | `bigint` | нет | performer id; see table constraints and DATA_MODEL.md. |

Ограничения:

- `immunization_encounter_id_not_null`: `NOT NULL encounter_id`
- `immunization_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `immunization_id_not_null`: `NOT NULL id`
- `immunization_occurred_at_not_null`: `NOT NULL occurred_at`
- `immunization_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `immunization_patient_id_not_null`: `NOT NULL patient_id`
- `immunization_performer_id_fkey`: `FOREIGN KEY (performer_id) REFERENCES org.staff(id)`
- `immunization_performer_id_not_null`: `NOT NULL performer_id`
- `immunization_pkey`: `PRIMARY KEY (id)`
- `immunization_status_check`: `CHECK ((status = ANY (ARRAY['completed'::text, 'not-done'::text, 'entered-in-error'::text])))`
- `immunization_status_not_null`: `NOT NULL status`
- `immunization_vaccine_concept_id_fkey`: `FOREIGN KEY (vaccine_concept_id) REFERENCES ref.concept(id)`
- `immunization_vaccine_concept_id_not_null`: `NOT NULL vaccine_concept_id`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.immunization FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.immunization FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## ehr.note_version

Append a new version to amend a signed note. Signed versions cannot be updated/deleted. SHA-256 detects body differences; it is not a qualified electronic signature.

Строк: 330,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `note_id` | `bigint` | нет | note id; see table constraints and DATA_MODEL.md. |
| `version` | `integer` | нет | version; see table constraints and DATA_MODEL.md. |
| `body` | `ref.nonblank_text` | нет | body; see table constraints and DATA_MODEL.md. |
| `created_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `author_id` | `bigint` | нет | author id; see table constraints and DATA_MODEL.md. |
| `signed_at` | `timestamp with time zone` | да | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `signed_by` | `bigint` | да | signed by; see table constraints and DATA_MODEL.md. |
| `supersedes_version` | `integer` | да | supersedes version; see table constraints and DATA_MODEL.md. |
| `amendment_reason` | `text` | да | amendment reason; see table constraints and DATA_MODEL.md. |
| `body_sha256` | `bytea` | да | body sha256; see table constraints and DATA_MODEL.md. |

Ограничения:

- `note_version_author_id_fkey`: `FOREIGN KEY (author_id) REFERENCES org.staff(id)`
- `note_version_author_id_not_null`: `NOT NULL author_id`
- `note_version_body_not_null`: `NOT NULL body`
- `note_version_check`: `CHECK (((signed_at IS NULL) = (signed_by IS NULL)))`
- `note_version_check1`: `CHECK (((signed_at IS NULL) OR (signed_at >= created_at)))`
- `note_version_check2`: `CHECK ((((version = 1) AND (supersedes_version IS NULL)) OR ((version > 1) AND (supersedes_version = (version - 1)) AND (amendment_reason IS NOT NULL))))`
- `note_version_created_at_not_null`: `NOT NULL created_at`
- `note_version_note_id_fkey`: `FOREIGN KEY (note_id) REFERENCES ehr.clinical_note(id)`
- `note_version_note_id_not_null`: `NOT NULL note_id`
- `note_version_note_id_supersedes_version_fkey`: `FOREIGN KEY (note_id, supersedes_version) REFERENCES ehr.note_version(note_id, version)`
- `note_version_pkey`: `PRIMARY KEY (note_id, version)`
- `note_version_signed_by_fkey`: `FOREIGN KEY (signed_by) REFERENCES org.staff(id)`
- `note_version_version_check`: `CHECK ((version > 0))`
- `note_version_version_not_null`: `NOT NULL version`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.note_version FOR EACH ROW EXECUTE FUNCTION audit.capture_change('note_id', 'version')`
- `CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.note_version FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('author_id')`
- `CREATE TRIGGER signed_note_immutable BEFORE DELETE OR UPDATE ON ehr.note_version FOR EACH ROW EXECUTE FUNCTION ehr.guard_note_version()`
- `CREATE TRIGGER signer_identity BEFORE INSERT OR UPDATE ON ehr.note_version FOR EACH ROW EXECUTE FUNCTION ehr.guard_signer()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `(EXISTS ( SELECT
   FROM ehr.clinical_note n
  WHERE (n.id = note_version.note_id)))`, WITH CHECK `(EXISTS ( SELECT
   FROM ehr.clinical_note n
  WHERE (n.id = note_version.note_id)))`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## ehr.observation

Typed clinical measurements, monthly RANGE partitions 2024–2027; exactly one value, unit checked against catalog. Partition key is part of primary key.

Строк: 1,320,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | нет | encounter id; see table constraints and DATA_MODEL.md. |
| `test_id` | `integer` | нет | test id; see table constraints and DATA_MODEL.md. |
| `observed_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `value_numeric` | `numeric(18,4)` | да | value numeric; see table constraints and DATA_MODEL.md. |
| `value_text` | `text` | да | value text; see table constraints and DATA_MODEL.md. |
| `value_concept_id` | `integer` | да | value concept id; see table constraints and DATA_MODEL.md. |
| `value_boolean` | `boolean` | да | value boolean; see table constraints and DATA_MODEL.md. |
| `unit_code` | `text` | да | unit code; see table constraints and DATA_MODEL.md. |
| `recorded_by` | `bigint` | нет | recorded by; see table constraints and DATA_MODEL.md. |

Ограничения:

- `observation_check`: `CHECK ((num_nonnulls(value_numeric, value_text, value_concept_id, value_boolean) = 1))`
- `observation_check1`: `CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL)))`
- `observation_encounter_id_not_null`: `NOT NULL encounter_id`
- `observation_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `observation_id_not_null`: `NOT NULL id`
- `observation_observed_at_not_null`: `NOT NULL observed_at`
- `observation_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `observation_patient_id_not_null`: `NOT NULL patient_id`
- `observation_pkey`: `PRIMARY KEY (id, observed_at)`
- `observation_recorded_by_fkey`: `FOREIGN KEY (recorded_by) REFERENCES org.staff(id)`
- `observation_recorded_by_not_null`: `NOT NULL recorded_by`
- `observation_status_check`: `CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))`
- `observation_status_not_null`: `NOT NULL status`
- `observation_test_id_fkey`: `FOREIGN KEY (test_id) REFERENCES ref.test(id)`
- `observation_test_id_not_null`: `NOT NULL test_id`
- `observation_unit_code_fkey`: `FOREIGN KEY (unit_code) REFERENCES ref.unit(code)`
- `observation_value_concept_id_fkey`: `FOREIGN KEY (value_concept_id) REFERENCES ref.concept(id)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.observation FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'observed_at', 'patient_id')`
- `CREATE TRIGGER author_identity BEFORE INSERT OR UPDATE ON ehr.observation FOR EACH ROW EXECUTE FUNCTION ehr.guard_clinical_author('recorded_by')`
- `CREATE TRIGGER observation_type_guard BEFORE INSERT OR UPDATE ON ehr.observation FOR EACH ROW EXECUTE FUNCTION ehr.guard_observation()`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.observation FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## ehr.procedure

Hospital reference model / ehr / procedure. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 40,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | нет | encounter id; see table constraints and DATA_MODEL.md. |
| `service_id` | `integer` | нет | service id; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `performed_period` | `tstzrange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |
| `performer_id` | `bigint` | нет | performer id; see table constraints and DATA_MODEL.md. |
| `outcome_text` | `text` | да | outcome text; see table constraints and DATA_MODEL.md. |

Ограничения:

- `procedure_encounter_id_not_null`: `NOT NULL encounter_id`
- `procedure_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `procedure_id_not_null`: `NOT NULL id`
- `procedure_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `procedure_patient_id_not_null`: `NOT NULL patient_id`
- `procedure_performed_period_check`: `CHECK ((NOT isempty(performed_period)))`
- `procedure_performed_period_not_null`: `NOT NULL performed_period`
- `procedure_performer_id_fkey`: `FOREIGN KEY (performer_id) REFERENCES org.staff(id)`
- `procedure_performer_id_not_null`: `NOT NULL performer_id`
- `procedure_pkey`: `PRIMARY KEY (id)`
- `procedure_service_id_fkey`: `FOREIGN KEY (service_id) REFERENCES ref.service(id)`
- `procedure_service_id_not_null`: `NOT NULL service_id`
- `procedure_status_check`: `CHECK ((status = ANY (ARRAY['preparation'::text, 'in-progress'::text, 'completed'::text, 'not-done'::text])))`
- `procedure_status_not_null`: `NOT NULL status`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ehr.procedure FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON ehr.procedure FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## iam.access_grant

Patient/purpose/time-limited authorization; keyed to session_user via application_user. Custom session GUCs are not an authorization source.

Строк: 300. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `user_id` | `bigint` | нет | user id; see table constraints and DATA_MODEL.md. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `purpose` | `text` | нет | purpose; see table constraints and DATA_MODEL.md. |
| `valid_during` | `tstzrange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |
| `granted_by` | `bigint` | нет | granted by; see table constraints and DATA_MODEL.md. |
| `reason` | `text` | нет | reason; see table constraints and DATA_MODEL.md. |

Ограничения:

- `access_grant_granted_by_fkey`: `FOREIGN KEY (granted_by) REFERENCES iam.application_user(id)`
- `access_grant_granted_by_not_null`: `NOT NULL granted_by`
- `access_grant_id_not_null`: `NOT NULL id`
- `access_grant_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `access_grant_patient_id_not_null`: `NOT NULL patient_id`
- `access_grant_pkey`: `PRIMARY KEY (id)`
- `access_grant_purpose_check`: `CHECK ((purpose = ANY (ARRAY['treatment'::text, 'registration'::text, 'billing'::text])))`
- `access_grant_purpose_not_null`: `NOT NULL purpose`
- `access_grant_reason_not_null`: `NOT NULL reason`
- `access_grant_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES iam.application_user(id)`
- `access_grant_user_id_not_null`: `NOT NULL user_id`
- `access_grant_user_id_patient_id_purpose_valid_during_key`: `UNIQUE (user_id, patient_id, purpose, valid_during)`
- `access_grant_valid_during_check`: `CHECK ((NOT isempty(valid_during)))`
- `access_grant_valid_during_not_null`: `NOT NULL valid_during`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON iam.access_grant FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`

Политики доступа:

- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## iam.application_user

Hospital reference model / iam / application user. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 4. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `database_principal` | `name` | нет | database principal; see table constraints and DATA_MODEL.md. |
| `staff_id` | `bigint` | да | staff id; see table constraints and DATA_MODEL.md. |
| `display_name` | `text` | нет | display name; see table constraints and DATA_MODEL.md. |
| `active` | `boolean` | нет | active; see table constraints and DATA_MODEL.md. |

Ограничения:

- `application_user_active_not_null`: `NOT NULL active`
- `application_user_database_principal_key`: `UNIQUE (database_principal)`
- `application_user_database_principal_not_null`: `NOT NULL database_principal`
- `application_user_display_name_not_null`: `NOT NULL display_name`
- `application_user_id_not_null`: `NOT NULL id`
- `application_user_pkey`: `PRIMARY KEY (id)`
- `application_user_staff_id_fkey`: `FOREIGN KEY (staff_id) REFERENCES org.staff(id)`
- `application_user_staff_id_key`: `UNIQUE (staff_id)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON iam.application_user FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## iam.break_glass

Hospital reference model / iam / break glass. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 1. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `user_id` | `bigint` | нет | user id; see table constraints and DATA_MODEL.md. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `reason` | `ref.nonblank_text` | нет | reason; see table constraints and DATA_MODEL.md. |
| `valid_during` | `tstzrange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |
| `approved_by` | `bigint` | нет | approved by; see table constraints and DATA_MODEL.md. |
| `reviewed_at` | `timestamp with time zone` | да | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |

Ограничения:

- `break_glass_approved_by_fkey`: `FOREIGN KEY (approved_by) REFERENCES iam.application_user(id)`
- `break_glass_approved_by_not_null`: `NOT NULL approved_by`
- `break_glass_check`: `CHECK ((user_id <> approved_by))`
- `break_glass_id_not_null`: `NOT NULL id`
- `break_glass_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `break_glass_patient_id_not_null`: `NOT NULL patient_id`
- `break_glass_pkey`: `PRIMARY KEY (id)`
- `break_glass_reason_not_null`: `NOT NULL reason`
- `break_glass_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES iam.application_user(id)`
- `break_glass_user_id_not_null`: `NOT NULL user_id`
- `break_glass_valid_during_check`: `CHECK (((NOT isempty(valid_during)) AND (NOT lower_inf(valid_during)) AND (NOT upper_inf(valid_during)) AND ((upper(valid_during) - lower(valid_during)) <= '01:00:00'::interval)))`
- `break_glass_valid_during_not_null`: `NOT NULL valid_during`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON iam.break_glass FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`

Политики доступа:

- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## iam.business_role

Hospital reference model / iam / business role. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 4. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `name` | `text` | нет | name; see table constraints and DATA_MODEL.md. |

Ограничения:

- `business_role_code_not_null`: `NOT NULL code`
- `business_role_name_not_null`: `NOT NULL name`
- `business_role_pkey`: `PRIMARY KEY (code)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON iam.business_role FOR EACH ROW EXECUTE FUNCTION audit.capture_change('code')`

## iam.user_role

Hospital reference model / iam / user role. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 4. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `user_id` | `bigint` | нет | user id; see table constraints and DATA_MODEL.md. |
| `role_code` | `text` | нет | role code; see table constraints and DATA_MODEL.md. |

Ограничения:

- `user_role_pkey`: `PRIMARY KEY (user_id, role_code)`
- `user_role_role_code_fkey`: `FOREIGN KEY (role_code) REFERENCES iam.business_role(code)`
- `user_role_role_code_not_null`: `NOT NULL role_code`
- `user_role_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES iam.application_user(id)`
- `user_role_user_id_not_null`: `NOT NULL user_id`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON iam.user_role FOR EACH ROW EXECUTE FUNCTION audit.capture_change('role_code', 'user_id')`

## imaging.imaging_order

Hospital reference model / imaging / imaging order. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 40,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | нет | encounter id; see table constraints and DATA_MODEL.md. |
| `service_id` | `integer` | нет | service id; see table constraints and DATA_MODEL.md. |
| `requested_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `requested_by` | `bigint` | нет | requested by; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |

Ограничения:

- `imaging_order_encounter_id_not_null`: `NOT NULL encounter_id`
- `imaging_order_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `imaging_order_id_not_null`: `NOT NULL id`
- `imaging_order_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `imaging_order_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `imaging_order_patient_id_not_null`: `NOT NULL patient_id`
- `imaging_order_pkey`: `PRIMARY KEY (id)`
- `imaging_order_requested_at_not_null`: `NOT NULL requested_at`
- `imaging_order_requested_by_fkey`: `FOREIGN KEY (requested_by) REFERENCES org.staff(id)`
- `imaging_order_requested_by_not_null`: `NOT NULL requested_by`
- `imaging_order_service_id_fkey`: `FOREIGN KEY (service_id) REFERENCES ref.service(id)`
- `imaging_order_service_id_not_null`: `NOT NULL service_id`
- `imaging_order_status_check`: `CHECK ((status = ANY (ARRAY['active'::text, 'completed'::text, 'cancelled'::text])))`
- `imaging_order_status_not_null`: `NOT NULL status`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON imaging.imaging_order FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON imaging.imaging_order FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## imaging.series

Hospital reference model / imaging / series. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 40,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `study_id` | `bigint` | нет | study id; see table constraints and DATA_MODEL.md. |
| `series_instance_uid` | `text` | нет | series instance uid; see table constraints and DATA_MODEL.md. |
| `series_number` | `integer` | нет | series number; see table constraints and DATA_MODEL.md. |
| `instance_count` | `integer` | нет | instance count; see table constraints and DATA_MODEL.md. |
| `storage_uri` | `text` | нет | storage uri; see table constraints and DATA_MODEL.md. |

Ограничения:

- `series_id_not_null`: `NOT NULL id`
- `series_instance_count_check`: `CHECK ((instance_count >= 0))`
- `series_instance_count_not_null`: `NOT NULL instance_count`
- `series_pkey`: `PRIMARY KEY (id)`
- `series_series_instance_uid_key`: `UNIQUE (series_instance_uid)`
- `series_series_instance_uid_not_null`: `NOT NULL series_instance_uid`
- `series_series_number_check`: `CHECK ((series_number > 0))`
- `series_series_number_not_null`: `NOT NULL series_number`
- `series_storage_uri_not_null`: `NOT NULL storage_uri`
- `series_study_id_fkey`: `FOREIGN KEY (study_id) REFERENCES imaging.study(id)`
- `series_study_id_not_null`: `NOT NULL study_id`
- `series_study_id_series_number_key`: `UNIQUE (study_id, series_number)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON imaging.series FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `(EXISTS ( SELECT
   FROM imaging.study s
  WHERE (s.id = series.study_id)))`, WITH CHECK `None`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## imaging.study

Hospital reference model / imaging / study. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 40,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `order_id` | `bigint` | нет | order id; see table constraints and DATA_MODEL.md. |
| `study_instance_uid` | `text` | нет | study instance uid; see table constraints and DATA_MODEL.md. |
| `accession_number` | `text` | нет | accession number; see table constraints and DATA_MODEL.md. |
| `modality` | `text` | нет | modality; see table constraints and DATA_MODEL.md. |
| `started_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `device_id` | `bigint` | нет | device id; see table constraints and DATA_MODEL.md. |
| `report_text` | `text` | да | report text; see table constraints and DATA_MODEL.md. |

Ограничения:

- `study_accession_number_key`: `UNIQUE (accession_number)`
- `study_accession_number_not_null`: `NOT NULL accession_number`
- `study_device_id_fkey`: `FOREIGN KEY (device_id) REFERENCES org.device(id)`
- `study_device_id_not_null`: `NOT NULL device_id`
- `study_id_not_null`: `NOT NULL id`
- `study_modality_check`: `CHECK ((modality = ANY (ARRAY['CT'::text, 'MR'::text, 'US'::text, 'DX'::text])))`
- `study_modality_not_null`: `NOT NULL modality`
- `study_order_id_not_null`: `NOT NULL order_id`
- `study_order_id_patient_id_fkey`: `FOREIGN KEY (order_id, patient_id) REFERENCES imaging.imaging_order(id, patient_id)`
- `study_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `study_patient_id_not_null`: `NOT NULL patient_id`
- `study_pkey`: `PRIMARY KEY (id)`
- `study_started_at_not_null`: `NOT NULL started_at`
- `study_status_check`: `CHECK ((status = ANY (ARRAY['registered'::text, 'available'::text, 'cancelled'::text])))`
- `study_status_not_null`: `NOT NULL status`
- `study_study_instance_uid_key`: `UNIQUE (study_instance_uid)`
- `study_study_instance_uid_not_null`: `NOT NULL study_instance_uid`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON imaging.study FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON imaging.study FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`
- `CREATE TRIGGER study_modality_guard BEFORE INSERT OR UPDATE ON imaging.study FOR EACH ROW EXECUTE FUNCTION imaging.guard_modality()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## integration.export_job

Hospital reference model / integration / export job. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 1. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `requested_by` | `bigint` | нет | requested by; see table constraints and DATA_MODEL.md. |
| `purpose` | `text` | нет | purpose; see table constraints and DATA_MODEL.md. |
| `requested_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `filter_json` | `jsonb` | нет | filter json; see table constraints and DATA_MODEL.md. |
| `output_uri` | `text` | да | output uri; see table constraints and DATA_MODEL.md. |
| `completed_at` | `timestamp with time zone` | да | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |

Ограничения:

- `export_job_check`: `CHECK (((completed_at IS NULL) OR (completed_at >= requested_at)))`
- `export_job_filter_json_check`: `CHECK ((jsonb_typeof(filter_json) = 'object'::text))`
- `export_job_filter_json_not_null`: `NOT NULL filter_json`
- `export_job_id_not_null`: `NOT NULL id`
- `export_job_pkey`: `PRIMARY KEY (id)`
- `export_job_purpose_not_null`: `NOT NULL purpose`
- `export_job_requested_at_not_null`: `NOT NULL requested_at`
- `export_job_requested_by_fkey`: `FOREIGN KEY (requested_by) REFERENCES iam.application_user(id)`
- `export_job_requested_by_not_null`: `NOT NULL requested_by`
- `export_job_status_check`: `CHECK ((status = ANY (ARRAY['queued'::text, 'running'::text, 'completed'::text, 'failed'::text])))`
- `export_job_status_not_null`: `NOT NULL status`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON integration.export_job FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## integration.external_identifier

Hospital reference model / integration / external identifier. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 2,000. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `resource_type` | `text` | нет | resource type; see table constraints and DATA_MODEL.md. |
| `internal_public_id` | `uuid` | нет | internal public id; see table constraints and DATA_MODEL.md. |
| `system_uri` | `text` | нет | system uri; see table constraints and DATA_MODEL.md. |
| `external_id` | `text` | нет | external id; see table constraints and DATA_MODEL.md. |

Ограничения:

- `external_identifier_external_id_not_null`: `NOT NULL external_id`
- `external_identifier_id_not_null`: `NOT NULL id`
- `external_identifier_internal_public_id_not_null`: `NOT NULL internal_public_id`
- `external_identifier_pkey`: `PRIMARY KEY (id)`
- `external_identifier_resource_type_check`: `CHECK ((resource_type = ANY (ARRAY['Patient'::text, 'Encounter'::text, 'DiagnosticReport'::text, 'MedicationRequest'::text])))`
- `external_identifier_resource_type_internal_public_id_system_key`: `UNIQUE (resource_type, internal_public_id, system_uri)`
- `external_identifier_resource_type_not_null`: `NOT NULL resource_type`
- `external_identifier_resource_type_system_uri_external_id_key`: `UNIQUE (resource_type, system_uri, external_id)`
- `external_identifier_system_uri_not_null`: `NOT NULL system_uri`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON integration.external_identifier FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## integration.inbox

Hospital reference model / integration / inbox. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 2,000. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `source` | `text` | нет | source; see table constraints and DATA_MODEL.md. |
| `message_id` | `text` | нет | message id; see table constraints and DATA_MODEL.md. |
| `received_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `payload_sha256` | `bytea` | нет | payload sha256; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `processed_at` | `timestamp with time zone` | да | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `error_text` | `text` | да | error text; see table constraints and DATA_MODEL.md. |

Ограничения:

- `inbox_message_id_not_null`: `NOT NULL message_id`
- `inbox_payload_sha256_check`: `CHECK ((octet_length(payload_sha256) = 32))`
- `inbox_payload_sha256_not_null`: `NOT NULL payload_sha256`
- `inbox_pkey`: `PRIMARY KEY (source, message_id)`
- `inbox_received_at_not_null`: `NOT NULL received_at`
- `inbox_source_not_null`: `NOT NULL source`
- `inbox_status_check`: `CHECK ((status = ANY (ARRAY['received'::text, 'processed'::text, 'failed'::text])))`
- `inbox_status_not_null`: `NOT NULL status`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON integration.inbox FOR EACH ROW EXECUTE FUNCTION audit.capture_change('message_id', 'source')`

## integration.outbox

Transactional outbox envelope; use SELECT FOR UPDATE SKIP LOCKED in a short transaction; delivery requires an external worker.

Строк: 2,000. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `event_id` | `uuid` | нет | event id; see table constraints and DATA_MODEL.md. |
| `aggregate_type` | `text` | нет | aggregate type; see table constraints and DATA_MODEL.md. |
| `aggregate_id` | `text` | нет | aggregate id; see table constraints and DATA_MODEL.md. |
| `event_type` | `text` | нет | event type; see table constraints and DATA_MODEL.md. |
| `payload` | `jsonb` | нет | payload; see table constraints and DATA_MODEL.md. |
| `created_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `published_at` | `timestamp with time zone` | да | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `attempts` | `integer` | нет | attempts; see table constraints and DATA_MODEL.md. |
| `next_attempt_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `last_error` | `text` | да | last error; see table constraints and DATA_MODEL.md. |

Ограничения:

- `outbox_aggregate_id_not_null`: `NOT NULL aggregate_id`
- `outbox_aggregate_type_not_null`: `NOT NULL aggregate_type`
- `outbox_attempts_check`: `CHECK ((attempts >= 0))`
- `outbox_attempts_not_null`: `NOT NULL attempts`
- `outbox_created_at_not_null`: `NOT NULL created_at`
- `outbox_event_id_key`: `UNIQUE (event_id)`
- `outbox_event_id_not_null`: `NOT NULL event_id`
- `outbox_event_type_not_null`: `NOT NULL event_type`
- `outbox_id_not_null`: `NOT NULL id`
- `outbox_next_attempt_at_not_null`: `NOT NULL next_attempt_at`
- `outbox_payload_check`: `CHECK ((jsonb_typeof(payload) = 'object'::text))`
- `outbox_payload_not_null`: `NOT NULL payload`
- `outbox_pkey`: `PRIMARY KEY (id)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON integration.outbox FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## inventory.item

Hospital reference model / inventory / item. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 40. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `sku` | `text` | нет | sku; see table constraints and DATA_MODEL.md. |
| `name` | `text` | нет | name; see table constraints and DATA_MODEL.md. |
| `medication_id` | `integer` | да | medication id; see table constraints and DATA_MODEL.md. |
| `unit_code` | `text` | нет | unit code; see table constraints and DATA_MODEL.md. |
| `reorder_point` | `numeric(18,4)` | нет | reorder point; see table constraints and DATA_MODEL.md. |

Ограничения:

- `item_id_not_null`: `NOT NULL id`
- `item_medication_id_fkey`: `FOREIGN KEY (medication_id) REFERENCES ref.medication(id)`
- `item_medication_id_key`: `UNIQUE (medication_id)`
- `item_name_not_null`: `NOT NULL name`
- `item_pkey`: `PRIMARY KEY (id)`
- `item_reorder_point_check`: `CHECK ((reorder_point >= (0)::numeric))`
- `item_reorder_point_not_null`: `NOT NULL reorder_point`
- `item_sku_key`: `UNIQUE (sku)`
- `item_sku_not_null`: `NOT NULL sku`
- `item_unit_code_fkey`: `FOREIGN KEY (unit_code) REFERENCES ref.unit(code)`
- `item_unit_code_not_null`: `NOT NULL unit_code`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.item FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## inventory.location

Hospital reference model / inventory / location. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 2. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `department_id` | `bigint` | нет | department id; see table constraints and DATA_MODEL.md. |
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `name` | `text` | нет | name; see table constraints and DATA_MODEL.md. |

Ограничения:

- `location_code_key`: `UNIQUE (code)`
- `location_code_not_null`: `NOT NULL code`
- `location_department_id_fkey`: `FOREIGN KEY (department_id) REFERENCES org.department(id)`
- `location_department_id_not_null`: `NOT NULL department_id`
- `location_id_not_null`: `NOT NULL id`
- `location_name_not_null`: `NOT NULL name`
- `location_pkey`: `PRIMARY KEY (id)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.location FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## inventory.lot

Hospital reference model / inventory / lot. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 40. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `item_id` | `bigint` | нет | item id; see table constraints and DATA_MODEL.md. |
| `lot_number` | `text` | нет | lot number; see table constraints and DATA_MODEL.md. |
| `expires_on` | `date` | нет | expires on; see table constraints and DATA_MODEL.md. |
| `supplier_id` | `bigint` | нет | supplier id; see table constraints and DATA_MODEL.md. |
| `received_on` | `date` | нет | received on; see table constraints and DATA_MODEL.md. |

Ограничения:

- `lot_check`: `CHECK ((expires_on > received_on))`
- `lot_expires_on_not_null`: `NOT NULL expires_on`
- `lot_id_item_id_key`: `UNIQUE (id, item_id)`
- `lot_id_not_null`: `NOT NULL id`
- `lot_item_id_fkey`: `FOREIGN KEY (item_id) REFERENCES inventory.item(id)`
- `lot_item_id_lot_number_key`: `UNIQUE (item_id, lot_number)`
- `lot_item_id_not_null`: `NOT NULL item_id`
- `lot_lot_number_not_null`: `NOT NULL lot_number`
- `lot_pkey`: `PRIMARY KEY (id)`
- `lot_received_on_not_null`: `NOT NULL received_on`
- `lot_supplier_id_fkey`: `FOREIGN KEY (supplier_id) REFERENCES inventory.supplier(id)`
- `lot_supplier_id_not_null`: `NOT NULL supplier_id`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.lot FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## inventory.purchase_order

Hospital reference model / inventory / purchase order. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 10. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `order_number` | `text` | нет | order number; see table constraints and DATA_MODEL.md. |
| `supplier_id` | `bigint` | нет | supplier id; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `ordered_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `currency_code` | `character(3)` | нет | currency code; see table constraints and DATA_MODEL.md. |

Ограничения:

- `purchase_order_currency_code_fkey`: `FOREIGN KEY (currency_code) REFERENCES ref.currency(code)`
- `purchase_order_currency_code_not_null`: `NOT NULL currency_code`
- `purchase_order_id_not_null`: `NOT NULL id`
- `purchase_order_order_number_key`: `UNIQUE (order_number)`
- `purchase_order_order_number_not_null`: `NOT NULL order_number`
- `purchase_order_ordered_at_not_null`: `NOT NULL ordered_at`
- `purchase_order_pkey`: `PRIMARY KEY (id)`
- `purchase_order_status_check`: `CHECK ((status = ANY (ARRAY['draft'::text, 'approved'::text, 'received'::text, 'cancelled'::text])))`
- `purchase_order_status_not_null`: `NOT NULL status`
- `purchase_order_supplier_id_fkey`: `FOREIGN KEY (supplier_id) REFERENCES inventory.supplier(id)`
- `purchase_order_supplier_id_not_null`: `NOT NULL supplier_id`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.purchase_order FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## inventory.purchase_order_line

Hospital reference model / inventory / purchase order line. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 40. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `order_id` | `bigint` | нет | order id; see table constraints and DATA_MODEL.md. |
| `line_no` | `integer` | нет | line no; see table constraints and DATA_MODEL.md. |
| `item_id` | `bigint` | нет | item id; see table constraints and DATA_MODEL.md. |
| `quantity` | `ref.positive_quantity` | нет | quantity; see table constraints and DATA_MODEL.md. |
| `unit_price` | `ref.nonnegative_money` | нет | unit price; see table constraints and DATA_MODEL.md. |

Ограничения:

- `purchase_order_line_item_id_fkey`: `FOREIGN KEY (item_id) REFERENCES inventory.item(id)`
- `purchase_order_line_item_id_not_null`: `NOT NULL item_id`
- `purchase_order_line_line_no_check`: `CHECK ((line_no > 0))`
- `purchase_order_line_line_no_not_null`: `NOT NULL line_no`
- `purchase_order_line_order_id_fkey`: `FOREIGN KEY (order_id) REFERENCES inventory.purchase_order(id)`
- `purchase_order_line_order_id_not_null`: `NOT NULL order_id`
- `purchase_order_line_pkey`: `PRIMARY KEY (order_id, line_no)`
- `purchase_order_line_quantity_not_null`: `NOT NULL quantity`
- `purchase_order_line_unit_price_not_null`: `NOT NULL unit_price`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.purchase_order_line FOR EACH ROW EXECUTE FUNCTION audit.capture_change('line_no', 'order_id')`

## inventory.stock_balance

Hospital reference model / inventory / stock balance. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 40. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `location_id` | `bigint` | нет | location id; see table constraints and DATA_MODEL.md. |
| `lot_id` | `bigint` | нет | lot id; see table constraints and DATA_MODEL.md. |
| `quantity` | `numeric(18,4)` | нет | quantity; see table constraints and DATA_MODEL.md. |
| `updated_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |

Ограничения:

- `stock_balance_location_id_fkey`: `FOREIGN KEY (location_id) REFERENCES inventory.location(id)`
- `stock_balance_location_id_not_null`: `NOT NULL location_id`
- `stock_balance_lot_id_fkey`: `FOREIGN KEY (lot_id) REFERENCES inventory.lot(id)`
- `stock_balance_lot_id_not_null`: `NOT NULL lot_id`
- `stock_balance_pkey`: `PRIMARY KEY (location_id, lot_id)`
- `stock_balance_quantity_check`: `CHECK ((quantity >= (0)::numeric))`
- `stock_balance_quantity_not_null`: `NOT NULL quantity`
- `stock_balance_updated_at_not_null`: `NOT NULL updated_at`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.stock_balance FOR EACH ROW EXECUTE FUNCTION audit.capture_change('location_id', 'lot_id')`

## inventory.stock_movement

Append-only inventory ledger. A per-location/lot balance is updated under row lock; negative stock rolls back the movement and dispensing transaction.

Строк: 90,040. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `location_id` | `bigint` | нет | location id; see table constraints and DATA_MODEL.md. |
| `lot_id` | `bigint` | нет | lot id; see table constraints and DATA_MODEL.md. |
| `quantity_delta` | `numeric(18,4)` | нет | quantity delta; see table constraints and DATA_MODEL.md. |
| `movement_type` | `text` | нет | movement type; see table constraints and DATA_MODEL.md. |
| `occurred_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `recorded_by` | `bigint` | нет | recorded by; see table constraints and DATA_MODEL.md. |
| `dispense_id` | `bigint` | да | dispense id; see table constraints and DATA_MODEL.md. |
| `idempotency_key` | `uuid` | нет | idempotency key; see table constraints and DATA_MODEL.md. |
| `reason` | `ref.nonblank_text` | нет | reason; see table constraints and DATA_MODEL.md. |

Ограничения:

- `stock_movement_check`: `CHECK ((((movement_type = ANY (ARRAY['receipt'::text, 'transfer-in'::text])) AND (quantity_delta > (0)::numeric)) OR ((movement_type = ANY (ARRAY['dispense'::text, 'transfer-out'::text])) AND (quantity_delta < (0)::numeric)) OR (movement_type = 'adjustment'::text)))`
- `stock_movement_check1`: `CHECK (((movement_type = 'dispense'::text) = (dispense_id IS NOT NULL)))`
- `stock_movement_dispense_id_fkey`: `FOREIGN KEY (dispense_id) REFERENCES pharmacy.dispense(id)`
- `stock_movement_dispense_id_key`: `UNIQUE (dispense_id)`
- `stock_movement_id_not_null`: `NOT NULL id`
- `stock_movement_idempotency_key_key`: `UNIQUE (idempotency_key)`
- `stock_movement_idempotency_key_not_null`: `NOT NULL idempotency_key`
- `stock_movement_location_id_fkey`: `FOREIGN KEY (location_id) REFERENCES inventory.location(id)`
- `stock_movement_location_id_not_null`: `NOT NULL location_id`
- `stock_movement_lot_id_fkey`: `FOREIGN KEY (lot_id) REFERENCES inventory.lot(id)`
- `stock_movement_lot_id_not_null`: `NOT NULL lot_id`
- `stock_movement_movement_type_check`: `CHECK ((movement_type = ANY (ARRAY['receipt'::text, 'dispense'::text, 'adjustment'::text, 'transfer-in'::text, 'transfer-out'::text])))`
- `stock_movement_movement_type_not_null`: `NOT NULL movement_type`
- `stock_movement_occurred_at_not_null`: `NOT NULL occurred_at`
- `stock_movement_pkey`: `PRIMARY KEY (id)`
- `stock_movement_quantity_delta_check`: `CHECK ((quantity_delta <> (0)::numeric))`
- `stock_movement_quantity_delta_not_null`: `NOT NULL quantity_delta`
- `stock_movement_reason_not_null`: `NOT NULL reason`
- `stock_movement_recorded_by_fkey`: `FOREIGN KEY (recorded_by) REFERENCES org.staff(id)`
- `stock_movement_recorded_by_not_null`: `NOT NULL recorded_by`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.stock_movement FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`
- `CREATE TRIGGER stock_ledger_guard BEFORE INSERT OR DELETE OR UPDATE ON inventory.stock_movement FOR EACH ROW EXECUTE FUNCTION inventory.guard_movement()`

## inventory.supplier

Hospital reference model / inventory / supplier. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 10. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `name` | `text` | нет | name; see table constraints and DATA_MODEL.md. |
| `is_synthetic` | `boolean` | нет | is synthetic; see table constraints and DATA_MODEL.md. |

Ограничения:

- `supplier_code_key`: `UNIQUE (code)`
- `supplier_code_not_null`: `NOT NULL code`
- `supplier_id_not_null`: `NOT NULL id`
- `supplier_is_synthetic_not_null`: `NOT NULL is_synthetic`
- `supplier_name_not_null`: `NOT NULL name`
- `supplier_pkey`: `PRIMARY KEY (id)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON inventory.supplier FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## lab.diagnostic_report

Hospital reference model / lab / diagnostic report. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 120,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `request_id` | `bigint` | нет | request id; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `issued_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `verified_by` | `bigint` | нет | verified by; see table constraints and DATA_MODEL.md. |
| `conclusion_text` | `text` | да | conclusion text; see table constraints and DATA_MODEL.md. |
| `version` | `integer` | нет | version; see table constraints and DATA_MODEL.md. |

Ограничения:

- `diagnostic_report_id_not_null`: `NOT NULL id`
- `diagnostic_report_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `diagnostic_report_issued_at_not_null`: `NOT NULL issued_at`
- `diagnostic_report_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `diagnostic_report_patient_id_not_null`: `NOT NULL patient_id`
- `diagnostic_report_pkey`: `PRIMARY KEY (id)`
- `diagnostic_report_request_id_not_null`: `NOT NULL request_id`
- `diagnostic_report_request_id_patient_id_fkey`: `FOREIGN KEY (request_id, patient_id) REFERENCES lab.service_request(id, patient_id)`
- `diagnostic_report_request_id_version_key`: `UNIQUE (request_id, version)`
- `diagnostic_report_status_check`: `CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text, 'entered-in-error'::text])))`
- `diagnostic_report_status_not_null`: `NOT NULL status`
- `diagnostic_report_verified_by_fkey`: `FOREIGN KEY (verified_by) REFERENCES org.staff(id)`
- `diagnostic_report_verified_by_not_null`: `NOT NULL verified_by`
- `diagnostic_report_version_check`: `CHECK ((version > 0))`
- `diagnostic_report_version_not_null`: `NOT NULL version`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON lab.diagnostic_report FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON lab.diagnostic_report FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## lab.report_result

Versioned diagnostic report membership; composite keys prevent patient mismatch. Further amendment workflow requires application orchestration.

Строк: 360,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `report_id` | `bigint` | нет | report id; see table constraints and DATA_MODEL.md. |
| `result_id` | `bigint` | нет | result id; see table constraints and DATA_MODEL.md. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |

Ограничения:

- `report_result_patient_id_not_null`: `NOT NULL patient_id`
- `report_result_pkey`: `PRIMARY KEY (report_id, result_id)`
- `report_result_report_id_not_null`: `NOT NULL report_id`
- `report_result_report_id_patient_id_fkey`: `FOREIGN KEY (report_id, patient_id) REFERENCES lab.diagnostic_report(id, patient_id)`
- `report_result_result_id_not_null`: `NOT NULL result_id`
- `report_result_result_id_patient_id_fkey`: `FOREIGN KEY (result_id, patient_id) REFERENCES lab.result(id, patient_id)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON lab.report_result FOR EACH ROW EXECUTE FUNCTION audit.capture_change('patient_id', 'report_id', 'result_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON lab.report_result FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`
- `CREATE TRIGGER report_result_guard BEFORE INSERT OR UPDATE ON lab.report_result FOR EACH ROW EXECUTE FUNCTION lab.guard_report_result()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## lab.request_specimen

Hospital reference model / lab / request specimen. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 120,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `request_id` | `bigint` | нет | request id; see table constraints and DATA_MODEL.md. |
| `specimen_id` | `bigint` | нет | specimen id; see table constraints and DATA_MODEL.md. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |

Ограничения:

- `request_specimen_patient_id_not_null`: `NOT NULL patient_id`
- `request_specimen_pkey`: `PRIMARY KEY (request_id, specimen_id)`
- `request_specimen_request_id_not_null`: `NOT NULL request_id`
- `request_specimen_request_id_patient_id_fkey`: `FOREIGN KEY (request_id, patient_id) REFERENCES lab.service_request(id, patient_id)`
- `request_specimen_specimen_id_not_null`: `NOT NULL specimen_id`
- `request_specimen_specimen_id_patient_id_fkey`: `FOREIGN KEY (specimen_id, patient_id) REFERENCES lab.specimen(id, patient_id)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON lab.request_specimen FOR EACH ROW EXECUTE FUNCTION audit.capture_change('patient_id', 'request_id', 'specimen_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON lab.request_specimen FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## lab.result

Hospital reference model / lab / result. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 360,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `specimen_id` | `bigint` | нет | specimen id; see table constraints and DATA_MODEL.md. |
| `test_id` | `integer` | нет | test id; see table constraints and DATA_MODEL.md. |
| `measured_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `value_numeric` | `numeric(18,4)` | да | value numeric; see table constraints and DATA_MODEL.md. |
| `value_text` | `text` | да | value text; see table constraints and DATA_MODEL.md. |
| `unit_code` | `text` | да | unit code; see table constraints and DATA_MODEL.md. |
| `reference_low` | `numeric(18,4)` | да | reference low; see table constraints and DATA_MODEL.md. |
| `reference_high` | `numeric(18,4)` | да | reference high; see table constraints and DATA_MODEL.md. |
| `interpretation` | `text` | да | interpretation; see table constraints and DATA_MODEL.md. |
| `analyzer_id` | `bigint` | да | analyzer id; see table constraints and DATA_MODEL.md. |

Ограничения:

- `result_analyzer_id_fkey`: `FOREIGN KEY (analyzer_id) REFERENCES org.device(id)`
- `result_check`: `CHECK ((num_nonnulls(value_numeric, value_text) = 1))`
- `result_check1`: `CHECK (((value_numeric IS NULL) OR (unit_code IS NOT NULL)))`
- `result_check2`: `CHECK (((reference_low IS NULL) OR (reference_high IS NULL) OR (reference_low <= reference_high)))`
- `result_id_not_null`: `NOT NULL id`
- `result_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `result_interpretation_check`: `CHECK ((interpretation = ANY (ARRAY['N'::text, 'L'::text, 'H'::text, 'critical'::text, 'not-applicable'::text])))`
- `result_measured_at_not_null`: `NOT NULL measured_at`
- `result_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `result_patient_id_not_null`: `NOT NULL patient_id`
- `result_pkey`: `PRIMARY KEY (id)`
- `result_specimen_id_not_null`: `NOT NULL specimen_id`
- `result_specimen_id_patient_id_fkey`: `FOREIGN KEY (specimen_id, patient_id) REFERENCES lab.specimen(id, patient_id)`
- `result_status_check`: `CHECK ((status = ANY (ARRAY['preliminary'::text, 'final'::text, 'amended'::text])))`
- `result_status_not_null`: `NOT NULL status`
- `result_test_id_fkey`: `FOREIGN KEY (test_id) REFERENCES ref.test(id)`
- `result_test_id_not_null`: `NOT NULL test_id`
- `result_unit_code_fkey`: `FOREIGN KEY (unit_code) REFERENCES ref.unit(code)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON lab.result FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON lab.result FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`
- `CREATE TRIGGER result_type_time_guard BEFORE INSERT OR UPDATE ON lab.result FOR EACH ROW EXECUTE FUNCTION lab.guard_result()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## lab.service_request

Hospital reference model / lab / service request. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 120,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | нет | encounter id; see table constraints and DATA_MODEL.md. |
| `service_id` | `integer` | нет | service id; see table constraints and DATA_MODEL.md. |
| `panel_id` | `integer` | да | panel id; see table constraints and DATA_MODEL.md. |
| `ordered_by` | `bigint` | нет | ordered by; see table constraints and DATA_MODEL.md. |
| `ordered_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `priority` | `text` | нет | priority; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |

Ограничения:

- `service_request_encounter_id_not_null`: `NOT NULL encounter_id`
- `service_request_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `service_request_id_not_null`: `NOT NULL id`
- `service_request_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `service_request_ordered_at_not_null`: `NOT NULL ordered_at`
- `service_request_ordered_by_fkey`: `FOREIGN KEY (ordered_by) REFERENCES org.staff(id)`
- `service_request_ordered_by_not_null`: `NOT NULL ordered_by`
- `service_request_panel_id_fkey`: `FOREIGN KEY (panel_id) REFERENCES ref.test_panel(id)`
- `service_request_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `service_request_patient_id_not_null`: `NOT NULL patient_id`
- `service_request_pkey`: `PRIMARY KEY (id)`
- `service_request_priority_check`: `CHECK ((priority = ANY (ARRAY['routine'::text, 'urgent'::text, 'stat'::text])))`
- `service_request_priority_not_null`: `NOT NULL priority`
- `service_request_service_id_fkey`: `FOREIGN KEY (service_id) REFERENCES ref.service(id)`
- `service_request_service_id_not_null`: `NOT NULL service_id`
- `service_request_status_check`: `CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'completed'::text, 'cancelled'::text])))`
- `service_request_status_not_null`: `NOT NULL status`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON lab.service_request FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON lab.service_request FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## lab.specimen

Hospital reference model / lab / specimen. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 120,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `accession_number` | `text` | нет | accession number; see table constraints and DATA_MODEL.md. |
| `type_code` | `text` | нет | type code; see table constraints and DATA_MODEL.md. |
| `collected_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `received_at` | `timestamp with time zone` | да | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `collected_by` | `bigint` | нет | collected by; see table constraints and DATA_MODEL.md. |

Ограничения:

- `specimen_accession_number_key`: `UNIQUE (accession_number)`
- `specimen_accession_number_not_null`: `NOT NULL accession_number`
- `specimen_check`: `CHECK (((received_at IS NULL) OR (received_at >= collected_at)))`
- `specimen_collected_at_not_null`: `NOT NULL collected_at`
- `specimen_collected_by_fkey`: `FOREIGN KEY (collected_by) REFERENCES org.staff(id)`
- `specimen_collected_by_not_null`: `NOT NULL collected_by`
- `specimen_id_not_null`: `NOT NULL id`
- `specimen_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `specimen_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `specimen_patient_id_not_null`: `NOT NULL patient_id`
- `specimen_pkey`: `PRIMARY KEY (id)`
- `specimen_status_check`: `CHECK ((status = ANY (ARRAY['available'::text, 'unavailable'::text, 'unsatisfactory'::text])))`
- `specimen_status_not_null`: `NOT NULL status`
- `specimen_type_code_not_null`: `NOT NULL type_code`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON lab.specimen FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON lab.specimen FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## mpi.address

Hospital reference model / mpi / address. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 120,002. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `use_code` | `text` | нет | use code; see table constraints and DATA_MODEL.md. |
| `country_code` | `character(2)` | нет | country code; see table constraints and DATA_MODEL.md. |
| `city` | `text` | нет | city; see table constraints and DATA_MODEL.md. |
| `line_text` | `text` | нет | line text; see table constraints and DATA_MODEL.md. |
| `postal_code` | `text` | да | postal code; see table constraints and DATA_MODEL.md. |
| `location` | `ext.geography(Point,4326)` | да | location; see table constraints and DATA_MODEL.md. |
| `valid_during` | `daterange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |

Ограничения:

- `address_city_not_null`: `NOT NULL city`
- `address_country_code_not_null`: `NOT NULL country_code`
- `address_id_not_null`: `NOT NULL id`
- `address_line_text_not_null`: `NOT NULL line_text`
- `address_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `address_patient_id_not_null`: `NOT NULL patient_id`
- `address_pkey`: `PRIMARY KEY (id)`
- `address_use_code_check`: `CHECK ((use_code = ANY (ARRAY['home'::text, 'temporary'::text, 'work'::text])))`
- `address_use_code_not_null`: `NOT NULL use_code`
- `address_valid_during_check`: `CHECK ((NOT isempty(valid_during)))`
- `address_valid_during_not_null`: `NOT NULL valid_during`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON mpi.address FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.
- `registrar_access` (hospital_registrar): USING `iam.has_patient_access(patient_id, 'registration'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'registration'::text)`.

## mpi.consent

Hospital reference model / mpi / consent. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 120,002. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `scope` | `text` | нет | scope; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `valid_during` | `tstzrange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |
| `recorded_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `recorded_by` | `bigint` | нет | recorded by; see table constraints and DATA_MODEL.md. |
| `document_reference` | `text` | да | document reference; see table constraints and DATA_MODEL.md. |

Ограничения:

- `consent_id_not_null`: `NOT NULL id`
- `consent_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `consent_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `consent_patient_id_not_null`: `NOT NULL patient_id`
- `consent_pkey`: `PRIMARY KEY (id)`
- `consent_recorded_at_not_null`: `NOT NULL recorded_at`
- `consent_recorded_by_fkey`: `FOREIGN KEY (recorded_by) REFERENCES org.staff(id)`
- `consent_recorded_by_not_null`: `NOT NULL recorded_by`
- `consent_scope_check`: `CHECK ((scope = ANY (ARRAY['treatment'::text, 'data_exchange'::text, 'research'::text])))`
- `consent_scope_not_null`: `NOT NULL scope`
- `consent_status_check`: `CHECK ((status = ANY (ARRAY['active'::text, 'revoked'::text, 'expired'::text])))`
- `consent_status_not_null`: `NOT NULL status`
- `consent_valid_during_check`: `CHECK ((NOT isempty(valid_during)))`
- `consent_valid_during_not_null`: `NOT NULL valid_during`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON mpi.consent FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.
- `registrar_access` (hospital_registrar): USING `iam.has_patient_access(patient_id, 'registration'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'registration'::text)`.

## mpi.contact

Hospital reference model / mpi / contact. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 120,002. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `system` | `text` | нет | system; see table constraints and DATA_MODEL.md. |
| `value` | `text` | нет | value; see table constraints and DATA_MODEL.md. |
| `use_code` | `text` | нет | use code; see table constraints and DATA_MODEL.md. |
| `rank` | `smallint` | нет | rank; see table constraints and DATA_MODEL.md. |

Ограничения:

- `contact_id_not_null`: `NOT NULL id`
- `contact_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `contact_patient_id_not_null`: `NOT NULL patient_id`
- `contact_patient_id_system_rank_key`: `UNIQUE (patient_id, system, rank)`
- `contact_pkey`: `PRIMARY KEY (id)`
- `contact_rank_check`: `CHECK ((rank > 0))`
- `contact_rank_not_null`: `NOT NULL rank`
- `contact_system_check`: `CHECK ((system = ANY (ARRAY['phone'::text, 'email'::text])))`
- `contact_system_not_null`: `NOT NULL system`
- `contact_use_code_not_null`: `NOT NULL use_code`
- `contact_value_not_null`: `NOT NULL value`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON mpi.contact FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.
- `registrar_access` (hospital_registrar): USING `iam.has_patient_access(patient_id, 'registration'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'registration'::text)`.

## mpi.identifier

Hospital reference model / mpi / identifier. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 120,002. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `system_uri` | `text` | нет | system uri; see table constraints and DATA_MODEL.md. |
| `value` | `ref.nonblank_text` | нет | value; see table constraints and DATA_MODEL.md. |
| `valid_during` | `daterange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |

Ограничения:

- `identifier_id_not_null`: `NOT NULL id`
- `identifier_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `identifier_patient_id_not_null`: `NOT NULL patient_id`
- `identifier_pkey`: `PRIMARY KEY (id)`
- `identifier_system_uri_not_null`: `NOT NULL system_uri`
- `identifier_system_uri_value_key`: `UNIQUE (system_uri, value)`
- `identifier_valid_during_check`: `CHECK ((NOT isempty(valid_during)))`
- `identifier_valid_during_not_null`: `NOT NULL valid_during`
- `identifier_value_not_null`: `NOT NULL value`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON mpi.identifier FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.
- `registrar_access` (hospital_registrar): USING `iam.has_patient_access(patient_id, 'registration'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'registration'::text)`.

## mpi.merge_history

Hospital reference model / mpi / merge history. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 1. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `source_patient_id` | `bigint` | нет | source patient id; see table constraints and DATA_MODEL.md. |
| `target_patient_id` | `bigint` | нет | target patient id; see table constraints and DATA_MODEL.md. |
| `merged_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `merged_by` | `bigint` | нет | merged by; see table constraints and DATA_MODEL.md. |
| `reason` | `ref.nonblank_text` | нет | reason; see table constraints and DATA_MODEL.md. |

Ограничения:

- `merge_history_check`: `CHECK ((source_patient_id <> target_patient_id))`
- `merge_history_id_not_null`: `NOT NULL id`
- `merge_history_merged_at_not_null`: `NOT NULL merged_at`
- `merge_history_merged_by_fkey`: `FOREIGN KEY (merged_by) REFERENCES org.staff(id)`
- `merge_history_merged_by_not_null`: `NOT NULL merged_by`
- `merge_history_pkey`: `PRIMARY KEY (id)`
- `merge_history_reason_not_null`: `NOT NULL reason`
- `merge_history_source_patient_id_fkey`: `FOREIGN KEY (source_patient_id) REFERENCES mpi.patient(id)`
- `merge_history_source_patient_id_key`: `UNIQUE (source_patient_id)`
- `merge_history_source_patient_id_not_null`: `NOT NULL source_patient_id`
- `merge_history_target_patient_id_fkey`: `FOREIGN KEY (target_patient_id) REFERENCES mpi.patient(id)`
- `merge_history_target_patient_id_not_null`: `NOT NULL target_patient_id`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON mpi.merge_history FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `(iam.has_patient_access(source_patient_id, 'treatment'::text) AND iam.has_patient_access(target_patient_id, 'treatment'::text))`, WITH CHECK `None`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.
- `registrar_access` (hospital_registrar): USING `(iam.has_patient_access(source_patient_id, 'registration'::text) AND iam.has_patient_access(target_patient_id, 'registration'::text))`, WITH CHECK `None`.

## mpi.patient

Master patient index; synthetic MRN and UUID. No real national identifiers or contact details. Row-level access is deny-by-default.

Строк: 120,002. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `public_id` | `uuid` | нет | Opaque UUID for external references; does not confer authorization. |
| `mrn` | `text` | нет | mrn; see table constraints and DATA_MODEL.md. |
| `family_name` | `ref.nonblank_text` | нет | family name; see table constraints and DATA_MODEL.md. |
| `given_name` | `ref.nonblank_text` | нет | given name; see table constraints and DATA_MODEL.md. |
| `birth_date` | `date` | нет | birth date; see table constraints and DATA_MODEL.md. |
| `administrative_gender` | `text` | нет | administrative gender; see table constraints and DATA_MODEL.md. |
| `deceased_at` | `timestamp with time zone` | да | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `active` | `boolean` | нет | active; see table constraints and DATA_MODEL.md. |
| `is_synthetic` | `boolean` | нет | is synthetic; see table constraints and DATA_MODEL.md. |
| `created_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `updated_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `row_version` | `bigint` | нет | row version; see table constraints and DATA_MODEL.md. |

Ограничения:

- `patient_active_not_null`: `NOT NULL active`
- `patient_administrative_gender_check`: `CHECK ((administrative_gender = ANY (ARRAY['female'::text, 'male'::text, 'other'::text, 'unknown'::text])))`
- `patient_administrative_gender_not_null`: `NOT NULL administrative_gender`
- `patient_birth_date_check`: `CHECK (((birth_date >= '1850-01-01'::date) AND (birth_date <= '2100-01-01'::date)))`
- `patient_birth_date_not_null`: `NOT NULL birth_date`
- `patient_check`: `CHECK (((deceased_at IS NULL) OR ((deceased_at)::date >= birth_date)))`
- `patient_created_at_not_null`: `NOT NULL created_at`
- `patient_family_name_not_null`: `NOT NULL family_name`
- `patient_given_name_not_null`: `NOT NULL given_name`
- `patient_id_not_null`: `NOT NULL id`
- `patient_is_synthetic_not_null`: `NOT NULL is_synthetic`
- `patient_mrn_key`: `UNIQUE (mrn)`
- `patient_mrn_not_null`: `NOT NULL mrn`
- `patient_pkey`: `PRIMARY KEY (id)`
- `patient_public_id_key`: `UNIQUE (public_id)`
- `patient_public_id_not_null`: `NOT NULL public_id`
- `patient_row_version_check`: `CHECK ((row_version > 0))`
- `patient_row_version_not_null`: `NOT NULL row_version`
- `patient_updated_at_not_null`: `NOT NULL updated_at`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON mpi.patient FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`
- `CREATE TRIGGER patient_dates_guard BEFORE UPDATE OF birth_date, deceased_at ON mpi.patient FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_dates()`
- `CREATE TRIGGER patient_touch BEFORE UPDATE ON mpi.patient FOR EACH ROW EXECUTE FUNCTION ops.touch_row()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.
- `registrar_access` (hospital_registrar): USING `iam.has_patient_access(id, 'registration'::text)`, WITH CHECK `iam.has_patient_access(id, 'registration'::text)`.

## mpi.related_person

Hospital reference model / mpi / related person. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 30,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `display_name` | `text` | нет | display name; see table constraints and DATA_MODEL.md. |
| `relationship` | `text` | нет | relationship; see table constraints and DATA_MODEL.md. |
| `contact_text` | `text` | да | contact text; see table constraints and DATA_MODEL.md. |
| `is_emergency_contact` | `boolean` | нет | is emergency contact; see table constraints and DATA_MODEL.md. |

Ограничения:

- `related_person_display_name_not_null`: `NOT NULL display_name`
- `related_person_id_not_null`: `NOT NULL id`
- `related_person_is_emergency_contact_not_null`: `NOT NULL is_emergency_contact`
- `related_person_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `related_person_patient_id_not_null`: `NOT NULL patient_id`
- `related_person_pkey`: `PRIMARY KEY (id)`
- `related_person_relationship_not_null`: `NOT NULL relationship`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON mpi.related_person FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.
- `registrar_access` (hospital_registrar): USING `iam.has_patient_access(patient_id, 'registration'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'registration'::text)`.

## ops.schema_migration

Hospital reference model / ops / schema migration. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 9. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `version` | `text` | нет | version; see table constraints and DATA_MODEL.md. |
| `applied_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `description` | `text` | нет | description; see table constraints and DATA_MODEL.md. |

Ограничения:

- `schema_migration_applied_at_not_null`: `NOT NULL applied_at`
- `schema_migration_description_not_null`: `NOT NULL description`
- `schema_migration_pkey`: `PRIMARY KEY (version)`
- `schema_migration_version_not_null`: `NOT NULL version`

## org.bed

Hospital reference model / org / bed. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 480. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `room_id` | `bigint` | нет | room id; see table constraints and DATA_MODEL.md. |
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `active` | `boolean` | нет | active; see table constraints and DATA_MODEL.md. |
| `bed_type` | `text` | нет | bed type; see table constraints and DATA_MODEL.md. |

Ограничения:

- `bed_active_not_null`: `NOT NULL active`
- `bed_bed_type_check`: `CHECK ((bed_type = ANY (ARRAY['standard'::text, 'icu'::text, 'isolation'::text, 'pediatric'::text])))`
- `bed_bed_type_not_null`: `NOT NULL bed_type`
- `bed_code_key`: `UNIQUE (code)`
- `bed_code_not_null`: `NOT NULL code`
- `bed_id_not_null`: `NOT NULL id`
- `bed_pkey`: `PRIMARY KEY (id)`
- `bed_room_id_fkey`: `FOREIGN KEY (room_id) REFERENCES org.room(id)`
- `bed_room_id_not_null`: `NOT NULL room_id`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.bed FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## org.credential

Hospital reference model / org / credential. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 600. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `staff_id` | `bigint` | нет | staff id; see table constraints and DATA_MODEL.md. |
| `credential_type` | `text` | нет | credential type; see table constraints and DATA_MODEL.md. |
| `identifier` | `text` | нет | identifier; see table constraints and DATA_MODEL.md. |
| `valid_during` | `daterange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |
| `issuer` | `text` | нет | issuer; see table constraints and DATA_MODEL.md. |
| `is_synthetic` | `boolean` | нет | is synthetic; see table constraints and DATA_MODEL.md. |

Ограничения:

- `credential_credential_type_not_null`: `NOT NULL credential_type`
- `credential_id_not_null`: `NOT NULL id`
- `credential_identifier_key`: `UNIQUE (identifier)`
- `credential_identifier_not_null`: `NOT NULL identifier`
- `credential_is_synthetic_not_null`: `NOT NULL is_synthetic`
- `credential_issuer_not_null`: `NOT NULL issuer`
- `credential_pkey`: `PRIMARY KEY (id)`
- `credential_staff_id_fkey`: `FOREIGN KEY (staff_id) REFERENCES org.staff(id)`
- `credential_staff_id_not_null`: `NOT NULL staff_id`
- `credential_valid_during_check`: `CHECK ((NOT isempty(valid_during)))`
- `credential_valid_during_not_null`: `NOT NULL valid_during`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.credential FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## org.department

Hospital reference model / org / department. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 30. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `site_id` | `bigint` | нет | site id; see table constraints and DATA_MODEL.md. |
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `name` | `text` | нет | name; see table constraints and DATA_MODEL.md. |
| `kind` | `text` | нет | kind; see table constraints and DATA_MODEL.md. |
| `active` | `boolean` | нет | active; see table constraints and DATA_MODEL.md. |

Ограничения:

- `department_active_not_null`: `NOT NULL active`
- `department_code_key`: `UNIQUE (code)`
- `department_code_not_null`: `NOT NULL code`
- `department_id_not_null`: `NOT NULL id`
- `department_id_site_id_key`: `UNIQUE (id, site_id)`
- `department_kind_check`: `CHECK ((kind = ANY (ARRAY['clinical'::text, 'diagnostic'::text, 'support'::text])))`
- `department_kind_not_null`: `NOT NULL kind`
- `department_name_not_null`: `NOT NULL name`
- `department_pkey`: `PRIMARY KEY (id)`
- `department_site_id_fkey`: `FOREIGN KEY (site_id) REFERENCES org.site(id)`
- `department_site_id_not_null`: `NOT NULL site_id`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.department FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## org.device

Hospital reference model / org / device. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 90. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `department_id` | `bigint` | нет | department id; see table constraints and DATA_MODEL.md. |
| `asset_tag` | `text` | нет | asset tag; see table constraints and DATA_MODEL.md. |
| `name` | `text` | нет | name; see table constraints and DATA_MODEL.md. |
| `modality` | `text` | да | modality; see table constraints and DATA_MODEL.md. |
| `serial_number` | `text` | да | serial number; see table constraints and DATA_MODEL.md. |
| `active` | `boolean` | нет | active; see table constraints and DATA_MODEL.md. |
| `next_maintenance_on` | `date` | да | next maintenance on; see table constraints and DATA_MODEL.md. |

Ограничения:

- `device_active_not_null`: `NOT NULL active`
- `device_asset_tag_key`: `UNIQUE (asset_tag)`
- `device_asset_tag_not_null`: `NOT NULL asset_tag`
- `device_department_id_fkey`: `FOREIGN KEY (department_id) REFERENCES org.department(id)`
- `device_department_id_not_null`: `NOT NULL department_id`
- `device_id_not_null`: `NOT NULL id`
- `device_name_not_null`: `NOT NULL name`
- `device_pkey`: `PRIMARY KEY (id)`
- `device_serial_number_key`: `UNIQUE (serial_number)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.device FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## org.organization

Hospital reference model / org / organization. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 1. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `public_id` | `uuid` | нет | Opaque UUID for external references; does not confer authorization. |
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `name` | `ref.nonblank_text` | нет | name; see table constraints and DATA_MODEL.md. |
| `kind` | `text` | нет | kind; see table constraints and DATA_MODEL.md. |
| `active` | `boolean` | нет | active; see table constraints and DATA_MODEL.md. |

Ограничения:

- `organization_active_not_null`: `NOT NULL active`
- `organization_code_key`: `UNIQUE (code)`
- `organization_code_not_null`: `NOT NULL code`
- `organization_id_not_null`: `NOT NULL id`
- `organization_kind_check`: `CHECK ((kind = ANY (ARRAY['hospital'::text, 'clinic'::text, 'laboratory'::text])))`
- `organization_kind_not_null`: `NOT NULL kind`
- `organization_name_not_null`: `NOT NULL name`
- `organization_pkey`: `PRIMARY KEY (id)`
- `organization_public_id_key`: `UNIQUE (public_id)`
- `organization_public_id_not_null`: `NOT NULL public_id`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.organization FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## org.room

Hospital reference model / org / room. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 360. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `department_id` | `bigint` | нет | department id; see table constraints and DATA_MODEL.md. |
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `name` | `text` | нет | name; see table constraints and DATA_MODEL.md. |
| `kind` | `text` | нет | kind; see table constraints and DATA_MODEL.md. |
| `floor_number` | `smallint` | нет | floor number; see table constraints and DATA_MODEL.md. |

Ограничения:

- `room_code_not_null`: `NOT NULL code`
- `room_department_id_code_key`: `UNIQUE (department_id, code)`
- `room_department_id_fkey`: `FOREIGN KEY (department_id) REFERENCES org.department(id)`
- `room_department_id_not_null`: `NOT NULL department_id`
- `room_floor_number_not_null`: `NOT NULL floor_number`
- `room_id_department_id_key`: `UNIQUE (id, department_id)`
- `room_id_not_null`: `NOT NULL id`
- `room_kind_check`: `CHECK ((kind = ANY (ARRAY['ward'::text, 'consultation'::text, 'procedure'::text, 'laboratory'::text, 'operating'::text, 'storage'::text])))`
- `room_kind_not_null`: `NOT NULL kind`
- `room_name_not_null`: `NOT NULL name`
- `room_pkey`: `PRIMARY KEY (id)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.room FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## org.site

Hospital reference model / org / site. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 3. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `organization_id` | `bigint` | нет | organization id; see table constraints and DATA_MODEL.md. |
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `name` | `text` | нет | name; see table constraints and DATA_MODEL.md. |
| `time_zone` | `text` | нет | time zone; see table constraints and DATA_MODEL.md. |
| `address_text` | `text` | нет | address text; see table constraints and DATA_MODEL.md. |
| `location` | `ext.geography(Point,4326)` | да | location; see table constraints and DATA_MODEL.md. |

Ограничения:

- `site_address_text_not_null`: `NOT NULL address_text`
- `site_code_key`: `UNIQUE (code)`
- `site_code_not_null`: `NOT NULL code`
- `site_id_not_null`: `NOT NULL id`
- `site_id_organization_id_key`: `UNIQUE (id, organization_id)`
- `site_name_not_null`: `NOT NULL name`
- `site_organization_id_fkey`: `FOREIGN KEY (organization_id) REFERENCES org.organization(id)`
- `site_organization_id_not_null`: `NOT NULL organization_id`
- `site_pkey`: `PRIMARY KEY (id)`
- `site_time_zone_not_null`: `NOT NULL time_zone`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.site FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## org.staff

Hospital reference model / org / staff. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 600. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `staff_number` | `text` | нет | staff number; see table constraints and DATA_MODEL.md. |
| `display_name` | `text` | нет | display name; see table constraints and DATA_MODEL.md. |
| `profession` | `text` | нет | profession; see table constraints and DATA_MODEL.md. |
| `specialty_concept_id` | `integer` | да | specialty concept id; see table constraints and DATA_MODEL.md. |
| `active` | `boolean` | нет | active; see table constraints and DATA_MODEL.md. |

Ограничения:

- `staff_active_not_null`: `NOT NULL active`
- `staff_display_name_not_null`: `NOT NULL display_name`
- `staff_id_not_null`: `NOT NULL id`
- `staff_pkey`: `PRIMARY KEY (id)`
- `staff_profession_check`: `CHECK ((profession = ANY (ARRAY['physician'::text, 'nurse'::text, 'technician'::text, 'pharmacist'::text, 'administrator'::text])))`
- `staff_profession_not_null`: `NOT NULL profession`
- `staff_specialty_concept_id_fkey`: `FOREIGN KEY (specialty_concept_id) REFERENCES ref.concept(id)`
- `staff_staff_number_key`: `UNIQUE (staff_number)`
- `staff_staff_number_not_null`: `NOT NULL staff_number`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.staff FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## org.staff_department

Hospital reference model / org / staff department. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 600. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `staff_id` | `bigint` | нет | staff id; see table constraints and DATA_MODEL.md. |
| `department_id` | `bigint` | нет | department id; see table constraints and DATA_MODEL.md. |
| `valid_during` | `daterange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |
| `is_primary` | `boolean` | нет | is primary; see table constraints and DATA_MODEL.md. |

Ограничения:

- `staff_department_department_id_fkey`: `FOREIGN KEY (department_id) REFERENCES org.department(id)`
- `staff_department_department_id_not_null`: `NOT NULL department_id`
- `staff_department_is_primary_not_null`: `NOT NULL is_primary`
- `staff_department_pkey`: `PRIMARY KEY (staff_id, department_id, valid_during)`
- `staff_department_staff_id_department_id_valid_during_excl`: `EXCLUDE USING gist (staff_id WITH =, department_id WITH =, valid_during WITH &&)`
- `staff_department_staff_id_fkey`: `FOREIGN KEY (staff_id) REFERENCES org.staff(id)`
- `staff_department_staff_id_not_null`: `NOT NULL staff_id`
- `staff_department_valid_during_check`: `CHECK ((NOT isempty(valid_during)))`
- `staff_department_valid_during_not_null`: `NOT NULL valid_during`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON org.staff_department FOR EACH ROW EXECUTE FUNCTION audit.capture_change('department_id', 'staff_id', 'valid_during')`

## pharmacy.administration

Hospital reference model / pharmacy / administration. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 90,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `order_id` | `bigint` | нет | order id; see table constraints and DATA_MODEL.md. |
| `dispense_id` | `bigint` | да | dispense id; see table constraints and DATA_MODEL.md. |
| `administered_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `quantity` | `ref.positive_quantity` | да | quantity; see table constraints and DATA_MODEL.md. |
| `unit_code` | `text` | да | unit code; see table constraints and DATA_MODEL.md. |
| `performed_by` | `bigint` | нет | performed by; see table constraints and DATA_MODEL.md. |
| `note` | `text` | да | note; see table constraints and DATA_MODEL.md. |

Ограничения:

- `administration_administered_at_not_null`: `NOT NULL administered_at`
- `administration_check`: `CHECK (((status <> 'completed'::text) OR ((quantity IS NOT NULL) AND (unit_code IS NOT NULL))))`
- `administration_dispense_id_patient_id_fkey`: `FOREIGN KEY (dispense_id, patient_id) REFERENCES pharmacy.dispense(id, patient_id)`
- `administration_id_not_null`: `NOT NULL id`
- `administration_order_id_not_null`: `NOT NULL order_id`
- `administration_order_id_patient_id_fkey`: `FOREIGN KEY (order_id, patient_id) REFERENCES pharmacy.medication_order(id, patient_id)`
- `administration_patient_id_not_null`: `NOT NULL patient_id`
- `administration_performed_by_fkey`: `FOREIGN KEY (performed_by) REFERENCES org.staff(id)`
- `administration_performed_by_not_null`: `NOT NULL performed_by`
- `administration_pkey`: `PRIMARY KEY (id)`
- `administration_status_check`: `CHECK ((status = ANY (ARRAY['completed'::text, 'not-done'::text, 'entered-in-error'::text])))`
- `administration_status_not_null`: `NOT NULL status`
- `administration_unit_code_fkey`: `FOREIGN KEY (unit_code) REFERENCES ref.unit(code)`

Триггеры:

- `CREATE TRIGGER administration_guard BEFORE INSERT ON pharmacy.administration FOR EACH ROW EXECUTE FUNCTION ehr.guard_administration()`
- `CREATE TRIGGER administration_immutable BEFORE DELETE OR UPDATE ON pharmacy.administration FOR EACH ROW EXECUTE FUNCTION ops.deny_mutation()`
- `CREATE TRIGGER administration_quantity_guard BEFORE INSERT ON pharmacy.administration FOR EACH ROW EXECUTE FUNCTION pharmacy.guard_administration_quantity()`
- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON pharmacy.administration FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON pharmacy.administration FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## pharmacy.dispense

Hospital reference model / pharmacy / dispense. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 90,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `order_id` | `bigint` | нет | order id; see table constraints and DATA_MODEL.md. |
| `medication_id` | `integer` | нет | medication id; see table constraints and DATA_MODEL.md. |
| `item_id` | `bigint` | нет | item id; see table constraints and DATA_MODEL.md. |
| `lot_id` | `bigint` | нет | lot id; see table constraints and DATA_MODEL.md. |
| `location_id` | `bigint` | нет | location id; see table constraints and DATA_MODEL.md. |
| `quantity` | `ref.positive_quantity` | нет | quantity; see table constraints and DATA_MODEL.md. |
| `dispensed_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `dispensed_by` | `bigint` | нет | dispensed by; see table constraints and DATA_MODEL.md. |
| `idempotency_key` | `uuid` | нет | idempotency key; see table constraints and DATA_MODEL.md. |

Ограничения:

- `dispense_dispensed_at_not_null`: `NOT NULL dispensed_at`
- `dispense_dispensed_by_fkey`: `FOREIGN KEY (dispensed_by) REFERENCES org.staff(id)`
- `dispense_dispensed_by_not_null`: `NOT NULL dispensed_by`
- `dispense_id_not_null`: `NOT NULL id`
- `dispense_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `dispense_idempotency_key_key`: `UNIQUE (idempotency_key)`
- `dispense_idempotency_key_not_null`: `NOT NULL idempotency_key`
- `dispense_item_id_not_null`: `NOT NULL item_id`
- `dispense_location_id_fkey`: `FOREIGN KEY (location_id) REFERENCES inventory.location(id)`
- `dispense_location_id_not_null`: `NOT NULL location_id`
- `dispense_lot_id_item_id_fkey`: `FOREIGN KEY (lot_id, item_id) REFERENCES inventory.lot(id, item_id)`
- `dispense_lot_id_not_null`: `NOT NULL lot_id`
- `dispense_medication_id_not_null`: `NOT NULL medication_id`
- `dispense_order_id_not_null`: `NOT NULL order_id`
- `dispense_order_id_patient_id_medication_id_fkey`: `FOREIGN KEY (order_id, patient_id, medication_id) REFERENCES pharmacy.medication_order(id, patient_id, medication_id)`
- `dispense_patient_id_not_null`: `NOT NULL patient_id`
- `dispense_pkey`: `PRIMARY KEY (id)`
- `dispense_quantity_not_null`: `NOT NULL quantity`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON pharmacy.dispense FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER dispense_guard BEFORE INSERT ON pharmacy.dispense FOR EACH ROW EXECUTE FUNCTION pharmacy.guard_dispense()`
- `CREATE TRIGGER dispense_immutable BEFORE DELETE OR UPDATE ON pharmacy.dispense FOR EACH ROW EXECUTE FUNCTION ops.deny_mutation()`
- `CREATE TRIGGER dispense_posts_stock AFTER INSERT ON pharmacy.dispense FOR EACH ROW EXECUTE FUNCTION pharmacy.post_dispense()`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON pharmacy.dispense FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## pharmacy.medication_order

Hospital reference model / pharmacy / medication order. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 90,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | нет | encounter id; see table constraints and DATA_MODEL.md. |
| `medication_id` | `integer` | нет | medication id; see table constraints and DATA_MODEL.md. |
| `ordered_by` | `bigint` | нет | ordered by; see table constraints and DATA_MODEL.md. |
| `ordered_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `route_code` | `text` | нет | route code; see table constraints and DATA_MODEL.md. |
| `instructions` | `text` | нет | instructions; see table constraints and DATA_MODEL.md. |
| `valid_during` | `tstzrange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |

Ограничения:

- `medication_order_encounter_id_not_null`: `NOT NULL encounter_id`
- `medication_order_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `medication_order_id_not_null`: `NOT NULL id`
- `medication_order_id_patient_id_key`: `UNIQUE (id, patient_id)`
- `medication_order_id_patient_id_medication_id_key`: `UNIQUE (id, patient_id, medication_id)`
- `medication_order_instructions_not_null`: `NOT NULL instructions`
- `medication_order_medication_id_fkey`: `FOREIGN KEY (medication_id) REFERENCES ref.medication(id)`
- `medication_order_medication_id_not_null`: `NOT NULL medication_id`
- `medication_order_ordered_at_not_null`: `NOT NULL ordered_at`
- `medication_order_ordered_by_fkey`: `FOREIGN KEY (ordered_by) REFERENCES org.staff(id)`
- `medication_order_ordered_by_not_null`: `NOT NULL ordered_by`
- `medication_order_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `medication_order_patient_id_not_null`: `NOT NULL patient_id`
- `medication_order_pkey`: `PRIMARY KEY (id)`
- `medication_order_route_code_fkey`: `FOREIGN KEY (route_code) REFERENCES ref.route(code)`
- `medication_order_route_code_not_null`: `NOT NULL route_code`
- `medication_order_status_check`: `CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'completed'::text, 'stopped'::text, 'cancelled'::text])))`
- `medication_order_status_not_null`: `NOT NULL status`
- `medication_order_valid_during_check`: `CHECK ((NOT isempty(valid_during)))`
- `medication_order_valid_during_not_null`: `NOT NULL valid_during`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON pharmacy.medication_order FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON pharmacy.medication_order FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## pharmacy.medication_reconciliation

Hospital reference model / pharmacy / medication reconciliation. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 30,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | нет | encounter id; see table constraints and DATA_MODEL.md. |
| `reconciled_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `reconciled_by` | `bigint` | нет | reconciled by; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `note` | `text` | нет | note; see table constraints and DATA_MODEL.md. |

Ограничения:

- `medication_reconciliation_encounter_id_not_null`: `NOT NULL encounter_id`
- `medication_reconciliation_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `medication_reconciliation_id_not_null`: `NOT NULL id`
- `medication_reconciliation_note_not_null`: `NOT NULL note`
- `medication_reconciliation_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `medication_reconciliation_patient_id_not_null`: `NOT NULL patient_id`
- `medication_reconciliation_pkey`: `PRIMARY KEY (id)`
- `medication_reconciliation_reconciled_at_not_null`: `NOT NULL reconciled_at`
- `medication_reconciliation_reconciled_by_fkey`: `FOREIGN KEY (reconciled_by) REFERENCES org.staff(id)`
- `medication_reconciliation_reconciled_by_not_null`: `NOT NULL reconciled_by`
- `medication_reconciliation_status_check`: `CHECK ((status = ANY (ARRAY['in-progress'::text, 'completed'::text])))`
- `medication_reconciliation_status_not_null`: `NOT NULL status`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON pharmacy.medication_reconciliation FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON pharmacy.medication_reconciliation FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## quality.incident

Hospital reference model / quality / incident. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 1,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | да | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | да | encounter id; see table constraints and DATA_MODEL.md. |
| `department_id` | `bigint` | нет | department id; see table constraints and DATA_MODEL.md. |
| `occurred_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `reported_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `reported_by` | `bigint` | нет | reported by; see table constraints and DATA_MODEL.md. |
| `category` | `text` | нет | category; see table constraints and DATA_MODEL.md. |
| `severity` | `text` | нет | severity; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `description` | `text` | нет | description; see table constraints and DATA_MODEL.md. |

Ограничения:

- `incident_category_not_null`: `NOT NULL category`
- `incident_check`: `CHECK ((reported_at >= occurred_at))`
- `incident_check1`: `CHECK (((encounter_id IS NULL) OR (patient_id IS NOT NULL)))`
- `incident_department_id_fkey`: `FOREIGN KEY (department_id) REFERENCES org.department(id)`
- `incident_department_id_not_null`: `NOT NULL department_id`
- `incident_description_not_null`: `NOT NULL description`
- `incident_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `incident_id_not_null`: `NOT NULL id`
- `incident_occurred_at_not_null`: `NOT NULL occurred_at`
- `incident_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `incident_pkey`: `PRIMARY KEY (id)`
- `incident_reported_at_not_null`: `NOT NULL reported_at`
- `incident_reported_by_fkey`: `FOREIGN KEY (reported_by) REFERENCES org.staff(id)`
- `incident_reported_by_not_null`: `NOT NULL reported_by`
- `incident_severity_check`: `CHECK ((severity = ANY (ARRAY['near-miss'::text, 'minor'::text, 'moderate'::text, 'severe'::text])))`
- `incident_severity_not_null`: `NOT NULL severity`
- `incident_status_check`: `CHECK ((status = ANY (ARRAY['open'::text, 'investigating'::text, 'closed'::text])))`
- `incident_status_not_null`: `NOT NULL status`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON quality.incident FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON quality.incident FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## quality.infection_case

Hospital reference model / quality / infection case. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 300. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | нет | encounter id; see table constraints and DATA_MODEL.md. |
| `onset_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `classification` | `text` | нет | classification; see table constraints and DATA_MODEL.md. |
| `organism_concept_id` | `integer` | да | organism concept id; see table constraints and DATA_MODEL.md. |
| `reported_by` | `bigint` | нет | reported by; see table constraints and DATA_MODEL.md. |

Ограничения:

- `infection_case_classification_check`: `CHECK ((classification = ANY (ARRAY['suspected'::text, 'confirmed'::text, 'excluded'::text])))`
- `infection_case_classification_not_null`: `NOT NULL classification`
- `infection_case_encounter_id_not_null`: `NOT NULL encounter_id`
- `infection_case_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `infection_case_id_not_null`: `NOT NULL id`
- `infection_case_onset_at_not_null`: `NOT NULL onset_at`
- `infection_case_organism_concept_id_fkey`: `FOREIGN KEY (organism_concept_id) REFERENCES ref.concept(id)`
- `infection_case_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `infection_case_patient_id_not_null`: `NOT NULL patient_id`
- `infection_case_pkey`: `PRIMARY KEY (id)`
- `infection_case_reported_by_fkey`: `FOREIGN KEY (reported_by) REFERENCES org.staff(id)`
- `infection_case_reported_by_not_null`: `NOT NULL reported_by`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON quality.infection_case FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON quality.infection_case FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## quality.patient_feedback

Hospital reference model / quality / patient feedback. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 20,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `encounter_id` | `bigint` | нет | encounter id; see table constraints and DATA_MODEL.md. |
| `submitted_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `rating` | `smallint` | нет | rating; see table constraints and DATA_MODEL.md. |
| `comment_text` | `text` | да | comment text; see table constraints and DATA_MODEL.md. |

Ограничения:

- `patient_feedback_encounter_id_not_null`: `NOT NULL encounter_id`
- `patient_feedback_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `patient_feedback_id_not_null`: `NOT NULL id`
- `patient_feedback_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `patient_feedback_patient_id_not_null`: `NOT NULL patient_id`
- `patient_feedback_pkey`: `PRIMARY KEY (id)`
- `patient_feedback_rating_check`: `CHECK (((rating >= 1) AND (rating <= 5)))`
- `patient_feedback_rating_not_null`: `NOT NULL rating`
- `patient_feedback_submitted_at_not_null`: `NOT NULL submitted_at`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON quality.patient_feedback FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`
- `CREATE TRIGGER patient_identity_immutable BEFORE UPDATE OF patient_id ON quality.patient_feedback FOR EACH ROW EXECUTE FUNCTION ehr.guard_patient_identity()`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.

## ref.code_system

Hospital reference model / ref / code system. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 4. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `smallint` | нет | Internal immutable surrogate key; identity sequence. |
| `uri` | `text` | нет | uri; see table constraints and DATA_MODEL.md. |
| `name` | `ref.nonblank_text` | нет | name; see table constraints and DATA_MODEL.md. |
| `version` | `text` | нет | version; see table constraints and DATA_MODEL.md. |
| `is_demo` | `boolean` | нет | is demo; see table constraints and DATA_MODEL.md. |

Ограничения:

- `code_system_id_not_null`: `NOT NULL id`
- `code_system_is_demo_not_null`: `NOT NULL is_demo`
- `code_system_name_not_null`: `NOT NULL name`
- `code_system_pkey`: `PRIMARY KEY (id)`
- `code_system_uri_key`: `UNIQUE (uri)`
- `code_system_uri_not_null`: `NOT NULL uri`
- `code_system_version_not_null`: `NOT NULL version`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.code_system FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## ref.concept

Hospital reference model / ref / concept. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 61. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `integer` | нет | Internal immutable surrogate key; identity sequence. |
| `system_id` | `smallint` | нет | system id; see table constraints and DATA_MODEL.md. |
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `display` | `ref.nonblank_text` | нет | display; see table constraints and DATA_MODEL.md. |
| `active` | `boolean` | нет | active; see table constraints and DATA_MODEL.md. |

Ограничения:

- `concept_active_not_null`: `NOT NULL active`
- `concept_code_not_null`: `NOT NULL code`
- `concept_display_not_null`: `NOT NULL display`
- `concept_id_not_null`: `NOT NULL id`
- `concept_pkey`: `PRIMARY KEY (id)`
- `concept_system_id_code_key`: `UNIQUE (system_id, code)`
- `concept_system_id_fkey`: `FOREIGN KEY (system_id) REFERENCES ref.code_system(id)`
- `concept_system_id_not_null`: `NOT NULL system_id`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.concept FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## ref.currency

Hospital reference model / ref / currency. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 1. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `code` | `character(3)` | нет | code; see table constraints and DATA_MODEL.md. |
| `label` | `text` | нет | label; see table constraints and DATA_MODEL.md. |
| `minor_units` | `smallint` | нет | minor units; see table constraints and DATA_MODEL.md. |

Ограничения:

- `currency_code_not_null`: `NOT NULL code`
- `currency_label_not_null`: `NOT NULL label`
- `currency_minor_units_check`: `CHECK (((minor_units >= 0) AND (minor_units <= 4)))`
- `currency_minor_units_not_null`: `NOT NULL minor_units`
- `currency_pkey`: `PRIMARY KEY (code)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.currency FOR EACH ROW EXECUTE FUNCTION audit.capture_change('code')`

## ref.encounter_type

Hospital reference model / ref / encounter type. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 3. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `label` | `text` | нет | label; see table constraints and DATA_MODEL.md. |

Ограничения:

- `encounter_type_code_not_null`: `NOT NULL code`
- `encounter_type_label_not_null`: `NOT NULL label`
- `encounter_type_pkey`: `PRIMARY KEY (code)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.encounter_type FOR EACH ROW EXECUTE FUNCTION audit.capture_change('code')`

## ref.medication

Hospital reference model / ref / medication. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 40. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `integer` | нет | Internal immutable surrogate key; identity sequence. |
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `name` | `text` | нет | name; see table constraints and DATA_MODEL.md. |
| `form` | `text` | нет | form; see table constraints and DATA_MODEL.md. |
| `unit_code` | `text` | нет | unit code; see table constraints and DATA_MODEL.md. |
| `is_demo` | `boolean` | нет | is demo; see table constraints and DATA_MODEL.md. |
| `active` | `boolean` | нет | active; see table constraints and DATA_MODEL.md. |

Ограничения:

- `medication_active_not_null`: `NOT NULL active`
- `medication_code_key`: `UNIQUE (code)`
- `medication_code_not_null`: `NOT NULL code`
- `medication_form_not_null`: `NOT NULL form`
- `medication_id_not_null`: `NOT NULL id`
- `medication_is_demo_not_null`: `NOT NULL is_demo`
- `medication_name_not_null`: `NOT NULL name`
- `medication_pkey`: `PRIMARY KEY (id)`
- `medication_unit_code_fkey`: `FOREIGN KEY (unit_code) REFERENCES ref.unit(code)`
- `medication_unit_code_not_null`: `NOT NULL unit_code`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.medication FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## ref.panel_item

Hospital reference model / ref / panel item. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 3. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `panel_id` | `integer` | нет | panel id; see table constraints and DATA_MODEL.md. |
| `test_id` | `integer` | нет | test id; see table constraints and DATA_MODEL.md. |
| `position` | `smallint` | нет | position; see table constraints and DATA_MODEL.md. |

Ограничения:

- `panel_item_panel_id_fkey`: `FOREIGN KEY (panel_id) REFERENCES ref.test_panel(id)`
- `panel_item_panel_id_not_null`: `NOT NULL panel_id`
- `panel_item_panel_id_position_key`: `UNIQUE (panel_id, "position")`
- `panel_item_pkey`: `PRIMARY KEY (panel_id, test_id)`
- `panel_item_position_check`: `CHECK (("position" > 0))`
- `panel_item_position_not_null`: `NOT NULL "position"`
- `panel_item_test_id_fkey`: `FOREIGN KEY (test_id) REFERENCES ref.test(id)`
- `panel_item_test_id_not_null`: `NOT NULL test_id`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.panel_item FOR EACH ROW EXECUTE FUNCTION audit.capture_change('panel_id', 'test_id')`

## ref.route

Hospital reference model / ref / route. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 1. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `name` | `text` | нет | name; see table constraints and DATA_MODEL.md. |

Ограничения:

- `route_code_not_null`: `NOT NULL code`
- `route_name_not_null`: `NOT NULL name`
- `route_pkey`: `PRIMARY KEY (code)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.route FOR EACH ROW EXECUTE FUNCTION audit.capture_change('code')`

## ref.service

Hospital reference model / ref / service. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 5. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `integer` | нет | Internal immutable surrogate key; identity sequence. |
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `name` | `ref.nonblank_text` | нет | name; see table constraints and DATA_MODEL.md. |
| `category` | `text` | нет | category; see table constraints and DATA_MODEL.md. |
| `active` | `boolean` | нет | active; see table constraints and DATA_MODEL.md. |

Ограничения:

- `service_active_not_null`: `NOT NULL active`
- `service_category_check`: `CHECK ((category = ANY (ARRAY['consultation'::text, 'laboratory'::text, 'imaging'::text, 'procedure'::text, 'bed_day'::text])))`
- `service_category_not_null`: `NOT NULL category`
- `service_code_key`: `UNIQUE (code)`
- `service_code_not_null`: `NOT NULL code`
- `service_id_not_null`: `NOT NULL id`
- `service_name_not_null`: `NOT NULL name`
- `service_pkey`: `PRIMARY KEY (id)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.service FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## ref.test

Hospital reference model / ref / test. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 10. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `integer` | нет | Internal immutable surrogate key; identity sequence. |
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `name` | `text` | нет | name; see table constraints and DATA_MODEL.md. |
| `unit_code` | `text` | да | unit code; see table constraints and DATA_MODEL.md. |
| `value_type` | `text` | нет | value type; see table constraints and DATA_MODEL.md. |
| `reference_note` | `text` | нет | reference note; see table constraints and DATA_MODEL.md. |

Ограничения:

- `test_code_key`: `UNIQUE (code)`
- `test_code_not_null`: `NOT NULL code`
- `test_id_not_null`: `NOT NULL id`
- `test_name_not_null`: `NOT NULL name`
- `test_pkey`: `PRIMARY KEY (id)`
- `test_reference_note_not_null`: `NOT NULL reference_note`
- `test_unit_code_fkey`: `FOREIGN KEY (unit_code) REFERENCES ref.unit(code)`
- `test_value_type_check`: `CHECK ((value_type = ANY (ARRAY['numeric'::text, 'text'::text, 'coded'::text, 'boolean'::text])))`
- `test_value_type_not_null`: `NOT NULL value_type`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.test FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## ref.test_panel

Hospital reference model / ref / test panel. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 1. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `integer` | нет | Internal immutable surrogate key; identity sequence. |
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `name` | `text` | нет | name; see table constraints and DATA_MODEL.md. |

Ограничения:

- `test_panel_code_key`: `UNIQUE (code)`
- `test_panel_code_not_null`: `NOT NULL code`
- `test_panel_id_not_null`: `NOT NULL id`
- `test_panel_name_not_null`: `NOT NULL name`
- `test_panel_pkey`: `PRIMARY KEY (id)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.test_panel FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## ref.unit

Hospital reference model / ref / unit. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 6. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `code` | `text` | нет | code; see table constraints and DATA_MODEL.md. |
| `label` | `text` | нет | label; see table constraints and DATA_MODEL.md. |
| `dimension` | `text` | нет | dimension; see table constraints and DATA_MODEL.md. |
| `ucum_code` | `text` | да | ucum code; see table constraints and DATA_MODEL.md. |

Ограничения:

- `unit_code_not_null`: `NOT NULL code`
- `unit_dimension_not_null`: `NOT NULL dimension`
- `unit_label_not_null`: `NOT NULL label`
- `unit_pkey`: `PRIMARY KEY (code)`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON ref.unit FOR EACH ROW EXECUTE FUNCTION audit.capture_change('code')`

## scheduling.appointment

Hospital reference model / scheduling / appointment. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 120,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `patient_id` | `bigint` | нет | Internal MPI key; patient/encounter identity enforced with composite foreign keys where applicable. |
| `slot_id` | `bigint` | нет | slot id; see table constraints and DATA_MODEL.md. |
| `service_id` | `integer` | нет | service id; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |
| `created_at` | `timestamp with time zone` | нет | Instant stored as timestamptz; display timezone Asia/Qyzylorda. |
| `encounter_id` | `bigint` | да | encounter id; see table constraints and DATA_MODEL.md. |
| `reason_text` | `text` | да | reason text; see table constraints and DATA_MODEL.md. |
| `appointment_period` | `tstzrange` | нет | Controlled copy of slot period; trigger-maintained and protected by a patient overlap exclusion constraint. |

Ограничения:

- `appointment_appointment_period_not_null`: `NOT NULL appointment_period`
- `appointment_created_at_not_null`: `NOT NULL created_at`
- `appointment_encounter_id_patient_id_fkey`: `FOREIGN KEY (encounter_id, patient_id) REFERENCES ehr.encounter(id, patient_id)`
- `appointment_id_not_null`: `NOT NULL id`
- `appointment_patient_id_fkey`: `FOREIGN KEY (patient_id) REFERENCES mpi.patient(id)`
- `appointment_patient_id_not_null`: `NOT NULL patient_id`
- `appointment_pkey`: `PRIMARY KEY (id)`
- `appointment_service_id_fkey`: `FOREIGN KEY (service_id) REFERENCES ref.service(id)`
- `appointment_service_id_not_null`: `NOT NULL service_id`
- `appointment_slot_id_fkey`: `FOREIGN KEY (slot_id) REFERENCES scheduling.slot(id)`
- `appointment_slot_id_key`: `UNIQUE (slot_id)`
- `appointment_slot_id_not_null`: `NOT NULL slot_id`
- `appointment_status_check`: `CHECK ((status = ANY (ARRAY['booked'::text, 'arrived'::text, 'fulfilled'::text, 'cancelled'::text, 'noshow'::text])))`
- `appointment_status_not_null`: `NOT NULL status`
- `patient_appointment_no_overlap`: `EXCLUDE USING gist (patient_id WITH =, appointment_period WITH &&) WHERE ((status = ANY (ARRAY['booked'::text, 'arrived'::text, 'fulfilled'::text])))`

Триггеры:

- `CREATE TRIGGER appointment_period_copy BEFORE INSERT OR UPDATE ON scheduling.appointment FOR EACH ROW EXECUTE FUNCTION scheduling.guard_appointment_period()`
- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON scheduling.appointment FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id', 'patient_id')`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `iam.has_patient_access(patient_id, 'treatment'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'treatment'::text)`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.
- `registrar_access` (hospital_registrar): USING `iam.has_patient_access(patient_id, 'registration'::text)`, WITH CHECK `iam.has_patient_access(patient_id, 'registration'::text)`.

## scheduling.appointment_participant

Hospital reference model / scheduling / appointment participant. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 120,000. RLS: True.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `appointment_id` | `bigint` | нет | appointment id; see table constraints and DATA_MODEL.md. |
| `staff_id` | `bigint` | нет | staff id; see table constraints and DATA_MODEL.md. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |

Ограничения:

- `appointment_participant_appointment_id_fkey`: `FOREIGN KEY (appointment_id) REFERENCES scheduling.appointment(id)`
- `appointment_participant_appointment_id_not_null`: `NOT NULL appointment_id`
- `appointment_participant_pkey`: `PRIMARY KEY (appointment_id, staff_id)`
- `appointment_participant_staff_id_fkey`: `FOREIGN KEY (staff_id) REFERENCES org.staff(id)`
- `appointment_participant_staff_id_not_null`: `NOT NULL staff_id`
- `appointment_participant_status_check`: `CHECK ((status = ANY (ARRAY['accepted'::text, 'tentative'::text, 'declined'::text])))`
- `appointment_participant_status_not_null`: `NOT NULL status`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON scheduling.appointment_participant FOR EACH ROW EXECUTE FUNCTION audit.capture_change('appointment_id', 'staff_id')`

Политики доступа:

- `clinician_access` (hospital_clinician): USING `(EXISTS ( SELECT
   FROM scheduling.appointment a
  WHERE (a.id = appointment_participant.appointment_id)))`, WITH CHECK `None`.
- `owner_access` (hospital_owner): USING `true`, WITH CHECK `true`.
- `registrar_access` (hospital_registrar): USING `(EXISTS ( SELECT
   FROM scheduling.appointment a
  WHERE (a.id = appointment_participant.appointment_id)))`, WITH CHECK `None`.

## scheduling.schedule

Hospital reference model / scheduling / schedule. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 240. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `staff_id` | `bigint` | нет | staff id; see table constraints and DATA_MODEL.md. |
| `department_id` | `bigint` | нет | department id; see table constraints and DATA_MODEL.md. |
| `valid_during` | `daterange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |
| `active` | `boolean` | нет | active; see table constraints and DATA_MODEL.md. |

Ограничения:

- `schedule_active_not_null`: `NOT NULL active`
- `schedule_department_id_fkey`: `FOREIGN KEY (department_id) REFERENCES org.department(id)`
- `schedule_department_id_not_null`: `NOT NULL department_id`
- `schedule_id_not_null`: `NOT NULL id`
- `schedule_id_staff_id_department_id_key`: `UNIQUE (id, staff_id, department_id)`
- `schedule_pkey`: `PRIMARY KEY (id)`
- `schedule_staff_id_fkey`: `FOREIGN KEY (staff_id) REFERENCES org.staff(id)`
- `schedule_staff_id_not_null`: `NOT NULL staff_id`
- `schedule_valid_during_check`: `CHECK ((NOT isempty(valid_during)))`
- `schedule_valid_during_not_null`: `NOT NULL valid_during`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON scheduling.schedule FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`

## scheduling.slot

Hospital reference model / scheduling / slot. Synthetic demonstration; see DATA_MODEL.md for semantics.

Строк: 120,000. RLS: False.

| Колонка | Тип | NULL | Назначение |
|---|---|---|---|
| `id` | `bigint` | нет | Internal immutable surrogate key; identity sequence. |
| `schedule_id` | `bigint` | нет | schedule id; see table constraints and DATA_MODEL.md. |
| `staff_id` | `bigint` | нет | staff id; see table constraints and DATA_MODEL.md. |
| `department_id` | `bigint` | нет | department id; see table constraints and DATA_MODEL.md. |
| `room_id` | `bigint` | нет | room id; see table constraints and DATA_MODEL.md. |
| `slot_period` | `tstzrange` | нет | Validity interval; temporal constraints apply. Use half-open [start,end) convention. |
| `status` | `text` | нет | status; see table constraints and DATA_MODEL.md. |

Ограничения:

- `slot_department_id_not_null`: `NOT NULL department_id`
- `slot_id_not_null`: `NOT NULL id`
- `slot_pkey`: `PRIMARY KEY (id)`
- `slot_room_id_department_id_fkey`: `FOREIGN KEY (room_id, department_id) REFERENCES org.room(id, department_id)`
- `slot_room_id_not_null`: `NOT NULL room_id`
- `slot_room_id_slot_period_excl`: `EXCLUDE USING gist (room_id WITH =, slot_period WITH &&)`
- `slot_schedule_id_not_null`: `NOT NULL schedule_id`
- `slot_schedule_id_staff_id_department_id_fkey`: `FOREIGN KEY (schedule_id, staff_id, department_id) REFERENCES scheduling.schedule(id, staff_id, department_id)`
- `slot_slot_period_check`: `CHECK (((NOT isempty(slot_period)) AND (NOT lower_inf(slot_period)) AND (NOT upper_inf(slot_period)) AND lower_inc(slot_period) AND (NOT upper_inc(slot_period))))`
- `slot_slot_period_not_null`: `NOT NULL slot_period`
- `slot_staff_id_not_null`: `NOT NULL staff_id`
- `slot_staff_id_slot_period_excl`: `EXCLUDE USING gist (staff_id WITH =, slot_period WITH &&)`
- `slot_status_check`: `CHECK ((status = ANY (ARRAY['free'::text, 'busy'::text, 'blocked'::text])))`
- `slot_status_not_null`: `NOT NULL status`

Триггеры:

- `CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON scheduling.slot FOR EACH ROW EXECUTE FUNCTION audit.capture_change('id')`
- `CREATE TRIGGER booked_slot_period_guard BEFORE UPDATE OF slot_period ON scheduling.slot FOR EACH ROW EXECUTE FUNCTION scheduling.guard_booked_slot()`
- `CREATE TRIGGER slot_dates_guard BEFORE INSERT OR UPDATE ON scheduling.slot FOR EACH ROW EXECUTE FUNCTION scheduling.guard_slot()`

