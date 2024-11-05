# Set Execution Policy to Bypass for the current process
Set-ExecutionPolicy Bypass -Scope Process -Force

# Set security protocol to support TLS 1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# Install Chocolatey
iex ((New-Object System.Net.WebClient).DownloadString("https://community.chocolatey.org/install.ps1"))

# Install Git, Azure CLI, and Visual Studio Code
choco install -y git
choco install -y azure-cli
choco install -y vscode
choco install -y nodejs

cd "C:\"
mkdir "Workspaces"
wsl.exe --update
powershell.exe -File 'C:\scheduler.ps1'
