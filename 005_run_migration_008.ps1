# =============================================
# Sameka — Run Migration 008 (Backfill user_id)
# Executes SQL migration against Supabase DB
# =============================================

$SUPABASE_URL = "https://longflatworm-supabase.cloudfy.live"
$SERVICE_ROLE_KEY = "__FILL_ME__SERVICE_ROLE_KEY__"  # Get from Supabase Dashboard > Settings > API

Write-Host "`n=== Executing Migration 008: Backfill user_id ===" -ForegroundColor Cyan

# Read the SQL file
$sqlPath = Join-Path $PSScriptRoot "migrations\008_backfill_user_id.sql"
if (-not (Test-Path $sqlPath)) {
    Write-Host "Error: Migration file not found at $sqlPath" -ForegroundColor Red
    exit 1
}

$sql = Get-Content $sqlPath -Raw

# Execute via Supabase PostgREST's rpc endpoint
# Note: This requires creating a helper function in the DB first, or use direct psql
Write-Host "Reading SQL from: $sqlPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "To execute this migration, run ONE of the following:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Option 1 - Supabase Studio (Recommended):" -ForegroundColor Cyan
Write-Host "1. Open https://longflatworm-supabase.cloudfy.live/project/_/sql/new"
Write-Host "2. Copy the contents of migrations/008_backfill_user_id.sql"
Write-Host "3. Paste and click 'Run'"
Write-Host ""
Write-Host "Option 2 - psql (if you have database password):" -ForegroundColor Cyan
Write-Host @"
psql "postgresql://postgres.longflatworm:[PASSWORD]@aws-0-us-west-1.pooler.supabase.com:6543/postgres" -f "$sqlPath"
"@ -ForegroundColor White
Write-Host ""
Write-Host "After running, refresh your Sameka app and the sessions should appear!" -ForegroundColor Green
