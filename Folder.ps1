param(
    [string]$TenantId = "<YourTenantID>",
    [string]$ClientId = "<ServicePrincipalID>",
    [string]$ClientSecret = "<ServicePrincipalSecret>",
    [string]$WorkspaceId = "<YourWorkspaceID>",
    [string]$ManifestPath = ".\manifest.json"
)

# ===== Helper Functions =====
function Get-AccessToken {
    param($TenantId, $ClientId, $ClientSecret)

    $Body = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://api.fabric.microsoft.com/.default"
    }

    $Response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $Body
    return $Response.access_token
}

function Get-ExistingFolders {
    param($AccessToken, $WorkspaceId)

    $Uri = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/folders"
    $Headers = @{ Authorization = "Bearer $AccessToken" }

    $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get
    return $Response.value  # returns objects with id and name
}

function Create-Folder {
    param($AccessToken, $WorkspaceId, $FolderName)

    $Uri = "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/folders"
    $Headers = @{
        Authorization = "Bearer $AccessToken"
        "Content-Type" = "application/json"
    }

    $Body = @{ name = $FolderName } | ConvertTo-Json -Depth 2
    $Response = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Post -Body $Body
    Write-Host "Created folder: $FolderName (ID: $($Response.id))"
    return $Response.id
}

function Ensure-Folders {
    param($AccessToken, $WorkspaceId, $FolderPath)

    # Split nested folder path
    $Folders = $FolderPath -split '\\'
    $CurrentPath = ""
    $LastFolderId = $null

    foreach ($Folder in $Folders) {
        $CurrentPath = if ($CurrentPath) { "$CurrentPath\$Folder" } else { $Folder }

        $ExistingFolders = Get-ExistingFolders -AccessToken $AccessToken -WorkspaceId $WorkspaceId

        $Match = $ExistingFolders | Where-Object { $_.name -eq $CurrentPath }

        if ($null -eq $Match) {
            $LastFolderId = Create-Folder -AccessToken $AccessToken -WorkspaceId $WorkspaceId -FolderName $CurrentPath
        }
        else {
            $LastFolderId = $Match.id
            Write-Host "Folder already exists: $CurrentPath (ID: $LastFolderId)"
        }
    }

    return $LastFolderId
}

# ===== Main Execution =====
$AccessToken = Get-AccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

$Manifest = Get-Content $ManifestPath | ConvertFrom-Json

$FoldersToCreate = if ($Manifest.Folder -is [System.Collections.IEnumerable] -and $Manifest.Folder -notis [string]) {
    $Manifest.Folder
} else {
    @($Manifest.Folder)
}

foreach ($FolderPath in $FoldersToCreate) {
    $FolderId = Ensure-Folders -AccessToken $AccessToken -WorkspaceId $WorkspaceId -FolderPath $FolderPath
    Write-Host "Final folder ID for '$FolderPath': $FolderId"
}
