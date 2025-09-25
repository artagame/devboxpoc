param(
    [string]$SqlInstance = "localhost",
    [string]$JsonPath = ".\jobsconfig.json"
)

Import-Module SqlServer -ErrorAction Stop

# Read JSON
$config = Get-Content $JsonPath | ConvertFrom-Json

# Connect to SQL Server
$server = New-Object Microsoft.SqlServer.Management.Smo.Server $SqlInstance
$jobServer = $server.JobServer

# Step action enums
$actionEnum = [Microsoft.SqlServer.Management.Smo.Agent.StepCompletionAction]

foreach ($jobConfig in $config.Jobs) {

    if (-not $jobConfig.Create -or $jobConfig.Create -eq $false) {
        Write-Output "Skipping job: $($jobConfig.JobName) (Create = false)"
        continue
    }

    # Drop existing job if present
    $existingJob = $jobServer.Jobs[$jobConfig.JobName]
    if ($existingJob) {
        Write-Output "Dropping existing job: $($jobConfig.JobName)"
        $existingJob.Drop()
    }

    # Create new job
    Write-Output "Creating job: $($jobConfig.JobName)"
    $job = New-Object Microsoft.SqlServer.Management.Smo.Agent.Job($jobServer, $jobConfig.JobName)
    if ($jobConfig.JobCategory) { $job.Category = $jobConfig.JobCategory }
    if ($jobConfig.Description) { $job.Description = $jobConfig.Description }
    $job.IsEnabled = $jobConfig.Enabled
    $job.Create()

    # Steps
    if ($jobConfig.Steps) {
        $stepId = 1
        foreach ($step in $jobConfig.Steps) {
            Write-Output "Adding step: $($step.StepName)"
            $jobStep = New-Object Microsoft.SqlServer.Management.Smo.Agent.JobStep($job, $step.StepName)
            $jobStep.StepID = $stepId
            $jobStep.SubSystem = $step.Subsystem

            if ($step.Subsystem -eq "SSIS" -and $step.SSIS) {
                $command = "/ISSERVER \"" + $step.SSIS.PackagePath + "\" /SERVER " + $step.SSIS.Server + " /Par \"LOGGING_LEVEL;(Int32)1\""
                if ($step.SSIS.Environment) {
                    $command += " /ENVREFERENCE \"" + $step.SSIS.Environment + "\""
                }
                $jobStep.Command = $command
            }
            elseif ($step.Command) {
                $jobStep.Command = $step.Command
            }

            if ($step.ProxyName) {
                Write-Output "Assigning proxy: $($step.ProxyName)"
                $jobStep.RunAs = $step.ProxyName
            }

            $jobStep.OnSuccessAction = if ($step.OnSuccessAction) {
                $actionEnum::$($step.OnSuccessAction)
            } else {
                $actionEnum::QuitWithSuccess
            }

            $jobStep.OnFailAction = if ($step.OnFailAction) {
                $actionEnum::$($step.OnFailAction)
            } else {
                $actionEnum::QuitWithFailure
            }

            $jobStep.Create()
            $stepId++
        }
    }

    # Schedule
    if ($jobConfig.Schedule) {
        Write-Output "Adding schedule: $($jobConfig.Schedule.Name)"
        $schedule = New-Object Microsoft.SqlServer.Management.Smo.Agent.JobSchedule($job, $jobConfig.Schedule.Name)
        $schedule.FrequencyTypes = [Microsoft.SqlServer.Management.Smo.Agent.FrequencyTypes]::$($jobConfig.Schedule.FrequencyType)
        $schedule.FrequencyInterval = $jobConfig.Schedule.FrequencyInterval
        $schedule.ActiveStartTimeOfDay = [TimeSpan]::Parse($jobConfig.Schedule.ActiveStartTimeOfDay)
        $schedule.Create()
    }

    # Notifications
    if ($jobConfig.Notifications) {
        $notifyMethods = 0
        foreach ($m in $jobConfig.Notifications.Methods) {
            switch ($m) {
                "Email"    { $notifyMethods = $notifyMethods -bor [Microsoft.SqlServer.Management.Smo.Agent.NotifyMethods]::NotifyEmail }
                "Pager"    { $notifyMethods = $notifyMethods -bor [Microsoft.SqlServer.Management.Smo.Agent.NotifyMethods]::NotifyPager }
                "NetSend"  { $notifyMethods = $notifyMethods -bor [Microsoft.SqlServer.Management.Smo.Agent.NotifyMethods]::NotifyNetSend }
            }
        }
        if ($notifyMethods -eq 0) {
            $notifyMethods = [Microsoft.SqlServer.Management.Smo.Agent.NotifyMethods]::NotifyEmail
        }

        foreach ($op in $jobConfig.Notifications.Operators) {
            $operator = $jobServer.Operators[$op.Name]
            if (-not $operator) {
                Write-Output "Creating operator: $($op.Name)"
                $operator = New-Object Microsoft.SqlServer.Management.Smo.Agent.Operator($jobServer, $op.Name)
                $operator.EmailAddress = $op.Email
                $operator.Create()
            }

            if ($jobConfig.Notifications.NotifyOn.OnFailure) {
                $job.AddNotification($operator.Name, $notifyMethods, [Microsoft.SqlServer.Management.Smo.Agent.CompletionAction]::OnFailure)
            }
            if ($jobConfig.Notifications.NotifyOn.OnSuccess) {
                $job.AddNotification($operator.Name, $notifyMethods, [Microsoft.SqlServer.Management.Smo.Agent.CompletionAction]::OnSuccess)
            }
            if ($jobConfig.Notifications.NotifyOn.OnCompletion) {
                $job.AddNotification($operator.Name, $notifyMethods, [Microsoft.SqlServer.Management.Smo.Agent.CompletionAction]::OnCompletion)
            }
        }
    }

    Write-Output "Job [$($jobConfig.JobName)] recreated successfully."
}
