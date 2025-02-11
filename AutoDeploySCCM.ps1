# Initial settings
$DPGroupName = ""  # Distribution point group
$CollectionName = ""  # Collection name for deployment
$updateHistoryPath = ""  # Path to the JSON file containing updates
$SccmAppFolder = ""  # Path in SCCM for organizing applications
$SiteCode = "" # Site code
$ProviderMachineName = "" # Provider machine name

function ConnectSCCM {
    param (
        [string]$SiteCode,
        [string]$ProviderMachineName
    )
    # Initialization parameters
    $initParams = @{
        #Verbose = $true  # Uncomment this line to enable detailed logging
        ErrorAction = "Stop"  # Uncomment this line to stop the script on errors
    }
    # Import the ConfigurationManager.psd1 module
    if ((Get-Module ConfigurationManager) -eq $null) {
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
    }
    # Connect to the site drive if not already connected
    if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams -Credential 
    }
    # Set the current location to the site code
    Push-Location "$($SiteCode):\"
}

# Function to log messages
function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path "C:\Users\user\Desktop\update_log.log" -Value "[$timestamp] $message"
    Write-Host "[$timestamp] $message"
}

# Function to identify the installer type
function Get-InstallerType {
    param ([string]$file)
    if ($file -match "\.msi$") {
        return "MSI"
    }
    elseif ($file -match "\.exe$") {
        return "EXE"
    }
    else {
        return "Other"
    }
}

# Function to extract installation parameters from YAML
function Get-ExeInstallParameters {
    param (
        [string]$YamlFilePath
    )

    if (-not (Test-Path $YamlFilePath)) {
        Write-Log "Error: YAML file not found at $YamlFilePath."
        return ""
    }

    $yamlContent = Get-Content -Path $YamlFilePath -Raw
    $installParams = ""

    # Look for the InstallerSwitches section and extract Silent or Custom values
    $silentMatch = $yamlContent | Select-String -Pattern "Silent:\s*(.+)"
    $customMatch = $yamlContent | Select-String -Pattern "Custom:\s*(.+)"

    if ($silentMatch) {
        $installParams = $silentMatch.Matches.Groups[1].Value.Trim()
    }
    elseif ($customMatch) {
        $installParams = $customMatch.Matches.Groups[1].Value.Trim()
    }

    if ($installParams -eq "") {
        Write-Log "Warning: No installation parameters found in $YamlFilePath."
    }

    return $installParams
}

