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
 Start-Process -FilePath $vs_code_path -ArgumentList "--install-extension $extension" -Wait -NoNewWindow
}

cd C:\Workspaces
#Checking if destination folder exists
if (Test-Path "C:\Workspaces\To-Do-List-WebApp") {
    git clone https://avadevboxpoc@dev.azure.com/avadevboxpoc/Dev%20Box%20POC/_git/To-Do-List-WebApp
}
else {
    Write-Host "Repo already exist"
}
