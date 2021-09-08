cls

$Var_EmailStyleSheet = Get-Content "C:\scripts\Email_Style.txt"
$Var_IntRelay = "EmailRelay"
$Var_Controllers = @("CitrixController)
$Var_Sender = "EmailSender"
$Var_Recipients = @("EmailRecipients)

$Date = $(Get-Date -Format 'yyyy-MM-dd_HH_mm')
$LogFileRoot = "$PSScriptRoot\$Date"
New-Item $($LogFileRoot) -ItemType Directory | Out-Null

$Transcript = "$($LogFileRoot)\$($Date)_transcript.txt" 
$ErrorFile = "$($LogFileRoot)\$($Date)_errors.txt" 
$Timestamps = "$($LogFileRoot)\$($Date)_timestamps.txt" 


$ScriptStartTime = Get-Date
$Start = $ScriptStartTime.AddMinutes(-20)

Start-Transcript -Path $Transcript

$Modules = @("PoshRSJob","C:\Program Files\Citrix\PowerShellModules\Citrix.Broker.Commands\Citrix.Broker.Commands.psd1")
$Modules | % {
	Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Importing Module $_"
	Remove-Module $_ -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	Import-Module $_ -ErrorAction Stop -WarningAction SilentlyContinue
}

$elapsedTime = [System.Diagnostics.Stopwatch]::StartNew()

$Machines = Get-BrokerMachine -AdminAddress $($Var_Controllers |Get-Random) -MaxRecordCount 10000 -PowerState On -SessionSupport SingleSession | Where-Object {$_.IPAddress -ne $null}

$Threads_MaxParallel = 50
$Threads_TimeOut = 120
$ObjectRunspaceFunctions = @()
$ObjectRunspaceModules = @()
$ObjectRunspaceSnapins = @()
$ObjectRunspaceScriptBlock = {
      $ThreadObj = New-Object -TypeName PSObject    
      $ThreadObj | Add-Member -MemberType NoteProperty -Name "Start_Time" -Value $(Get-Date -Format G)
      $ThreadObj | Add-Member -MemberType NoteProperty -Name "Machine_Object" -Value $_
      $ThreadObj | Add-Member -MemberType NoteProperty -Name "Machine_Name" -Value $($_.HostedMachineName)
      
      
      If($($ThreadObj.Machine_Name)){
            try { 
                  [Net.DNS]::GetHostEntry($($ThreadObj.Machine_Name)).AddressList.IPAddressToString | Out-Null
                  If($((New-Object Net.NetworkInformation.Ping).send($($_.HostedMachineName)).Status) -eq "Success"){
                        try {
                              $Events = Get-WinEvent -ComputerName $($_.HostedMachineName) -FilterHashtable @{logname='system'; ID=4101;StartTime = $($using:Start); EndTime = $($using:ScriptStartTime) } -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                         } catch {
                              $ThreadObj | Add-Member -MemberType NoteProperty -Name "Error" -Value "Events lookup failed for machine name $($ThreadObj.Machine_Name)"
                        }      
                              
                        If ($Events){
                            $ThreadObj | Add-Member -MemberType NoteProperty -Name "Events" -Value $Events
                            $ThreadObj | Add-Member -MemberType NoteProperty -Name "Timestamps" -Value $(($Events.TimeCreated) -join "; ")                                    
                        } 
                                  
                  } else {
                        $ThreadObj | Add-Member -MemberType NoteProperty -Name "Error" -Value "Ping failed for machine name $($ThreadObj.Machine_Name)"
                  }
            } catch {
                  $ThreadObj | Add-Member -MemberType NoteProperty -Name "Error" -Value "DNS lookup failed for machine name $($ThreadObj.Machine_Name). $($_.Exception)"
            }
      } else {
            $ThreadObj | Add-Member -MemberType NoteProperty -Name "Error" -Value "Missing machine Name"
      }
      
      $ThreadObj | Add-Member -MemberType NoteProperty -Name "End_Time" -Value $(Get-Date -Format G)
      $ThreadObj
}

$Machines | Start-RSJob -FunctionsToLoad $ObjectRunspaceFunctions -ScriptBlock $ObjectRunspaceScriptBlock -Name {$_.HostedMachineName} -Throttle $Threads_MaxParallel | Out-Null
Get-RSJob | Wait-RSJob -ShowProgress -Timeout $Threads_TimeOut | Out-Null
$Results = Get-RSJob -State Completed | Receive-RSJob
Get-RSJob | Remove-RSJob -Force

$ValidMachines = $Results | Where-Object {$_.Events -ne $null} 
$ErrorMachines = $Results | Where-Object {$_.Error -ne $null}
$ErrorMachines | out-file $ErrorFile 
$UserToContact = $ValidMachines | Select Machine_Name, @{Name="Current_User";Expression={$_.Machine_Object.SessionUserName}}, @{Name="ESXi_Host";Expression={$_.Machine_Object.HostingServerName}} | ConvertTo-Html -Head $Var_EmailStyleSheet
$ValidMachines | select Machine_Name, timestamps | out-file $timestamps

$Modules | % {
	Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Removing Module $_"
	Remove-Module $_ -ErrorAction Continue
}

Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Total execution time is: $($elapsedTime.Elapsed)"
Stop-Transcript | Out-Null

if ($ValidMachines -ne $null) {

    Send-MailMessage -from $Var_Sender `
                       -to $Var_recipients `
                       -subject "TDR Alert" `
                       -body ("
                          Help Desk,<br /><br />
                          Below are the user(s) who need to be logged off their VDI session due to a host issue. They can log back on immediately.<br /><br />
                          Please reach out to the user(s) by phone first and if there is no answer, follow up using the templated e-mail message.<br /><br />
                          If this alert is generated after hours (between 6:00 p.m.-9:00 a.m. EST), please first reach out to the on-call Citrix resource by phone. You should then proceed contacting the user(s) following the process above.<br /><br />
                          Thanks<br /><br /> 
                                                                                          
                       " + $UserToContact )` -Attachments $timestamps,$Transcript -smtpServer $Var_IntRelay -BodyAsHtml     
}




#>