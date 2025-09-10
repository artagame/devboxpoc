param(
    [string]$TenantId = "<YourTenantID>",
    [string]$ClientId = "<ServicePrincipalID>",
    [string]$ClientSecret = "<ServicePrincipalSecret>",
    [string]$WorkspaceName = "MyWorkspace",
    [string]$ManifestPath = "$(Pipeline.Workspace)\rdl\rdl-manifest.json"
)

# ===== Helper Functions =====

function Get-AccessToken {
    param($TenantId, $ClientId, $ClientSecret)

    $body = @{
        grant_type    = "client_credentials"
        scope         = "https://analysis.windows.net/powerbi/api/.default"
        client_id     = $ClientId
        client_secret = $ClientSecret
    }

    $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $body
    return $response.access_token
}

function Get-WorkspaceId {
    param($AccessToken, $WorkspaceName)

    $uri = "https://api.powerbi.com/v1.0/myorg/groups"
    $headers = @{ Authorization = "Bearer $AccessToken" }

    $groups = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    $workspace = $groups.value | Where-Object { $_.name -eq $WorkspaceName }

    if (-not $workspace) {
        throw "❌ Workspace '$WorkspaceName' not found!"
    }

    return $workspace.id
}

function Get-Folder {
    param($AccessToken, $WorkspaceId, $FolderName)

    $uri = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/rdlfolders"
    $headers = @{ Authorization = "Bearer $AccessToken" }

    $folders = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    return $folders.value | Where-Object { $_.name -eq $FolderName }
}

function Ensure-Folder {
    param($AccessToken, $WorkspaceId, $FolderName)

    if ([string]::IsNullOrWhiteSpace($FolderName)) {
        return $null # root folder
    }

    $existing = Get-Folder -AccessToken $AccessToken -WorkspaceId $WorkspaceId -FolderName $FolderName
    if ($existing) {
        return $existing.id
    }

    Write-Host "📂 Creating folder '$FolderName'..."
    $uri = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/rdlfolders"
    $headers = @{ Authorization = "Bearer $AccessToken"; "Content-Type" = "application/json" }
    $body = @{ name = $FolderName } | ConvertTo-Json

    $newFolder = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    return $newFolder.id
}

function Get-Report {
    param($AccessToken, $WorkspaceId, $ReportName, $FolderId)

    $uri = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/reports"
    $headers = @{ Authorization = "Bearer $AccessToken" }

    $reports = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    $match = $reports.value | Where-Object { $_.name -eq $ReportName }

    if ($FolderId -and $match) {
        # Only keep matches in this folder
        return $match | Where-Object { $_.folderId -eq $FolderId }
    }

    return $match
}

function Upload-Rdl {
    param($AccessToken, $WorkspaceId, $Report, $FolderId)

    $reportName = $Report.FileName
    $rdlPath = $Report.FullPath
    $headers = @{ Authorization = "Bearer $AccessToken"; "Content-Type" = "application/rdl" }

    $existing = Get-Report -AccessToken $AccessToken -WorkspaceId $WorkspaceId -ReportName $reportName -FolderId $FolderId

    if ($existing) {
        Write-Host "⚠️ Report '$reportName' already exists. Overwriting..."
        $uri = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/reports/$($existing.id)/UpdateReportContent?overrideModel=true"

        try {
            Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -InFile $rdlPath -ErrorAction Stop
            Write-Host "✅ Report '$reportName' overwritten successfully."
        }
        catch {
            Write-Host "❌ Failed to overwrite report '$reportName': $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "📤 Uploading new report '$reportName'..."
        $uri = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/reports/import?datasetDisplayName=$reportName"
        if ($FolderId) { $uri += "&folderId=$FolderId" }

        try {
            Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -InFile $rdlPath -ErrorAction Stop
            Write-Host "✅ Report '$reportName' uploaded successfully."
        }
        catch {
            Write-Host "❌ Failed to upload report '$reportName': $($_.Exception.Message)"
        }
    }
}
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

# Import module
Import-Module $moduleName -Global

# ===== Main Execution =====

try {
    Write-Host "🔑 Authenticating..."
    $token = Get-AccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

    Write-Host "📂 Getting workspace..."
    $workspaceId = Get-WorkspaceId -AccessToken $token -WorkspaceName $WorkspaceName

    if (-not (Test-Path $ManifestPath)) {
        throw "❌ Manifest '$ManifestPath' not found."
    }

    $manifest = Get-Content $ManifestPath | ConvertFrom-Json

    foreach ($report in $manifest) {
        $folderId = $null
        if ($report.Folder) {
            $folderId = Ensure-Folder -AccessToken $token -WorkspaceId $workspaceId -FolderName $report.Folder
        }

        Upload-Rdl -AccessToken $token -WorkspaceId $workspaceId -Report $report -FolderId $folderId
    }

    Write-Host "🎉 Deployment completed."
}
catch {
    Write-Host "❌ Script failed: $($_.Exception.Message)"
}
