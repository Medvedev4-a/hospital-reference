[CmdletBinding()]
param([string]$NewDatabase='hospital_reference_copy',[string]$BackupFile=(Join-Path $PSScriptRoot 'hospital_reference.backup'),[string]$PgBin='C:\Program Files\PostgreSQL\18\bin')
$ErrorActionPreference='Stop'
if ($NewDatabase -notmatch '^[a-z][a-z0-9_]{0,62}$' -or $NewDatabase -in @('postgres','template0','template1','hospital_reference')) { throw 'Use a NEW database name consisting of lowercase letters, digits and underscores. The working database is protected.' }
if (-not (Test-Path -LiteralPath $BackupFile -PathType Leaf)) { throw 'Backup archive not found' }
if (-not $env:PGPASSWORD) { throw 'Provide the administrator password through PGPASSWORD in this process; no passwords are stored in the project.' }
$argsPg=@('-X','-w','-h','localhost','-U','postgres','-v','ON_ERROR_STOP=1')
$exists=& "$PgBin\psql.exe" @argsPg -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname='$NewDatabase';"
if ($LASTEXITCODE -ne 0) { throw 'Connection failed' }
if ($exists -eq '1') { throw 'Target database already exists; restore refused.' }
& "$PgBin\psql.exe" @argsPg -d postgres -c "CREATE DATABASE $NewDatabase OWNER hospital_owner TEMPLATE template0 ENCODING 'UTF8';"
if ($LASTEXITCODE -ne 0) { throw 'Database creation failed; prepare the roles with roles.sql on a new server.' }
& "$PgBin\psql.exe" @argsPg -d postgres -c "REVOKE ALL ON DATABASE $NewDatabase FROM PUBLIC; GRANT CONNECT ON DATABASE $NewDatabase TO hospital_owner,hospital_clinician,hospital_registrar,hospital_billing,hospital_analyst,hospital_auditor; ALTER DATABASE $NewDatabase SET timezone='Asia/Qyzylorda';"
if ($LASTEXITCODE -ne 0) { throw 'Database privileges failed' }
& "$PgBin\pg_restore.exe" -w -h localhost -U postgres -d $NewDatabase --enable-row-security --exit-on-error -j 4 $BackupFile
if ($LASTEXITCODE -ne 0) { throw 'Restore failed. Target retained for inspection; no existing database was overwritten.' }
& "$PgBin\psql.exe" @argsPg -d $NewDatabase -c 'SET row_security=on; REFRESH MATERIALIZED VIEW analytics.daily_activity; REFRESH MATERIALIZED VIEW analytics.monthly_revenue; ANALYZE;'
if ($LASTEXITCODE -ne 0) { throw 'Post-restore ANALYZE failed' }
Write-Output ('Restored successfully: '+$NewDatabase)
