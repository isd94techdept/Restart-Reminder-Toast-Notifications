$ImageDir = "C:\Program Files\RestartReminder"
$RequiredFiles = @(
    "notification_icon.ico",
    "startrestart.gif",
    "pleasereboot.gif",
    "shuttingdown.gif"
)

$AllExist = $true
foreach ($file in $RequiredFiles) {
    if (-not (Test-Path -Path (Join-Path $ImageDir $file))) {
        $AllExist = $false
    }
}

if ($AllExist) {
    Write-Host "All image files exist, no action needed."
    exit 0
} else {
    Write-Host "One or more image files are missing, remediation required."
    exit 1
}