# Function to create automatic deployment in SCCM
function CreateSccmDeployment {
    param (
        [string]$AppName,
        [string]$AppVersion,
        [string]$AppPublisher,
        [string]$AppType,
        [string]$AppFilePath,
        [string]$AppYamlPath
    )

    # Check if the application already exists and remove it if it does
    $TestApplication = Get-CMApplication -Name "$AppName"
    if ($TestApplication) {
        # Check if there are any active deployments
        $Deployments = Get-CMDeployment -SoftwareName "$AppName" -ErrorAction SilentlyContinue
    
        if ($Deployments) {
            Write-Log "Removing deployment for $AppName..."
            foreach ($deployment in $Deployments) {
                Remove-CMApplicationDeployment -Name $AppName -CollectionName $deployment.CollectionName -Force -ErrorAction SilentlyContinue
            }
        }
        else {
            Write-Log "No deployments found for $AppName."
        }
    
        # Now, we can safely remove the application
        Write-Log "Removing application $AppName..."
        Remove-CMApplication -Name "$AppName" -Force
    }
    else {
        Write-Log "Application $AppName not found in SCCM."
    }

    # Create a new application in SCCM
    Write-Log "Creating application $AppName in SCCM..."
    New-CMApplication -Name "$AppName" -SoftwareVersion "$AppVersion"

    # PowerShell script to check if the software is already installed and matches the version
    $scriptText = @" 
    `$Product = "$AppName"   # Application name
    `$ProductVersion = "$AppVersion" # Expected version
    # Search in the uninstall registry (64 and 32 bits)
    `$installedApps = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, 
                                      HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall |
        Get-ItemProperty |
        Where-Object { `$_.DisplayName -match `$Product }
    # Check if the software was found
    if (`$installedApps) {
        `$found = `$false
        foreach (`$app in `$installedApps) {
            # Normalize the version by removing extra zeros
            `$installedVersion = (`$app.DisplayVersion -replace "^(\d+\.\d+)\.0+.*$", '$1')
            `$expectedVersion = (`$ProductVersion -replace "^(\d+\.\d+)\.0+.*$", '$1')
            if (`$installedVersion -eq `$expectedVersion) {
                Write-Host "Installed"
                #return `$true
            } else {
                #Write-Host "Installed version (`$app.DisplayVersion) does not match the required version (`$ProductVersion)."
            }
        }
        if (`$found) { return `$false }
    } else {
        #Write-Host "No software matching '`$Product' was found."
        return `$false
    }
"@

    if ($AppType -eq "MSI") {
        Add-CMMsiDeploymentType -ApplicationName "$AppName" -DeploymentTypeName "DeployAuto_$AppName" -ContentLocation "$AppFilePath" -UserInteractionMode Hidden
    }
    elseif ($AppType -eq "EXE") {
        Pop-Location  
        # Automatically search for the YAML file within the software folder
        $yamlFile = Get-ChildItem -Path $AppYamlPath -Filter "*.yaml" | Select-Object -First 1
        $yamlFilePath = if ($yamlFile) { $yamlFile.FullName } else { "" }

        if ($yamlFilePath -eq "") {
            Write-Log "Warning: No YAML file found for $AppName."
        }

        # Extract installation parameters from YAML
        $installParams = Get-ExeInstallParameters -YamlFilePath $yamlFilePath

        if ($installParams -eq "") {
            Write-Log "Warning: No parameters found for $AppName. Installing with defaults."
        }
        # Identify the EXE installer name in the folder
        $installerFile = Get-ChildItem -Path $AppFilePath -Filter "*.exe" | Select-Object -First 1
        if ($installerFile) {
            $installerName = $installerFile.Name
        }
        else {
            Write-Log "Error: No EXE installer found for $AppName!"
            return
        }
        Push-Location "$($SiteCode):\"
        $InstallCommand = @"
        "$installerName" $installParams
"@
        # Create the deployment in SCCM with the parameters
        Add-CMScriptDeploymentType -ApplicationName "$AppName" -DeploymentTypeName "DeployAuto_$AppName" -ContentLocation "$AppYamlPath" -InstallCommand "$InstallCommand" -UserInteractionMode Hidden -InstallationBehaviorType InstallForSystem -LogonRequirementType WhetherOrNotUserLoggedOn -EstimatedRuntimeMins 10 -ScriptLanguage PowerShell -ScriptText $scriptText
    }
    else {
        Write-Log "Unrecognized installer type: $AppType"
        return
    }

    # Start content distribution to distribution points
    if (-not [string]::IsNullOrEmpty($DPGroupName)) {
        Write-Log "Distributing content to distribution points..."
        Start-CMContentDistribution -ApplicationName "$AppName" -DistributionPointGroupName "$DPGroupName"
    }
    else {
        Write-Log "Warning: No distribution point group defined. Skipping this step."
    }
    # Create a new application deployment in SCCM
    Write-Log "Creating deployment for $AppName..."
    New-CMApplicationDeployment -Name "$AppName" -CollectionName "$CollectionName" -DeployAction Install -DeployPurpose Required

    # Move the application to a specific location in SCCM
    $app = Get-CMApplication -Name "$AppName"
    if ($app) {
        Move-CMObject -FolderPath $SccmAppFolder -InputObject $app
    }
    else {
        Write-Log "Error: Application $AppName not found, could not move it."
    }

    Write-Log "Deployment for $AppName completed."
}

# Check if the updates JSON file exists
if (-not (Test-Path $updateHistoryPath)) {
    Write-Log "Error: The update_history.json file was not found at $updateHistoryPath."
    #exit
}

# Read the JSON content
$updateData = Get-Content -Path $updateHistoryPath | ConvertFrom-Json

# Check if there are any updates listed
if (-not $updateData.updates) {
    Write-Log "No updates found in the JSON."
    exit
}

ConnectSCCM -SiteCode $SiteCode -ProviderMachineName $ProviderMachineName

# Process each software listed in the JSON
foreach ($software in $updateData.updates) {
    $appName = $software.software
    $appVersion = $software.version
    $appPath = $software.path

    Write-Log "Processing update for $appName version $appVersion..."

    Pop-Location

    # Identify the installer type
    $installerFiles = Get-ChildItem -Path $appPath -File | Where-Object { $_.Extension -match "msi|exe" }

    if (-not $installerFiles) {
        Write-Log "Error: No installer found for $appName in $appPath."
        continue
    }

    # Take the first valid installer found
    $installer = $installerFiles[0].FullName
    $installerType = Get-InstallerType -file $installer

    Write-Log "Identified $installerType installer for $appName : $installer"

    Push-Location "$($SiteCode):\"

    # Create deployment in SCCM
    CreateSccmDeployment -AppName "$appName" -AppVersion "$appVersion" -AppType $installerType -AppFilePath $installer -AppYamlPath $appPath
}

Write-Log "Update processing completed."
Pop-Location