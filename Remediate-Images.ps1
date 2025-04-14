$ImageDir = "C:\Program Files\RestartReminder"
$Images = @{
    "notification_icon.ico" = "<YOUR_PUBLIC_URL>/notification_icon.ico"
    "startrestart.gif"     = "<YOUR_PUBLIC_URL>/startrestart.gif"
    "pleasereboot.gif"     = "<YOUR_PUBLIC_URL>/pleasereboot.gif"
    "shuttingdown.gif"     = "<YOUR_PUBLIC_URL>/shuttingdown.gif"
}

# Ensure directory exists
if (-not (Test-Path -Path $ImageDir)) {
    New-Item -Path $ImageDir -ItemType Directory -Force | Out-Null
}

# Download missing files
foreach ($file in $Images.Keys) {
    $localPath = Join-Path $ImageDir $file
    $url = $Images[$file]

    if (-not (Test-Path -Path $localPath)) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $localPath -UseBasicParsing
        } catch {
            Write-Warning "Failed to download $file from $url. Error: $_"
        }
    }
}
