# gsd_setup.ps1
# Setup Get-Shit-Done (GSD) agents and workflows in the current project.

$repoUrl = "https://github.com/gsd-build/get-shit-done.git"
$tempDir = Join-Path $env:TEMP "gsd_temp_$(Get-Date -Format 'yyyyMMddHHmmss')"
$targetBase = Join-Path (Get-Location) ".agent"
$agentsDir = Join-Path $targetBase "agents"
$workflowsDir = Join-Path $targetBase "workflows"

Write-Host "Setting up GSD in $(Get-Location)..."

# Create directories
if (-not (Test-Path $agentsDir)) { New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null }
if (-not (Test-Path $workflowsDir)) { New-Item -ItemType Directory -Path $workflowsDir -Force | Out-Null }

try {
    Write-Host "Cloning GSD repository to $tempDir..."
    git clone --depth 1 $repoUrl $tempDir

    if (Test-Path $tempDir) {
        Write-Host "Copying agents..."
        $sourceAgents = Join-Path $tempDir "agents"
        if (Test-Path $sourceAgents) {
            Get-ChildItem -Path $sourceAgents -Filter "*.md" | Copy-Item -Destination $agentsDir -Force
        }

        Write-Host "Copying workflows..."
        $gsdSubDir = Join-Path $tempDir "get-shit-done"
        $sourceWorkflows = Join-Path $gsdSubDir "workflows"
        if (Test-Path $sourceWorkflows) {
            Get-ChildItem -Path $sourceWorkflows -Filter "*.md" | Copy-Item -Destination $workflowsDir -Force
        }

        Write-Host "GSD setup complete!"
    } else {
        Write-Error "Failed to clone GSD repository."
    }
}
catch {
    Write-Error "An error occurred during GSD setup: $_"
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
