[CmdletBinding()]
param([string]$HostName='localhost',[int]$Port=5432,[string]$AdminUser='postgres')
$ErrorActionPreference='Stop'
$pgBin='C:\Program Files\PostgreSQL\18\bin'
$database='hospital_reference'
if (-not $env:PGPASSWORD) { throw 'Set PGPASSWORD for this process only before running. No password is stored in this project.' }
$env:PGCLIENTENCODING='UTF8'
$common=@('-X','-w','-h',$HostName,'-p',"$Port",'-U',$AdminUser,'-v','ON_ERROR_STOP=1')
function Invoke-Admin([string]$sql) {
    & "$pgBin\psql.exe" @common -d postgres -c $sql
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL administration command failed' }
}
$exists=& "$pgBin\psql.exe" @common -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname='$database';"
if ($LASTEXITCODE -ne 0) { throw 'Unable to connect' }
if ($exists -eq '1') { throw 'hospital_reference already exists. Refusing to overwrite data. Use migrations for an existing deployment.' }
Invoke-Admin @'
DO $roles$ DECLARE r text; BEGIN FOREACH r IN ARRAY ARRAY['hospital_owner','hospital_clinician','hospital_registrar','hospital_billing','hospital_analyst','hospital_auditor','hospital_demo_clinician','hospital_demo_registrar','hospital_demo_billing'] LOOP
IF EXISTS(SELECT FROM pg_roles WHERE rolname=r) THEN RAISE EXCEPTION 'Role already exists: %. Inspect before deployment.',r; END IF;
EXECUTE format('CREATE ROLE %I NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS',r);
END LOOP; END $roles$;
GRANT hospital_clinician TO hospital_demo_clinician WITH INHERIT TRUE;
GRANT hospital_registrar TO hospital_demo_registrar WITH INHERIT TRUE;
GRANT hospital_billing TO hospital_demo_billing WITH INHERIT TRUE;
'@
Invoke-Admin "CREATE DATABASE hospital_reference OWNER hospital_owner TEMPLATE template0 ENCODING 'UTF8';"
Invoke-Admin "ALTER DATABASE hospital_reference SET timezone='Asia/Qyzylorda';"
Invoke-Admin "COMMENT ON DATABASE hospital_reference IS 'Professional hospital reference architecture; synthetic data only; see project README and validation report.';"
$files=@('00_bootstrap.sql','01_organization_patient.sql','02_clinical.sql','03_operations.sql','04_integrity.sql','05_seed.sql','06_security_analytics.sql')
foreach($file in $files) {
    Write-Output ('Applying '+$file)
    & "$pgBin\psql.exe" @common -d $database -f (Join-Path $PSScriptRoot $file)
    if ($LASTEXITCODE -ne 0) { throw ('Migration failed: '+$file+'. Existing database preserved for inspection.') }
}
Write-Output 'DEPLOY_SUCCESS'
