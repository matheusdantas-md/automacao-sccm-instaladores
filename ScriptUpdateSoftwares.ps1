# Configurações
$softwareList = Get-Content -Path "C:\temp\Scripts\software_list.json" | ConvertFrom-Json
$downloadDir = "C:\temp\Instaladores"
$logFile = "C:\temp\Scripts\update_log.log"
$DestDir = "D:\Applications"  # Caminho para o servidor onde os instaladores serão organizados
$supportedExtensions = @(".exe", ".msi")

# Criar diretório de download, se não existir
if (!(Test-Path -Path $downloadDir)) { New-Item -ItemType Directory -Path $downloadDir -Force }

# Função para registrar logs
function Write-Log {
    param (
        [string]$message,
        [String]$color = "white")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    
    # Usar bloqueio de arquivo para evitar acesso concorrente
    $fileStream = [System.IO.File]::Open($logFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $streamWriter = New-Object System.IO.StreamWriter($fileStream)
    $streamWriter.WriteLine($logMessage)
    $streamWriter.Close()
    $fileStream.Close()
    
    Write-Host $logMessage -ForegroundColor $color
}

# Função para obter a versão do instalador
function Get-InstallerVersion {
    param ([string]$installerPath)
    try {
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($installerPath)
        if ($fileName -match "_(\d+\.\d+(\.\d+){0,2})_") {
            return $matches[1]
        }
        else {
            Write-Log "Versão do instalador não encontrada no nome do arquivo: $installerPath"  
            return $null
        }
    }
    catch {
        Write-Log "Erro ao obter versão do instalador: $installerPath - $_"
        return $null
    }
}

# Função para obter a versão mais recente do software via Winget
function Get-LatestVersion {
    param ([string]$softwareId)
    try {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Log "winget não está instalado ou disponível no sistema."
            return $null
        }

        $wingetInfo = winget show --id $softwareId | Out-String
        $latestVersion = ($wingetInfo -split "`n" | Where-Object { $_ -match "Version:\s+([\d\.]+)" } | ForEach-Object { $matches[1] }) | Select-Object -First 1
        return $latestVersion
    }
    catch {
        Write-Log "Erro ao obter versão mais recente de $softwareId - $_"
        return $null
    }
}

# Função para gerar um nome amigável para a pasta
function Get-FriendlyFolderName {
    param ([string]$installerName)
    $friendlyName = $installerName.Split('_')[0]
    $friendlyName = $friendlyName.Substring(0, 1).ToUpper() + $friendlyName.Substring(1).ToLower()
    return $friendlyName
}

# Verificar e baixar atualizações
foreach ($software in $softwareList.softwares) {
    Write-Log "Verificando atualizações para $software..."

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
        Write-Log "Pulado: não foi possível obter a versão mais recente de $software."
        continue
    }

    if ($existingInstaller) {
        Write-Log "Instalador existente encontrado: $($existingInstaller.FullName)"

        $currentVersion = Get-InstallerVersion -installerPath $existingInstaller.FullName
        if (-not $currentVersion) {
            Write-Log "Pulado: não foi possível obter a versão do instalador existente de $software." -color Red
            continue
        }

        Write-Log "Versão atual do instalador: $currentVersion" -color DarkYellow
        Write-Log "Versão mais recente disponível: $latestVersion" -color Cyan

        if ($currentVersion -ne $latestVersion) {
            Write-Log "Nova versão disponível. Atualizando $software..." -color DarkGreen

            try {
                Remove-Item -Path $existingInstaller.FullName -Force
                Write-Log "Instalador antigo removido: $($existingInstaller.FullName)" -color Green
            }
            catch {
                Write-Log "Erro ao remover instalador antigo $($existingInstaller.FullName): $_" -color Red
                continue
            }

            try {
                winget download --id $software --download-directory $downloadDir --accept-source-agreements --accept-package-agreements
                if ($?) {
                    Write-Log "Download concluído para $software (versão $latestVersion)." -color Green
                }
                else {
                    Write-Log "Erro no comando winget para $software." -color Red
                }
            }
            catch {
                Write-Log "Erro ao baixar nova versão de $software $_" -color Red
            }
        }
        else {
            Write-Log "O instalador já está na versão mais recente. Nenhuma ação necessária." -color Green
        }
    }
    else {
        Write-Log "Nenhum instalador encontrado para $software. Baixando a versão mais recente..." -color Yellow
        try {
            winget download --id $software --download-directory $downloadDir --accept-source-agreements --accept-package-agreements
            if ($?) {
                Write-Log "Download concluído para $software." -color Green
            }
            else {
                Write-Log "Erro no comando winget para $software." -color Red
            }
        }
        catch {
            Write-Log "Erro ao baixar $software $_" -color Red
        }
    }
}

# Copiar os instaladores para as pastas organizadas no servidor
$installers = Get-ChildItem -Path $downloadDir -File
$processedFolders = @()

foreach ($installer in $installers) {
    $AppFolder = Join-Path -Path $DestDir -ChildPath (Get-FriendlyFolderName -installerName $installer.BaseName)
    
    if ($processedFolders -contains $AppFolder) {
        continue
    }
    
    if (Test-Path -Path $AppFolder) {
        Write-Log "A pasta $AppFolder já existe. Verificando arquivos antigos..."
        
        $oldFiles = Get-ChildItem -Path $AppFolder -File
        
        if ($oldFiles.Count -gt 0) {
            Write-Log "Removendo $($oldFiles.Count) arquivo(s) antigo(s) de $AppFolder."
            $oldFiles | Remove-Item -Force -Recurse
        } else {
            Write-Log "Nenhum arquivo antigo encontrado em $AppFolder."
        }
    } else {
        Write-Log "Criando pasta para $($installer.BaseName) no servidor."
        New-Item -ItemType Directory -Path $AppFolder -Force
    }

    try {
        $installerBaseName = [System.IO.Path]::GetFileNameWithoutExtension($installer.Name)
        $matchingFiles = Get-ChildItem -Path $downloadDir -Filter "$installerBaseName.*" -File

        foreach ($file in $matchingFiles) {
            $DestPath = Join-Path -Path $AppFolder -ChildPath $file.Name

            if (!(Test-Path -Path $DestPath)) {
                Write-Log "Copiando $($file.Name) para $DestPath." -color Green
                Copy-Item -Path $file.FullName -Destination $DestPath -Force
            } else {
                Write-Log "Arquivo $($file.Name) já está na pasta. Pulando cópia." -color Yellow
            }
        }
    } catch {
        Write-Log "Erro ao copiar arquivos para $AppFolder $_" -color Red
    }

    $processedFolders += $AppFolder

    Start-Sleep -Seconds 1
}

Write-Log "Processo de atualização concluído." -color Green
