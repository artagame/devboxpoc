# ================================
# PowerShell Script - Import RDL into Power BI Workspace
# ================================

param(
    [string]$TenantId       = "<YOUR_TENANT_ID>",
    [string]$ClientId       = "<YOUR_CLIENT_ID>",
    [string]$ClientSecret   = "<YOUR_CLIENT_SECRET>",
    [string]$WorkspaceId    = "<YOUR_WORKSPACE_ID>",
    [string]$RdlFilePath    = "<PATH_TO_YOUR_RDL_FILE>"
)

# Install module if not present
if (-not (Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt)) {
    Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser -Force
}

Import-Module MicrosoftPowerBIMgmt

# Authenticate using Service Principal
$SecureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
$Credential   = New-Object System.Management.Automation.PSCredential($ClientId, $SecureSecret)

Connect-PowerBIServiceAccount -ServicePrincipal -Tenant $TenantId -Credential $Credential

# Derive report name from file
$ReportName = [System.IO.Path]::GetFileNameWithoutExtension($RdlFilePath)

# Check if report already exists
$ExistingReport = Get-PowerBIReport -WorkspaceId $WorkspaceId | Where-Object { $_.Name -eq $ReportName -and $_.ReportType -eq "PaginatedReport" }

if ($ExistingReport) {
    Write-Host "Report '$ReportName' already exists. Deleting for overwrite..."
    Remove-PowerBIReport -Id $ExistingReport.Id -WorkspaceId $WorkspaceId -Force
}

# Import the RDL
Write-Host "Importing RDL report '$ReportName'..."
Import-PowerBIReport -Path $RdlFilePath -Name $ReportName -WorkspaceId $WorkspaceId -ConflictAction CreateOrOverwrite -ImportAsPaginatedReport

Write-Host "✅ RDL report '$ReportName' imported successfully."
