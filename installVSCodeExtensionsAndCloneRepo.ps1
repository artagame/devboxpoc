Write-Host "========================================================================================================="
Write-Host "Installing VS Code Extensions..."
Write-Host "========================================================================================================="

$vs_code_path = "C:/Program Files/Microsoft VS Code/bin/code.cmd"

# Array of VS Code extensions to install
$extensions = @(
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "flowtype.flow-for-vscode",
    "mgmcdermott.vscode-language-babel",
    "DevCenter.ms-devbox"
)

foreach ($extension in $extensions) {
 Start-Process -FilePath $vs_code_path -ArgumentList "--install-extension $extension --force" -Wait -NoNewWindow
}


cd C:\Workspaces
#Checking if destination folder exists
Write-Host "========================================================================================================="
Write-Host "Checking if the project repository already exists..."
Write-Host "========================================================================================================="

if (Test-Path "C:\Workspaces\To-Do-List-WebApp") {
    Write-Host "========================================================================================================="
    Write-Host "Project repository already exists..."
    Write-Host "========================================================================================================="

}
else {
    Write-Host "========================================================================================================="
    Write-Host "Cloning Repository...."
    Write-Host "========================================================================================================="
    git clone https://avadevboxpoc@dev.azure.com/avadevboxpoc/Dev%20Box%20POC/_git/To-Do-List-WebApp
}
