param(
    [string]$TenantId      = "<YourTenantID>",
    [string]$ClientId      = "<YourServicePrincipalId>",
    [string]$ClientSecret  = "<YourServicePrincipalSecret>",
    [string]$WorkspaceId   = "<YourWorkspaceId>",
    [string]$ManifestPath  = ".\manifest.json"
)

# === Helper: Get Access Token ===
function Get-AccessToken {
    param($TenantId, $ClientId, $ClientSecret)

    $body = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://api.fabric.microsoft.com/.default"
    }

    $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $body
    return $response.access_token
}

# === Helper: Get Existing Folders ===
function Get-Folders {
    param(
        [string]$WorkspaceId,
        [string]$AccessToken
    )

    $uri = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/folders"

    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers @{
        "Authorization" = "Bearer $AccessToken"
    }

    return $response.value
}

# === Helper: Create Folder if Needed ===
function Ensure-Folder {
    param(
        [string]$WorkspaceId,
        [string]$FolderName,
        [string]$ParentId,
        [string]$AccessToken,
        [array]$AllFolders
    )

    # Find if folder already exists under the same parent
    $existing = $AllFolders | Where-Object { $_.displayName -eq $FolderName -and ($_.parentId -eq $ParentId -or (-not $_.parentId -and -not $ParentId)) }

    if ($existing) {
        return $existing.id
    }

    # Create folder if not found
    $uri = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/folders"

    $body = @{
        displayName = $FolderName
    }

    if ($ParentId) {
        $body.parentId = $ParentId
    }

    $jsonBody = $body | ConvertTo-Json -Depth 5

    $response = Invoke-RestMethod -Method Post -Uri $uri -Headers @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    } -Body $jsonBody

    # Add new folder to cache
    $AllFolders += $response

    return $response.id
}

# === Main Logic ===
$token = Get-AccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

$manifest = Get-Content $ManifestPath | ConvertFrom-Json
$allFolders = Get-Folders -WorkspaceId $WorkspaceId -AccessToken $token

foreach ($entry in $manifest) {
    $folderPath = $entry.Folder -split "\\\\|/"
    $parentId = $null
    $lastFolderId = $null

    foreach ($folder in $folderPath) {
        $folderId = Ensure-Folder -WorkspaceId $WorkspaceId -FolderName $folder -ParentId $parentId -AccessToken $token -AllFolders ([ref]$allFolders).Value
        $parentId = $folderId
        $lastFolderId = $folderId
    }

    Write-Output "Last folder created (or existing) ID: $lastFolderId"
}
