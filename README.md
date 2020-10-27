Transition Azure Automation schedules from one Runbook to another
=================================================================


  *  
SYNOPSIS
This script transitions all Azure Automation Runbook schedules from one Runbook to another


  *  
DESCRIPTION
You've gone to great lengths to create all the schedules, linked to your current Runbook, and set all the parameters as required for each schedule.
Now you've created a new version of the Runbook, but what a pain what a pain to go through all that setup again.
This script will transition from one Runbook to another


  *  
all the schedule links

  *  
all parameters

  *  test the new runbook with the provided parameters and displays the output for you to check

  *  remove the link from the old Runbook



  *  
MODULES

  *  
AzureRM > 4.0.0




  *  
INPUTS

  *  
$SubscriptionID
The subscription GUID for the Automation Account

  *  
$AutomationAccountName
The Automation Account Name where the Runbooks are published

  *  
$ResourceGroupName
The Resource Group Name for the Automation Account

  *  
$OldRunbookName
The Old RunBook Name with the current schedules linked with parameters

  *  
$NewRunbookName
The New RunBook Name to move the schedules to, and test against

  *  
$TestRunBook
Set this to $true if you want to run a test using the parameters specified in the schedule(s)
Set this to $false if you DON'T want to test



 


        
    
TechNet gallery is retiring! This script was migrated from TechNet script center to GitHub by Microsoft Azure Automation product group. All the Script Center fields like Rating, RatingCount and DownloadCount have been carried over to Github as-is for the migrated scripts only. Note : The Script Center fields will not be applicable for the new repositories created in Github & hence those fields will not show up for new Github repositories.
