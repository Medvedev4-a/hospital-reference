[CmdletBinding()]
param([switch]$ResumeAfterHardening,[switch]$ResumeFromBackup)
$ErrorActionPreference='Stop'
$pgBin='C:\Program Files\PostgreSQL\18\bin'
$python='C:\Users\D M\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$env:PGCLIENTENCODING='UTF8'
$common=@('-X','-w','-h','localhost','-U','postgres','-v','ON_ERROR_STOP=1')
function SqlFile([string]$db,[string]$file,[string]$log) {
    & "$pgBin\psql.exe" @common -d $db -f (Join-Path $PSScriptRoot $file) *> (Join-Path $PSScriptRoot $log)
    if ($LASTEXITCODE -ne 0) { throw ('SQL validation/migration failed: '+$file+'; see '+$log) }
}
Push-Location $PSScriptRoot
try {
    if (-not $ResumeAfterHardening -and -not $ResumeFromBackup) {
        SqlFile 'hospital_reference' '07_hardening.sql' 'hardening.log'
        SqlFile 'hospital_reference' '09_authorized_workflows.sql' 'authorized_workflows.log'
    }
    if (-not $ResumeFromBackup) {
    SqlFile 'hospital_reference' '08_validate.sql' 'validation.log'
    Write-Output 'PRIMARY_VALIDATION_SUCCESS'
    & "$pgBin\pg_dump.exe" -w -h localhost -U postgres -d hospital_reference --schema-only -f (Join-Path $PSScriptRoot 'schema.sql')
    if ($LASTEXITCODE -ne 0) { throw 'Schema dump failed' }
    & "$pgBin\pg_dump.exe" -w -h localhost -U postgres -d hospital_reference -Fc -Z 6 -f (Join-Path $PSScriptRoot 'hospital_reference.backup')
    if ($LASTEXITCODE -ne 0) { throw 'Full backup failed' }
    Write-Output 'BACKUP_SUCCESS'
    } elseif (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'hospital_reference.backup'))) {
        throw 'No backup exists for resume'
    }
    $clone='hospital_reference_restore_check'
    $exists=& "$pgBin\psql.exe" @common -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname='$clone'"
    if ($exists -eq '1') { throw 'Restore-check database already exists; leaving it intact.' }
    & "$pgBin\psql.exe" @common -d postgres -c 'CREATE DATABASE hospital_reference_restore_check OWNER hospital_owner TEMPLATE template0;'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to create disposable restore-check database' }
    & "$pgBin\psql.exe" @common -d postgres -c "ALTER DATABASE hospital_reference_restore_check SET timezone='Asia/Qyzylorda';"
    & "$pgBin\psql.exe" @common -d postgres -c 'REVOKE ALL ON DATABASE hospital_reference_restore_check FROM PUBLIC; GRANT CONNECT ON DATABASE hospital_reference_restore_check TO hospital_owner,hospital_clinician,hospital_registrar,hospital_billing,hospital_analyst,hospital_auditor;'
    if ($LASTEXITCODE -ne 0) { throw 'Restore database privilege setup failed' }
    & "$pgBin\pg_restore.exe" -w -h localhost -U postgres -d $clone --enable-row-security --exit-on-error -j 4 (Join-Path $PSScriptRoot 'hospital_reference.backup') *> (Join-Path $PSScriptRoot 'restore.log')
    if ($LASTEXITCODE -ne 0) { throw 'Restore failed; disposable copy retained for diagnosis' }
    & "$pgBin\psql.exe" @common -d $clone -c 'SET row_security=on; REFRESH MATERIALIZED VIEW analytics.daily_activity; REFRESH MATERIALIZED VIEW analytics.monthly_revenue; ANALYZE;'
    if ($LASTEXITCODE -ne 0) { throw 'Post-restore aggregate refresh failed' }
    SqlFile $clone '08_validate.sql' 'restore_validation.log'
    Write-Output 'RESTORE_VALIDATION_SUCCESS'
    & $python (Join-Path $PSScriptRoot 'concurrency_check.py') $clone
    if ($LASTEXITCODE -ne 0) { throw 'Concurrency tests failed; disposable copy retained' }
    & "$pgBin\psql.exe" @common -d postgres -c 'DROP DATABASE hospital_reference_restore_check;'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to remove the disposable validation database' }
    $archive=Get-Item -LiteralPath (Join-Path $PSScriptRoot 'hospital_reference.backup')
    $testCount=@(Import-Csv -LiteralPath (Join-Path $PSScriptRoot 'validation_results.csv')).Count
    [ordered]@{passed=$true;full_restore_verified=$true;sql_tests_on_restore=$testCount;concurrent_tests=2;disposable_database_removed=$true;backup_bytes=$archive.Length;backup_sha256=(Get-FileHash -LiteralPath $archive.FullName -Algorithm SHA256).Hash;verified_at=(Get-Date -Format o)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'restore_results.json') -Encoding utf8
    & $python (Join-Path $PSScriptRoot 'build_report.py')
    if ($LASTEXITCODE -ne 0) { throw 'Report extraction failed' }
    Write-Output 'ALL_VERIFICATION_SUCCESS'
} finally { Pop-Location }
