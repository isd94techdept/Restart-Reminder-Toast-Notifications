# Check if reminders are disabled
if (Test-Path -Path "C:\Program Files\RestartReminder\DisableNag.txt" -PathType Leaf) {
    Write-Output "Reminders disabled by DisableNag.txt. No action required."
    exit 0
}

# Get last reboot time
$Last_reboot = Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime

# Check FastBoot status
$Check_FastBoot = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -ErrorAction SilentlyContinue).HiberbootEnabled

# Adjust last boot time based on FastBoot
if (($Check_FastBoot -eq $null) -or ($Check_FastBoot -eq 0)) {
    $Boot_Event = Get-WinEvent -ProviderName 'Microsoft-Windows-Kernel-Boot' -ErrorAction SilentlyContinue | Where-Object { $_.Id -eq 27 -and $_.Message -like "*0x0*" }
    if ($Boot_Event) { $Last_boot = $Boot_Event[0].TimeCreated }
} elseif ($Check_FastBoot -eq 1) {
    $Boot_Event = Get-WinEvent -ProviderName 'Microsoft-Windows-Kernel-Boot' -ErrorAction SilentlyContinue | Where-Object { $_.Id -eq 27 -and $_.Message -like "*0x1*" }
    if ($Boot_Event) { $Last_boot = $Boot_Event[0].TimeCreated }
}

# Determine uptime
$Uptime = if ($Last_boot) { if ($Last_reboot -gt $Last_boot) { $Last_reboot } else { $Last_boot } } else { $Last_reboot }
$Days = ((Get-Date) - $Uptime).Days

# Check if reboot is needed
if ($Days -le 5) {
    Write-Output "Computer has restarted within the last 5 days ($Days days). No remediation needed."
    exit 0
} else {
    Write-Output "Computer has not restarted in $Days days (over 5 days). Remediation required."
    exit 1
}
