# Settings
$softwareList = Get-Content -Path "C:\temp\Scripts\software_list.json" | ConvertFrom-Json
$downloadDir = "C:\temp\Instaladores"
$logFile = "C:\temp\Scripts\update_log.log"
$DestDir = "D:\Applications" 
$updateHistoryFile = "D:\Applications\update_history.json"
$supportedExtensions = @(".exe", ".msi")

# Create download directory if it doesn't exist
if (!(Test-Path -Path $downloadDir)) { New-Item -ItemType Directory -Path $downloadDir -Force }
# Delete old log file
if (Test-Path $updateHistoryFile) { Remove-Item -Path $updateHistoryFile -Force -ErrorAction SilentlyContinue }

# Function to record updates in JSON
function Write-UpdateHistory {
    param (
        [string]$software,
        [string]$version,
        [string]$path
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Create new entry structure
    $newEntry = @{
        software  = $software
        version   = $version
        path      = $path
        timestamp = $timestamp
    }
    
    # Check if JSON file exists
    if (Test-Path $updateHistoryFile) {
        # Read existing content
        $updateHistory = Get-Content -Path $updateHistoryFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        # Initialize if empty
        if (-not $updateHistory) {
            $updateHistory = @{ updates = @() }
        }

        # Check for duplicate entries
        $entryExists = $updateHistory.updates | Where-Object { 
            $_.software -eq $newEntry.software -and $_.version -eq $newEntry.version
        }

        if (-not $entryExists) {
            # Add new entry            
            $updateHistory.updates += $newEntry
        }
    }
    else {
        # Initialize structure if file doesn't exist
        $updateHistory = @{ updates = @($newEntry) }
    }

    # Save updated JSON
    $updateHistory | ConvertTo-Json -Depth 10 | Set-Content -Path $updateHistoryFile -Encoding UTF8
}

# Function for logging
function Write-Log {
    param (
        [string]$message,
        [String]$color = "white"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    
    # Use file locking to prevent concurrent access
    $fileStream = [System.IO.File]::Open($logFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $streamWriter = New-Object System.IO.StreamWriter($fileStream)
    $streamWriter.WriteLine($logMessage)
    $streamWriter.Close()
    $fileStream.Close()
    
    Write-Host $logMessage -ForegroundColor $color
}

# Function to get installer version from filename
function Get-InstallerVersion {
    param ([string]$installerPath)
    try {
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($installerPath)
        if ($fileName -match "_(\d+\.\d+(\.\d+){0,2})_") {
            return $matches[1]
        }
        else {
            Write-Log "Installer version not found in filename: $installerPath"  
            return $null
        }
    }
    catch {
        Write-Log "Error retrieving installer version: $installerPath - $_"
        return $null
    }
}

# Function to get latest version via Winget
function Get-LatestVersion {
    param ([string]$softwareId)
    try {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Log "winget is not installed or available on the system."
            return $null
        }

        $wingetInfo = winget show --id $softwareId | Out-String
        $latestVersion = ($wingetInfo -split "`n" | Where-Object { $_ -match "Version:\s+([\d\.]+)" } | ForEach-Object { $matches[1] }) | Select-Object -First 1
        return $latestVersion
    }
    catch {
        Write-Log "Error retrieving latest version of $softwareId - $_"
        return $null
    }
}

# Function to generate friendly folder name
function Get-FriendlyFolderName {
    param ([string]$installerName)
    $friendlyName = $installerName.Split('_')[0]
    $friendlyName = $friendlyName.Substring(0, 1).ToUpper() + $friendlyName.Substring(1).ToLower()
    return $friendlyName
}

# Function to download and update installer
function DownloadAndUpdateInstaller {
    param (
        [string]$software,
        [string]$latestVersion
    )

    try {
        winget download --id $software --download-directory $downloadDir --accept-source-agreements --accept-package-agreements
        if ($?) {
            Write-Log "Download completed for $software (version $latestVersion)." -color Green
        }
        else {
            Write-Log "winget command failed for $software." -color Red
        }
    }
    catch {
        Write-Log "Error downloading $software $_" -color Red
    }
}

# Check and download updates
foreach ($software in $softwareList.softwares) {
    Write-Log "Checking updates for $software..."

    $existingInstaller = $null
    $wingetOutput = winget show --id $software
    $softwareName = ($wingetOutput | Select-String -Pattern "^Found\s+([^\[]+)").Matches.Groups[1].Value.Trim()

    foreach ($extension in $supportedExtensions) {
        $installer = Get-ChildItem -Path $downloadDir -Filter "*$softwareName*$extension" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    
        if ($extension -eq ".exe" -and $installer) {
            $existingInstaller = $installer
        }
        elseif ($extension -eq ".msi" -and !$existingInstaller -and $installer) {
            $existingInstaller = $installer
        }
    }
        
    $latestVersion = Get-LatestVersion -softwareId $software
    if (-not $latestVersion) {
        Write-Log "Skipped: Failed to retrieve latest version of $software."
        continue
    }

    if ($existingInstaller) {
        Write-Log "Existing installer found: $($existingInstaller.FullName)"

        $currentVersion = Get-InstallerVersion -installerPath $existingInstaller.FullName
        if (-not $currentVersion) {
            Write-Log "Skipped: Could not get version of existing installer for $software." -color Red
            continue
        }

        Write-Log "Current installer version: $currentVersion" -color DarkYellow
        Write-Log "Latest available version: $latestVersion" -color Cyan

        if ($currentVersion -ne $latestVersion) {
            Write-Log "New version available. Updating $software..." -color DarkGreen

            try {
                Remove-Item -Path $existingInstaller.FullName -Force
                $yamlFile = [System.IO.Path]::ChangeExtension($existingInstaller.FullName, ".yaml")
                Remove-Item -Path $yamlFile -Force
                Write-Log "Old installer removed: $($existingInstaller.FullName)" -color Green
            }
            catch {
                Write-Log "Error removing old installer $($existingInstaller.FullName): $_" -color Red
                continue
            }
            
            DownloadAndUpdateInstaller -software $software -latestVersion $latestVersion
        }
        else {
            Write-Log "Installer is already up-to-date. No action required." -color Green
        }
    }
    else {
        Write-Log "No installer found for $software. Downloading latest version..." -color Yellow
        DownloadAndUpdateInstaller -software $software -latestVersion $latestVersion
    }
}

# Copy installers to organized server folders
$installers = Get-ChildItem -Path $downloadDir -File
$processedFolders = @()

foreach ($installer in $installers) {
    $AppFolder = Join-Path -Path $DestDir -ChildPath (Get-FriendlyFolderName -installerName $installer.BaseName)
    $software = Get-FriendlyFolderName -installerName $installer.BaseName

    if ($processedFolders -contains $AppFolder) {
        continue
    }

    # Check for existing server installer
    $existingInstaller = $null
    foreach ($extension in $supportedExtensions) {
        $existingInstaller = Get-ChildItem -Path $AppFolder -Filter "*$($installer.BaseName)*$extension" -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($existingInstaller) { break }
    }

    # Get server version (if exists)
    $serverVersion = if ($existingInstaller) { Get-InstallerVersion -installerPath $existingInstaller.FullName } else { "0.0.0.0" }

    # Get downloaded version
    $downloadedVersion = Get-InstallerVersion -installerPath $installer.FullName

    Write-Log "Software: $software → Server version: $serverVersion | Downloaded version: $downloadedVersion"

    # Compare versions
    if ([version]$downloadedVersion -gt [version]$serverVersion) {
        Write-Log "New version detected. Updating server..."

        # Create folder if missing
        if (!(Test-Path -Path $AppFolder)) {
            New-Item -ItemType Directory -Path $AppFolder -Force
        }

        # Remove old files
        $oldFiles = Get-ChildItem -Path $AppFolder -File
        if ($oldFiles.Count -gt 0) {
            Write-Log "Removing $($oldFiles.Count) old file(s) from $AppFolder."
            $oldFiles | Remove-Item -Force -Recurse
        }

        # Copy new files
        try {
            $installerBaseName = [System.IO.Path]::GetFileNameWithoutExtension($installer.Name)
            $matchingFiles = Get-ChildItem -Path $downloadDir -Filter "$installerBaseName.*" -File
            
            foreach ($file in $matchingFiles) {
                $DestPath = Join-Path -Path $AppFolder -ChildPath $file.Name
                Write-Log "Copying $($file.Name) to $DestPath." -color Green
                Copy-Item -Path $file.FullName -Destination $DestPath -Force
            }

            # Record update
            Write-UpdateHistory -software $software -version $downloadedVersion -path $AppFolder
        }
        catch {
            Write-Log "Error copying files to $AppFolder $_" -color Red
        }
    }
    else {
        Write-Log "Server version is already up-to-date. No action required."
    }

    $processedFolders += $AppFolder
    Start-Sleep -Seconds 1
}

Write-Log "Update process completed." -color Green
