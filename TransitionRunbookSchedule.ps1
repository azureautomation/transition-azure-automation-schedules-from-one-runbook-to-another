$SubscriptionID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$AutomationAccountName = "{My Automation Account Name}"
$ResourceGroupName = "{My ResourceGroup Name}"
$OldRunbookName = "{Old RunBook Name}"
$NewRunbookName = "{New RunBook Name}"
#Set to $true if you want to run a test using the parameters specified in the schedule(s)
$TestRunBook = $true

#Select the specified Subscription
Set-AzureRmContext -SubscriptionId $SubscriptionID

#Check for any webhooks
$OldWebHook = $null
$OldWebHook = Get-AzureRmAutomationWebhook -RunbookName $OldRunbookName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ErrorAction SilentlyContinue
#If there are Webhoooks, create new ones for the new runbook
if ($OldWebHook -ne $null) {
    Write-Output "Creating Webhooks"
    foreach ($WebHook in $OldWebHook) {
        try {
            $NewWebHook = New-AzureRmAutomationWebhook -Name "$($NewRunbookName)-$($WebHook.Name)" -RunbookName $NewRunbookName -IsEnabled $WebHook.IsEnabled -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -ExpiryTime $WebHook.ExpiryTime -Force -ErrorAction Stop
            $WebhookRecord = New-TemporaryFile
            Write-Host "Webhook Name: $($NewWebHook.Name)"
            Write-Host "Very Important, SAVE THIS!"
            Write-Host -BackgroundColor Red -ForegroundColor White $NewWebHook.WebhookURI 
            #Save URI to file and open it to copy and paste later
            $NewWebHook.WebhookURI | Out-File $WebhookRecord.FullName
            Start-Process Notepad $WebhookRecord.FullName
        } catch {
            Write-Output "Webhook with name '$($NewRunbookName)-$($WebHook.Name)' already exists"
        }
    }
}

#Retrieve summary of Schedule information for the old runbook
$SchedDetails = Get-AzureRmAutomationScheduledRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName $OldRunbookName
#loop through schedules and get the details
foreach ($Sched in $SchedDetails) {
    $Det = $null
    $Det = Get-AzureRmAutomationScheduledRunbook -JobScheduleId $Sched.JobScheduleId -ResourceGroupName $Sched.ResourceGroupName -AutomationAccountName $sched.AutomationAccountName -ErrorAction SilentlyContinue
    Write-Output $Det
    $Params = $Det.Parameters
    #if TestRunBook var is true then start the runbook with the parameters from the schedule
    if ($TestRunBook -eq $true) {
        #Output Job details
        Write-Output "Starting RunBook $($NewRunbookName) with parameters: `n$($Params.Keys | %{"`t$($_) = $($Params.Item($_))`n"})"
        
        #Start Runbook
        $TestJob = Start-AzureRmAutomationRunbook -Name $OldRunbookName -Parameters $Params -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
        
        #Loop while job status is not Completed, Stopped, Failed or Suspended
        $Status = Get-AzureRmAutomationJob -Id $TestJob.JobId -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName 
        Write-Output "Status:"
        while ($Status.Status -notin ("Completed","Stopped","Failed","Suspended")) {
            #Get and output the status
            Write-Output "`t$($Status.Status)"
            sleep -Seconds 30
            $Status = Get-AzureRmAutomationJob -Id $TestJob.JobId -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName 
        } 
        Write-Output "`t$($Status.Status)"

        #Get all the job output result data
        $AllOutP = Get-AzureRmAutomationJobOutput -Id $TestJob.JobId -Stream Any -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName | Sort-Object -Property Time | Get-AzureRmAutomationJobOutputRecord 
        
        #Create a new temporary file
        $TempOutputfile = New-TemporaryFile 

        #Loop through output and write to file
        foreach ($OutPut in $AllOutP) {
            $OutP = $OutPut.Value
            if ($OutP.ContainsKey("Message")) {
                "`t$($OutPut.Type)$($OutP.Message.Substring($OutP.Message.LastIndexOf(":")))" | Out-File -FilePath $TempOutputfile.FullName -Append
            }
            if ($OutP.ContainsKey("value")) {
                $OutP.value | Out-File -FilePath $TempOutputfile.FullName -Append
            }
        }

        #Open the output results in notepad, wait for user to close the file
        Write-Output "Opening Job results in Notepad, close Notepad to continue"
        Start-Process notepad -ArgumentList $TempOutputfile.fullname -wait

        #Delete the temporary file - Clean up
        del -Path $TempOutputfile.fullname

        #If the job is suspended, tell user and force it to stop - there is nothing worse than a bunch of suspended jobs hanging around
        if ($Status.Status -eq "Suspended") {
            Write-Output "The Runbook is currently suspended, forcing to stop now"
            Stop-AzureRmAutomationJob -Id $TestJob.JobId -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName 
        }
        
    }

    #Check with the user it's OK to create schedule for new runbook
    $Validate = Read-Host "Create the schedule for the new Runbook? (Y/N)"
    
    #If user validated then link the schedule to the new runbook
    if ($Validate.ToUpper() = "Y") {
        Register-AzureRMAutomationScheduledRunbook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -RunbookName $NewRunbookName -ScheduleName $Det.ScheduleName -Parameters $Params
        
        #Ask user if they want the old runbook unlinked to the schedule
        $RemoveOld = Read-Host "Remove schedule from old runbook? (Y/N)"
        if ($RemoveOld.ToUpper() -eq "Y") {
            Unregister-AzureRmAutomationScheduledRunbook -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -RunbookName $OldRunbookName -ScheduleName $Det.ScheduleName -Force
        }
    }
}
Write-Output "Completed"