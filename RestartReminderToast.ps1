param (
    [string]$Uri
)

# Handle protocol URI
if ($Uri) {
    if ($Uri -eq 'RestartScript:') {
        shutdown /r /f /t 0
        exit
    }
}

# Define paths (customize these as needed)
$ImageDir = "C:\Program Files\RestartReminder"
$IconPath = "$ImageDir\notification_icon.ico"
$StartRestartGif = "$ImageDir\startrestart.gif"
$PleaseRebootGif = "$ImageDir\pleasereboot.gif"
$ShuttingDownGif = "$ImageDir\shuttingdown.gif"

# Ensure directory exists
if (-not (Test-Path -Path $ImageDir)) {
    New-Item -Path $ImageDir -ItemType Directory -Force | Out-Null
}

# Get last reboot time
$Last_reboot = Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime
$Check_FastBoot = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -ErrorAction SilentlyContinue).HiberbootEnabled

if (($Check_FastBoot -eq $null) -or ($Check_FastBoot -eq 0)) {
    $Boot_Event = Get-WinEvent -ProviderName 'Microsoft-Windows-Kernel-Boot' -ErrorAction SilentlyContinue | Where-Object { $_.Id -eq 27 -and $_.Message -like "*0x0*" }
    if ($Boot_Event) { $Last_boot = $Boot_Event[0].TimeCreated }
} elseif ($Check_FastBoot -eq 1) {
    $Boot_Event = Get-WinEvent -ProviderName 'Microsoft-Windows-Kernel-Boot' -ErrorAction SilentlyContinue | Where-Object { $_.Id -eq 27 -and $_.Message -like "*0x1*" }
    if ($Boot_Event) { $Last_boot = $Boot_Event[0].TimeCreated }
}

$Uptime = if ($Last_boot) { if ($Last_reboot -gt $Last_boot) { $Last_reboot } else { $Last_boot } } else { $Last_reboot }
$Days = ((Get-Date) - $Uptime).Days

# Protocol for restart action
$ActionProtocol = 'RestartScript'
$RestartScript = 'shutdown /r /f /t 0'
$RestartPath = "$env:TEMP\RestartScript.cmd"
$RegPath = "HKCU:\SOFTWARE\Classes\$ActionProtocol\shell\open\command"

$RestartScript | Out-File $RestartPath -Encoding ASCII -Force
New-Item -Path $RegPath -Force | Out-Null
New-ItemProperty -Path "HKCU:\SOFTWARE\Classes\$ActionProtocol" -Name "URL Protocol" -Value "" -Force | Out-Null
Set-ItemProperty -Path $RegPath -Name "(Default)" -Value $RestartPath -Force

# Notification configuration
$HeroImage = $null
$ImageXml = ""
$Scenario = "reminder"
$Audio = ""
$Progress = ""
$Branding = ""
switch ($Days) {
    {$_ -ge 20} {
        $Title = "Restart In Progress"
        $Message = "Your computer has not restarted in 20 days. It will restart in 5 minutes! Please save all work now."
        $Audio = '<audio src="ms-winsoundevent:Notification.Looping.Alarm4" loop="true" />'
        $Buttons = @"
<action activationType="protocol" arguments="${ActionProtocol}:" content="Restart Now" />
"@
        $HeroImage = $ShuttingDownGif
        break
    }
    {$_ -ge 16} {
        $Title = "Restart Required"
        $Remaining = 20 - $Days
        $Message = "It has been $Days days since your PC was last rebooted. Your computer will restart automatically in $Remaining days. Please save your work and restart now."
        $Audio = '<audio src="ms-winsoundevent:Notification.Reminder" />'
        $Buttons = @"
<input id="snoozetime" type="selection" defaultInput="5">
    <selection id="5" content="5 min" />
    <selection id="10" content="10 min" />
    <selection id="60" content="1 hr" />
    <selection id="240" content="4 hrs" />
    <selection id="1440" content="1 day" />
</input>
<action activationType="system" arguments="snooze" hint-inputId="snoozeTime" content="Snooze" />
<action activationType="protocol" arguments="${ActionProtocol}:" content="Restart Now" />
"@
        $HeroImage = $PleaseRebootGif
        break
    }
    {$_ -ge 11} {
        $Title = "Restart Recommended"
        $Message = "It has been $Days days since your PC was last rebooted. It is important to restart your computer to ensure you have the latest security updates."
        $Audio = '<audio src="ms-winsoundevent:Notification.SMS" />'
        $Buttons = @"
<action activationType="protocol" arguments="${ActionProtocol}:" content="Restart Now" />
<action activationType="protocol" arguments="Dismiss" content="Dismiss" />
"@
        $HeroImage = $StartRestartGif
        break
    }
    {$_ -ge 6} {
        $Title = "Restart Recommended"
        $Message = "It has been $Days days since your PC was last rebooted. Please restart your computer daily to keep your computer secure and up to date."
        $Audio = '<audio src="ms-winsoundevent:Notification.Default" />'
        $Buttons = @"
<action activationType="protocol" arguments="Dismiss" content="Dismiss" />
"@
        $HeroImage = $StartRestartGif
        break
    }
    default { exit }
}

