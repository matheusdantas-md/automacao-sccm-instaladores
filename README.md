# Gerenciamento Automático de Instaladores com PowerShell

## Visão Geral

Este projeto automatiza o download e a organização de instaladores de software no SCCM, utilizando o Winget para buscar as versões mais recentes. Ele verifica se há uma nova versão disponível e, caso positivo, baixa e organiza os arquivos automaticamente. Posteriormente, um segundo script será desenvolvido para criar o deploy dessas aplicações no SCCM sem necessidade de intervenção manual.

## Funcionalidades

- **Verificação Automática**: Compara a versão do software já baixado com a versão mais recente disponível via Winget.
- **Download Automatizado**: Obtém os instaladores mais recentes e os organiza em pastas estruturadas.
- **Registro de Logs**: Mantém um histórico das atualizações para auditoria e depuração.
- **Adaptação ao Ambiente**: Pode ser configurado para diferentes cenários sem necessidade de autenticação.

## Requisitos

- Windows 10/11 com suporte ao Winget
- PowerShell 5.1 ou superior
- Permissão para execução de scripts (Set-ExecutionPolicy)

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
4. **Verifique os logs**
   Os registros serão armazenados em `C:\temp\Scripts\update_log.log`.

## Próximos Passos

- Desenvolvimento de um script complementar para criar automaticamente os pacotes e deploy no SCCM.
- Melhorias na gestão de erros e otimização do processo de detecção de versões.

## Contribuição

Pull requests são bem-vindos! Se tiver ideias para melhorias, sinta-se à vontade para abrir uma issue.

