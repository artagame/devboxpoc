$rdlFolder = "$(Build.SourcesDirectory)\reports"
$artifactDir = "$(Build.ArtifactStagingDirectory)"
$newManifestPath = Join-Path $artifactDir "rdl-manifest.json"

# Step 1: Compute hashes
$newHashes = @()
Get-ChildItem -Path $rdlFolder -Filter *.rdl -File -Recurse | ForEach-Object {
    $hash = Get-FileHash -Algorithm SHA256 -Path $_.FullName
    $newHashes += [PSCustomObject]@{
        FileName = $_.Name
        RelativePath = $_.FullName.Substring($rdlFolder.Length+1)
        Hash = $hash.Hash
        FullPath = $_.FullName
    }
}

# Step 2: Load old manifest if exists
$oldManifestPath = "$(Pipeline.Workspace)\previous\rdl\rdl-manifest.json"
$oldHashes = @()
if (Test-Path $oldManifestPath) {
    $oldHashes = Get-Content $oldManifestPath | ConvertFrom-Json
}

# Step 3: Compare
$changed = @()
foreach ($n in $newHashes) {
    $match = $oldHashes | Where-Object { $_.FileName -eq $n.FileName }
    if (-not $match) {
        Write-Host "NEW report: $($n.FileName)"
        $changed += $n
    }
    elseif ($match.Hash -ne $n.Hash) {
        Write-Host "CHANGED report: $($n.FileName)"
        $changed += $n
    }
    else {
        Write-Host "UNCHANGED report: $($n.FileName)"
    }
}

# Step 4: Copy only changed files to artifact directory
foreach ($c in $changed) {
    $targetPath = Join-Path $artifactDir $c.FileName
    Copy-Item $c.FullPath $targetPath -Force
}

# Step 5: Save new manifest
$newHashes | ConvertTo-Json -Depth 3 | Out-File $newManifestPath
