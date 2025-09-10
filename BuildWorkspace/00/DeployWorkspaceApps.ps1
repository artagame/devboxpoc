<#
.SYNOPSIS
Deploys or updates a Power BI Workspace App.
#>

param(
    [Parameter(Mandatory=$true)] [string]$TenantId,
    [Parameter(Mandatory=$true)] [string]$ClientId,
    [Parameter(Mandatory=$true)] [string]$ClientSecret,
    [Parameter(Mandatory=$true)] [string]$WorkspaceName,
    [Parameter(Mandatory=$true)] [string]$AppConfigPath
)

# ===== Ensure MicrosoftPowerBIMgmt module is installed =====
$moduleName = "MicrosoftPowerBIMgmt"

if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    Write-Host "📦 Module '$moduleName' not found. Installing..."
    try {
        Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
        Write-Host "✅ Module '$moduleName' installed successfully."
    }
    catch {
        throw "❌ Failed to install module '$moduleName': $($_.Exception.Message)"
    }
}
else {
    Write-Host "✅ Module '$moduleName' is already installed."
}

Import-Module $moduleName -Global

# ===== Connect to Power BI using Service Principal =====
try {
    Write-Host "🔑 Connecting to Power BI Service..."
    Connect-PowerBIServiceAccount -ServicePrincipal -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
    Write-Host "✅ Connected successfully."
}
catch {
    throw "❌ Failed to authenticate to Power BI: $($_.Exception.Message)"
}

# ===== Resolve Workspace =====
$workspace = Get-PowerBIWorkspace -Name $WorkspaceName -ErrorAction Stop
if (-not $workspace) {
    throw "❌ Workspace '$WorkspaceName' not found!"
}

Write-Host "📂 Workspace found: $($workspace.Name) (Id: $($workspace.Id))"

# ===== Load App Config =====
if (-not (Test-Path $AppConfigPath)) {
    throw "❌ App config file '$AppConfigPath' not found."
}

try {
    $config = Get-Content $AppConfigPath -Raw | ConvertFrom-Json
    Write-Host "✅ Loaded app-config.json"
}
catch {
    throw "❌ Failed to parse JSON: $($_.Exception.Message)"
}

# ===== Resolve Report IDs =====
$reportsInWorkspace = Get-PowerBIReport -WorkspaceId $workspace.Id

foreach ($section in $config.navigation.sections) {
    foreach ($item in $section.items) {
        if ($item.reportName) {
            $report = $reportsInWorkspace | Where-Object { $_.Name -eq $item.reportName }
            if (-not $report) {
                throw "❌ Report '$($item.reportName)' not found in workspace!"
            }
            # Replace reportName with reportId
            $item.PSObject.Properties.Remove("reportName")
            $item | Add-Member -MemberType NoteProperty -Name "reportId" -Value $report.Id
        }
    }
}

# ===== Save resolved config to temp file =====
$resolvedConfigPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "app-config.resolved.json")
$config | ConvertTo-Json -Depth 10 | Out-File $resolvedConfigPath -Encoding utf8
Write-Host "✅ Resolved report IDs saved to $resolvedConfigPath"

# ===== Update/Publish Workspace App =====
try {
    Write-Host "📦 Updating workspace app..."
    Publish-PowerBIApp -WorkspaceId $workspace.Id -AppDefinitionPath $resolvedConfigPath -ErrorAction Stop
    Write-Host "✅ Workspace App updated successfully!"
}
catch {
    throw "❌ Failed to update workspace app: $($_.Exception.Message)"
}
