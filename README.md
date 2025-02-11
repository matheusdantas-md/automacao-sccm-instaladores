# Automatic Installer Management with PowerShell

## Overview

This project automates the download, organization, and deployment of software installers in SCCM, using Winget to fetch the latest versions. It checks if a new version is available and, if so, downloads, organizes the files automatically, and deploys the applications in SCCM without manual intervention.

## Features

- **Automatic Verification**: Compares the already downloaded software version with the latest version available via Winget.
- **Automated Download**: Retrieves the latest installers and organizes them into structured folders.
- **Log Recording**: Maintains a history of updates for auditing and debugging purposes.
- **Environment Adaptability**: Can be configured for different scenarios without requiring authentication.
- **New Download Function**: The script now includes a dedicated function to download installers via Winget, making the code more modular and easier to maintain.
- **Update Recording in JSON**: A JSON file is generated on the server to log which software has been updated, eliminating the need for the next deploy script to check all the folders and speeding up the process.
- **Smart File Copying Check**: Before copying an installer to the server, the script compares the existing version with the new one. If they are the same, the copy is skipped, reducing unnecessary transfers.
- **Automatic SCCM Deployment**: Identifies software type (MSI or EXE), removes old versions, and creates new deployments automatically.
- **YAML Parameter Parsing**: Uses YAML files to fetch installation parameters for EXE installers.
- **Detection Method Creation**: Ensures that EXE applications are properly installed by generating detection rules.
- **Content Distribution**: Automatically distributes the updated content to the defined DP Groups in SCCM.

## Requirements

- Windows 10/11 with Winget support
- PowerShell 5.1 or later
- Permission to execute scripts (Set-ExecutionPolicy)
- SCCM environment configured for application deployment

## How to Use

1. **Download the script**
   ```powershell
   git clone https://github.com/matheusdantas-md/automacao-sccm-instaladores.git
   cd automacao-sccm-instaladores
   ```
2. **Configure the software list**
   Edit the `software_list.json` file with the desired packages (based on Winget IDs).
3. **Run the script**
   ```powershell
   .\ScriptUpdateSoftwares.ps1
   ```
4. **Deploy applications in SCCM**
   ```powershell
   .\DeploySCCM.ps1
   ```
5. **Check the logs**
   Logs will be stored in `C:\temp\Scripts\update_log.log`.

## Contribution

Pull requests are welcome! If you have ideas for improvements, feel free to open an issue.

---

# Gerenciamento Automático de Instaladores com PowerShell

## Visão Geral

Este projeto automatiza o download, a organização e o deploy de instaladores de software no SCCM, utilizando o Winget para buscar as versões mais recentes. Ele verifica se há uma nova versão disponível e, caso positivo, baixa, organiza os arquivos automaticamente e implanta as aplicações no SCCM sem necessidade de intervenção manual.

## Funcionalidades

- **Verificação Automática**: Compara a versão do software já baixado com a versão mais recente disponível via Winget.
- **Download Automatizado**: Obtém os instaladores mais recentes e os organiza em pastas estruturadas.
- **Registro de Logs**: Mantém um histórico das atualizações para auditoria e depuração.
- **Adaptação ao Ambiente**: Pode ser configurado para diferentes cenários sem necessidade de autenticação.
- **Nova Função de Download**: O script agora possui uma função dedicada para baixar os instaladores via Winget, tornando o código mais modular e fácil de manter.
- **Registro de Atualizações em JSON**: Um arquivo JSON é gerado no servidor para registrar quais softwares foram atualizados. Isso elimina a necessidade do próximo script de deploy verificar todas as pastas, acelerando o processo.
- **Verificação Inteligente na Cópia de Arquivos**: Antes de copiar um instalador para o servidor, o script compara a versão existente com a nova. Se forem iguais, a cópia é evitada, reduzindo transferências desnecessárias.
- **Deploy Automático no SCCM**: Identifica o tipo de instalador (MSI ou EXE), remove versões antigas e cria novos deployments automaticamente.
- **Leitura de Parâmetros via YAML**: Usa arquivos YAML para obter os parâmetros de instalação de EXEs.
- **Criação de Método de Detecção**: Garante que as aplicações EXE sejam corretamente instaladas criando regras de detecção.
- **Distribuição de Conteúdo**: Distribui automaticamente o conteúdo atualizado para os DP Groups definidos no SCCM.

## Requisitos

- Windows 10/11 com suporte ao Winget
- PowerShell 5.1 ou superior
- Permissão para execução de scripts (Set-ExecutionPolicy)
- Ambiente SCCM configurado para implantação de aplicações

## Como Usar

1. **Baixe o script**
   ```powershell
   git clone https://github.com/matheusdantas-md/automacao-sccm-instaladores.git
   cd automacao-sccm-instaladores
   ```
2. **Configure a lista de softwares**
   Edite o arquivo `software_list.json` com os pacotes desejados (baseados no ID do Winget).
3. **Execute o script**
   ```powershell
   .\ScriptUpdateSoftwares.ps1
   ```
4. **Implante as aplicações no SCCM**
   ```powershell
   .\DeploySCCM.ps1
   ```
5. **Verifique os logs**
   Os registros serão armazenados em `C:\temp\Scripts\update_log.log`.


## Contribuição

Pull requests são bem-vindos! Se tiver ideias para melhorias, sinta-se à vontade para abrir uma issue.

