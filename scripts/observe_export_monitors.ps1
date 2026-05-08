# Usage: ./observe_export_monitors.ps1 -CustomerId <id> -Token <token> [-Domain <domain>]
# Example (no domain): ./observe_export_monitors.ps1 -CustomerId 154507918603 -Token mytoken123
# Example (with domain): ./observe_export_monitors.ps1 -CustomerId 154507918603 -Token mytoken123 -Domain eu-1
# Requires: PowerShell 7+ (pwsh)

param(
    [Parameter(Mandatory)] [string] $CustomerId,
    [Parameter(Mandatory)] [string] $Token,
    [string] $Domain = ""
)

$OutputFile = "observe_monitors_$(Get-Date -Format 'yyyy-MM-dd').json"

$Host_ = if ($Domain) { "$CustomerId.$Domain.observeinc.com" } else { "$CustomerId.observeinc.com" }
$BaseUrl = "https://$Host_/v1/monitors"
$Headers = @{
    "Authorization" = "Bearer $CustomerId $Token"
    "Content-Type"  = "application/json"
}

Write-Host "Fetching monitor list from $BaseUrl ..."

try {
    $ListResponse = Invoke-RestMethod -Uri $BaseUrl -Method Get -Headers $Headers
} catch {
    Write-Error "Failed to fetch monitor list: $_"
    exit 1
}

$Monitors = if ($ListResponse -is [array]) { $ListResponse } else { @($ListResponse) }
$Total = $Monitors.Count

if ($Total -eq 0) {
    Write-Host "No monitors found."
    "[]" | Set-Content -Path $OutputFile -Encoding UTF8
    exit 0
}

Write-Host "Found $Total monitors. Fetching details..."

$Details = [System.Collections.Generic.List[object]]::new()
$Fetched = 0
$Errors  = 0

foreach ($Monitor in $Monitors) {
    $Id = $Monitor.id
    try {
        $Detail = Invoke-RestMethod -Uri "$BaseUrl/$Id" -Method Get -Headers $Headers
        $Details.Add($Detail)
        $Fetched++
        Write-Host "  [$Fetched/$Total] $Id"
    } catch {
        Write-Warning "Failed to fetch monitor $Id : $_"
        $Errors++
    }
}

$Details | ConvertTo-Json -Depth 100 | Set-Content -Path $OutputFile -Encoding UTF8

Write-Host ""
Write-Host "Done. $Fetched monitors exported to $OutputFile ($Errors errors)"
