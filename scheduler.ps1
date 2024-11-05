# Task Scheduler for VS Code Extensions
$ShedService = New-Object -comobject "Schedule.Service"
$ShedService.Connect()
$RunAsUserTask = "InstallVSCodeExtensions"
# Schedule the script to be run in the user context on login
$Task = $ShedService.NewTask(0)
$Task.RegistrationInfo.Description = "Visual Studio Code Extensions"
$Task.Settings.Enabled = $true
$Task.Settings.AllowDemandStart = $false
$Task.Principal.RunLevel = 1
$Trigger = $Task.Triggers.Create(9)
$Trigger.Enabled = $true
$Action = $Task.Actions.Create(0)
$Action.Path = "C:\Program Files\PowerShell\7\pwsh.exe"
$Action.Arguments = "-MTA -Command C:\installVSCodeExtensionsAndCloneRepo.ps1"
$TaskFolder = $ShedService.GetFolder("\")
$TaskFolder.RegisterTaskDefinition("$($RunAsUserTask)", $Task , 6, "Users", $null, 4)
Write-Host "Done setting up scheduled tasks"
