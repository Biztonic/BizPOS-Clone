# Remove Print Statements Script
# This script removes debug print statements while preserving error logging

$files = @(
    "lib\providers\dashboard_provider.dart",
    "lib\providers\inventory_provider.dart",
    "lib\providers\order_provider.dart",
    "lib\providers\customer_provider.dart",
    "lib\providers\store_provider.dart",
    "lib\providers\auth_provider.dart"
)

$totalRemoved = 0

foreach ($file in $files) {
    $content = Get-Content $file -Raw
    $originalLength = $content.Length
    
    # Remove standalone print statements (keep error context)
    # Pattern: Remove lines that are just print statements for debugging
    $content = $content -replace '(?m)^\s*print\("DEBUG:.*?\);\s*$', ''
    $content = $content -replace '(?m)^\s*print\("SYNC:.*?\);\s*$', ''
    $content = $content -replace '(?m)^\s*print\("INFO:.*?\);\s*$', ''
    $content = $content -replace '(?m)^\s*print\(''DEBUG:.*?\);\s*$', ''
    
    # Remove empty lines created by removal
    $content = $content -replace '(?m)^\s*\r?\n\s*\r?\n', "`n"
    
    $newLength = $content.Length
    $removed = ($originalLength - $newLength)
    $totalRemoved += $removed
    
    Set-Content -Path $file -Value $content -NoNewline
    Write-Host "Processed $file - Removed $removed bytes"
}

Write-Host "`nTotal removed: $totalRemoved bytes"
