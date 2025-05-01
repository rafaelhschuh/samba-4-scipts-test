# Samba 4 Manager - Debian Scripts (Refatorado)

[![Author](https://img.shields.io/badge/Author-Rafael%20Schuh%20%26%20Manus-blue.svg)](https://github.com/rafaelhschuh)

---

## Visão Geral

Bem-vindo à coleção de scripts **Samba 4 Manager**! Este conjunto de scripts fornece uma interface amigável baseada em terminal (`dialog`) para simplificar a instalação, configuração e gerenciamento do Samba 4 em sistemas baseados em Debian. Seja para configurar um Controlador de Domínio Active Directory, um servidor de arquivos autônomo ou um membro de domínio, estes scripts visam agilizar o processo.

Os scripts suportam múltiplos idiomas (Inglês e Português Brasileiro), possuem um sistema de logging centralizado e guiam você através dos passos necessários com prompts claros e feedback.

**Nota:** Esta é uma versão refatorada com estrutura de diretórios aprimorada e logging implementado.

## Funcionalidades

*   **Suporte Multi-idioma**: Escolha entre Inglês (US) e Português (Brasil) na inicialização.
*   **Interface Amigável**: Utiliza `dialog` para uma experiência limpa e orientada por menus no terminal.
*   **Instalação/Atualização do Samba**: Verifica instalações existentes do Samba e oferece instalação completa ou atualização.
*   **Funções Versáteis do Samba**:
    *   Configurar Samba 4 como **Controlador de Domínio Active Directory**.
    *   Configurar Samba 4 como **Servidor de Arquivos Autônomo**.
    *   Ingressar em um domínio existente como **Membro de Domínio**.
*   **Gerenciamento de Dependências**: Verifica e instala automaticamente as dependências necessárias para o Samba e os scripts do gerenciador.
*   **Sistema de Logging**: Registra as principais operações e erros em um arquivo de log centralizado (`/opt/samba-manager-app/logs/samba_manager.log` por padrão após instalação).
*   **Auto-Atualização**: Opção para verificar e instalar atualizações para os scripts do Samba Manager (funcionalidade original, pode precisar de revisão no script `atualizar_manager.sh` para compatibilidade com nova estrutura).
*   **Gerenciamento de Grupos e Permissões**: 
    *   Definir uma tag global para grupos.
    *   Criar novos grupos com a tag definida (`nomegrupo-smb@tag`).
    *   Modificar permissões de grupo em pastas compartilhadas usando ACLs.
    *   Listar grupos (com tag) e seus membros.
*   **Gerenciamento de Usuários**: 
    *   Definir uma tag global para usuários (usa a mesma tag dos grupos).
    *   Adicionar novos usuários com a tag definida (`nomeusuario@tag`).
    *   Associar novos usuários a grupos com tag existentes.
    *   Listar usuários (com tag).
*   **Área Crítica**: Remover com segurança o Samba 4, os scripts do Samba Manager, ou ambos.
*   **Instalação Simplificada**: Um script `install.sh` para copiar os arquivos para `/opt/samba-manager-app` e criar um lançador.

## Instalação

Para instalar ou atualizar o Samba 4 Manager no seu sistema Debian, execute o intalador automático, copiando e colando no seu terminal:

```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/rafaelhschuh/samba-4-scipts/main/install.sh)"
```

**Ou com curl:**

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/rafaelhschuh/samba-4-scipts/main/install.sh)"
```

O script de instalação irá:
*   Verificar se está sendo executado como root.
*   Remover qualquer instalação anterior em `/opt/samba-manager-app`.
*   Criar os diretórios `/opt/samba-manager-app/samba_manager` e `/opt/samba-manager-app/logs`.
*   Copiar os scripts e arquivos de documentação para `/opt/samba-manager-app`.
*   Tornar os scripts executáveis.
*   Criar um lançador chamado `samba-manager` em `/usr/local/bin`.

## Uso

Após uma instalação bem-sucedida, você pode executar o Samba 4 Manager de qualquer lugar no seu terminal usando o seguinte comando:

```bash
sudo samba-manager
```

1.  Você será solicitado a selecionar seu idioma preferido (Inglês ou Português).
2.  O menu principal aparecerá, permitindo que você escolha entre as várias opções de gerenciamento.
3.  As operações serão registradas no arquivo de log: `/opt/samba-manager-app/logs/samba_manager.log`.

Siga as instruções na tela fornecidas pela interface `dialog` para completar as tarefas desejadas.

## Estrutura de Diretórios (Após Instalação)

```
/opt/samba-manager-app/
├── logs/
│   └── samba_manager.log  # Arquivo de log principal
├── samba_manager/         # Diretório principal dos scripts
│   ├── lib/
│   │   └── logging.sh     # Biblioteca de logging
│   ├── locale/
│   │   ├── en_US.sh       # Arquivo de idioma Inglês
│   │   └── pt_BR.sh       # Arquivo de idioma Português
│   ├── adicionar_usuario.sh
│   ├── adicionar_usuario_dialog.sh
│   ├── area_critica.sh
│   ├── atualizar_manager.sh
│   ├── gerenciar_grupos.sh
│   ├── gerenciar_usuarios.sh
│   ├── instalar_atualizar_samba.sh
│   └── samba_manager.sh   # Script principal
├── DOCUMENTACAO_PT.md
├── DOCUMENTATION_EN.md
└── README.md

/usr/local/bin/
└── samba-manager          # Lançador global
```

## Documentação Detalhada

Para instruções mais detalhadas sobre instalação e uso, consulte a documentação completa disponível em seu idioma preferido:

*   **[English Documentation](./DOCUMENTATION_EN.md)**
*   **[Documentação em Português](./DOCUMENTACAO_PT.md)**

## Requisitos

*   Sistema operacional baseado em Debian (Debian 10 Buster ou superior recomendado).
*   Privilégios de root (`sudo`).
*   Conexão com a Internet (para baixar pacotes e dependências).
*   Pacote `dialog` (será instalado automaticamente se não estiver presente).

## Autor Original

*   **Rafael Schuh** - [github.com/rafaelhschuh](https://github.com/rafaelhschuh)

## Refatoração e Logging

*   **Manus** (Maio 2025)

---

Sinta-se à vontade para contribuir, reportar problemas ou sugerir melhorias no repositório original ou no fork onde esta refatoração foi realizada.