if ($HeroImage -and (Test-Path $HeroImage)) {
    $ImageXml = "<image placement='hero' src='$HeroImage'/>"
} else {
    Write-Warning "Hero image not found: $HeroImage"
}

[xml]$Toast = @"
<toast scenario="$Scenario">
  <visual>
    <binding template="ToastGeneric">
      $ImageXml
      <text>$Title</text>
      <text>$Message</text>
      $Progress
      $Branding
    </binding>
  </visual>
  $Audio
  <actions>
    $Buttons
  </actions>
</toast>
"@

# Register application for notifications
$AppID = "RestartReminder"
$DisplayName = "Restart Reminder"
$NotifRegPath = "HKCU:\Software\Classes\AppUserModelId\$AppID"
New-Item -Path $NotifRegPath -Force | Out-Null
New-ItemProperty -Path $NotifRegPath -Name DisplayName -Value $DisplayName -PropertyType String -Force | Out-Null
New-ItemProperty -Path $NotifRegPath -Name IconUri -Value $IconPath -PropertyType ExpandString -Force | Out-Null
New-ItemProperty -Path $NotifRegPath -Name IconBackgroundColor -Value "Transparent" -PropertyType String -Force | Out-Null
New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\$AppID" -Name 'ShowInActionCenter' -Value 1 -PropertyType DWORD -Force | Out-Null

# Display notification
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
$ToastXml = New-Object Windows.Data.Xml.Dom.XmlDocument
$ToastXml.LoadXml($Toast.OuterXml)

$Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppID)
if ($Days -ge 20) {
    $EndTime = [DateTime]::Now.AddSeconds(300)
    shutdown /r /t 300
    $MinutesRemaining = 5
    while ([DateTime]::Now -lt $EndTime -and $MinutesRemaining -ge 1) {
        $SecondsLeft = [math]::Round(($EndTime - [DateTime]::Now).TotalSeconds)
        $MinutesLeft = [math]::Ceiling($SecondsLeft / 60)
        $ToastMessage = "Your computer has not restarted in 20 days. It will restart in $MinutesLeft minute(s)! Please save all work now."
        $ToastXml.LoadXml("<toast scenario=`"alarm`"><visual><binding template=`"ToastGeneric`">$ImageXml<text>$Title</text><text>$ToastMessage</text>$Branding</binding></visual>$Audio<actions>$Buttons</actions></toast>")
        $Notification = New-Object Windows.UI.Notifications.ToastNotification $ToastXml
        $Notifier.Show($Notification)
        Start-Sleep -Seconds 60
        $Notifier.Hide($Notification)
        $MinutesRemaining--
    }
} else {
    $Notification = New-Object Windows.UI.Notifications.ToastNotification $ToastXml
    $Notifier.Show($Notification)
}
