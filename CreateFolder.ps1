param(
    [string]$TenantId       = "<YourTenantID>",
    [string]$ClientId       = "<ServicePrincipalID>",
    [string]$ClientSecret   = "<ServicePrincipalSecret>",
    [string]$WorkspaceId    = "<YourWorkspaceID>",
    [string]$FolderPath     = "TestFolder/TestFolder/a"  # from manifest
)

# ===== Helper: Get Access Token =====
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

# ===== Helper: Get Folder by Name =====
function Get-FolderByName {
    param($WorkspaceId, $ParentFolderId, $Name, $Headers)

    $uri = "https://api.fabric.microsoft.com/core/folders/v1/workspaces/$WorkspaceId/folders"
    if ($ParentFolderId -ne "") {
        $uri += "?parentFolderId=$ParentFolderId"
    }

    $folders = Invoke-RestMethod -Method Get -Uri $uri -Headers $Headers
    return $folders.value | Where-Object { $_.name -eq $Name }
}

# ===== Helper: Create Folder =====
function New-Folder {
    param($WorkspaceId, $Name, $ParentFolderId, $Headers)

    $body = @{ name = $Name }
    if ($ParentFolderId -ne "") { $body["parentFolderId"] = $ParentFolderId }

    $bodyJson = $body | ConvertTo-Json -Depth 5
    $uri = "https://api.fabric.microsoft.com/core/folders/v1/workspaces/$WorkspaceId/folders"
    return Invoke-RestMethod -Method Post -Uri $uri -Headers $Headers -Body $bodyJson
}

# ===== Main Script =====
$token = Get-AccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

$parts = $FolderPath -split "/"
$parentId = ""
$createdFolders = @()

foreach ($part in $parts) {
    $existing = Get-FolderByName -WorkspaceId $WorkspaceId -ParentFolderId $parentId -Name $part -Headers $headers

    if ($null -eq $existing) {
        Write-Output "Creating folder: $part (under parent: $parentId)"
        $folder = New-Folder -WorkspaceId $WorkspaceId -Name $part -ParentFolderId $parentId -Headers $headers
    } else {
        Write-Output "Folder already exists: $part"
        $folder = $existing
    }

    $parentId = $folder.id
    $createdFolders += $folder
}

Write-Output "Final folder ID (deepest level): $parentId"
